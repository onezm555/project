import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:image_picker/image_picker.dart';

class ProfileEditPage extends StatefulWidget {
  final String userEmail;
  final String userName;

  const ProfileEditPage({
    Key? key,
    required this.userEmail,
    required this.userName,
  }) : super(key: key);

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final ImagePicker _picker = ImagePicker();
Future<void> _pickAndUploadImage() async {
  print('เริ่มเลือกและอัปโหลดรูปภาพ');
  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
  if (image == null) {
    print('ไม่ได้เลือกรูปภาพ');
    return;
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();
  final int? userIdInt = prefs.getInt('user_id');
  print('userIdInt: $userIdInt');
  String? userId;
  if (userIdInt != null) {
    userId = userIdInt.toString();
  }
  print('userId: $userId');
  if (userId == null || userId.isEmpty) {
    _showSnackBar('ไม่พบ ID ผู้ใช้', Colors.red);
    print('ไม่พบ user_id ใน SharedPreferences');
    return;
  }

  final url = Uri.parse('${_apiBaseUrl}upload_profile_image.php');
  try {
    var request = http.MultipartRequest('POST', url);
    request.fields['user_id'] = userId;
    request.files.add(await http.MultipartFile.fromPath('profile_image', image.path));
    print('ส่ง request ไปยัง $url');
    var response = await request.send();
    print('response.statusCode: ${response.statusCode}');
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      print('response body: $respStr');
      final respData = json.decode(respStr);
      if (respData['status'] == 'success') {
        // เพิ่ม query string timestamp เพื่อป้องกัน cache
        final String newImgUrl = '${respData['user_img_full_url']}?t=${DateTime.now().millisecondsSinceEpoch}';
        setState(() {
          _userImgUrl = newImgUrl;
        });
        await prefs.setString('user_img', newImgUrl);
        _showSnackBar('อัปโหลดรูปโปรไฟล์สำเร็จ', Colors.green);
      } else {
        _showSnackBar(respData['message'] ?? 'อัปโหลดรูปไม่สำเร็จ', Colors.red);
      }
    } else {
      _showSnackBar('เกิดข้อผิดพลาดในการอัปโหลดรูป (${response.statusCode})', Colors.red);
    }
  } catch (e) {
    _showSnackBar('เกิดข้อผิดพลาด: $e', Colors.red);
    print('เกิดข้อผิดพลาด: $e');
  }
}
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();

