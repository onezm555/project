import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'login.dart';
import 'expired_items.dart';
import 'profile_edit_page.dart'; // ตรวจสอบว่าไฟล์นี้อยู่ใน path ที่ถูกต้อง
import 'statistics_page.dart'; // ตรวจสอบว่าไฟล์นี้อยู่ใน path ที่ถูกต้อง
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

  @override
  void initState() {
    super.initState();
    _loadUserData(); // เรียกฟังก์ชันโหลดข้อมูลผู้ใช้เมื่อ Widget ถูกสร้าง
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('saved_email'); // ดึง email
    String? name = prefs.getString('user_name'); // ดึงชื่อ
    String? imgUrl = prefs.getString('user_img'); // ดึง URL รูปภาพ

    setState(() {
      _userEmail = email ?? 'ไม่พบอีเมล';
      _userName = name ?? 'กรุณากรอกชื่อของคุณ'; // ใช้ fallback หากไม่พบชื่อ
      _userImgUrl = imgUrl; // กำหนด URL รูปภาพ
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ListView(
        children: [
          const SizedBox(height: 8),
          MenuItem(
            // ไม่ใช่ const แล้ว
            icon: Icons.person_outline,
            title: 'โปรไฟล์ผู้ใช้', // ส่ง title เข้าไป
            onTap: () async {
              // ทำให้เป็น async เพื่อรอผลลัพธ์จาก ProfileEditPage
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileEditPage(
                    userEmail: _userEmail, // ใช้อีเมลที่ดึงมา
                    userName: _userName, // ใช้ชื่อที่ดึงมา
                  ),
                ),
              );
              // หากกลับมาจาก ProfileEditPage และมีการอัปเดต (result == true)
              if (result == true) {
                print("Profile updated, reloading user data...");
                _loadUserData(); // โหลดข้อมูลผู้ใช้ใหม่เพื่ออัปเดต UI
              }
            },
          ),
          MenuItem(
            icon: Icons.receipt_long_outlined,
            title: 'รายการที่หมดอายุ/ใช้หมดแล้ว', // ส่ง title เข้าไป
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExpiredItemsPage(),
                ),
              );
            },
          ),
          // แก้ไขตรงนี้: เพิ่ม named parameter 'title' ให้กับ MenuItem ที่เป็น const
          MenuItem(
            icon: Icons.history,
            title: 'สถิติ',
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
          const MenuItem(icon: Icons.brightness_6_outlined, title: 'ธีมของแอป'),
          const MenuItem(icon: Icons.info_outline, title: 'เกี่ยวกับแอป'),

          MenuItem(
            icon: Icons.logout,
            title: 'ออกจากระบบ', // ส่ง title เข้าไป
            isLogout: true,
            onTap: () async {
              // ทำให้เป็น async เพื่อใช้ await กับ SharedPreferences
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('ยืนยันการออกจากระบบ'),
                  content: const Text('คุณต้องการออกจากระบบหรือไม่?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                    TextButton(
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
                      child: const Text('ออกจากระบบ'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
              fontSize: 16,
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
