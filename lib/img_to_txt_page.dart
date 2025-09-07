import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;

class ImgToTxtPage extends StatefulWidget {
  const ImgToTxtPage({Key? key}) : super(key: key);

  @override
  State<ImgToTxtPage> createState() => _ImgToTxtPageState();
}

class _ImgToTxtPageState extends State<ImgToTxtPage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  String _extractedText = '';
  
  // ตั้งค่า Google Cloud Vision API
  static const String _apiKey = 'AIzaSyDyDMv_6fb-v847tb213iDEr-ts5a0e3go'; //
  static const String _apiUrl = 'https://vision.googleapis.com/v1/images:annotate?key=$_apiKey';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // ขอสิทธิ์เข้าถึงกล้อง
    final cameraStatus = await Permission.camera.request();
    
    if (cameraStatus.isGranted) {
      try {
        // รับรายการกล้องที่มีอยู่
        _cameras = await availableCameras();
        
        if (_cameras!.isNotEmpty) {
          // สร้าง CameraController สำหรับกล้องหลัง
          _cameraController = CameraController(
            _cameras![0], // กล้องหลัง
            ResolutionPreset.high,
          );

          // เริ่มต้นกล้อง
          await _cameraController!.initialize();
          
          if (mounted) {
            setState(() {
              _isCameraInitialized = true;
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        print('Error initializing camera: $e');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        setState(() {
          _isProcessing = true;
        });

        final XFile image = await _cameraController!.takePicture();
        
        // อ่านไฟล์รูปภาพ
        final File imageFile = File(image.path);
        final Uint8List imageBytes = await imageFile.readAsBytes();
        
        // ตัดรูปให้เหลือเฉพาะส่วนในกรอบ
        final Uint8List croppedImageBytes = await _cropImageToFrame(imageBytes);

        // ส่งไปยัง Google Cloud Vision API
        final String extractedText = await _extractTextFromImage(croppedImageBytes);

        setState(() {
          _extractedText = extractedText;
          _isProcessing = false;
        });

        // ส่งค่ากลับไปยังหน้าก่อนหน้าโดยไม่ต้อง preview หรือ dialog
        if (extractedText.isNotEmpty && Navigator.canPop(context)) {
          Navigator.pop(context, extractedText);
        }
        
      } catch (e) {
        print('Error processing image: $e');
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Uint8List> _cropImageToFrame(Uint8List imageBytes) async {
    // แปลงภาพเป็น Image object
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) throw Exception('ไม่สามารถอ่านภาพได้');
    
    // คำนวณขนาดและตำแหน่งของกรอบบนภาพจริง
    // สมมติว่ากรอบมีขนาด 280x200 และอยู่ตรงกลางหน้าจอ
    final double frameWidth = 280;
    final double frameHeight = 200;
    
    // คำนวณอัตราส่วนการปรับขนาด
    final double imageAspectRatio = originalImage.width / originalImage.height;
    final double screenAspectRatio = _cameraController!.value.aspectRatio;
    
    // คำนวณตำแหน่งและขนาดที่จะตัด
    double cropX, cropY, cropWidth, cropHeight;
    
    if (imageAspectRatio > screenAspectRatio) {
      // ภาพกว้างกว่าหน้าจอ
      cropHeight = originalImage.height.toDouble();
      cropWidth = cropHeight * screenAspectRatio;
      cropX = (originalImage.width - cropWidth) / 2;
      cropY = 0;
    } else {
      // ภาพสูงกว่าหน้าจอ
      cropWidth = originalImage.width.toDouble();
      cropHeight = cropWidth / screenAspectRatio;
      cropX = 0;
      cropY = (originalImage.height - cropHeight) / 2;
    }
    
    // คำนวณตำแหน่งกรอบบนภาพ
    final double scaleX = cropWidth / MediaQuery.of(context).size.width;
    final double scaleY = cropHeight / MediaQuery.of(context).size.height;
    
    final double frameCenterX = MediaQuery.of(context).size.width / 2;
    final double frameCenterY = MediaQuery.of(context).size.height / 2;
    
    final double frameLeft = (frameCenterX - frameWidth / 2) * scaleX + cropX;
    final double frameTop = (frameCenterY - frameHeight / 2) * scaleY + cropY;
    final double frameWidthScaled = frameWidth * scaleX;
    final double frameHeightScaled = frameHeight * scaleY;
    
    // ตัดภาพตามกรอบ
    img.Image croppedImage = img.copyCrop(
      originalImage,
      x: frameLeft.toInt(),
      y: frameTop.toInt(),
      width: frameWidthScaled.toInt(),
      height: frameHeightScaled.toInt(),
    );
    
    // แปลงกลับเป็น bytes
    return Uint8List.fromList(img.encodeJpg(croppedImage, quality: 90));
  }

  Future<String> _extractTextFromImage(Uint8List imageBytes) async {
    try {
      // แปลงภาพเป็น base64
      final String base64Image = base64Encode(imageBytes);
      
      // สร้าง request body สำหรับ Google Cloud Vision API
      final Map<String, dynamic> requestBody = {
        'requests': [
          {
            'image': {
              'content': base64Image,
            },
            'features': [
              {
                'type': 'TEXT_DETECTION',
                'maxResults': 1,
              }
            ],
          }
        ],
      };
      
      // ส่ง request ไปยัง API
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      // DEBUG: print response.body
      print('Google Vision API response: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['responses'] != null &&
            responseData['responses'].isNotEmpty &&
            responseData['responses'][0]['textAnnotations'] != null) {

          // ดึงข้อความที่สแกนได้และแปลงให้เป็นแถวเดียว
          final String detectedText = responseData['responses'][0]['textAnnotations'][0]['description'] ?? '';
          final String singleLineText = detectedText.replaceAll('\n', '').trim();
          return singleLineText;
        } else {
          return 'ไม่พบข้อความในภาพ';
        }
      } else {
        throw Exception('API Error: \\${response.statusCode} - \\${response.body}');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ API: $e');
    }
  }

  void _showResultDialog(String text) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ข้อความที่สแกนได้'),
          content: SingleChildScrollView(
            child: SelectableText(
              text.isEmpty ? 'ไม่พบข้อความ' : text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ปิด'),
            ),
            if (text.isNotEmpty)
              TextButton(
                onPressed: () {
                  // คัดลอกข้อความไปยัง clipboard
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('คัดลอกข้อความแล้ว'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('คัดลอก'),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'แปลงรูปเป็นข้อความ',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : !_isCameraInitialized
              ? const Center(
                  child: Text(
                    'ไม่สามารถเข้าถึงกล้องได้\nกรุณาอนุญาตการใช้งานกล้อง',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : Stack(
                  children: [
                    // Camera Preview
                    Positioned.fill(
                      child: AspectRatio(
                        aspectRatio: _cameraController!.value.aspectRatio,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                    
                    // Overlay สำหรับกรอบเลือกพื้นที่
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                        ),
                        child: Center(
                          child: Container(
                            width: 280,
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // กรอบมุมสำหรับทำให้ดูเป็น scanner
                    Positioned.fill(
                      child: Center(
                        child: SizedBox(
                          width: 280,
                          height: 200,
                          child: Stack(
                            children: [
                              // มุมซ้ายบน
                              Positioned(
                                top: -2,
                                left: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Colors.green, width: 4),
                                      left: BorderSide(color: Colors.green, width: 4),
                                    ),
                                  ),
                                ),
                              ),
                              // มุมขวาบน
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Colors.green, width: 4),
                                      right: BorderSide(color: Colors.green, width: 4),
                                    ),
                                  ),
                                ),
                              ),
                              // มุมซ้ายล่าง
                              Positioned(
                                bottom: -2,
                                left: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: Colors.green, width: 4),
                                      left: BorderSide(color: Colors.green, width: 4),
                                    ),
                                  ),
                                ),
                              ),
                              // มุมขวาล่าง
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: Colors.green, width: 4),
                                      right: BorderSide(color: Colors.green, width: 4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // ข้อความแนะนำ
                    Positioned(
                      top: 100,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Text(
                          'วางข้อความที่ต้องการแปลงภายในกรอบ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    
                    // Loading overlay เมื่อกำลังประมวลผล
                    if (_isProcessing)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.7),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                                SizedBox(height: 20),
                                Text(
                                  'กำลังสแกนข้อความ...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    
                    // ปุ่มถ่ายรูปด้านล่าง
                    Positioned(
                      bottom: 50,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _isProcessing ? null : _takePicture,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isProcessing ? Colors.grey : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: _isProcessing
                                ? const CircularProgressIndicator(
                                    color: Colors.black,
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    color: Colors.black,
                                    size: 35,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    
                    // ปุ่มสลับกล้อง (หากมีกล้องหน้า)
                    if (_cameras != null && _cameras!.length > 1)
                      Positioned(
                        top: 100,
                        right: 20,
                        child: GestureDetector(
                          onTap: _switchCamera,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.5),
                            ),
                            child: const Icon(
                              Icons.flip_camera_ios,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras != null && _cameras!.length > 1) {
      // หากำลังใช้กล้องหลัง ให้สลับเป็นกล้องหน้า และในทางกลับกัน
      final newCameraIndex = _cameraController!.description == _cameras![0] ? 1 : 0;
      
      await _cameraController!.dispose();
      
      _cameraController = CameraController(
        _cameras![newCameraIndex],
        ResolutionPreset.high,
      );
      
      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {});
      }
    }
  }
}