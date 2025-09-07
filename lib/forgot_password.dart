import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Ensure this class name is consistent
class ConfirmOtpAndResetPasswordPage extends StatefulWidget {
  final String email;

  // Constructor must match the class name
  const ConfirmOtpAndResetPasswordPage({Key? key, required this.email}) : super(key: key);

  @override
  // createState must return the State object for this StatefulWidget
  State<ConfirmOtpAndResetPasswordPage> createState() => _ConfirmOtpAndResetPasswordPageState();
}

// State class name must be consistent with the StatefulWidget
class _ConfirmOtpAndResetPasswordPageState extends State<ConfirmOtpAndResetPasswordPage> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmNewPasswordVisible = false;
  String _apiBaseUrl = '';

  @override
  void initState() {
    super.initState();
    _apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project';
  }

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_newPasswordController.text != _confirmNewPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('รหัสผ่านใหม่และการยืนยันรหัสผ่านไม่ตรงกัน'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String apiUrl = '$_apiBaseUrl/reset_password_with_otp.php'; // New backend endpoint

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'email': widget.email,
          'otp': _otpController.text,
          'new_password': _newPasswordController.text,
        }),
      );

      if (mounted) {
        final responseData = jsonDecode(response.body);
        if (response.statusCode == 200 && responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'รีเซ็ตรหัสผ่านสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate back to login page (or main layout if already logged in)
          Navigator.of(context).popUntil((route) => route.isFirst); // Go back to the first route (Login Page)
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'ไม่สามารถรีเซ็ตรหัสผ่านได้'),
              backgroundColor: Colors.red,
            ),
          );
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
          _isLoading = false;
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
              Container(
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
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'รีเซ็ตรหัสผ่าน',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Text(
                            'เราได้ส่งรหัสยืนยันไปยัง ${widget.email} กรุณากรอกรหัสและรหัสผ่านใหม่ของคุณ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // OTP Field
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
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              hintText: 'รหัสยืนยัน (OTP)',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: Icon(
                                Icons.vpn_key_outlined,
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
                              counterText: '',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'กรุณากรอกรหัสยืนยัน';
                              }
                              if (value.length != 6) {
                                return 'รหัสยืนยันต้องมี 6 ตัวเลข';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        // New Password Field
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
                            controller: _newPasswordController,
                            obscureText: !_isNewPasswordVisible,
                            decoration: InputDecoration(
                              hintText: 'รหัสผ่านใหม่',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: Colors.purple[400],
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.purple[400],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isNewPasswordVisible = !_isNewPasswordVisible;
                                  });
                                },
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
                                return 'กรุณากรอกรหัสผ่านใหม่';
                              }
                              if (value.length < 6) {
                                return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Confirm Password Field
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
                            controller: _confirmNewPasswordController,
                            obscureText: !_isConfirmNewPasswordVisible,
                            decoration: InputDecoration(
                              hintText: 'ยืนยันรหัสผ่านใหม่',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: Colors.purple[400],
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isConfirmNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.purple[400],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isConfirmNewPasswordVisible = !_isConfirmNewPasswordVisible;
                                  });
                                },
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
                                return 'กรุณายืนยันรหัสผ่านใหม่';
                              }
                              if (value != _newPasswordController.text) {
                                return 'รหัสผ่านไม่ตรงกัน';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Reset Button
                        Container(
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
                            onPressed: _isLoading ? null : _resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'รีเซ็ตรหัสผ่าน',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
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