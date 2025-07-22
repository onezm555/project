import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // เพิ่ม import นี้


class AddItemPage extends StatefulWidget {
  final bool is_existing_item;
  final VoidCallback? on_item_added;
  final Map<String, dynamic>? item_data; // เพิ่มรับข้อมูล item เดิม

  const AddItemPage({
    Key? key,
    this.is_existing_item = false,
    this.on_item_added,
    this.item_data,
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
  XFile? _picked_image;
  bool _is_loading = false;
  List<String> _units = ['วันหมดอายุ(EXP)', 'วันผลิต(MFG)'];
  List<String> _categories = ['เลือกประเภท', 'เพิ่มประเภทสินค้า'];
  List<Map<String, dynamic>> _storage_locations = [
    {'area_id': null, 'area_name': 'เลือกพื้นที่จัดเก็บ'},
    {'area_id': null, 'area_name': 'เพิ่มพื้นที่การเอง'},
  ];
  int? _current_user_id; // สำหรับเก็บ user_id

  // ใช้ URL จาก .env
  final String _api_base_url = dotenv.env['API_BASE_URL'] ?? 'http://localhost';


  @override
  void initState() {
    super.initState();
    _initialize_data();
    _notification_days_controller.text = '7';
    // ถ้าเป็นโหมดแก้ไข ให้เติมข้อมูลจาก item_data
    if (widget.is_existing_item && widget.item_data != null) {
      final item = widget.item_data!;
      _name_controller.text = item['name'] ?? '';
      _quantity_controller.text = item['quantity']?.toString() ?? '1';
      _barcode_controller.text = item['barcode'] ?? '';
      _notification_days_controller.text = (item['item_notification'] != null && item['item_notification'].toString().trim().isNotEmpty)
          ? item['item_notification'].toString()
          : '7';
      _selected_unit = item['unit'] ?? item['date_type'] ?? 'วันหมดอายุ(EXP)';
      _selected_category = item['category'] ?? 'เลือกประเภท';
      _selected_storage = item['storage_location'] ?? 'เลือกพื้นที่จัดเก็บ';
      if (item['item_date'] != null) {
        try {
          _selected_date = DateTime.parse(item['item_date']);
        } catch (e) {
          _selected_date = DateTime.now().add(const Duration(days: 7));
        }
      }
      // ไม่เติมรูปภาพเดิม (_picked_image) เพราะต้องเลือกใหม่
    }
    // ป้องกัน error dropdown: ถ้า value ไม่อยู่ใน list ให้เซ็ตเป็น default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_categories.contains(_selected_category)) {
        setState(() {
          _selected_category = 'เลือกประเภท';
        });
      }
      final storageNames = _storage_locations.map((e) => e['area_name'] as String).toList();
      if (!storageNames.contains(_selected_storage)) {
        setState(() {
          _selected_storage = 'เลือกพื้นที่จัดเก็บ';
        });
      }
    });
  }

  Future<void> _initialize_data() async {
    setState(() {
      _is_loading = true;
    });
    await _load_user_id();
    if (_current_user_id != null) {
      await _fetch_categories();
      await _fetch_storage_locations();
    } else {
      _show_error_message('ไม่พบข้อมูลผู้ใช้งาน กรุณาลองเข้าสู่ระบบใหม่');
    }
    setState(() {
      _is_loading = false;
    });
  }

  Future<void> _load_user_id() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _current_user_id = prefs.getInt('user_id');
    });
  }

  Future<void> _fetch_categories() async {
    if (_current_user_id == null) return;

    try {
      final response = await http.get(Uri.parse('$_api_base_url/get_types.php?user_id=$_current_user_id'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final loadedCategories = ['เลือกประเภท'] + data.map((e) => e['type_name'] as String).toList() + ['เพิ่มประเภทสินค้า'];
        setState(() {
          _categories = loadedCategories;
          // ถ้าเป็นโหมดแก้ไขและมีข้อมูลเดิม ให้เลือก category ตามข้อมูลเดิม
          if (widget.is_existing_item && widget.item_data != null) {
            final itemCat = widget.item_data!['category'] ?? '';
            if (_categories.contains(itemCat)) {
              _selected_category = itemCat;
            } else {
              _selected_category = 'เลือกประเภท';
            }
          } else {
            if (!_categories.contains(_selected_category)) {
              _selected_category = 'เลือกประเภท';
            }
          }
        });
      } else {
        _show_error_message('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      _show_error_message('Error fetching categories: $e');
    }
  }

  Future<void> _fetch_storage_locations() async {
    if (_current_user_id == null) return;

    try {
      final response = await http.get(Uri.parse('$_api_base_url/get_areas.php?user_id=$_current_user_id'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final loadedLocations = [
          {'area_id': null, 'area_name': 'เลือกพื้นที่จัดเก็บ', 'user_id': null},
          ...data.map((e) => {
            'area_id': e['area_id'],
            'area_name': e['area_name'],
            'user_id': e['user_id'],
          }),
          {'area_id': null, 'area_name': 'เพิ่มพื้นที่การเอง', 'user_id': null},
        ];
        setState(() {
          _storage_locations = loadedLocations;
          final storageNames = _storage_locations.map((e) => e['area_name'] as String).toList();
          // ถ้าเป็นโหมดแก้ไขและมีข้อมูลเดิม ให้เลือก storage ตามข้อมูลเดิม
          if (widget.is_existing_item && widget.item_data != null) {
            final itemStorage = widget.item_data!['storage_location'] ?? '';
            if (storageNames.contains(itemStorage)) {
              _selected_storage = itemStorage;
            } else {
              _selected_storage = 'เลือกพื้นที่จัดเก็บ';
            }
          } else {
            if (!storageNames.contains(_selected_storage)) {
              _selected_storage = 'เลือกพื้นที่จัดเก็บ';
            }
          }
        });
      } else {
        _show_error_message('Failed to load storage locations: ${response.statusCode}');
      }
    } catch (e) {
      _show_error_message('Error fetching storage locations: $e');
    }
  }

  Future<void> _select_date() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selected_date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selected_date) {
      setState(() {
        _selected_date = picked;
      });
    }
  }

  String _format_date(DateTime date) {
    return "${date.day}/${date.month}/${date.year + 543}"; // Convert to Buddhist year
  }

  Future<void> _pick_image({required ImageSource source}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    setState(() {
      _picked_image = image;
    });
  }

  Future<void> _show_add_category_dialog() async {
    String? new_category_name;
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('เพิ่มประเภทสินค้าใหม่'),
          content: TextField(
            onChanged: (value) {
              new_category_name = value;
            },
            decoration: const InputDecoration(hintText: 'ชื่อประเภทสินค้า'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              child: const Text('เพิ่ม'),
              onPressed: () async {
                if (new_category_name != null && new_category_name!.isNotEmpty) {
                  Navigator.pop(context, new_category_name);
                } else {
                  _show_error_message('กรุณากรอกชื่อประเภทสินค้า');
                }
              },
            ),
          ],
        );
      },
    ).then((value) async {
      if (value != null) {
        await _add_new_category(value);
      }
    });
  }

  Future<void> _add_new_category(String type_name) async {
    if (_current_user_id == null) {
      _show_error_message('ไม่พบข้อมูลผู้ใช้งาน กรุณาลองเข้าสู่ระบบใหม่');
      return;
    }

    setState(() {
      _is_loading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_api_base_url/add_type.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'type_name': type_name,
          'user_id': _current_user_id.toString(),
        }),
      );

      if (response.statusCode == 200) {
        final response_data = json.decode(utf8.decode(response.bodyBytes));
        if (response_data['status'] == 'success') {
          _show_success_message('เพิ่มประเภทสินค้าสำเร็จแล้ว!');
          await _fetch_categories(); // Refresh categories
          setState(() {
            _selected_category = type_name; // Select the newly added category
          });
        } else {
          _show_error_message('Error: ${response_data['message']}');
        }
      } else {
        final error_body_decoded = utf8.decode(response.bodyBytes);
        _show_error_message('Server error: ${response.statusCode} - $error_body_decoded');
      }
    } catch (e) {
      _show_error_message('เกิดข้อผิดพลาดในการเพิ่มประเภทสินค้า: $e');
    } finally {
      setState(() {
        _is_loading = false;
      });
    }
  }


  Future<void> _show_add_storage_dialog() async {
    String? new_area_name;
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('เพิ่มพื้นที่จัดเก็บใหม่'),
          content: TextField(
            onChanged: (value) {
              new_area_name = value;
            },
            decoration: const InputDecoration(hintText: 'ชื่อพื้นที่จัดเก็บ'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              child: const Text('เพิ่ม'),
              onPressed: () async {
                if (new_area_name != null && new_area_name!.isNotEmpty) {
                  Navigator.pop(context, new_area_name);
                } else {
                  _show_error_message('กรุณากรอกชื่อพื้นที่จัดเก็บ');
                }
              },
            ),
          ],
        );
      },
    ).then((value) async {
      if (value != null) {
        await _add_new_storage_location(value);
      }
    });
  }

  Future<void> _add_new_storage_location(String area_name) async {
    if (_current_user_id == null) {
      _show_error_message('ไม่พบข้อมูลผู้ใช้งาน กรุณาลองเข้าสู่ระบบใหม่');
      return;
    }

    setState(() {
      _is_loading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_api_base_url/add_area.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'area_name': area_name,
          'user_id': _current_user_id.toString(),
        }),
      );

      if (response.statusCode == 200) {
        final response_data = json.decode(utf8.decode(response.bodyBytes));
        if (response_data['status'] == 'success') {
          _show_success_message('เพิ่มพื้นที่จัดเก็บสำเร็จแล้ว!');
          await _fetch_storage_locations();
          setState(() {
            _selected_storage = area_name;
          });
        } else {
          _show_error_message('Error: ${response_data['message']}');
        }
      } else {
        final error_body_decoded = utf8.decode(response.bodyBytes);
        _show_error_message('Server error: ${response.statusCode} - $error_body_decoded');
      }
    } catch (e) {
      _show_error_message('เกิดข้อผิดพลาดในการเพิ่มพื้นที่จัดเก็บ: $e');
    } finally {
      setState(() {
        _is_loading = false;
      });
    }
  }

  // NEW: Function to confirm deletion of a storage location
  Future<void> _confirm_delete_storage_dialog(String area_name) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: Text('คุณต้องการลบพื้นที่จัดเก็บ "$area_name" ใช่หรือไม่?'),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('ลบ'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog
                await _delete_storage_location(area_name);
              },
            ),
          ],
        );
      },
    );
  }

  // NEW: Function to delete a storage location
  Future<void> _delete_storage_location(String area_name) async {
    if (_current_user_id == null) {
      _show_error_message('ไม่พบข้อมูลผู้ใช้งาน กรุณาลองเข้าสู่ระบบใหม่');
      return;
    }

    setState(() {
      _is_loading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_api_base_url/delete_area.php'), // NEW PHP file
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'area_name': area_name,
          'user_id': _current_user_id.toString(),
        }),
      );

      if (response.statusCode == 200) {
        final response_data = json.decode(utf8.decode(response.bodyBytes));
        if (response_data['status'] == 'success') {
          _show_success_message('ลบพื้นที่จัดเก็บสำเร็จแล้ว!');
          await _fetch_storage_locations(); // Reload locations after deletion
          // Reset selected storage if the deleted one was selected
          if (_selected_storage == area_name) {
            setState(() {
              _selected_storage = 'เลือกพื้นที่จัดเก็บ';
            });
          }
        } else {
          _show_error_message('Error: ${response_data['message']}');
        }
      } else {
        final error_body_decoded = utf8.decode(response.bodyBytes);
        _show_error_message('Server error: ${response.statusCode} - $error_body_decoded');
      }
    } catch (e) {
      _show_error_message('เกิดข้อผิดพลาดในการลบพื้นที่จัดเก็บ: $e');
    } finally {
      setState(() {
        _is_loading = false;
      });
    }
  }


  bool _validate_form_data() {
    if (_form_key.currentState!.validate()) {
      if (_selected_category == 'เลือกประเภท') {
        _show_error_message('กรุณาเลือกประเภทสินค้า');
        return false;
      }
      if (_selected_storage == 'เลือกพื้นที่จัดเก็บ') {
        _show_error_message('กรุณาเลือกพื้นที่จัดเก็บ');
        return false;
      }
      return true;
    }
    return false;
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

    setState(() {
      _is_loading = true;
    });
    try {
      // เลือก API ตามโหมด
      final apiUrl = widget.is_existing_item ? '$_api_base_url/edit_item.php' : '$_api_base_url/add_item.php';
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(apiUrl),
      );

      // ถ้าแก้ไข ต้องส่ง item_id ด้วย
      if (widget.is_existing_item && widget.item_data != null) {
        request.fields['item_id'] = widget.item_data!['item_id'].toString();
      }

      request.fields['name'] = _name_controller.text;
      request.fields['quantity'] = _quantity_controller.text;
      request.fields['selected_date'] = _selected_date.toIso8601String().split('T')[0];
      request.fields['notification_days'] = _notification_days_controller.text;
      request.fields['barcode'] = _barcode_controller.text;
      request.fields['user_id'] = _current_user_id.toString();
      request.fields['category'] = _selected_category;
      request.fields['storage_location'] = _selected_storage;

      // หา area_id จากชื่อพื้นที่จัดเก็บที่เลือก
      int? areaId;
      for (var loc in _storage_locations) {
        if (loc['area_name'] == _selected_storage) {
          areaId = loc['area_id'] is int ? loc['area_id'] : int.tryParse(loc['area_id'].toString());
          break;
        }
      }
      if (areaId != null) {
        request.fields['storage_id'] = areaId.toString();
      }

      // อัปโหลดรูปภาพ (key แตกต่างกัน)
      if (_picked_image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', _picked_image!.path),
        );
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        final response_body = await response.stream.bytesToString();
        final response_data = json.decode(response_body);
        if (response_data['status'] == 'success') {
          _show_success_message(widget.is_existing_item ? 'แก้ไขข้อมูลสินค้าสำเร็จแล้ว!' : 'บันทึกข้อมูลสินค้าสำเร็จแล้ว!');
          if (widget.on_item_added != null) {
            widget.on_item_added!();
          }
          Navigator.pop(context, true);
        } else {
          _show_error_message('Error: ${response_data['message']}');
        }
      } else {
        final error_body = await response.stream.bytesToString();
        _show_error_message('Server error: ${response.statusCode} - $error_body');
      }
    // Remove duplicate/invalid code after finally
    } finally {
      setState(() {
        _is_loading = false;
      });
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _build_section_title('สินค้า'),
                          IconButton(
                            icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF4A90E2)),
                            tooltip: 'แสกนรูปภาพเพื่อดึงข้อความ',
                            onPressed: () async {
                              final result = await Navigator.pushNamed(context, '/img_to_txt');
                              if (result != null && result is String && result.isNotEmpty) {
                                setState(() {
                                  _name_controller.text = result;
                                });
                              }
                            },
                          ),
                        ],
                      ),
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
                          Stack(
                            children: [
                              Container(
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
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: PopupMenuButton<String>(
                                  icon: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.add_a_photo, size: 20, color: Color(0xFF4A90E2)),
                                  ),
                                  onSelected: (value) async {
                                    if (value == 'camera') {
                                      await _pick_image(source: ImageSource.camera);
                                    } else if (value == 'gallery') {
                                      await _pick_image(source: ImageSource.gallery);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'camera',
                                      child: ListTile(
                                        leading: Icon(Icons.photo_camera),
                                        title: Text('ถ่ายรูป'),
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'gallery',
                                      child: ListTile(
                                        leading: Icon(Icons.photo_library),
                                        title: Text('เลือกรูปจากคลัง'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                      // Modified dropdown for storage locations
                      DropdownButtonFormField<String>(
                        value: _selected_storage,
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
                        items: _storage_locations.map((loc) {
                          String item = loc['area_name'];
                          int? locUserId = loc['user_id'] != null ? int.tryParse(loc['user_id'].toString()) : null;
                          bool showDeleteIcon = (_current_user_id != null && _current_user_id != 0 && item != 'เลือกพื้นที่จัดเก็บ' && item != 'เพิ่มพื้นที่การเอง' && locUserId != null && locUserId != 0);
                          return DropdownMenuItem<String>(
                            value: item,
                            child: showDeleteIcon
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item,
                                        style: TextStyle(
                                          color: item.startsWith('เลือก')
                                              ? Colors.grey[400]
                                              : (item == 'เพิ่มพื้นที่การเอง' ? const Color(0xFF4A90E2) : Colors.black87),
                                          fontWeight: item == 'เพิ่มพื้นที่การเอง' ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        onPressed: () {
                                          Navigator.pop(context); // Close dropdown
                                          _confirm_delete_storage_dialog(item);
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  )
                                : Text(
                                    item,
                                    style: TextStyle(
                                      color: item.startsWith('เลือก')
                                          ? Colors.grey[400]
                                          : (item == 'เพิ่มพื้นที่การเอง' ? const Color(0xFF4A90E2) : Colors.black87),
                                      fontWeight: item == 'เพิ่มพื้นที่การเอง' ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue == 'เพิ่มพื้นที่การเอง') {
                            _show_add_storage_dialog();
                          } else {
                            setState(() {
                              _selected_storage = newValue!;
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.startsWith('เลือก')) {
                            return 'กรุณาเลือกตัวเลือก';
                          }
                          return null;
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
    FormFieldValidator<String>? validator,
    IconData? suffix_icon,
    VoidCallback? on_suffix_pressed,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
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
        suffixIcon: suffix_icon != null
            ? IconButton(
                icon: Icon(suffix_icon, color: Colors.grey),
                onPressed: () async {
                  if (suffix_icon == Icons.qr_code_scanner) {
                    final result = await Navigator.pushNamed(context, '/barcode_scanner');
                    if (result != null && result is String && result.isNotEmpty) {
                      controller.text = result;
                    }
                  } else if (on_suffix_pressed != null) {
                    on_suffix_pressed();
                  }
                },
              )
            : null,
      ),
      validator: validator,
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
              color: item.startsWith('เลือก')
                  ? Colors.grey[400]
                  : (item.startsWith('เพิ่ม') ? const Color(0xFF4A90E2) : Colors.black87),
              fontWeight: item.startsWith('เพิ่ม') ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue == 'เพิ่มประเภทสินค้า') {
          _show_add_category_dialog();
        } else {
          onChanged(newValue);
        }
      },
      validator: (value) {
        if (value == null || value.startsWith('เลือก')) {
          return 'กรุณาเลือกตัวเลือก';
        }
        return null;
      },
    );
  }
}