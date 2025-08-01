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
  final TextEditingController _notification_days_controller = TextEditingController(text: '');
  final GlobalKey<FormState> _form_key = GlobalKey<FormState>();

  DateTime _selected_date = DateTime.now().add(const Duration(days: 7));
  String _selected_unit = 'วันหมดอายุ(EXP)';
  String _selected_category = 'เลือกประเภท';
  String _selected_storage = 'เลือกพื้นที่จัดเก็บ';
  XFile? _picked_image;
  bool _is_loading = false;
  List<String> _units = ['วันหมดอายุ(EXP)', 'ควรบริโภคก่อน(BBF)'];
  List<String> _categories = ['เลือกประเภท'];
  List<Map<String, dynamic>> _storage_locations = [
    {'area_id': null, 'area_name': 'เลือกพื้นที่จัดเก็บ'},
    {'area_id': null, 'area_name': 'เพิ่มพื้นที่การเอง'},
  ];
  int? _current_user_id; // สำหรับเก็บ user_id
  
  // Variables for multiple storage locations
  bool _use_multiple_locations = false;
  bool _enable_multiple_locations_option = false; // เปิดใช้งานตัวเลือกกระจายสินค้า
  List<Map<String, dynamic>> _item_locations = [];
  int _remaining_quantity = 0;

  // ใช้ URL จาก .env
  final String _api_base_url = dotenv.env['API_BASE_URL'] ?? 'http://localhost';


  @override
  void initState() {
    super.initState();
    _initialize_data();
    _notification_days_controller.text = '7';
    
    // Add listener to quantity controller
    _quantity_controller.addListener(() {
      _check_multiple_locations_availability();
    });
    // ถ้าเป็นโหมดแก้ไข ให้เติมข้อมูลจาก item_data
    if (widget.is_existing_item && widget.item_data != null) {
      print('DEBUG: Populating form with item_data: ${widget.item_data}');
      final item = widget.item_data!;
      
      _name_controller.text = item['name'] ?? item['item_name'] ?? '';
      _quantity_controller.text = item['quantity']?.toString() ?? '1';
      _barcode_controller.text = item['barcode'] ?? '';
      _notification_days_controller.text = (item['item_notification'] != null && item['item_notification'].toString().trim().isNotEmpty)
          ? item['item_notification'].toString()
          : '7';
      
      // ตรวจสอบและแปลงค่า unit/date_type ให้ตรงกับ dropdown
      String rawUnit = item['unit'] ?? item['date_type'] ?? 'วันหมดอายุ(EXP)';
      print('DEBUG: Raw unit from item_data: $rawUnit');
      
      if (rawUnit == 'EXP' || rawUnit == 'วันหมดอายุ(EXP)') {
        _selected_unit = 'วันหมดอายุ(EXP)';
      } else if (rawUnit == 'BBF' || rawUnit == 'ควรบริโภคก่อน(BBF)') {
        _selected_unit = 'ควรบริโภคก่อน(BBF)';
      } else {
        // ถ้าไม่ตรง ให้ใช้ default
        _selected_unit = _units.contains(rawUnit) ? rawUnit : 'วันหมดอายุ(EXP)';
      }
      
      _selected_category = item['category'] ?? item['type_name'] ?? 'เลือกประเภท';
      _selected_storage = item['storage_location'] ?? item['area_name'] ?? 'เลือกพื้นที่จัดเก็บ';
      
      if (item['item_date'] != null) {
        try {
          _selected_date = DateTime.parse(item['item_date']);
        } catch (e) {
          _selected_date = DateTime.now().add(const Duration(days: 7));
        }
      }
      
      print('DEBUG: Form populated - name: ${_name_controller.text}, category: $_selected_category, storage: $_selected_storage, unit: $_selected_unit');
      // ไม่เติมรูปภาพเดิม (_picked_image) เพราะต้องเลือกใหม่
    }
    // ป้องกัน error dropdown: ตรวจสอบ unit เท่านั้นตอนนี้
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_units.contains(_selected_unit)) {
        setState(() {
          _selected_unit = 'วันหมดอายุ(EXP)';
        });
      }
      // Check if multiple locations should be enabled
      _check_multiple_locations_availability();
    });
  }

  @override
  void dispose() {
    _quantity_controller.removeListener(_check_multiple_locations_availability);
    super.dispose();
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
        final loadedCategories = ['เลือกประเภท'] + data.map((e) => e['type_name'] as String).toList();
        setState(() {
          _categories = loadedCategories;
          // ถ้าเป็นโหมดแก้ไขและมีข้อมูลเดิม ให้เลือก category ตามข้อมูลเดิม
          if (widget.is_existing_item && widget.item_data != null) {
            final itemCat = widget.item_data!['category'] ?? widget.item_data!['type_name'] ?? '';
            print('DEBUG: Setting category from item_data: $itemCat');
            if (_categories.contains(itemCat)) {
              _selected_category = itemCat;
              print('DEBUG: Category set to: $_selected_category');
            } else {
              _selected_category = 'เลือกประเภท';
              print('DEBUG: Category not found in list, using default');
            }
          } else {
            // สำหรับโหมดเพิ่มใหม่ ถ้า _selected_category ไม่อยู่ใน list ให้เซ็ตเป็น default
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
            final itemStorage = widget.item_data!['storage_location'] ?? widget.item_data!['area_name'] ?? '';
            print('DEBUG: Setting storage from item_data: $itemStorage');
            if (storageNames.contains(itemStorage)) {
              _selected_storage = itemStorage;
              print('DEBUG: Storage set to: $_selected_storage');
            } else {
              _selected_storage = 'เลือกพื้นที่จัดเก็บ';
              print('DEBUG: Storage not found in list, using default');
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

  bool _isDataInitialized() {
    // ตรวจสอบว่าข้อมูลได้โหลดเสร็จแล้วและไม่มีปัญหากับ dropdown values
    if (widget.is_existing_item && widget.item_data != null) {
      final storageNames = _storage_locations.map((e) => e['area_name'] as String).toList();
      return _categories.length > 2 && // มีมากกว่า default values
             _storage_locations.length > 2 && // มีมากกว่า default values
             _categories.contains(_selected_category) &&
             storageNames.contains(_selected_storage);
    }
    return true; // สำหรับโหมดเพิ่มใหม่
  }

  void _check_multiple_locations_availability() {
    final quantity = int.tryParse(_quantity_controller.text) ?? 0;
    setState(() {
      if (quantity >= 2) {
        _enable_multiple_locations_option = true;
        // ถ้าเปิดใช้งานตัวเลือกแล้ว ให้อัปเดต remaining quantity
        if (_use_multiple_locations) {
          _update_remaining_quantity();
        }
      } else {
        _enable_multiple_locations_option = false;
        _use_multiple_locations = false;
        _item_locations.clear();
        _remaining_quantity = 0;
      }
    });
  }

  void _update_remaining_quantity() {
    final totalQuantity = int.tryParse(_quantity_controller.text) ?? 0;
    final distributedQuantity = _item_locations.fold<int>(
      0, 
      (sum, location) => sum + (location['quantity'] as int? ?? 0)
    );
    
    // คำนวณจำนวนที่เหลือ โดยลบจำนวนที่กระจายในหลายพื้นที่
    // และลบ 1 ชิ้นสำหรับพื้นที่หลักที่เลือกไว้แล้ว (ถ้ามี)
    int usedInMainLocation = 0;
    if (_selected_storage != 'เลือกพื้นที่จัดเก็บ') {
      usedInMainLocation = 1;
    }
    
    setState(() {
      _remaining_quantity = totalQuantity - distributedQuantity - usedInMainLocation;
    });
  }

  void _toggle_multiple_locations(bool value) {
    setState(() {
      _use_multiple_locations = value;
      if (value) {
        _update_remaining_quantity();
      } else {
        _item_locations.clear();
        _remaining_quantity = 0;
      }
    });
  }

  void _add_storage_location() {
    if (_remaining_quantity <= 0) {
      _show_error_message('ไม่มีจำนวนสินค้าเหลือที่จะกระจาย');
      return;
    }
    
    // Check if there are available storage locations
    final availableLocations = _storage_locations
        .where((loc) => loc['area_name'] != 'เลือกพื้นที่จัดเก็บ' && 
                       loc['area_name'] != 'เพิ่มพื้นที่การเอง')
        .toList();
    
    if (availableLocations.isEmpty) {
      _show_error_message('ไม่มีพื้นที่จัดเก็บให้เลือก กรุณาเพิ่มพื้นที่จัดเก็บก่อน');
      return;
    }
    
    // Find first available storage location that's not already selected
    String defaultArea = '';
    int? defaultAreaId;
    
    for (var loc in availableLocations) {
      String areaName = loc['area_name'];
      // Check if this area is already used
      bool alreadyUsed = _item_locations.any((item) => item['area_name'] == areaName);
      if (!alreadyUsed) {
        defaultArea = areaName;
        defaultAreaId = loc['area_id'];
        break;
      }
    }
    
    // If no available area found, use the first valid area
    if (defaultArea.isEmpty && availableLocations.isNotEmpty) {
      defaultArea = availableLocations.first['area_name'];
      defaultAreaId = availableLocations.first['area_id'];
    }
    
    setState(() {
      _item_locations.add({
        'area_id': defaultAreaId,
        'area_name': defaultArea,
        'quantity': 1,
      });
      _update_remaining_quantity();
    });
  }

  void _remove_storage_location(int index) {
    setState(() {
      _item_locations.removeAt(index);
      _update_remaining_quantity();
    });
  }

  void _update_location_quantity(int index, int quantity) {
    setState(() {
      _item_locations[index]['quantity'] = quantity;
      _update_remaining_quantity();
    });
  }

  void _update_location_area(int index, String areaName, int? areaId) {
    setState(() {
      _item_locations[index]['area_name'] = areaName;
      _item_locations[index]['area_id'] = areaId;
    });
  }

  Future<void> _pick_image({required ImageSource source}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    setState(() {
      _picked_image = image;
    });
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ลบ', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                _delete_storage_location(area_name);
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
        Uri.parse('$_api_base_url/delete_area.php'),
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
          await _fetch_storage_locations();
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
      
      if (_use_multiple_locations && _enable_multiple_locations_option) {
        // ตรวจสอบว่าเลือกพื้นที่หลักแล้วหรือไม่
        if (_selected_storage == 'เลือกพื้นที่จัดเก็บ') {
          _show_error_message('กรุณาเลือกพื้นที่จัดเก็บหลักก่อน');
          return false;
        }
        
        // ถ้ามี remaining quantity > 0 แต่ไม่มี additional locations
        if (_remaining_quantity > 0 && _item_locations.isEmpty) {
          _show_error_message('กรุณาเพิ่มพื้นที่เพิ่มเติมหรือลดจำนวนสินค้า (เหลือ $_remaining_quantity ชิ้น)');
          return false;
        }
        
        if (_remaining_quantity > 0 && _item_locations.isNotEmpty) {
          _show_error_message('กรุณากระจายสินค้าให้ครบทุกชิ้น (เหลือ $_remaining_quantity ชิ้น)');
          return false;
        }
        
        // Check if all additional locations have valid area selected
        for (var location in _item_locations) {
          if (location['area_name'] == 'เลือกพื้นที่จัดเก็บ' || 
              location['area_id'] == null || 
              location['area_name'] == null || 
              location['area_name'].toString().isEmpty) {
            _show_error_message('กรุณาเลือกพื้นที่จัดเก็บให้ครบทุกรายการ');
            return false;
          }
        }
        
      } else {
        // Validate single location (ไม่ใช้ multiple locations หรือมีสินค้าน้อยกว่า 2 ชิ้น)
        if (_selected_storage == 'เลือกพื้นที่จัดเก็บ') {
          _show_error_message('กรุณาเลือกพื้นที่จัดเก็บ');
          return false;
        }
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

  // เพิ่มฟังก์ชันสำหรับดึง default image ตามประเภทสินค้า
  Future<String> _get_default_image_for_category(String category) async {
    print('DEBUG: Getting default image for category: $category');
    try {
      final response = await http.get(
        Uri.parse('$_api_base_url/get_default_image.php?category=${Uri.encodeComponent(category)}')
      );
      
      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('DEBUG: Parsed data: $data');
        if (data['status'] == 'success') {
          String defaultImage = data['default_image'] ?? 'default.png';
          print('DEBUG: Returning default image: $defaultImage');
          return defaultImage;
        }
      }
    } catch (e) {
      print('Error getting default image: $e');
    }
    print('DEBUG: Using fallback default.png');
    return 'default.png'; // fallback
  }

  Future<void> _save_item() async {
    if (!_validate_form_data()) {
      return;
    }

    print('DEBUG: Starting _save_item()');
    print('DEBUG: Form data validation passed');

    setState(() {
      _is_loading = true;
    });
    try {
      // สำหรับการสแกนบาร์โค้ดของสินค้าที่มีอยู่ ให้ใช้ add_item.php เสมอ
      // เพราะเราเพิ่มสินค้าใหม่โดยใช้ข้อมูลเดิมเป็นต้นแบบ
      final apiUrl = '$_api_base_url/add_item.php';
      print('DEBUG: API URL: $apiUrl');
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(apiUrl),
      );

      // ไม่ต้องส่ง item_id เพราะเป็นการเพิ่มใหม่เสมอ
      // แม้ว่าจะใช้ข้อมูลเดิมเป็นต้นแบบ

      request.fields['name'] = _name_controller.text;
      request.fields['quantity'] = _quantity_controller.text;
      request.fields['selected_date'] = _selected_date.toIso8601String().split('T')[0];
      request.fields['notification_days'] = _notification_days_controller.text;
      request.fields['barcode'] = _barcode_controller.text;
      request.fields['user_id'] = _current_user_id.toString();
      request.fields['category'] = _selected_category;
      request.fields['date_type'] = _selected_unit;

      // Handle multiple locations or single location
      if (_use_multiple_locations && _enable_multiple_locations_option && _item_locations.isNotEmpty) {
        // Send multiple locations data
        request.fields['use_multiple_locations'] = 'true';
        request.fields['item_locations'] = json.encode(_item_locations);
        
        // For backward compatibility, use the first location as primary
        request.fields['storage_location'] = _item_locations[0]['area_name'];
        if (_item_locations[0]['area_id'] != null) {
          request.fields['storage_id'] = _item_locations[0]['area_id'].toString();
        }
        print('DEBUG: Using multiple locations');
        print('DEBUG: item_locations: ${json.encode(_item_locations)}');
      } else {
        // Single location (original behavior)
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
        print('DEBUG: Using single location');
        print('DEBUG: storage_location: $_selected_storage');
        print('DEBUG: storage_id (area_id): $areaId');
      }

      // Log all fields being sent
      print('DEBUG: All request fields:');
      request.fields.forEach((key, value) {
        print('DEBUG: $key = $value');
      });

      // อัปโหลดรูปภาพ (key ต้องเป็น 'item_img' เพื่อรองรับแก้ไข)
      if (_picked_image != null) {
        print('DEBUG: Adding image file: ${_picked_image!.path}');
        request.files.add(
          await http.MultipartFile.fromPath('item_img', _picked_image!.path),
        );
      } else {
        // ใช้ default image สำหรับประเภทที่เลือก
        String defaultImage = await _get_default_image_for_category(_selected_category);
        request.fields['default_image'] = defaultImage;
        print('DEBUG: Using default image: $defaultImage');
      }

      print('DEBUG: Sending request...');
      var response = await request.send();
      print('DEBUG: Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final response_body = await response.stream.bytesToString();
        print('DEBUG: Response body: $response_body');
        final response_data = json.decode(response_body);
        print('DEBUG: Parsed response: $response_data');
        
        if (response_data['status'] == 'success') {
          print('DEBUG: Success! Item saved successfully');
          _show_success_message('บันทึกข้อมูลสินค้าสำเร็จแล้ว!');
          if (widget.on_item_added != null) {
            widget.on_item_added!();
          }
          Navigator.pop(context, true);
        } else {
          print('DEBUG: API returned error: ${response_data['message']}');
          _show_error_message('Error: ${response_data['message']}');
        }
      } else {
        final error_body = await response.stream.bytesToString();
        print('DEBUG: HTTP error ${response.statusCode}: $error_body');
        _show_error_message('Server error: ${response.statusCode} - $error_body');
      }
    // Remove duplicate/invalid code after finally
    } catch (e) {
      print('DEBUG: Exception occurred: $e');
      _show_error_message('เกิดข้อผิดพลาด: $e');
    } finally {
      print('DEBUG: _save_item() completed');
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
      body: (_is_loading && _categories.length <= 1 && _storage_locations.length <= 1) || 
             (widget.is_existing_item && !_isDataInitialized())
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
                              value: _units.contains(_selected_unit) ? _selected_unit : 'วันหมดอายุ(EXP)',
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
                        value: _categories.contains(_selected_category) ? _selected_category : 'เลือกประเภท',
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
                        value: _storage_locations.map((e) => e['area_name'] as String).contains(_selected_storage) 
                            ? _selected_storage 
                            : 'เลือกพื้นที่จัดเก็บ',
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
                              // อัปเดต remaining quantity เมื่อเปลี่ยนพื้นที่หลัก
                              if (_use_multiple_locations) {
                                _update_remaining_quantity();
                              }
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
                      
                      // Multiple locations option toggle
                      if (_enable_multiple_locations_option) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ต้องการเพิ่มพื้นที่จัดเก็บมากกว่าหนึ่งแห่งหรือไม่?',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'เลือก "ใช่" หากต้องการแยกจำนวนสินค้าไปเก็บในพื้นที่หลายแห่ง',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Switch(
                                value: _use_multiple_locations,
                                onChanged: _toggle_multiple_locations,
                                activeColor: const Color(0xFF4A90E2),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Multiple storage locations section
                      if (_use_multiple_locations && _enable_multiple_locations_option) ...[
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _build_section_title('กระจายสินค้าไปพื้นที่เพิ่มเติม'),
                            Text(
                              'เหลือ: $_remaining_quantity ชิ้น',
                              style: TextStyle(
                                fontSize: 14,
                                color: _remaining_quantity > 0 ? Colors.orange : Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // List of distributed locations
                        ...List.generate(_item_locations.length, (index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[50],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: DropdownButtonFormField<String>(
                                        value: _item_locations[index]['area_name'],
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            borderSide: BorderSide(color: Colors.grey[300]!),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            borderSide: BorderSide(color: Colors.grey[300]!),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            borderSide: const BorderSide(color: Color(0xFF4A90E2)),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        items: _storage_locations
                                            .where((loc) => loc['area_name'] != 'เลือกพื้นที่จัดเก็บ' && 
                                                           loc['area_name'] != 'เพิ่มพื้นที่การเอง')
                                            .map((loc) {
                                          return DropdownMenuItem<String>(
                                            value: loc['area_name'],
                                            child: Text(
                                              loc['area_name'],
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (newValue) {
                                          if (newValue != null) {
                                            final selectedLocation = _storage_locations.firstWhere(
                                              (loc) => loc['area_name'] == newValue
                                            );
                                            _update_location_area(index, newValue, selectedLocation['area_id']);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey[300]!),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: IconButton(
                                              onPressed: () {
                                                final currentQty = _item_locations[index]['quantity'] as int;
                                                if (currentQty > 1) {
                                                  _update_location_quantity(index, currentQty - 1);
                                                }
                                              },
                                              icon: const Icon(Icons.remove, size: 12),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            width: 40,
                                            height: 28,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey[300]!),
                                              borderRadius: BorderRadius.circular(4),
                                              color: Colors.white,
                                            ),
                                            child: Text(
                                              '${_item_locations[index]['quantity']}',
                                              style: const TextStyle(fontSize: 12),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey[300]!),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: IconButton(
                                              onPressed: () {
                                                final currentQty = _item_locations[index]['quantity'] as int;
                                                if (currentQty < _remaining_quantity + currentQty) {
                                                  _update_location_quantity(index, currentQty + 1);
                                                }
                                              },
                                              icon: const Icon(Icons.add, size: 12),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _remove_storage_location(index),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        // Add more location button
                        if (_remaining_quantity > 0)
                          Container(
                            width: double.infinity,
                            height: 40,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: OutlinedButton.icon(
                              onPressed: _add_storage_location,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('เพิ่มพื้นที่เพิ่มเติม'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4A90E2),
                                side: const BorderSide(color: Color(0xFF4A90E2)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                      ],
                      
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
    // ป้องกัน error โดยตรวจสอบว่า value อยู่ใน items หรือไม่
    String safeValue = items.contains(value) ? value : items.first;
    
    return DropdownButtonFormField<String>(
      value: safeValue,
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
        onChanged(newValue);
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