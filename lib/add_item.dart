import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_switch/flutter_switch.dart';

class AddItemPage extends StatefulWidget {
  final bool is_existing_item;
  final VoidCallback? on_item_added;
  final Map<String, dynamic>? item_data;

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
  
  // Variables for date dropdown selection
  int _selected_day = DateTime.now().add(const Duration(days: 7)).day;
  int _selected_month = DateTime.now().add(const Duration(days: 7)).month;
  int _selected_year = DateTime.now().add(const Duration(days: 7)).year;
  
  String _selected_unit = 'วันหมดอายุ(EXP)';
  String _selected_category = 'เลือกประเภท';
  String _selected_storage = 'เลือกพื้นที่จัดเก็บ';
  String? _temp_category_from_item_data; // เก็บหมวดหมู่ชั่วคราวจาก item_data
  String? _temp_storage_from_item_data; // เก็บพื้นที่จัดเก็บชั่วคราวจาก item_data
  XFile? _picked_image;
  bool _is_loading = false;
  List<String> _units = ['วันหมดอายุ(EXP)', 'ควรบริโภคก่อน(BBF)'];
  List<String> _categories = ['เลือกประเภท'];
  List<Map<String, dynamic>> _storage_locations = [
    {'area_id': null, 'area_name': 'เลือกพื้นที่จัดเก็บ'},
    {'area_id': null, 'area_name': 'เพิ่มพื้นที่การเอง'},
  ];
  int? _current_user_id; // สำหรับเก็บ user_id
  
  // Variables for multiple storage locations (old system)
  bool _use_multiple_locations = false;
  bool _enable_multiple_locations_option = false;
  List<Map<String, dynamic>> _item_locations = [];
  int _remaining_quantity = 0;

  bool _allow_separate_storage = false; // ให้ผู้ใช้เลือกว่าจะแยกพื้นที่เก็บหรือไม่
  List<Map<String, dynamic>> _item_storage_details = []; // พื้นที่เก็บแต่ละชิ้น
  List<Map<String, dynamic>> _storage_groups = []; // กลุ่มพื้นที่เก็บ (พื้นที่ + จำนวน)
  
  // Cache for modified preview items (Option B approach)
  List<Map<String, dynamic>>? _cached_preview_items;

  bool _use_multiple_expire_dates = false;
  bool _allow_separate_expire_dates = false; // ให้ผู้ใช้เลือกว่าจะแยกวันหมดอายุหรือไม่
  List<Map<String, dynamic>> _item_expire_details = []; // วันหมดอายุแต่ละชิ้น
  List<Map<String, dynamic>> _expire_date_groups = []; // กลุ่มวันหมดอายุ (วันที่ + จำนวน)

  // ใช้ URL จาก .env
  final String _api_base_url = dotenv.env['API_BASE_URL'] ?? 'http://localhost';


  @override
  void initState() {
    super.initState();
    // Sync dropdown values with _selected_date
    _selected_day = _selected_date.day;
    _selected_month = _selected_date.month;
    _selected_year = _selected_date.year;
    
    _initialize_data();
    _notification_days_controller.text = '7';

    _quantity_controller.addListener(() {
      _clear_preview_cache(); // Clear cache when quantity changes
      _check_multiple_locations_availability();
      
      // อัปเดตข้อมูลเมื่อจำนวนเปลี่ยน
      if (_use_multiple_locations) {
        _update_remaining_quantity();
      }
      
    
      if (_allow_separate_expire_dates && _expire_date_groups.isNotEmpty) {
        final newTotal = int.tryParse(_quantity_controller.text) ?? 0;
        final currentTotal = _get_total_grouped_quantity();
        
        if (newTotal != currentTotal && newTotal > 0) {
        
          if (_expire_date_groups.isNotEmpty) {
            final difference = newTotal - currentTotal;
            final firstGroup = _expire_date_groups[0];
            final newFirstGroupQty = (firstGroup['quantity'] as int) + difference;
            
            if (newFirstGroupQty > 0) {
              firstGroup['quantity'] = newFirstGroupQty;
            } else {
              // ถ้าจำนวนน้อยลง ให้ปรับทุกกลุ่ม
              _expire_date_groups.clear();
              _expire_date_groups.add({
                'expire_date': _selected_date,
                'quantity': newTotal,
                'unit': _selected_unit,
              });
            }
          }
        }
      }
      
      // อัปเดตกลุ่มพื้นที่เก็บถ้าจำเป็น
      if (_allow_separate_storage && _storage_groups.isNotEmpty) {
        final newTotal = int.tryParse(_quantity_controller.text) ?? 0;
        final currentTotal = _get_total_grouped_storage_quantity();
        
        if (newTotal != currentTotal && newTotal > 0) {
          // ปรับกลุ่มแรกให้ตรงกับจำนวนใหม่
          if (_storage_groups.isNotEmpty) {
            final difference = newTotal - currentTotal;
            final firstGroup = _storage_groups[0];
            final newFirstGroupQty = (firstGroup['quantity'] as int) + difference;
            
            if (newFirstGroupQty > 0) {
              firstGroup['quantity'] = newFirstGroupQty;
            } else {
              // ถ้าจำนวนน้อยลง ให้ปรับทุกกลุ่ม
              _storage_groups.clear();
              _storage_groups.add({
                'area_id': null,
                'area_name': null, // ให้ผู้ใช้เลือกเอง
                'quantity': newTotal,
              });
            }
          }
        }
      }
    });
    
    if (widget.item_data != null) {
      final item = widget.item_data!;
      
      _name_controller.text = item['name'] ?? item['item_name'] ?? '';
      _quantity_controller.text = item['quantity']?.toString() ?? '1';
      _barcode_controller.text = item['barcode'] ?? item['item_barcode'] ?? '';
      _notification_days_controller.text = (item['item_notification'] != null && item['item_notification'].toString().trim().isNotEmpty)
          ? item['item_notification'].toString()
          : '7';
      
      
      String rawUnit = item['unit'] ?? item['date_type'] ?? 'วันหมดอายุ(EXP)';
      
      if (rawUnit == 'EXP' || rawUnit == 'วันหมดอายุ(EXP)') {
        _selected_unit = 'วันหมดอายุ(EXP)';
      } else if (rawUnit == 'BBF' || rawUnit == 'ควรบริโภคก่อน(BBF)') {
        _selected_unit = 'ควรบริโภคก่อน(BBF)';
      } else {
        // ถ้าไม่ตรง ให้ใช้ default
        _selected_unit = _units.contains(rawUnit) ? rawUnit : 'วันหมดอายุ(EXP)';
      }
      
      
      _temp_category_from_item_data = item['category'] ?? item['type_name'] ?? '';
      
      // เก็บพื้นที่จัดเก็บไว้ชั่วคราว รอ _fetch_storage_locations() ตั้งค่าให้
      _temp_storage_from_item_data = item['storage_location'] ?? item['area_name'] ?? '';
      if (_temp_storage_from_item_data != null && _temp_storage_from_item_data!.isNotEmpty) {
        _selected_storage = _temp_storage_from_item_data!;
      }
      
      if (item['item_date'] != null) {
        try {
          _selected_date = DateTime.parse(item['item_date']);
          // Sync dropdown values
          _selected_day = _selected_date.day;
          _selected_month = _selected_date.month;
          _selected_year = _selected_date.year;
        } catch (e) {
          _selected_date = DateTime.now().add(const Duration(days: 7));
          // Sync dropdown values for default date
          _selected_day = _selected_date.day;
          _selected_month = _selected_date.month;
          _selected_year = _selected_date.year;
        }
      }
    }
    
    // โหลดข้อมูลเพิ่มเติมสำหรับโหมดแก้ไขเท่านั้น
    if (widget.is_existing_item && widget.item_data != null) {
      final item = widget.item_data!;
      
      // โหลดข้อมูล item_expire_details (วันหมดอายุแต่ละชิ้น) ถ้ามี
      if (item['item_expire_details'] != null) {
        final existingExpireDetails = item['item_expire_details'] as List;
        
        // Clear existing data
        _item_expire_details.clear();
        
        // Load existing expire details (เฉพาะสถานะ active เท่านั้น)
        for (int i = 0; i < existingExpireDetails.length; i++) {
          final detail = existingExpireDetails[i];
          
          // กรองเฉพาะสถานะ active เท่านั้น
          if (detail['status'] != null && detail['status'] != 'active') {
            continue;
          }
          
          DateTime expireDate;
          try {
            expireDate = DateTime.parse(detail['expire_date']);
          } catch (e) {
            expireDate = _selected_date;
          }
          
          _item_expire_details.add({
            'id': detail['detail_id'] ?? detail['item_detail_id'] ?? detail['id'], // detail_id สำหรับ API
            'index': _item_expire_details.length, // ใช้ index จากข้อมูลที่กรองแล้ว
            'expire_date': expireDate,
            'barcode': detail['barcode'] ?? _barcode_controller.text,
            'item_img': detail['item_img'],
            'area_id': detail['area_id'], // เพิ่ม area_id
            'area_name': detail['area_name'], // เพิ่ม area_name
            'quantity': detail['quantity'] ?? 1,
          });
        }
        
        // ถ้ามีมากกว่า 1 ชิ้น ให้เปิดใช้งาน multiple expire dates
        if (_item_expire_details.length > 1) {
          _use_multiple_expire_dates = true;
          _allow_separate_expire_dates = true; // ในโหมดแก้ไข ถ้ามีข้อมูลแยกอยู่แล้ว
        }
        
        // อัปเดต quantity ให้ตรงกับจำนวน active items เท่านั้น
        _quantity_controller.text = _item_expire_details.length.toString();
      }
      
      // โหลดข้อมูล item_locations (พื้นที่จัดเก็บหลายแห่ง) ถ้ามี
      if (item['storage_locations'] != null) {
        final existingStorageLocations = item['storage_locations'] as List;
        
        // Clear existing data
        _item_locations.clear();
        
        // Load existing storage locations ยกเว้นพื้นที่หลัก
        String mainAreaName = '';
        
        // หาพื้นที่หลักและคำนวณจำนวนที่กระจาย
        for (final locationData in existingStorageLocations) {
          if (locationData['is_main'] == true || locationData['is_main'] == 1) {
            mainAreaName = locationData['area_name'] ?? '';
          } else {
            _item_locations.add({
              'area_id': locationData['area_id'],
              'area_name': locationData['area_name'],
              'quantity': locationData['quantity'] ?? 1,
            });
          }
        }
        
        // ถ้าไม่มีพื้นที่หลัก ให้เอาพื้นที่แรกเป็นหลัก
        if (mainAreaName.isEmpty && existingStorageLocations.isNotEmpty) {
          final firstLocation = existingStorageLocations.first;
          mainAreaName = firstLocation['area_name'] ?? '';
          
          // ลบพื้นที่แรกออกจาก _item_locations และปรับจำนวน
          if (_item_locations.isNotEmpty && _item_locations.first['area_name'] == mainAreaName) {
            final removedLocation = _item_locations.removeAt(0);
            final originalQty = removedLocation['quantity'] as int;
            
 
            if (originalQty > 1) {
              _item_locations.insert(0, {
                'area_id': removedLocation['area_id'],
                'area_name': removedLocation['area_name'],
                'quantity': originalQty - 1,
              });
            }
          }
          
        }
        
        // ตั้งค่าพื้นที่หลักถ้าพบ
        if (mainAreaName.isNotEmpty) {
          _selected_storage = mainAreaName;
        }
        
        // ถ้ามีการกระจายพื้นที่เก็บ ให้เปิดใช้งาน multiple locations
        if (_item_locations.isNotEmpty) {
          _use_multiple_locations = true;
          _enable_multiple_locations_option = true;
          
          // คำนวณ remaining quantity
          _update_remaining_quantity();
        }
      }
      
      // ไม่เติมรูปภาพเดิม (_picked_image) เพราะต้องเลือกใหม่
    }
    // ป้องกัน error dropdown: ตรวจสอบ unit เท่านั้นตอนนี้
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_units.contains(_selected_unit)) {
        setState(() {
          _selected_unit = 'วันหมดอายุ(EXP)';
        });
      }
      
