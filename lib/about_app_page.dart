import 'package:flutter/material.dart';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เกี่ยวกับแอปพลิเคชัน'),
        backgroundColor: const Color(0xFFF8BBD9), 
        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
        toolbarTextStyle: const TextStyle(fontSize: 24),
        titleTextStyle: const TextStyle(
          fontSize: 24, 
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 0, 0, 0), 
        ),
        elevation: 8,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFFFF5F8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE8F5E8), 
                          const Color(0xFFF0F8FF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.schedule,
                      size: 80,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ระบบเตือนวันหมดอายุ',
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A4A4A),
                    ),
                  ),
                  const SizedBox(height: 8),

                ],
              ),
            ),
            const SizedBox(height: 32),

            _buildSection(
              title: 'เกี่ยวกับแอปพลิเคชัน',
              icon: Icons.info_outline,
              iconColor: const Color(0xFFFFB6C1),
              bgColor: const Color(0xFFFFF0F5), 
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'แอปพลิเคชันสำหรับบันทึกและติดตามสิ่งของต่าง ๆ พร้อมการแจ้งเตือนวันหมดอายุ ช่วยให้คุณไม่พลาดการใช้สิ่งของก่อนที่จะหมดอายุ และจัดการสิ่งของในบ้านได้อย่างมีประสิทธิภาพ',
                    style: TextStyle(fontSize: 18, height: 1.5, color: Color(0xFF4A4A4A)), 
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE6E6FA),
                          const Color(0xFFF0F8FF), 
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD8BFD8)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Color(0xFF9370DB)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'ไม่ต้องกังวลเรื่องของหมดอายุอีกต่อไป แอปจะเตือนคุณล่วงหน้า!',
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4A4A4A), 
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSection(
              title: 'ฟีเจอร์หลัก',
              icon: Icons.star_outline,
              iconColor: const Color(0xFFFFDBA4),
              bgColor: const Color(0xFFFFFAF0),
              content: Column(
                children: [
                  _buildFeatureItem(
                    icon: Icons.add_circle_outline,
                    iconColor: const Color(0xFF98FB98),
                    title: 'บันทึกสิ่งของ',
                    description: 'เพิ่มรายการสิ่งของพร้อมวันหมดอายุ รูปภาพ และรายละเอียด',
                  ),
                  _buildFeatureItem(
                    icon: Icons.qr_code_scanner,
                    iconColor: const Color(0xFFADD8E6),
                    title: 'สแกนบาร์โค้ด',
                    description: 'สแกนบาร์โค้ดเพื่อเพิ่มข้อมูลสิ่งของอัตโนมัติ ประหยัดเวลา',
                  ),
                  _buildFeatureItem(
                    icon: Icons.notification_important_outlined,
                    iconColor: const Color(0xFFFFB6C1),
                    title: 'แจ้งเตือนวันหมดอายุ',
                    description: 'รับการแจ้งเตือนล่วงหน้าก่อนสิ่งของจะหมดอายุ',
                  ),
                  _buildFeatureItem(
                    icon: Icons.location_on_outlined,
                    iconColor: const Color(0xFFDDA0DD), 
                    title: 'จัดเก็บหลายพื้นที่',
                    description: 'แบ่งสิ่งของเก็บในหลายพื้นที่ เช่น ตู้เย็น ห้องเก็บของ',
                  ),
                  _buildFeatureItem(
                    icon: Icons.calendar_view_week_outlined,
                    iconColor: const Color(0xFFF0E68C), 
                    title: 'ดูรายการที่หมดอายุ',
                    description: 'ตรวจสอบรายการสิ่งของที่กำลังจะหมดอายุหรือหมดอายุแล้ว',
                  ),
                  _buildFeatureItem(
                    icon: Icons.camera_alt_outlined,
                    iconColor: const Color(0xFFAFEEEE), 
                    title: 'แปลงรูปเป็นข้อความ',
                    description: 'ใช้ AI อ่านข้อความจากรูปภาพเพื่อบันทึกข้อมูลได้รวดเร็ว',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSection(
              title: 'วิธีการใช้งาน',
              icon: Icons.help_outline,
              iconColor: const Color(0xFFFFA07A), 
              bgColor: const Color(0xFFFFF8DC), 
              content: Column(
                children: [
                  _buildStepItem(1, 'เพิ่มพื้นที่จัดเก็บ', 'สร้างพื้นที่ต่าง ๆ เช่น ตู้เย็น ห้องเก็บของ ห้องครัว', const Color(0xFF98FB98)),
                  _buildStepItem(2, 'บันทึกสิ่งของ', 'เพิ่มรายการสิ่งของพร้อมกำหนดวันหมดอายุ', const Color(0xFFFFB6C1)),
                  _buildStepItem(3, 'ตั้งค่าการแจ้งเตือน', 'เลือกว่าต้องการให้แจ้งเตือนก่อนหมดอายุกี่วัน', const Color(0xFFDDA0DD)),
                  _buildStepItem(4, 'ติดตามและจัดการ', 'ตรวจสอบรายการและจัดการสิ่งของที่ใกล้หมดอายุ', const Color(0xFFADD8E6)),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE6E6FA),
                          const Color(0xFFF0F8FF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Color(0xFFFF69B4),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'จัดการสิ่งของด้วยความรัก',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4A4A4A), 
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ไม่ให้อะไรหมดอายุโดยเปล่าประโยชน์',
                          style: TextStyle(
                            fontSize: 16, 
                            color: const Color(0xFF666666), 
                          ),
                        ),
                      ],
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget content,
    Color? iconColor,
    Color? bgColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor ?? const Color(0xFF8B5A8C), size: 28),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26, 
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  iconColor?.withOpacity(0.3) ?? const Color(0xFFE6E6FA),
                  iconColor?.withOpacity(0.1) ?? const Color(0xFFF0F8FF),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor ?? const Color(0xFF8B5A8C), size: 24), 
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.w600,
                    color: Color.fromARGB(255, 0, 0, 0), 
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 16, 
                    color: Color.fromARGB(255, 0, 0, 0), 
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String title, String description, Color stepColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  stepColor,
                  stepColor.withOpacity(0.7),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
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
                    fontSize: 18, // เพิ่มขนาดจาก 16 เป็น 18
                    fontWeight: FontWeight.w600,
                    color: Color.fromARGB(255, 0, 0, 0), 
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 16, 
                    color: Color.fromARGB(255, 0, 0, 0), 
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
