import 'package:flutter/material.dart';
import 'index_working.dart'; // Import the working index page
import 'calendar.dart';
import 'notification.dart';
import 'menu.dart';
import 'add_item.dart';
import 'barcode_scanner_page.dart'; // เพิ่ม import สำหรับ barcode scanner
import 'package:http/http.dart' as http; // For API calls in filter
import 'dart:convert'; // For JSON parsing in filter
import 'package:flutter_dotenv/flutter_dotenv.dart'; // For API_BASE_URL
import 'package:shared_preferences/shared_preferences.dart'; // For SharedPreferences

class MainLayout extends StatefulWidget {
  final int initial_tab;

  const MainLayout({
    Key? key,
    this.initial_tab = 0,
  }) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _selected_index;
  final TextEditingController _search_controller = TextEditingController();
  String _api_base_url = ''; // Added for API calls

  // State variables for filter options in Modal
  String? _selected_storage_location;
  String? _selected_category;
  String? _selected_sort_order;
  bool _filter_all = true;
  bool _filter_expired = false;
  bool _filter_expiring_7_days = false;
  bool _filter_expiring_30_days = false;

  List<String> _storage_locations = [];
  List<String> _categories = [];
  bool _is_filter_options_loading = true;
  String _user_name = ''; // เพิ่มตัวแปรสำหรับเก็บชื่อผู้ใช้

  // Reference to IndexPageState for calling methods
  dynamic _indexPageState;

  @override
  void initState() {
    super.initState();
    _selected_index = widget.initial_tab;
    _api_base_url = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project'; // Load API base URL
    _fetch_filter_options(); // Fetch filter dropdown options when MainLayout initializes
    _load_user_name(); // โหลดชื่อผู้ใช้
  }

  @override
  void dispose() {
    _search_controller.dispose();
    super.dispose();
  }

