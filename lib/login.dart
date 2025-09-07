import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'request_otp_page.dart';
import 'verify_code_page.dart';
import 'register.dart';
import 'main_layout.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _email_controller = TextEditingController();
  final TextEditingController _password_controller = TextEditingController();
  final GlobalKey<FormState> _form_key = GlobalKey<FormState>();
  bool _is_password_visible = false;
  bool _is_loading = false;
  String _api_base_url = ''; // เพิ่มตัวแปรสำหรับเก็บ base URL

  @override
  void initState() {
    super.initState();
    _api_base_url = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project';
    _loadSavedLogin();
  }

  @override
  void dispose() {
    _email_controller.dispose();
    _password_controller.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('saved_email');
    String? savedPassword = prefs.getString('saved_password');
    if (savedEmail != null) {
      _email_controller.text = savedEmail;
    }
    if (savedPassword != null) {
      _password_controller.text = savedPassword;
    }
  }

  Future<void> _handle_login() async {
    if (!_form_key.currentState!.validate()) {
      return;
    }

    setState(() {
      _is_loading = true;
    });

    // ใช้ _api_base_url ที่ดึงมาจาก .env
    final String apiUrl = '$_api_base_url/login.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'email': _email_controller.text,
          'password': _password_controller.text,
        }),
      );

      if (mounted) {
        final responseData = jsonDecode(response.body);
        
        // Debug: พิมพ์ response เพื่อดู
        print('Response Status Code: ${response.statusCode}');
        print('Response Data: $responseData');
        
        if (response.statusCode == 200) {
          if (responseData['status'] == 'success' &&
              responseData['user_id'] != null) {
            final int userId = responseData['user_id'];
            final String userName = responseData['name'] ?? 'Guest';
            final String? userImgUrl = responseData['profile_image_url'];

            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setInt('user_id', userId);
            await prefs.setString('saved_email', _email_controller.text);
            await prefs.setString('saved_password', _password_controller.text);
            await prefs.setString('user_name', userName); // บันทึกชื่อผู้ใช้
            if (userImgUrl != null) {
              await prefs.setString('user_img', userImgUrl); // บันทึก URL รูปโปรไฟล์
            } else {
              await prefs.remove('user_img'); // ลบถ้าไม่มีรูป
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['message'] ?? 'เข้าสู่ระบบสำเร็จ'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainLayout()),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  responseData['message'] ??
                      'เข้าสู่ระบบไม่สำเร็จ: ไม่พบ User ID',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // ตรวจสอบว่าเป็นกรณี unverified หรือไม่ (ไม่ขึ้นกับ status code)
          print('Checking unverified status: ${responseData['status']}'); // Debug เพิ่ม
          if (responseData['status'] == 'unverified') {
            print('Email from response: ${responseData['email']}'); // Debug เพิ่ม
            _showUnverifiedDialog(responseData['email']);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['message'] ?? 'เข้าสู่ระบบไม่สำเร็จ'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _is_loading = false;
        });
      }
    }
  }

  void _showUnverifiedDialog(String email) {
    print('Showing unverified dialog for email: $email'); // Debug
    
    showDialog(
      context: context,
      barrierDismissible: false, // ไม่ให้ปิดโดยการแตะข้างนอก
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'ยืนยันอีเมล',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'คุณยังไม่ได้ยืนยันอีเมล คุณต้องการส่งรหัสและยืนยันใหม่หรือไม่?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ปิด dialog
              },
              child: const Text(
                'ยกเลิก',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // ปิด dialog
                
                // แสดง loading dialog ขณะส่งรหัส
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 20),
                          Text('กำลังส่งรหัสยืนยัน...'),
                        ],
                      ),
                    );
                  },
                );
                
                // ส่งรหัสยืนยันทันที
                await _sendVerificationCode(email);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('ส่งรหัสใหม่'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendVerificationCode(String email) async {
    try {
      final String apiUrl = '$_api_base_url/send_otp.php';
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'email': email,
        }),
      );

      if (mounted) {
        Navigator.of(context).pop(); // ปิด loading dialog
        
        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          
          if (responseData['status'] == 'success') {
            // ส่งรหัสสำเร็จ - นำทางไปหน้า verify
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['message'] ?? 'ส่งรหัสยืนยันสำเร็จ'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VerifyCodePage(email: email),
              ),
            );
          } else {
            // ส่งรหัสไม่สำเร็จ
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['message'] ?? 'ไม่สามารถส่งรหัสได้'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } else {
          // Server error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('เกิดข้อผิดพลาดในการส่งรหัส'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // ปิด loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _navigate_to_register() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _form_key,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'lib/img/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.business,
                          size: 40,
                          color: Colors.blue[600],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _email_controller,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'อีเมล',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกอีเมล';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'รูปแบบอีเมลไม่ถูกต้อง';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password_controller,
                  obscureText: !_is_password_visible,
                  decoration: InputDecoration(
                    hintText: 'รหัสผ่าน',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _is_password_visible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _is_password_visible = !_is_password_visible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกรหัสผ่าน';
                    }
                    if (value.length < 6) {
                      return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _is_loading ? null : _handle_login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _is_loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'เข้าสู่ระบบ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const RequestOtpPage(), // Navigate to the new page
                      ),
                    );
                  },
                  child: const Text(
                    'ลืมรหัสผ่าน?',
                    style: TextStyle(
                      color: Color(0xFF4A90E2),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'ยังไม่มีบัญชี? ',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: _navigate_to_register,
                      child: const Text(
                        'สมัครสมาชิก',
                        style: TextStyle(
                          color: Color(0xFF4A90E2),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}