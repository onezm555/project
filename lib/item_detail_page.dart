import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'add_item.dart';

class ItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item_data;

  const ItemDetailPage({
    Key? key,
    required this.item_data,
  }) : super(key: key);

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  // Controllers to display data (will be initialized in initState)
  final TextEditingController _name_controller = TextEditingController();
  final TextEditingController _quantity_controller = TextEditingController();
  final TextEditingController _barcode_controller = TextEditingController();
  final TextEditingController _notification_days_controller = TextEditingController();

  // Variables to display data
  DateTime _selected_date = DateTime.now();
  String _selected_unit = '';
  String _selected_category = '';
  String _selected_storage = '';

  // ฟังก์ชันโหลดข้อมูล item ล่าสุดจาก API
  Future<void> _reload_item_data() async {
    int? itemId = widget.item_data['item_id'] ?? widget.item_data['id'];
    if (itemId == null) return;
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/get_item.php?item_id=$itemId'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success' && data['item'] != null) {
          setState(() {
            widget.item_data.clear();
            widget.item_data.addAll(data['item']);
            _populate_fields();
          });
        }
      }
    } catch (e) {
      debugPrint('Error reloading item data: $e');
    }
  }
  late String _apiBaseUrl;

  @override
  void initState() {
    super.initState();
    // ดึงค่าจาก .env
    _apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project';
    _populate_fields();
  }

  void _populate_fields() {
    final item = widget.item_data;

    _name_controller.text = item['name'] ?? '';
    _quantity_controller.text = item['quantity']?.toString() ?? '1';
    _barcode_controller.text = item['barcode'] ?? '';
    _notification_days_controller.text = (item['item_notification'] != null && item['item_notification'].toString().trim().isNotEmpty)
        ? item['item_notification'].toString()
        : '-';

    final rawUnit = item['unit'] ?? item['date_type'] ?? 'วันหมดอายุ(EXP)';
    if (rawUnit == 'EXP') {
      _selected_unit = 'วันหมดอายุ(EXP)';
    } else if (rawUnit == 'BBF') {
      _selected_unit = 'ควรบริโภคก่อน(BBF)';
    } else {
      _selected_unit = rawUnit;
    }
    _selected_category = item['category'] ?? 'เลือกประเภท';
    _selected_storage = item['storage_location'] ?? 'เลือกพื้นที่จัดเก็บ';

    if (item['item_date'] != null) {
      try {
        _selected_date = DateTime.parse(item['item_date']);
      } catch (e) {
        debugPrint('Error parsing date: ${item['item_date']} - $e');
        _selected_date = DateTime.now().add(const Duration(days: 7));
      }
    }
  }

  Future<void> _delete_item() async {
    // Show a confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบสิ่งของนี้?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // User confirms
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ลบ', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false; // In case dialog is dismissed without selection

    if (!confirmDelete) {
      return; // If user cancels, do nothing
    }

    final String url = '$_apiBaseUrl/delete_item.php'; // ใช้ _apiBaseUrl ที่ได้จาก .env
    // รองรับทั้ง item_id และ id
    int? itemId = widget.item_data['item_id'];
    if (itemId == null && widget.item_data['id'] != null) {
      // บางหน้าส่งมาเป็น 'id' แทน 'item_id'
      itemId = widget.item_data['id'] is int
          ? widget.item_data['id']
          : int.tryParse(widget.item_data['id'].toString());
    }

    int? userId = widget.item_data['user_id'];
    if (userId == null) {
      // ถ้าไม่มี user_id ใน item_data ให้ดึงจาก SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getInt('user_id');
      } catch (e) {
        debugPrint('Error loading user_id from SharedPreferences: $e');
      }
    }

    if (itemId == null || userId == null) {
      _show_snackbar('Error: Item ID or User ID is missing.', Colors.red);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        body: {
          'item_id': itemId.toString(),
          'user_id': userId.toString(),
        },
      );

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        _show_snackbar(responseData['message'] ?? 'Item deleted successfully!', Colors.green);
        // Navigate back after successful deletion, likely to the previous list page
        Navigator.of(context).pop(true); // Pass true to indicate a change occurred
      } else {
        _show_snackbar(responseData['message'] ?? 'Failed to delete item.', Colors.red);
      }
    } catch (e) {
      debugPrint('Error deleting item: $e');
      _show_snackbar('An error occurred: ${e.toString()}', Colors.red);
    }
  }

  void _show_snackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _show_discard_options_dialog() async {
    // ตรวจสอบว่ามีรายละเอียดแต่ละชิ้นหรือไม่
    final item_expire_details = widget.item_data['item_expire_details'] as List?;
    
    if (item_expire_details != null && item_expire_details.isNotEmpty) {
      // แสดงรายการแต่ละชิ้นให้เลือก
      _show_item_selection_dialog();
    } else {
      // แสดง dialog แบบเดิมสำหรับเลือกจำนวน
      _show_traditional_discard_dialog();
    }
  }

  Future<void> _show_item_selection_dialog() async {
    final item_expire_details = widget.item_data['item_expire_details'] as List;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ปุ่มปิด X ด้านบน
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'เลือกชิ้นที่ต้องการจัดการ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // รายการชิ้นต่างๆ
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: item_expire_details.length,
                    itemBuilder: (context, index) {
                      final detail = item_expire_details[index];
                      final item_number = index + 1;
                      
                      // คำนวณวันหมดอายุ
                      DateTime? expire_date;
                      String expire_text = 'ไม่ระบุ';
                      Color expire_color = Colors.grey;
                      
                      try {
                        expire_date = DateTime.parse(detail['expire_date']);
                        final days_left = expire_date.difference(DateTime.now()).inDays;
                        
                        if (days_left < 0) {
                          expire_text = 'หมดอายุแล้ว ${days_left.abs()} วัน';
                          expire_color = Colors.red;
                        } else if (days_left == 0) {
                          expire_text = 'หมดอายุวันนี้';
                          expire_color = Colors.red;
                        } else if (days_left == 1) {
                          expire_text = 'หมดอายุพรุ่งนี้';
                          expire_color = Colors.orange;
                        } else if (days_left <= 7) {
                          expire_text = 'หมดอายุอีก $days_left วัน';
                          expire_color = Colors.orange;
                        } else if (days_left <= 30) {
                          expire_text = 'หมดอายุอีก $days_left วัน';
                          expire_color = Colors.blue;
                        } else {
                          // แสดงวันที่เต็ม
                          final months = [
                            '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
                            'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
                          ];
                          final buddhist_year = expire_date.year + 543;
                          expire_text = 'หมดอายุ ${expire_date.day} ${months[expire_date.month]} $buddhist_year';
                          expire_color = Colors.green;
                        }
                      } catch (e) {
                        expire_text = 'ไม่ระบุวันหมดอายุ';
                        expire_color = Colors.grey;
                      }
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // หัวข้อชิ้นที่และสถานะ
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ชิ้นที่ $item_number',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                // สถานะวันหมดอายุ
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: expire_color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    expire_text,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: expire_color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // รายละเอียด
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (detail['area_name'] != null)
                                        Text('พื้นที่: ${detail['area_name']}', 
                                             style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                      Text('จำนวน: ${detail['quantity'] ?? 1} ชิ้น', 
                                           style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                    ],
                                  ),
                                ),
                                if (expire_date != null)
                                  Text('${expire_date.day}/${expire_date.month}/${expire_date.year + 543}', 
                                       style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // ปุ่มดำเนินการ
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _show_individual_item_confirmation_dialog(item_number, detail, 'used');
                                    },
                                    icon: const Icon(Icons.check_circle_outline, size: 16),
                                    label: const Text('ใช้หมด', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _show_individual_item_confirmation_dialog(item_number, detail, 'expired');
                                    },
                                    icon: const Icon(Icons.warning_outlined, size: 16),
                                    label: const Text('ทิ้ง/หมดอายุ', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _show_traditional_discard_dialog() async {
    // ตรวจสอบจำนวนสินค้าปัจจุบัน
    int currentQuantity = int.tryParse(_quantity_controller.text) ?? 1;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ปุ่มปิด X ด้านบน
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // ข้อความ "สินค้าหมดหรือยัง"
                const Text(
                  'สินค้าหมดหรือยัง',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // ปุ่ม "ใช้ของหมด" (สีฟ้า)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (currentQuantity > 1) {
                        _show_quantity_selection_dialog('used');
                      } else {
                        _handle_used_up_item();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text(
                      currentQuantity > 1 ? 'ใช้ของหมด (เลือกจำนวน)' : 'ใช้ของหมด',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // ปุ่ม "ทิ้ง/หมดอายุ" (สีฟ้า)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (currentQuantity > 1) {
                        _show_quantity_selection_dialog('expired');
                      } else {
                        _handle_discard_expired_item();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text(
                      currentQuantity > 1 ? 'ทิ้ง/หมดอายุ (เลือกจำนวน)' : 'ทิ้ง/หมดอายุ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _show_quantity_selection_dialog(String action) async {
    int currentQuantity = int.tryParse(_quantity_controller.text) ?? 1;
    int selectedQuantity = 1;
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ปุ่มปิด X ด้านบน
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.grey),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // ข้อความหัวข้อ
                    Text(
                      action == 'used' ? 'เลือกจำนวนที่ใช้หมด' : 'เลือกจำนวนที่ทิ้ง/หมดอายุ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // แสดงจำนวนปัจจุบัน
                    Text(
                      'จำนวนปัจจุบัน: $currentQuantity ชิ้น',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // เลือกจำนวน
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ปุ่มลด
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: selectedQuantity > 1 
                                ? () => setState(() => selectedQuantity--)
                                : null,
                            icon: const Icon(Icons.remove),
                            iconSize: 20,
                          ),
                        ),
                        
                        // แสดงจำนวน
                        Container(
                          width: 80,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            selectedQuantity.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        
                        // ปุ่มเพิ่ม
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: selectedQuantity < currentQuantity 
                                ? () => setState(() => selectedQuantity++)
                                : null,
                            icon: const Icon(Icons.add),
                            iconSize: 20,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // ปุ่มยืนยัน
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (action == 'used') {
                            _handle_used_up_item_with_quantity(selectedQuantity);
                          } else {
                            _handle_discard_expired_item_with_quantity(selectedQuantity);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: action == 'used' ? Colors.blue : Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: Text(
                          'ยืนยัน ${action == 'used' ? 'ใช้หมด' : 'ทิ้ง/หมดอายุ'} $selectedQuantity ชิ้น',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handle_used_up_item_with_quantity(int quantity) async {
    // จัดการเมื่อเลือก "ใช้ของหมด" พร้อมจำนวน
    await _update_item_quantity('used', quantity, 'ใช้ของหมดเรียบร้อย $quantity ชิ้น');
  }

  Future<void> _handle_discard_expired_item_with_quantity(int quantity) async {
    // จัดการเมื่อเลือก "ทิ้ง/หมดอายุ" พร้อมจำนวน
    await _update_item_quantity('expired', quantity, 'ทิ้ง/หมดอายุเรียบร้อย $quantity ชิ้น');
  }

  Future<void> _update_item_quantity(String type, int quantity, String successMessage) async {
    final String url = '$_apiBaseUrl/update_item_status_v2.php'; // ใช้ API ใหม่
    
    // รองรับทั้ง item_id และ id
    int? itemId = widget.item_data['item_id'];
    if (itemId == null && widget.item_data['id'] != null) {
      itemId = widget.item_data['id'] is int
          ? widget.item_data['id']
          : int.tryParse(widget.item_data['id'].toString());
    }

    int? userId = widget.item_data['user_id'];
    if (userId == null) {
      // ถ้าไม่มี user_id ใน item_data ให้ดึงจาก SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getInt('user_id');
      } catch (e) {
        debugPrint('Error loading user_id from SharedPreferences: $e');
      }
    }

    if (itemId == null || userId == null) {
      _show_snackbar('Error: ไม่พบข้อมูล Item ID หรือ User ID', Colors.red);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        body: {
          'item_id': itemId.toString(),
          'user_id': userId.toString(),
          'quantity_type': type, // 'used' หรือ 'expired'
          'quantity': quantity.toString(),
        },
      );

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        // อัปเดตข้อมูลก่อนแสดงข้อความ
        await _reload_item_data();
        
        _show_snackbar(successMessage, Colors.green);
        
        // อัปเดตข้อมูลในหน้าเดิมด้วย
        setState(() {
          if (responseData['data'] != null) {
            int newRemainingQuantity = responseData['data']['remaining_quantity'] ?? 0;
            String newStatus = responseData['data']['new_status'] ?? 'active';
            widget.item_data['quantity'] = newRemainingQuantity;
            widget.item_data['remaining_quantity'] = newRemainingQuantity;
            _quantity_controller.text = newRemainingQuantity.toString();
            if (newRemainingQuantity <= 0) {
              widget.item_data['item_status'] = newStatus;
            }
          } else {
            int currentQuantity = int.tryParse(_quantity_controller.text) ?? 1;
            int newQuantity = currentQuantity - quantity;
            if (newQuantity <= 0) {
              widget.item_data['item_status'] = type == 'used' ? 'disposed' : 'expired';
              widget.item_data['quantity'] = 0;
              widget.item_data['remaining_quantity'] = 0;
              _quantity_controller.text = '0';
            } else {
              widget.item_data['quantity'] = newQuantity;
              widget.item_data['remaining_quantity'] = newQuantity;
              _quantity_controller.text = newQuantity.toString();
            }
          }
        });
        
        // กลับไปหน้าก่อนหน้าพร้อมส่งสัญญาณว่ามีการเปลี่ยนแปลง
        Navigator.pop(context, true);
      } else {
        _show_snackbar(responseData['message'] ?? 'ไม่สามารถอัพเดตจำนวนได้', Colors.red);
      }
    } catch (e) {
      debugPrint('Error updating item quantity: $e');
      _show_snackbar('เกิดข้อผิดพลาด: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _handle_used_up_item() async {
    // จัดการเมื่อเลือก "ใช้ของหมด" - ส่งสถานะ 'disposed'
    await _update_item_status('disposed', 'ใช้ของหมดเรียบร้อย');
  }

  Future<void> _handle_discard_expired_item() async {
    // จัดการเมื่อเลือก "ทิ้ง/หมดอายุ" - ส่งสถานะ 'expired'
    await _update_item_status('expired', 'ทิ้ง/หมดอายุเรียบร้อย');
  }

  Future<void> _update_item_status(String newStatus, String successMessage) async {
    final String url = '$_apiBaseUrl/update_item_status.php';
    
    // รองรับทั้ง item_id และ id
    int? itemId = widget.item_data['item_id'];
    if (itemId == null && widget.item_data['id'] != null) {
      itemId = widget.item_data['id'] is int
          ? widget.item_data['id']
          : int.tryParse(widget.item_data['id'].toString());
    }

    int? userId = widget.item_data['user_id'];
    if (userId == null) {
      // ถ้าไม่มี user_id ใน item_data ให้ดึงจาก SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getInt('user_id');
      } catch (e) {
        debugPrint('Error loading user_id from SharedPreferences: $e');
      }
    }

    if (itemId == null || userId == null) {
      _show_snackbar('Error: ไม่พบข้อมูล Item ID หรือ User ID', Colors.red);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        body: {
          'item_id': itemId.toString(),
          'user_id': userId.toString(),
          'new_status': newStatus,
        },
      );

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        _show_snackbar(successMessage, Colors.green);
        setState(() {
          widget.item_data['item_status'] = newStatus;
        });
        await _reload_item_data();
        // กลับไปหน้าก่อนหน้าพร้อมส่งสัญญาณว่ามีการเปลี่ยนแปลง
        Navigator.pop(context, true);
      } else {
        _show_snackbar(responseData['message'] ?? 'ไม่สามารถอัพเดตสถานะได้', Colors.red);
      }
    } catch (e) {
      debugPrint('Error updating item status: $e');
      _show_snackbar('เกิดข้อผิดพลาด: ${e.toString()}', Colors.red);
    }
  }

  @override
  void dispose() {
    _name_controller.dispose();
    _quantity_controller.dispose();
    _barcode_controller.dispose();
    _notification_days_controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'รายละเอียดสินค้า',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'ลบสิ่งของ',
            onPressed: _delete_item, // Call the delete function
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ชื่อสินค้า
              _build_section_title('สินค้า'),
              const SizedBox(height: 12),
              _build_text_display(
                controller: _name_controller,
                hint: 'ระบุชื่อสินค้า',
              ),

              const SizedBox(height: 12),

              // จำนวนสินค้าและรูปภาพ
              Row(
                children: [
                  // จำนวนสินค้า
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _build_section_title('จำนวนสินค้า'),
                        const SizedBox(height: 8),
                        _build_text_display(
                          controller: _quantity_controller,
                          hint: 'จำนวน',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // พื้นที่รูปภาพ (แสดงรูปภาพที่มี หรือ placeholder)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: widget.item_data['item_img'] != null &&
                          (widget.item_data['item_img'] as String).isNotEmpty &&
                          (widget.item_data['item_img'] as String) != 'lib/img/default.png'
                          ? Image.network(
                              widget.item_data['item_img'],
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
                ],
              ),

              const SizedBox(height: 24),

              // วัน
              _build_section_title('วัน'),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Dropdown หน่วยวัน (แสดงผลอย่างเดียว)
                  Expanded(
                    flex: 2,
                    child: _build_text_display(
                      controller: TextEditingController(text: _selected_unit),
                      hint: 'หน่วยวัน',
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ปุ่มเลือกวันที่ (แสดงผลอย่างเดียว)
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _format_date(_selected_date),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // หมวดหมู่
              _build_section_title('หมวดหมู่'),
              const SizedBox(height: 12),
              _build_text_display(
                controller: TextEditingController(text: _selected_category),
                hint: 'หมวดหมู่',
              ),

              const SizedBox(height: 16),

              // พื้นที่จัดเก็บ

              // แสดงพื้นที่จัดเก็บทั้งหมด (ถ้ามีหลายพื้นที่)
              if ((widget.item_data['storage_locations'] ?? []).isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _build_section_title('พื้นที่จัดเก็บทั้งหมด'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        (widget.item_data['storage_locations'] as List)
                          .map((loc) => loc['area_name'] ?? '')
                          .where((name) => name.toString().isNotEmpty)
                          .toList()
                          .join(', '),
                        style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                )
              else
                _build_text_display(
                  controller: TextEditingController(text: _selected_storage),
                  hint: 'พื้นที่จัดเก็บ',
                ),

              const SizedBox(height: 16),

              // แสดงรายละเอียดแต่ละชิ้น (ถ้ามีข้อมูล item_expire_details)
              if ((widget.item_data['item_expire_details'] ?? []).isNotEmpty)
                _build_individual_items_section(),

              const SizedBox(height: 24),

              // ตั้งการแจ้งเตือน
              _build_section_title('ตั้งการแจ้งเตือน'),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'แจ้งเตือนอีก',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Container(
                    width: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _build_text_display(
                      controller: _notification_days_controller,
                      hint: '', // เปลี่ยนจาก '3' เป็นค่าว่าง
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'วันก่อนหมดอายุ',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // รหัสบาร์โค้ด
              _build_section_title('รหัสบาร์โค้ด'),
              const SizedBox(height: 12),
              _build_text_display(
                controller: _barcode_controller,
                hint: 'รหัสบาร์โค้ด',
              ),

              const SizedBox(height: 32),

              // ไม่มีปุ่มบันทึกในหน้ารายละเอียด
              // Add the new buttons here
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // เตรียม item_data ให้ date_type เป็นภาษาไทยก่อนส่งไป AddItemPage (รองรับทั้งรหัสและ label)
                          final itemDataForEdit = Map<String, dynamic>.from(widget.item_data);
                          final rawUnit = widget.item_data['unit'] ?? widget.item_data['date_type'] ?? 'วันหมดอายุ(EXP)';
                          if (rawUnit == 'EXP' || rawUnit == 'วันหมดอายุ(EXP)') {
                            itemDataForEdit['date_type'] = 'วันหมดอายุ(EXP)';
                          } else if (rawUnit == 'BBF' || rawUnit == 'ควรบริโภคก่อน(BBF)') {
                            itemDataForEdit['date_type'] = 'ควรบริโภคก่อน(BBF)';
                          } else {
                            itemDataForEdit['date_type'] = rawUnit;
                          }
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddItemPage(
                                is_existing_item: true,
                                item_data: itemDataForEdit,
                              ),
                            ),
                          );
                          if (result == true) {
                            // ถ้าแก้ไขแล้ว กลับหรือ refresh
                            Navigator.pop(context, true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // Blue button
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          'แก้ไขข้อมูล',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16), // Space between buttons
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _show_discard_options_dialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, // Red button
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          'ทิ้งสิ่งของ/สิ่งของหมด',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget หัวข้อส่วน
  Widget _build_section_title(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  // Widget สำหรับแสดงรายละเอียดแต่ละชิ้น
  Widget _build_individual_items_section() {
    final item_expire_details = widget.item_data['item_expire_details'] as List;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _build_section_title('รายละเอียดแต่ละชิ้น (${item_expire_details.length} ชิ้น)'),
        const SizedBox(height: 12),
        
        // แสดงรายการแต่ละชิ้น
        ...item_expire_details.asMap().entries.map((entry) {
          final index = entry.key;
          final detail = entry.value;
          final item_number = index + 1;
          
          // คำนวณวันหมดอายุ
          DateTime? expire_date;
          String expire_text = 'ไม่ระบุ';
          Color expire_color = Colors.grey;
          
          try {
            expire_date = DateTime.parse(detail['expire_date']);
            final days_left = expire_date.difference(DateTime.now()).inDays;
            
            if (days_left < 0) {
              expire_text = 'หมดอายุแล้ว ${days_left.abs()} วัน';
              expire_color = Colors.red;
            } else if (days_left == 0) {
              expire_text = 'หมดอายุวันนี้';
              expire_color = Colors.red;
            } else if (days_left == 1) {
              expire_text = 'หมดอายุพรุ่งนี้';
              expire_color = Colors.orange;
            } else if (days_left <= 7) {
              expire_text = 'หมดอายุอีก $days_left วัน';
              expire_color = Colors.orange;
            } else if (days_left <= 30) {
              expire_text = 'หมดอายุอีก $days_left วัน';
              expire_color = Colors.blue;
            } else {
              // แสดงวันที่เต็ม
              final months = [
                '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
                'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
              ];
              final buddhist_year = expire_date.year + 543;
              expire_text = 'หมดอายุ ${expire_date.day} ${months[expire_date.month]} $buddhist_year';
              expire_color = Colors.green;
            }
          } catch (e) {
            expire_text = 'ไม่ระบุวันหมดอายุ';
            expire_color = Colors.grey;
          }
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // หัวข้อชิ้นที่
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ชิ้นที่ $item_number',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // สถานะวันหมดอายุ
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: expire_color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        expire_text,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: expire_color,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // ข้อมูลรายละเอียด
                Row(
                  children: [
                    // คอลัมน์ซ้าย
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (detail['area_name'] != null)
                            _build_detail_row('พื้นที่:', detail['area_name']),
                          if (detail['barcode'] != null && detail['barcode'].toString().isNotEmpty)
                            _build_detail_row('บาร์โค้ด:', detail['barcode']),
                        ],
                      ),
                    ),
                    
                    // คอลัมน์ขวา
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _build_detail_row('จำนวน:', '${detail['quantity'] ?? 1} ชิ้น'),
                          if (expire_date != null)
                            _build_detail_row('วันหมดอายุ:', '${expire_date.day}/${expire_date.month}/${expire_date.year + 543}'),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // Helper widget สำหรับแสดงข้อมูลแต่ละแถว
  Widget _build_detail_row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันแสดง confirmation dialog สำหรับชิ้นเฉพาะ
  void _show_individual_item_confirmation_dialog(int item_number, Map<String, dynamic> detail, String action) {
    String actionText = action == 'used' ? 'ใช้แล้ว' : 'หมดอายุ';
    String confirmText = action == 'used' ? 'ยืนยันการใช้สินค้า' : 'ยืนยันการทิ้ง/หมดอายุ';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(confirmText),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('คุณต้องการทำเครื่องหมายชิ้นที่ $item_number ว่า$actionText หรือไม่?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('รายละเอียด:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    if (detail['area_name'] != null)
                      Text('พื้นที่: ${detail['area_name']}', style: TextStyle(fontSize: 12)),
                    if (detail['expire_date'] != null)
                      Text('วันหมดอายุ: ${_format_expire_date(detail['expire_date'])}', style: TextStyle(fontSize: 12)),
                    Text('จำนวน: ${detail['quantity'] ?? 1} ชิ้น', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handle_individual_item_action(detail, action);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'used' ? Colors.green : Colors.red,
              ),
              child: Text('ยืนยัน', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ฟังก์ชันจัดการการกระทำกับชิ้นเฉพาะ
  Future<void> _handle_individual_item_action(Map<String, dynamic> detail, String action) async {
    // รองรับทั้ง item_id และ id
    int? itemId = widget.item_data['item_id'];
    if (itemId == null && widget.item_data['id'] != null) {
      itemId = widget.item_data['id'] is int
          ? widget.item_data['id']
          : int.tryParse(widget.item_data['id'].toString());
    }

    int? userId = widget.item_data['user_id'];
    if (userId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getInt('user_id');
      } catch (e) {
        debugPrint('Error loading user_id from SharedPreferences: $e');
      }
    }

    if (itemId == null || userId == null) {
      _show_snackbar('Error: ไม่พบข้อมูล Item ID หรือ User ID', Colors.red);
      return;
    }

    // ตรวจสอบ detail_id
    dynamic detailId = detail['id'] ?? detail['detail_id'];
    
    // ถ้าไม่มี detail_id ให้ค้นหาจาก API
    if (detailId == null) {
      print('DEBUG: No detail_id found, searching via API...');
      try {
        final findResponse = await http.post(
          Uri.parse('$_apiBaseUrl/find_detail_id.php'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'item_id': itemId,
            'area_id': detail['area_id'],
            'expire_date': detail['expire_date'],
          }),
        );
        
        if (findResponse.statusCode == 200) {
          final findData = json.decode(findResponse.body);
          if (findData['status'] == 'success') {
            detailId = findData['detail_id'];
            print('DEBUG: Found detail_id via API: $detailId');
          } else {
            _show_snackbar('Error: ${findData['message']}', Colors.red);
            return;
          }
        } else {
          _show_snackbar('Error: ไม่สามารถค้นหา detail_id ได้', Colors.red);
          return;
        }
      } catch (e) {
        _show_snackbar('Error: เกิดข้อผิดพลาดในการค้นหา detail_id', Colors.red);
        print('ERROR finding detail_id: $e');
        return;
      }
    }
    
    // Debug logging
    print('DEBUG: handle_individual_item_action');
    print('DEBUG: detail = $detail');
    print('DEBUG: action = $action');
    print('DEBUG: detailId = $detailId (type: ${detailId.runtimeType})');
    print('DEBUG: itemId = $itemId');
    print('DEBUG: userId = $userId');

    if (detailId == null) {
      _show_snackbar('Error: ไม่พบข้อมูล Detail ID สำหรับ item_id: $itemId, area_id: ${detail['area_id']}, expire_date: ${detail['expire_date']}', Colors.red);
      return;
    }

    // แปลงเป็น int
    int? detailIdInt;
    if (detailId is int) {
      detailIdInt = detailId;
    } else if (detailId is String) {
      detailIdInt = int.tryParse(detailId);
    }
    
    if (detailIdInt == null || detailIdInt <= 0) {
      _show_snackbar('Error: Detail ID ไม่ถูกต้อง: $detailId', Colors.red);
      return;
    }

    final String url = '$_apiBaseUrl/update_item_status.php'; // ใช้ API เดียวกัน

    try {
      final requestBody = {
        'item_id': itemId.toString(),
        'user_id': userId.toString(),
        'detail_id': detailIdInt.toString(), // ส่ง detail_id
        'new_status': action == 'used' ? 'disposed' : 'expired', // แปลง action เป็น status
      };
      
      // Debug logging
      print('DEBUG: Request URL: $url');
      print('DEBUG: Request body: $requestBody');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        String message = action == 'used' 
            ? 'ทำเครื่องหมายใช้แล้วสำเร็จ' 
            : 'ทำเครื่องหมายหมดอายุสำเร็จ';
        
        // ดึงข้อมูลล่าสุดจาก API เพื่อ refresh UI
        await _reload_item_data();
        
        // แสดงข้อความสำเร็จหลังจาก reload แล้ว
        _show_snackbar(message, Colors.green);
        
        // กลับไปหน้าก่อนหน้าพร้อมส่งสัญญาณว่ามีการเปลี่ยนแปลงเสมอ
        Navigator.pop(context, true);
      } else {
        _show_snackbar(responseData['message'] ?? 'ไม่สามารถอัพเดตได้', Colors.red);
      }
    } catch (e) {
      debugPrint('Error updating individual item: $e');
      _show_snackbar('เกิดข้อผิดพลาด: ${e.toString()}', Colors.red);
    }
  }

  // ฟังก์ชันจัดรูปแบบวันหมดอายุ
  String _format_expire_date(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year + 543}';
    } catch (e) {
      return dateString;
    }
  }

  // Widget สำหรับแสดงข้อความ (อ่านอย่างเดียว)
  Widget _build_text_display({
    required TextEditingController controller,
    required String hint,
    TextAlign textAlign = TextAlign.start,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true, // ทำให้เป็นอ่านอย่างเดียว
      textAlign: textAlign,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!), // ไม่ต้องเปลี่ยนสีเมื่อ focus
        ),
        filled: true,
        fillColor: Colors.grey[100], // เปลี่ยนสีพื้นหลังเล็กน้อยเพื่อบ่งบอกว่าอ่านอย่างเดียว
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: const TextStyle(color: Colors.black87),
    );
  }

  // ฟังก์ชันจัดรูปแบบวันที่ (คัดลอกมาจาก add_item.dart)
  String _format_date(DateTime date) {
    const List<String> thai_months = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];

    // แปลงเป็นปี พ.ศ.
    final int buddhist_year = date.year + 543;

    return '${date.day} ${thai_months[date.month]} $buddhist_year';
  }
}