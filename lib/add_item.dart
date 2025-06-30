import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // เพิ่ม import นี้

// URL พื้นฐานของ API ของคุณ - ลบบรรทัดนี้ออกไป
// const String _api_base_url = 'http://10.192.168.1.176/project';

class AddItemPage extends StatefulWidget {
  final bool is_existing_item;
  // เพิ่ม callback สำหรับการรีโหลดข้อมูลในหน้าก่อนหน้า
  final VoidCallback? on_item_added;

  const AddItemPage({
    Key? key,
    this.is_existing_item = false,
    this.on_item_added,
  }) : super(key: key);

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final TextEditingController _name_controller = TextEditingController();
  final TextEditingController _quantity_controller = TextEditingController(text: '1');
  final TextEditingController _barcode_controller = TextEditingController();
  final TextEditingController _price_controller = TextEditingController();
  final TextEditingController _notification_days_controller = TextEditingController(text: '');
  final GlobalKey<FormState> _form_key = GlobalKey<FormState>();

  DateTime _selected_date = DateTime.now().add(const Duration(days: 7));
  String _selected_unit = 'วันหมดอายุ(EXP)';
  String _selected_category = 'เลือกประเภท';
  String _selected_storage = 'เลือกพื้นที่จัดเก็บ';
  bool _is_loading = false;

  XFile? _picked_image;

  final List<String> _units = [
    'วันหมดอายุ(EXP)',
    'วันที่ผลิต(MFG)',
  ];

  List<String> _categories = ['เลือกประเภท'];
  List<String> _storage_locations = ['เลือกพื้นที่จัดเก็บ'];

  int? _current_user_id;

  String _api_base_url = ''; // เพิ่มตัวแปรนี้สำหรับเก็บ base URL

  @override
  void initState() {
    super.initState();
    // ดึงค่าจาก .env เมื่อ initState
    _api_base_url = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project'; // กำหนดค่า default ถ้าหาไม่เจอ
    _load_user_id();
    _fetch_categories();
    _fetch_storage_locations();
  }

  @override
  void dispose() {
    _name_controller.dispose();
    _quantity_controller.dispose();
    _barcode_controller.dispose();
    _price_controller.dispose();
    _notification_days_controller.dispose();
    super.dispose();
  }