      // ตั้งค่าหมวดหมู่อีกครั้งหลังจากที่ _categories โหลดเสร็จแล้ว (ทั้งโหมดแก้ไขและโหมดเพิ่มใหม่)
      if (widget.item_data != null && _temp_category_from_item_data != null) {
        // ใช้ Future.delayed เพื่อให้แน่ใจว่า _categories โหลดเสร็จแล้ว
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _categories.contains(_temp_category_from_item_data!) && _temp_category_from_item_data!.isNotEmpty) {
            setState(() {
              _selected_category = _temp_category_from_item_data!;
            });
          }
        });
      }
      
      // ตั้งค่าพื้นที่จัดเก็บอีกครั้งหลังจากที่ _storage_locations โหลดเสร็จแล้ว
      if (widget.item_data != null && _temp_storage_from_item_data != null) {
        // ใช้ Future.delayed เพื่อให้แน่ใจว่า _storage_locations โหลดเสร็จแล้ว
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _temp_storage_from_item_data!.isNotEmpty) {
            final storageNames = _storage_locations.map((e) => e['area_name'] as String).toList();
            if (storageNames.contains(_temp_storage_from_item_data!)) {
              setState(() {
                _selected_storage = _temp_storage_from_item_data!;
              });
            }
          }
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
          // ถ้ามี item_data ให้เลือก category ตามข้อมูลที่ส่งมา
          if (widget.item_data != null && _temp_category_from_item_data != null) {
            final itemCat = _temp_category_from_item_data ?? '';
            if (_categories.contains(itemCat) && itemCat.isNotEmpty) {
              _selected_category = itemCat;
            } else {
              _selected_category = 'เลือกประเภท';
            }
          } else {
            // สำหรับกรณีไม่มี item_data ถ้า _selected_category ไม่อยู่ใน list ให้เซ็ตเป็น default
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
          // ตั้งค่าพื้นที่จัดเก็บตามข้อมูลที่ส่งมา
          if (widget.item_data != null && _temp_storage_from_item_data != null) {
            // ไม่ใช้ข้อมูลจาก storage_location ที่เป็น string รวม เพราะจะตั้งจาก storage_locations แล้ว
            // เฉพาะกรณีที่ไม่มี storage_locations ถึงจะใช้ storage_location
            if (widget.item_data!['storage_locations'] == null) {
              final itemStorage = _temp_storage_from_item_data!;
              if (storageNames.contains(itemStorage) && itemStorage.isNotEmpty) {
                _selected_storage = itemStorage;
              } else if (!storageNames.contains(_selected_storage)) {
                _selected_storage = 'เลือกพื้นที่จัดเก็บ';
              }
            }
            // หมายเหตุ: สำหรับ multiple locations, _selected_storage จะถูกตั้งค่าใน initState แล้ว
            
            // ถ้ามีการใช้ multiple locations ให้อัปเดต remaining quantity
            if (_use_multiple_locations && _item_locations.isNotEmpty) {
              _update_remaining_quantity();
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

  // Update _selected_date from dropdown values
  void _update_selected_date() {
    try {
      _selected_date = DateTime(_selected_year, _selected_month, _selected_day);
    } catch (e) {
      // If invalid date, reset to valid date
      _selected_date = DateTime(_selected_year, _selected_month, 1);
      _selected_day = 1;
    }
  }

  // Get list of months in Thai
  List<Map<String, dynamic>> _get_months() {
    return [
      {'value': 1, 'name': '01'},
      {'value': 2, 'name': '02'},
      {'value': 3, 'name': '03'},
      {'value': 4, 'name': '04'},
      {'value': 5, 'name': '05'},
      {'value': 6, 'name': '06'},
      {'value': 7, 'name': '07'},
      {'value': 8, 'name': '08'},
      {'value': 9, 'name': '09'},
      {'value': 10, 'name': '10'},
      {'value': 11, 'name': '11'},
      {'value': 12, 'name': '12'},
    ];
  }

  // Get list of years (from last year to 20 years in the future)
  List<int> _get_years() {
    int currentYear = DateTime.now().year;
    return List.generate(22, (index) => currentYear - 1 + index); // From last year to +20 years (22 years total)
  }

  String _format_date(DateTime date) {
    String day = date.day.toString().padLeft(2, '0');
    String month = date.month.toString().padLeft(2, '0');
    return "$day/$month/${date.year}"; // Show in DD/MM/YYYY format
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
    // ในโหมดแก้ไข ไม่ต้องทำอะไร เพราะข้อมูลถูกโหลดจากฐานข้อมูลแล้ว
    if (widget.is_existing_item) {
      return;
    }
    
    final quantity = int.tryParse(_quantity_controller.text) ?? 0;
    setState(() {
      if (quantity >= 2) {
        _enable_multiple_locations_option = true;
        // ไม่เปิดใช้งานการกรอกวันหมดอายุแต่ละชิ้นโดยอัตโนมัติ
        // ให้ผู้ใช้เลือกเอง
        
        // ถ้าเปิดใช้งานตัวเลือกแล้ว ให้อัปเดต remaining quantity
        if (_use_multiple_locations) {
          _update_remaining_quantity();
        }
      } else {
        _enable_multiple_locations_option = false;
        _use_multiple_locations = false;
        _use_multiple_expire_dates = false;
        _allow_separate_expire_dates = false;
        _item_locations.clear();
        _item_expire_details.clear();
        _remaining_quantity = 0;
      }
    });
  }

  void _initialize_expire_details() {
    final quantity = int.tryParse(_quantity_controller.text) ?? 0;
    
    // ถ้าเป็นโหมดแก้ไขและมีข้อมูลเดิมอยู่แล้ว และจำนวนไม่เปลี่ยน ไม่ต้องทำอะไร
    if (widget.is_existing_item && _item_expire_details.length == quantity && quantity > 0) {
      return;
    }
    
    // ถ้าจำนวนใหม่มากกว่าจำนวนเดิม ให้เพิ่ม
    if (quantity > _item_expire_details.length) {
      for (int i = _item_expire_details.length; i < quantity; i++) {
        _item_expire_details.add({
          'index': i,
          'expire_date': _selected_date, // เริ่มต้นด้วยวันเดียวกัน
          'barcode': _barcode_controller.text,
          'item_img': null,
        });
      }
    }
    // ถ้าจำนวนใหม่น้อยกว่าจำนวนเดิม ให้ลด
    else if (quantity < _item_expire_details.length) {
      _item_expire_details.removeRange(quantity, _item_expire_details.length);
    }
  }

  void _toggle_separate_expire_dates(bool value) {
    setState(() {
      _allow_separate_expire_dates = value;
      if (value) {
        _use_multiple_expire_dates = true;
        _initialize_expire_groups(); // ใช้ระบบกลุ่มแทน
        _initialize_expire_details();
      } else {
        _use_multiple_expire_dates = false;
        // ล้างข้อมูลวันหมดอายุแต่ละชิ้น
        _item_expire_details.clear();
        _expire_date_groups.clear();
      }
    });
  }

  void _update_expire_date(int index, DateTime date) {
    if (index < _item_expire_details.length) {
      setState(() {
        _item_expire_details[index]['expire_date'] = date;
      });
    }
  }

  // จัดการกลุ่มวันหมดอายุ
  void _initialize_expire_groups() {
    final totalQuantity = int.tryParse(_quantity_controller.text) ?? 1;
    
    if (_expire_date_groups.isEmpty && totalQuantity > 1) {
      setState(() {
        _expire_date_groups = [
          {
            'expire_date': _selected_date,
            'quantity': totalQuantity,
            'unit': _selected_unit,
          }
        ];
      });
    }
  }

  void _add_expire_group() {
    final totalQuantity = int.tryParse(_quantity_controller.text) ?? 0;
    final currentTotal = _get_total_grouped_quantity();
    
    if (currentTotal >= totalQuantity) {
      _show_error_message('ได้จัดสรรสิ่งของครบตามจำนวนแล้ว');
      return;
    }
    
    final remainingQuantity = totalQuantity - currentTotal;
    
    setState(() {
      _expire_date_groups.add({
        'expire_date': DateTime.now().add(const Duration(days: 7)),
        'quantity': remainingQuantity > 0 ? (remainingQuantity > 1 ? 1 : remainingQuantity) : 1,
        'unit': _selected_unit,
      });
    });
  }

  void _remove_expire_group(int index) {
    if (_expire_date_groups.length > 1) {
      setState(() {
        _expire_date_groups.removeAt(index);
      });
    }
  }

  void _update_expire_group_date(int index, DateTime date) {
    if (index < _expire_date_groups.length) {
      setState(() {
        _expire_date_groups[index]['expire_date'] = date;
      });
    }
  }

  void _update_expire_group_quantity(int index, int quantity) {
    if (index < _expire_date_groups.length) {
      setState(() {
        _expire_date_groups[index]['quantity'] = quantity;
        // อัปเดตการแสดงผลเพื่อให้เห็นการเปลี่ยนแปลงช่วงชิ้น
      });
    }
  }

  void _update_expire_group_unit(int index, String unit) {
    if (index < _expire_date_groups.length) {
      setState(() {
        // ตรวจสอบว่าถ้าเปลี่ยนเป็น BBF ให้เปลี่ยนทั้งหมดเป็น BBF 
        // เนื่องจากฐานข้อมูลรองรับเฉพาะประเภทเดียว
        if (unit == 'ควรบริโภคก่อน(BBF)') {
          // เปลี่ยนทุกกลุ่มเป็น BBF
          for (int i = 0; i < _expire_date_groups.length; i++) {
            _expire_date_groups[i]['unit'] = unit;
          }
          // เปลี่ยน selected_unit หลักด้วย
          _selected_unit = unit;
        } else if (unit == 'วันหมดอายุ(EXP)') {
          // ถ้าเปลี่ยนเป็น EXP ให้เปลี่ยนทุกกลุ่มเป็น EXP
          for (int i = 0; i < _expire_date_groups.length; i++) {
            _expire_date_groups[i]['unit'] = unit;
          }
          // เปลี่ยน selected_unit หลักด้วย
          _selected_unit = unit;
        }
      });
    }
  }

  int _get_total_grouped_quantity() {
    return _expire_date_groups.fold<int>(
      0, 
      (sum, group) => sum + (group['quantity'] as int? ?? 0)
    );
  }

  // ฟังก์ชันใหม่: รีเซ็ตจำนวนในกลุ่มให้เท่ากันทั้งหมด
  void _distribute_equally() {
    final totalQuantity = int.tryParse(_quantity_controller.text) ?? 0;
    final groupCount = _expire_date_groups.length;
    
    if (groupCount > 0 && totalQuantity > 0) {
      setState(() {
        final baseQuantity = totalQuantity ~/ groupCount;
        final remainder = totalQuantity % groupCount;
        
        for (int i = 0; i < _expire_date_groups.length; i++) {
          // กลุ่มแรกๆ จะได้เศษจำนวนที่เหลือ
          _expire_date_groups[i]['quantity'] = baseQuantity + (i < remainder ? 1 : 0);
        }
      });
    }
  }

  void _update_remaining_quantity() {
    final totalQuantity = int.tryParse(_quantity_controller.text) ?? 0;
    final distributedQuantity = _item_locations.fold<int>(
      0, 
      (sum, location) => sum + (location['quantity'] as int? ?? 0)
    );
    
    // คำนวณจำนวนในพื้นที่หลัก
    final mainLocationQuantity = totalQuantity - distributedQuantity;
    
    setState(() {
      // ตรวจสอบว่าการกระจายไม่เกินจำนวนทั้งหมด
      if (distributedQuantity > totalQuantity) {
        // ถ้ากระจายเกิน ให้ปรับลดจำนวนใน locations จากท้ายไปหน้า
        int excessQuantity = distributedQuantity - totalQuantity;
        
        for (int i = _item_locations.length - 1; i >= 0 && excessQuantity > 0; i--) {
          final location = _item_locations[i];
          final currentQty = location['quantity'] as int;
          final reduction = (excessQuantity >= currentQty) ? currentQty - 1 : excessQuantity;
          
          if (reduction > 0) {
            location['quantity'] = currentQty - reduction;
            excessQuantity -= reduction;
            
            // ถ้าจำนวนเหลือ 0 ให้ลบ location นั้นออก
            if (location['quantity'] <= 0) {
              _item_locations.removeAt(i);
            }
          }
        }
        
        // คำนวณใหม่หลังจากปรับ
        final newDistributedQuantity = _item_locations.fold<int>(
          0, 
          (sum, location) => sum + (location['quantity'] as int? ?? 0)
        );
        final newMainQuantity = totalQuantity - newDistributedQuantity;
        _remaining_quantity = newMainQuantity.clamp(0, totalQuantity);
      } else {
        // การกระจายปกติ
        _remaining_quantity = mainLocationQuantity.clamp(0, totalQuantity);
      }
      
      // ตรวจสอบว่าพื้นที่หลักต้องมีอย่างน้อย 1 ชิ้น (เมื่อมี multiple locations)
      if (_use_multiple_locations && _item_locations.isNotEmpty) {
        final finalMainQuantity = totalQuantity - _item_locations.fold<int>(
          0, 
          (sum, location) => sum + (location['quantity'] as int? ?? 0)
        );
        
        if (finalMainQuantity < 1) {
          // ย้ายจำนวน 1 ชิ้นจาก location สุดท้ายกลับไปยังพื้นที่หลัก
          if (_item_locations.isNotEmpty) {
            final lastLocation = _item_locations.last;
            final lastQty = lastLocation['quantity'] as int;
            
            if (lastQty > 1) {
              lastLocation['quantity'] = lastQty - 1;
            } else {
              _item_locations.removeLast();
            }
            
            // คำนวณ remaining quantity ใหม่
            final adjustedDistributed = _item_locations.fold<int>(
              0, 
              (sum, location) => sum + (location['quantity'] as int? ?? 0)
            );
            _remaining_quantity = (totalQuantity - adjustedDistributed).clamp(0, totalQuantity);
          }
        }
      }
    });
  }



  void _add_storage_location() {
    if (_remaining_quantity <= 0) {
      _show_error_message('ไม่มีจำนวนสิ่งของเหลือที่จะกระจาย');
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
      if (!alreadyUsed && areaName != _selected_storage) { // ไม่ซ้ำกับพื้นที่หลัก
        defaultArea = areaName;
        defaultAreaId = loc['area_id'];
        break;
      }
    }
    
    // If no available area found, use the first valid area
    if (defaultArea.isEmpty && availableLocations.isNotEmpty) {
      for (var loc in availableLocations) {
        if (loc['area_name'] != _selected_storage) {
          defaultArea = loc['area_name'];
          defaultAreaId = loc['area_id'];
          break;
        }
      }
    }
    
    if (defaultArea.isEmpty) {
      _show_error_message('ไม่มีพื้นที่จัดเก็บอื่นที่สามารถใช้ได้');
      return;
    }
    
    setState(() {
      _item_locations.add({
        'area_id': defaultAreaId,
        'area_name': defaultArea,
        'quantity': 1, // เริ่มต้นด้วย 1 ชิ้น
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
    if (index < 0 || index >= _item_locations.length) return;
    
    final totalQuantity = int.tryParse(_quantity_controller.text) ?? 0;
    final currentDistributed = _item_locations.fold<int>(
      0, 
      (sum, location) => sum + (location['quantity'] as int? ?? 0)
    ) - (_item_locations[index]['quantity'] as int); // ลบจำนวนของ index ที่จะแก้ไข
    
    // ตรวจสอบว่าจำนวนใหม่ไม่เกินจำนวนที่เหลือ
    final maxAllowed = totalQuantity - currentDistributed - 1; // เก็บ 1 ชิ้นไว้ในพื้นที่หลัก
    final validQuantity = quantity.clamp(1, maxAllowed > 0 ? maxAllowed : 1);
    
    setState(() {
      _item_locations[index]['quantity'] = validQuantity;
      _update_remaining_quantity();
    });
  }

  void _update_location_area(int index, String areaName, int? areaId) {
    setState(() {
      _item_locations[index]['area_name'] = areaName;
      _item_locations[index]['area_id'] = areaId;
    });
  }

  // ============ Storage Groups Management Functions ============
  
  // Toggle individual storage management
  void _toggle_individual_storage(bool value) {
    setState(() {
      _allow_separate_storage = value;
      
      if (value) {
        // เปิดใช้งาน - ให้ผู้ใช้เลือกพื้นที่เอง
        final totalQuantity = int.tryParse(_quantity_controller.text) ?? 1;
        
        if (_storage_groups.isEmpty) {
          // สร้างกลุ่มเริ่มต้น โดยไม่ตั้งค่าพื้นที่ล่วงหน้า
          _storage_groups.add({
            'area_id': null,
            'area_name': null, // ให้ผู้ใช้เลือกเอง
            'quantity': totalQuantity,
          });
        }
      } else {
        // ปิดใช้งาน - ใช้พื้นที่เดียวสำหรับทั้งหมด
        _storage_groups.clear();
        _item_storage_details.clear();
      }
    });
  }

  // Get storage id from selected storage name
  int? _get_selected_storage_id() {
    for (var location in _storage_locations) {
      if (location['area_name'] == _selected_storage) {
        return location['area_id'];
      }
    }
    return null;
  }

  // Add new storage group
  void _add_storage_group() {
    final totalQuantity = int.tryParse(_quantity_controller.text) ?? 0;
    final usedQuantity = _get_total_grouped_storage_quantity();
    
    if (usedQuantity >= totalQuantity) {
      _show_error_message('ได้จัดสรรสิ่งของครบตามจำนวนแล้ว');
      return;
    }
    
    // Clear preview cache when adding storage group
    _clear_preview_cache();

    // หาพื้นที่ที่มีให้เลือก (อนุญาตให้ใช้พื้นที่เดียวกันได้)
    final availableAreas = _storage_locations
        .where((loc) => loc['area_name'] != 'เลือกพื้นที่จัดเก็บ' && 
                       loc['area_name'] != 'เพิ่มพื้นที่การเอง')
        .toList();

    if (availableAreas.isEmpty) {
      _show_error_message('ไม่มีพื้นที่จัดเก็บให้เลือก');
      return;
    }

    // ให้ผู้ใช้เลือกพื้นที่เอง โดยไม่ตั้งค่าเริ่มต้น
    final remainingQuantity = totalQuantity - usedQuantity;
    
    setState(() {
      _storage_groups.add({
        'area_id': null,
        'area_name': null, // ไม่ตั้งค่าเริ่มต้น ให้ผู้ใช้เลือกเอง
        'quantity': remainingQuantity > 0 ? 1 : 0,
      });
    });
  }

  // Remove storage group
  void _remove_storage_group(int index) {
    if (index < 0 || index >= _storage_groups.length) return;
    
    // ป้องกันไม่ให้ลบกลุ่มสุดท้าย
    if (_storage_groups.length <= 1) {
      _show_error_message('ต้องมีพื้นที่จัดเก็บอย่างน้อย 1 แห่ง');
      return;
    }

    setState(() {
      // Clear preview cache when removing storage group
      _clear_preview_cache();
      final removedGroup = _storage_groups.removeAt(index);
      final removedQuantity = removedGroup['quantity'] as int;
      
      // เพิ่มจำนวนที่ลบให้กับกลุ่มแรก
      if (_storage_groups.isNotEmpty && removedQuantity > 0) {
        _storage_groups[0]['quantity'] = (_storage_groups[0]['quantity'] as int) + removedQuantity;
      }
    });
  }

  // Update storage group quantity
  void _update_storage_group_quantity(int index, int newQuantity) {
    if (index < 0 || index >= _storage_groups.length) return;
    
    // Clear preview cache when updating quantity
    _clear_preview_cache();

    final totalQuantity = int.tryParse(_quantity_controller.text) ?? 0;
    final otherGroupsTotal = _storage_groups
        .asMap()
        .entries
        .where((entry) => entry.key != index)
        .fold<int>(0, (sum, entry) => sum + (entry.value['quantity'] as int));

    // ตรวจสอบว่าจำนวนใหม่ไม่เกินจำนวนทั้งหมด
    final maxAllowed = totalQuantity - otherGroupsTotal;
    final validQuantity = newQuantity.clamp(0, maxAllowed);

    setState(() {
      _storage_groups[index]['quantity'] = validQuantity;
    });
  }

  // Update storage group area
  void _update_storage_group_area(int index, String areaName, int? areaId) {
    if (index < 0 || index >= _storage_groups.length) return;
    
    // Clear preview cache when updating area
    _clear_preview_cache();

    setState(() {
      _storage_groups[index]['area_name'] = areaName;
      _storage_groups[index]['area_id'] = areaId;
    });
  }

  // Get total quantity in storage groups
  int _get_total_grouped_storage_quantity() {
    return _storage_groups.fold<int>(0, (sum, group) => sum + (group['quantity'] as int));
  }



  // Generate storage groups data from current preview state
  List<Map<String, dynamic>> _generate_storage_groups_from_preview() {
    final previewItems = _generate_storage_preview();
    Map<String, Map<String, dynamic>> groupedByArea = {};
    
    for (var item in previewItems) {
      String areaName = item['area_name'];
      int? areaId = item['area_id'];
      
      if (!groupedByArea.containsKey(areaName)) {
        groupedByArea[areaName] = {
          'area_id': areaId,
          'area_name': areaName,
          'quantity': 0,
          'details': []
        };
      }
      
      groupedByArea[areaName]!['quantity'] = (groupedByArea[areaName]!['quantity'] as int) + 1;
      groupedByArea[areaName]!['details'].add({
        'expire_date': (item['expire_date'] as DateTime).toIso8601String().split('T')[0],
        'barcode': _barcode_controller.text,
        'item_img': null,
        'quantity': 1,
        'notification_days': _notification_days_controller.text,
        'status': 'active'
      });
    }
    
    return groupedByArea.values.toList();
  }

  // Clear cached preview items when data changes
  void _clear_preview_cache() {
    _cached_preview_items = null;
  }

  // Generate preview of items distribution with expire dates
  List<Map<String, dynamic>> _generate_storage_preview() {
    // Return cached version if available and no manual changes
    if (_cached_preview_items != null) {
      return _cached_preview_items!;
    }
    
    List<Map<String, dynamic>> itemList = [];
    
    if (_allow_separate_storage && _storage_groups.isNotEmpty) {
      // ระบบ Storage Groups
      if (_allow_separate_expire_dates && _expire_date_groups.isNotEmpty) {
        // ใช้ระบบกลุ่มวันหมดอายุ - กระจายตามลำดับที่ตั้งไว้
        int globalItemIndex = 0; // ดัชนีสิ่งของทั้งหมด
        
        for (var group in _storage_groups) {
          final areaName = group['area_name']?.toString() ?? 'ไม่ระบุ';
          final areaId = group['area_id'];
          final quantity = group['quantity'] as int? ?? 0;
          
          // เพิ่มสิ่งของในกลุ่มพื้นที่นี้
          for (int i = 0; i < quantity; i++) {
            // หาว่าสิ่งของชิ้นนี้ควรได้วันหมดอายุจากกลุ่มไหน
            int currentExpireGroup = 0;
            int itemsInPreviousGroups = 0;
            
            for (int expIndex = 0; expIndex < _expire_date_groups.length; expIndex++) {
              final groupQuantity = _expire_date_groups[expIndex]['quantity'] as int;
              
              if (globalItemIndex < itemsInPreviousGroups + groupQuantity) {
                currentExpireGroup = expIndex;
                break;
              }
              itemsInPreviousGroups += groupQuantity;
            }
            
            // ป้องกันการเกินขอบเขต
            if (currentExpireGroup >= _expire_date_groups.length) {
              currentExpireGroup = _expire_date_groups.length - 1;
            }
            
            final expireGroup = _expire_date_groups[currentExpireGroup];
            final expireDate = expireGroup['expire_date'] as DateTime;
            final unit = expireGroup['unit'] as String? ?? _selected_unit;
            
            itemList.add({
              'index': itemList.length + 1,
              'area_name': areaName,
              'area_id': areaId,
              'expire_date': expireDate,
              'unit': unit,
              'from_group': true,
            });
            
            globalItemIndex++;
          }
        }
      } else {
        // ใช้วันหมดอายุเดียวกันทั้งหมด
        for (var group in _storage_groups) {
          final areaName = group['area_name']?.toString() ?? 'ไม่ระบุ';
          final areaId = group['area_id'];
          final quantity = group['quantity'] as int? ?? 0;
          
          for (int i = 0; i < quantity; i++) {
            itemList.add({
              'index': itemList.length + 1,
              'area_name': areaName,
              'area_id': areaId,
              'expire_date': _selected_date,
              'unit': _selected_unit,
              'from_group': true,
            });
          }
        }
      }
    } else if (_use_multiple_locations && _item_locations.isNotEmpty) {
      // ระบบ Multiple Locations เดิม
      // เพิ่มพื้นที่หลักก่อน
      final totalQuantity = int.tryParse(_quantity_controller.text) ?? 0;
      final distributedQuantity = _item_locations.fold<int>(0, (sum, loc) => sum + (loc['quantity'] as int? ?? 0));
      final mainQuantity = totalQuantity - distributedQuantity;
      
      for (int i = 0; i < mainQuantity; i++) {
        itemList.add({
          'index': itemList.length + 1,
          'area_name': _selected_storage,
          'area_id': _get_selected_storage_id(),
          'expire_date': _selected_date,
          'unit': _selected_unit,
          'from_group': false,
          'is_main': true,
        });
      }
      
      // เพิ่มพื้นที่เพิ่มเติม
      for (var location in _item_locations) {
        final quantity = location['quantity'] as int? ?? 0;
        for (int i = 0; i < quantity; i++) {
          itemList.add({
            'index': itemList.length + 1,
            'area_name': location['area_name'],
            'area_id': location['area_id'],
            'expire_date': _selected_date,
            'unit': _selected_unit,
            'from_group': false,
            'is_main': false,
          });
        }
      }
    } else {
      // ระบบเดียวปกติ
      final totalQuantity = int.tryParse(_quantity_controller.text) ?? 1;
      
      if (_allow_separate_expire_dates && _expire_date_groups.isNotEmpty) {
        // ใช้ระบบกลุ่มวันหมดอายุ
        for (var expireGroup in _expire_date_groups) {
          final expireGroupQuantity = expireGroup['quantity'] as int;
          final expireDate = expireGroup['expire_date'] as DateTime;
          final unit = expireGroup['unit'] as String? ?? _selected_unit;
          
          for (int i = 0; i < expireGroupQuantity; i++) {
            itemList.add({
              'index': itemList.length + 1,
              'area_name': _selected_storage,
              'area_id': _get_selected_storage_id(),
              'expire_date': expireDate,
              'unit': unit,
              'from_group': false,
            });
          }
        }
      } else {
        // ใช้วันหมดอายุเดียวกัน
        for (int i = 0; i < totalQuantity; i++) {
          itemList.add({
            'index': itemList.length + 1,
            'area_name': _selected_storage,
            'area_id': _get_selected_storage_id(),
            'expire_date': _selected_date,
            'unit': _selected_unit,
            'from_group': false,
          });
        }
      }
    }
    
    // Cache the generated items for Option B approach
    _cached_preview_items = List<Map<String, dynamic>>.from(
      itemList.map((item) => Map<String, dynamic>.from(item))
    );
    
    return _cached_preview_items!;
  }

  Future<void> _show_main_storage_selection_dialog() async {
    final availableLocations = _storage_locations
        .where((loc) => loc['area_name'] != 'เลือกพื้นที่จัดเก็บ' && 
                       loc['area_name'] != 'เพิ่มพื้นที่การเอง')
        .toList();

    String? selectedArea = _selected_storage; // ตั้งค่าเริ่มต้น

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('เลือกพื้นที่หลัก'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('เลือกพื้นที่จัดเก็บหลักสำหรับสิ่งของของคุณ'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: availableLocations.any((loc) => loc['area_name'] == selectedArea) 
                        ? selectedArea 
                        : null,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: availableLocations.map((loc) {
                      return DropdownMenuItem<String>(
                        value: loc['area_name'],
                        child: Text(loc['area_name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedArea = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedArea),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('เลือก'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result != _selected_storage) {
      setState(() {
        _selected_storage = result;
      });
    }
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
          _show_error_message(response_data['message'] ?? 'เกิดข้อผิดพลาดในการเพิ่มพื้นที่จัดเก็บ');
        }
      } else {
        // Parse error response to get Thai message
        try {
          final error_data = json.decode(utf8.decode(response.bodyBytes));
          if (error_data['message'] != null) {
            _show_error_message(error_data['message']);
          } else {
            _show_error_message('เกิดข้อผิดพลาดในการเพิ่มพื้นที่จัดเก็บ');
          }
        } catch (e) {
          _show_error_message('เกิดข้อผิดพลาดในการเพิ่มพื้นที่จัดเก็บ');
        }
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
      barrierDismissible: false,
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

  // NEW: Function to show confirmation dialog for deleting area with disposed/expired items
  Future<bool> _show_delete_confirmation_dialog(String area_name) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('คำเตือน'),
          content: Text(
            'คุณต้องการลบพื้นที่จัดเก็บ "$area_name" ใช่หรือไม่?\n\n'
            'เนื่องจากคุณเคยบันทึกสิ่งของที่หมดอายุ (expired) หรือทิ้งแล้ว (disposed) ในพื้นที่นี้'
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ลบ', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false;
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
      // ตรวจสอบสถานะของ items ในพื้นที่ก่อนลบ
      final requestBody = json.encode({
        'area_name': area_name,
        'user_id': _current_user_id.toString(),
      });
      
      final checkResponse = await http.post(
        Uri.parse('$_api_base_url/check_area_status.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      if (checkResponse.statusCode == 200) {
        final responseBody = utf8.decode(checkResponse.bodyBytes);
        
        try {
          final checkData = json.decode(responseBody);
          
          if (checkData['status'] == 'error') {
            setState(() {
              _is_loading = false;
            });
            _show_error_message(checkData['message'] ?? 'เกิดข้อผิดพลาดในการตรวจสอบสถานะพื้นที่');
            return;
          }
          
          if (checkData['has_active_items'] == true) {
            setState(() {
              _is_loading = false;
            });
            _show_error_message('ไม่สามารถลบพื้นที่นี้ได้ เนื่องจากยังมีสิ่งของที่ใช้งานอยู่ (active) ในพื้นที่นี้');
            return;
          }
          
          if (checkData['has_disposed_or_expired_items'] == true) {
            setState(() {
              _is_loading = false;
            });
            
            // แสดง dialog เตือนผู้ใช้
            bool shouldDelete = await _show_delete_confirmation_dialog(area_name);
            if (!shouldDelete) {
              return;
            }
            
            setState(() {
              _is_loading = true;
            });
          }
        } catch (e) {
          setState(() {
            _is_loading = false;
          });
          _show_error_message('เกิดข้อผิดพลาดในการประมวลผลข้อมูล: $e\nResponse: $responseBody');
          return;
        }
      } else {
        setState(() {
          _is_loading = false;
        });
        _show_error_message('เกิดข้อผิดพลาดในการตรวจสอบสถานะพื้นที่: ${checkResponse.statusCode}');
        return;
      }

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

      final response_body = utf8.decode(response.bodyBytes);
      
      if (response.statusCode == 200) {
        final response_data = json.decode(response_body);
        if (response_data['status'] == 'success') {
          _show_success_message(response_data['message'] ?? 'ลบพื้นที่จัดเก็บสำเร็จแล้ว!');
          await _fetch_storage_locations();
          if (_selected_storage == area_name) {
            setState(() {
              _selected_storage = 'เลือกพื้นที่จัดเก็บ';
            });
          }
        } else {
          _show_error_message(response_data['message'] ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ');
        }
      } else {
        try {
          final error_data = json.decode(response_body);
          _show_error_message(error_data['message'] ?? 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์');
        } catch (e) {
          _show_error_message('Server error: ${response.statusCode}');
        }
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
        _show_error_message('กรุณาเลือกประเภทสิ่งของ');
        return false;
      }
      
      // ตรวจสอบวันหมดอายุแต่ละชิ้น (ถ้ามีมากกว่า 1 ชิ้น)
      if (_use_multiple_expire_dates && _item_expire_details.isNotEmpty) {
        for (int i = 0; i < _item_expire_details.length; i++) {
          final detail = _item_expire_details[i];
          if (detail['expire_date'] == null) {
            _show_error_message('กรุณากรอกวันหมดอายุของชิ้นที่ ${i + 1}');
            return false;
          }
        }
      }

      // ตรวจสอบกลุ่มวันหมดอายุ (ในโหมดเพิ่มใหม่)
      if (!widget.is_existing_item && _allow_separate_expire_dates && _expire_date_groups.isNotEmpty) {
        final totalQuantity = int.tryParse(_quantity_controller.text) ?? 0;
        final totalGrouped = _get_total_grouped_quantity();
        
        if (totalGrouped != totalQuantity) {
          _show_error_message('จำนวนในกลุ่มวันหมดอายุไม่ตรงกับจำนวนทั้งหมด (รวม: $totalGrouped/$totalQuantity ชิ้น)');
          return false;
        }

        for (int i = 0; i < _expire_date_groups.length; i++) {
          final group = _expire_date_groups[i];
          if (group['expire_date'] == null) {
            _show_error_message('กรุณากรอกวันหมดอายุของกลุ่มที่ ${i + 1}');
            return false;
          }
          if ((group['quantity'] as int) <= 0) {
            _show_error_message('จำนวนในกลุ่มที่ ${i + 1} ต้องมากกว่า 0');
            return false;
          }
        }
      }

      // ตรวจสอบกลุ่มพื้นที่เก็บ (ในโหมดเพิ่มใหม่)
      if (!widget.is_existing_item && _allow_separate_storage && _storage_groups.isNotEmpty) {
        final totalQuantity = int.tryParse(_quantity_controller.text) ?? 0;
        final totalStorageGrouped = _get_total_grouped_storage_quantity();
        
        if (totalStorageGrouped != totalQuantity) {
          _show_error_message('จำนวนในกลุ่มพื้นที่เก็บไม่ตรงกับจำนวนทั้งหมด (รวม: $totalStorageGrouped/$totalQuantity ชิ้น)');
          return false;
        }

        for (int i = 0; i < _storage_groups.length; i++) {
          final group = _storage_groups[i];
          if (group['area_name'] == null || 
              group['area_name'].toString().isEmpty ||
              group['area_name'] == 'เลือกพื้นที่จัดเก็บ') {
            _show_error_message('กรุณาเลือกพื้นที่จัดเก็บของกลุ่มที่ ${i + 1}');
            return false;
          }
          if ((group['quantity'] as int) <= 0) {
            _show_error_message('จำนวนในกลุ่มที่ ${i + 1} ต้องมากกว่า 0');
            return false;
          }
        }
      }
      
      // ตรวจสอบการกระจายพื้นที่เฉพาะในโหมดเพิ่มใหม่เท่านั้น
      if (!widget.is_existing_item && _use_multiple_locations && _enable_multiple_locations_option && !_allow_separate_storage) {
        // ตรวจสอบว่าเลือกพื้นที่หลักแล้วหรือไม่
        if (_selected_storage == 'เลือกพื้นที่จัดเก็บ') {
          _show_error_message('กรุณาเลือกพื้นที่จัดเก็บหลักก่อน');
          return false;
        }
        
        // ถ้ามี remaining quantity > 0 แต่ไม่มี additional locations
        if (_remaining_quantity > 0 && _item_locations.isEmpty) {
          _show_error_message('กรุณาเพิ่มพื้นที่เพิ่มเติมหรือลดจำนวนสิ่งของ (เหลือ $_remaining_quantity ชิ้น)');
          return false;
        }
        
        if (_remaining_quantity > 0 && _item_locations.isNotEmpty) {
          _show_error_message('กรุณากระจายสิ่งของให้ครบทุกชิ้น (เหลือ $_remaining_quantity ชิ้น)');
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
        
      } else if (!_allow_separate_storage) {
        // Validate single location (ไม่ใช้ระบบกลุ่มหรือ multiple locations) - ใช้ทั้งโหมดเพิ่มและแก้ไข
        if (_selected_storage == 'เลือกพื้นที่จัดเก็บ') {
          _show_error_message('กรุณาเลือกพื้นที่จัดเก็บ');
          return false;
        }
      }
      
      // สำหรับโหมดแก้ไข: ตรวจสอบเฉพาะพื้นฐาน ไม่ต้องตรวจสอบการกระจาย
      if (widget.is_existing_item) {
        // ตรวจสอบพื้นที่เก็บพื้นฐาน
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

  // เพิ่มฟังก์ชันสำหรับดึง default image ตามประเภทสิ่งของ
  Future<String> _get_default_image_for_category(String category) async {
    try {
      final response = await http.get(
        Uri.parse('$_api_base_url/get_default_image.php?category=${Uri.encodeComponent(category)}')
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          return data['default_image'] ?? 'default.png';
        }
      }
    } catch (e) {
      // Handle error silently
    }
    return 'default.png'; // fallback
  }

  Future<void> _save_item() async {
    if (!_validate_form_data()) {
      return;
    }

    setState(() {
      _is_loading = true;
    });
    try {
      // ปรับให้รองรับโหมดแก้ไข (edit) และเพิ่ม (add)
      final bool isEditMode = widget.is_existing_item && widget.item_data != null && widget.item_data!['item_id'] != null;
      final String apiUrl = isEditMode
          ? '$_api_base_url/edit_item.php'
          : '$_api_base_url/add_item.php';

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(apiUrl),
      );

      // ถ้าเป็นโหมดแก้ไข ให้ส่ง item_id เดิมไปด้วย
      if (isEditMode) {
        request.fields['item_id'] = widget.item_data!['item_id'].toString();
        
        // ส่งข้อมูล item_expire_details สำหรับโหมดแก้ไข
        request.fields['item_expire_details'] = json.encode(_item_expire_details.map((detail) => {
          'detail_id': detail['id'], // detail_id จากฐานข้อมูล
          'area_id': detail['area_id'],
          'area_name': detail['area_name'],
          'expire_date': detail['expire_date'] is DateTime 
            ? (detail['expire_date'] as DateTime).toIso8601String().split('T')[0]
            : detail['expire_date'].toString(),
          'quantity': detail['quantity'] ?? 1,
        }).toList());
        
      }

      request.fields['name'] = _name_controller.text;
      // ในโหมดแก้ไข ไม่ส่ง quantity เพราะไม่ให้แก้ไข
      if (!isEditMode) {
        request.fields['quantity'] = _quantity_controller.text;
      }
      request.fields['selected_date'] = _selected_date.toIso8601String().split('T')[0];
      request.fields['notification_days'] = _notification_days_controller.text;
      request.fields['barcode'] = _barcode_controller.text;
      request.fields['user_id'] = _current_user_id.toString();
      request.fields['category'] = _selected_category;
      request.fields['date_type'] = _selected_unit;

      // Handle storage groups (new system) - individual item storage management
      if (_allow_separate_storage && _storage_groups.isNotEmpty && !widget.is_existing_item) {
        request.fields['use_storage_groups'] = 'true';
        
        // ใช้ข้อมูลจาก preview ที่อัปเดตแล้วเพื่อความถูกต้อง
        final storageGroupsWithDetails = _generate_storage_groups_from_preview();
        
        request.fields['storage_groups'] = json.encode(storageGroupsWithDetails);
        
        // ใช้กลุ่มแรกเป็นพื้นที่หลักสำหรับ backward compatibility
        if (_storage_groups.isNotEmpty) {
          request.fields['storage_location'] = _storage_groups[0]['area_name'];
          if (_storage_groups[0]['area_id'] != null) {
            request.fields['storage_id'] = _storage_groups[0]['area_id'].toString();
          }
        }
      } 
      // Handle multiple locations or single location (old system)
      else if (_use_multiple_locations && _enable_multiple_locations_option && _item_locations.isNotEmpty) {
        // Send multiple locations data with expire details
        request.fields['use_multiple_locations'] = 'true';
        
        
        // เพิ่มข้อมูลวันหมดอายุแต่ละชิ้นในแต่ละพื้นที่
        List<Map<String, dynamic>> locationsWithDetails = [];
        
        // เพิ่มพื้นที่หลักก่อน (main location)
        int? mainAreaId;
        for (var loc in _storage_locations) {
          if (loc['area_name'] == _selected_storage) {
            mainAreaId = loc['area_id'] is int ? loc['area_id'] : int.tryParse(loc['area_id'].toString());
            break;
          }
        }
        
        // คำนวณจำนวนในพื้นที่หลัก
        final totalQuantity = int.tryParse(_quantity_controller.text) ?? 0;
        final distributedQuantity = _item_locations.fold<int>(
          0, 
          (sum, location) => sum + (location['quantity'] as int? ?? 0)
        );
        final mainLocationQuantity = totalQuantity - distributedQuantity;
        
        
        if (mainLocationQuantity > 0 && mainAreaId != null) {
          Map<String, dynamic> mainLocationData = {
            'area_id': mainAreaId,
            'area_name': _selected_storage,
            'quantity': mainLocationQuantity,
            'details': []
          };
          
          // เพิ่มข้อมูลวันหมดอายุสำหรับพื้นที่หลัก
          if (_allow_separate_expire_dates && _expire_date_groups.isNotEmpty && !widget.is_existing_item) {
            // ใช้ระบบกลุ่มวันหมดอายุใหม่
            int itemsAdded = 0;
            for (var group in _expire_date_groups) {
              final groupQuantity = group['quantity'] as int;
              final groupDate = group['expire_date'] as DateTime;
              
              for (int i = 0; i < groupQuantity && itemsAdded < mainLocationQuantity; i++) {
                mainLocationData['details'].add({
                  'expire_date': groupDate.toIso8601String().split('T')[0],
                  'barcode': _barcode_controller.text,
                  'item_img': null,
                  'quantity': 1,
                  'notification_days': _notification_days_controller.text,
                  'status': 'active'
                });
                itemsAdded++;
              }
              
              if (itemsAdded >= mainLocationQuantity) break;
            }
          } else if (_item_expire_details.isNotEmpty) {
            // โหมดแก้ไขหรือระบบเดิม
            for (int i = 0; i < mainLocationQuantity && i < _item_expire_details.length; i++) {
              final detail = _item_expire_details[i];
              mainLocationData['details'].add({
                'expire_date': (detail['expire_date'] as DateTime).toIso8601String().split('T')[0],
                'barcode': detail['barcode'] ?? _barcode_controller.text,
                'item_img': detail['item_img'],
                'quantity': 1,
                'notification_days': _notification_days_controller.text,
                'status': 'active'
              });
            }
          } else {
            // กรณีไม่มีการแยกวันหมดอายุ ใช้วันเดียวกันทั้งหมด
            for (int i = 0; i < mainLocationQuantity; i++) {
              mainLocationData['details'].add({
                'expire_date': _selected_date.toIso8601String().split('T')[0],
                'barcode': _barcode_controller.text,
                'item_img': null,
                'quantity': 1,
                'notification_days': _notification_days_controller.text,
                'status': 'active'
              });
            }
          }
          
          locationsWithDetails.add(mainLocationData);
        }
        
        // เพิ่มพื้นที่เพิ่มเติม
        for (var location in _item_locations) {
          Map<String, dynamic> locationData = {
            'area_id': location['area_id'],
            'area_name': location['area_name'],
            'quantity': location['quantity'],
            'details': []
          };
          
          // กระจายวันหมดอายุตามจำนวนในแต่ละพื้นที่
          int locationQuantity = location['quantity'] ?? 0;
          
          if (_allow_separate_expire_dates && _expire_date_groups.isNotEmpty && !widget.is_existing_item) {
            // ใช้ระบบกลุ่มวันหมดอายุใหม่
            // คำนวณจำนวนที่ใช้ไปแล้วในพื้นที่ก่อนหน้า
            int usedItems = 0;
            for (int j = 0; j < locationsWithDetails.length; j++) {
              usedItems += (locationsWithDetails[j]['details'] as List).length;
            }
            
            int itemsAdded = 0;
            for (var group in _expire_date_groups) {
              final groupQuantity = group['quantity'] as int;
              final groupDate = group['expire_date'] as DateTime;
              
              // ข้ามไปถึงกลุ่มที่ยังไม่ได้ใช้
              int groupUsed = 0;
              int currentTotal = 0;
              for (var prevGroup in _expire_date_groups) {
                if (prevGroup == group) break;
                currentTotal += prevGroup['quantity'] as int;
              }
              
              if (currentTotal < usedItems) {
                groupUsed = usedItems - currentTotal;
                if (groupUsed >= groupQuantity) continue;
              }
              
              for (int i = groupUsed; i < groupQuantity && itemsAdded < locationQuantity; i++) {
                locationData['details'].add({
                  'expire_date': groupDate.toIso8601String().split('T')[0],
                  'barcode': _barcode_controller.text,
                  'item_img': null,
                  'quantity': 1,
                  'notification_days': _notification_days_controller.text,
                  'status': 'active'
                });
                itemsAdded++;
              }
              
              if (itemsAdded >= locationQuantity) break;
            }
          } else if (_item_expire_details.isNotEmpty) {
            // โหมดแก้ไขหรือระบบเดิม
            int currentDetailIndex = 0;
            
            // หาจำนวนสิ่งของที่ถูกใช้ไปแล้วในพื้นที่ก่อนหน้า
            for (int j = 0; j < locationsWithDetails.length; j++) {
              currentDetailIndex += (locationsWithDetails[j]['details'] as List).length;
            }
            
            for (int i = 0; i < locationQuantity && currentDetailIndex < _item_expire_details.length; i++) {
              final detail = _item_expire_details[currentDetailIndex];
              locationData['details'].add({
                'expire_date': (detail['expire_date'] as DateTime).toIso8601String().split('T')[0],
                'barcode': detail['barcode'] ?? _barcode_controller.text,
                'item_img': detail['item_img'],
                'quantity': 1,
                'notification_days': _notification_days_controller.text,
                'status': 'active'
              });
              currentDetailIndex++;
            }
          } else {
            // กรณีไม่มีการแยกวันหมดอายุ ใช้วันเดียวกันทั้งหมด
            for (int i = 0; i < locationQuantity; i++) {
              locationData['details'].add({
                'expire_date': _selected_date.toIso8601String().split('T')[0],
                'barcode': _barcode_controller.text,
                'item_img': null,
                'quantity': 1,
                'notification_days': _notification_days_controller.text,
                'status': 'active'
              });
            }
          }
          
          locationsWithDetails.add(locationData);
        }
        
        request.fields['item_locations'] = json.encode(locationsWithDetails);

        // For backward compatibility, use the first location as primary
        request.fields['storage_location'] = _item_locations[0]['area_name'];
        if (_item_locations[0]['area_id'] != null) {
          request.fields['storage_id'] = _item_locations[0]['area_id'].toString();
        }
      } else {
        // Single location (original behavior) with multiple expire dates
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
        
        // ส่งข้อมูลวันหมดอายุแต่ละชิ้นสำหรับ single location
        if (_use_multiple_expire_dates && _allow_separate_expire_dates && !widget.is_existing_item) {
          // ใช้ระบบกลุ่มวันหมดอายุใหม่
          if (_expire_date_groups.isNotEmpty) {
            List<Map<String, dynamic>> expireDetails = [];
            
            // แปลงข้อมูลกลุ่มเป็นรายละเอียดแต่ละชิ้น
            for (var group in _expire_date_groups) {
              final groupQuantity = group['quantity'] as int;
              final groupDate = group['expire_date'] as DateTime;
              
              for (int i = 0; i < groupQuantity; i++) {
                expireDetails.add({
                  'expire_date': groupDate.toIso8601String().split('T')[0],
                  'barcode': _barcode_controller.text,
                  'item_img': null,
                  'quantity': 1,
                  'notification_days': _notification_days_controller.text,
                  'status': 'active'
                });
              }
            }
            
            request.fields['item_locations'] = json.encode([{
              'area_id': areaId,
              'area_name': _selected_storage,
              'quantity': expireDetails.length,
              'details': expireDetails
            }]);
            request.fields['use_multiple_locations'] = 'true';
          }
        } else if (_use_multiple_expire_dates && _item_expire_details.isNotEmpty && _allow_separate_expire_dates) {
          // โหมดแก้ไข - ใช้ข้อมูลเดิม
          List<Map<String, dynamic>> expireDetails = [];
          for (var detail in _item_expire_details) {
            expireDetails.add({
              'expire_date': (detail['expire_date'] as DateTime).toIso8601String().split('T')[0],
              'barcode': detail['barcode'] ?? _barcode_controller.text,
              'item_img': detail['item_img'],
              'quantity': 1,
              'notification_days': _notification_days_controller.text,
              'status': 'active'
            });
          }
          request.fields['item_locations'] = json.encode([{
            'area_id': areaId,
            'area_name': _selected_storage,
            'quantity': _item_expire_details.length,
            'details': expireDetails
          }]);
          request.fields['use_multiple_locations'] = 'true';
        } else if (!_allow_separate_expire_dates && (int.tryParse(_quantity_controller.text) ?? 0) > 1) {
          // กรณีผู้ใช้เลือกใช้วันหมดอายุเดียวกันทั้งหมด
          List<Map<String, dynamic>> expireDetails = [];
          final quantity = int.tryParse(_quantity_controller.text) ?? 0;
          for (int i = 0; i < quantity; i++) {
            expireDetails.add({
              'expire_date': _selected_date.toIso8601String().split('T')[0],
              'barcode': _barcode_controller.text,
              'item_img': null,
              'quantity': 1,
              'notification_days': _notification_days_controller.text,
              'status': 'active'
            });
          }
          request.fields['item_locations'] = json.encode([{
            'area_id': areaId,
            'area_name': _selected_storage,
            'quantity': quantity,
            'details': expireDetails
          }]);
          request.fields['use_multiple_locations'] = 'true';
        } else {
          // กรณีสิ่งของ 1 ชิ้น หรือไม่ได้เปิดใช้ multiple expire dates
          // ไม่ส่ง item_locations, ใช้ข้อมูลพื้นฐานใน items table เท่านั้น
          request.fields['use_multiple_locations'] = 'false';
        }
      }

      // Log all fields being sent
      request.fields.forEach((key, value) {
      });

      // อัปโหลดรูปภาพ (key ต้องเป็น 'item_img' เพื่อรองรับแก้ไข)
      if (_picked_image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('item_img', _picked_image!.path),
        );
      } else if (isEditMode) {
        // ถ้าเป็นโหมดแก้ไขและไม่ได้เลือกรูปใหม่ ให้รักษารูปเดิมไว้
        request.fields['keep_existing_image'] = 'true';
      } else {
        // ใช้ default image สำหรับประเภทที่เลือก (สำหรับรายการใหม่เท่านั้น)
        String defaultImage = await _get_default_image_for_category(_selected_category);
        request.fields['default_image'] = defaultImage;
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        final response_body = await response.stream.bytesToString();
        final response_data = json.decode(response_body);

        if (response_data['status'] == 'success') {
          _show_success_message(isEditMode ? 'แก้ไขข้อมูลสิ่งของสำเร็จแล้ว!' : 'บันทึกข้อมูลสิ่งของสำเร็จแล้ว!');
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
    } catch (e) {
      _show_error_message('เกิดข้อผิดพลาด: $e');
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
                          _build_section_title('สิ่งของ'),
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
                        hint: 'ระบุชื่อสิ่งของ',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกชื่อสิ่งของ';
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
                                Row(
                                  children: [
                                    _build_section_title('จำนวนสิ่งของ'),
                                    if (widget.is_existing_item) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.lock_outline, size: 16, color: Colors.grey[600]),
                                    ],
                                  ],
                                ),
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
                                        onPressed: widget.is_existing_item ? null : () {
                                          int current_quantity = int.tryParse(_quantity_controller.text) ?? 1;
                                          if (current_quantity > 1) {
                                            _quantity_controller.text = (current_quantity - 1).toString();
                                          }
                                        },
                                        icon: Icon(Icons.remove, 
                                          size: 16, 
                                          color: widget.is_existing_item ? Colors.grey[400] : null
                                        ),
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
                                        enabled: !widget.is_existing_item, // ปิดการใช้งานในโหมดแก้ไข
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey[300]!),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                          filled: widget.is_existing_item,
                                          fillColor: widget.is_existing_item ? Colors.grey[100] : null,
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
                                        onPressed: widget.is_existing_item ? null : () {
                                          int current_quantity = int.tryParse(_quantity_controller.text) ?? 1;
                                          _quantity_controller.text = (current_quantity + 1).toString();
                                        },
                                        icon: Icon(Icons.add, 
                                          size: 16,
                                          color: widget.is_existing_item ? Colors.grey[400] : null
                                        ),
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
                      
                      // แสดงตัวเลือกสำหรับแยกวันหมดอายุเมื่อมีสิ่งของมากกว่า 1 ชิ้น (เฉพาะโหมดเพิ่มใหม่)
                      if (!widget.is_existing_item && _enable_multiple_locations_option) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.event_note, color: Colors.green[600], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'จัดกลุ่มตามวันหมดอายุ',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green[800],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '• เปิด: แยกสิ่งของเป็นกลุ่มตามวันหมดอายุที่ต่างกัน\n• ปิด: กำหนดวันหมดอายุเดียวกันสำหรับทุกชิ้น',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.green[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FlutterSwitch(
                                    width: 70,
                                    height: 32,
                                    value: _allow_separate_expire_dates,
                                    onToggle: _toggle_separate_expire_dates,
                                    activeColor: Colors.green[600]!,
                                    inactiveColor: Colors.red[400]!,
                                    activeText: 'เปิด',
                                    inactiveText: 'ปิด',
                                    activeTextColor: Colors.white,
                                    inactiveTextColor: Colors.white,
                                    toggleColor: Colors.white,
                                    showOnOff: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // แสดงส่วนการตั้งค่าตามที่ผู้ใช้เลือก
                              if (_allow_separate_expire_dates) ...[
                                // ส่วนจัดกลุ่มวันหมดอายุ
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, color: Colors.orange[600], size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'จัดกลุ่มตามวันหมดอายุ',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[800],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'จะสามารถจัดกลุ่มสิ่งของตามวันหมดอายุได้ เช่น 4 ชิ้น หมดอายุ 15/9/2568',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.orange[600],
                                  ),
                                ),
                              ] else ...[
                                // ส่วนวันหมดอายุเดียวกันทั้งหมด
                                Row(
                                  children: [
                                    Icon(Icons.event, color: Colors.blue[600], size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'วันหมดอายุเดียวกันทั้งหมด (${_quantity_controller.text} ชิ้น)',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'สิ่งของทั้งหมดจะมีวันหมดอายุเดียวกัน',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.blue[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // กรณีสิ่งของมากกว่า 1 ชิ้น และเลือกแยกวันหมดอายุ
                      // หรือในโหมดแก้ไขที่มีข้อมูล item_expire_details
                      if ((widget.is_existing_item && _item_expire_details.isNotEmpty) ||
                          (_allow_separate_expire_dates && _use_multiple_expire_dates && !widget.is_existing_item)) ...[

                        // แสดงระบบกลุ่มวันหมดอายุใหม่ (เฉพาะโหมดเพิ่มใหม่)
                        if (!widget.is_existing_item) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'กลุ่มวันหมดอายุ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            Row(
                              children: [
                                Text(
                                  'รวม: ${_get_total_grouped_quantity()}/${_quantity_controller.text} ชิ้น',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _get_total_grouped_quantity() == (int.tryParse(_quantity_controller.text) ?? 0) 
                                        ? Colors.green 
                                        : Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_expire_date_groups.length > 1)
                                  TextButton(
                                    onPressed: _distribute_equally,
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF4A90E2),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'กระจายเท่าๆกัน',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                              ],
                            ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // แสดงสรุปการจัดกลุ่ม
                          if (_expire_date_groups.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'สรุปการจัดกลุ่ม',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ...List.generate(_expire_date_groups.length, (index) {
                                    final group = _expire_date_groups[index];
                                    int startItem = 1;
                                    for (int i = 0; i < index; i++) {
                                      startItem += _expire_date_groups[i]['quantity'] as int;
                                    }
                                    int endItem = startItem + (group['quantity'] as int) - 1;
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '• กลุ่มที่ ${index + 1}: ${group['quantity']} ชิ้น ${(group['quantity'] as int) == 1 ? '(ชิ้นที่ $startItem)' : '(ชิ้นที่ $startItem-$endItem)'} หมดอายุ ${_format_date(group['expire_date'] ?? _selected_date)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),

                          // รายการกลุ่มวันหมดอายุ
                          ...List.generate(_expire_date_groups.length, (index) {
                            final group = _expire_date_groups[index];
                            
                            // คำนวณช่วงชิ้นที่ของกลุ่มนี้
                            int startItem = 1;
                            for (int i = 0; i < index; i++) {
                              startItem += _expire_date_groups[i]['quantity'] as int;
                            }
                            int endItem = startItem + (group['quantity'] as int) - 1;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[50],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'กลุ่มที่ ${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          (group['quantity'] as int) == 1 
                                              ? 'ชิ้นที่ $startItem'
                                              : 'ชิ้นที่ $startItem-$endItem',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.blue[800],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (_expire_date_groups.length > 1)
                                        IconButton(
                                          onPressed: () => _remove_expire_group(index),
                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // จำนวนชิ้น
                                  Row(
                                    children: [
                                      const Text(
                                        'จำนวน:',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: IconButton(
                                          onPressed: () {
                                            final currentQty = group['quantity'] as int;
                                            if (currentQty > 1) {
                                              _update_expire_group_quantity(index, currentQty - 1);
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
                                          '${group['quantity']}',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                                            final currentQty = group['quantity'] as int;
                                            final totalAvailable = (int.tryParse(_quantity_controller.text) ?? 0);
                                            final otherGroupsTotal = _expire_date_groups
                                                .where((g) => g != group)
                                                .fold<int>(0, (sum, g) => sum + (g['quantity'] as int));
                                            
                                            if (currentQty + otherGroupsTotal < totalAvailable) {
                                              _update_expire_group_quantity(index, currentQty + 1);
                                            }
                                          },
                                          icon: const Icon(Icons.add, size: 12),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'ชิ้น',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // วันหมดอายุ
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: _build_dropdown(
                                          value: _units.contains(group['unit']) ? group['unit'] : 'วันหมดอายุ(EXP)',
                                          items: _units,
                                          fontSize: 16,
                                          onChanged: (value) {
                                            _update_expire_group_unit(index, value!);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: GestureDetector(
                                          onTap: () async {
                                            await _show_expire_group_date_picker(index, group['expire_date'] ?? _selected_date);
                                          },
                                          child: Container(
                                            height: 40,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey[300]!),
                                              borderRadius: BorderRadius.circular(8),
                                              color: Colors.white,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _format_date(group['expire_date'] ?? _selected_date),
                                                    style: const TextStyle(fontSize: 16),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),

                          // ปุ่มเพิ่มกลุ่ม
                          if (_get_total_grouped_quantity() < (int.tryParse(_quantity_controller.text) ?? 0))
                            Container(
                              width: double.infinity,
                              height: 40,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: OutlinedButton.icon(
                                onPressed: _add_expire_group,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('เพิ่มกลุ่มวันหมดอายุ'),
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

                        // แสดงรายการวันหมดอายุแต่ละชิ้นในโหมดแก้ไข (เดิม)
                        if (widget.is_existing_item) ...[
                          ...List.generate(_item_expire_details.length, (index) {
                            // ตรวจสอบว่ามีข้อมูลใน _item_expire_details หรือไม่
                            final bool hasDetail = index < _item_expire_details.length;
                            final detail = hasDetail ? _item_expire_details[index] : null;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[50],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ชิ้นที่ ${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _build_dropdown(
                                        value: _units.contains(_selected_unit) ? _selected_unit : 'วันหมดอายุ(EXP)',
                                        items: _units,
                                        fontSize: 16, // เพิ่มขนาดฟอนต์
                                        onChanged: (value) {
                                          setState(() {
                                            _selected_unit = value!;
                                            // อัพเดตกลุ่มวันหมดอายุที่มีอยู่แล้วด้วย (ถ้ามี)
                                            for (int i = 0; i < _expire_date_groups.length; i++) {
                                              _expire_date_groups[i]['unit'] = value;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: GestureDetector(
                                        onTap: () async {
                                          final currentDate = hasDetail && detail != null && detail['expire_date'] != null
                                              ? detail['expire_date']
                                              : _selected_date;
                                          await _show_individual_expire_date_picker(index, currentDate);
                                        },
                                        child: Container(
                                          height: 40,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey[300]!),
                                            borderRadius: BorderRadius.circular(8),
                                            color: Colors.white,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  hasDetail && detail != null && detail['expire_date'] != null
                                                      ? _format_date(detail['expire_date'])
                                                      : _format_date(_selected_date),
                                                  style: const TextStyle(fontSize: 16), // เพิ่มขนาดฟอนต์
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // แสดงและแก้ไขพื้นที่จัดเก็บในโหมดแก้ไข
                                if (widget.is_existing_item && hasDetail && detail != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'พื้นที่จัดเก็บ:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: () {
                                      // รายการ area ที่ใช้งานได้
                                      final validAreas = _storage_locations
                                          .where((loc) => loc['area_name'] != 'เลือกพื้นที่จัดเก็บ' && 
                                                         loc['area_name'] != 'เพิ่มพื้นที่การเอง')
                                          .map((e) => e['area_name'] as String)
                                          .toList();
                                      
                                      // ตรวจสอบว่า area_name ของ detail อยู่ในรายการหรือไม่
                                      if (detail['area_name'] != null && 
                                          validAreas.contains(detail['area_name'])) {
                                        return detail['area_name'] as String;
                                      }
                                      
                                      // ถ้าไม่มี ให้ใช้ area แรกที่พร้อมใช้งาน
                                      return validAreas.isNotEmpty ? validAreas.first : null;
                                    }(),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    items: _storage_locations
                                        .where((loc) => loc['area_name'] != 'เลือกพื้นที่จัดเก็บ' && 
                                                       loc['area_name'] != 'เพิ่มพื้นที่การเอง')
                                        .map((location) {
                                      return DropdownMenuItem<String>(
                                        value: location['area_name'],
                                        child: Text(
                                          location['area_name'],
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          // อัปเดตพื้นที่ในข้อมูล
                                          final selectedLocation = _storage_locations.firstWhere(
                                            (loc) => loc['area_name'] == newValue,
                                            orElse: () => {'area_id': null}
                                          );
                                          _item_expire_details[index]['area_name'] = newValue;
                                          _item_expire_details[index]['area_id'] = selectedLocation['area_id'];
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        ], // ปิด if (widget.is_existing_item)
                      ] else if (!widget.is_existing_item && _enable_multiple_locations_option && !_allow_separate_expire_dates) ...[
                        // กรณีมีสิ่งของมากกว่า 1 ชิ้น แต่เลือกใช้วันหมดอายุเดียวกัน
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _build_dropdown(
                                value: _units.contains(_selected_unit) ? _selected_unit : 'วันหมดอายุ(EXP)',
                                items: _units,
                                fontSize: 16,
                                onChanged: (value) {
                                  setState(() {
                                    _selected_unit = value!;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _build_date_dropdown(),
                            ),
                          ],
                        ),
                      ] else ...[
                        // กรณีสิ่งของ 1 ชิ้น ใช้ UI เดิม
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _build_dropdown(
                                value: _units.contains(_selected_unit) ? _selected_unit : 'วันหมดอายุ(EXP)',
                                items: _units,
                                fontSize: 16, 
                                onChanged: (value) {
                                  setState(() {
                                    _selected_unit = value!;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _build_date_dropdown(),
                            ),
                          ],
                        ),
                      ],
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
                      // แสดงการเลือกพื้นที่เก็บหลักเฉพาะเมื่อไม่ได้ใช้ multiple locations และไม่ได้ใช้ระบบแยกพื้นที่สิ่งของ
                      if (!widget.is_existing_item && !_use_multiple_locations && !_allow_separate_storage) ...[
                        _build_section_title('พื้นที่จัดเก็บ'),
                        const SizedBox(height: 12),
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
                                          Navigator.pop(context); 
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
                      ], // ปิด if (!widget.is_existing_item)
                      
                      // แสดงข้อความแจ้งเตือนเมื่อซ่อนพื้นที่จัดเก็บเพราะใช้ระบบแยกพื้นที่สิ่งของ
                      if (!widget.is_existing_item && (_allow_separate_storage || _use_multiple_locations)) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber[600], size: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _allow_separate_storage 
                                      ? 'การตั้งค่าพื้นที่จัดเก็บจะกำหนดในแต่ละกลุ่มด้านล่าง'
                                      : 'การตั้งค่าพื้นที่จัดเก็บจะกำหนดเป็นพื้นที่หลักและพื้นที่เพิ่มเติมด้านล่าง',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color.fromARGB(255, 0, 0, 0),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Individual Storage Management Option (ซ่อนในโหมดแก้ไข)
                      if (!widget.is_existing_item && (int.tryParse(_quantity_controller.text) ?? 0) > 1) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.storage, color: Colors.green[600], size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'จัดกลุ่มตามพื้นที่เก็บ',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '• เปิด: แยกสิ่งของเป็นกลุ่มตามพื้นที่เก็บที่ต่างกัน\n• ปิด: เก็บสิ่งของทุกชิ้นในพื้นที่เดียวกัน',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.green[600],
                                      ),
                                    ),
                                    if (_allow_separate_storage) ...[

                                    
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              FlutterSwitch(
                                width: 70,
                                height: 32,
                                value: _allow_separate_storage,
                                onToggle: _toggle_individual_storage,
                                activeColor: Colors.green[600]!,
                                inactiveColor: Colors.red[400]!,
                                activeText: 'เปิด',
                                inactiveText: 'ปิด',
                                activeTextColor: Colors.white,
                                inactiveTextColor: Colors.white,
                                toggleColor: Colors.white,
                                showOnOff: true,
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Storage Groups Section (ใหม่)
                      if (_allow_separate_storage && !widget.is_existing_item && (int.tryParse(_quantity_controller.text) ?? 0) > 1) ...[
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _build_section_title('จัดกลุ่มพื้นที่เก็บ'),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'สถานะ: ${_get_total_grouped_storage_quantity() >= (int.tryParse(_quantity_controller.text) ?? 0) ? "จัดครบแล้ว" : "ยังจัดไม่ครบ"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _get_total_grouped_storage_quantity() >= (int.tryParse(_quantity_controller.text) ?? 0) ? Colors.green : Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'รวม: ${(int.tryParse(_quantity_controller.text) ?? 0)} ชิ้น',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  'จัดแล้ว: ${_get_total_grouped_storage_quantity()} ชิ้น',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // รายการกลุ่มพื้นที่เก็บ
                        ...List.generate(_storage_groups.length, (index) {
                          final group = _storage_groups[index];
                          final totalAvailable = int.tryParse(_quantity_controller.text) ?? 0;
                          final otherGroupsTotal = _storage_groups
                              .asMap()
                              .entries
                              .where((entry) => entry.key != index)
                              .fold<int>(0, (sum, entry) => sum + (entry.value['quantity'] as int));

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.green[50],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'กลุ่มที่ ${index + 1}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green[800],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'จำนวน: ${group['quantity']} ชิ้น | พื้นที่: ${group['area_name'] != null && group['area_name'].toString().isNotEmpty ? group['area_name'] : 'ยังไม่เลือก'}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.green[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_storage_groups.length > 1)
                                      IconButton(
                                        onPressed: () => _remove_storage_group(index),
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // จำนวนสิ่งของ
                                Row(
                                  children: [
                                    const Text(
                                      'จำนวน:',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.green[300]!),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: IconButton(
                                        onPressed: () {
                                          final currentQty = group['quantity'] as int;
                                          if (currentQty > 0) {
                                            _update_storage_group_quantity(index, currentQty - 1);
                                          }
                                        },
                                        icon: const Icon(Icons.remove, size: 12),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 50,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.green[300]!),
                                        borderRadius: BorderRadius.circular(4),
                                        color: Colors.white,
                                      ),
                                      child: Text(
                                        '${group['quantity']}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.green[300]!),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: IconButton(
                                        onPressed: () {
                                          final currentQty = group['quantity'] as int;
                                          final maxAllowed = totalAvailable - otherGroupsTotal;
                                          
                                          if (currentQty < maxAllowed) {
                                            _update_storage_group_quantity(index, currentQty + 1);
                                          }
                                        },
                                        icon: const Icon(Icons.add, size: 12),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'ชิ้น',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 12),
                                    // ปุ่มเพิ่มพื้นที่จัดเก็บใหม่แบบกะทัดรัด
                                    SizedBox(
                                      height: 28,
                                      child: OutlinedButton.icon(
                                        onPressed: _show_add_storage_dialog,
                                        icon: const Icon(Icons.add_location_alt_outlined, size: 12),
                                        label: const Text(
                                          'เพิ่มพื้นที่',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF4A90E2),
                                          side: const BorderSide(color: Color(0xFF4A90E2), width: 1),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          minimumSize: Size.zero,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // พื้นที่เก็บ
                                Row(
                                  children: [
                                    const Text(
                                      'พื้นที่เก็บ:',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: () {
                                          // ตรวจสอบว่า area_name ของกลุ่มมีใน storage_locations หรือไม่
                                          final availableAreas = _storage_locations
                                              .where((loc) => loc['area_name'] != 'เลือกพื้นที่จัดเก็บ' && 
                                                             loc['area_name'] != 'เพิ่มพื้นที่การเอง')
                                              .map((loc) => loc['area_name'] as String)
                                              .toList();
                                          
                                          final groupAreaName = group['area_name']?.toString();
                                          
                                          // ถ้า area_name ของกลุ่มมีอยู่ในรายการ และไม่ใช่ "เลือกพื้นที่จัดเก็บ" ให้ใช้ค่านั้น
                                          if (groupAreaName != null && 
                                              groupAreaName != 'เลือกพื้นที่จัดเก็บ' && 
                                              availableAreas.contains(groupAreaName)) {
                                            return groupAreaName;
                                          }
                                          
                                          // คืนค่า null เสมอเพื่อให้ผู้ใช้เลือกเอง
                                          return null;
                                        }(),
                                        decoration: InputDecoration(
                                          hintText: 'เลือกพื้นที่จัดเก็บ',
                                          hintStyle: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            borderSide: BorderSide(color: Colors.green[300]!),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            borderSide: BorderSide(color: Colors.green[300]!),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                        dropdownColor: Colors.white,
                                        menuMaxHeight: 400,
                                        itemHeight: 56,
                                        items: () {
                                          List<DropdownMenuItem<String>> items = [];
                                          
                                          // ไม่แสดงตัวเลือก "เพิ่มพื้นที่ใหม่" ใน dropdown ของกลุ่มพื้นที่เก็บ
                                          // เพื่อป้องกัน error และความสับสน
                                          
                                          // รวมพื้นที่ทั้งหมดและกรองซ้ำ
                                          final uniqueAreas = <String>{};
                                          final filteredLocations = _storage_locations
                                            .where((loc) => loc['area_name'] != 'เลือกพื้นที่จัดเก็บ' && 
                                                           loc['area_name'] != 'เพิ่มพื้นที่การเอง')
                                            .where((loc) {
                                              final areaName = loc['area_name'] as String;
                                              if (uniqueAreas.contains(areaName)) {
                                                return false; // ถ้ามีแล้วไม่เอา
                                              }
                                              uniqueAreas.add(areaName);
                                              return true;
                                            })
                                            .toList();
                                          
                                          // พื้นที่ระบบก่อน
                                          for (var loc in filteredLocations.where((loc) => loc['user_id'] != _current_user_id)) {
                                            items.add(DropdownMenuItem<String>(
                                              value: loc['area_name'],
                                              child: Text(
                                                loc['area_name'],
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ));
                                          }
                                          
                                          // พื้นที่ที่ผู้ใช้เพิ่มเอง (ท้ายสุด พร้อมไอคอนลบ)
                                          for (var loc in filteredLocations.where((loc) => loc['user_id'] == _current_user_id)) {
                                            items.add(DropdownMenuItem<String>(
                                              value: loc['area_name'],
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    loc['area_name'],
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: () {
                                                      Navigator.pop(context); // ปิด dropdown ก่อน
                                                      _confirm_delete_storage_dialog(loc['area_name']);
                                                    },
                                                    child: Icon(
                                                      Icons.delete_outline,
                                                      size: 16,
                                                      color: Colors.red[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ));
                                          }
                                          
                                          return items;
                                        }(),
                                        onChanged: (newValue) async {
                                          if (newValue != null) {
                                            try {
                                              final selectedLocation = _storage_locations.firstWhere(
                                                (loc) => loc['area_name'] == newValue,
                                                orElse: () => {'area_name': newValue, 'area_id': null}
                                              );
                                              _update_storage_group_area(index, newValue, selectedLocation['area_id']);
                                            } catch (e) {
                                              // Handle error gracefully
                                              print('Error updating storage group area: $e');
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),

                        // ปุ่มเพิ่มกลุ่ม
                        if (_get_total_grouped_storage_quantity() < (int.tryParse(_quantity_controller.text) ?? 0))
                          Container(
                            width: double.infinity,
                            height: 40,
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            child: OutlinedButton.icon(
                              onPressed: _add_storage_group,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('เพิ่มกลุ่มพื้นที่เก็บ'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4CAF50),
                                side: const BorderSide(color: Color(0xFF4CAF50)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),

                        // สรุปการกระจายสิ่งของตามพื้นที่เก็บ
                        if (_storage_groups.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.summarize, color: Colors.grey[700], size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'สรุปการกระจายสิ่งของ',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...() {
                                  // ใช้ฟังก์ชันใหม่เพื่อแสดงรายละเอียดแต่ละชิ้น
                                  final itemList = _generate_storage_preview();
                                  
                                  return itemList.map((item) {
                                    final expireDate = item['expire_date'] as DateTime;
                                    final unit = item['unit'] as String;
                                    final areaName = item['area_name'] as String;
                                    final isMain = item['is_main'] as bool? ?? false;
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey[200]!),
                                      ),
                                      child: Row(
                                        children: [
                                          // หมายเลขชิ้น
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: Colors.green[100],
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.green[300]!),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${item['index']}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          
                                          // ชื่อพื้นที่ (Dropdown)
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                DropdownButtonFormField<String>(
                                                  value: _storage_locations
                                                      .where((loc) => loc['area_name'] != 'เลือกพื้นที่จัดเก็บ' && 
                                                                     loc['area_name'] != 'เพิ่มพื้นที่การเอง')
                                                      .map((loc) => loc['area_name'] as String)
                                                      .contains(areaName) ? areaName : null,
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
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                  dropdownColor: Colors.white,
                                                  menuMaxHeight: 400,
                                                  itemHeight: 56,
                                                  items: () {
                                                    List<DropdownMenuItem<String>> items = [];
                                                    
                                                    // แสดงตัวเลือกเพิ่มพื้นที่ใหม่เสมอในสรุปการกระจาย
                                                    items.add(const DropdownMenuItem<String>(
                                                      value: '__ADD_NEW_AREA__',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.add_circle_outline, color: Color(0xFF4A90E2), size: 14),
                                                          SizedBox(width: 6),
                                                          Text(
                                                            'เพิ่มพื้นที่ใหม่',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Color(0xFF4A90E2),
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ));
                                                    
                                                    // รวมพื้นที่ทั้งหมดและกรองซ้ำ
                                                    final uniqueAreas = <String>{};
                                                    final filteredLocations = _storage_locations
                                                      .where((loc) => loc['area_name'] != 'เลือกพื้นที่จัดเก็บ' && 
                                                                     loc['area_name'] != 'เพิ่มพื้นที่การเอง')
                                                      .where((loc) {
                                                        final areaName = loc['area_name'] as String;
                                                        if (uniqueAreas.contains(areaName)) {
                                                          return false; // ถ้ามีแล้วไม่เอา
                                                        }
                                                        uniqueAreas.add(areaName);
                                                        return true;
                                                      })
                                                      .toList();
                                                    
                                                    // พื้นที่ระบบก่อน
                                                    for (var loc in filteredLocations.where((loc) => loc['user_id'] != _current_user_id)) {
                                                      items.add(DropdownMenuItem<String>(
                                                        value: loc['area_name'],
                                                        child: Text(
                                                          loc['area_name'],
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black87,
                                                          ),
                                                        ),
                                                      ));
                                                    }
                                                    
                                                    // พื้นที่ที่ผู้ใช้เพิ่มเอง (ท้ายสุด พร้อมไอคอนลบ)
                                                    for (var loc in filteredLocations.where((loc) => loc['user_id'] == _current_user_id)) {
                                                      items.add(DropdownMenuItem<String>(
                                                        value: loc['area_name'],
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              loc['area_name'],
                                                              style: const TextStyle(
                                                                fontSize: 14,
                                                                color: Colors.black87,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            GestureDetector(
                                                              onTap: () {
                                                                Navigator.pop(context); // ปิด dropdown ก่อน
                                                                _confirm_delete_storage_dialog(loc['area_name']);
                                                              },
                                                              child: Icon(
                                                                Icons.delete_outline,
                                                                size: 16,
                                                                color: Colors.red[600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ));
                                                    }
                                                    
                                                    return items;
                                                  }(),
                                                  onChanged: (newValue) async {
                                                    if (newValue == '__ADD_NEW_AREA__') {
                                                      // เรียกฟังก์ชันเพิ่มพื้นที่ใหม่
                                                      await _show_add_storage_dialog();
                                                      // อัปเดตพื้นที่ที่เลือกใหม่ในรายการ preview
                                                      if (_selected_storage != 'เลือกพื้นที่จัดเก็บ') {
                                                        final selectedLocation = _storage_locations.firstWhere(
                                                          (loc) => loc['area_name'] == _selected_storage,
                                                          orElse: () => {'area_name': _selected_storage, 'area_id': null}
                                                        );
                                                        setState(() {
                                                          item['area_name'] = _selected_storage;
                                                          item['area_id'] = selectedLocation['area_id'];
                                                        });
                                                      }
                                                    } else if (newValue != null) {
                                                      try {
                                                        final selectedLocation = _storage_locations.firstWhere(
                                                          (loc) => loc['area_name'] == newValue,
                                                          orElse: () => {'area_name': newValue, 'area_id': null}
                                                        );
                                                        
                                                        setState(() {
                                                          // อัปเดตข้อมูลในรายการ preview โดยตรง
                                                          item['area_name'] = newValue;
                                                          item['area_id'] = selectedLocation['area_id'];
                                                          
                                                          // บังคับให้ preview ถูก rebuild เพื่อแสดงการเปลี่ยนแปลง
                                                        });
                                                      } catch (e) {
                                                        // Handle error gracefully
                                                        print('Error updating area: $e');
                                                      }
                                                    }
                                                  },
                                                ),
                                                if (isMain)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4),
                                                    child: Text(
                                                      '(พื้นที่หลัก)',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.blue[600],
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          
                                          // วันหมดอายุ
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  _format_date(expireDate),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black87, // เพิ่มสีตัวอักษรให้ชัดเจน
                                                  ),
                                                ),
                                                Text(
                                                  unit,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList();
                                }(),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green[300]!),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'รวมทั้งหมด:',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                      Text(
                                        '${_get_total_grouped_storage_quantity()} ชิ้น',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      
                      // Multiple storage locations section (ซ่อนในโหมดแก้ไขและถ้าเปิด individual storage)
                      if (_use_multiple_locations && _enable_multiple_locations_option && !widget.is_existing_item && !_allow_separate_storage) ...[
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _build_section_title('กระจายสิ่งของไปพื้นที่เพิ่มเติม'),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'สถานะ: ${_remaining_quantity > 0 ? "ยังกระจายไม่ครบ" : "กระจายครบแล้ว"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _remaining_quantity > 0 ? Colors.orange : Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'รวม: ${(int.tryParse(_quantity_controller.text) ?? 0)} ชิ้น',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  'พื้นที่หลัก: ${(int.tryParse(_quantity_controller.text) ?? 0) - _item_locations.fold<int>(0, (sum, loc) => sum + (loc['quantity'] as int? ?? 0))} ชิ้น',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[600],
                                  ),
                                ),
                                Text(
                                  'พื้นที่เพิ่มเติม: ${_item_locations.fold<int>(0, (sum, loc) => sum + (loc['quantity'] as int? ?? 0))} ชิ้น',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.purple[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // แสดงข้อมูลพื้นที่หลักอย่างชัดเจน
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.home, color: Colors.blue[600], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'พื้นที่หลัก: $_selected_storage',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      // แสดง dialog เลือกพื้นที่หลักใหม่
                                      _show_main_storage_selection_dialog();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    'จำนวน:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.blue[300]!),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        final currentMainQty = (int.tryParse(_quantity_controller.text) ?? 0) - 
                                            _item_locations.fold<int>(0, (sum, loc) => sum + (loc['quantity'] as int? ?? 0));
                                        if (currentMainQty > 1 && _item_locations.isNotEmpty) {
                                          // ลดจำนวนในพื้นที่หลัก = เพิ่มจำนวนในพื้นที่กระจาย
                                          final firstLocation = _item_locations[0];
                                          final newQty = (firstLocation['quantity'] as int) + 1;
                                          _update_location_quantity(0, newQty);
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
                                      border: Border.all(color: Colors.blue[300]!),
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.white,
                                    ),
                                    child: Text(
                                      '${(int.tryParse(_quantity_controller.text) ?? 0) - _item_locations.fold<int>(0, (sum, loc) => sum + (loc['quantity'] as int? ?? 0))}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.blue[300]!),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        // เพิ่มจำนวนในพื้นที่หลัก = ลดจำนวนในพื้นที่กระจาย
                                        if (_item_locations.isNotEmpty) {
                                          final firstLocation = _item_locations[0];
                                          final currentQty = firstLocation['quantity'] as int;
                                          if (currentQty > 1) {
                                            _update_location_quantity(0, currentQty - 1);
                                          } else if (currentQty == 1) {
                                            // ถ้าเหลือ 1 ชิ้น ให้ลบ location นั้นออก
                                            _remove_storage_location(0);
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.add, size: 12),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'ชิ้น',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
                                // หัวข้อของพื้นที่เพิ่มเติม
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'พื้นที่เพิ่มเติม ${index + 1}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'จำนวน: ${_item_locations[index]['quantity']} ชิ้น | พื้นที่: ${_item_locations[index]['area_name'] ?? 'ยังไม่เลือก'}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      onPressed: () => _remove_storage_location(index),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: DropdownButtonFormField<String>(
                                        value: () {
                                          // ตรวจสอบว่า area_name ของ location มีใน storage_locations หรือไม่
                                          final availableAreas = _storage_locations
                                              .where((loc) => loc['area_name'] != 'เลือกพื้นที่จัดเก็บ' && 
                                                             loc['area_name'] != 'เพิ่มพื้นที่การเอง')
                                              .map((loc) => loc['area_name'] as String)
                                              .toList();
                                          
                                          final locationAreaName = _item_locations[index]['area_name']?.toString();
                                          
                                          // ถ้า area_name ของ location มีอยู่ในรายการ ให้ใช้ค่านั้น
                                          if (locationAreaName != null && availableAreas.contains(locationAreaName)) {
                                            return locationAreaName;
                                          }
                                          
                                          // ถ้าไม่มี ให้เลือกพื้นที่แรกที่มี
                                          return availableAreas.isNotEmpty ? availableAreas.first : null;
                                        }(),
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
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87, // เพิ่มสีตัวอักษร
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (newValue) {
                                          if (newValue != null) {
                                            try {
                                              final selectedLocation = _storage_locations.firstWhere(
                                                (loc) => loc['area_name'] == newValue,
                                                orElse: () => {'area_name': newValue, 'area_id': null}
                                              );
                                              _update_location_area(index, newValue, selectedLocation['area_id']);
                                            } catch (e) {
                                              // Handle error gracefully
                                              print('Error updating location area: $e');
                                            }
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
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        
                        // สรุปการกระจายสิ่งของสำหรับ Multiple Locations
                        if (_item_locations.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.summarize, color: Colors.blue[700], size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'สรุปการกระจายสิ่งของ',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // แสดงรายละเอียดแต่ละชิ้นสำหรับ Multiple Locations
                                ...() {
                                  final itemList = _generate_storage_preview();
                                  
                                  return itemList.map((item) {
                                    final expireDate = item['expire_date'] as DateTime;
                                    final unit = item['unit'] as String;
                                    final areaName = item['area_name'] as String;
                                    final isMain = item['is_main'] as bool? ?? false;
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.blue[200]!),
                                      ),
                                      child: Row(
                                        children: [
                                          // หมายเลขชิ้น
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: isMain ? Colors.blue[100] : Colors.orange[100],
                                              shape: BoxShape.circle,
                                              border: Border.all(color: isMain ? Colors.blue[300]! : Colors.orange[300]!),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${item['index']}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: isMain ? Colors.blue[700] : Colors.orange[700],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          
                                          // ชื่อพื้นที่
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  areaName,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (isMain)
                                                  Text(
                                                    '(พื้นที่หลัก)',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.blue[600],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          
                                          // วันหมดอายุ
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  _format_date(expireDate),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  unit,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList();
                                }(),
                                
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blue[300]!),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'รวมทั้งหมด:',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                      Text(
                                        '${int.tryParse(_quantity_controller.text) ?? 0} ชิ้น',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
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
                              style: TextStyle(fontSize: 20),
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
                            style: TextStyle(fontSize: 20),
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
        fontSize: 20, // เพิ่มจาก 16 เป็น 20
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
      style: const TextStyle(fontSize: 18), // เพิ่มขนาดฟอนต์
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 18), // เพิ่มขนาดฟอนต์ hint
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // เพิ่ม vertical padding
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
    double? fontSize, // เพิ่มพารามิเตอร์ขนาดฟอนต์
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), // เพิ่ม vertical padding
      ),
      style: TextStyle(
        fontSize: fontSize ?? 18,
        color: Colors.black87, // เพิ่มสีตัวอักษรหลักของ dropdown
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: TextStyle(
              fontSize: fontSize ?? 18, // เพิ่มขนาดฟอนต์เริ่มต้น
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

  // Build date dropdown widget
  Widget _build_date_dropdown() {
    return GestureDetector(
      onTap: _show_date_picker_popup,
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
                _format_date_display(_selected_date),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Format date for display (showing Christian year)
  String _format_date_display(DateTime date) {
    String day = date.day.toString().padLeft(2, '0');
    String month = date.month.toString().padLeft(2, '0');
    return "$day/$month/${date.year}"; // Show in DD/MM/YYYY format
  }

  // Show date picker popup
  Future<void> _show_date_picker_popup() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        int tempDay = _selected_day;
        int tempMonth = _selected_month;
        int tempYear = _selected_year;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('เลือกวันที่', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Day dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              const Text('วัน', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: tempDay,
                                    isExpanded: true,
                                    items: _get_days_in_month_for_year_month(tempYear, tempMonth).map((day) {
                                      return DropdownMenuItem<int>(
                                        value: day,
                                        child: Text('$day', style: const TextStyle(fontSize: 14)),
                                      );
                                    }).toList(),
                                    onChanged: (newDay) {
                                      if (newDay != null) {
                                        setDialogState(() {
                                          tempDay = newDay;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Month dropdown
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              const Text('เดือน', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: tempMonth,
                                    isExpanded: true,
                                    items: _get_months().map((month) {
                                      return DropdownMenuItem<int>(
                                        value: month['value'],
                                        child: Text(month['name'], style: const TextStyle(fontSize: 14)),
                                      );
                                    }).toList(),
                                    onChanged: (newMonth) {
                                      if (newMonth != null) {
                                        setDialogState(() {
                                          tempMonth = newMonth;
                                          // Check if current day is valid for new month
                                          int daysInMonth = DateTime(tempYear, newMonth + 1, 0).day;
                                          if (tempDay > daysInMonth) {
                                            tempDay = daysInMonth;
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Year dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              const Text('ปี (ค.ศ.)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: tempYear,
                                    isExpanded: true,
                                    items: _get_years().map((year) {
                                      return DropdownMenuItem<int>(
                                        value: year,
                                        child: Text('$year', style: const TextStyle(fontSize: 14)), // Show Christian year
                                      );
                                    }).toList(),
                                    onChanged: (newYear) {
                                      if (newYear != null) {
                                        setDialogState(() {
                                          tempYear = newYear;
                                          // Check if current day is valid for new month/year
                                          int daysInMonth = DateTime(newYear, tempMonth + 1, 0).day;
                                          if (tempDay > daysInMonth) {
                                            tempDay = daysInMonth;
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Preview selected date
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'วันที่เลือก: ${tempDay.toString().padLeft(2, '0')}/${tempMonth.toString().padLeft(2, '0')}/${tempYear}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selected_day = tempDay;
                      _selected_month = tempMonth;
                      _selected_year = tempYear;
                      _update_selected_date();
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('ตกลง'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper function to get days in specific month/year
  List<int> _get_days_in_month_for_year_month(int year, int month) {
    int daysInMonth = DateTime(year, month + 1, 0).day;
    return List.generate(daysInMonth, (index) => index + 1);
  }

  // Show date picker popup for expire group
  Future<void> _show_expire_group_date_picker(int groupIndex, DateTime currentDate) async {
    int tempDay = currentDate.day;
    int tempMonth = currentDate.month;
    int tempYear = currentDate.year;

    final DateTime? result = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('เลือกวันหมดอายุ - กลุ่มที่ ${groupIndex + 1}', 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Day dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              const Text('วัน', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: tempDay,
                                    isExpanded: true,
                                    items: _get_days_in_month_for_year_month(tempYear, tempMonth).map((day) {
                                      return DropdownMenuItem<int>(
                                        value: day,
                                        child: Text('$day', style: const TextStyle(fontSize: 14)),
                                      );
                                    }).toList(),
                                    onChanged: (newDay) {
                                      if (newDay != null) {
                                        setDialogState(() {
                                          tempDay = newDay;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Month dropdown
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              const Text('เดือน', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: tempMonth,
                                    isExpanded: true,
                                    items: _get_months().map((month) {
                                      return DropdownMenuItem<int>(
                                        value: month['value'],
                                        child: Text(month['name'], style: const TextStyle(fontSize: 14)),
                                      );
                                    }).toList(),
                                    onChanged: (newMonth) {
                                      if (newMonth != null) {
                                        setDialogState(() {
                                          tempMonth = newMonth;
                                          // Check if current day is valid for new month
                                          int daysInMonth = DateTime(tempYear, newMonth + 1, 0).day;
                                          if (tempDay > daysInMonth) {
                                            tempDay = daysInMonth;
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Year dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              const Text('ปี (ค.ศ.)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: tempYear,
                                    isExpanded: true,
                                    items: _get_years().map((year) {
                                      return DropdownMenuItem<int>(
                                        value: year,
                                        child: Text('$year', style: const TextStyle(fontSize: 14)),
                                      );
                                    }).toList(),
                                    onChanged: (newYear) {
                                      if (newYear != null) {
                                        setDialogState(() {
                                          tempYear = newYear;
                                          // Check if current day is valid for new month/year
                                          int daysInMonth = DateTime(newYear, tempMonth + 1, 0).day;
                                          if (tempDay > daysInMonth) {
                                            tempDay = daysInMonth;
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Preview selected date
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.orange.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'วันที่เลือก: ${tempDay.toString().padLeft(2, '0')}/${tempMonth.toString().padLeft(2, '0')}/${tempYear}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final selectedDate = DateTime(tempYear, tempMonth, tempDay);
                    Navigator.of(context).pop(selectedDate);
                  },
                  child: const Text('ตกลง'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      _update_expire_group_date(groupIndex, result);
    }
  }

  // Show date picker popup for individual item expire date
  Future<void> _show_individual_expire_date_picker(int itemIndex, DateTime currentDate) async {
    int tempDay = currentDate.day;
    int tempMonth = currentDate.month;
    int tempYear = currentDate.year;

    final DateTime? result = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('เลือกวันหมดอายุ - ชิ้นที่ ${itemIndex + 1}', 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Day dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              const Text('วัน', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: tempDay,
                                    isExpanded: true,
                                    items: _get_days_in_month_for_year_month(tempYear, tempMonth).map((day) {
                                      return DropdownMenuItem<int>(
                                        value: day,
                                        child: Text('$day', style: const TextStyle(fontSize: 14)),
                                      );
                                    }).toList(),
                                    onChanged: (newDay) {
                                      if (newDay != null) {
                                        setDialogState(() {
                                          tempDay = newDay;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Month dropdown
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              const Text('เดือน', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: tempMonth,
                                    isExpanded: true,
                                    items: _get_months().map((month) {
                                      return DropdownMenuItem<int>(
                                        value: month['value'],
                                        child: Text(month['name'], style: const TextStyle(fontSize: 14)),
                                      );
                                    }).toList(),
                                    onChanged: (newMonth) {
                                      if (newMonth != null) {
                                        setDialogState(() {
                                          tempMonth = newMonth;
                                          // Check if current day is valid for new month
                                          int daysInMonth = DateTime(tempYear, newMonth + 1, 0).day;
                                          if (tempDay > daysInMonth) {
                                            tempDay = daysInMonth;
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Year dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              const Text('ปี (ค.ศ.)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: tempYear,
                                    isExpanded: true,
                                    items: _get_years().map((year) {
                                      return DropdownMenuItem<int>(
                                        value: year,
                                        child: Text('$year', style: const TextStyle(fontSize: 14)),
                                      );
                                    }).toList(),
                                    onChanged: (newYear) {
                                      if (newYear != null) {
                                        setDialogState(() {
                                          tempYear = newYear;
                                          // Check if current day is valid for new month/year
                                          int daysInMonth = DateTime(newYear, tempMonth + 1, 0).day;
                                          if (tempDay > daysInMonth) {
                                            tempDay = daysInMonth;
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Preview selected date
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.green.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'วันที่เลือก: ${tempDay.toString().padLeft(2, '0')}/${tempMonth.toString().padLeft(2, '0')}/${tempYear}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final selectedDate = DateTime(tempYear, tempMonth, tempDay);
                    Navigator.of(context).pop(selectedDate);
                  },
                  child: const Text('ตกลง'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      _update_expire_date(itemIndex, result);
    }
  }
}