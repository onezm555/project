import 'package:flutter/material.dart';

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
  final TextEditingController _confirm_password_controller = TextEditingController();
  final GlobalKey<FormState> _form_key = GlobalKey<FormState>();
  
  bool _is_password_visible = false;
  bool _is_confirm_password_visible = false;
  bool _is_loading = false;

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

    setState(() {
      _is_loading = true;
    });

    try {
      // TODO: เพิ่มการเรียก API สำหรับสมัครสมาชิก
      await Future.delayed(const Duration(seconds: 2)); // จำลองการเรียก API
      
      // หากสมัครสมาชิกสำเร็จ กลับไปหน้าล็อคอิน
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สมัครสมาชิกสำเร็จ กรุณาเข้าสู่ระบบ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      // จัดการข้อผิดพลาด
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('สมัครสมาชิกไม่สำเร็จ: $error'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _form_key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // หัวข้อ
                const Text(
                  'สมัครสมาชิก',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // ช่องกรอกชื่อผู้ใช้
                const Text(
                  'ชื่อผู้ใช้',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name_controller,
                  decoration: InputDecoration(
                    hintText: 'กรอกชื่อผู้ใช้',
                    prefixIcon: const Icon(Icons.person_outline),
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
                      return 'กรุณากรอกชื่อผู้ใช้';
                    }
                    if (value.length < 2) {
                      return 'ชื่อผู้ใช้ต้องมีอย่างน้อย 2 ตัวอักษร';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // ช่องกรอกอีเมล
                const Text(
                  'อีเมล',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _email_controller,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'กรอกอีเมล',
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
                      return 'กรุณากรอกอีเมล';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'รูปแบบอีเมลไม่ถูกต้อง';
                    }
                    return null;
                  },
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
                        _is_confirm_password_visible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _is_confirm_password_visible = !_is_confirm_password_visible;
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
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _is_loading ? null : _handle_register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28A745),
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
                            'สมัครสมาชิก',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}