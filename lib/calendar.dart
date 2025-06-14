/**
 * @fileoverview หน้าปฏิทินของแอปพลิเคชัน
 * 
 * รายละเอียดทั่วไป:
 * - หน้าแสดงปฏิทิน 12 เดือนในปีเดียว
 * - สามารถเลือกปีได้
 * - แสดงสีในวันที่มีสินค้าหมดอายุ
 * - มีฟิลเตอร์แสดง/ซ่อนเดือนที่มีหมดอายุ
 * - ไม่มี AppBar หรือ Bottom Navigation (จัดการโดย MainLayout)
 * 
 * การอัปเดต:
 * - 06/06/2025: สร้างหน้าปฏิทินแบบใหม่
 */

import 'package:flutter/material.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  int _selected_year = DateTime.now().year;
  bool _show_only_expiry_months = false;

  // ข้อมูลสินค้าตัวอย่าง (ควรได้มาจาก shared state หรือ database จริงๆ)
  final Map<String, List<String>> _expiry_dates = {
    '2025-06-02': ['นมสด'],
    '2025-06-18': ['เคลอร์ แมนพุ'],
    '2025-07-30': ['พริกไทยป่น'],
    '2025-12-15': ['เกลือ ปรุงกิฟฟี่'],
  };

  final List<String> _month_names = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
  ];

  final List<String> _day_names = ['อ', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ส่วนหัวเลือกปีและฟิลเตอร์
        _build_header(),
        
        // รายการปฏิทิน 12 เดือน
        Expanded(
          child: _build_calendar_grid(),
        ),
      ],
    );
  }

  // Widget ส่วนหัว
  Widget _build_header() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // เลือกปี
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selected_year--;
                  });
                },
                icon: const Icon(Icons.chevron_left),
              ),
              
              Text(
                '$_selected_year',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              IconButton(
                onPressed: () {
                  setState(() {
                    _selected_year++;
                  });
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // ฟิลเตอร์
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.filter_alt,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                'แสดงเดือนที่มีวันหมดอายุ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Switch(
                value: _show_only_expiry_months,
                onChanged: (value) {
                  setState(() {
                    _show_only_expiry_months = value;
                  });
                },
                activeColor: const Color(0xFF4A90E2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget กริดปฏิทิน 12 เดือน
  Widget _build_calendar_grid() {
    List<int> months_to_show = [];
    
    if (_show_only_expiry_months) {
      // แสดงเฉพาะเดือนที่มีสินค้าหมดอายุ
      Set<int> expiry_months = {};
      _expiry_dates.keys.forEach((date) {
        final parsed_date = DateTime.parse(date);
        if (parsed_date.year == _selected_year) {
          expiry_months.add(parsed_date.month);
        }
      });
      months_to_show = expiry_months.toList()..sort();
    } else {
      // แสดงทุกเดือน
      months_to_show = List.generate(12, (index) => index + 1);
    }

    if (months_to_show.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'ไม่มีสินค้าหมดอายุในปีนี้',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1, // แสดงทีละเดือน (เหมือนรูป)
        childAspectRatio: 1.2,
        mainAxisSpacing: 20,
      ),
      itemCount: months_to_show.length,
      itemBuilder: (context, index) {
        return _build_month_calendar(months_to_show[index]);
      },
    );
  }

  // Widget ปฏิทินของแต่ละเดือน
  Widget _build_month_calendar(int month) {
    final first_day = DateTime(_selected_year, month, 1);
    final last_day = DateTime(_selected_year, month + 1, 0);
    final days_in_month = last_day.day;
    final start_weekday = first_day.weekday % 7; // 0 = อาทิตย์

    return Container(
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
      child: Column(
        children: [
          // ชื่อเดือน
          Text(
            _month_names[month - 1],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // หัวตารางวัน
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _day_names.map((day) => 
              Expanded(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ).toList(),
          ),
          
          const SizedBox(height: 8),
          
          // ตารางวันที่
          Expanded(
            child: _build_days_grid(month, days_in_month, start_weekday),
          ),
        ],
      ),
    );
  }

  // Widget กริดวันที่ในเดือน
  Widget _build_days_grid(int month, int days_in_month, int start_weekday) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: 42, // 6 สัปดาห์ x 7 วัน
      itemBuilder: (context, index) {
        final day_number = index - start_weekday + 1;
        
        if (day_number < 1 || day_number > days_in_month) {
          return const SizedBox(); // วันว่าง
        }
        
        final date_string = '$_selected_year-${month.toString().padLeft(2, '0')}-${day_number.toString().padLeft(2, '0')}';
        final has_expiry = _expiry_dates.containsKey(date_string);
        
        Color? background_color;
        Color text_color = Colors.black87;
        
        if (has_expiry) {
          background_color = const Color(0xFF4A90E2); // สีน้ำเงินเหมือน theme หลัก
          text_color = Colors.white;
        }
        
        return GestureDetector(
          onTap: has_expiry ? () => _show_expiry_details(date_string) : null,
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: background_color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: has_expiry ? Colors.transparent : Colors.transparent,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                '$day_number',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: has_expiry ? FontWeight.bold : FontWeight.normal,
                  color: text_color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // แสดงรายละเอียดสินค้าที่หมดอายุในวันนั้น
  void _show_expiry_details(String date) {
    final items = _expiry_dates[date] ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('สินค้าหมดอายุ\n${_format_thai_date(date)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) => 
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A90E2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  // แปลงวันที่เป็นภาษาไทย
  String _format_thai_date(String date) {
    final parsed_date = DateTime.parse(date);
    return '${parsed_date.day} ${_month_names[parsed_date.month - 1]} ${parsed_date.year + 543}';
  }
}