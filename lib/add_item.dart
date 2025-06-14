/**
 * @fileoverview หน้าเพิ่มสินค้าของแอปพลิเคชัน (แก้ไขปัญหา DatePicker)
 * 
 * รายละเอียดทั่วไป:
 * - หน้าสำหรับเพิ่มสินค้าใหม่หรือสินค้าที่มีอยู่
 * - มีฟอร์มกรอกข้อมูลครบถ้วน
 * - รองรับการเลือกรูปภาพ
 * - มีระบบ validation ข้อมูล
 * - แก้ไขปัญหา MaterialLocalizations สำหรับ DatePicker
 * 
 * การอัปเดต:
 * - 06/06/2025: สร้างหน้าเพิ่มสินค้า
 * - 13/06/2025: แก้ไขปัญหา DatePicker MaterialLocalizations
 */

import 'package:flutter/material.dart';

class AddItemPage extends StatefulWidget {
  final bool is_existing_item;
  
  const AddItemPage({
    Key? key,
    this.is_existing_item = false,
  }) : super(key: key);

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final TextEditingController _name_controller = TextEditingController();
  final TextEditingController _quantity_controller = TextEditingController(text: '1');
  final TextEditingController _barcode_controller = TextEditingController();
  final TextEditingController _price_controller = TextEditingController();
  final TextEditingController _notification_days_controller = TextEditingController(text: '3');
  final GlobalKey<FormState> _form_key = GlobalKey<FormState>();

  DateTime _selected_date = DateTime.now().add(const Duration(days: 7));
  String _selected_unit = 'วันหมดอายุ(EXP)';
  String _selected_category = 'เลือกประเภท';
  String _selected_storage = 'เลือกพื้นที่จัดเก็บ';
  bool _is_loading = false;

  final List<String> _units = [
    'วันหมดอายุ(EXP)',
    'วันที่ผลิต(MFG)',
    'ใช้ภายใน',
    'แช่เย็น',
    'แช่แข็ง',
  ];

  final List<String> _categories = [
    'เลือกประเภท',
    'อาหารสด',
    'อาหารแห้ง',
    'เครื่องดื่ม',
    'ยาและเวชภัณฑ์',
    'เครื่องสำอาง',
    'ของใช้ในบ้าน',
    'อื่นๆ',
  ];

  final List<String> _storage_locations = [
    'เลือกพื้นที่จัดเก็บ',
    'ตู้เย็น',
    'ตู้แช่แข็ง',
    'ตู้กับข้าว',
    'ชั้นวางของ',
    'ห้องเก็บของ',
    'อื่นๆ',
  ];

