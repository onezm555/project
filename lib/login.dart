/**
 * @fileoverview หน้าล็อคอินสำหรับแอปพลิเคชัน Flutter
 * 
 * รายละเอียดทั่วไป:
 * - หน้าล็อคอินที่มี UI สวยงามตามแบบที่กำหนด
 * - รองรับการกรอกอีเมลและรหัสผ่าน
 * - มีปุ่มแสดง/ซ่อนรหัสผ่าน
 * - มีลิงก์สำหรับลืมรหัสผ่าน
 * - เชื่อมต่อไปหน้าสมัครสมาชิก
 * - ใช้โลโก้จากไฟล์ lib/img/logo.png
 * 
 * การอัปเดต:
 * - 06/06/2025: เริ่มพัฒนาหน้าล็อคอิน
 * - 06/06/2025: เพิ่มการเชื่อมต่อไปหน้าสมัครสมาชิก
 */

import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    _email_controller.dispose();
    _password_controller.dispose();
    super.dispose();
  }

  // ฟังก์ชันสำหรับจัดการการล็อคอิน
  Future<void> _handle_login() async {
    if (!_form_key.currentState!.validate()) {
      return;
    }

    setState(() {
      _is_loading = true;
    });

    try {
      // TODO: เพิ่มการเรียก API สำหรับล็อคอิน
      await Future.delayed(const Duration(seconds: 2)); // จำลองการเรียก API
      
      // หากล็อคอินสำเร็จ นำทางไปหน้าหลัก
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MainLayout(),
          ),
        );
      }
    } catch (error) {
      // จัดการข้อผิดพลาด
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เข้าสู่ระบบไม่สำเร็จ: $error'),
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

  // ฟังก์ชันสำหรับไปหน้าสมัครสมาชิก
  void _navigate_to_register() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegisterPage(),
      ),
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
                
                // โลโก้
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
                        // ถ้าโหลดรูปไม่ได้ จะแสดงไอคอนแทน
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
                
                // ช่องกรอกอีเมล
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
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'รูปแบบอีเมลไม่ถูกต้อง';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // ช่องกรอกรหัสผ่าน
                TextFormField(
                  controller: _password_controller,
                  obscureText: !_is_password_visible,
                  decoration: InputDecoration(
                    hintText: 'รหัสผ่าน',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _is_password_visible ? Icons.visibility : Icons.visibility_off,
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
                
                // ปุ่มเข้าสู่ระบบ
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                
                // ลิงก์ลืมรหัสผ่าน
                TextButton(
                  onPressed: _navigate_to_register,
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
                
                // ข้อความและลิงก์สมัครสมาชิก
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'ยังไม่มีบัญชี? ',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
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