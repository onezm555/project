import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'item_detail_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  int _selected_year = DateTime.now().year; 
  int _selected_month = DateTime.now().month; // เพิ่มเดือนที่เลือก
  int _display_mode = 0; // 0: ทั้งหมด, 1: เฉพาะเดือนที่มีสิ่งของ, 2: ต่อเดือน

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

  String _api_base_url = ''; 

  @override
  void initState() {
    super.initState();
    // <--- (4) ดึงค่าจาก .env เมื่อ initState
    _api_base_url =
        dotenv.env['API_BASE_URL'] ??
        'http://localhost/project'; 
    _fetch_expiry_data(); 
  }

  Future<void> _fetch_expiry_data() async {
    setState(() {
      _is_loading = true;
      _error_message = null;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    if (userId == null) {
      setState(() {
        _error_message = 'ไม่พบ User ID กรุณาเข้าสู่ระบบใหม่';
        _is_loading = false;
      });
      return;
    }

    final String apiUrl = '$_api_base_url/calendar_items.php?user_id=$userId';

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
                      style: TextStyle(fontSize: 20, color: Color.fromARGB(255, 0, 0, 0)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetch_expiry_data,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Column(
                  children: [
                    _build_display_mode_selector(), // ตัวเลือกโหมดการแสดง
                    const SizedBox(height: 16),
                    if (_display_mode == 0 || _display_mode == 2)
                      _build_year_selector(), // เลือกปีสำหรับโหมดทั้งหมดและต่อเดือน
                    if (_display_mode == 2) ...[
                      const SizedBox(height: 16),
                      _build_month_selector(), // เลือกเดือนสำหรับโหมดต่อเดือน
                    ],
                    const SizedBox(height: 16),

                    ...(_display_mode == 1
                        ? _getSortedMonthsForFilter().map((pair) => _build_month_calendar(pair['month'] as int, year: pair['year'] as int)).toList()
                        : _display_mode == 2
                        ? [_build_month_calendar(_selected_month)]
                        : List.generate(12, (index) => _build_month_calendar(index + 1))),
                  ],
                ),
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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), // เพิ่มจาก 18 เป็น 24
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

  Widget _build_display_mode_selector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'โหมดการแสดง',
            style: TextStyle(
              fontSize: 24, // เพิ่มจาก 16 เป็น 24
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A90E2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModeButton(
                  title: 'ทั้งหมด',
                  subtitle: '12 เดือน',
                  isSelected: _display_mode == 0,
                  onTap: () => setState(() => _display_mode = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeButton(
                  title: 'มีสิ่งของ',
                  subtitle: 'เฉพาะเดือนที่มี',
                  isSelected: _display_mode == 1,
                  onTap: () => setState(() => _display_mode = 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeButton(
                  title: 'ต่อเดือน',
                  subtitle: 'ทีละเดือน',
                  isSelected: _display_mode == 2,
                  onTap: () => setState(() => _display_mode = 2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18, // เพิ่มจาก 14 เป็น 18
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16, // เพิ่มจาก 12 เป็น 16
                color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _build_month_selector() {
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
                if (_selected_month == 1) {
                  _selected_month = 12;
                  _selected_year--;
                } else {
                  _selected_month--;
                }
              });
            },
          ),
          Text(
            '${_month_names[_selected_month - 1]} ${_selected_year + 543}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), // เพิ่มจาก 18 เป็น 24
          ),
          IconButton(
            icon: const Icon(Icons.arrow_right),
            onPressed: () {
              setState(() {
                if (_selected_month == 12) {
                  _selected_month = 1;
                  _selected_year++;
                } else {
                  _selected_month++;
                }
              });
            },
          ),
        ],
      ),
    );
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
    int display_year = year ?? (_display_mode == 1 ? DateTime.now().year : _selected_year);

    int days_in_month = DateTime(display_year, month + 1, 0).day;
    DateTime first_day_of_month = DateTime(display_year, month, 1);
    int start_day_of_week = first_day_of_month.weekday;

    int offset = (start_day_of_week == 7) ? 0 : start_day_of_week;

    String month_title = _month_names[month - 1];
    if (_display_mode == 1 && year != null) {
      month_title += ' ${year + 543}';
    } else if (_display_mode == 0 || _display_mode == 2) {
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
                Expanded(child: Center(child: Text('อา', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)))), // เพิ่มจาก 14 เป็น 18
                Expanded(child: Center(child: Text('จ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)))), // เพิ่มจาก 14 เป็น 18
                Expanded(child: Center(child: Text('อ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)))), // เพิ่มจาก 14 เป็น 18
                Expanded(child: Center(child: Text('พ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)))), // เพิ่มจาก 14 เป็น 18
                Expanded(child: Center(child: Text('พฤ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)))), // เพิ่มจาก 14 เป็น 18
                Expanded(child: Center(child: Text('ศ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)))), // เพิ่มจาก 14 เป็น 18
                Expanded(child: Center(child: Text('ส', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)))), // เพิ่มจาก 14 เป็น 18
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

              // เก็บรายการสิ่งของที่หมดอายุในวันนี้ (สำหรับปีที่เลือก หรือทุกปี)
              List<Map<String, dynamic>> items_on_this_day_across_all_years =
                  [];
              // ไม่ต้องเก็บ expiry_years_on_this_day สำหรับแสดงบนตัวเลขวันแล้ว
              // Set<int> expiry_years_on_this_day = {};


              for (var entry in _all_expiry_items_by_date.entries) {
                DateTime stored_date = DateTime.parse(entry.key);
                if (stored_date.month == month && stored_date.day == day) {
                  if (_display_mode == 1) {
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
                        fontSize: 20, // เพิ่มจาก 16 เป็น 20
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
    // หากอยู่ในโหมดรวมทุกปี (_display_mode == 1)
    // หัวข้อ Dialog ไม่ควรมีปีเฉพาะเจาะจง เพราะวันที่เดียวกันอาจมีสิ่งของจากหลายปี
    if (_display_mode == 1) {
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

    // หัวข้อ Dialog: ถ้ามี BBF ให้แสดง "สิ่งของควรบริโภคก่อน" ถ้าไม่มีก็ "สิ่งของหมดอายุ"
    final hasBBF = items.any((item) => (item['date_type'] ?? '').toString().toUpperCase() == 'BBF');
    final dialogTitlePrefix = hasBBF ? 'สิ่งของควรบริโภคก่อน' : 'สิ่งของหมดอายุ';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '$dialogTitlePrefix\n$dialog_date_title',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24, // เพิ่มจาก 22 เป็น 24
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A90E2),
          ),
        ),
        content: items.isEmpty
            ? Text(hasBBF ? 'ไม่พบสิ่งของควรบริโภคก่อนในวันนี้' : 'ไม่พบสิ่งของหมดอายุในวันนี้')
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
                        
                        // เตรียมข้อมูลให้ครบถ้วนสำหรับ ItemDetailPage
                        Map<String, dynamic> itemDetailData = {
                          // ข้อมูลพื้นฐาน
                          'item_id': item_data['item_id'],
                          'id': item_data['item_id'], // เพิ่ม id สำรอง
                          'name': item_data['item_name'] ?? item_data['name'] ?? '',
                          'item_name': item_data['item_name'] ?? item_data['name'] ?? '',
                          'quantity': item_data['item_number'] ?? item_data['quantity'] ?? item_data['remaining_quantity'] ?? 1,
                          'item_number': item_data['item_number'] ?? item_data['quantity'] ?? 1,
                          'remaining_quantity': item_data['remaining_quantity'] ?? item_data['item_number'] ?? item_data['quantity'] ?? 1,
                          
                          // ข้อมูลหมวดหมู่และที่เก็บ
                          'category': item_data['category'] ?? item_data['type_name'] ?? 'ไม่ระบุ',
                          'type_name': item_data['type_name'] ?? item_data['category'] ?? 'ไม่ระบุ',
                          'storage_location': item_data['storage_location'] ?? item_data['area_name'] ?? 'ไม่ระบุ',
                          'area_name': item_data['area_name'] ?? item_data['storage_location'] ?? 'ไม่ระบุ',
                          
                          // ข้อมูลวันที่
                          'item_date': item_data['item_date'],
                          'date_type': item_data['date_type'] ?? 'EXP',
                          'unit': item_data['date_type'] ?? 'EXP',
                          
                          // ข้อมูลการแจ้งเตือน
                          'item_notification': item_data['item_notification'] ?? item_data['notification_days'] ?? 3,
                          'notification_days': item_data['notification_days'] ?? item_data['item_notification'] ?? 3,
                          
                          // ข้อมูลบาร์โค้ด
                          'barcode': item_data['item_barcode'] ?? item_data['barcode'] ?? '',
                          'item_barcode': item_data['item_barcode'] ?? item_data['barcode'] ?? '',
                          
                          // ข้อมูลผู้ใช้และสถานะ
                          'user_id': item_data['user_id'],
                          'item_status': item_data['item_status'] ?? 'active',
                          
                          // ข้อมูลรูปภาพ
                          'item_img': item_data['item_img_full_url'] ?? item_data['item_img'] ?? null,
                          
                          // ข้อมูลเพิ่มเติม
                          'storage_locations': item_data['storage_locations'] ?? [],
                          'item_expire_details': item_data['item_expire_details'] ?? [],
                          'used_quantity': item_data['used_quantity'] ?? 0,
                          'expired_quantity': item_data['expired_quantity'] ?? 0,
                        };
                        
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ItemDetailPage(
                              item_data: itemDetailData,
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
                                      fontSize: 20, // เพิ่มจาก 16 เป็น 20
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4A90E2),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'จำนวน: ${item_data['item_number'] ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 16, // เพิ่มจาก 12 เป็น 16
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    'หมวดหมู่: ${item_data['category'] ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 16, // เพิ่มจาก 12 เป็น 16
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  // แสดงพื้นที่จัดเก็บทั้งหมด (ถ้ามีหลายพื้นที่)
                                  if ((item_data['storage_locations'] != null && (item_data['storage_locations'] as List).isNotEmpty))
                                    Text(
                                      'จัดเก็บ: ${(item_data['storage_locations'] as List)
                                          .map((loc) => (loc is Map) ? (loc['area_name'] ?? '') : '')
                                          .where((name) => name.toString().isNotEmpty)
                                          .toSet() // ใช้ Set เพื่อลบชื่อซ้ำ
                                          .join(', ')}',
                                      style: TextStyle(
                                        fontSize: 16, // เพิ่มจาก 12 เป็น 16
                                        color: Colors.grey[700],
                                      ),
                                    )
                                  else
                                    Text(
                                      'จัดเก็บ: ${item_data['storage_location'] ?? item_data['area_name'] ?? 'N/A'}',
                                      style: TextStyle(
                                        fontSize: 16, // เพิ่มจาก 12 เป็น 16
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
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontSize: 18), // เพิ่มขนาดตัวอักษรปุ่ม
            ),
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