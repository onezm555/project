import 'package:flutter/material.dart';
import 'verify_code_page.dart';
import 'package:http/http.dart' as http; // นำเข้า http package
import 'dart:convert'; // นำเข้าสำหรับ JSON encoding/decoding
import 'package:flutter_dotenv/flutter_dotenv.dart'; // เพิ่มบรรทัดนี้เพื่อใช้ dotenv

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _name_controller = TextEditingController();
  final TextEditingController _email_controller = TextEditingController();
  final TextEditingController _phone_controller = TextEditingController();
  final TextEditingController _password_controller = TextEditingController();
  final TextEditingController _confirm_password_controller =
      TextEditingController();
  final GlobalKey<FormState> _form_key = GlobalKey<FormState>();

  bool _is_password_visible = false;
  bool _is_confirm_password_visible = false;
  bool _is_loading = false; // สถานะการโหลดเมื่อกำลังส่งข้อมูล

  @override
  void dispose() {
    _name_controller.dispose();
    _email_controller.dispose();
    _phone_controller.dispose();
    _password_controller.dispose();
    _confirm_password_controller.dispose();
    super.dispose();
  }

  // ฟังก์ชันสำหรับจัดการการสมัครสมาชิก
  Future<void> _handle_register() async {
    if (!_form_key.currentState!.validate()) {
      return;
    }

    // ตรวจสอบรหัสผ่านและการยืนยันรหัสผ่านว่าตรงกันหรือไม่
    if (_password_controller.text != _confirm_password_controller.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('รหัสผ่านและการยืนยันรหัสผ่านไม่ตรงกัน'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _is_loading = true; // ตั้งค่าสถานะเป็นกำลังโหลด
    });

    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['API_BASE_URL']}/register.php'), // ใช้ URL จาก .env
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'name': _name_controller.text,
          'email': _email_controller.text,
          'phone': _phone_controller.text,
          'password': _password_controller.text,
        }),
      );

      // ตรวจสอบว่า widget ยังคงอยู่ใน tree หรือไม่ ก่อนที่จะอัปเดต UI
      if (mounted) {
        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          if (responseData['status'] == 'success') {
            // สมัครสมาชิกสำเร็จ นำทางไปยังหน้ายืนยันรหัส
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['message']),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VerifyCodePage(email: _email_controller.text), // ส่ง email ไปยังหน้า VerifyCodePage
              ),
            );
          } else {
            // สมัครสมาชิกไม่สำเร็จจากข้อผิดพลาดที่มาจาก API
            // แม้ statusCode เป็น 200 แต่ status ใน JSON เป็น 'error'
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['message']),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // ส่วนที่แก้ไข: จัดการกับ status code ที่ไม่ใช่ 200 (เช่น 400, 409, 500)
          String errorMessage = 'เกิดข้อผิดพลาดที่ไม่รู้จัก'; // ข้อความเริ่มต้นหากอ่านไม่ได้
          try {
            final Map<String, dynamic> errorResponseData = jsonDecode(response.body);
            if (errorResponseData.containsKey('message')) {
              errorMessage = errorResponseData['message']; // ดึงข้อความผิดพลาดจาก Server
            } else {
              // กรณีที่ Server ส่ง statusCode ไม่ใช่ 200 แต่ไม่มี 'message' ใน JSON
              errorMessage = 'Server ตอบกลับมาไม่ถูกต้อง: ${response.statusCode}';
            }
          } catch (e) {
            // ถ้า Response body ไม่ใช่ JSON ที่ถูกต้อง ก็ใช้ข้อความผิดพลาดทั่วไป
            errorMessage = 'เกิดข้อผิดพลาดในการเชื่อมต่อกับเซิร์ฟเวอร์ หรือข้อมูลเสียหาย';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage), // แสดงข้อความที่ได้จาก Server หรือข้อความทั่วไป
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // จัดการกับข้อผิดพลาดเครือข่าย หรือ Exception อื่นๆ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // ไม่ว่าจะสำเร็จหรือล้มเหลว ให้ตั้งค่าสถานะโหลดกลับเป็น false
      if (mounted) {
        setState(() {
          _is_loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF3E8FF), // ม่วงอ่อน (purple-50)
              Color(0xFFE9D5FF), // ม่วงกลาง (purple-100)
              Color(0xFFDDD6FE), // ม่วงไวโอเล็ต (violet-200)
              Color(0xFFF0E6FF), // ลาเวนเดอร์อ่อน
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _form_key,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        // หัวข้อ
                        const Center(
                          child: Text(
                            'สมัครสมาชิก',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'สร้างบัญชีใหม่เพื่อเริ่มใช้งาน',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ช่องกรอกชื่อผู้ใช้
                        const Text(
                          'ชื่อผู้ใช้',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _name_controller,
                            decoration: InputDecoration(
                              hintText: 'กรอกชื่อผู้ใช้',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: Colors.purple[400],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.purple[400]!,
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'กรุณากรอกชื่อผู้ใช้';
                              }
                              if (value.length < 2) {
                                return 'ชื่อผู้ใช้ต้องมีอย่างน้อย 2 ตัวอักษร';
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 20),
                        // ช่องกรอกอีเมล
                        const Text(
                          'อีเมล',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _email_controller,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'กรอกอีเมล',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: Colors.purple[400],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.purple[400]!,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
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
                        ),

                const SizedBox(height: 20),

                // ช่องกรอกเบอร์โทร
                const Text(
                  'เบอร์โทร',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phone_controller,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'กรอกเบอร์โทร',
                    prefixIcon: const Icon(Icons.phone_outlined),
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
                      borderSide: const BorderSide(color: Colors.green),
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
                      return 'กรุณากรอกเบอร์โทร';
                    }
                    if (!RegExp(r'^[0-9]{9,10}$').hasMatch(value)) {
                      return 'เบอร์โทรต้องเป็นตัวเลข 9-10 หลัก';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // ช่องกรอกรหัสผ่าน
                const Text(
                  'รหัสผ่าน',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _password_controller,
                  obscureText: !_is_password_visible,
                  decoration: InputDecoration(
                    hintText: 'กรอกรหัสผ่าน',
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
                      borderSide: const BorderSide(color: Colors.green),
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

                const SizedBox(height: 20),

                // ช่องกรอกยืนยันรหัสผ่าน
                const Text(
                  'ยืนยันรหัสผ่าน',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirm_password_controller,
                  obscureText: !_is_confirm_password_visible,
                  decoration: InputDecoration(
                    hintText: 'ยืนยันรหัสผ่าน',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _is_confirm_password_visible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _is_confirm_password_visible =
                              !_is_confirm_password_visible;
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
                      borderSide: const BorderSide(color: Colors.green),
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
                      return 'กรุณายืนยันรหัสผ่าน';
                    }
                    if (value != _password_controller.text) {
                      return 'รหัสผ่านไม่ตรงกัน';
                    }
                    return null;
                  },
                ),

                        const SizedBox(height: 40),
                        // ปุ่มสมัครสมาชิก
                        Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF9C4AE0),
                                Color(0xFF7C3AED),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _is_loading ? null : _handle_register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _is_loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'สมัครสมาชิก',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}