  @override
  void dispose() {
    _name_controller.dispose();
    _quantity_controller.dispose();
    _barcode_controller.dispose();
    _price_controller.dispose();
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
        title: Text(
          widget.is_existing_item ? 'เพิ่มรายการ' : 'เพิ่มรายการ',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _form_key,
        child: SingleChildScrollView(
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
                _build_text_field(
                  controller: _name_controller,
                  hint: 'ระบุชื่อสินค้า',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกชื่อสินค้า';
                    }
                    return null;
                  },
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
                          Row(
                            children: [
                              // ปุ่มลด
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    int current_quantity = int.tryParse(_quantity_controller.text) ?? 1;
                                    if (current_quantity > 1) {
                                      _quantity_controller.text = (current_quantity - 1).toString();
                                    }
                                  },
                                  icon: const Icon(Icons.remove, size: 16),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              
                              // ช่องจำนวน
                              Container(
                                width: 60,
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                child: TextFormField(
                                  controller: _quantity_controller,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'จำนวน';
                                    }
                                    final parsed_quantity = int.tryParse(value);
                                    if (parsed_quantity == null || parsed_quantity < 1) {
                                      return 'ไม่ถูกต้อง';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              
                              // ปุ่มเพิ่ม
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    int current_quantity = int.tryParse(_quantity_controller.text) ?? 1;
                                    _quantity_controller.text = (current_quantity + 1).toString();
                                  },
                                  icon: const Icon(Icons.add, size: 16),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 20),
                    
                    // พื้นที่รูปภาพ
                    GestureDetector(
                      onTap: _pick_image,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Icon(
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
                    // Dropdown หน่วยวัน
                    Expanded(
                      flex: 2,
                      child: _build_dropdown(
                        value: _selected_unit,
                        items: _units,
                        onChanged: (value) {
                          setState(() {
                            _selected_unit = value!;
                          });
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // ปุ่มเลือกวันที่
                    Expanded(
                      child: GestureDetector(
                        onTap: _select_date,
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
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // หมวดหมู่
                _build_section_title('หมวดหมู่'),
                const SizedBox(height: 12),
                _build_dropdown(
                  value: _selected_category,
                  items: _categories,
                  onChanged: (value) {
                    setState(() {
                      _selected_category = value!;
                    });
                  },
                ),
                
                const SizedBox(height: 16),
                
                // พื้นที่จัดเก็บ
                _build_dropdown(
                  value: _selected_storage,
                  items: _storage_locations,
                  onChanged: (value) {
                    setState(() {
                      _selected_storage = value!;
                    });
                  },
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
                      child: TextFormField(
                        controller: _notification_days_controller,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '3',
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return null; // ไม่บังคับ
                          }
                          final parsed_days = int.tryParse(value);
                          if (parsed_days == null || parsed_days < 0) {
                            return 'ไม่ถูกต้อง';
                          }
                          return null;
                        },
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
                _build_text_field(
                  controller: _barcode_controller,
                  hint: 'สแกนหรือป้อนรหัสบาร์โค้ด',
                  suffix_icon: Icons.qr_code_scanner,
                  on_suffix_pressed: () {
                    // TODO: เพิ่มฟังก์ชันสแกนบาร์โค้ด
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ฟีเจอร์สแกนบาร์โค้ดยังไม่พร้อมใช้งาน'),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                
                // ปุ่มบันทึก
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _is_loading ? null : _save_item,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _is_loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'บันทึกข้อมูล',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
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

  // Widget ช่องข้อความ
  Widget _build_text_field({
    required TextEditingController controller,
    required String hint,
    IconData? suffix_icon,
    VoidCallback? on_suffix_pressed,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        suffixIcon: suffix_icon != null
            ? IconButton(
                icon: Icon(suffix_icon, color: Colors.grey),
                onPressed: on_suffix_pressed,
              )
            : null,
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
          borderSide: const BorderSide(color: Color(0xFF4A90E2)),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // Widget Dropdown
  Widget _build_dropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
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
          borderSide: const BorderSide(color: Color(0xFF4A90E2)),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: TextStyle(
              color: item.startsWith('เลือก') ? Colors.grey[400] : Colors.black87,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.startsWith('เลือก')) {
          return 'กรุณาเลือกตัวเลือก';
        }
        return null;
      },
    );
  }

  // ฟังก์ชันเลือกวันที่ (แก้ไขปัญหา MaterialLocalizations)
  Future<void> _select_date() async {
    try {
      final DateTime? picked_date = await showDatePicker(
        context: context,
        initialDate: _selected_date,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 ปี
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFF4A90E2),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );
      
      if (picked_date != null) {
        setState(() {
          _selected_date = picked_date;
        });
      }
    } catch (error) {
      debugPrint('Error selecting date: $error');
      // แสดง Snackbar แจ้งเตือนข้อผิดพลาด
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเลือกวันที่'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ฟังก์ชันจัดรูปแบบวันที่ (ไม่ใช้ intl package)
  String _format_date(DateTime date) {
    const List<String> thai_months = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    
    // แปลงเป็นปี พ.ศ.
    final int buddhist_year = date.year + 543;
    
    return '${date.day} ${thai_months[date.month]} $buddhist_year';
  }

  // ฟังก์ชันเลือกรูปภาพ
  void _pick_image() {
    // TODO: เพิ่มฟังก์ชันเลือกรูปภาพ
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ฟีเจอร์เลือกรูปภาพยังไม่พร้อมใช้งาน'),
      ),
    );
  }

  // ฟังก์ชันตรวจสอบข้อมูลก่อนบันทึก
  bool _validate_form_data() {
    // ตรวจสอบฟอร์ม
    if (!_form_key.currentState!.validate()) {
      return false;
    }

    // ตรวจสอบหมวดหมู่
    if (_selected_category == 'เลือกประเภท') {
      _show_error_message('กรุณาเลือกหมวดหมู่สินค้า');
      return false;
    }

    // ตรวจสอบพื้นที่จัดเก็บ
    if (_selected_storage == 'เลือกพื้นที่จัดเก็บ') {
      _show_error_message('กรุณาเลือกพื้นที่จัดเก็บ');
      return false;
    }

    return true;
  }

  // ฟังก์ชันแสดงข้อความผิดพลาด
  void _show_error_message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ฟังก์ชันแสดงข้อความสำเร็จ
  void _show_success_message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ฟังก์ชันบันทึกข้อมูล
  Future<void> _save_item() async {
    if (!_validate_form_data()) {
      return;
    }

    setState(() {
      _is_loading = true;
    });

    try {
      // สร้างข้อมูลสินค้า
      final Map<String, dynamic> item_data = {
        'name': _name_controller.text.trim(),
        'quantity': int.parse(_quantity_controller.text),
        'category': _selected_category,
        'storage_location': _selected_storage,
        'date_type': _selected_unit,
        'selected_date': _selected_date.toIso8601String(),
        'notification_days': int.tryParse(_notification_days_controller.text) ?? 3,
        'barcode': _barcode_controller.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      };

      // TODO: เพิ่มการบันทึกข้อมูลไปยัง Database หรือ API
      // await ItemService.saveItem(item_data);
      
      // จำลองการบันทึกข้อมูล
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pop(context, item_data); // ส่งข้อมูลกลับไป
        _show_success_message('บันทึกข้อมูลสำเร็จ');
      }
    } catch (error) {
      debugPrint('Error saving item: $error');
      if (mounted) {
        _show_error_message('เกิดข้อผิดพลาด: ${error.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _is_loading = false;
        });
      }
    }
  }
}