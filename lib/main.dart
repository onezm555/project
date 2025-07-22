import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login.dart';
import 'main_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'barcode_scanner_page.dart';
import 'img_to_txt_page.dart';
import 'package:camera/camera.dart'; // เพิ่ม import นี้

// Global variable เพื่อเก็บรายชื่อกล้องที่ใช้ได้
List<CameraDescription> cameras = [];

Future<void> main() async {
  // ตรวจสอบให้แน่ใจว่า Flutter engine เริ่มต้นแล้ว
  WidgetsFlutterBinding.ensureInitialized();

  // โหลด .env file
  await dotenv.load(fileName: ".env");

  // เริ่มต้นกล้องทั้งหมดที่นี่
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error initializing cameras: ${e.code}\nError Message: ${e.description}');
    // คุณอาจต้องการจัดการข้อผิดพลาดนี้ เช่น แสดงข้อความแจ้งเตือนผู้ใช้
  }

  // ตรวจสอบสถานะล็อกอิน
  SharedPreferences prefs = await SharedPreferences.getInstance();
  final int? userId = prefs.getInt('user_id');

  runApp(MyApp(isLoggedIn: userId != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
        ),
        useMaterial3: true,
      ),
      home: isLoggedIn ? const MainLayout() : const LoginPage(),
      routes: {
        '/barcode_scanner': (context) => const BarcodeScannerPage(),
        '/img_to_txt': (context) => const ImgToTxtPage(),
      },
    );
  }
}