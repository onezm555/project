import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'item_detail_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async'; // เพิ่ม import สำหรับ Timer

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  Set<String> _sentNotifications = {}; // เก็บรายการการแจ้งเตือนที่ส่งไปแล้ว
  Timer? _periodicTimer; // เพิ่มตัวแปรสำหรับการตรวจสอบอัตโนมัติ

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _requestNotificationPermission();
    _loadSentNotifications();
    _fetch_notifications();
    _startPeriodicNotificationCheck(); // เริ่มการตรวจสอบอัตโนมัติ
  }

  @override
  void dispose() {
    _periodicTimer?.cancel(); // ยกเลิก Timer เมื่อ dispose
    super.dispose();
  }

  // ฟังก์ชันโหลดรายการการแจ้งเตือนที่ส่งแล้วจาก SharedPreferences
  Future<void> _loadSentNotifications() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? sentList = prefs.getStringList('sent_notifications');
      
      if (sentList != null) {
        _sentNotifications = sentList.toSet();
        
        // ทำความสะอาดข้อมูลเก่าหลังจากโหลด
        _cleanupOldNotifications();
        await _saveSentNotifications();
      }
    } catch (e) {
      // ข้อผิดพลาดในการโหลด
    }
  }

  // ฟังก์ชันบันทึกรายการการแจ้งเตือนที่ส่งแล้วลง SharedPreferences
  Future<void> _saveSentNotifications() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('sent_notifications', _sentNotifications.toList());
    } catch (e) {
      // ข้อผิดพลาดในการบันทึก
    }
  }

  // ฟังก์ชันการแจ้งเตือน
  void _startPeriodicNotificationCheck() {
    _periodicTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkAndSendNotifications();
    });
    _checkAndSendNotifications();
  }

  Future<void> _checkAndSendNotifications() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');
      
      if (userId == null) {
        return;
      }

      final String apiUrl = '${dotenv.env['API_BASE_URL']}/calendar_items.php?user_id=$userId';
      final response = await http.get(Uri.parse(apiUrl));
      
      if (response.statusCode != 200) {
        return;
      }
      
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      
      if (responseData['success'] != true) {
        return;
      }
      
      final items = responseData['data'] as List;
      final now = DateTime.now();
      
      for (var item in items) {
        try {
          if (item['item_expire_details'] != null && 
              (item['item_expire_details'] as List).isNotEmpty) {

            final List<dynamic> expire_details = item['item_expire_details'];
            
            for (int index = 0; index < expire_details.length; index++) {
              final detail = expire_details[index];
              final expireDate = DateTime.parse(detail['expire_date']);
              final notifyDays = detail['notification_days'] ?? 
                               item['item_notification'] ?? 
                               item['notification_days'] ?? 3;
              final notifyDate = expireDate.subtract(Duration(days: notifyDays));
              final daysLeft = expireDate.difference(now).inDays;

              final shouldNotify = now.isAfter(notifyDate) && now.isBefore(expireDate.add(const Duration(days: 1)));
              
              if (shouldNotify) {
                final itemId = item['item_id'] is int ? item['item_id'] : int.tryParse(item['item_id'].toString()) ?? 0;
                final itemName = item['item_name'] ?? 'สิ่งของไม่ระบุชื่อ';
                final areaName = detail['area_name'] ?? item['area_name'] ?? '';

                final notificationKey = '${itemId}_${index}_${now.year}-${now.month}-${now.day}';

                if (_sentNotifications.contains(notificationKey)) {
                  continue;
                }
                
                final dateType = item['date_type']?.toString().toUpperCase() ?? 'EXP';
                final isBBF = dateType == 'BBF';
                
                String title = isBBF ? 'สิ่งของใกล้ควรบริโภคก่อน' : 'สิ่งของใกล้หมดอายุ';
                String message;
                
                if (isBBF) {
                  message = daysLeft < 0
                      ? '$itemName (ชิ้นที่ ${index + 1}${areaName.isNotEmpty ? ' - $areaName' : ''}) เลยวันควรบริโภคแล้ว'
                      : '$itemName (ชิ้นที่ ${index + 1}${areaName.isNotEmpty ? ' - $areaName' : ''}) ควรบริโภคในอีก $daysLeft วัน';
                } else {
                  message = daysLeft < 0
                      ? '$itemName (ชิ้นที่ ${index + 1}${areaName.isNotEmpty ? ' - $areaName' : ''}) หมดอายุแล้ว'
                      : '$itemName (ชิ้นที่ ${index + 1}${areaName.isNotEmpty ? ' - $areaName' : ''}) จะหมดอายุในอีก $daysLeft วัน';
                }
                
                try {
                  await flutterLocalNotificationsPlugin.show(
                    itemId + 10000 + index,
                    title,
                    message,
                    const NotificationDetails(
                      android: AndroidNotificationDetails(
                        'auto_expire_channel',
                        'แจ้งเตือนสิ่งของอัตโนมัติ',
                        channelDescription: 'แจ้งเตือนสิ่งของที่ถึงเวลาอัตโนมัติ',
                        importance: Importance.max,
                        priority: Priority.high,
                        showWhen: true,
                      ),
                    ),
                  );

                  _sentNotifications.add(notificationKey);
                  await _saveSentNotifications(); 
                  
                } catch (e) {
                  //
                }
              }
            }
          } else {
            final expireDate = DateTime.parse(item['item_date']);
            final notifyDays = int.tryParse(item['item_notification'].toString()) ?? 0;
            final notifyDate = expireDate.subtract(Duration(days: notifyDays));
            final daysLeft = expireDate.difference(now).inDays;

            final shouldNotify = now.isAfter(notifyDate) && now.isBefore(expireDate.add(const Duration(days: 1)));
            
            if (shouldNotify) {
              final itemId = item['item_id'] is int ? item['item_id'] : int.tryParse(item['item_id'].toString()) ?? 0;
              final itemName = item['item_name'] ?? 'สิ่งของไม่ระบุชื่อ';

              final notificationKey = '${itemId}_${now.year}-${now.month}-${now.day}';

              if (_sentNotifications.contains(notificationKey)) {
                continue;
              }
              
              final dateType = item['date_type']?.toString().toUpperCase() ?? 'EXP';
              final isBBF = dateType == 'BBF';
              
              String title = isBBF ? 'สิ่งของใกล้ควรบริโภคก่อน' : 'สิ่งของใกล้หมดอายุ';
              String message;
              
              if (isBBF) {
                message = daysLeft < 0
                    ? '$itemName เลยวันควรบริโภคแล้ว'
                    : '$itemName ควรบริโภคในอีก $daysLeft วัน';
              } else {
                message = daysLeft < 0
                    ? '$itemName หมดอายุแล้ว'
                    : '$itemName จะหมดอายุในอีก $daysLeft วัน';
              }

              try {
                await flutterLocalNotificationsPlugin.show(
                  itemId + 10000, 
                  title,
                  message,
                  const NotificationDetails(
                    android: AndroidNotificationDetails(
                      'auto_expire_channel',
                      'แจ้งเตือนสิ่งของอัตโนมัติ',
                      channelDescription: 'แจ้งเตือนสิ่งของที่ถึงเวลาอัตโนมัติ',
                      importance: Importance.max,
                      priority: Priority.high,
                      showWhen: true,
                    ),
                  ),
                );
                
                // เพิ่ม key ลงในรายการที่ส่งแล้ว
                _sentNotifications.add(notificationKey);
                await _saveSentNotifications(); 
                
              } catch (e) {
                // การแจ้งเตือนล้มเหลว ไม่ต้องทำอะไร
              }
            }
          }
        } catch (e) {
          // ข้อผิดพลาดในการประมวลผลรายการ
        }
      }
      

      await _cleanupOldNotifications();
      
    } catch (e) {
      // ข้อผิดพลาดในการตรวจสอบอัตโนมัติ
    }
  }

  // ฟังก์ชันทำความสะอาดรายการการแจ้งเตือนเก่า
  Future<void> _cleanupOldNotifications() async {
    final now = DateTime.now();
    final cutoffDate = now.subtract(const Duration(days: 7));
    final initialCount = _sentNotifications.length;
    

    _sentNotifications.removeWhere((key) {
      try {
        final parts = key.split('_');
        String? dateStr;
        if (parts.length == 2) {
          dateStr = parts[1];
        } else if (parts.length == 3) {
          dateStr = parts[2];
        } else {
          // ถ้า format ไม่ตรง ให้ลบออก
          return true;
        }
        final dateParts = dateStr.split('-');
        if (dateParts.length == 3) {
          final notificationDate = DateTime(
            int.parse(dateParts[0]), 
            int.parse(dateParts[1]), 
            int.parse(dateParts[2]), 
          );
          return notificationDate.isBefore(cutoffDate);
        }
        return false;
      } catch (e) {
        // ถ้า parse ไม่ได้ให้ลบออก
        return true;
      }
    });
    
    // บันทึกข้อมูลหลังจากทำความสะอาดถ้ามีการเปลี่ยนแปลง
    if (initialCount != _sentNotifications.length) {
      await _saveSentNotifications();
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    
    // ตรวจสอบ Schedule Exact Alarm permission (Android 12+)
    try {
      final plugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (plugin != null) {
        await plugin.requestExactAlarmsPermission();
      }
    } catch (e) {
      // ข้อผิดพลาดในการขอสิทธิ์
    }
  }

  Future<void> _initializeNotifications() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }
  Future<void> _fetch_notifications() async {
    setState(() {
      _isLoading = true;
    });
    
    await _cleanupOldNotifications();
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');
    if (userId == null) {
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
      return;
    }

    final String apiUrl = '${dotenv.env['API_BASE_URL']}/calendar_items.php?user_id=$userId';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        if (responseData['success'] == true) {
          List<Map<String, dynamic>> notiList = [];
          final now = DateTime.now();
          
          for (var item in responseData['data']) {
            // ตรวจสอบว่ามีข้อมูล item_expire_details หรือไม่ (สำหรับสิ่งของที่มีมากกว่า 1 ชิ้น)
            if (item['item_expire_details'] != null && 
                (item['item_expire_details'] as List).isNotEmpty) {
              
              // กรณีสิ่งของมีรายละเอียดแต่ละชิ้น
              final List<dynamic> expire_details = item['item_expire_details'];
              
              for (int index = 0; index < expire_details.length; index++) {
                final detail = expire_details[index];
                final expireDate = DateTime.parse(detail['expire_date']);
                final notifyDays = detail['notification_days'] ?? 
                                 item['item_notification'] ?? 
                                 item['notification_days'] ?? 3;
                final notifyDate = expireDate.subtract(Duration(days: notifyDays));
                final daysLeft = expireDate.difference(now).inDays;
                
                // Schedule local notification
                _scheduleIndividualNotification(item, detail, index, notifyDate, daysLeft);
                
                // เช็คว่าควรแสดงการแจ้งเตือนหรือไม่
                // แสดงการแจ้งเตือนถ้า: 1) ถึงเวลาแจ้งเตือนแล้ว หรือ 2) หมดอายุแล้ว (ไม่จำกัดจำนวนวัน)
                bool shouldShowNotification = false;
                if (daysLeft >= 0) {
                  // ยังไม่หมดอายุ - แสดงถ้าถึงเวลาแจ้งเตือนแล้ว
                  shouldShowNotification = now.isAfter(notifyDate);
                } else {
                  // หมดอายุแล้ว - แสดงเรื่อยๆ จนกว่าจะเปลี่ยนสถานะ
                  shouldShowNotification = true;
                }
                
                if (shouldShowNotification) {
                  // ตรวจสอบประเภทวันที่ (EXP หรือ BBF)
                  final dateType = item['date_type']?.toString().toUpperCase() ?? 'EXP';
                  final isBBF = dateType == 'BBF';
                  final areaName = detail['area_name'] ?? item['area_name'] ?? '';
                  
                  String description;
                  String dateLabel;
                  
                  if (isBBF) {
                    description = daysLeft < 0
                        ? 'เลยวันควรบริโภคแล้ว ${(-daysLeft)} วัน (ชิ้นที่ ${index + 1}${areaName.isNotEmpty ? ' - $areaName' : ''})'
                        : 'ควรบริโภคในอีก ${daysLeft} วัน (ชิ้นที่ ${index + 1}${areaName.isNotEmpty ? ' - $areaName' : ''})';
                    dateLabel = 'วันควรบริโภคก่อน ${expireDate.day}/${expireDate.month}/${expireDate.year}';
                  } else {
                    description = daysLeft < 0
                        ? 'หมดอายุแล้ว ${(-daysLeft)} วัน (ชิ้นที่ ${index + 1}${areaName.isNotEmpty ? ' - $areaName' : ''})'
                        : 'จะหมดอายุในอีก ${daysLeft} วัน (ชิ้นที่ ${index + 1}${areaName.isNotEmpty ? ' - $areaName' : ''})';
                    dateLabel = 'วันหมดอายุ ${expireDate.day}/${expireDate.month}/${expireDate.year}';
                  }
                  
                  // สร้างข้อมูลสำหรับแต่ละชิ้น
                  Map<String, dynamic> individual_item = Map<String, dynamic>.from(item);
                  individual_item['item_date'] = detail['expire_date'];
                  individual_item['item_notification'] = notifyDays;
                  individual_item['notification_days'] = notifyDays;
                  individual_item['area_name'] = areaName;
                  individual_item['storage_location'] = areaName;
                  individual_item['item_number'] = detail['quantity'] ?? 1;
                  individual_item['quantity'] = detail['quantity'] ?? 1;
                  individual_item['expire_detail_id'] = detail['id'];
                  individual_item['expire_detail'] = detail;
                  
                  notiList.add({
                    'id': '${item['item_id']}_$index', // unique ID สำหรับแต่ละชิ้น
                    'type': daysLeft <= 0 ? 'today' : 'stored',
                    'title': '${item['item_name']} (ชิ้นที่ ${index + 1})',
                    'description': description,
                    'date': dateLabel,
                    'is_expired': daysLeft < 0,
                    'is_bbf': isBBF,
                    'date_type': dateType,
                    'created_at': now,
                    'item_data': individual_item, // เก็บข้อมูลที่ปรับแล้วสำหรับชิ้นนี้
                  });
                }
              }
            } else {
              // กรณีสิ่งของปกติ (1 ชิ้น หรือไม่มี item_expire_details)
              final expireDate = DateTime.parse(item['item_date']);
              final notifyDays = int.tryParse(item['item_notification'].toString()) ?? 0;
              final notifyDate = expireDate.subtract(Duration(days: notifyDays));
              final daysLeft = expireDate.difference(now).inDays;
              
              // Schedule local notification
              _scheduleNotification(item, notifyDate, daysLeft);
              
              // เช็คว่าควรแสดงการแจ้งเตือนหรือไม่
              // แสดงการแจ้งเตือนถ้า: 1) ถึงเวลาแจ้งเตือนแล้ว หรือ 2) หมดอายุแล้ว (ไม่จำกัดจำนวนวัน)
              bool shouldShowNotification = false;
              if (daysLeft >= 0) {
                // ยังไม่หมดอายุ - แสดงถ้าถึงเวลาแจ้งเตือนแล้ว
                shouldShowNotification = now.isAfter(notifyDate);
              } else {
                // หมดอายุแล้ว - แสดงเรื่อยๆ จนกว่าจะเปลี่ยนสถานะ
                shouldShowNotification = true;
              }
              
              if (shouldShowNotification) {
                // ตรวจสอบประเภทวันที่ (EXP หรือ BBF)
                final dateType = item['date_type']?.toString().toUpperCase() ?? 'EXP';
                final isBBF = dateType == 'BBF';
                
                String description;
                String dateLabel;
                
                if (isBBF) {
                  description = daysLeft < 0
                      ? 'เลยวันควรบริโภคแล้ว ${(-daysLeft)} วัน'
                      : 'ควรบริโภคในอีก ${daysLeft} วัน';
                  dateLabel = 'วันควรบริโภคก่อน ${expireDate.day}/${expireDate.month}/${expireDate.year}';
                } else {
                  description = daysLeft < 0
                      ? 'หมดอายุแล้ว ${(-daysLeft)} วัน'
                      : 'จะหมดอายุในอีก ${daysLeft} วัน';
                  dateLabel = 'วันหมดอายุ ${expireDate.day}/${expireDate.month}/${expireDate.year}';
                }
                
                notiList.add({
                  'id': item['item_id'],
                  'type': daysLeft <= 0 ? 'today' : 'stored',
                  'title': item['item_name'],
                  'description': description,
                  'date': dateLabel,
                  'is_expired': daysLeft < 0,
                  'is_bbf': isBBF,
                  'date_type': dateType,
                  'created_at': now,
                  'item_data': item, // เก็บข้อมูลดิบของสิ่งของจาก calendar_items.php
                });
              }
            }
          }
          setState(() {
            _notifications = notiList;
            _isLoading = false;
          });
        } else {
          setState(() {
            _notifications = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _scheduleNotification(Map<String, dynamic> item, DateTime notifyDate, int daysLeft) async {
    final now = DateTime.now();
    final itemId = item['item_id'] is int ? item['item_id'] : int.tryParse(item['item_id'].toString()) ?? 0;
    final dateType = item['date_type']?.toString().toUpperCase() ?? 'EXP';
    final isBBF = dateType == 'BBF';
    
    // สร้าง unique key สำหรับตรวจสอบการแจ้งเตือนซ้ำ
    final notificationKey = '${itemId}_${now.year}-${now.month}-${now.day}';
    
    // เช็คว่าเคยส่งการแจ้งเตือนในวันนี้แล้วหรือไม่
    if (_sentNotifications.contains(notificationKey)) {
      return;
    }
    
    // ยกเลิกการแจ้งเตือนเก่าก่อน (ถ้ามี)
    try {
      await flutterLocalNotificationsPlugin.cancel(itemId);
    } catch (e) {
      // ข้อผิดพลาดในการยกเลิก
    }
    
    String title = isBBF ? 'สิ่งของใกล้ควรบริโภคก่อน' : 'สิ่งของใกล้หมดอายุ';
    String message;
    
    if (isBBF) {
      message = daysLeft < 0
          ? '${item['item_name']} เลยวันควรบริโภคแล้ว ${(-daysLeft)} วัน'
          : '${item['item_name']} ควรบริโภคในอีก $daysLeft วัน';
    } else {
      message = daysLeft < 0
          ? '${item['item_name']} หมดอายุแล้ว ${(-daysLeft)} วัน'
          : '${item['item_name']} จะหมดอายุในอีก $daysLeft วัน';
    }
    
    // ถ้าควรแจ้งเตือนแล้ว (ผ่านวันแจ้งเตือนแล้ว) ให้แจ้งทันที
    if (now.isAfter(notifyDate) || now.isAtSameMomentAs(notifyDate)) {
      try {
        await flutterLocalNotificationsPlugin.show(
          itemId,
          title,
          message,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'expire_immediate_channel',
              'แจ้งเตือนสิ่งของทันที',
              channelDescription: 'แจ้งเตือนสิ่งของที่ถึงเวลาแล้ว',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
        );
        
        // บันทึกว่าส่งการแจ้งเตือนแล้ว
        _sentNotifications.add(notificationKey);
        await _saveSentNotifications(); // บันทึกลง SharedPreferences
      } catch (e) {
        // ข้อผิดพลาดในการแสดงการแจ้งเตือน
      }
    } else {
      // ถ้ายังไม่ถึงเวลา ให้ตั้งเวลาแจ้งเตือน
      try {
        // ตั้งเวลาแจ้งเตือนในวันที่กำหนด เวลา 09:00
        final scheduledDate = DateTime(
          notifyDate.year,
          notifyDate.month,
          notifyDate.day,
          9, // 9 AM
          0,
          0,
        );
        
        await flutterLocalNotificationsPlugin.zonedSchedule(
          itemId,
          title,
          message,
          tz.TZDateTime.from(scheduledDate, tz.getLocation('Asia/Bangkok')),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'expire_scheduled_channel',
              'แจ้งเตือนสิ่งของตามกำหนด',
              channelDescription: 'แจ้งเตือนวันหมดอายุสิ่งของตามที่ตั้งไว้',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        // ข้อผิดพลาดในการตั้งเวลา
      }
    }
  }

  Future<void> _scheduleIndividualNotification(Map<String, dynamic> item, Map<String, dynamic> detail, int index, DateTime notifyDate, int daysLeft) async {
    final now = DateTime.now();
    final itemId = item['item_id'] is int ? item['item_id'] : int.tryParse(item['item_id'].toString()) ?? 0;
    final dateType = item['date_type']?.toString().toUpperCase() ?? 'EXP';
    final isBBF = dateType == 'BBF';
    final areaName = detail['area_name'] ?? item['area_name'] ?? '';
    
    // สร้าง unique key สำหรับตรวจสอบการแจ้งเตือนซ้ำ (รวม index เพื่อแยกแต่ละชิ้น)
    final notificationKey = '${itemId}_${index}_${now.year}-${now.month}-${now.day}';
    
    // เช็คว่าเคยส่งการแจ้งเตือนในวันนี้แล้วหรือไม่
    if (_sentNotifications.contains(notificationKey)) {
      return;
    }
    
    // ยกเลิกการแจ้งเตือนเก่าก่อน (ถ้ามี)
    try {
      await flutterLocalNotificationsPlugin.cancel(itemId + index * 1000); // ใช้ ID ที่แตกต่างกันสำหรับแต่ละชิ้น
    } catch (e) {
      // ข้อผิดพลาดในการยกเลิก
    }
    
    String title = isBBF ? 'สิ่งของใกล้ควรบริโภคก่อน' : 'สิ่งของใกล้หมดอายุ';
    String message;
    
    if (isBBF) {
      message = daysLeft < 0
          ? '${item['item_name']} (ชิ้นที่ ${index + 1}${areaName.isNotEmpty ? ' - $areaName' : ''}) เลยวันควรบริโภคแล้ว ${(-daysLeft)} วัน'
          : '${item['item_name']} (ชิ้นที่ ${index + 1}${areaName.isNotEmpty ? ' - $areaName' : ''}) ควรบริโภคในอีก $daysLeft วัน';
    } else {
      message = daysLeft < 0
          ? '${item['item_name']} (ชิ้นที่ ${index + 1}${areaName.isNotEmpty ? ' - $areaName' : ''}) หมดอายุแล้ว ${(-daysLeft)} วัน'
          : '${item['item_name']} (ชิ้นที่ ${index + 1}${areaName.isNotEmpty ? ' - $areaName' : ''}) จะหมดอายุในอีก $daysLeft วัน';
    }
    
    // ถ้าควรแจ้งเตือนแล้ว (ผ่านวันแจ้งเตือนแล้ว) ให้แจ้งทันที
    if (now.isAfter(notifyDate) || now.isAtSameMomentAs(notifyDate)) {
      try {
        await flutterLocalNotificationsPlugin.show(
          itemId + index * 1000, // ใช้ ID ที่แตกต่างกันสำหรับแต่ละชิ้น
          title,
          message,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'expire_immediate_individual_channel',
              'แจ้งเตือนสิ่งของแต่ละชิ้นทันที',
              channelDescription: 'แจ้งเตือนสิ่งของแต่ละชิ้นที่ถึงเวลาแล้ว',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
        );
        
        // บันทึกว่าส่งการแจ้งเตือนแล้ว
        _sentNotifications.add(notificationKey);
        await _saveSentNotifications(); // บันทึกลง SharedPreferences
      } catch (e) {
        // ข้อผิดพลาดในการแสดงการแจ้งเตือน
      }
    } else {
      try {
        final scheduledDate = DateTime(
          notifyDate.year,
          notifyDate.month,
          notifyDate.day,
          9, // 9 AM
          index, // เพิ่มนาทีตาม index เพื่อไม่ให้แจ้งเตือนพร้อมกัน
          0,
        );
        
        await flutterLocalNotificationsPlugin.zonedSchedule(
          itemId + index * 1000, // ใช้ ID ที่แตกต่างกันสำหรับแต่ละชิ้น
          title,
          message,
          tz.TZDateTime.from(scheduledDate, tz.getLocation('Asia/Bangkok')),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'expire_scheduled_individual_channel',
              'แจ้งเตือนสิ่งของแต่ละชิ้นตามกำหนด',
              channelDescription: 'แจ้งเตือนวันหมดอายุสิ่งของแต่ละชิ้นตามที่ตั้งไว้',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        // ข้อผิดพลาดในการตั้งเวลา
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        title: const Text(''),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _build_empty_state()
              : RefreshIndicator(
                  onRefresh: _fetch_notifications,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ..._build_notification_sections(),
                    ],
                  ),
                ),
    );
  }

  // Widget สำหรับแสดงเมื่อไม่มีการแจ้งเตือน
  Widget _build_empty_state() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_outlined,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'ไม่มีการแจ้งเตือน',
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'การแจ้งเตือนจะแสดงที่นี่',
            style: TextStyle(
              fontSize: 18, 
              color: Color.fromARGB(255, 0, 0, 0),
            ),
          ),
        ],
      ),
    );
  }

  // สร้างส่วนการแจ้งเตือนแบบรวม
  List<Widget> _build_notification_sections() {
    // รวมการแจ้งเตือนทั้งหมดเข้าด้วยกัน
    final all_notifications = _notifications.toList();

    List<Widget> sections = [];

    // แสดงการแจ้งเตือนทั้งหมดโดยไม่มีหัวข้อ
    if (all_notifications.isNotEmpty) {
      sections.addAll(
        all_notifications.map((notification) => 
          _build_notification_card(notification)
        ).toList(),
      );
    }

    return sections;
  }

  // Widget การ์ดการแจ้งเตือน
  Widget _build_notification_card(Map<String, dynamic> notification) {
    final is_expired = notification['is_expired'] as bool;
    final is_bbf = notification['is_bbf'] as bool? ?? false;
    
    // กำหนดสีพาสเทลและไอคอนตามประเภท
    Color statusColor;
    Color backgroundColor;
    IconData statusIcon;
    
    if (is_expired) {
      statusColor = Colors.red; // เปลี่ยนเป็นสีแดงชัดเจนสำหรับหมดอายุ
      backgroundColor = is_bbf ? const Color(0xFFFFF5F0) : const Color(0xFFFFF0F5); // พื้นหลังสีครีมอ่อน
      statusIcon = is_bbf ? Icons.schedule : Icons.error; // เปลี่ยนเป็นไอคอนแบบเต็ม
    } else {
      statusColor = is_bbf ? const Color(0xFFD4A574) : const Color(0xFFDDA0DD); // สีทองพาสเทลและม่วงพาสเทล
      backgroundColor = is_bbf ? const Color(0xFFFFFAF0) : const Color(0xFFF8F4FF); // พื้นหลังสีครีมและม่วงอ่อน
      statusIcon = is_bbf ? Icons.schedule_outlined : Icons.warning_outlined;
    }
    
    return GestureDetector(
      onTap: () async {
        final item_data = notification['item_data'];
        if (item_data == null) return;
        
        // เตรียมข้อมูลให้ครบถ้วนสำหรับ ItemDetailPage (เหมือนใน calendar.dart)
        Map<String, dynamic> itemDetailData = {
          // ข้อมูลพื้นฐาน
          'item_id': item_data['item_id'],
          'id': item_data['item_id'], // เพิ่ม id สำรอง
          'name': item_data['item_name'] ?? item_data['name'] ?? '',
          'item_name': item_data['item_name'] ?? item_data['name'] ?? '',
          'quantity': item_data['item_number'] ?? item_data['quantity'] ?? item_data['remaining_quantity'] ?? 1,
          'item_number': item_data['item_number'] ?? item_data['quantity'] ?? 1,
          'remaining_quantity': item_data['remaining_quantity'] ?? item_data['item_number'] ?? item_data['quantity'] ?? 1,
          
          // ข้อมูลหมวดหมู่และที่เก็บ
          'category': item_data['category'] ?? item_data['type_name'] ?? 'ไม่ระบุ',
          'type_name': item_data['type_name'] ?? item_data['category'] ?? 'ไม่ระบุ',
          'storage_location': item_data['storage_location'] ?? item_data['area_name'] ?? 'ไม่ระบุ',
          'area_name': item_data['area_name'] ?? item_data['storage_location'] ?? 'ไม่ระบุ',
          
          // ข้อมูลวันที่
          'item_date': item_data['item_date'],
          'date_type': item_data['date_type'] ?? 'EXP',
          'unit': item_data['date_type'] ?? 'EXP',
          
          // ข้อมูลการแจ้งเตือน
          'item_notification': item_data['item_notification'] ?? item_data['notification_days'] ?? 3,
          'notification_days': item_data['notification_days'] ?? item_data['item_notification'] ?? 3,
          
          // ข้อมูลบาร์โค้ด
          'barcode': item_data['item_barcode'] ?? item_data['barcode'] ?? '',
          'item_barcode': item_data['item_barcode'] ?? item_data['barcode'] ?? '',
          
          // ข้อมูลผู้ใช้และสถานะ
          'user_id': item_data['user_id'],
          'item_status': item_data['item_status'] ?? 'active',
          
          // ข้อมูลรูปภาพ
          'item_img': item_data['item_img_full_url'] ?? item_data['item_img'] ?? null,
          
          // ข้อมูลเพิ่มเติม
          'storage_locations': item_data['storage_locations'] ?? [],
          'item_expire_details': item_data['item_expire_details'] ?? [],
          'used_quantity': item_data['used_quantity'] ?? 0,
          'expired_quantity': item_data['expired_quantity'] ?? 0,
        };
        
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailPage(
              item_data: itemDetailData,
            ),
          ),
        );
        if (result == true) {
          _fetch_notifications(); 
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.transparent, 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE9D5FF).withOpacity(0.7),
            width: 3,
          ),
          // เอา boxShadow ออกเพื่อให้ไม่มีสีเงา
        ),
        child: Row(
          children: [
            // ไอคอนสถานะ
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // ข้อมูลการแจ้งเตือน
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ชื่อสิ่งของ
                  Text(
                    notification['title'],
                    style: const TextStyle(
                      fontSize: 20, // เพิ่มจาก 16 เป็น 20
                      fontWeight: FontWeight.w600,
                      color: Colors.black87, // เปลี่ยนเป็นสีดำเพื่อความชัดเจน
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // รายละเอียด
                  Text(
                    notification['description'],
                    style: TextStyle(
                      fontSize: 16, // เพิ่มจาก 14 เป็น 16
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // แสดงพื้นที่จัดเก็บ (เหมือนใน calendar)
                  if (notification['item_data'] != null)
                    Builder(
                      builder: (context) {
                        final item_data = notification['item_data'];
                        if ((item_data['storage_locations'] != null && (item_data['storage_locations'] as List).isNotEmpty)) {
                          final locations = (item_data['storage_locations'] as List)
                              .map((loc) => (loc is Map) ? (loc['area_name'] ?? '') : '')
                              .where((name) => name.toString().isNotEmpty)
                              .toSet()
                              .join(', ');
                          return Text(
                            'จัดเก็บ: $locations',
                            style: const TextStyle(
                              fontSize: 14, // เพิ่มจาก 12 เป็น 14
                              color: Colors.black87, // เปลี่ยนเป็นสีดำเพื่อความชัดเจน
                            ),
                          );
                        } else {
                          return Text(
                            'จัดเก็บ: ${item_data['storage_location'] ?? item_data['area_name'] ?? 'ไม่ระบุ'}',
                            style: const TextStyle(
                              fontSize: 14, // เพิ่มจาก 12 เป็น 14
                              color: Colors.black87, // เปลี่ยนเป็นสีดำเพื่อความชัดเจน
                            ),
                          );
                        }
                      },
                    ),
                  
                  const SizedBox(height: 2),
                  
                  // วันที่หมดอายุ
                  Text(
                    notification['date'],
                    style: const TextStyle(
                      fontSize: 14, // เพิ่มจาก 12 เป็น 14
                      color: Colors.black87, // เปลี่ยนเป็นสีดำเพื่อความชัดเจน
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}