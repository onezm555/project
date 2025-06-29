import 'package:flutter/material.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  // ข้อมูลการแจ้งเตือน
  List<Map<String, dynamic>> _notifications = [
    {
      'id': 1,
      'type': 'today',
      'title': 'เกลือ ปรุงกิฟฟี่ เสริมไอโอดีน',
      'description': 'หมดอายุแล้ว',
      'date': 'วันหมดอายุ 21 ม.ค. 2025',
      'is_expired': true,
      'created_at': DateTime.now().subtract(const Duration(hours: 2)),
    },
    {
      'id': 2,
      'type': 'stored',
      'title': 'พริกไทยป่น เฮมเพพ',
      'description': 'จะหมดอายุในอีก 30 วัน',
      'date': 'วันหมดอายุ 21 ม.ค. 2025',
      'is_expired': false,
      'created_at': DateTime.now().subtract(const Duration(days: 1)),
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (_notifications.isEmpty) {
      return _build_empty_state();
    }

    return RefreshIndicator(
      onRefresh: _refresh_notifications,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._build_notification_sections(),
        ],
      ),
    );
  }

  // Widget สำหรับแสดงเมื่อไม่มีการแจ้งเตือน
  Widget _build_empty_state() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_outlined,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'ไม่มีการแจ้งเตือน',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'การแจ้งเตือนจะแสดงที่นี่',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // สร้างส่วนการแจ้งเตือนตามประเภท
  List<Widget> _build_notification_sections() {
    final today_notifications = _notifications.where((n) => n['type'] == 'today').toList();
    final stored_notifications = _notifications.where((n) => n['type'] == 'stored').toList();

    List<Widget> sections = [];

    // ส่วนวันนี้
    if (today_notifications.isNotEmpty) {
      sections.add(_build_section_header('วันนี้'));
      sections.addAll(
        today_notifications.map((notification) => 
          _build_notification_card(notification)
        ).toList(),
      );
      sections.add(const SizedBox(height: 24));
    }

    // ส่วนสินค้าที่เก็บ
    if (stored_notifications.isNotEmpty) {
      sections.add(_build_section_header('สินค้าที่เก็บ'));
      sections.addAll(
        stored_notifications.map((notification) => 
          _build_notification_card(notification)
        ).toList(),
      );
    }

    return sections;
  }

  // Widget หัวข้อส่วน
  Widget _build_section_header(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  // Widget การ์ดการแจ้งเตือน
  Widget _build_notification_card(Map<String, dynamic> notification) {
    final is_expired = notification['is_expired'] as bool;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ไอคอนสถานะ
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: is_expired ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              is_expired ? Icons.error_outline : Icons.warning_outlined,
              color: is_expired ? Colors.red : Colors.orange,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // ข้อมูลการแจ้งเตือน
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ชื่อสินค้า
                Text(
                  notification['title'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // รายละเอียด
                Text(
                  notification['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: is_expired ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // วันที่หมดอายุ
                Text(
                  notification['date'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          
          // ปุ่มลบ
          IconButton(
            onPressed: () => _delete_notification(notification['id']),
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.grey,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันลบการแจ้งเตือน
  void _delete_notification(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบการแจ้งเตือน'),
        content: const Text('คุณต้องการลบการแจ้งเตือนนี้หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _notifications.removeWhere((n) => n['id'] == id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ลบการแจ้งเตือนเรียบร้อยแล้ว'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'ลบ',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันรีเฟรชการแจ้งเตือน
  Future<void> _refresh_notifications() async {
    await Future.delayed(const Duration(seconds: 1));
    // TODO: เพิ่มการโหลดข้อมูลการแจ้งเตือนจาก API หรือ Database
    setState(() {
      // อัปเดตข้อมูลถ้าจำเป็น
    });
  }
}