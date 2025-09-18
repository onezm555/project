
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'item_detail_page.dart';

class IndexPageWorking extends StatefulWidget {
  final Function(Map<String, dynamic>)? onRefreshRequested;
  final Function(IndexPageWorkingState)? onStateCreated;
  
  const IndexPageWorking({Key? key, this.onRefreshRequested, this.onStateCreated}) : super(key: key);

  @override
  State<IndexPageWorking> createState() => IndexPageWorkingState();
}

class IndexPageWorkingState extends State<IndexPageWorking> {
  List<Map<String, dynamic>> _stored_items = [];
  bool _is_loading = true;
  String? _api_message;
  bool _is_true_error = false;
  String _api_base_url = '';
  Map<String, dynamic> _current_filters = {};

  @override
  void initState() {
    super.initState();
    _api_base_url = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project';
    fetchItemsData();
    // Notify parent widget that this state is created
    if (widget.onStateCreated != null) {
      widget.onStateCreated!(this);
    }
  }

  Future<void> fetchItemsData({Map<String, dynamic>? filters}) async {
    setState(() {
      _is_loading = true;
      _api_message = null;
      _is_true_error = false;
      _current_filters = filters ?? {};
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

    String url = '$_api_base_url/my_items.php?user_id=$user_id';
    
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
          
          List<dynamic> filteredItems = itemsData;
          
          if (filters != null && filters.containsKey('status')) {
            final statusFilter = filters['status'].toString();
            
            if (statusFilter == 'expired') {
              filteredItems = itemsData.where((item) {
                final itemStatus = item['item_status']?.toString().toLowerCase();
                final expireDate = item['earliest_expire_date'] ?? item['item_date'] ?? '';
                final daysLeft = _calculate_days_left(expireDate.toString());
                return itemStatus == 'active' && daysLeft < 0;
              }).toList();
            } else if (statusFilter == 'expiring_7_days') {
              filteredItems = itemsData.where((item) {
                final itemStatus = item['item_status']?.toString().toLowerCase();
                final expireDate = item['earliest_expire_date'] ?? item['item_date'] ?? '';
                final daysLeft = _calculate_days_left(expireDate.toString());
                return itemStatus == 'active' && daysLeft >= 0 && daysLeft <= 7;
              }).toList();
            } else if (statusFilter == 'expiring_30_days') {
              filteredItems = itemsData.where((item) {
                final itemStatus = item['item_status']?.toString().toLowerCase();
                final expireDate = item['earliest_expire_date'] ?? item['item_date'] ?? '';
                final daysLeft = _calculate_days_left(expireDate.toString());
                return itemStatus == 'active' && daysLeft >= 0 && daysLeft <= 30;
              }).toList();
            }
          }

          // ลบการจัดเรียงข้อมูลออก เพราะให้ Backend จัดการแล้ว
          // if (filters != null && filters.containsKey('sort_order')) {
          //   ... (โค้ดเรียงลำดับที่ลบออก)
          // }

          setState(() {
            _stored_items = List<Map<String, dynamic>>.from(filteredItems);
            _is_loading = false;
            _api_message = null;
          });
        } else {
          setState(() {
            _stored_items = [];
            _is_loading = false;
            _api_message = responseData['message'] ?? 'Failed to fetch data.';
            _is_true_error = false;
          });
        }
      } else {
        setState(() {
          _stored_items = [];
          _is_loading = false;
          _api_message = 'HTTP Error: ${response.statusCode}';
          _is_true_error = true;
        });
      }
    } catch (e) {
      setState(() {
        _stored_items = [];
        _is_loading = false;
        _api_message = 'Error: $e';
        _is_true_error = true;
      });
    }
  }

  int _calculate_days_left(String? expireDate) {
    if (expireDate == null || expireDate.isEmpty) return 999;
    try {
      final expire = DateTime.parse(expireDate);
      final now = DateTime.now();
      final nowDate = DateTime(now.year, now.month, now.day);
      final expireOnlyDate = DateTime(expire.year, expire.month, expire.day);
      return expireOnlyDate.difference(nowDate).inDays;
    } catch (e) {
      return 999;
    }
  }

  // ฟังก์ชันสำหรับเรียงลำดับกลุ่มสิ่งของตาม sort_order
  void _sortItemGroup(List<Map<String, dynamic>> items) {
    final sortOrder = _current_filters['sort_order']?.toString();
    
    if (sortOrder == 'ชื่อ (ก-ฮ)') {
      items.sort((a, b) {
        final nameA = (a['item_name'] ?? '').toString();
        final nameB = (b['item_name'] ?? '').toString();
        return nameA.compareTo(nameB);
      });
    } else if (sortOrder == 'ชื่อ (ฮ-ก)') {
      items.sort((a, b) {
        final nameA = (a['item_name'] ?? '').toString();
        final nameB = (b['item_name'] ?? '').toString();
        return nameB.compareTo(nameA);
      });
    } else if (sortOrder == 'วันหมดอายุ (เร็วที่สุด)') {
      items.sort((a, b) {
        final expireDateA = a['earliest_expire_date'] ?? a['item_date'] ?? '';
        final expireDateB = b['earliest_expire_date'] ?? b['item_date'] ?? '';
        final daysA = _calculate_days_left(expireDateA.toString());
        final daysB = _calculate_days_left(expireDateB.toString());
        return daysA.compareTo(daysB);
      });
    } else if (sortOrder == 'วันหมดอายุ (ช้าที่สุด)') {
      items.sort((a, b) {
        final expireDateA = a['earliest_expire_date'] ?? a['item_date'] ?? '';
        final expireDateB = b['earliest_expire_date'] ?? b['item_date'] ?? '';
        final daysA = _calculate_days_left(expireDateA.toString());
        final daysB = _calculate_days_left(expireDateB.toString());
        return daysB.compareTo(daysA);
      });
    } else {
      // Default: เรียงตามวันหมดอายุ (เร็วที่สุด)
      items.sort((a, b) {
        final expireDateA = a['earliest_expire_date'] ?? a['item_date'] ?? '';
        final expireDateB = b['earliest_expire_date'] ?? b['item_date'] ?? '';
        final daysA = _calculate_days_left(expireDateA.toString());
        final daysB = _calculate_days_left(expireDateB.toString());
        return daysA.compareTo(daysB);
      });
    }
  }

  // ฟังก์ชันสำหรับจัดกลุ่มสิ่งของและเพิ่มหัวข้อ
  List<Map<String, dynamic>> _getItemsWithHeaders() {
    List<Map<String, dynamic>> result = [];
    
    // ตรวจสอบว่ามีการใช้ตัวกรองหรือไม่ (ยกเว้น item_status ที่เป็น default)
    bool hasActiveFilter = _current_filters.keys.any((key) => 
      key != 'item_status' && _current_filters[key] != null && _current_filters[key].toString().isNotEmpty
    );
    
    // หากมีการใช้ตัวกรอง ให้แสดงทั้งหมดโดยไม่แยกกลุ่ม
    if (hasActiveFilter) {
      _sortItemGroup(_stored_items);
      for (var item in _stored_items) {
        result.add({'isHeader': false, 'item': item});
      }
      return result;
    }
    
    // หากไม่มีการกรอง ให้แยกกลุ่มตามปกติ
    // แยกสิ่งของตามสถานะ
    List<Map<String, dynamic>> expiredItems = [];
    List<Map<String, dynamic>> expiringSoon7Items = []; // <= 7 วัน
    List<Map<String, dynamic>> normalItems = []; // > 7 วัน
    
    for (var item in _stored_items) {
      final expireDate = item['earliest_expire_date'] ?? item['item_date'] ?? '';
      final daysLeft = _calculate_days_left(expireDate.toString());
      
      if (daysLeft < 0) {
        expiredItems.add(item);
      } else if (daysLeft <= 7) {
        expiringSoon7Items.add(item);
      } else {
        normalItems.add(item);
      }
    }
    
    // จัดเรียงแต่ละกลุ่มตาม sort_order ที่ผู้ใช้เลือก
    _sortItemGroup(expiredItems);
    _sortItemGroup(expiringSoon7Items);
    _sortItemGroup(normalItems);
    
    // เพิ่มหัวข้อและรายการ
    if (expiredItems.isNotEmpty) {
      result.add({'isHeader': true, 'title': 'หมดอายุแล้ว (${expiredItems.length})','textColor': Color(0xFFD32F2F)}); 
      for (var item in expiredItems) {
        result.add({'isHeader': false, 'item': item});
      }
    }
    
    if (expiringSoon7Items.isNotEmpty) {
      result.add({'isHeader': true, 'title': 'สิ่งของใกล้หมดอายุน้อยกว่า7วัน (${expiringSoon7Items.length})','textColor': Color(0xFFFF9800)}); 
      for (var item in expiringSoon7Items) {
        result.add({'isHeader': false, 'item': item});
      }
    }
    
    if (normalItems.isNotEmpty) {
      result.add({'isHeader': true, 'title': 'สิ่งของวันหมดอายุมากกว่า7วัน (${normalItems.length})','textColor': Color(0xFF1976D2)}); // สีน้ำเงินเข้ม
      for (var item in normalItems) {
        result.add({'isHeader': false, 'item': item});
      }
    }
    
    return result;
  }

  // ฟังก์ชันสำหรับสร้างหัวข้อส่วน
  Widget _buildSectionHeader(String title, {Color textColor = Colors.black}) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor, 
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_is_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_api_message != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _is_true_error ? Icons.error : Icons.info,
              size: 64,
              color: _is_true_error ? Colors.red : Colors.blue,
            ),
            const SizedBox(height: 16),
            Text(
              _api_message!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => fetchItemsData(),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_stored_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'ไม่มีสิ่งของในตู้เก็บของ',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => fetchItemsData(filters: _current_filters),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _getItemsWithHeaders().length,
        itemBuilder: (context, index) {
          final itemWithHeader = _getItemsWithHeaders()[index];
          if (itemWithHeader['isHeader'] == true) {
            return _buildSectionHeader(
              itemWithHeader['title'], 
              textColor: itemWithHeader['textColor'] ?? Colors.black
            );
          } else {
            return _buildItemCard(itemWithHeader['item']);
          }
        },
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final itemName = item['item_name']?.toString() ?? 'ไม่ระบุชื่อ';
    final quantity = item['total_quantity'] ?? item['quantity'] ?? item['item_number'] ?? 0;
    
    // ใช้ earliest_expire_date เป็นหลัก หรือ fallback เป็น item_date
    final expireDate = item['earliest_expire_date'] ?? item['item_date'] ?? '';
    final daysLeft = _calculate_days_left(expireDate.toString());
    
    final imageUrl = item['item_img_full_url']?.toString() ?? '';
    // กรองพื้นที่เก็บเฉพาะที่มี status เป็น active
    final storageLocation = _getActiveStorageLocations(item);
    final dateType = item['date_type']?.toString() ?? 'EXP';
    final category = item['category']?.toString() ?? item['type_name']?.toString() ?? '';

    // กำหนดสีของการ์ดและกรอบตามสถานะ
    Color textColor = Colors.green.shade700;
    Color borderColor;
    Gradient cardGradient;
    
    if (daysLeft < 0) {
      // หมดอายุแล้ว - สีแดง
      textColor = Colors.red.shade700;
      borderColor = Colors.red.shade400;
      cardGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFEE2E2), // from-red-100 → #FEE2E2
          Color(0xFFFBCFE8), // to-pink-200 → #FBCFE8
        ],
      );
    } else if (daysLeft <= 7) {
      // ใกล้หมดอายุ (≤7 วัน) - สีเหลือง-ส้ม
      textColor = Colors.orange.shade700;
      borderColor = Colors.orange.shade400;
      cardGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFEF9C3), // from-yellow-100 → #FEF9C3
          Color(0xFFFED7AA), // to-orange-200 → #FED7AA
        ],
      );
    } else {
      // สิ่งของปกติ (> 7 วัน) - สีเขียว
      textColor = Colors.green.shade700;
      borderColor = Colors.green.shade400;
      cardGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFDCFCE7), // from-green-100 → #DCFCE7
          Color(0xFFA7F3D0), // to-emerald-200 → #A7F3D0
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2), // ใช้สีกรอบที่กำหนด และเพิ่มความหนา
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.2), // เงาสีเดียวกับกรอบ
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemDetailPage(
                item_data: item,
              ),
            ),
          ).then((_) {
            fetchItemsData(filters: _current_filters);
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20), // เพิ่ม padding จาก 16 เป็น 20
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row - สถานที่อยู่ด้านขาง (บน)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      itemName,
                      style: const TextStyle(
                        fontSize: 20, // เพิ่มจาก 16 เป็น 20
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Storage Location (ด้านขาง-บน)
                  if (storageLocation.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF), // ม่วงอ่อน
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFDDD6FE), // ม่วงกลาง
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: const Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            storageLocation,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7C3AED), // ม่วงเข้ม
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC), // เทาอ่อนกว่า
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0), // เทากลาง
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_off,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ไม่ระบุ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              // Content Row - รูปภาพและรายละเอียด
              Row(
                children: [
                  // Item Image - ปรับขนาดให้ใหญ่ขึ้น
                  Container(
                    width: 80, // เพิ่มจาก 60 เป็น 80
                    height: 80, // เพิ่มจาก 60 เป็น 80
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12), // เพิ่มจาก 8 เป็น 12
                      color: Colors.grey.shade200,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12), // เพิ่มจาก 8 เป็น 12
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.inventory, color: Colors.grey, size: 40); // เพิ่มขนาด icon
                              },
                            )
                          : const Icon(Icons.inventory, color: Colors.grey, size: 40), // เพิ่มขนาด icon
                    ),
                  ),
                  const SizedBox(width: 20), // เพิ่มจาก 16 เป็น 20
                  // Item Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'จำนวน: $quantity',
                          style: TextStyle(
                            fontSize: 18, // เพิ่มจาก 14 เป็น 16
                            color: const Color.fromARGB(255, 0, 0, 0),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (category.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'ประเภท: $category',
                            style: TextStyle(
                              fontSize: 16, // เพิ่มจาก 12 เป็น 14
                              color: const Color.fromARGB(255, 0, 0, 0),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // แสดงวันหมดอายุในรูปแบบ Grid 2 คอลัมน์
                        _buildExpireDateWidget(item, dateType, textColor),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getActiveStorageLocations(Map<String, dynamic> item) {
    final itemExpireDetails = item['item_expire_details'] as List?;
    
    if (itemExpireDetails == null || itemExpireDetails.isEmpty) {
      // ถ้าไม่มี item_expire_details ให้ใช้ข้อมูลหลัก
      return item['storage_info']?.toString() ?? item['storage_location']?.toString() ?? '';
    }
    
    // กรองเฉพาะสิ่งของที่ active และรวบรวมพื้นที่เก็บ
    final activeDetails = itemExpireDetails
        .where((detail) => detail['status'] == 'active')
        .toList();
    
    if (activeDetails.isEmpty) {
      return '';
    }
    
    // รวบรวมพื้นที่เก็บที่ไม่ซ้ำจาก active details
    Set<String> activeStorageLocations = {};
    for (var detail in activeDetails) {
      final areaName = detail['area_name']?.toString() ?? '';
      if (areaName.isNotEmpty) {
        activeStorageLocations.add(areaName);
      }
    }
    
    // ถ้าไม่มีพื้นที่เก็บใน details ให้ใช้ข้อมูลหลัก
    if (activeStorageLocations.isEmpty) {
      return item['storage_info']?.toString() ?? item['storage_location']?.toString() ?? '';
    }
    
    // รวมพื้นที่เก็บเป็น string โดยคั่นด้วยเครื่องหมายจุลภาค
    return activeStorageLocations.join(', ');
  }

  Widget _buildExpireDateWidget(Map<String, dynamic> item, String dateType, Color textColor) {
    final itemExpireDetails = item['item_expire_details'] as List?;
    
    if (itemExpireDetails == null || itemExpireDetails.isEmpty) {
      // ถ้าไม่มี item_expire_details ให้ใช้ข้อมูลหลัก
      final expireDate = item['earliest_expire_date'] ?? item['item_date'] ?? '';
      final daysLeft = _calculate_days_left(expireDate.toString());
      return Text(
        _format_simple_expire_date(expireDate, daysLeft, dateType),
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    
    // กรองเฉพาะสิ่งของที่ active และจัดเรียงตามวันหมดอายุ
    final activeDetails = itemExpireDetails
        .where((detail) => detail['status'] == 'active')
        .toList();
    
    if (activeDetails.isEmpty) {
      return Text(
        'ไม่มีสิ่งของที่ยังใช้ได้',
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    
    // จัดเรียงตามวันหมดอายุ
    activeDetails.sort((a, b) {
      final dateA = a['expire_date'] ?? '';
      final dateB = b['expire_date'] ?? '';
      return dateA.toString().compareTo(dateB.toString());
    });
    
    // สร้าง Map เพื่อนับจำนวนในแต่ละวัน
    Map<String, int> dateQuantityMap = {};
    for (var detail in activeDetails) {
      final date = detail['expire_date'] ?? '';
      final quantity = (detail['quantity'] ?? 1) as int;
      dateQuantityMap[date] = (dateQuantityMap[date] ?? 0) + quantity;
    }
    
    // เอาวันที่ไม่ซ้ำมาเรียงลำดับ
    final uniqueDates = dateQuantityMap.keys.toList();
    uniqueDates.sort();
    
    List<Widget> dateWidgets = [];
    
    // แสดงสูงสุด 3 วัน
    final maxShow = 3;
    final showDates = uniqueDates.take(maxShow).toList();
    
    for (final date in showDates) {
      final quantity = dateQuantityMap[date] ?? 0;
      final daysLeft = _calculate_days_left(date);
      final dateText = _format_simple_expire_date(date, daysLeft, dateType);
      
      String displayText;
      if (uniqueDates.length == 1) {
        displayText = dateText;
      } else {
        displayText = '$dateText ($quantity)';
      }
      
      dateWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(right: 6, bottom: 4),
          decoration: BoxDecoration(
            color: textColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: textColor.withOpacity(0.3), width: 2),
          ),
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: 12,
              color: const Color.fromARGB(255, 0, 0, 0),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    // ถ้ามีมากกว่า 3 วัน ให้แสดง "อื่นๆ"
    if (uniqueDates.length > maxShow) {
      final remainingDates = uniqueDates.length - maxShow;
      
      dateWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(right: 6, bottom: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
          ),
          child: Text(
            'อื่นๆ +$remainingDates',
            style: TextStyle(
              fontSize: 12,
              color: const Color.fromARGB(255, 0, 0, 0),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    // แสดงในรูปแบบ Wrap แถวละ 2 อัน
    return Wrap(
      children: dateWidgets,
      runSpacing: 4, // ระยะห่างระหว่างแถว
      spacing: 0, // ไม่ต้องมี spacing เพราะมี margin ใน Container แล้ว
    );
  }

  String _format_simple_expire_date(String expire_date, int days_left, String date_type) {
    String label = 'หมดอายุ';
    if (date_type == 'BBF') {
      label = 'ควรบริโภคก่อน';
    }
    
    if (days_left < 0) {
      if (date_type == 'BBF') {
        return 'เลยวันควรบริโภคก่อนแล้ว ${days_left.abs()} วัน';
      } else {
        return '${label}แล้ว ${days_left.abs()} วัน';
      }
    } else if (days_left == 0) {
      return '${label}วันนี้';
    } else if (days_left == 1) {
      return '${label}พรุ่งนี้';
    } else if (days_left <= 30) {
      return '${label}อีก $days_left วัน';
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
