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
  bool _isUploading = false; // เพิ่มตัวแปรสำหรับสถานะการอัปโหลด
  bool _isUpdatingProfile = false; // เพิ่มตัวแปรสำหรับสถานะการอัปเดตโปรไฟล์
  bool _isChangingPassword = false; // เพิ่มตัวแปรสำหรับสถานะการเปลี่ยนรหัสผ่าน
Future<void> _pickAndUploadImage() async {
  if (_isUploading) return; // ป้องกันการอัปโหลดซ้ำ
  
  print('เริ่มเลือกและอัปโหลดรูปภาพ');
  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
  if (image == null) {
    print('ไม่ได้เลือกรูปภาพ');
    return;
  }

  setState(() {
    _isUploading = true;
  });

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
    setState(() {
      _isUploading = false;
    });
    return;
  }

  final url = Uri.parse('${_apiBaseUrl.endsWith('/') ? _apiBaseUrl : '$_apiBaseUrl/'}upload_profile_image.php');
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
  } finally {
    setState(() {
      _isUploading = false;
    });
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
    print('ProfileEditPage API Base URL: $_apiBaseUrl'); // Debug เพิ่ม
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
      '${_apiBaseUrl.endsWith('/') ? _apiBaseUrl : '$_apiBaseUrl/'}get_user_data.php',
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
    if (_isUpdatingProfile) return; // ป้องกันการอัปเดตซ้ำ
    
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

    setState(() {
      _isUpdatingProfile = true;
    });

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
      setState(() {
        _isUpdatingProfile = false;
      });
      return;
    }

    final url = Uri.parse('${_apiBaseUrl.endsWith('/') ? _apiBaseUrl : '$_apiBaseUrl/'}update_profile.php');
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
    } finally {
      setState(() {
        _isUpdatingProfile = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (_isChangingPassword) return; // ป้องกันการเปลี่ยนรหัสผ่านซ้ำ
    
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

    setState(() {
      _isChangingPassword = true;
    });

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
      setState(() {
        _isChangingPassword = false;
      });
      return;
    }

    final url = Uri.parse('${_apiBaseUrl.endsWith('/') ? _apiBaseUrl : '$_apiBaseUrl/'}upload_profile_image.php');
    print('[DEBUG] _changePassword: url = $url');
    try {
      final response = await http.post(
        url,
        body: {
          'user_id': userId,
          'old_password': oldPassword,
          'password': newPassword,
        },
      );
      print('[DEBUG] _changePassword: response.statusCode = ${response.statusCode}');
      print('[DEBUG] _changePassword: response.body = ${response.body}');
      final responseData = json.decode(response.body);
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
    } finally {
      setState(() {
        _isChangingPassword = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
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
          borderSide: const BorderSide(color: Colors.orangeAccent, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        labelStyle: TextStyle(color: Colors.grey[600]),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        elevation: 2,
        shadowColor: Colors.grey.withOpacity(0.1),
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
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  children: [
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.3),
                                      spreadRadius: 2,
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 70,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: (_userImgUrl != null && _userImgUrl!.isNotEmpty)
                                      ? NetworkImage(_userImgUrl!)
                                      : null,
                                  child: (_userImgUrl == null || _userImgUrl!.isEmpty)
                                      ? Icon(
                                          Icons.person,
                                          size: 90,
                                          color: Colors.grey[400],
                                        )
                                      : null,
                                ),
                              ),
                              if (_isUploading)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _isUploading ? null : _pickAndUploadImage,
                                  child: Container(
                                    width: 45,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: _isUploading ? Colors.grey : Colors.blueAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.3),
                                          spreadRadius: 1,
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isUploading ? Icons.hourglass_empty : Icons.camera_alt,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentUserName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            _nameController.text = _currentUserName;
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                title: const Text(
                                  'แก้ไขชื่อผู้ใช้',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                content: TextField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'ชื่อผู้ใช้',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Colors.blueAccent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'ยกเลิก',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _isUpdatingProfile 
                                        ? null 
                                        : () {
                                            Navigator.pop(context);
                                            _updateProfile();
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isUpdatingProfile ? Colors.grey : Colors.blueAccent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: _isUpdatingProfile
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'บันทึก',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.blueAccent,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.userEmail,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Password Change Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.security,
                              color: Colors.orangeAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'เปลี่ยนรหัสผ่าน',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      _buildPasswordField(
                        controller: _oldPasswordController,
                        label: 'รหัสผ่านเดิม',
                        icon: Icons.lock_outline,
                      ),
                      const SizedBox(height: 20),
                      _buildPasswordField(
                        controller: _newPasswordController,
                        label: 'รหัสผ่านใหม่',
                        icon: Icons.lock_open,
                      ),
                      const SizedBox(height: 20),
                      _buildPasswordField(
                        controller: _confirmNewPasswordController,
                        label: 'ยืนยันรหัสผ่านใหม่',
                        icon: Icons.lock,
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isChangingPassword ? null : _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isChangingPassword ? Colors.grey : Colors.orangeAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _isChangingPassword ? 0 : 2,
                          ),
                          child: _isChangingPassword
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'เปลี่ยนรหัสผ่าน',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
