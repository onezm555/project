// index.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'item_detail_page.dart'; // ตรวจสอบให้แน่ใจว่า import ถูกต้อง

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
          url += '&$key=${Uri.encodeComponent(value.toString())}';
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
        // ลบ title ออก
        title: null,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await fetchItemsData(filters: _current_filters);
        },
        child: _is_loading
            ? const Center(child: CircularProgressIndicator())
            : _is_true_error
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
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
                        ),
                      ),
                    ],
                  )
                : _stored_items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.grey, size: 40),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'ไม่พบรายการสิ่งของคุณกรุณาเพิ่มสิ่งของใหม่เพื่อเก็บเป็นวันหมดอายุ',
                                    style: TextStyle(color: Colors.grey, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _stored_items.length,
                        itemBuilder: (context, index) {
                          final item = _stored_items[index];
                          final days_left = _calculate_days_left(item['item_date']);
                          final status_info = _get_status_info(days_left);
                          // ตรวจสอบ date_type เพื่อใช้ข้อความที่เหมาะสม
                          final dateType = (item['date_type'] ?? '').toString().toUpperCase();
                          return _build_item_card(
                            item: item,
                            days_left: days_left,
                            status_text: status_info['text'],
                            status_color: status_info['color'],
                            date_type: dateType,
                          );
                        },
                      ),
      ),
    );
  }

  // Widget สำหรับสร้างการ์ดรายการสินค้า
  Widget _build_item_card({
    required Map<String, dynamic> item,
    required int days_left,
    required String status_text,
    required Color status_color,
    required String date_type,
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
                'quantity': item['quantity'] ?? item['item_number'], // ใช้ quantity ก่อน แล้วค่อย fallback เป็น item_number
                'barcode': item['item_barcode'],
                'item_notification': item['item_notification'],
                'unit': item['date_type'] ?? item['unit'],
                'category': item['type_name'] ?? item['category'],
                'storage_location': item['storage_location'],
                'storage_locations': item['storage_locations'], // ส่งข้อมูลละเอียดไปด้วย
                'item_date': item['item_date'],
                'item_img': item['item_img_full_url'],
                'item_expire_details': item['item_expire_details'] ?? [], // ส่งข้อมูลรายละเอียดแต่ละชิ้น
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
                              'จำนวน: ${item['quantity'] ?? item['item_number'] ?? 'N/A'}', // ใช้ quantity ก่อน แล้วค่อย fallback
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            // แสดงวันหมดอายุ - ถ้ามีข้อมูลแต่ละชิ้นให้แสดงสรุป
                            _build_expire_date_display(
                              item['item_date'] ?? '',
                              days_left,
                              date_type,
                              item['item_expire_details'] ?? [],
                              status_color,
                            ),
                          ],
                        ),
                      ),
                      // ย้ายพื้นที่จัดเก็บ (area_name) ไปด้านขวา
                      if ((item['storage_locations'] ?? []).isNotEmpty)
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
                            ((item['storage_locations'] as List)
                              .map((loc) => loc['area_name'] ?? '')
                              .where((name) => name.toString().isNotEmpty)
                              .toList())
                              .join(', '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
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

  // Widget สำหรับแสดงวันหมดอายุ - รองรับทั้งแบบเดี่ยวและหลายชิ้น
  Widget _build_expire_date_display(
    String main_expire_date,
    int days_left,
    String date_type,
    List<dynamic> expire_details,
    Color status_color,
  ) {
    // Debug: พิมพ์ข้อมูล expire_details ที่ได้รับ
    if (expire_details.isNotEmpty) {
      print('DEBUG: expire_details = $expire_details');
    }
    
    // ถ้ามีข้อมูลวันหมดอายุแต่ละชิ้น
    if (expire_details.isNotEmpty) {
      // เรียงข้อมูลตามวันหมดอายุ
      List<DateTime> all_dates = [];
      for (var detail in expire_details) {
        try {
          final date = DateTime.parse(detail['expire_date']);
          all_dates.add(date);
          print('DEBUG: Parsed date = $date from ${detail['expire_date']}');
        } catch (e) {
          print('DEBUG: Failed to parse date ${detail['expire_date']}: $e');
          // ข้ามวันที่ที่ไม่ถูกต้อง
        }
      }
      
      if (all_dates.isEmpty) {
        // ถ้าไม่มีวันที่ถูกต้อง ใช้ค่าเดิม
        return Text(
          _format_expire_date(main_expire_date, days_left, date_type),
          style: TextStyle(
            fontSize: 14,
            color: status_color,
            fontWeight: FontWeight.w500,
          ),
        );
      }
      
      // เรียงวันที่จากเร็วไปช้า
      all_dates.sort();
      print('DEBUG: Sorted dates = $all_dates');
      
      final earliest_date = all_dates.first;
      final earliest_days_left = earliest_date.difference(DateTime.now()).inDays;
      final earliest_status_info = _get_status_info(earliest_days_left);
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _format_expire_date(earliest_date.toIso8601String(), earliest_days_left, date_type),
            style: TextStyle(
              fontSize: 14,
              color: earliest_status_info['color'],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (all_dates.length > 1) ...[
            const SizedBox(height: 2),
            _build_additional_dates_display(all_dates.skip(1).toList()),
          ],
        ],
      );
    }
    
    // ใช้ข้อมูลเดิม (ถ้าไม่มีข้อมูลแต่ละชิ้น)
    return Text(
      _format_expire_date(main_expire_date, days_left, date_type),
      style: TextStyle(
        fontSize: 14,
        color: status_color,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ฟังก์ชันสำหรับแสดงวันหมดอายุเพิ่มเติม
  Widget _build_additional_dates_display(List<DateTime> additional_dates) {
    if (additional_dates.isEmpty) return const SizedBox.shrink();
    
    // แสดงวันที่สูงสุด 3 วันที่ถัดไป
    final dates_to_show = additional_dates.take(3).toList();
    final remaining_count = additional_dates.length - dates_to_show.length;
    
    String dates_text = dates_to_show.map((date) {
      return _format_date_short(date);
    }).join(', ');
    
    String display_text = 'และอีก ${additional_dates.length} ชิ้น';
    if (dates_to_show.isNotEmpty) {
      display_text += ' ($dates_text';
      if (remaining_count > 0) {
        display_text += ', +$remaining_count';
      }
      display_text += ')';
    }
    
    return Text(
      display_text,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
        fontStyle: FontStyle.italic,
      ),
    );
  }

  // ฟังก์ชันสำหรับจัดรูปแบบวันที่แบบสั้น
  String _format_date_short(DateTime date) {
    final months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${(date.year + 543).toString().substring(2)}';
  }

  String _format_expire_date(String expire_date, int days_left, String date_type) {
    String label = 'หมดอายุ';
    if (date_type == 'BBF') {
      label = 'ควรบริโภคก่อน';
    }
    if (days_left < 0) {
      return '$labelแล้ว ${days_left.abs()} วัน';
    } else if (days_left == 0) {
      return '$labelวันนี้';
    } else if (days_left == 1) {
      return '$labelพรุ่งนี้';
    } else if (days_left <= 30) {
      return '$labelอีก $days_left วัน';
    } else {
      try {
        final date = DateTime.parse(expire_date);
        final months = [
          '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
          'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
        ];
        final buddhist_year = date.year + 543;
        return '$label ${date.day} ${months[date.month]} $buddhist_year';
      } catch (e) {
        return 'ไม่ระบุวันหมดอายุ';
      }
    }
  }
}