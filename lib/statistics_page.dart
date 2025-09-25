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
  String _selectedMonth = 'all';
  
  // สถิติข้อมูล
  int _totalItems = 0;
  int _expiredItems = 0;
  int _disposedItems = 0;

  
  double _expiredChangePercent = 0.0;
  
  List<dynamic> _categoryStats = [];
  List<dynamic> _productStats = [];
  List<String> _availableMonths = [];

  @override
  void initState() {
    super.initState();
    _selectedMonth = 'all';
    print('StatisticsPage initState - starting with month: $_selectedMonth');
    _loadStatistics();
  }

  String _getCurrentMonth() {
    DateTime now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  void _addCurrentMonthForTesting() {
    String currentMonth = _getCurrentMonth();
    if (!_availableMonths.contains(currentMonth)) {
      setState(() {
        _availableMonths.add(currentMonth);
        _availableMonths.sort((a, b) => b.compareTo(a));
      });
      print('Added current month for testing: $currentMonth');
      print('Available months after addition: $_availableMonths');
    }
  }

  bool _canMovePrevious() {
    if (_selectedMonth == 'all') {
      return _availableMonths.isNotEmpty;
    }
    if (_availableMonths.isEmpty) return false;
    
    List<String> sortedMonths = List.from(_availableMonths);
    sortedMonths.sort((a, b) => b.compareTo(a));
    int currentIndex = sortedMonths.indexOf(_selectedMonth);
    bool canMove = currentIndex >= 0 && currentIndex < sortedMonths.length - 1;
    
    print('_canMovePrevious - selectedMonth: $_selectedMonth, currentIndex: $currentIndex, canMove: $canMove, sortedMonths: $sortedMonths');
    return canMove;
  }

  bool _canMoveNext() {
    if (_selectedMonth == 'all') return false;
    if (_availableMonths.isEmpty) return false;
    
    List<String> sortedMonths = List.from(_availableMonths);
    sortedMonths.sort((a, b) => b.compareTo(a));
    int currentIndex = sortedMonths.indexOf(_selectedMonth);
    bool canMove = currentIndex > 0 || currentIndex == 0;
    
    print('_canMoveNext - selectedMonth: $_selectedMonth, currentIndex: $currentIndex, canMove: $canMove, sortedMonths: $sortedMonths');
    return canMove;
  }

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

      final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project/';
      final String apiBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      String apiUrl;
      
      if (_selectedMonth == 'all') {
        apiUrl = '${apiBaseUrl}get_statistics.php?user_id=$userId';
      } else {
        apiUrl = '${apiBaseUrl}get_statistics.php?user_id=$userId&month=$_selectedMonth';
      }
      
      print('API URL: $apiUrl');
      
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
          
          if (data['success'] == true) {
            setState(() {
              _totalItems = _parseToInt(data['data']['total_items']);
              _expiredItems = _parseToInt(data['data']['expired_items']);
              _disposedItems = _parseToInt(data['data']['disposed_items']);
              _expiredChangePercent = _parseToDouble(data['data']['expired_change_percent']);
              _categoryStats = data['data']['category_breakdown'] ?? [];
              _productStats = data['data']['product_breakdown'] ?? [];
              _availableMonths = (data['data']['available_months'] as List?)?.cast<String>() ?? [];
              _isLoading = false;
            });
            print('Statistics loaded successfully');
            print('Total items: $_totalItems');
            print('Available months: $_availableMonths');
            print('Current selected month: $_selectedMonth');
          } else {
            final errorMessage = data['message']?.toString() ?? 'เกิดข้อผิดพลาดในการโหลดข้อมูล';
            setState(() {
              _isLoading = false;
              _errorMessage = 'Server Error: $errorMessage';
            });
          }
        } catch (jsonError) {
          print('JSON parsing error: $jsonError');
          setState(() {
            _isLoading = false;
            _errorMessage = 'เกิดข้อผิดพลาดในการแปลงข้อมูล: $jsonError';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ (HTTP ${response.statusCode})';
        });
      }
    } catch (e) {
      print('Exception occurred: $e');
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
      
      final response = await http.get(
        Uri.parse(testUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test User ID 1 - HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } catch (e) {
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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      String? userIdString = prefs.getString('user_id');
      int? userIdInt = prefs.getInt('user_id');
      String? userId;
      
      if (userIdString != null && userIdString.isNotEmpty) {
        userId = userIdString;
      } else if (userIdInt != null) {
        userId = userIdInt.toString();
      }
      
      final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project/';
      final String apiBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final String testUrl = '${apiBaseUrl}get_statistics.php?user_id=${userId ?? "1"}&month=$_selectedMonth';
      
      final response = await http.get(
        Uri.parse(testUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
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
    print('_changeMonth called with direction: $direction (${direction == -1 ? "Previous/Older" : "Next/Newer"})');
    print('Current _selectedMonth: $_selectedMonth');
    print('Available months: $_availableMonths');
    
    if (_selectedMonth == 'all') {
      if (direction == -1 && _availableMonths.isNotEmpty) {
        List<String> sortedMonths = List.from(_availableMonths);
        sortedMonths.sort((a, b) => b.compareTo(a));
        print('Moving from "all" to latest month: ${sortedMonths.first}');
        setState(() {
          _selectedMonth = sortedMonths.first;
        });
        _loadStatistics();
      }
      return;
    }
    
    if (_availableMonths.isEmpty) {
      print('No available months, returning early');
      return;
    }
    
    List<String> sortedMonths = List.from(_availableMonths);
    sortedMonths.sort((a, b) => b.compareTo(a));
    
    int currentIndex = sortedMonths.indexOf(_selectedMonth);
    print('Current index: $currentIndex in sorted months: $sortedMonths');
    
    if (currentIndex == -1) {
      print('Current month not found in available months');
      setState(() {
        _selectedMonth = 'all';
      });
      _loadStatistics();
      return;
    }
    
    int newIndex;
    if (direction == -1) {
      newIndex = currentIndex + 1;
    } else {
      newIndex = currentIndex - 1;
    }
    
    print('New index would be: $newIndex (range: 0 to ${sortedMonths.length - 1})');
    
    if (newIndex >= 0 && newIndex < sortedMonths.length) {
      String newMonth = sortedMonths[newIndex];
      print('Moving to month: $newMonth (${direction == -1 ? "older" : "newer"} than $_selectedMonth)');
      setState(() {
        _selectedMonth = newMonth;
      });
      _loadStatistics();
    } else {
      print('New index out of bounds - newIndex: $newIndex, length: ${sortedMonths.length}');
      if (direction == 1 && newIndex < 0) {
        print('Going back to "all" statistics');
        setState(() {
          _selectedMonth = 'all';
        });
        _loadStatistics();
      }
    }
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
    
    if (_disposedItems > 0) {
      sections.add(PieChartSectionData(
        color: const Color(0xFF8B5CF6),
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
    
    if (_expiredItems > 0) {
      sections.add(PieChartSectionData(
        color: const Color(0xFFEF4444),
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
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: _loadStatistics,
                            child: const Text('ลองใหม่'),
                          ),
                          ElevatedButton(
                            onPressed: _testConnection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                            child: const Text('ทดสอบการเชื่อมต่อ'),
                          ),
                          ElevatedButton(
                            onPressed: _testWithDifferentUserId,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: const Text('ทดสอบ User ID 1'),
                          ),
                          ElevatedButton(
                            onPressed: _addCurrentMonthForTesting,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('เพิ่มเดือนปัจจุบัน'),
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
                            _selectedMonth == 'all' 
                                ? 'ยังไม่พบสถิติการเก็บสิ่งของคุณ'
                                : 'ไม่มีข้อมูลในเดือน${_getMonthName(_selectedMonth).replaceAll(' ', ' ')}',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedMonth == 'all'
                                ? 'เริ่มต้นเพิ่มสิ่งของแรกของคุณเพื่อดูสถิติ'
                                : 'ลองเลือกเดือนอื่นหรือกลับไปดูสถิติทั้งหมด',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_selectedMonth != 'all') ...[
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedMonth = 'all';
                                });
                                _loadStatistics();
                              },
                              child: const Text('กลับไปสถิติทั้งหมด'),
                            ),
                          ],
                        ],
                      ),
                    )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              onPressed: _canMovePrevious() ? () {
                                print('Previous button pressed - current month: $_selectedMonth');
                                _changeMonth(-1);
                              } : null,
                              icon: Icon(
                                Icons.chevron_left,
                                color: _canMovePrevious() ? Colors.blue[600] : Colors.grey[400],
                              ),
                              tooltip: _canMovePrevious() ? 'เดือนก่อนหน้า (เก่ากว่า)' : 'ไม่มีเดือนก่อนหน้า',
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
                              onPressed: _canMoveNext() ? () {
                                print('Next button pressed - current month: $_selectedMonth');
                                _changeMonth(1);
                              } : null,
                              icon: Icon(
                                Icons.chevron_right,
                                color: _canMoveNext() ? Colors.blue[600] : Colors.grey[400],
                              ),
                              tooltip: _canMoveNext() ? (_availableMonths.isNotEmpty && _selectedMonth == _availableMonths.reduce((a, b) => a.compareTo(b) > 0 ? a : b) ? 'กลับไปสถิติทั้งหมด' : 'เดือนถัดไป (ใหม่กว่า)') : 'ไม่มีเดือนถัดไป',
                            ),
                            if (_selectedMonth != 'all')
                              IconButton(
                                onPressed: () {
                                  print('Home button pressed - going back to all statistics');
                                  setState(() {
                                    _selectedMonth = 'all';
                                  });
                                  _loadStatistics();
                                },
                                icon: const Icon(Icons.home, color: Colors.green),
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
                              _disposedItems.toString(),
                              Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'หมดอายุ',
                              _expiredItems.toString(),
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                      
                      // Pie Chart
                      if ((_disposedItems + _expiredItems) > 0) ...[
                        const SizedBox(height: 24),
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
                      ],
                      
                      // Category breakdown
                      if (_categoryStats.isNotEmpty) ...[
                        const SizedBox(height: 24),
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
                      
                      // Product breakdown
                      if (_productStats.isNotEmpty) ...[
                        const SizedBox(height: 24),
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
                      '${_parseToInt(category['disposed_count'])}',
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
                      '${_parseToInt(category['expired_count'])}',
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
                      '${_parseToInt(product['disposed_count'])}',
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
                      '${_parseToInt(product['expired_count'])}',
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