  // ฟังก์ชันสำหรับโหลดชื่อผู้ใช้จาก SharedPreferences
  Future<void> _load_user_name() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userName = prefs.getString('user_name') ?? prefs.getString('username') ?? prefs.getString('name');
      if (userName != null && userName.isNotEmpty) {
        setState(() {
          _user_name = userName;
        });
      }
    } catch (e) {
      print('Error loading user name: $e');
    }
  }

  // Function to fetch storage locations and categories from your PHP APIs
  Future<void> _fetch_filter_options() async {
    setState(() {
      _is_filter_options_loading = true;
    });
    try {
      // ดึง user_id จาก SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');
      if (userId == null) {
        setState(() {
          _storage_locations = [];
          _categories = [];
          _is_filter_options_loading = false;
        });
        return;
      }
      final response = await http.get(Uri.parse('$_api_base_url/get_user_areas_types.php?user_id=$userId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _storage_locations = (data['areas'] as List).map((item) => item['area_name'].toString()).toList();
            _categories = (data['types'] as List).map((item) => item['type_name'].toString()).toList();
          });
        } else {
          setState(() {
            _storage_locations = [];
            _categories = [];
          });
        }
      }
    } catch (e) {
      print('Error fetching filter options: $e');
    } finally {
      setState(() {
        _is_filter_options_loading = false;
      });
    }
  }

  // List of pages, now using callback approach
  late final List<Widget> _pages = [
    IndexPageWorking(
      onStateCreated: (state) {
        _indexPageState = state;
      },
    ), // Use the working IndexPage
    const CalendarPage(),
    const NotificationPage(),
    const MenuPage(),
  ];

  // ฟังก์ชันสำหรับสร้างข้อความทักทายตามเวลา
  String _get_greeting() {
    final now = DateTime.now();
    final hour = now.hour;
    
    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'สวัสดีตอนเช้า';
    } else if (hour >= 12 && hour < 17) {
      greeting = 'สวัสดีตอนกลางวัน';
    } else {
      greeting = 'สวัสดีตอนเย็น';
    }
    
    // เพิ่มชื่อผู้ใช้ถ้ามี
    if (_user_name.isNotEmpty) {
      return '$greeting คุณ$_user_name';
    }
    return greeting;
  }

  List<String> get _page_titles => [
    _get_greeting(),
    'ปฏิทิน',
    'การแจ้งเตือน',
    'เมนู',
  ];

  void _on_tab_selected(int index) {
    setState(() {
      _selected_index = index;
    });
  }

  void _handle_search(String query) {
    print('Searching for: $query');
    if (query.trim().isEmpty) {
      _indexPageState?.fetchItemsData(filters: {});
    } else {
      _indexPageState?.fetchItemsData(filters: {'search_query': query});
    }
  }

  Future<void> _scan_barcode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerPage(),
        ),
      );
      
      // ตรวจสอบว่าผลลัพธ์ไม่ใช่ null, ไม่ใช่ -1 (cancel), และไม่ใช่ค่าว่าง
      if (result != null && 
          result is String && 
          result.isNotEmpty && 
          result != '-1') {
        // ใส่รหัสบาร์โค้ดในช่องค้นหา
        setState(() {
          _search_controller.text = result;
        });
        // ทำการค้นหาด้วยรหัสบาร์โค้ด
        _handle_search(result);
      }
      // ถ้าเป็น -1 หรือค่าอื่นที่ไม่ต้องการ ไม่ต้องทำอะไร
    } catch (e) {
      print('Error scanning barcode: $e');
      // แสดงข้อความผิดพลาดถ้าจำเป็น
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เกิดข้อผิดพลาดในการสแกนบาร์โค้ด'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _show_add_item_menu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _add_new_item();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'เพิ่มสิ่งของใหม่',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _add_existing_item();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'เพิ่มสิ่งของที่มีอยู่(บาร์โค้ด)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _add_new_item() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddItemPage(is_existing_item: false),
      ),
    ).then((result) {
      if (result == true) {
        // Refresh data on IndexPage after adding item
        _indexPageState?.fetchItemsData();
      }
    });
  }

  void _add_existing_item() async {
    try {
      // เปิด barcode scanner ก่อน
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerPage(),
        ),
      );
      
      // ตรวจสอบว่าผลลัพธ์ไม่ใช่ null, ไม่ใช่ -1 (cancel), และไม่ใช่ค่าว่าง
      if (result != null && 
          result is String && 
          result.isNotEmpty && 
          result != '-1') {
        
        // ค้นหาข้อมูลสิ่งของในฐานข้อมูลด้วยบาร์โค้ด
        await _search_existing_item_by_barcode(result);
      }
      // ถ้าเป็น -1 หรือค่าอื่นที่ไม่ต้องการ ไม่ต้องทำอะไร
    } catch (e) {
      print('Error in _add_existing_item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เกิดข้อผิดพลาดในการสแกนบาร์โค้ด'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _search_existing_item_by_barcode(String barcode) async {
    try {
      // แสดง loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // ดึง user_id จาก SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');
      
      if (userId == null) {
        Navigator.pop(context); // ปิด loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่พบข้อมูลผู้ใช้งาน กรุณาเข้าสู่ระบบใหม่'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // เรียก API เพื่อค้นหาสิ่งของด้วยบาร์โค้ด
      final apiUrl = '$_api_base_url/search_item_by_barcode.php?user_id=$userId&barcode=${Uri.encodeComponent(barcode)}';
      print('Calling API: $apiUrl');
      
      final response = await http.get(Uri.parse(apiUrl));
      
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      Navigator.pop(context); // ปิด loading

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          
          // เพิ่ม debug เพื่อดูข้อมูลที่ได้จาก API
          print('API Response: $data');
          print('Response success: ${data['success']}');
          print('Response data: ${data['data']}');
          
          if (data['success'] == true && data['data'] != null) {
          // พบข้อมูลสิ่งของ - นำไปยังหน้าเพิ่มสิ่งของพร้อมข้อมูลเดิม
          final itemData = data['data'];
          
          // เพิ่ม debug เพื่อดูข้อมูลสิ่งของ
          print('Item Data from API: $itemData');
          print('item_name: ${itemData['item_name']}');
          print('item_barcode: ${itemData['item_barcode']}');
          print('category: ${itemData['category']}');
          print('storage_location: ${itemData['storage_location']}');
          print('date_type: ${itemData['date_type']}');
          
          // แสดงข้อความแจ้งเตือนก่อน
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('พบข้อมูลสิ่งของ: ${itemData['item_name']}'),
              backgroundColor: Colors.green,
            ),
          );
          
          final Map<String, dynamic> itemDataToSend = {
            // ชื่อสิ่งของ
            'name': itemData['item_name'] ?? '',
            'item_name': itemData['item_name'] ?? '',
            
            // ประเภท/หมวดหมู่
            'category': itemData['category'] ?? '',
            'type_name': itemData['category'] ?? '',
            
            // รหัสบาร์โค้ด
            'barcode': itemData['item_barcode'] ?? barcode,
            'item_barcode': itemData['item_barcode'] ?? barcode,
            
            // ข้อมูลอื่นๆ
            'storage_location': itemData['storage_location'] ?? '',
            'area_name': itemData['storage_location'] ?? '',
            'unit': itemData['date_type'] == 'BBF' ? 'ควรบริโภคก่อน(BBF)' : 'วันหมดอายุ(EXP)',
            'date_type': itemData['date_type'] ?? 'EXP',
            
            // เพิ่มข้อมูลเพิ่มเติมถ้ามี
            'description': itemData['description'] ?? '',
            'brand': itemData['brand'] ?? '',
          };
          
          // เพิ่ม debug เพื่อดูข้อมูลที่จะส่งไป
          print('Data to send to AddItemPage: $itemDataToSend');
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddItemPage(
                is_existing_item: false, // เปลี่ยนเป็น false เพื่อให้เป็นโหมดเพิ่มใหม่
                item_data: itemDataToSend,
              ),
            ),
          ).then((result) {
            if (result == true) {
              // Refresh data on IndexPage after adding item
              _indexPageState?.fetchItemsData();
            }
          });
        } else {
          // ไม่พบข้อมูลสิ่งของ - ให้ผู้ใช้เพิ่มใหม่
          _show_item_not_found_dialog(barcode);
        }
        } catch (e) {
          print('Error parsing JSON response: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาดในการประมวลผลข้อมูล: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการค้นหาข้อมูล'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // ปิด loading (ถ้ายังเปิดอยู่)
      print('Error searching item by barcode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _show_item_not_found_dialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ไม่พบข้อมูลสิ่งของ'),
        content: Text('ไม่พบสิ่งของที่มีรหัสบาร์โค้ด: $barcode\nคุณต้องการเพิ่มสิ่งของใหม่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // เพิ่มสิ่งของใหม่พร้อมรหัสบาร์โค้ด
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddItemPage(
                    is_existing_item: false,
                    item_data: {
                      'barcode': barcode,
                    },
                  ),
                ),
              ).then((result) {
                if (result == true) {
                  _indexPageState?.fetchItemsData();
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
            ),
            child: const Text('เพิ่มใหม่'),
          ),
        ],
      ),
    );
  }

  // Complete Filter Modal logic
  void _open_filter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the modal to take up more height
      builder: (context) {
        // StatefulBuilder allows us to update the UI within the modal itself
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8, // 80% of screen height
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header with Close button and Title
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'ตัวกรอง',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 48), // Spacer to balance the close button
                      ],
                    ),
                  ),
                  // Filter Options
                  Expanded(
                    child: _is_filter_options_loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            children: [
                              _build_filter_section_title('สถานที่จัดเก็บ'),
                              _build_dropdown_filter(
                                'เลือกสถานที่จัดเก็บ',
                                _selected_storage_location,
                                _storage_locations, // Options from API
                                (newValue) {
                                  setModalState(() {
                                    _selected_storage_location = newValue;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              _build_filter_section_title('หมวดหมู่'),
                              _build_dropdown_filter(
                                'เลือกหมวดหมู่',
                                _selected_category,
                                _categories, // Options from API
                                (newValue) {
                                  setModalState(() {
                                    _selected_category = newValue;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              _build_filter_section_title('เรียงตาม'),
                              _build_dropdown_filter(
                                'เลือกการเรียงลำดับ',
                                _selected_sort_order,
                                ['ชื่อ (ก-ฮ)', 'ชื่อ (ฮ-ก)', 'วันหมดอายุ (เร็วที่สุด)', 'วันหมดอายุ (ช้าที่สุด)'],
                                (newValue) {
                                  setModalState(() {
                                    _selected_sort_order = newValue;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              _build_filter_section_title('สถานะการหมดอายุ'),
                              _build_checkbox_filter(
                                'ทั้งหมด',
                                _filter_all,
                                (bool? value) {
                                  setModalState(() {
                                    _filter_all = value!;
                                    if (_filter_all) { // If "All" is checked, uncheck others
                                      _filter_expired = false;
                                      _filter_expiring_7_days = false;
                                      _filter_expiring_30_days = false;
                                    }
                                  });
                                },
                              ),
                              _build_checkbox_filter(
                                'หมดอายุแล้ว',
                                _filter_expired,
                                (bool? value) {
                                  setModalState(() {
                                    _filter_expired = value!;
                                    if (_filter_expired) _filter_all = false; // If this is checked, uncheck "All"
                                  });
                                },
                              ),
                              _build_checkbox_filter(
                                'ใกล้หมดอายุ (ภายใน 7 วัน)',
                                _filter_expiring_7_days,
                                (bool? value) {
                                  setModalState(() {
                                    _filter_expiring_7_days = value!;
                                    if (_filter_expiring_7_days) _filter_all = false; // Uncheck "All"
                                  });
                                },
                              ),
                              _build_checkbox_filter(
                                'ควรระวัง (ภายใน 30 วัน)',
                                _filter_expiring_30_days,
                                (bool? value) {
                                  setModalState(() {
                                    _filter_expiring_30_days = value!;
                                    if (_filter_expiring_30_days) _filter_all = false; // Uncheck "All"
                                  });
                                },
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                  ),
                  // Action buttons (Save and Reset)
                  _build_filter_action_buttons(setModalState), // Pass setModalState
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _build_filter_section_title(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
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

  Widget _build_dropdown_filter(String hint, String? currentValue, List<String> options, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint),
          value: currentValue,
          icon: const Icon(Icons.keyboard_arrow_down),
          iconSize: 24,
          elevation: 16,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          onChanged: onChanged,
          items: options.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _build_checkbox_filter(String title, bool value, ValueChanged<bool?> onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF4A90E2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _build_filter_action_buttons(StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Map<String, dynamic> filters = {};
                if (_selected_storage_location != null) {
                  filters['storage_location'] = _selected_storage_location;
                }
                if (_selected_category != null) {
                  filters['category'] = _selected_category;
                }
                if (_selected_sort_order != null) {
                  filters['sort_order'] = _selected_sort_order;
                }
                // Determine expiration status filter
                if (_filter_expired) {
                  filters['status'] = 'expired';
                } else if (_filter_expiring_7_days) {
                  filters['status'] = 'expiring_7_days';
                } else if (_filter_expiring_30_days) {
                  filters['status'] = 'expiring_30_days';
                } else if (_filter_all) {
                  filters['status'] = 'all'; // Pass 'all' if selected
                } else {
                  // If none of the specific status filters are checked, and 'all' isn't checked,
                  // it means no status filter is applied. Don't add 'status' to filters map.
                }

                // Call fetchItemsData on IndexPage with the collected filters
                _indexPageState?.fetchItemsData(filters: filters);
                Navigator.pop(context); // Close the modal
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'บันทึกข้อมูล',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                // Reset filter state variables in the modal
                setModalState(() {
                  _selected_storage_location = null;
                  _selected_category = null;
                  _selected_sort_order = null;
                  _filter_all = true; // Set "All" as default for reset
                  _filter_expired = false;
                  _filter_expiring_7_days = false;
                  _filter_expiring_30_days = false;
                });
                // Call fetchItemsData on IndexPage to clear filters (fetch all)
                _indexPageState?.fetchItemsData(filters: {}); // Pass empty filters
                Navigator.pop(context); // Close the modal
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4A90E2),
                side: const BorderSide(color: Color(0xFF4A90E2)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'รีเซ็ต',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF3E8FF), // ม่วงอ่อน (purple-50)
                Color(0xFFE9D5FF), // ม่วงกลาง (purple-100)
                Color(0xFFDDD6FE), // ม่วงไวโอเล็ต (violet-200)
                Color(0xFFF0E6FF), // ลาเวนเดอร์อ่อน
              ],
            ),
          ),
          child: SafeArea(
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: _selected_index == 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        _page_titles[_selected_index],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    )
                  : Text(
                      _page_titles[_selected_index],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
              centerTitle: _selected_index == 0 ? false : true,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_selected_index == 0)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 60, // เพิ่มจาก 45 เป็น 60
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16), // เพิ่มจาก 12 เป็น 16
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1.5, // เพิ่มความหนาจาก 1 เป็น 1.5
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _search_controller,
                        onChanged: _handle_search, // เปลี่ยนจาก onSubmitted เป็น onChanged
                        style: const TextStyle(
                          fontSize: 18, // เพิ่มขนาดตัวอักษรที่พิมพ์
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาสิ่งของของคุณ',
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 18, // เพิ่มจาก 14 เป็น 18
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                            size: 28, // เพิ่มจาก 20 เป็น 28
                          ),
                          suffixIcon: IconButton(
                            onPressed: _scan_barcode,
                            icon: const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.grey,
                              size: 28, // เพิ่มจาก 20 เป็น 28
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, // เพิ่มจาก 16 เป็น 20
                            vertical: 16, // เพิ่มจาก 12 เป็น 16
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12), // เพิ่มจาก 8 เป็น 12
                  Container(
                    width: 60, // เพิ่มจาก 45 เป็น 60
                    height: 60, // เพิ่มจาก 45 เป็น 60
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16), // เพิ่มจาก 12 เป็น 16
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1.5, // เพิ่มความหนาจาก 1 เป็น 1.5
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _open_filter, // Calls the full filter modal
                      icon: const Icon(
                        Icons.tune,
                        color: Colors.grey,
                        size: 28, // เพิ่มจาก 20 เป็น 28
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _selected_index,
              children: _pages,
            ),
          ),
        ],
      ),
      floatingActionButton: _selected_index == 0 ? Container(
        width: 70, // เพิ่มจาก 60 เป็น 70
        height: 70, // เพิ่มจาก 60 เป็น 70
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(35), // เพิ่มจาก 30 เป็น 35
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90E2).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          onPressed: _show_add_item_menu,
          icon: const Icon(
            Icons.add,
            color: Colors.white,
            size: 32, // เพิ่มจาก 28 เป็น 32
          ),
        ),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 78, 14, 255).withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selected_index,
          onTap: _on_tab_selected,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF4A90E2),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 16, // เพิ่มจาก 24 เป็น 16 (ที่เหมาะสม)
          unselectedFontSize: 14, // เพิ่มจาก 20 เป็น 14 (ที่เหมาะสม)
          selectedIconTheme: const IconThemeData(size: 28), // เพิ่มขนาด icon
          unselectedIconTheme: const IconThemeData(size: 24), // เพิ่มขนาด icon
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'หน้าแรก',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'ปฏิทิน',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'การแจ้งเตือน',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_outlined),
              activeIcon: Icon(Icons.menu),
              label: 'เมนู',
            ),
          ],
        ),
      ),
    );
  }
}