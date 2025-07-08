// index.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'item_detail_page.dart'; // ตรวจสอบให้แน่ใจว่า import ถูกต้อง
import 'add_item.dart'; // เพิ่มบรรทัดนี้เพื่อให้สามารถใช้ AddItemPage ได้

class IndexPage extends StatefulWidget {
  const IndexPage({Key? key}) : super(key: key);

  @override
  // ทำให้ createState() คืนค่าเป็น IndexPageState (ไม่ใช่ _IndexPageState)
  State<IndexPage> createState() => IndexPageState();
}

// ทำให้คลาส State เป็น public โดยลบ underscore ออก
class IndexPageState extends State<IndexPage> {
  List<Map<String, dynamic>> _stored_items = [];
  bool _is_loading = true;
  String? _api_message;
  bool _is_true_error = false;
  String _api_base_url = '';
  // เพิ่มตัวแปรสำหรับเก็บสถานะฟิลเตอร์ปัจจุบัน
  Map<String, dynamic> _current_filters = {};

  @override
  void initState() {
    super.initState();
    _api_base_url = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project';
    // เรียกใช้ fetchItemsData โดยไม่มี filters ในการโหลดครั้งแรก
    fetchItemsData();
  }

  // เปลี่ยนชื่อฟังก์ชันเป็น public (จาก _fetch_items_data)
  Future<void> fetchItemsData({Map<String, dynamic>? filters}) async {
    setState(() {
      _is_loading = true;
      _api_message = null;
      _is_true_error = false;
      _current_filters = filters ?? {}; // อัปเดตฟิลเตอร์ปัจจุบัน
    });

    final prefs = await SharedPreferences.getInstance();
    final user_id = prefs.getInt('user_id');

    if (user_id == null) {
      setState(() {
        _is_loading = false;
        _api_message = 'User not logged in.';
        _is_true_error = true;
      });
      return;
    }

    // *** แก้ไขตรงนี้: เปลี่ยนจาก get_items.php เป็น my_items.php ตามที่คุณแจ้ง ***
    String url = '$_api_base_url/my_items.php?user_id=$user_id&order_by=desc';
    if (filters != null && filters.isNotEmpty) {
      filters.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          url += '&$key=$value';
        }
      });
    }

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          List<dynamic> itemsData = responseData['data'] ?? [];
          setState(() {
            _stored_items = itemsData.map((item) => item as Map<String, dynamic>).toList();
            _is_loading = false;
          });
        } else {
          setState(() {
            _api_message = responseData['message'] ?? 'Failed to load items.';
            _is_true_error = true;
            _is_loading = false;
            _stored_items = []; // Clear items on error
          });
        }
      } else {
        setState(() {
          _api_message = 'Server error: ${response.statusCode}';
          _is_true_error = true;
          _is_loading = false;
          _stored_items = [];
        });
      }
    } catch (e) {
      setState(() {
        _api_message = 'Error fetching data: $e';
        _is_true_error = true;
        _is_loading = false;
        _stored_items = [];
      });
    }
  }

  // Helper function to calculate days left
  int _calculate_days_left(String item_date) {
    try {
      final expire_date = DateTime.parse(item_date);
      final today = DateTime.now();
      return expire_date.difference(today).inDays;
    } catch (e) {
      return -9999; // Indicate an error or invalid date
    }
  }

  // Helper function to get status text and color
  Map<String, dynamic> _get_status_info(int days_left) {
    if (days_left < 0) {
      return {'text': 'หมดอายุแล้ว', 'color': Colors.red};
    } else if (days_left <= 7) {
      return {'text': 'ใกล้หมดอายุ', 'color': Colors.orange};
    } else {
      return {'text': '', 'color': Colors.green};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        title: const Text(
          'รายการสินค้า',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: _is_loading
          ? const Center(child: CircularProgressIndicator())
          : _is_true_error
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        _api_message ?? 'An unknown error occurred.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => fetchItemsData(filters: _current_filters), // Retry with current filters
                        child: const Text('ลองอีกครั้ง'),
                      ),
                    ],
                  ),
                )
              : _stored_items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline, color: Colors.grey, size: 40),
                          const SizedBox(height: 10),
                          const Text(
                            'ไม่พบรายการสินค้า',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _stored_items.length,
                      itemBuilder: (context, index) {
                        final item = _stored_items[index];
                        final days_left = _calculate_days_left(item['item_date']);
                        final status_info = _get_status_info(days_left);

                        return _build_item_card(
                          item: item,
                          days_left: days_left,
                          status_text: status_info['text'],
                          status_color: status_info['color'],
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddItemPage(),
            ),
          );
          if (result == true) {
            fetchItemsData();
          }
        },
        child: const Icon(Icons.add),
        backgroundColor: const Color(0xFF4A90E2),
      ),
    );
  }

  // Widget สำหรับสร้างการ์ดรายการสินค้า
  Widget _build_item_card({
    required Map<String, dynamic> item,
    required int days_left,
    required String status_text,
    required Color status_color,
  }) {
    return GestureDetector(
      onTap: () async {
        final bool? result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailPage(
              item_data: {
                'item_id': item['item_id'],
                'user_id': item['user_id'],
                'name': item['item_name'],
                'quantity': item['item_number'],
                'barcode': item['item_barcode'],
                'item_notification': item['item_notification'],
                'unit': item['date_type'] ?? item['unit'],
                'category': item['type_name'] ?? item['category'],
                'storage_location': item['area_name'] ?? item['storage_location'],
                'item_date': item['item_date'],
                'item_img': item['item_img_full_url'],
              },
            ),
          ),
        );
        if (result == true) {
          fetchItemsData(filters: _current_filters);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // รูปภาพ
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item['item_img_full_url'] != null &&
                        (item['item_img_full_url'] as String).isNotEmpty &&
                        (item['item_img_full_url'] as String) != 'lib/img/default.png'
                    ? Image.network(
                        item['item_img_full_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 30,
                            ),
                          );
                        },
                      )
                    : const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.grey,
                        size: 32,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['item_name'] ?? 'ไม่มีชื่อ',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'จำนวน: ${item['item_number'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _format_expire_date(item['item_date'] ?? '', days_left),
                              style: TextStyle(
                                fontSize: 14,
                                color: status_color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ย้ายพื้นที่จัดเก็บ (area_name) ไปด้านขวา
                      if ((item['storage_location'] ?? '').toString().isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 8, top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            item['storage_location'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (status_text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            ),
          ],
        ),
      ),
    );
  }

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
      try {
        final date = DateTime.parse(expire_date);
        final months = [
          '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
          'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
        ];
        final buddhist_year = date.year + 543;
        return 'หมดอายุ ${date.day} ${months[date.month]} $buddhist_year';
      } catch (e) {
        return 'ไม่ระบุวันหมดอายุ';
      }
    }
  }
}