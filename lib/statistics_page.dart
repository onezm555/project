import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({Key? key}) : super(key: key);

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
    with TickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _statistics = {
    'total_items': 0,
    'expired_items': 0,
    'disposed_items': 0,
    'active_items': 0,
  };
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _pieAnimationController;
  late AnimationController _countAnimationController;
  late Animation<double> _pieAnimation;
  late Animation<double> _countAnimation;

  @override
  void initState() {
    super.initState();
    _pieAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _countAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pieAnimation = CurvedAnimation(
      parent: _pieAnimationController,
      curve: Curves.easeInOutCubic,
    );
    _countAnimation = CurvedAnimation(
      parent: _countAnimationController,
      curve: Curves.easeOutCubic,
    );
    _loadStatistics();
  }

  @override
  void dispose() {
    _pieAnimationController.dispose();
    _countAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      
      if (userId == null) {
        setState(() {
          _errorMessage = 'ไม่พบข้อมูลผู้ใช้';
          _isLoading = false;
        });
        return;
      }

      await dotenv.load();
      String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost/project/';
      
      String yearMonth = DateFormat('yyyy-MM').format(_selectedDate);
      
      final response = await http.get(
        Uri.parse('${baseUrl}get_statistics.php?user_id=$userId&month=$yearMonth'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _statistics = data['data'];
            _isLoading = false;
          });
          _startAnimations();
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'เกิดข้อผิดพลาด';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด: $e';
        _isLoading = false;
      });
    }
  }

  void _startAnimations() {
    _pieAnimationController.reset();
    _countAnimationController.reset();
    _pieAnimationController.forward();
    _countAnimationController.forward();
  }

  void _changeMonth(int direction) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + direction,
        1,
      );
    });
    _loadStatistics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'สถิติ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF6366F1),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'กำลังโหลดข้อมูล...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStatistics,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildMonthNavigator(),
                        const SizedBox(height: 24),
                        _buildStatisticsCards(),
                        const SizedBox(height: 24),
                        _buildPieChart(),
                        const SizedBox(height: 24),
                        _buildDetailCards(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMonthNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left, size: 28),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
              foregroundColor: const Color(0xFF6366F1),
            ),
          ),
          Text(
            DateFormat('MMMM yyyy', 'th').format(_selectedDate),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right, size: 28),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
              foregroundColor: const Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildStatisticsCards() {
    int totalItems = int.tryParse(_statistics['total_items']?.toString() ?? '') ?? 0;
    int expiredItems = int.tryParse(_statistics['expired_items']?.toString() ?? '') ?? 0;
    int disposedItems = int.tryParse(_statistics['disposed_items']?.toString() ?? '') ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'ทั้งหมด',
            totalItems.toString(),
            Icons.inventory_2_outlined,
            const Color(0xFF6366F1),
            0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'หมดอายุ',
            expiredItems.toString(),
            Icons.schedule_outlined,
            const Color(0xFFEF4444),
            1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'ใช้หมดแล้ว',
            disposedItems.toString(),
            Icons.delete_outline,
            const Color(0xFF10B981),
            2,
          ),
        ),
      ],
    );
  }

Widget _buildStatCard(String title, String value, IconData icon, Color color, int index) {
    return AnimatedBuilder(
      animation: _countAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _countAnimation.value)),
          child: Opacity(
            opacity: _countAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _countAnimation,
                    builder: (context, child) {
                      // Safely parse the value to an int.
                      // Use 0 as a fallback if parsing fails.
                      int parsedValue = int.tryParse(value) ?? 0;
                      int animatedValue = (parsedValue * _countAnimation.value).round();
                      return Text(
                        animatedValue.toString(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPieChart() {
    int expiredItems = int.tryParse(_statistics['expired_items']?.toString() ?? '') ?? 0;
    int disposedItems = int.tryParse(_statistics['disposed_items']?.toString() ?? '') ?? 0;
    int activeItems = int.tryParse(_statistics['active_items']?.toString() ?? '') ?? 0;
    int totalItems = expiredItems + disposedItems + activeItems;

    if (totalItems == 0) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 64,
              color: Color(0xFFD1D5DB),
            ),
            SizedBox(height: 16),
            Text(
              'ไม่มีข้อมูลในเดือนนี้',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'สัดส่วนสถานะของไอเทม',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: _pieAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(200, 200),
                  painter: PieChartPainter(
                    expiredItems: expiredItems,
                    disposedItems: disposedItems,
                    activeItems: activeItems,
                    animationValue: _pieAnimation.value,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        _buildLegendItem('หมดอายุแล้ว', const Color(0xFFEF4444)),
        const SizedBox(height: 8),
        _buildLegendItem('ใช้หมดแล้ว', const Color(0xFF10B981)),
        const SizedBox(height: 8),
        _buildLegendItem('ยังใช้ได้', const Color(0xFF6366F1)),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCards() {
    int expiredItems = int.tryParse(_statistics['expired_items']?.toString() ?? '') ?? 0;
    int disposedItems = int.tryParse(_statistics['disposed_items']?.toString() ?? '') ?? 0;
    int totalItems = int.tryParse(_statistics['total_items']?.toString() ?? '') ?? 0;

    double expiredPercent = totalItems > 0 ? (expiredItems / totalItems) * 100 : 0;
    double disposedPercent = totalItems > 0 ? (disposedItems / totalItems) * 100 : 0;

    return Column(
      children: [
        _buildDetailCard(
          'ของที่หมดอายุ',
          '$expiredItems รายการ',
          '${expiredPercent.toStringAsFixed(1)}% ของทั้งหมด',
          Icons.schedule,
          const Color(0xFFEF4444),
          expiredPercent / 100,
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          'ของที่ใช้หมดแล้ว',
          '$disposedItems รายการ',
          '${disposedPercent.toStringAsFixed(1)}% ของทั้งหมด',
          Icons.check_circle,
          const Color(0xFF10B981),
          disposedPercent / 100,
        ),
      ],
    );
  }

  Widget _buildDetailCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    double progress,
  ) {
    return AnimatedBuilder(
      animation: _countAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _countAnimation.value)),
          child: Opacity(
            opacity: _countAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress * _countAnimation.value,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class PieChartPainter extends CustomPainter {
  final int expiredItems;
  final int disposedItems;
  final int activeItems;
  final double animationValue;

  PieChartPainter({
    required this.expiredItems,
    required this.disposedItems,
    required this.activeItems,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.8;
    
    final total = expiredItems + disposedItems + activeItems;
    if (total == 0) return;

    double startAngle = -math.pi / 2; // เริ่มจากด้านบน

    // วาด expired items
    if (expiredItems > 0) {
      final sweepAngle = (expiredItems / total) * 2 * math.pi * animationValue;
      final paint = Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle / animationValue * animationValue;
    }

    // วาด disposed items
    if (disposedItems > 0) {
      final sweepAngle = (disposedItems / total) * 2 * math.pi * animationValue;
      final paint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle / animationValue * animationValue;
    }

    // วาด active items
    if (activeItems > 0) {
      final sweepAngle = (activeItems / total) * 2 * math.pi * animationValue;
      final paint = Paint()
        ..color = const Color(0xFF6366F1)
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
    }

    // วาดวงกลมกลางเพื่อให้ดูเป็น donut chart
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius * 0.5, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}