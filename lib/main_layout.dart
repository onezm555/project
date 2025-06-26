
import 'package:flutter/material.dart';
import 'index.dart';
import 'calendar.dart';
import 'notification.dart';
import 'menu.dart';
import 'add_item.dart';

class MainLayout extends StatefulWidget {
  final int initial_tab;
  
  const MainLayout({
    Key? key, 
    this.initial_tab = 0,
  }) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _selected_index;
  final TextEditingController _search_controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected_index = widget.initial_tab;
  }

  @override
  void dispose() {
    _search_controller.dispose();
    super.dispose();
  }

  // รายการหน้าต่างๆ
  final List<Widget> _pages = [
    const IndexPage(),
    const CalendarPage(),
    const NotificationPage(),
    const MenuPage(),
  ];

  // รายการชื่อหน้า
  final List<String> _page_titles = [
    'หน้าแรก',
    'ปฏิทิน',
    'การแจ้งเตือน',
    'เมนู',
  ];

  // ฟังก์ชันสำหรับการเปลี่ยนแท็บ
  void _on_tab_selected(int index) {
    setState(() {
      _selected_index = index;
    });
  }

  // ฟังก์ชันสำหรับการค้นหา
  void _handle_search(String query) {
    // TODO: เพิ่มฟังก์ชันการค้นหา
    print('ค้นหา: $query');
  }

  // ฟังก์ชันสำหรับแสดงเมนูเพิ่มสินค้า
  void _show_add_item_menu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ปุ่มเพิ่มสินค้าใหม่
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _add_new_item();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'เพิ่มสินค้าใหม่',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            
            // ปุ่มเพิ่มสินค้าที่มีอยู่
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _add_existing_item();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'เพิ่มสินค้าที่มีอยู่',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ฟังก์ชันสำหรับเพิ่มสินค้าใหม่
  void _add_new_item() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddItemPage(is_existing_item: false),
      ),
    ).then((result) {
      if (result == true) {
        // รีเฟรชข้อมูลถ้าบันทึกสำเร็จ
        setState(() {
          // TODO: รีเฟรชข้อมูลในหน้าแรก
        });
      }
    });
  }

  // ฟังก์ชันสำหรับเพิ่มสินค้าที่มีอยู่
  void _add_existing_item() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddItemPage(is_existing_item: true),
      ),
    ).then((result) {
      if (result == true) {
        // รีเฟรชข้อมูลถ้าบันทึกสำเร็จ
        setState(() {
          // TODO: รีเฟรชข้อมูลในหน้าแรก
        });
      }
    });
  }

  // ฟังก์ชันสำหรับเปิดฟิลเตอร์
  void _open_filter() {
    // TODO: เพิ่มฟังก์ชันฟิลเตอร์
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ฟีเจอร์ฟิลเตอร์ยังไม่พร้อมใช้งาน'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _page_titles[_selected_index],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // แถบค้นหา - แสดงเฉพาะในหน้าแรก
          if (_selected_index == 0)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // ช่องค้นหา
                  Expanded(
                    child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _search_controller,
                        onSubmitted: _handle_search,
                        decoration: const InputDecoration(
                          hintText: 'ค้นหาสินค้าของคุณ',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // ปุ่มตะกร้า/สแกน QR
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      onPressed: _show_add_item_menu,
                      icon: const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // ปุ่มฟิลเตอร์
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      onPressed: _open_filter,
                      icon: const Icon(
                        Icons.tune,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // เนื้อหาหลัก
          Expanded(
            child: IndexedStack(
              index: _selected_index,
              children: _pages,
            ),
          ),
        ],
      ),
      
      // ปุ่มเพิ่มสินค้าลอยตัว - แสดงเฉพาะในหน้าแรก
      floatingActionButton: _selected_index == 0 ? Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90E2).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          onPressed: _show_add_item_menu,
          icon: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      
      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selected_index,
          onTap: _on_tab_selected,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF4A90E2),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'หน้าแรก',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'ปฏิทิน',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'การแจ้งเตือน',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_outlined),
              activeIcon: Icon(Icons.menu),
              label: 'เมนู',
            ),
          ],
        ),
      ),
    );
  }
}