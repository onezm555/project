/**
 * @fileoverview หน้าเมนูของแอปพลิเคชัน
 * 
 * รายละเอียดทั่วไป:
 * - หน้าแสดงเมนูต่างๆ ของแอป
 * - ไม่มี AppBar หรือ Bottom Navigation (จัดการโดย MainLayout)
 * - เป็นส่วนหนึ่งของ MainLayout
 * 
 * การอัปเดต:
 * - 06/06/2025: สร้างหน้าเมนู
 */

import 'package:flutter/material.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({Key? key}) : super(key: key);

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'เมนู',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'เมนูต่างๆ จะแสดงที่นี่',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}