// item_detail_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import http package
import 'dart:convert'; // Import for json.decode
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // เพิ่ม import นี้
import 'add_item.dart'; // เพิ่ม import สำหรับหน้าแก้ไข

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

  // Base URL for your API. Now loaded from .env
  late String _apiBaseUrl; // ใช้ late เพื่อบ่งบอกว่าจะถูก initialize ใน initState

  @override
  void initState() {
    super.initState();
    // ดึงค่าจาก .env
    _apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project'; // กำหนดค่า default ถ้าหาไม่เจอ
    _populate_fields();
  }

  void _populate_fields() {
    final item = widget.item_data;

    _name_controller.text = item['name'] ?? '';
    _quantity_controller.text = item['quantity']?.toString() ?? '1';
    _barcode_controller.text = item['barcode'] ?? '';
    // ใช้เฉพาะ item_notification และแสดง 0 ได้
    _notification_days_controller.text = (item['item_notification'] != null && item['item_notification'].toString().trim().isNotEmpty)
        ? item['item_notification'].toString()
        : '-';

    // แก้ไขให้แปลงรหัส EXP/BBF เป็นข้อความภาษาไทยที่ AddItemPage รองรับ
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
              onPressed: () => Navigator.of(context).pop(false), // User cancels
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
    final String url = '$_apiBaseUrl/update_item_status.php'; // ใช้ API เดิม
    
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
        _show_snackbar(successMessage, Colors.green);
        
        // อัพเดตข้อมูลใน UI ใช้ข้อมูลจาก API response
        setState(() {
          if (responseData['data'] != null) {
            // ใช้ข้อมูลจาก API response
            int newRemainingQuantity = responseData['data']['remaining_quantity'] ?? 0;
            String newStatus = responseData['data']['new_status'] ?? 'active';
            
            // อัพเดตข้อมูลในหน้าปัจจุบัน
            widget.item_data['quantity'] = newRemainingQuantity;
            widget.item_data['remaining_quantity'] = newRemainingQuantity;
            _quantity_controller.text = newRemainingQuantity.toString();
            
            // อัพเดตสถานะถ้าจำเป็น
            if (newRemainingQuantity <= 0) {
              widget.item_data['item_status'] = newStatus;
            }
          } else {
            // fallback ถ้าไม่มี data ใน response
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
        Navigator.of(context).pop(true);
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
        // อัพเดตข้อมูลใน widget.item_data
        setState(() {
          widget.item_data['item_status'] = newStatus;
        });
        // กลับไปหน้าก่อนหน้าพร้อมส่งสัญญาณว่ามีการเปลี่ยนแปลง
        Navigator.of(context).pop(true);
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