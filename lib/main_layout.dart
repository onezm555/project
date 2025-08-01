import 'package:flutter/material.dart';
import 'index.dart'; // Ensure this path is correct
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

  // GlobalKey to access IndexPage's state methods
  final GlobalKey<IndexPageState> _indexPageKey = GlobalKey<IndexPageState>();

  @override
  void initState() {
    super.initState();
    _selected_index = widget.initial_tab;
    _api_base_url = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project'; // Load API base URL
    _fetch_filter_options(); // Fetch filter dropdown options when MainLayout initializes
  }

  @override
  void dispose() {
    _search_controller.dispose();
    super.dispose();
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

  // List of pages, now using the GlobalKey for IndexPage
  late final List<Widget> _pages = [
    IndexPage(key: _indexPageKey), // Assign the GlobalKey here
    const CalendarPage(),
    const NotificationPage(),
    const MenuPage(),
  ];

  final List<String> _page_titles = [
    'หน้าแรก',
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
      _indexPageKey.currentState?.fetchItemsData(filters: {});
    } else {
      _indexPageKey.currentState?.fetchItemsData(filters: {'search_query': query});
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
                  'เพิ่มสินค้าใหม่',
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
                  'เพิ่มสินค้าที่มีอยู่(บาร์โค้ด)',
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
        _indexPageKey.currentState?.fetchItemsData();
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
        
        // ค้นหาข้อมูลสินค้าในฐานข้อมูลด้วยบาร์โค้ด
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

      // เรียก API เพื่อค้นหาสินค้าด้วยบาร์โค้ด
      final response = await http.get(
        Uri.parse('$_api_base_url/search_item_by_barcode.php?user_id=$userId&barcode=${Uri.encodeComponent(barcode)}')
      );

      Navigator.pop(context); // ปิด loading

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // เพิ่ม debug เพื่อดูข้อมูลที่ได้จาก API
        print('API Response: $data');
        
        if (data['success'] == true && data['data'] != null) {
          // พบข้อมูลสินค้า - นำไปยังหน้าเพิ่มสินค้าพร้อมข้อมูลเดิม
          final itemData = data['data'];
          
          // เพิ่ม debug เพื่อดูข้อมูลสินค้า
          print('Item Data: $itemData');
          
          // แสดงข้อความแจ้งเตือนก่อน
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('พบข้อมูลสินค้า: ${itemData['item_name']}'),
              backgroundColor: Colors.green,
            ),
          );
          
          final Map<String, dynamic> itemDataToSend = {
            'name': itemData['item_name'] ?? '',
            'item_name': itemData['item_name'] ?? '', // เพิ่มทั้งสองชื่อ field
            'category': itemData['category'] ?? '',
            'type_name': itemData['category'] ?? '', // เพิ่มทั้งสองชื่อ field
            'storage_location': itemData['storage_location'] ?? '',
            'area_name': itemData['storage_location'] ?? '', // เพิ่มทั้งสองชื่อ field
            'barcode': itemData['item_barcode'] ?? barcode,
            'unit': itemData['date_type'] == 'BBF' ? 'ควรบริโภคก่อน(BBF)' : 'วันหมดอายุ(EXP)',
            'date_type': itemData['date_type'] == 'BBF' ? 'ควรบริโภคก่อน(BBF)' : 'วันหมดอายุ(EXP)',
          };
          
          // เพิ่ม debug เพื่อดูข้อมูลที่จะส่งไป
          print('Data to send to AddItemPage: $itemDataToSend');
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddItemPage(
                is_existing_item: true, // เปลี่ยนเป็น true เพื่อให้เติมข้อมูลเดิม
                item_data: itemDataToSend,
              ),
            ),
          ).then((result) {
            if (result == true) {
              // Refresh data on IndexPage after adding item
              _indexPageKey.currentState?.fetchItemsData();
            }
          });
        } else {
          // ไม่พบข้อมูลสินค้า - ให้ผู้ใช้เพิ่มใหม่
          _show_item_not_found_dialog(barcode);
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
        title: const Text('ไม่พบข้อมูลสินค้า'),
        content: Text('ไม่พบสินค้าที่มีรหัสบาร์โค้ด: $barcode\nคุณต้องการเพิ่มสินค้าใหม่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // เพิ่มสินค้าใหม่พร้อมรหัสบาร์โค้ด
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
                  _indexPageKey.currentState?.fetchItemsData();
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
                _indexPageKey.currentState?.fetchItemsData(filters: filters);
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
                _indexPageKey.currentState?.fetchItemsData(filters: {}); // Pass empty filters
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
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _page_titles[_selected_index],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
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
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _search_controller,
                        onChanged: _handle_search, // เปลี่ยนจาก onSubmitted เป็น onChanged
                        decoration: InputDecoration(
                          hintText: 'ค้นหาสินค้าของคุณ',
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            onPressed: _scan_barcode,
                            icon: const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      onPressed: _open_filter, // Calls the full filter modal
                      icon: const Icon(
                        Icons.tune,
                        color: Colors.grey,
                        size: 20,
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
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
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
            size: 28,
          ),
        ),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
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
          selectedFontSize: 12,
          unselectedFontSize: 12,
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