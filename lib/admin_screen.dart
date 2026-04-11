import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Đã dùng để format ngày giờ
import 'main.dart'; 

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 1; // Mặc định vào tab "Người dùng"

  // Danh sách các màn hình tương ứng với Menu
  final List<Widget> _screens = [
    const Center(child: Text("Trang Tổng Quan (Dashboard) đang phát triển...", style: TextStyle(fontSize: 20, color: Colors.grey))),
    const UserManagementScreen(), //  Nội dung chính nằm ở đây
    const Center(child: Text("Nhật ký lỗi đang phát triển...", style: TextStyle(fontSize: 20, color: Colors.grey))),
    const Center(child: Text("Quản lý Model AI đang phát triển...", style: TextStyle(fontSize: 20, color: Colors.grey))),
    const Center(child: Text("Hộp thư Góp ý đang phát triển...", style: TextStyle(fontSize: 20, color: Colors.grey))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          // ---------------------------------------
          // 1. SIDEBAR (MENU BÊN TRÁI)
          // ---------------------------------------
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index); // Cập nhật trạng thái để đổi trang
            },
            backgroundColor: Colors.white,
            elevation: 1,
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 20),
              child: CircleAvatar(
                backgroundColor: Colors.blue,
                radius: 20,
                child: Icon(Icons.admin_panel_settings, color: Colors.white),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: Colors.blue),
                label: Text('Tổng Quan'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people, color: Colors.blue),
                label: Text('Người Dùng'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.warning_amber_rounded),
                selectedIcon: Icon(Icons.warning, color: Colors.blue),
                label: Text('Nhật Ký Lỗi'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.layers_outlined),
                selectedIcon: Icon(Icons.layers, color: Colors.blue),
                label: Text('Phiên Bản'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble, color: Colors.blue),
                label: Text('Góp Ý'),
              ),
            ],
          ),

          // ---------------------------------------
          // 2. NỘI DUNG CHÍNH (THAY ĐỔI THEO MENU)
          // ---------------------------------------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _screens[_selectedIndex], // Hiển thị màn hình tương ứng
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// WIDGET RIÊNG CHO TAB "QUẢN LÝ NGƯỜI DÙNG"
// ---------------------------------------------------------
class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Quản Lý Người Dùng", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text("Danh sách tài khoản và trạng thái hoạt động", style: TextStyle(color: Colors.grey)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {}, // Tính năng xuất Excel để sau
              icon: const Icon(Icons.download, size: 18),
              label: const Text("Export CSV"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
            )
          ],
        ),
        const SizedBox(height: 20),

        // BẢNG DỮ LIỆU
        Expanded(
          child: Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('users').orderBy('created_at', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 50,
                      dataRowMinHeight: 60,
                      dataRowMaxHeight: 60,
                      columnSpacing: 30,
                      headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                      columns: const [
                        DataColumn(label: Text('USER', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('VAI TRÒ', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('TRẠNG THÁI', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('LẦN HOẠT ĐỘNG CUỐI', style: TextStyle(fontWeight: FontWeight.bold))), // ✨ Cột mới
                        DataColumn(label: Text('THAO TÁC', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: docs.map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        String name = data['username'] ?? 'No Name';
                        String email = data['email'] ?? '';
                        String role = data['role'] ?? 'user';
                        String status = data['status'] ?? 'offline';

                        // Xử lý thời gian (Last Active)
                        String lastActive = "Chưa hoạt động";
                        if (data['location'] != null && data['location']['timestamp'] != null) {
                          Timestamp t = data['location']['timestamp'];
                          // Format: 14:30 - 09/02
                          lastActive = DateFormat('HH:mm - dd/MM').format(t.toDate());
                        }

                        return DataRow(cells: [
                          // 1. User Info
                          DataCell(Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.blue[100],
                                child: Text(name[0].toUpperCase(), style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ],
                          )),
                          
                          // 2. Role (Vai trò)
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: role == 'blind' ? Colors.purple[50] : Colors.green[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: role == 'blind' ? Colors.purple[200]! : Colors.green[200]!),
                            ),
                            child: Text(role == 'blind' ? 'KHIẾM THỊ' : 'NGƯỜI THÂN', 
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: role == 'blind' ? Colors.purple : Colors.green)),
                          )),

                          // 3. Status (Trạng thái)
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.blue[600], borderRadius: BorderRadius.circular(4)),
                            child: const Text("ACTIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          )),

                          // 4. Last Active (Lần cuối vào App) ✨
                          DataCell(Text(lastActive, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500))),

                          // 5. Actions
                          DataCell(Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.location_on_outlined, color: Colors.blue),
                                tooltip: "Xem vị trí",
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => TrackingScreen(targetName: name)));
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                                onPressed: () {},
                              ),
                            ],
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}