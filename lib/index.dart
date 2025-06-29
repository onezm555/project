// index.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'item_detail_page.dart'; // **ปรับเปลี่ยนตาม path ของคุณ**

class IndexPage extends StatefulWidget {
  const IndexPage({Key? key}) : super(key: key);

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  List<Map<String, dynamic>> _stored_items = [];
  bool _is_loading = true;
  String? _api_message;
  bool _is_true_error = false;

  @override
  void initState() {
    super.initState();
    _fetch_items_data();
  }

  Future<void> _fetch_items_data() async {
    setState(() {
      _is_loading = true;
      _api_message = null;
      _is_true_error = false;
      _stored_items = [];
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    if (userId == null) {
      setState(() {
        _api_message = 'ไม่พบ User ID กรุณาเข้าสู่ระบบใหม่';
        _is_true_error = true;
        _is_loading = false;
      });
      return;
    }

    final String apiUrl = 'http://10.10.44.149/project/my_items.php?user_id=$userId';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          List<Map<String, dynamic>> fetchedItems = [];
          for (var itemJson in responseData['data']) {
            DateTime expireDate = DateTime.parse(itemJson['item_date']);
            DateTime now = DateTime.now();
            int daysLeft = expireDate.difference(now).inDays;

            fetchedItems.add({
              'id': itemJson['item_id'],
              'name': itemJson['item_name'],
              'image': itemJson['item_img_full_url'] ?? 'lib/img/default.png',
              'quantity': itemJson['item_number'],
              'unit': itemJson['item_unit'] ?? 'ชิ้น', // ดึง unit จาก API ด้วย
              'expire_date': itemJson['item_date'],
              'storage_location': itemJson['storage_location'] ?? 'ไม่ได้ระบุ', // ดึง storage_location จาก API
              'category': itemJson['category'] ?? 'ไม่ได้ระบุ', // ดึง category จาก API
              'date_type': itemJson['date_type'] ?? 'วันหมดอายุ(EXP)', // ดึง date_type จาก API
              'notification_days': itemJson['notification_days'] != null ? int.tryParse(itemJson['notification_days'].toString()) : 3, // ดึง notification_days
              'barcode': itemJson['barcode'] ?? '', // ดึง barcode
              'selected_date': itemJson['item_date'], // ใช้ item_date เป็น selected_date
              'days_left': daysLeft,
            });
          }
          setState(() {
            _stored_items = fetchedItems;
          });
        } else {
          setState(() {
            _api_message = responseData['message'] ?? 'ไม่พบข้อมูลสินค้า';
            _is_true_error = false;
            _stored_items = [];
          });
        }
      } else {
        setState(() {
          _api_message = 'เกิดข้อผิดพลาดในการดึงข้อมูล: ${response.statusCode}';
          _is_true_error = true;
        });
      }
    } catch (e) {
      setState(() {
        _api_message = 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e';
        _is_true_error = true;
      });
    } finally {
      setState(() {
        _is_loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _is_loading
          ? const Center(child: CircularProgressIndicator())
          : _is_true_error
              ? _build_error_state(_api_message!)
              : _stored_items.isEmpty
                  ? _build_empty_state()
                  : _build_items_list(),
    );
  }

  Widget _build_error_state(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'ข้อผิดพลาด: $message',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _fetch_items_data,
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _build_items_list() {
    return RefreshIndicator(
      onRefresh: _fetch_items_data,
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

  Widget _build_item_card(Map<String, dynamic> item, int index) {
    final days_left = item['days_left'] as int;
    Color status_color;
    String status_text;

    if (days_left < 0) {
      status_color = Colors.red;
      status_text = 'หมดอายุแล้ว';
    } else if (days_left == 0) {
      status_color = Colors.red;
      status_text = 'หมดอายุวันนี้';
    } else if (days_left <= 7) {
      status_color = Colors.orange;
      status_text = 'ใกล้หมดอายุ';
    } else {
      status_color = Colors.green;
      status_text = 'อยู่ที่${item['storage_location']}';
    }

    return GestureDetector(
      onTap: () {
        // Navigate to ItemDetailPage when card is tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailPage(item_data: item),
          ),
        );
      },
      child: Container(
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
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item['image'],
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
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Text(
                    'จำนวน ${item['quantity']} ${item['unit']}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
        return 'หมดอายุ ${date.day} ${months[date.month]} ${date.year + 543}';
      } catch (e) {
        return 'หมดอายุ $expire_date';
      }
    }
  }
}