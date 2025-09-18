import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({Key? key}) : super(key: key);

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedMonth = 'all'; // เริ่มต้นด้วย 'all' เพื่อแสดงสถิติทั้งหมด
  
  // สถิติข้อมูล
  int _totalItems = 0;
  int _expiredItems = 0;
  int _disposedItems = 0;
  double _expiredChangePercent = 0.0;
  
  List<dynamic> _categoryStats = [];
  List<dynamic> _productStats = []; // เพิ่มสำหรับสิ่งของแยกตามประเภทเฉพาะ

  @override
  void initState() {
    super.initState();
    _selectedMonth = 'all'; // เริ่มต้นด้วยสถิติทั้งหมด
    _loadStatistics();
  }

  String _getCurrentMonth() {
    DateTime now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  bool _isCurrentMonth() {
    return _selectedMonth == _getCurrentMonth();
  }

  // Helper methods สำหรับ parsing ข้อมูล
  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // ลองดึง user_id เป็นทั้ง String และ int แบบ safe
      String? userIdString;
      int? userIdInt;
      String? userId;
      
      try {
        userIdString = prefs.getString('user_id');
      } catch (e) {
        print('getString error in _loadStatistics: $e');
        userIdString = null;
      }
      
      try {
        userIdInt = prefs.getInt('user_id');
      } catch (e) {
        print('getInt error in _loadStatistics: $e');
        userIdInt = null;
      }
      
      if (userIdString != null && userIdString.isNotEmpty) {
        userId = userIdString;
      } else if (userIdInt != null) {
        userId = userIdInt.toString();
      }
      
      if (userId == null || userId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบใหม่';
        });
        return;
      }
      print('User ID String from SharedPreferences: $userIdString');
      print('User ID Int from SharedPreferences: $userIdInt');
      print('Final User ID: $userId');
      print('Selected month: $_selectedMonth');

      final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project/';
      // ตรวจสอบให้แน่ใจว่า baseUrl มี / ท้าย
      final String apiBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      print('Base URL from .env: ${dotenv.env['API_BASE_URL']}');
      print('Final API Base URL: $apiBaseUrl'); // Debug เพิ่ม
      String apiUrl;
      
      if (_selectedMonth == 'all') {
        // สำหรับสถิติทั้งหมด ไม่ส่งพารามิเตอร์ month
        apiUrl = '${apiBaseUrl}get_statistics.php?user_id=$userId';
      } else {
        // สำหรับสถิติรายเดือน
        apiUrl = '${apiBaseUrl}get_statistics.php?user_id=$userId&month=$_selectedMonth';
      }
      
      print('API URL: $apiUrl');
      print('Base URL from .env: ${dotenv.env['API_BASE_URL']}');
      print('Making HTTP GET request...');
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          print('Decoded data: $data');
          
          if (data['success'] == true) {
            setState(() {
              _totalItems = _parseToInt(data['data']['total_items']);
              _expiredItems = _parseToInt(data['data']['expired_items']);
              _disposedItems = _parseToInt(data['data']['disposed_items']);
              _expiredChangePercent = _parseToDouble(data['data']['expired_change_percent']);
              _categoryStats = data['data']['category_breakdown'] ?? [];
              _productStats = data['data']['product_breakdown'] ?? [];
              _isLoading = false;
            });
          } else {
            final errorMessage = data['message']?.toString() ?? 'เกิดข้อผิดพลาดในการโหลดข้อมูล';
            setState(() {
              _isLoading = false;
              _errorMessage = 'Server Error: $errorMessage';
            });
            print('API returned success: false');
            print('Error message: ${data['message']}');
            print('Full response data: $data');
          }
        } catch (jsonError) {
          print('JSON parsing error: $jsonError');
          setState(() {
            _isLoading = false;
            _errorMessage = 'เกิดข้อผิดพลาดในการแปลงข้อมูล: $jsonError';
          });
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        print('Response body: ${response.body}');
        setState(() {
          _isLoading = false;
          _errorMessage = 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ (HTTP ${response.statusCode})';
        });
      }
    } catch (e) {
      print('Exception occurred: $e');
      print('Exception type: ${e.runtimeType}');
      setState(() {
        _isLoading = false;
        _errorMessage = 'เกิดข้อผิดพลาด: $e';
      });
    }
  }

  Future<void> _testWithDifferentUserId() async {
    try {
      print('=== Testing with User ID 1 ===');
      
      final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project/';
      final String apiBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final String testUrl = '${apiBaseUrl}get_statistics.php?user_id=1&month=$_selectedMonth';
      
      print('Test URL with User ID 1: $testUrl');
      
      final response = await http.get(
        Uri.parse(testUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test User ID 1 - HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } catch (e) {
      print('Test with User ID 1 error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test with User ID 1 failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    try {
      print('=== Testing Connection ===');
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // ลองดึง user_id เป็นทั้ง String และ int
      String? userIdString = prefs.getString('user_id');
      int? userIdInt = prefs.getInt('user_id');
      String? userId;
      
      if (userIdString != null && userIdString.isNotEmpty) {
        userId = userIdString;
      } else if (userIdInt != null) {
        userId = userIdInt.toString();
      }
      
      print('User ID String from SharedPreferences: $userIdString');
      print('User ID Int from SharedPreferences: $userIdInt');
      print('Final User ID: $userId');
      print('Selected month: $_selectedMonth');
      print('Base URL from .env: ${dotenv.env['API_BASE_URL']}');
      
      final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project/';
      final String apiBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final String testUrl = '${apiBaseUrl}get_statistics.php?user_id=${userId ?? "1"}&month=$_selectedMonth';
      
      print('Test URL: $testUrl');
      
      final response = await http.get(
        Uri.parse(testUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Test connection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection test failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _changeMonth(int direction) {
    if (_selectedMonth == 'all') {
      // จาก 'all' ไปเดือนปัจจุบัน (ทางซ้าย)
      if (direction == -1) {
        setState(() {
          _selectedMonth = _getCurrentMonth();
        });
        _loadStatistics();
      }
      // ไม่สามารถไปทางขวาจาก 'all' ได้
      return;
    }
    
    DateTime currentDate = DateTime.parse('$_selectedMonth-01');
    DateTime newDate = DateTime(currentDate.year, currentDate.month + direction, 1);
    String newMonth = '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}';
    
    // ตรวจสอบว่าเดือนใหม่ไม่เกินเดือนปัจจุบัน
    DateTime now = DateTime.now();
    String currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    if (newMonth.compareTo(currentMonth) > 0) {
      // หากเดือนใหม่มากกว่าเดือนปัจจุบัน ไม่ให้เปลี่ยน
      return;
    }
    
    setState(() {
      _selectedMonth = newMonth;
    });
    _loadStatistics();
  }

  String _getMonthName(String monthStr) {
    if (monthStr == 'all') {
      return 'สถิติทั้งหมด';
    }
    
    List<String> months = [
      'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
      'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
    ];
    
    List<String> parts = monthStr.split('-');
    int year = int.parse(parts[0]);
    int month = int.parse(parts[1]);
    
    return '${months[month - 1]} $year';
  }

  List<PieChartSectionData> _getPieChartSections() {
    int displayTotal = _disposedItems + _expiredItems;
    if (displayTotal == 0) return [];
    
    List<PieChartSectionData> sections = [];
    
    // เพิ่มส่วนสำหรับ disposed items (ใช้แล้ว)
    if (_disposedItems > 0) {
      sections.add(PieChartSectionData(
        color: const Color(0xFF8B5CF6), // สีม่วง
        value: _disposedItems.toDouble(),
        title: '${((_disposedItems / displayTotal) * 100).toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }
    
    // เพิ่มส่วนสำหรับ expired items (หมดอายุ)
    if (_expiredItems > 0) {
      sections.add(PieChartSectionData(
        color: const Color(0xFFEF4444), // สีแดง
        value: _expiredItems.toDouble(),
        title: '${((_expiredItems / displayTotal) * 100).toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }
    
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'สถิติ',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _loadStatistics,
                            child: const Text('ลองใหม่'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _testConnection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                            child: const Text('ทดสอบการเชื่อมต่อ'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _testWithDifferentUserId,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: const Text('ทดสอบ User ID 1'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : _totalItems == 0
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'ยังไม่พบสถิติการเก็บสิ่งของคุณ',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'เริ่มต้นเพิ่มสิ่งของแรกของคุณเพื่อดูสถิติ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Debug information (แสดงเฉพาะเมื่อมี error)
                      if (_errorMessage.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Debug Information:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Selected Month: $_selectedMonth'),
                              Text('Base URL: ${dotenv.env['API_BASE_URL'] ?? 'Not found in .env'}'),
                              FutureBuilder<String?>(
                                future: SharedPreferences.getInstance().then((prefs) {
                                  String? userIdString = prefs.getString('user_id');
                                  int? userIdInt = prefs.getInt('user_id');
                                  if (userIdString != null && userIdString.isNotEmpty) {
                                    return userIdString;
                                  } else if (userIdInt != null) {
                                    return userIdInt.toString();
                                  }
                                  return null;
                                }),
                                builder: (context, snapshot) {
                                  return Text('User ID: ${snapshot.data ?? 'Loading...'}');
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Month selector
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _selectedMonth == 'all' ? () => _changeMonth(-1) : () => _changeMonth(-1),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Text(
                                _getMonthName(_selectedMonth),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              onPressed: (_selectedMonth == 'all' || _isCurrentMonth()) ? null : () => _changeMonth(1),
                              icon: Icon(
                                Icons.chevron_right,
                                color: (_selectedMonth == 'all' || _isCurrentMonth()) ? Colors.grey[400] : null,
                              ),
                            ),
                            // เพิ่มปุ่มกลับไปสถิติทั้งหมด
                            if (_selectedMonth != 'all')
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedMonth = 'all';
                                  });
                                  _loadStatistics();
                                },
                                icon: const Icon(Icons.home),
                                tooltip: 'กลับไปสถิติทั้งหมด',
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Statistics cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'ทั้งหมด',
                              _totalItems.toString(),
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'ใช้แล้ว',
                              _disposedItems.toString(),  // เปลี่ยนจาก _expiredItems เป็น _disposedItems
                              Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'หมดอายุ',
                              _expiredItems.toString(),   // เปลี่ยนจาก _disposedItems เป็น _expiredItems
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                      
                      // เพิ่มการแสดงเปรียบเทียบกับเดือนก่อน
                      if (_expiredChangePercent != 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _expiredChangePercent >= 0 ? Colors.red[50] : Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _expiredChangePercent >= 0 ? Colors.red[200]! : Colors.green[200]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _expiredChangePercent >= 0 ? Icons.trending_up : Icons.trending_down,
                                color: _expiredChangePercent >= 0 ? Colors.red : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'รายการหมดอายุเดือนนี้ ${_expiredChangePercent >= 0 ? "เพิ่มขึ้น" : "ลดลง"} ${_expiredChangePercent.abs().toStringAsFixed(1)}% เทียบกับเดือนที่แล้ว',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _expiredChangePercent >= 0 ? Colors.red[700] : Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Pie Chart
                      if ((_disposedItems + _expiredItems) > 0)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 200,
                                child: PieChart(
                                  PieChartData(
                                    sections: _getPieChartSections(),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildLegendItem('ใช้แล้ว', const Color(0xFF8B5CF6)),
                                  _buildLegendItem('หมดอายุ', const Color(0xFFEF4444)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                      
                      // Category breakdown
                      if (_categoryStats.isNotEmpty) ...[
                        const Text(
                          'สถิติตามหมวดหมู่',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              ..._categoryStats.map((category) => 
                                _buildCategoryItem(category)
                              ).toList(),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Product breakdown (สิ่งของแยกตามประเภทเฉพาะ)
                      if (_productStats.isNotEmpty) ...[
                        const Text(
                          'สถิติตามประเภทสิ่งของ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              ..._productStats.map((product) => 
                                _buildProductItem(product)
                              ).toList(),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(dynamic category) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.orange[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category['category']?.toString() ?? 'ไม่ระบุหมวดหมู่',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Column(
                children: [
                  Text(
                    'ใช้หมด',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple[200]!),
                    ),
                    child: Text(
                      '${_parseToInt(category['disposed_count'])}',  // เปลี่ยนจาก expired_count เป็น disposed_count
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Text(
                    'หมดอายุ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      '${_parseToInt(category['expired_count'])}',  // เปลี่ยนจาก disposed_count เป็น expired_count
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(dynamic product) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    product['item_category']?.toString() ?? 'ไม่ระบุประเภท',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Column(
                children: [
                  Text(
                    'ใช้หมด',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple[200]!),
                    ),
                    child: Text(
                      '${_parseToInt(product['disposed_count'])}',  // เปลี่ยนจาก expired_count เป็น disposed_count
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Text(
                    'หมดอายุ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      '${_parseToInt(product['expired_count'])}',  // เปลี่ยนจาก disposed_count เป็น expired_count
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
