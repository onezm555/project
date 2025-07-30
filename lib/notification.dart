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

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();


  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _requestNotificationPermission();
    _fetch_notifications();
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
        final bool? granted = await plugin.requestExactAlarmsPermission();
        debugPrint('[NOTI] Exact alarms permission granted: $granted');
      }
    } catch (e) {
      debugPrint('[NOTI] Error requesting exact alarms permission: $e');
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');
    debugPrint('[NOTI] userId: $userId');
    if (userId == null) {
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
      debugPrint('[NOTI] No userId found, abort fetch');
      return;
    }
    final String apiUrl = '${dotenv.env['API_BASE_URL']}/notification_check.php?user_id=$userId&check_only=true';
    debugPrint('[NOTI] Fetching from: $apiUrl');
    try {
      final response = await http.get(Uri.parse(apiUrl));
      debugPrint('[NOTI] API status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('[NOTI] API response: $responseData');
        if (responseData['success'] == true) {
          List<Map<String, dynamic>> notiList = [];
          final now = DateTime.now();
          for (var item in responseData['data']) {
            final expireDate = DateTime.parse(item['item_date']);
            final notifyDays = int.tryParse(item['item_notification'].toString()) ?? 0;
            final notifyDate = expireDate.subtract(Duration(days: notifyDays));
            final daysLeft = expireDate.difference(now).inDays;
            debugPrint('[NOTI] Item: ${item['item_name']} | expire: $expireDate | notifyDays: $notifyDays | notifyDate: $notifyDate | daysLeft: $daysLeft');
            // Schedule local notification
            _scheduleNotification(item, notifyDate, daysLeft);
            if (now.isAfter(notifyDate) && now.isBefore(expireDate.add(const Duration(days: 1)))) {
              // ตรวจสอบประเภทวันที่ (EXP หรือ BBF)
              final dateType = item['date_type']?.toString().toUpperCase() ?? 'EXP';
              final isBBF = dateType == 'BBF';
              
              String description;
              String dateLabel;
              
              if (isBBF) {
                description = daysLeft < 0
                    ? 'เลยวันควรบริโภคแล้ว'
                    : 'ควรบริโภคในอีก ${daysLeft} วัน';
                dateLabel = 'วันควรบริโภคก่อน ${expireDate.day}/${expireDate.month}/${expireDate.year}';
              } else {
                description = daysLeft < 0
                    ? 'หมดอายุแล้ว'
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
                'item_data': item, // เพิ่มข้อมูลดิบของสินค้า
              });
            }
          }
          debugPrint('[NOTI] notiList.length: ${notiList.length}');
          setState(() {
            _notifications = notiList;
            _isLoading = false;
          });
        } else {
          debugPrint('[NOTI] API success==false');
          setState(() {
            _notifications = [];
            _isLoading = false;
          });
        }
      } else {
        debugPrint('[NOTI] API status != 200');
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[NOTI] Exception: $e');
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
    
    debugPrint('[NOTI] _scheduleNotification: itemId=$itemId, notifyDate=$notifyDate, now=$now, daysLeft=$daysLeft, dateType=$dateType');
    
    if (notifyDate.isAfter(now)) {
      try {
        String title = isBBF ? 'สินค้าใกล้ควรบริโภคก่อน' : 'สินค้าใกล้หมดอายุ';
        String message;
        
        if (isBBF) {
          message = daysLeft < 0
              ? '${item['item_name']} เลยวันควรบริโภคแล้ว'
              : '${item['item_name']} ควรบริโภคในอีก $daysLeft วัน';
        } else {
          message = daysLeft < 0
              ? '${item['item_name']} หมดอายุแล้ว'
              : '${item['item_name']} จะหมดอายุในอีก $daysLeft วัน';
        }
        
        await flutterLocalNotificationsPlugin.zonedSchedule(
          itemId,
          title,
          message,
          tz.TZDateTime.from(notifyDate, tz.getLocation('Asia/Bangkok')),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'expire_channel',
              'แจ้งเตือนสินค้า',
              channelDescription: 'แจ้งเตือนวันหมดอายุสินค้า',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
        debugPrint('[NOTI] zonedSchedule success for itemId=$itemId');
      } catch (e) {
        debugPrint('[NOTI] zonedSchedule ERROR for itemId=$itemId: $e');
      }
    } else {
      debugPrint('[NOTI] Not scheduling: notifyDate ($notifyDate) is not after now ($now)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
      floatingActionButton: FloatingActionButton(
        onPressed: _testApiNotification,
        tooltip: 'การแจ้งเตือน',
        backgroundColor: Colors.purple,
        child: const Icon(Icons.api),
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
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'การแจ้งเตือนจะแสดงที่นี่',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // สร้างส่วนการแจ้งเตือนตามประเภท
  List<Widget> _build_notification_sections() {
    final today_notifications = _notifications.where((n) => n['type'] == 'today').toList();
    final stored_notifications = _notifications.where((n) => n['type'] == 'stored').toList();

    List<Widget> sections = [];

    // ส่วนวันนี้
    if (today_notifications.isNotEmpty) {
      sections.add(_build_section_header('วันนี้'));
      sections.addAll(
        today_notifications.map((notification) => 
          _build_notification_card(notification)
        ).toList(),
      );
      sections.add(const SizedBox(height: 24));
    }

    // ส่วนสินค้าที่เก็บ
    if (stored_notifications.isNotEmpty) {
      sections.add(_build_section_header('สินค้าที่เก็บ'));
      sections.addAll(
        stored_notifications.map((notification) => 
          _build_notification_card(notification)
        ).toList(),
      );
    }

    return sections;
  }

  // Widget หัวข้อส่วน
  Widget _build_section_header(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  // Widget การ์ดการแจ้งเตือน
  Widget _build_notification_card(Map<String, dynamic> notification) {
    final is_expired = notification['is_expired'] as bool;
    final is_bbf = notification['is_bbf'] as bool? ?? false;
    
    // กำหนดสีและไอคอนตามประเภท
    Color statusColor;
    Color backgroundColor;
    IconData statusIcon;
    
    if (is_expired) {
      statusColor = is_bbf ? Colors.deepOrange : Colors.red;
      backgroundColor = is_bbf ? Colors.deepOrange.withOpacity(0.1) : Colors.red.withOpacity(0.1);
      statusIcon = is_bbf ? Icons.schedule_outlined : Icons.error_outline;
    } else {
      statusColor = is_bbf ? Colors.amber : Colors.orange;
      backgroundColor = is_bbf ? Colors.amber.withOpacity(0.1) : Colors.orange.withOpacity(0.1);
      statusIcon = is_bbf ? Icons.schedule_outlined : Icons.warning_outlined;
    }
    return GestureDetector(
      onTap: () async {
        // ดึงข้อมูลสินค้าทั้งหมดจาก _notifications หรือ fetch ใหม่จาก API ถ้าต้องการข้อมูลเต็ม
        // ในที่นี้จะลอง fetch ใหม่จาก API เพื่อให้ได้ข้อมูลล่าสุดและครบถ้วน
        SharedPreferences prefs = await SharedPreferences.getInstance();
        final int? userId = prefs.getInt('user_id');
        if (userId == null) return;
        final String apiUrl = '${dotenv.env['API_BASE_URL'] ?? 'http://localhost/project'}/my_items.php?user_id=$userId';
        try {
          final response = await http.get(Uri.parse(apiUrl));
          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);
            if (responseData['success'] == true) {
              // หา item ที่ id ตรงกับ notification['id']
              final item = (responseData['data'] as List).firstWhere(
                (i) => i['item_id'].toString() == notification['id'].toString(),
                orElse: () => null,
              );
              if (item != null) {
                // ส่งข้อมูลครบถ้วนเหมือน index.dart
                Navigator.push(
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
                        'storage_location': item['area_name'] ?? item['storage_location'],
                        'item_date': item['item_date'],
                        'item_img': item['item_img_full_url'],
                      },
                    ),
                  ),
                );
              }
            }
          }
        } catch (e) {
          // ไม่ต้องทำอะไรถ้า error
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
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
                  // ชื่อสินค้า
                  Text(
                    notification['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // รายละเอียด
                  Text(
                    notification['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // วันที่หมดอายุ
                  Text(
                    notification['date'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
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

  // ฟังก์ชันทดสอบการแจ้งเตือนจาก API
  Future<void> _testApiNotification() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');
      
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่พบ User ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      debugPrint('[TEST_API_NOTI] Testing API notification for user: $userId');
      
      final String apiUrl = '${dotenv.env['API_BASE_URL']}/notification_check.php?user_id=$userId&check_only=false';
      debugPrint('[TEST_API_NOTI] API URL: $apiUrl');
      
      final response = await http.get(Uri.parse(apiUrl));
      debugPrint('[TEST_API_NOTI] API Response status: ${response.statusCode}');
      debugPrint('[TEST_API_NOTI] API Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true) {
          final notifications = responseData['data'] as List;
          final summary = responseData['summary'];
          
          // แสดงผลลัพธ์
          String message = 'ผลการทดสอบ API:\n\n';
          message += 'การแจ้งเตือนทั้งหมด: ${summary['total_notifications']}\n';
          message += 'สินค้าหมดอายุแล้ว: ${summary['expired_items']}\n';
          message += 'สินค้าใกล้หมดอายุ: ${summary['expiring_items']}\n\n';
          
          if (notifications.isNotEmpty) {
            message += 'รายการที่ควรได้รับการแจ้งเตือน:\n';
            for (var noti in notifications.take(5)) { // แสดงแค่ 5 รายการแรก
              message += '• ${noti['item_name']} (${noti['notification_message']})\n';
            }
            if (notifications.length > 5) {
              message += '... และอีก ${notifications.length - 5} รายการ\n';
            }
          } else {
            message += 'ไม่มีสินค้าที่ควรได้รับการแจ้งเตือนในขณะนี้';
          }
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('ผลการทดสอบ API'),
              content: SingleChildScrollView(
                child: Text(message),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ปิด'),
                ),
                if (notifications.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _fetch_notifications(); // รีเฟรชข้อมูล
                    },
                    child: const Text('รีเฟรชการแจ้งเตือน'),
                  ),
              ],
            ),
          );
          if (notifications.isNotEmpty) {
            final firstNotification = notifications.first;
            await flutterLocalNotificationsPlugin.show(
              99997,
              'การแจ้งเตือน: ${firstNotification['notification_title']}',
              firstNotification['notification_message'],
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'api_test_channel',
                  'ทดสอบ API แจ้งเตือน',
                  channelDescription: 'ช่องทดสอบการแจ้งเตือนจาก API',
                  importance: Importance.max,
                  priority: Priority.high,
                ),
              ),
            );
          }
          
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('API Error: ${responseData['message'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('HTTP Error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('[TEST_API_NOTI] Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถทดสอบ API ได้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}