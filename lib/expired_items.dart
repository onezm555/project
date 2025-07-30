import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'item_detail_page.dart'; // ตรวจสอบให้แน่ใจว่า import ถูกต้อง

class ExpiredItemsPage extends StatefulWidget {
  const ExpiredItemsPage({Key? key}) : super(key: key);

  @override
  State<ExpiredItemsPage> createState() => _ExpiredItemsPageState();
}

class _ExpiredItemsPageState extends State<ExpiredItemsPage> {
  List<Map<String, dynamic>> _stored_items = [];
  List<Map<String, dynamic>> _filtered_items = [];
  bool _is_loading = true;
  String? _api_message;
  bool _is_true_error = false;
  String _api_base_url = '';
  String _selected_category = 'ทั้งหมด';
  String _selected_storage = 'ทั้งหมด';
  String _search_query = '';
  List<String> _available_categories = ['ทั้งหมด'];
  List<String> _available_storages = ['ทั้งหมด'];
  bool _show_filters = false;
  final TextEditingController _search_controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _api_base_url = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project';
    fetchExpiredItemsData();
  }

  @override
  void dispose() {
    _search_controller.dispose();
    super.dispose();
  }

  // ฟังก์ชันดึงรายการพื้นที่จัดเก็บจาก API
  Future<List<String>> _fetch_storages_from_api() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user_id = prefs.getInt('user_id');
      
      if (user_id == null) return ['ทั้งหมด'];

      String url = '$_api_base_url/my_items.php?user_id=$user_id&status=all_expired';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        if (responseData['success'] == true) {
          List<dynamic> itemsData = responseData['data'] ?? [];
          Set<String> storages = {'ทั้งหมด'};
          
          for (var item in itemsData) {
            String storage = item['storage_location'] ?? '';
            if (storage.isNotEmpty) {
              storages.add(storage);
            }
          }
          
          List<String> sortedStorages = storages.toList()..sort();
          // ย้าย "ทั้งหมด" มาข้างหน้า
          sortedStorages.remove('ทั้งหมด');
          sortedStorages.insert(0, 'ทั้งหมด');
          
          return sortedStorages;
        }
      }
    } catch (e) {
      debugPrint('Error fetching storages: $e');
    }
    
    return ['ทั้งหมด'];
  }

  // ฟังก์ชันดึงรายการหมวดหมู่จาก API
  Future<List<String>> _fetch_categories_from_api() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user_id = prefs.getInt('user_id');
      
      if (user_id == null) return ['ทั้งหมด'];

      String url = '$_api_base_url/my_items.php?user_id=$user_id&status=all_expired';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        if (responseData['success'] == true) {
          List<dynamic> itemsData = responseData['data'] ?? [];
          Set<String> categories = {'ทั้งหมด'};
          
          for (var item in itemsData) {
            String category = item['category'] ?? '';
            if (category.isNotEmpty) {
              categories.add(category);
            }
          }
          
          List<String> sortedCategories = categories.toList()..sort();
          // ย้าย "ทั้งหมด" มาข้างหน้า
          sortedCategories.remove('ทั้งหมด');
          sortedCategories.insert(0, 'ทั้งหมด');
          
          return sortedCategories;
        }
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
    
    return ['ทั้งหมด'];
  }

  // ฟังก์ชันอัพเดทรายการหมวดหมู่และกรองข้อมูล
  Future<void> _update_categories_and_filter() async {
    // ดึงหมวดหมู่และพื้นที่จัดเก็บจาก API
    _available_categories = await _fetch_categories_from_api();
    _available_storages = await _fetch_storages_from_api();
    
    // กรองรายการตามเงื่อนไขต่างๆ
    _filtered_items = _stored_items.where((item) {
      // กรองตามหมวดหมู่
      bool categoryMatch = true;
      if (_selected_category != 'ทั้งหมด') {
        String itemCategory = item['category'] ?? '';
        categoryMatch = itemCategory == _selected_category;
      }
      
      // กรองตามพื้นที่จัดเก็บ
      bool storageMatch = true;
      if (_selected_storage != 'ทั้งหมด') {
        String itemStorage = item['storage_location'] ?? '';
        storageMatch = itemStorage == _selected_storage;
      }
      
      // กรองตามการค้นหา
      bool searchMatch = true;
      if (_search_query.isNotEmpty) {
        String itemName = (item['item_name'] ?? '').toLowerCase();
        String barcode = (item['item_barcode'] ?? '').toLowerCase();
        String searchLower = _search_query.toLowerCase();
        searchMatch = itemName.contains(searchLower) || barcode.contains(searchLower);
      }
      
      return categoryMatch && storageMatch && searchMatch;
    }).toList();
  }

  Future<void> fetchExpiredItemsData() async {
    setState(() {
      _is_loading = true;
      _api_message = null;
      _is_true_error = false;
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

    // แก้ไข: เพิ่ม status=all_expired เพื่อดึงทั้ง 'expired' และ 'disposed'
    String url = '$_api_base_url/my_items.php?user_id=$user_id&status=all_expired&order_by=desc';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          List<dynamic> itemsData = responseData['data'] ?? [];
          setState(() {
            // กรองรายการที่ไม่ใช่ 'expired' หรือ 'disposed' ออกไป
            _stored_items = itemsData
                .where((item) {
                  final status = item['item_status'] as String?;
                  return status == 'expired' || status == 'disposed';
                })
                .map((item) => item as Map<String, dynamic>)
                .toList();
            _is_loading = false;
          });
          
          // อัพเดทหมวดหมู่และกรองข้อมูลหลังจาก setState
          await _update_categories_and_filter();
          setState(() {}); // รีเฟรช UI หลังจากอัพเดทหมวดหมู่
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

  // Helper function to calculate days left (reused from index.dart)
  int _calculate_days_left(String item_date) {
    try {
      final expire_date = DateTime.parse(item_date);
      final today = DateTime.now();
      return expire_date.difference(today).inDays;
    } catch (e) {
      return -9999; // Indicate an error or invalid date
    }
  }

  // Helper function to get status text and color based on item_status
  Map<String, dynamic> _get_status_info(String item_status, int days_left) {
    if (item_status == 'expired') {
      return {'text': 'หมดอายุแล้ว', 'color': Colors.red};
    } else if (item_status == 'disposed') {
      return {'text': 'ใช้หมดแล้ว', 'color': Colors.grey};
    }
    // กรณี fallback ที่ item_status ไม่ใช่ 'expired' หรือ 'disposed'
    // และเลยวันหมดอายุ (ควรถูกกรองไปแล้วโดย where clause ด้านบน)
    if (days_left < 0) {
      return {'text': 'หมดอายุแล้ว (จากวันหมดอายุ)', 'color': Colors.orange};
    }
    // สำหรับสถานะอื่นๆ รวมถึง 'active' ที่ควรถูกกรองไปแล้ว
    return {'text': '', 'color': Colors.transparent}; // คืนค่าว่างเปล่าเพื่อไม่แสดง
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'รายการที่หมดอายุ/ใช้หมดแล้ว',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
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
                    onPressed: fetchExpiredItemsData, // Retry fetching data
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
                    'ไม่พบรายการที่หมดอายุหรือใช้หมดแล้ว',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // ส่วนค้นหาและฟิลเตอร์
                Container(
                  margin: const EdgeInsets.all(16),
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
                      // แถบค้นหาและปุ่มฟิลเตอร์
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _search_controller,
                              decoration: InputDecoration(
                                hintText: 'ค้นหาชื่อสินค้าหรือบาร์โค้ด...',
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF4A90E2)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _search_query = value;
                                });
                                _update_categories_and_filter().then((_) {
                                  setState(() {});
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: _show_filters ? const Color(0xFF4A90E2) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _show_filters ? const Color(0xFF4A90E2) : Colors.grey[300]!,
                              ),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.filter_list,
                                color: _show_filters ? Colors.white : Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(() {
                                  _show_filters = !_show_filters;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      // ส่วนฟิลเตอร์ (แสดงเมื่อ _show_filters = true)
                      if (_show_filters) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        
                        // ฟิลเตอร์หมวดหมู่สินค้า
                        Row(
                          children: [
                            const SizedBox(width: 100, child: Text('สินค้า:', style: TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selected_category,
                                    isExpanded: true,
                                    items: _available_categories.map((String category) {
                                      return DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(category),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) async {
                                      if (newValue != null) {
                                        setState(() {
                                          _selected_category = newValue;
                                        });
                                        await _update_categories_and_filter();
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // ฟิลเตอร์พื้นที่จัดเก็บ
                        Row(
                          children: [
                            const SizedBox(width: 100, child: Text('พื้นที่:', style: TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selected_storage,
                                    isExpanded: true,
                                    items: _available_storages.map((String storage) {
                                      return DropdownMenuItem<String>(
                                        value: storage,
                                        child: Text(storage),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) async {
                                      if (newValue != null) {
                                        setState(() {
                                          _selected_storage = newValue;
                                        });
                                        await _update_categories_and_filter();
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // ปุ่มรีเซ็ตฟิลเตอร์
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              setState(() {
                                _selected_category = 'ทั้งหมด';
                                _selected_storage = 'ทั้งหมด';
                                _search_query = '';
                                _search_controller.clear();
                              });
                              await _update_categories_and_filter();
                              setState(() {});
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('รีเซ็ตฟิลเตอร์'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                      
                      // แสดงจำนวนที่กรองแล้ว
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'แสดง ${_filtered_items.length} รายการจากทั้งหมด ${_stored_items.length} รายการ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // รายการสินค้า
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtered_items.length,
                    itemBuilder: (context, index) {
                      final item = _filtered_items[index];
                      final days_left = _calculate_days_left(item['item_date'] ?? '');
                      final status_info = _get_status_info(item['item_status'] ?? '', days_left);
                      final category = item['category'] ?? 'ไม่ระบุ';

                      return _build_item_card(
                        item: item,
                        days_left: days_left,
                        status_text: status_info['text'],
                        status_color: status_info['color'],
                        category: category,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  // Widget for building an item card (reused from index.dart, with minor adjustments for onTap)
  Widget _build_item_card({
    required Map<String, dynamic> item,
    required int days_left,
    required String status_text,
    required Color status_color,
    required String category,
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
                'storage_location':
                    item['area_name'] ?? item['storage_location'],
                'item_date': item['item_date'],
                'item_img': item['item_img_full_url'],
              },
            ),
          ),
        );
        if (result == true) {
          fetchExpiredItemsData(); // Refresh data if an item was modified/deleted
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
            // Image
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
                        (item['item_img_full_url'] as String) !=
                            'lib/img/default.png'
                    ? Image.network(
                        item['item_img_full_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.image,
                              color: Colors.grey,
                              size: 30,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.image,
                          color: Colors.grey,
                          size: 30,
                        ),
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
                            // แสดงประเภทสินค้า
                            Text(
                              'สินค้า: $category',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // แสดงสถานะที่ได้จาก _get_status_info
                            // จะแสดงเฉพาะเมื่อ status_text ไม่ว่างเปล่า
                            if (status_text.isNotEmpty)
                              Text(
                                status_text, // ใช้ status_text ที่ได้จาก _get_status_info
                                style: TextStyle(
                                  fontSize: 14,
                                  color: status_color, // ใช้ status_color ที่ได้จาก _get_status_info
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Storage location
                      if ((item['storage_location'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 8, top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
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
                  // แสดงสถานะเสริม เช่น 'หมดอายุแล้ว', 'ใช้หมดแล้ว'
                  // ในหน้านี้เราจะใช้ status_text ที่มาจาก item_status เป็นหลัก
                  // ดังนั้นไม่จำเป็นต้องแสดง Container ซ้ำหาก status_text ถูกแสดงไปแล้ว
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}