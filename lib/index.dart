/**
 * @fileoverview หน้าแรกของแอปพลิเคชัน
 * 
 * รายละเอียดทั่วไป:
 * - หน้าแรกที่แสดงรายการสินค้าที่เก็บไว้
 * - แสดงรูป ชื่อสินค้า จำนวน วันหมดอายุ และสถานที่เก็บ
 * - ไม่มี AppBar หรือ Bottom Navigation (จัดการโดย MainLayout)
 * - เป็นส่วนหนึ่งของ MainLayout
 * 
 * การอัปเดต:
 * - 06/06/2025: แยกหน้าแรกออกมาเป็นไฟล์แยก
 * - 06/06/2025: แก้ไขให้แสดงรายการสินค้าตามรูปแบบใหม่
 */

import 'package:flutter/material.dart';

class IndexPage extends StatefulWidget {
  const IndexPage({Key? key}) : super(key: key);

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  // รายการสินค้าที่เก็บไว้
  List<Map<String, dynamic>> _stored_items = [
    {
      'id': 1,
      'name': 'เกลือ ปรุงกิฟฟี่ เสริมไอโอดีน',
      'image': 'lib/img/salt.png',
      'quantity': 1,
      'unit': 'ชิ้น',
      'expire_date': '2025-12-15',
      'storage_location': 'ตู้กับข้าว',
      'days_left': 187,
    },
    {
      'id': 2,
      'name': 'พริกไทยป่น เฮมเพพ',
      'image': 'lib/img/pepper.png',
      'quantity': 1,
      'unit': 'ชิ้น',
      'expire_date': '2025-07-30',
      'storage_location': 'ตู้กับข้าว',
      'days_left': 48,
    },
    {
      'id': 3,
      'name': 'เคลอร์ แมนพุ แอมมิเนตเดนอร์พี',
      'image': 'lib/img/cleaner.png',
      'quantity': 1,
      'unit': 'ชิ้น',
      'expire_date': '2025-06-18',
      'storage_location': 'ตู้ก้นครอบ',
      'days_left': 6,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _stored_items.isEmpty ? _build_empty_state() : _build_items_list(),
    );
  }

  // Widget สำหรับแสดงเมื่อไม่มีข้อมูล
  Widget _build_empty_state() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'ไม่พบการเก็บวันหมดอายุของคุณ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'เริ่มต้นเพิ่มสินค้าแรกของคุณ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Widget สำหรับแสดงรายการสินค้า
  Widget _build_items_list() {
    return RefreshIndicator(
      onRefresh: _refresh_data,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _stored_items.length,
        itemBuilder: (context, index) {
          final item = _stored_items[index];
          return _build_item_card(item, index);
        },
      ),
    );
  }

  // Widget สำหรับการ์ดสินค้า
  Widget _build_item_card(Map<String, dynamic> item, int index) {
  final days_left = item['days_left'] as int;
  Color status_color = Colors.green;
  String status_text = 'อยู่ที่${item['storage_location']}';

  if (days_left < 0) {
    status_color = Colors.red;
    status_text = 'หมดอายุแล้ว';
  } else if (days_left <= 7) {
    status_color = Colors.orange;
    status_text = 'ใกล้หมดอายุ';
  } else {
    status_color = Colors.green;
    status_text = 'อยู่ที่${item['storage_location']}';
  }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // รูปสินค้า
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                item['image'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // ถ้าโหลดรูปไม่ได้ จะแสดงไอคอนแทน
                  return Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.inventory_2,
                      color: Colors.grey,
                      size: 30,
                    ),
                  );
                },
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // ข้อมูลสินค้า
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ชื่อสินค้า
                Text(
                  item['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 4),
                
                // จำนวนที่เก็บ
                Text(
                  'จำนวน ${item['quantity']} ${item['unit']}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // วันหมดอายุ
                Text(
                  _format_expire_date(item['expire_date'], days_left),
                  style: TextStyle(
                    fontSize: 12,
                    color: days_left <= 7 ? Colors.orange : Colors.grey,
                    fontWeight: days_left <= 7 ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          
          // สถานะและสถานที่เก็บ
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // สถานะ (แสดงสถานที่เก็บหรือสถานะหมดอายุ)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: status_color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: status_color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  status_text,
                  style: TextStyle(
                    fontSize: 10,
                    color: status_color,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันจัดรูปแบบวันหมดอายุ
  String _format_expire_date(String expire_date, int days_left) {
    if (days_left < 0) {
      return 'หมดอายุแล้ว ${days_left.abs()} วัน';
    } else if (days_left == 0) {
      return 'หมดอายุวันนี้';
    } else if (days_left == 1) {
      return 'หมดอายุพรุ่งนี้';
    } else if (days_left <= 30) {
      return 'หมดอายุอีก $days_left วัน';
    } else {
      // แสดงวันที่จริง
      try {
        final date = DateTime.parse(expire_date);
        final months = [
          '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
          'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
        ];
        return 'หมดอายุ ${date.day} ${months[date.month]} ${date.year + 543}';
      } catch (e) {
        return 'หมดอายุ $expire_date';
      }
    }
  }

  // ฟังก์ชันสำหรับรีเฟรชข้อมูล
  Future<void> _refresh_data() async {
    await Future.delayed(const Duration(seconds: 1));
    // TODO: เพิ่มการโหลดข้อมูลจาก API หรือ Database
    setState(() {
      // อัปเดตข้อมูลถ้าจำเป็น
    });
  }
}