  Future<void> _load_user_id() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _current_user_id = prefs.getInt('user_id');
    });
    debugPrint('Loaded user_id from SharedPreferences: $_current_user_id');
  }

  Future<void> _fetch_categories() async {
    setState(() {
      _is_loading = true;
    });
    try {
      // ใช้ _api_base_url ที่ดึงมาจาก .env
      final response = await http.get(Uri.parse('$_api_base_url/get_types.php'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _categories = ['เลือกประเภท', ...data.map((item) => item['type_name'].toString()).toList()];
          if (!_categories.contains(_selected_category)) {
            _selected_category = 'เลือกประเภท';
          }
        });
      } else {
        debugPrint('Failed to load categories: ${response.statusCode}');
        _show_error_message('ไม่สามารถดึงหมวดหมู่ได้: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      _show_error_message('เกิดข้อผิดพลาดในการเชื่อมต่อเพื่อดึงหมวดหมู่: $e');
    } finally {
      setState(() {
        _is_loading = false;
      });
    }
  }

  Future<void> _fetch_storage_locations() async {
    setState(() {
      _is_loading = true;
    });
    try {
      // ใช้ _api_base_url ที่ดึงมาจาก .env
      final response = await http.get(Uri.parse('$_api_base_url/get_areas.php'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _storage_locations = ['เลือกพื้นที่จัดเก็บ', ...data.map((item) => item['area_name'].toString()).toList()];
          if (!_storage_locations.contains(_selected_storage)) {
            _selected_storage = 'เลือกพื้นที่จัดเก็บ';
          }
        });
      } else {
        debugPrint('Failed to load storage locations: ${response.statusCode}');
        _show_error_message('ไม่สามารถดึงพื้นที่จัดเก็บได้: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching storage locations: $e');
      _show_error_message('เกิดข้อผิดพลาดในการเชื่อมต่อเพื่อดึงพื้นที่จัดเก็บ: $e');
    } finally {
      setState(() {
        _is_loading = false;
      });
    }
  }

  Future<void> _select_date() async {
    try {
      final DateTime? picked_date = await showDatePicker(
        context: context,
        initialDate: _selected_date,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
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

  String _format_date(DateTime date) {
    const List<String> thai_months = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    final int buddhist_year = date.year + 543;
    return '${date.day} ${thai_months[date.month]} $buddhist_year';
  }

  Future<void> _pick_image() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _picked_image = image;
      });
    }
  }

  bool _validate_form_data() {
    if (!_form_key.currentState!.validate()) {
      return false;
    }
    if (_selected_category == 'เลือกประเภท') {
      _show_error_message('กรุณาเลือกหมวดหมู่สินค้า');
      return false;
    }
    if (_selected_storage == 'เลือกพื้นที่จัดเก็บ') {
      _show_error_message('กรุณาเลือกพื้นที่จัดเก็บ');
      return false;
    }
    return true;
  }

  void _show_success_message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _show_error_message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _save_item() async {
    if (!_validate_form_data()) {
      return;
    }

    if (_current_user_id == null) {
      _show_error_message('ไม่พบข้อมูลผู้ใช้งาน กรุณาลองเข้าสู่ระบบใหม่');
      setState(() {
        _is_loading = false;
      });
      return;
    }

    setState(() {
      _is_loading = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_api_base_url/add_item.php'), // ใช้ _api_base_url ที่ดึงมาจาก .env
      );

      request.fields['name'] = _name_controller.text.trim();
      request.fields['quantity'] = _quantity_controller.text;
      request.fields['category'] = _selected_category;
      request.fields['storage_location'] = _selected_storage;
      request.fields['selected_date'] = _selected_date.toIso8601String().split('T')[0];
      request.fields['notification_days'] = _notification_days_controller.text;
      request.fields['barcode'] = _barcode_controller.text.trim();
      request.fields['user_id'] = _current_user_id.toString();

      if (_picked_image != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'item_img',
          _picked_image!.path,
        ));
      }

      var streamed_response = await request.send();
      var response = await http.Response.fromStream(streamed_response);

      if (mounted) {
        if (response.statusCode == 200) {
          final response_data = jsonDecode(utf8.decode(response.bodyBytes));
          if (response_data['status'] == 'success') {
            _show_success_message('เพิ่มรายการสำเร็จแล้ว!');
            if (widget.on_item_added != null) {
              widget.on_item_added!();
            }
            Navigator.pop(context);
          } else {
            _show_error_message('Error: ${response_data['message']}');
          }
        } else {
          _show_error_message('Server error: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
        }
      }
    } catch (error) {
      debugPrint('Error saving item: $error');
      if (mounted) {
        _show_error_message('เกิดข้อผิดพลาดในการบันทึกข้อมูล: ${error.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _is_loading = false;
        });
      }
    }
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
          widget.is_existing_item ? 'แก้ไขรายการ' : 'เพิ่มรายการ',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: _is_loading && _categories.length <= 1 && _storage_locations.length <= 1
          ? const Center(child: CircularProgressIndicator())
          : Form(
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
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _build_section_title('จำนวนสินค้า'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
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
                          GestureDetector(
                            onTap: _pick_image,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                                image: _picked_image != null
                                    ? DecorationImage(
                                        image: FileImage(File(_picked_image!.path)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _picked_image == null
                                  ? const Icon(
                                      Icons.camera_alt_outlined,
                                      color: Colors.grey,
                                      size: 32,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _build_section_title('วัน'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
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
                                hintText: '',
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return null;
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
                      _build_section_title('รหัสบาร์โค้ด'),
                      const SizedBox(height: 12),
                      _build_text_field(
                        controller: _barcode_controller,
                        hint: 'สแกนหรือป้อนรหัสบาร์โค้ด',
                        suffix_icon: Icons.qr_code_scanner,
                        on_suffix_pressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ฟีเจอร์สแกนบาร์โค้ดยังไม่พร้อมใช้งาน'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
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
}