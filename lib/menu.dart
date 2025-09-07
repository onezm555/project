import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'package:http/http.dart' as http; // เพิ่ม http import
import 'dart:convert'; // เพิ่ม dart:convert import
import 'package:flutter_dotenv/flutter_dotenv.dart'; // เพิ่ม dotenv import
import 'login.dart';
import 'expired_items.dart';
import 'profile_edit_page.dart'; // ตรวจสอบว่าไฟล์นี้อยู่ใน path ที่ถูกต้อง
import 'statistics_page.dart'; // ตรวจสอบว่าไฟล์นี้อยู่ใน path ที่ถูกต้อง
import 'about_app_page.dart'; // เพิ่ม import หน้าเกี่ยวกับแอป
class MenuPage extends StatefulWidget {
  // เปลี่ยนเป็น StatefulWidget เพื่อโหลดข้อมูล
  const MenuPage({Key? key}) : super(key: key);

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String _userEmail = '';
  String _userName = 'กำลังโหลด...'; // ค่าเริ่มต้นขณะโหลด
  String? _userImgUrl; // เพิ่มตัวแปรสำหรับ URL รูปภาพ
  bool _isLoading = true; // เพิ่มตัวแปรสำหรับสถานะการโหลด
  
  // เพิ่มตัวแปรสำหรับ API
  final String _apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project/';

  @override
  void initState() {
    super.initState();
    print('API Base URL: $_apiBaseUrl'); // Debug เพิ่ม
    _loadUserData(); // เรียกฟังก์ชันโหลดข้อมูลผู้ใช้เมื่อ Widget ถูกสร้าง
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // โหลดข้อมูลใหม่เมื่อหน้านี้กลับมาแสดง
    if (!_isLoading) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      print('Loading user data...'); // Debug
      setState(() {
        _isLoading = true;
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // ดึง user_id สำหรับเรียก API
      final int? userIdInt = prefs.getInt('user_id');
      String? userId;
      if (userIdInt != null) {
        userId = userIdInt.toString();
      }

      if (userId == null || userId.isEmpty) {
        // ถ้าไม่มี user_id ให้โหลดจาก SharedPreferences เฉยๆ
        String? email = prefs.getString('saved_email');
        String? name = prefs.getString('user_name');
        String? imgUrl = prefs.getString('user_img');
        
        print('No user_id found, using cached data: email=$email, name=$name, imgUrl=$imgUrl'); // Debug
        
        if (mounted) {
          setState(() {
            _userEmail = email ?? 'ไม่พบอีเมล';
            _userName = name ?? 'กรุณากรอกชื่อของคุณ';
            _userImgUrl = imgUrl;
            _isLoading = false;
          });
        }
        return;
      }

      // เรียก API เพื่อดึงข้อมูลล่าสุด
      final apiUrl = _apiBaseUrl.endsWith('/') 
          ? '${_apiBaseUrl}get_user_data.php' 
          : '$_apiBaseUrl/get_user_data.php';
      print('Calling API: $apiUrl'); // Debug เพิ่ม
      
      final url = Uri.parse(apiUrl);
      final response = await http.post(url, body: {'user_id': userId});

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Full API Response: $responseData'); // Debug เพิ่ม
        
        if (responseData['status'] == 'success') {
          final userData = responseData['user'];
          print('userData: $userData'); // Debug เพิ่ม
          
          // อัพเดท SharedPreferences ด้วยข้อมูลใหม่
          await prefs.setString('user_name', userData['name'] ?? '');
          await prefs.setString('saved_email', userData['email'] ?? '');
          if (userData['user_img_full_url'] != null && userData['user_img_full_url'].toString().isNotEmpty) {
            print('Saving user_img to SharedPreferences: ${userData['user_img_full_url']}'); // Debug เพิ่ม
            await prefs.setString('user_img', userData['user_img_full_url']);
          } else {
            print('Removing user_img from SharedPreferences'); // Debug เพิ่ม
            await prefs.remove('user_img');
          }

          print('API data loaded: email=${userData['email']}, name=${userData['name']}, imgUrl=${userData['user_img_full_url']}'); // Debug

          if (mounted) {
            setState(() {
              _userEmail = userData['email'] ?? 'ไม่พบอีเมล';
              _userName = userData['name'] ?? 'กรุณากรอกชื่อของคุณ';
              _userImgUrl = userData['user_img_full_url'];
              _isLoading = false;
            });
          }
        } else {
          // API ล้มเหลว ใช้ข้อมูลจาก SharedPreferences
          await _loadFromSharedPreferences(prefs);
        }
      } else {
        // Server error ใช้ข้อมูลจาก SharedPreferences
        await _loadFromSharedPreferences(prefs);
      }
    } catch (e) {
      print('Error loading user data: $e'); // Debug
      // Error เกิดขึ้น ใช้ข้อมูลจาก SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await _loadFromSharedPreferences(prefs);
    }
  }

