import 'package:flutter/material.dart';
import 'login.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const MenuItem(icon: Icons.person_outline, title: 'โปรไฟล์ผู้ใช้'),
          const MenuItem(icon: Icons.receipt_long_outlined, title: 'รายการที่หมดอายุ/ใช้หมดแล้ว'),
          const MenuItem(icon: Icons.history, title: 'สถิติ'),
          const MenuItem(icon: Icons.brightness_6_outlined, title: 'ธีมของแอป'),
          const MenuItem(icon: Icons.info_outline, title: 'เกี่ยวกับแอป'),

MenuItem(
  icon: Icons.logout,
  title: 'ออกจากระบบ',
  isLogout: true,
  onTap: () {
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
            onPressed: () {
              Navigator.pop(context);

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
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
  final String title;
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
