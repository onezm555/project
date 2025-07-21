import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // สำหรับโหลด .env
import 'package:shared_preferences/shared_preferences.dart'; // เพิ่ม SharedPreferences เพื่อบันทึกชื่อใหม่

import 'package:image_picker/image_picker.dart';

class ProfileEditPage extends StatefulWidget {
  final String userEmail;
  final String userName;
  // final String? userImgUrl; // ลบออก ไม่ต้องส่ง userImgUrl มาจากหน้าก่อนหน้าแล้ว

  const ProfileEditPage({
    Key? key,
    required this.userEmail,
    required this.userName,
    // this.userImgUrl, // ลบออก
  }) : super(key: key);

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordChange = false;
  
  String? _displayUserImgFileName; // เก็บแค่ชื่อไฟล์ (ส่วนท้ายของ URL)
  String? _displayUserImgUrl; // URL ที่ใช้แสดงผล (URL เต็ม)

  // ฟังก์ชันสำหรับสร้าง URL รูปโปรไฟล์
  String getProfileImageUrl(String? input) {
    if (input == null || input.isEmpty) {
      // คืนค่าว่าง หรือ URL รูปภาพ default ที่คุณต้องการ
      return '';
    }

    // ถ้า input เป็น URL เต็มอยู่แล้ว (มี http:// หรือ https://) ให้คืนค่าเดิมเลย
    if (input.startsWith('http://') || input.startsWith('https://')) {
      print('[DEBUG] getProfileImageUrl: Input is already a full URL: $input');
      return input;
    }

    // ถ้า input เป็นแค่ชื่อไฟล์ หรือ path สัมพัทธ์
    final baseUrl = dotenv.env['PROFILE_IMAGE_BASE_URL'];
    String finalBaseUrl = 'http://10.10.60.143/project/img/'; // Fallback URL (ควรใช้ .env)

    if (baseUrl != null && baseUrl.isNotEmpty) {
      finalBaseUrl = baseUrl;
    } else {
      print('[DEBUG] PROFILE_IMAGE_BASE_URL is null or empty in .env. Using hardcoded fallback: $finalBaseUrl');
    }

    // ตรวจสอบให้แน่ใจว่ามี "/" ระหว่าง baseUrl และ input
    if (!finalBaseUrl.endsWith('/') && !input.startsWith('/')) {
      return '$finalBaseUrl/$input';
    } else if (finalBaseUrl.endsWith('/') && input.startsWith('/')) {
      return '$finalBaseUrl${input.substring(1)}'; // ตัด '/' ซ้ำออก
    } else {
      return '$finalBaseUrl$input';
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userName;
    _loadProfileImage(); // เรียกฟังก์ชันใหม่เพื่อโหลดรูปภาพจาก SharedPreferences
  }

  // ฟังก์ชันสำหรับโหลดรูปโปรไฟล์จาก SharedPreferences
  Future<void> _loadProfileImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // ดึงค่า 'user_img' ซึ่งตอนนี้เราคาดว่ามันคือชื่อไฟล์รูปภาพ
    final String? userImgFileName = prefs.getString('user_img'); 
    print('[DEBUG] _loadProfileImage: loaded user_img from prefs: $userImgFileName');

    if (userImgFileName != null && userImgFileName.isNotEmpty) {
      setState(() {
        _displayUserImgFileName = userImgFileName;
        // ใช้ getProfileImageUrl เพื่อสร้าง URL เต็มจากชื่อไฟล์
        _displayUserImgUrl = getProfileImageUrl(userImgFileName); 
        print('[DEBUG] _loadProfileImage: _displayUserImgUrl = $_displayUserImgUrl');
      });
    } else {
      setState(() {
        _displayUserImgFileName = null;
        _displayUserImgUrl = null; // หรือตั้งค่าเป็น URL รูป Default ของคุณ
        print('[DEBUG] _loadProfileImage: user_img from prefs is null or empty. Using default/no image.');
      });
    }
  }