  Future<void> _loadFromSharedPreferences(SharedPreferences prefs) async {
    String? email = prefs.getString('saved_email');
    String? name = prefs.getString('user_name');
    String? imgUrl = prefs.getString('user_img');

    print('Loading from SharedPreferences: email=$email, name=$name, imgUrl=$imgUrl'); // Debug

    if (mounted) {
      setState(() {
        _userEmail = email ?? 'ไม่พบอีเมล';
        _userName = name ?? 'กรุณากรอกชื่อของคุณ';
        _userImgUrl = imgUrl;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
          // Profile Card Section
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isLoading 
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: _userImgUrl != null && _userImgUrl!.isNotEmpty
                              ? Image.network(
                                  _userImgUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Colors.white,
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: const TextStyle(
                                fontSize: 24, // เพิ่มจาก 18 เป็น 24
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userEmail,
                              style: TextStyle(
                                fontSize: 16, // เพิ่มจาก 14 เป็น 16
                                color: Colors.white.withOpacity(0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          
          // Menu Items Section
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                ModernMenuItem(
                  icon: Icons.person_outline,
                  title: 'โปรไฟล์ผู้ใช้',
                  subtitle: 'จัดการข้อมูลส่วนตัว',
                  iconColor: const Color(0xFF4A90E2),
                  onTap: () async {
                    print('Navigating to profile edit...'); // Debug
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileEditPage(
                          userEmail: _userEmail,
                          userName: _userName,
                        ),
                      ),
                    );
                    // รีเฟรชข้อมูลเสมอเมื่อกลับมา
                    print("Returned from profile, result: $result"); // Debug
                    print("Reloading user data..."); // Debug
                    await _loadUserData();
                  },
                ),
                const Divider(height: 1, indent: 56),
                ModernMenuItem(
                  icon: Icons.history,
                  title: 'ประวัติรายการ',
                  subtitle: 'สิ่งของที่หมดอายุ/ใช้หมดแล้ว',
                  iconColor: const Color(0xFFFF9800),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ExpiredItemsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ModernMenuItem(
                  icon: Icons.bar_chart,
                  title: 'สถิติ',
                  subtitle: 'ข้อมูลการใช้งาน',
                  iconColor: const Color(0xFF4CAF50),
                  onTap: () {
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StatisticsPage(),
                        ),
                      );
                    } catch (e) {
                      print('Error navigating to statistics: $e');
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                ModernMenuItem(
                  icon: Icons.info_outline,
                  title: 'เกี่ยวกับแอปพลิเคชัน',
                  subtitle: 'ข้อมูลและเวอร์ชันแอปพลิเคชัน',
                  iconColor: const Color(0xFF9C27B0),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutAppPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Logout Section
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ModernMenuItem(
              icon: Icons.logout,
              title: 'ออกจากระบบ',
              subtitle: 'ออกจากบัญชีของคุณ',
              iconColor: Colors.red,
              isLogout: true,
              onTap: () async {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'ยืนยันการออกจากระบบ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 20, // เพิ่มขนาดให้ dialog title
                      ),
                    ),
                    content: const Text(
                      'คุณต้องการออกจากระบบหรือไม่?',
                      style: TextStyle(fontSize: 16), // เพิ่มขนาดให้ dialog content
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'ยกเลิก',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16, // เพิ่มขนาดปุ่ม
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          await prefs.remove('user_id');
                          await prefs.remove('saved_email');
                          await prefs.remove('saved_password');
                          await prefs.remove('user_name');
                          await prefs.remove('user_img');

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'ออกจากระบบ',
                          style: TextStyle(fontSize: 16), // เพิ่มขนาดปุ่ม
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }
}

class ModernMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool isLogout;

  const ModernMenuItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    this.onTap,
    this.isLogout = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20, // เพิ่มจาก 16 เป็น 20
                      fontWeight: FontWeight.w500,
                      color: isLogout ? Colors.red : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 16, // เพิ่มจาก 13 เป็น 16
                      color: isLogout ? Colors.red.withOpacity(0.7) : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

class MenuItem extends StatelessWidget {
  final IconData icon;
  final String title; // ตัวแปร title ถูกต้องแล้ว
  final VoidCallback? onTap;
  final bool isLogout;

  const MenuItem({
    Key? key,
    required this.icon,
    required this.title,
    this.onTap,
    this.isLogout = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = isLogout ? Colors.red : Colors.black87;

    return Column(
      children: [
        ListTile(
          leading: Icon(icon, size: 26, color: color),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 20, // เพิ่มจาก 16 เป็น 20
              fontWeight: FontWeight.w400,
              color: color,
            ),
          ),
          onTap: onTap,
        ),
        const Divider(height: 1, color: Colors.grey),
      ],
    );
  }
}
