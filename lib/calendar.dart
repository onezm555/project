import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <--- (1) เพิ่ม import นี้
import 'item_detail_page.dart'; // ตรวจสอบให้แน่ใจว่า path ถูกต้อง
import 'add_item.dart';

// URL พื้นฐานของ API ของคุณ (บรรทัดนี้ถูกลบแล้ว)
// const String _api_base_url = 'http://10.192.168.1.176/project'; // <--- (2) บรรทัดนี้ถูกลบออกไป

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  int _selected_year = DateTime.now().year; // ปีที่เลือกในโหมดปกติ
  bool _show_only_expiry_months = false; // สวิตช์กรอง

  Map<String, List<Map<String, dynamic>>> _all_expiry_items_by_date = {};
  bool _is_loading = true;
  String? _error_message;

  final List<String> _month_names = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  String _api_base_url = ''; // <--- (3) เพิ่มตัวแปรนี้สำหรับเก็บ base URL

  @override
  void initState() {
    super.initState();
    // <--- (4) ดึงค่าจาก .env เมื่อ initState
    _api_base_url =
        dotenv.env['API_BASE_URL'] ??
        'http://localhost/project'; // กำหนดค่า default ถ้าหาไม่เจอ
    _fetch_expiry_data(); // เรียกเมื่อเริ่มต้น
  }

  Future<void> _fetch_expiry_data() async {
    setState(() {
      _is_loading = true;
      _error_message = null;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id'); // userId ถูกประกาศที่นี่

    // *** ย้าย debugPrint มาไว้ตรงนี้ ***
    debugPrint('Fetched User ID: $userId');

    if (userId == null) {
      setState(() {
        _error_message = 'ไม่พบ User ID กรุณาเข้าสู่ระบบใหม่';
        _is_loading = false;
      });
      return;
    }

    // <--- (5) ใช้ _api_base_url ที่ดึงมาจาก .env เพื่อสร้าง apiUrl
    final String apiUrl = '$_api_base_url/my_items.php?user_id=$userId';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final response_data = json.decode(utf8.decode(response.bodyBytes));
        if (response_data['success'] == true) {
          final List<dynamic> items = response_data['data'];
          Map<String, List<Map<String, dynamic>>> new_expiry_items_by_date = {};

          for (var item_map in items) {
            String item_date = item_map['item_date'] as String;

            try {
              DateTime expiryDateTime = DateTime.parse(item_date);
              String formatted_date = expiryDateTime.toIso8601String().split(
                'T',
              )[0];

              if (new_expiry_items_by_date.containsKey(formatted_date)) {
                new_expiry_items_by_date[formatted_date]!.add(item_map);
              } else {
                new_expiry_items_by_date[formatted_date] = [item_map];
              }
            } catch (e) {
              debugPrint(
                'Error parsing date for item ${item_map['item_name']}: $item_date, Error: $e',
              );
            }
          }

          setState(() {
            _all_expiry_items_by_date = new_expiry_items_by_date;
            _is_loading = false;
          });
        } else {
          setState(() {
            _error_message =
                response_data['message'] ?? 'ไม่สามารถดึงข้อมูลได้';
            _is_loading = false;
          });
        }
      } else {
        setState(() {
          _error_message = 'Server error: ${response.statusCode}';
          _is_loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error_message = 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e';
        _is_loading = false;
      });
      debugPrint('Error fetching expiry data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _is_loading
          ? const Center(child: CircularProgressIndicator())
          : _error_message != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _error_message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _fetch_expiry_data,
                      child: const Text('ลองใหม่'),
                    ),
                  ],
                ),
              ),
            )
          : _all_expiry_items_by_date.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.inbox, color: Colors.grey, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'ไม่พบสิ่งของเพิ่มการเก็บวันหมดอายุของคุณ',
                      style: TextStyle(fontSize: 20, color: Color(0xFF4A90E2)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: Column(
                children: [
                  _build_month_filter(), // ตัวกรองอยู่ด้านบนเสมอ
                  const SizedBox(height: 16),
                  if (!_show_only_expiry_months)
                    _build_year_selector(), // เลือกปีถ้าไม่ได้กรอง
                  const SizedBox(height: 16),

                  ...(_show_only_expiry_months
                      ? _getSortedMonthsForFilter().map((pair) => _build_month_calendar(pair['month'] as int, year: pair['year'] as int)).toList()
                      : List.generate(12, (index) => _build_month_calendar(index + 1))),
                ],
              ),
            ),
    );
  }

  Widget _build_year_selector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_left),
            onPressed: () {
              setState(() {
                _selected_year--;
              });
            },
          ),
          Text(
            'ปี ${_selected_year + 543}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_right),
            onPressed: () {
              setState(() {
                _selected_year++;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _build_month_filter() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'แสดงเฉพาะเดือนที่มีสินค้าหมดอายุ (ทุกปี)',
              style: TextStyle(fontSize: 16, color: Color(0xFF4A90E2)),
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
      ),
    );
  }

  bool _has_any_expiry_in_month(int month) {
    for (var date_string in _all_expiry_items_by_date.keys) {
      DateTime date = DateTime.parse(date_string);
      if (date.month == month) {
        return true;
      }
    }
    return false;
  }

  /// คืนค่า List ของ Map {'month': int, 'year': int} เรียงจากปีน้อยไปมาก เดือนน้อยไปมาก เฉพาะเดือนที่มีของหมดอายุ (ใช้ในโหมดกรอง)
  List<Map<String, int>> _getSortedMonthsForFilter() {
    final Set<String> monthYearSet = {};
    for (final dateString in _all_expiry_items_by_date.keys) {
      final date = DateTime.parse(dateString);
      monthYearSet.add('${date.year}-${date.month}');
    }
    final List<Map<String, int>> result = monthYearSet
        .map((s) {
          final parts = s.split('-');
          return {'year': int.parse(parts[0]), 'month': int.parse(parts[1])};
        })
        .toList();
    result.sort((a, b) {
      if (a['year'] != b['year']) {
        return a['year']!.compareTo(b['year']!);
      }
      return a['month']!.compareTo(b['month']!);
    });
    return result;
  }

  Widget _build_month_calendar(int month, {int? year}) {
    int display_year = year ?? (_show_only_expiry_months ? DateTime.now().year : _selected_year);

    int days_in_month = DateTime(display_year, month + 1, 0).day;
    DateTime first_day_of_month = DateTime(display_year, month, 1);
    int start_day_of_week = first_day_of_month.weekday;

    int offset = (start_day_of_week == 7) ? 0 : start_day_of_week;

    String month_title = _month_names[month - 1];
    if (_show_only_expiry_months && year != null) {
      month_title += ' ${year + 543}';
    } else if (!_show_only_expiry_months) {
      month_title += ' ${_selected_year + 543}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // แสดงชื่อเดือนและปีที่นี่
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              month_title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A90E2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // แสดงหัวข้อวันของสัปดาห์
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              children: const [
                Expanded(child: Center(child: Text('อา', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)))),
                Expanded(child: Center(child: Text('จ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)))),
                Expanded(child: Center(child: Text('อ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)))),
                Expanded(child: Center(child: Text('พ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)))),
                Expanded(child: Center(child: Text('พฤ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)))),
                Expanded(child: Center(child: Text('ศ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)))),
                Expanded(child: Center(child: Text('ส', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)))),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
            itemCount: days_in_month + offset,
            itemBuilder: (context, index) {
              if (index < offset) {
                return Container();
              }
              int day = index - offset + 1;

              // เก็บรายการสินค้าที่หมดอายุในวันนี้ (สำหรับปีที่เลือก หรือทุกปี)
              List<Map<String, dynamic>> items_on_this_day_across_all_years =
                  [];
              // ไม่ต้องเก็บ expiry_years_on_this_day สำหรับแสดงบนตัวเลขวันแล้ว
              // Set<int> expiry_years_on_this_day = {};


              for (var entry in _all_expiry_items_by_date.entries) {
                DateTime stored_date = DateTime.parse(entry.key);
                if (stored_date.month == month && stored_date.day == day) {
                  if (_show_only_expiry_months) {
                    if (year != null && stored_date.year != year) continue;
                  } else {
                    if (stored_date.year != _selected_year) continue;
                  }
                  items_on_this_day_across_all_years.addAll(entry.value);
                }
              }

              bool has_expiry = items_on_this_day_across_all_years.isNotEmpty;

              return GestureDetector(
                onTap: () {
                  if (has_expiry) {
                    _show_expiry_dialog(
                      context,
                      month,
                      day,
                      items_on_this_day_across_all_years,
                    );
                  }
                },
                child: Container(
                  alignment: Alignment.center,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: has_expiry ? Colors.white : Colors.transparent,
                      shape: BoxShape.circle,
                      border: has_expiry
                          ? Border.all(
                              color: const Color(0xFFE91E63),
                              width: 2.5,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 16,
                        color: has_expiry
                            ? const Color(0xFFE91E63)
                            : Colors.black87,
                        fontWeight: has_expiry
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
            ),
          ),
        ],
      ),
    );
  }

  void _show_expiry_dialog(
    BuildContext context,
    int month,
    int day,
    List<Map<String, dynamic>> items,
  ) {
    // ใน Dialog ให้แสดงวันที่ของ Dialog ให้ตรงกับวันที่กด
    String dialog_date_title;
    // หากอยู่ในโหมดรวมทุกปี (_show_only_expiry_months)
    // หัวข้อ Dialog ไม่ควรมีปีเฉพาะเจาะจง เพราะวันที่เดียวกันอาจมีสินค้าจากหลายปี
    if (_show_only_expiry_months) {
      dialog_date_title =
          '${day} ${_month_names[month - 1]}'; // แสดงแค่วันที่และเดือน
    } else {
      // โหมดปกติ แสดงวัน เดือน ปี ที่เลือก
      dialog_date_title = _format_thai_date(
        DateTime(_selected_year, month, day).toIso8601String().split('T')[0],
      );
    }

    items.sort((a, b) {
      DateTime dateA = DateTime.parse(a['item_date']);
      DateTime dateB = DateTime.parse(b['item_date']);
      return dateA.compareTo(dateB);
    });

    // หัวข้อ Dialog: ถ้ามี BBF ให้แสดง "สินค้าควรบริโภคก่อน" ถ้าไม่มีก็ "สินค้าหมดอายุ"
    final hasBBF = items.any((item) => (item['date_type'] ?? '').toString().toUpperCase() == 'BBF');
    final dialogTitlePrefix = hasBBF ? 'สินค้าควรบริโภคก่อน' : 'สินค้าหมดอายุ';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '$dialogTitlePrefix\n$dialog_date_title',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A90E2),
          ),
        ),
        content: items.isEmpty
            ? Text(hasBBF ? 'ไม่พบสินค้าควรบริโภคก่อนในวันนี้' : 'ไม่พบสินค้าหมดอายุในวันนี้')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items.map((item_data) {
                    String display_item_name = item_data['item_name'] ?? 'ไม่มีชื่อ';
                    try {
                      DateTime expiry_date = DateTime.parse(item_data['item_date']);
                      display_item_name += ' (${expiry_date.year + 543} พ.ศ.)';
                    } catch (e) {}

                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ItemDetailPage(
                              item_data: {
                                ...item_data,
                                'item_img': item_data['item_img_full_url'],
                                'category': item_data['category'],
                                'storage_location': item_data['storage_location'],
                                'name': item_data['item_name'],
                                'barcode': item_data['item_barcode'],
                              },
                            ),
                          ),
                        );
                        if (result == true) {
                          _fetch_expiry_data();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            if (item_data['item_img_full_url'] != null && item_data['item_img_full_url'].isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  item_data['item_img_full_url'],
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.image,
                                        color: Colors.grey,
                                        size: 24,
                                      ),
                                    );
                                  },
                                ),
                              )
                            else
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.grey,
                                  size: 24,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    display_item_name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4A90E2),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'จำนวน: ${item_data['item_number'] ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    'หมวดหมู่: ${item_data['category'] ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    'จัดเก็บ: ${item_data['storage_location'] ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
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

  String _format_thai_date(String date) {
    final parsed_date = DateTime.parse(date);
    return '${parsed_date.day} ${_month_names[parsed_date.month - 1]} ${parsed_date.year + 543}';
  }
}