  String _currentUserName = '';
  String? _userImgUrl;
  bool _isLoading = true; // To show loading state for profile image/name
  // ดึงค่า API_BASE_URL จาก .env หากไม่พบให้ใช้ค่า fallback
  final String _apiBaseUrl =
      dotenv.env['API_BASE_URL'] ?? 'http://localhost/project/';

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
    _nameController.text = widget.userName;
    _fetchUserData(); // เรียกฟังก์ชันดึงข้อมูลผู้ใช้เมื่อ Widget ถูกสร้าง
  }

  Future<void> _fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // *** การแก้ไขสำหรับวิธีที่ 2: ดึง user_id เป็น int แล้วแปลงเป็น String ***
    final int? userIdInt = prefs.getInt('user_id'); // พยายามดึงเป็น int
    String? userId;
    if (userIdInt != null) {
      userId = userIdInt.toString(); // ถ้าดึงได้ ให้แปลงเป็น String
    }
    // *******************************************************************

    if (userId == null || userId.isEmpty) {
      // ตรวจสอบว่า userId มีค่าหรือไม่
      print('User ID not found in SharedPreferences or is empty.');
      setState(() {
        _isLoading = false; // หยุดโหลดแม้ไม่มี userId
      });
      return;
    }

    final url = Uri.parse(
      '${_apiBaseUrl}get_user_data.php',
    ); // URL ของ API ดึงข้อมูลผู้ใช้

    try {
      final response = await http.post(
        url,
        body: {
          'user_id': userId, // ใช้ userId ที่เป็น String
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          final userData = responseData['user'];
          setState(() {
            _currentUserName = userData['name'] ?? 'ไม่ระบุชื่อ';
            _nameController.text =
                _currentUserName; // อัปเดต Controller ด้วยชื่อล่าสุด
            _userImgUrl = userData['user_img_full_url']; // ใช้ full URL
            _isLoading = false;
          });
          // อัปเดต SharedPreferences ด้วยข้อมูลใหม่ที่ได้มา
          await prefs.setString('user_name', userData['name'] ?? '');
          if (userData['user_img_full_url'] != null) {
            await prefs.setString('user_img', userData['user_img_full_url']);
          } else {
            await prefs.remove('user_img'); // ถ้าไม่มีรูป ก็ลบออกจาก prefs
          }
        } else {
          print('Failed to fetch user data: ${responseData['message']}');
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        print('Server error: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error connecting to API: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    final newName = _nameController.text.trim();
    print('[DEBUG] _updateProfile: newName = $newName');
    if (newName.isEmpty) {
      _showSnackBar('ชื่อผู้ใช้ไม่สามารถเว้นว่างได้', Colors.red);
      print('[DEBUG] _updateProfile: ชื่อผู้ใช้ว่าง');
      return;
    }

    if (newName == _currentUserName) {
      _showSnackBar('ไม่มีการเปลี่ยนแปลงชื่อผู้ใช้', Colors.orange);
      print('[DEBUG] _updateProfile: ไม่มีการเปลี่ยนแปลงชื่อ');
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? userIdInt = prefs.getInt('user_id');
    String? userId;
    if (userIdInt != null) {
      userId = userIdInt.toString();
    }

    print('[DEBUG] _updateProfile: userId = $userId');
    if (userId == null || userId.isEmpty) {
      _showSnackBar('ไม่พบ ID ผู้ใช้', Colors.red);
      print('[DEBUG] _updateProfile: ไม่พบ user_id');
      return;
    }

    final url = Uri.parse('${_apiBaseUrl}update_profile.php');
    print('[DEBUG] _updateProfile: url = $url');
    try {
      final response = await http.post(
        url,
        body: {
          'user_id': userId,
          'user_name': newName,
        },
      );
      print('[DEBUG] _updateProfile: response.statusCode = \\${response.statusCode}');
      print('[DEBUG] _updateProfile: response.body = \\${response.body}');
      final responseData = json.decode(response.body);
      if (responseData['success'] == true || responseData['status'] == 'success') {
        await prefs.setString('user_name', newName);
        setState(() {
          _currentUserName = newName;
        });
        _showSnackBar('อัปเดตโปรไฟล์สำเร็จ', Colors.green);
        Navigator.pop(context, true);
      } else {
        _showSnackBar(
          responseData['message'] ?? 'เกิดข้อผิดพลาดในการอัปเดตโปรไฟล์',
          Colors.red,
        );
        print('[DEBUG] _updateProfile: error = \\${responseData['message']}');
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e', Colors.red);
      print('[DEBUG] _updateProfile: exception = $e');
    }
  }

  Future<void> _changePassword() async {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmNewPassword = _confirmNewPasswordController.text;
    print('[DEBUG] _changePassword: oldPassword = $oldPassword, newPassword = $newPassword, confirmNewPassword = $confirmNewPassword');

    if (oldPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmNewPassword.isEmpty) {
      _showSnackBar('กรุณากรอกข้อมูลรหัสผ่านให้ครบถ้วน', Colors.red);
      print('[DEBUG] _changePassword: มีช่องว่าง');
      return;
    }

    if (newPassword != confirmNewPassword) {
      _showSnackBar('รหัสผ่านใหม่ไม่ตรงกัน', Colors.red);
      print('[DEBUG] _changePassword: รหัสผ่านใหม่ไม่ตรงกัน');
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar('รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร', Colors.red);
      print('[DEBUG] _changePassword: รหัสผ่านใหม่สั้น');
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? userIdInt = prefs.getInt('user_id');
    String? userId;
    if (userIdInt != null) {
      userId = userIdInt.toString();
    }
    print('[DEBUG] _changePassword: userId = $userId');
    if (userId == null || userId.isEmpty) {
      _showSnackBar('ไม่พบ ID ผู้ใช้', Colors.red);
      print('[DEBUG] _changePassword: ไม่พบ user_id');
      return;
    }

    final url = Uri.parse('${_apiBaseUrl}upload_profile_image.php');
    print('[DEBUG] _changePassword: url = $url');
    try {
      var request = http.MultipartRequest('POST', url);
      request.fields['user_id'] = userId;
      request.fields['old_password'] = oldPassword;
      request.fields['password'] = newPassword;
      // ไม่ต้องแนบไฟล์ profile_image ถ้าไม่เปลี่ยนรูป

      print('[DEBUG] _changePassword: sending fields = ' + request.fields.toString());
      var streamedResponse = await request.send();
      print('[DEBUG] _changePassword: response.statusCode = ${streamedResponse.statusCode}');
      final respStr = await streamedResponse.stream.bytesToString();
      print('[DEBUG] _changePassword: response.body = $respStr');
      final responseData = json.decode(respStr);
      if (responseData['status'] == 'success') {
        _showSnackBar('เปลี่ยนรหัสผ่านสำเร็จ', Colors.green);
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmNewPasswordController.clear();
      } else {
        _showSnackBar(
          responseData['message'] ?? 'เกิดข้อผิดพลาดในการเปลี่ยนรหัสผ่าน',
          Colors.red,
        );
        print('[DEBUG] _changePassword: error = ${responseData['message']}');
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e', Colors.red);
      print('[DEBUG] _changePassword: exception = $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            Navigator.pop(context, false);
          },
        ),
        title: const Text(
          'โปรไฟล์ผู้ใช้',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _isLoading
                  ? const CircularProgressIndicator() // แสดง Indicator ขณะโหลด
                  : GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                            (_userImgUrl != null && _userImgUrl!.isNotEmpty)
                            ? NetworkImage(_userImgUrl!)
                            : null,
                        child: (_userImgUrl == null || _userImgUrl!.isEmpty)
                            ? Icon(
                                Icons.person,
                                size: 80,
                                color: Colors.grey[600],
                              )
                            : null,
                      ),
                    ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _currentUserName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.black54),
                      onPressed: () {
                        _nameController.text = _currentUserName;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text(
                              'แก้ไขชื่อผู้ใช้',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            content: TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'ชื่อผู้ใช้',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('ยกเลิก'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _updateProfile();
                                },
                                child: const Text('บันทึก'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'เปลี่ยนรหัสผ่าน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _oldPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่านเดิม',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่านใหม่',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_open),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _confirmNewPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'ยืนยันรหัสผ่านใหม่',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'เปลี่ยนรหัสผ่าน',
                    style: TextStyle(fontSize: 18, color: Colors.white),
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
