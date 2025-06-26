import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // เพิ่ม package http
import 'dart:convert'; // เพิ่ม dart:convert สำหรับ JSON encoding/decoding
import 'success_register_page.dart'; // ตรวจสอบว่าไฟล์นี้มีอยู่จริง
import 'main_layout.dart'; // หรือหน้าที่คุณต้องการให้ไปหลังจากยืนยันสำเร็จ

class VerifyCodePage extends StatefulWidget {
  final String email; // เพิ่ม email parameter เข้ามา
  const VerifyCodePage({Key? key, required this.email}) : super(key: key);

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  // สร้าง Controllers สำหรับแต่ละช่องกรอกโค้ด
  final List<TextEditingController> _code_controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focus_nodes =
      List.generate(6, (index) => FocusNode());

  bool _is_loading = false; // สถานะสำหรับปุ่ม "ยืนยัน"

  @override
  void dispose() {
    for (var controller in _code_controllers) {
      controller.dispose();
    }
    for (var focusNode in _focus_nodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  // ฟังก์ชันสำหรับจัดการการยืนยันโค้ด
  Future<void> _handle_verify_code() async {
    // รวมรหัสจากแต่ละช่องเป็นสตริงเดียว
    String enteredCode = _code_controllers.map((c) => c.text).join();

    // ตรวจสอบว่ากรอกครบ 6 หลักหรือไม่
    if (enteredCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกรหัสยืนยันให้ครบ 6 หลัก'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _is_loading = true; // แสดง loading
    });

    // กำหนด URL ของ API
    // **สำคัญ: เปลี่ยน YOUR_SERVER_IP_OR_DOMAIN เป็น IP หรือโดเมนของเซิร์ฟเวอร์ PHP ของคุณ**
    // ใช้ IP เดียวกันกับที่ใช้ใน login.dart
    const String apiUrl = 'http://10.10.33.118/project/verify_code.php'; // ตัวอย่าง: ใช้ IP เดียวกับที่คุณเจอใน error

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'email': widget.email, // ส่ง email ที่ได้รับมาจากหน้า Register
          'code': enteredCode, // ส่งรหัสที่ผู้ใช้กรอก
        }),
      );

      if (mounted) {
        final responseData = jsonDecode(response.body);
        if (response.statusCode == 200) {
          // ยืนยันสำเร็จ
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'ยืนยันโค้ดสำเร็จ!'),
              backgroundColor: Colors.green,
            ),
          );
          // นำทางไปหน้าสำเร็จการลงทะเบียน หรือหน้าหลัก
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const SuccessRegisterPage(), // หรือ MainLayout()
            ),
          );
        } else {
          // ยืนยันไม่สำเร็จ (มีข้อผิดพลาดจาก PHP)
          // PHP จะส่งข้อความ error ที่ชัดเจนกลับมา (เช่น "รหัสยืนยันโค้ดไม่ถูกต้อง")
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'เกิดข้อผิดพลาดในการยืนยัน'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // จัดการข้อผิดพลาดระดับเครือข่าย หรือ JSON parsing
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
          _is_loading = false; // ซ่อน loading
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'ยืนยันโค้ด',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'ใส่รหัสยืนยันของคุณที่ส่งไปยังอีเมลของคุณ',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 45,
                  height: 55,
                  child: TextField(
                    controller: _code_controllers[index],
                    focusNode: _focus_nodes[index],
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    textAlign: TextAlign.center, // จัดข้อความให้อยู่ตรงกลาง
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // ทำให้รหัสตัวใหญ่ขึ้น
                    decoration: InputDecoration(
                      counterText: "",
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder( // เพิ่ม focus border
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.length == 1) {
                        // ถ้ากรอกแล้ว ให้เลื่อนไปช่องถัดไป
                        if (index < 5) {
                          FocusScope.of(context).requestFocus(_focus_nodes[index + 1]);
                        } else {
                          // ถ้าเป็นช่องสุดท้าย ให้ซ่อนคีย์บอร์ด
                          FocusScope.of(context).unfocus();
                        }
                      } else if (value.isEmpty) {
                        // ถ้าลบ ให้เลื่อนไปช่องก่อนหน้า
                        if (index > 0) {
                          FocusScope.of(context).requestFocus(_focus_nodes[index - 1]);
                        }
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _is_loading ? null : _handle_verify_code, // ผูกกับฟังก์ชัน API
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
                        'ยืนยัน',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
            // ปุ่ม "ส่งรหัสใหม่" (ถ้าต้องการ)
            TextButton(
              onPressed: _is_loading ? null : () {
                // TODO: Implement resend code logic (เรียก API ไปยัง register.php เพื่อส่งโค้ดใหม่)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ฟังก์ชันส่งรหัสใหม่ยังไม่พร้อมใช้งาน'),
                  ),
                );
              },
              child: const Text(
                'ส่งรหัสใหม่',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}