  // ฟังก์ชันสำหรับเลือกและอัปโหลดรูปภาพ
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final apiUrl = dotenv.env['API_URL_UPLOAD_PROFILE_IMAGE'];
      if (apiUrl == null || apiUrl.isEmpty) {
        _showSnackBar('API URL สำหรับอัปโหลดรูปโปรไฟล์ไม่ถูกต้อง', Colors.red);
        setState(() { _isLoading = false; });
        return;
      }

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['email'] = widget.userEmail;
      request.files.add(await http.MultipartFile.fromPath(
        'profile_image', // ต้องตรงกับชื่อใน $_FILES ใน PHP
        pickedFile.path,
      ));

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final responseData = jsonDecode(responseBody);
        if (responseData['success']) {
          // API คืน URL เต็มมาให้แล้ว (image_url คือ URL เต็ม)
          final String? newFullImageUrl = responseData['image_url'] as String?;
          print('[DEBUG] upload success: fullImageUrl=$newFullImageUrl');

          if (newFullImageUrl != null) {
            final String fileName = Uri.parse(newFullImageUrl).pathSegments.last; // แยกเอาแค่ชื่อไฟล์

            setState(() {
              _displayUserImgFileName = fileName; // เก็บแค่ชื่อไฟล์
              _displayUserImgUrl = newFullImageUrl; // ใช้ URL เต็มที่ได้มาในการแสดงผล
            });
            // บันทึกแค่ชื่อไฟล์ลง SharedPreferences ด้วยคีย์ 'user_img'
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_img', fileName);
            // ถ้าคุณยังต้องการเก็บ URL เต็มไว้ด้วย (ไม่จำเป็นถ้าใช้ getProfileImageUrl)
            // await prefs.setString('user_img_url', newFullImageUrl); 
            print('[DEBUG] set user_img in prefs: $fileName');
          }
          _showSnackBar(responseData['message'] ?? 'อัปโหลดรูปโปรไฟล์สำเร็จ', Colors.green);
        } else {
          _showSnackBar(responseData['message'] ?? 'เกิดข้อผิดพลาดในการอัปโหลดรูปโปรไฟล์', Colors.red);
        }
      } else {
        _showSnackBar('เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์: ${response.statusCode}', Colors.red);
        print('[DEBUG] upload_profile_image error status: ${response.statusCode}');
        print('[DEBUG] upload_profile_image response: $responseBody');
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการอัปโหลด: $e', Colors.red);
      print('[DEBUG] upload_profile_image catch error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ฟังก์ชันสำหรับอัปเดตข้อมูลโปรไฟล์ (ชื่อและ/หรือรหัสผ่าน)
  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });

    // ตรวจสอบเงื่อนไขการเปลี่ยนรหัสผ่าน
    if (_isPasswordChange) {
      if (_currentPasswordController.text.isEmpty ||
          _newPasswordController.text.isEmpty ||
          _confirmNewPasswordController.text.isEmpty) {
        _showSnackBar('กรุณากรอกรหัสผ่านปัจจุบัน รหัสผ่านใหม่ และยืนยันรหัสผ่านใหม่', Colors.orange);
        setState(() { _isLoading = false; });
        return;
      }
      if (_newPasswordController.text != _confirmNewPasswordController.text) {
        _showSnackBar('รหัสผ่านใหม่และการยืนยันไม่ตรงกัน', Colors.orange);
        setState(() { _isLoading = false; });
        return;
      }
    }

    final apiUrl = dotenv.env['API_URL_UPDATE_PROFILE'];
    if (apiUrl == null || apiUrl.isEmpty) {
      _showSnackBar('API URL สำหรับอัปเดตโปรไฟล์ไม่ถูกต้อง', Colors.red);
      setState(() { _isLoading = false; });
      return;
    }

    Map<String, dynamic> data = {
      'email': widget.userEmail,
      'name': _nameController.text,
    };

    if (_isPasswordChange) {
      data['current_password'] = _currentPasswordController.text;
      data['new_password'] = _newPasswordController.text;
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      final responseData = jsonDecode(response.body);
      print('[DEBUG] Update Profile Response Status: ${response.statusCode}');
      print('[DEBUG] Update Profile Response Body: $responseData');

      if (response.statusCode == 200 && responseData['success']) {
        _showSnackBar(responseData['message'] ?? 'ข้อมูลโปรไฟล์อัปเดตสำเร็จ', Colors.green);
        // อัปเดตชื่อผู้ใช้ใน SharedPreferences หลังจากอัปเดตสำเร็จ
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', _nameController.text);
        print('[DEBUG] set user_name in prefs: ${_nameController.text}');

        // ล้างฟิลด์รหัสผ่านหลังจากอัปเดตสำเร็จ
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmNewPasswordController.clear();
        setState(() {
          _isPasswordChange = false; // รีเซ็ตสถานะการเปลี่ยนรหัสผ่าน
        });
      } else {
        _showSnackBar(responseData['message'] ?? 'เกิดข้อผิดพลาดในการอัปเดตข้อมูล', Colors.red);
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e', Colors.red);
      print('[DEBUG] Update Profile catch error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ฟังก์ชันสำหรับแสดง SnackBar
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'แก้ไขโปรไฟล์',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickAndUploadImage, // เรียกฟังก์ชันอัปโหลดเมื่อแตะรูป
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _displayUserImgUrl != null && _displayUserImgUrl!.isNotEmpty
                        ? NetworkImage(_displayUserImgUrl!) // ใช้ URL ที่สร้างขึ้น
                        : null,
                    child: _displayUserImgUrl == null || _displayUserImgUrl!.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey.shade700,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.blue.shade700,
                      radius: 20,
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'ชื่อผู้ใช้',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _isPasswordChange,
                  onChanged: (bool? value) {
                    setState(() {
                      _isPasswordChange = value ?? false;
                      if (!_isPasswordChange) {
                        _currentPasswordController.clear();
                        _newPasswordController.clear();
                        _confirmNewPasswordController.clear();
                      }
                    });
                  },
                ),
                const Text('เปลี่ยนรหัสผ่าน'),
              ],
            ),
            if (_isPasswordChange) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่านปัจจุบัน',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่านใหม่',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmNewPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'ยืนยันรหัสผ่านใหม่',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : _updateProfile,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'บันทึกการเปลี่ยนแปลง',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}