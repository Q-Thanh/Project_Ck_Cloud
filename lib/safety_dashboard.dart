import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class SafetyDashboardScreen extends StatefulWidget {
  final String targetUserId;
  final String targetName;

  const SafetyDashboardScreen({
    super.key,
    required this.targetUserId,
    required this.targetName,
  });

  @override
  State<SafetyDashboardScreen> createState() => _SafetyDashboardScreenState();
}

class _SafetyDashboardScreenState extends State<SafetyDashboardScreen> with TickerProviderStateMixin {
  late DateTime _selectedDate;
  late List<DateTime> _dates;
  late AnimationController _chartAnimationController;

  final Map<String, String> _labelDictionary = {
    'person': 'người',
    'bicycle': 'xe đạp',
    'car': 'ô tô',
    'motorcycle': 'xe máy',
    'bus': 'xe buýt',
    'truck': 'xe tải',
    'bench': 'ghế dài',
    'cat': 'con mèo',
    'dog': 'con chó',
    'bottle': 'cái chai',
    'cup': 'cái cốc',
    'chair': 'cái ghế',
    'couch': 'sofa',
    'bed': 'giường',
    'dining table': 'bàn ăn',
    'tv': 'tivi',
    'laptop': 'máy tính',
    'mouse': 'con chuột',
    'keyboard': 'bàn phím',
    'cell phone': 'điện thoại',
    'refrigerator': 'tủ lạnh',
    'book': 'sách',
    'clock': 'đồng hồ',
    'vase': 'bình hoa',
    'scissors': 'cái kéo',
    'fan': 'cái quạt',
    'obstacle': 'vật cản',
    'barrier': 'rào chắn',
    'step': 'bậc thềm',
    'steps': 'bậc thềm',
    'fence': 'hàng rào',
    'pole': 'cột điện',
    'tree': 'cây cối'
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // Tạo danh sách 7 ngày qua (từ hôm nay lùi về sau)
    _dates = List.generate(7, (index) => DateTime.now().subtract(Duration(days: index)));
    
    _chartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _chartAnimationController.forward();
  }

  @override
  void dispose() {
    _chartAnimationController.dispose();
    super.dispose();
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _chartAnimationController.reset();
      _chartAnimationController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Thời điểm bắt đầu và kết thúc của ngày đã chọn (Local Time)
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          "Safety Analytics: ${widget.targetName}",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        backgroundColor: Colors.grey[950],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.cyanAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Horizontal Date Picker
            _buildDatePicker(),

            // Query cả location_history và safety_records của ngày được chọn
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('location_history')
                  .where('user_id', isEqualTo: widget.targetUserId)
                  .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                  .where('timestamp', isLessThanOrEqualTo: endOfDay)
                  .snapshots(),
              builder: (context, locationSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('safety_records')
                      .where('user_id', isEqualTo: widget.targetUserId)
                      .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                      .where('timestamp', isLessThanOrEqualTo: endOfDay)
                      .snapshots(),
                  builder: (context, safetySnapshot) {
                    if (locationSnapshot.connectionState == ConnectionState.waiting ||
                        safetySnapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 300,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.cyanAccent),
                        ),
                      );
                    }

                    // A. Xử lý dữ liệu lịch sử di chuyển để tính Quãng đường
                    final locDocs = locationSnapshot.data?.docs ?? [];
                    // Sắp xếp in-memory theo thời gian để tính khoảng cách di chuyển tuần tự
                    final sortedLocs = List<QueryDocumentSnapshot>.from(locDocs)
                      ..sort((a, b) {
                        final tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                        final tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                        if (tA == null) return 1;
                        if (tB == null) return -1;
                        return tA.compareTo(tB);
                      });

                    double totalDistanceMeters = 0.0;
                    for (int i = 0; i < sortedLocs.length - 1; i++) {
                      final p1 = sortedLocs[i].data() as Map<String, dynamic>;
                      final p2 = sortedLocs[i + 1].data() as Map<String, dynamic>;
                      if (p1['latitude'] != null &&
                          p1['longitude'] != null &&
                          p2['latitude'] != null &&
                          p2['longitude'] != null) {
                        totalDistanceMeters += Geolocator.distanceBetween(
                          p1['latitude'] as double,
                          p1['longitude'] as double,
                          p2['latitude'] as double,
                          p2['longitude'] as double,
                        );
                      }
                    }
                    final double distanceKm = totalDistanceMeters / 1000.0;

                    // B. Xử lý dữ liệu chướng ngại vật (Detections)
                    final safetyDocs = safetySnapshot.data?.docs ?? [];
                    final sortedSafety = List<QueryDocumentSnapshot>.from(safetyDocs)
                      ..sort((a, b) {
                        final tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                        final tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                        if (tA == null) return 1;
                        if (tB == null) return -1;
                        return tA.compareTo(tB);
                      });

                    int totalObstacles = 0;
                    final List<int> hourlyObstacles = List.filled(24, 0);
                    final Map<String, int> labelBreakdown = {};

                    for (var doc in sortedSafety) {
                      final data = doc.data() as Map<String, dynamic>;
                      final int count = data['object_count'] ?? 0;
                      totalObstacles += count;

                      final Timestamp? ts = data['timestamp'] as Timestamp?;
                      if (ts != null) {
                        final localTime = ts.toDate().toLocal();
                        hourlyObstacles[localTime.hour] += count;
                      }

                      final List<dynamic>? labels = data['labels'] as List<dynamic>?;
                      if (labels != null) {
                        for (var label in labels) {
                          final String lblStr = label.toString();
                          labelBreakdown[lblStr] = (labelBreakdown[lblStr] ?? 0) + 1;
                        }
                      }
                    }

                    // Tìm thời điểm rủi ro nhất (khung giờ có nhiều chướng ngại vật nhất)
                    int maxCount = -1;
                    int peakHour = -1;
                    for (int h = 0; h < 24; h++) {
                      if (hourlyObstacles[h] > maxCount) {
                        maxCount = hourlyObstacles[h];
                        peakHour = h;
                      }
                    }
                    final String peakHourText =
                        (totalObstacles > 0 && peakHour != -1) ? "$peakHour:00 - ${peakHour + 1}:00" : "N/A";

                    // C. Sinh báo cáo tự động bằng Tiếng Việt
                    final String summaryNarrative = _generateSummaryNarrative(
                      distanceKm: distanceKm,
                      totalObstacles: totalObstacles,
                      labelBreakdown: labelBreakdown,
                      peakHour: peakHour,
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 2. Thẻ hiển thị các chỉ số chính (KPI Cards)
                          _buildKpiSection(distanceKm, totalObstacles, peakHourText),
                          const SizedBox(height: 20),

                          // 3. Báo cáo bằng ngôn ngữ tự nhiên
                          _buildNarrativeCard(summaryNarrative),
                          const SizedBox(height: 20),

                          // 4. Biểu đồ đường xu hướng theo giờ
                          _buildHourlyTrendCard(hourlyObstacles),
                          const SizedBox(height: 20),

                          // 5. Phân loại chướng ngại vật
                          _buildBreakdownCard(labelBreakdown),
                          const SizedBox(height: 20),

                          // 6. Nhật ký hành trình
                          _buildTimelineCard(sortedSafety),
                          const SizedBox(height: 40),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- DỰNG GIAO DIỆN CHỌN NGÀY ---
  Widget _buildDatePicker() {
    return Container(
      height: 95,
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      color: Colors.grey[950],
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true, // Hiển thị ngày hôm nay đầu tiên
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          final date = _dates[index];
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final dayStr = DateFormat('dd/MM').format(date); // Ngày

          return GestureDetector(
            onTap: () => _onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 65,
              margin: const EdgeInsets.symmetric(horizontal: 6.0),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Colors.cyan, Colors.blueAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: isSelected ? Colors.cyanAccent.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getFriendlyDayName(date),
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.grey[400],
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dayStr,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getFriendlyDayName(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) return "H.Nay";
    if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) return "H.Qua";
    
    // Tự biên dịch thứ sang tiếng Việt viết tắt
    switch (date.weekday) {
      case DateTime.monday: return "T2";
      case DateTime.tuesday: return "T3";
      case DateTime.wednesday: return "T4";
      case DateTime.thursday: return "T5";
      case DateTime.friday: return "T6";
      case DateTime.saturday: return "T7";
      case DateTime.sunday: return "CN";
      default: return "";
    }
  }

  // --- DỰNG THẺ CHỈ SỐ NHANH ---
  Widget _buildKpiSection(double distanceKm, int totalObstacles, String peakHourText) {
    return Row(
      children: [
        Expanded(
          child: _buildSingleKpiCard(
            title: "QUÃNG ĐƯỜNG",
            value: "${distanceKm.toStringAsFixed(1)} km",
            icon: Icons.directions_walk,
            color: Colors.cyanAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSingleKpiCard(
            title: "VẬT CẢN TRÁNH",
            value: "$totalObstacles",
            icon: Icons.security,
            color: Colors.greenAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSingleKpiCard(
            title: "RỦI RO CAO NHẤT",
            value: peakHourText,
            icon: Icons.warning_amber_rounded,
            color: Colors.redAccent,
            valueSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    double valueSize = 18,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: valueSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- DỰNG BÁO CÁO NGÔN NGỮ TỰ NHIÊN ---
  Widget _buildNarrativeCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.cyan.withOpacity(0.12), Colors.blue.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.15), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note, color: Colors.cyanAccent, size: 24),
              SizedBox(width: 8),
              Text(
                "Tóm Tắt Báo Cáo Hành Trình",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // --- DỰNG BIỂU ĐỒ ĐƯỜNG XU HƯỚNG ---
  Widget _buildHourlyTrendCard(List<int> hourlyObstacles) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Biểu đồ vật cản phát hiện theo giờ",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 5),
          const Text(
            "Số lượng chướng ngại vật tránh được phân bố theo thời gian",
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 25),
          AnimatedBuilder(
            animation: _chartAnimationController,
            builder: (context, child) {
              return SizedBox(
                height: 180,
                width: double.infinity,
                child: CustomPaint(
                  painter: LineChartPainter(
                    data: hourlyObstacles,
                    animationProgress: _chartAnimationController.value,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- DỰNG PHÂN LOẠI VẬT CẢN (BAR CHART HORIZONTAL) ---
  Widget _buildBreakdownCard(Map<String, int> labelBreakdown) {
    final sortedLabels = labelBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalDetections = labelBreakdown.values.fold(0, (acc, val) => acc + val);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Phân loại chướng ngại vật đã tránh",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 5),
          const Text(
            "Các nhóm vật cản phát hiện nhiều nhất trên lộ trình",
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 20),
          if (sortedLabels.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text("Không có dữ liệu vật cản", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(5, sortedLabels.length), // Chỉ lấy tối đa top 5
              itemBuilder: (context, index) {
                final entry = sortedLabels[index];
                final tag = entry.key;
                final count = entry.value;
                final vnName = _capitalize(_labelDictionary[tag] ?? tag);
                final ratio = totalDetections > 0 ? count / totalDetections : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(vnName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                          Text("$count lần", style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Stack(
                        children: [
                          Container(
                            height: 8,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _chartAnimationController,
                            builder: (context, child) {
                              return FractionallySizedBox(
                                widthFactor: ratio * _chartAnimationController.value,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.cyan, Colors.blueAccent],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.cyanAccent.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- DỰNG NHẬT KÝ HÀNH TRÌNH CHỦ ĐỘNG ---
  Widget _buildTimelineCard(List<QueryDocumentSnapshot> safetyDocs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Nhật ký hành trình chi tiết",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 5),
          const Text(
            "Danh sách chi tiết các chướng ngại vật được phát hiện",
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 20),
          if (safetyDocs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text("Không có lịch sử hành trình", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(10, safetyDocs.length), // Chỉ lấy tối đa 10 sự kiện gần nhất
              itemBuilder: (context, index) {
                // Đảo ngược thứ tự để hiển thị mới nhất trước
                final doc = safetyDocs[safetyDocs.length - 1 - index];
                final data = doc.data() as Map<String, dynamic>;
                final Timestamp? ts = data['timestamp'] as Timestamp?;
                final String timeText = ts != null ? DateFormat('HH:mm:ss').format(ts.toDate().toLocal()) : "N/A";

                final int count = data['object_count'] ?? 0;
                final List<dynamic>? labels = data['labels'] as List<dynamic>?;
                
                final String labelsText = labels != null
                    ? labels.map((l) => _labelDictionary[l.toString()] ?? l.toString()).join(", ")
                    : "vật cản";

                final double? lat = data['latitude'] as double?;
                final double? lng = data['longitude'] as double?;
                final String coordText = (lat != null && lng != null)
                    ? "Tọa độ: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}"
                    : "Không rõ tọa độ";

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cột vẽ trục Timeline
                      Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 2,
                              color: index == math.min(10, safetyDocs.length) - 1
                                  ? Colors.transparent
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Nội dung
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    timeText,
                                    style: const TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "Tránh $count vật cản",
                                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Đã nhận diện: ${_capitalize(labelsText)}",
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                coordText,
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- CÔNG CỤ TẠO BÁO CÁO VĂN BẢN TIẾNG VIỆT ---
  String _generateSummaryNarrative({
    required double distanceKm,
    required int totalObstacles,
    required Map<String, int> labelBreakdown,
    required int peakHour,
  }) {
    if (distanceKm == 0 && totalObstacles == 0) {
      return "Hôm nay chưa ghi nhận dữ liệu hành trình của người khiếm thị. Hãy đảm bảo ứng dụng chính đang hoạt động và bật GPS chia sẻ vị trí.";
    }

    final sortedLabels = labelBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Gom chuỗi mô tả top vật cản: ví dụ "30 xe máy, 5 rào chắn, 10 bậc thềm"
    List<String> detailParts = [];
    for (int i = 0; i < math.min(3, sortedLabels.length); i++) {
      final entry = sortedLabels[i];
      final rawLabel = entry.key;
      final count = entry.value;
      
      // Lấy tên tiếng Việt từ từ điển
      String vnName = _labelDictionary[rawLabel] ?? rawLabel;
      // Dịch từ tiếng Anh số nhiều/ít
      if (count > 1) {
        if (vnName == 'xe máy') vnName = 'xe máy';
        else if (vnName == 'người') vnName = 'người';
        else if (vnName == 'rào chắn') vnName = 'rào chắn';
        else if (vnName == 'bậc thềm') vnName = 'bậc thềm';
      }
      detailParts.add("$count $vnName");
    }

    String breakdownText = "";
    if (detailParts.isNotEmpty) {
      breakdownText = " (${detailParts.join(", ")})";
    }

    String riskText = "";
    if (totalObstacles > 0 && peakHour != -1) {
      riskText = " Tuyến đường di chuyển vào lúc $peakHour giờ có mức độ rủi ro cao nhất (phát hiện nhiều chướng ngại vật nhất).";
    }

    final distanceStr = distanceKm.toStringAsFixed(1);
    return "Hôm nay, người dùng đã di chuyển được quãng đường dài $distanceStr km, vượt qua an toàn $totalObstacles chướng ngại vật$breakdownText.$riskText Báo cáo cho thấy người khiếm thị đã có một hành trình di chuyển thuận lợi và an toàn.";
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

// --- BIỂU ĐỒ ĐƯỜNG BẰNG CUSTOM PAINTER ---
class LineChartPainter extends CustomPainter {
  final List<int> data; // 24 phần tử tương ứng 24 giờ
  final double animationProgress;

  LineChartPainter({required this.data, required this.animationProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintGlow = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.3)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintPoint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final paintPointBorder = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final paintGrid = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    // Tính toán tỷ lệ vẽ
    // Giới hạn hiển thị 24 giờ từ 0h đến 23h
    const int numXPoints = 24;
    final double stepX = size.width / (numXPoints - 1);

    int maxVal = data.fold(0, (max, element) => element > max ? element : max);
    if (maxVal == 0) maxVal = 5; // Dự phòng tối thiểu để vẽ lưới y
    final double maxValDouble = maxVal.toDouble();

    // 1. Vẽ các đường lưới ngang và nhãn trục Y
    const int gridRows = 4;
    for (int i = 0; i <= gridRows; i++) {
      final double y = size.height * (1.0 - (i / gridRows));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);

      // Vẽ text nhãn y
      final labelY = (maxVal * (i / gridRows)).round();
      textPainter.text = TextSpan(
        text: "$labelY",
        style: TextStyle(color: Colors.grey[600], fontSize: 9, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(4, y - textPainter.height - 2));
    }

    // Vẽ nhãn trục X
    final List<int> sampleHours = [4, 8, 12, 16, 20, 23];
    for (int hour in sampleHours) {
      final double x = hour * stepX;
      textPainter.text = TextSpan(
        text: "${hour}h",
        style: TextStyle(color: Colors.grey[500], fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height + 4));
    }

    // 2. Tạo đường dẫn Path cho biểu đồ
    final List<Offset> points = [];
    for (int i = 0; i < 24; i++) {
      final double x = i * stepX;
      // Áp dụng animationProgress vào trục Y
      final double val = data[i].toDouble() * animationProgress;
      final double y = size.height * (1.0 - (val / maxValDouble));
      points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);

      // Vẽ Bezier mượt mà (Cubic Bezier curve)
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
        final controlY1 = p0.dy;
        final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
        final controlY2 = p1.dy;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
      }

      // 3. Vẽ vùng phủ Gradient dưới đường Bezier (Fading Fill)
      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();

      final paintFill = Paint()
        ..shader = LinearGradient(
          colors: [Colors.cyan.withOpacity(0.25), Colors.cyan.withOpacity(0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, paintFill);

      // 4. Vẽ đường chính (Stroke) và Glow
      canvas.drawPath(path, paintGlow);
      canvas.drawPath(path, paintLine);

      // 5. Vẽ các chấm tròn neon trên đỉnh các điểm có dữ liệu > 0
      for (int i = 0; i < points.length; i++) {
        if (data[i] > 0) {
          final p = points[i];
          // Chấm phát sáng
          final paintGlowDot = Paint()
            ..color = Colors.cyanAccent.withOpacity(0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
          canvas.drawCircle(p, 6.0, paintGlowDot);

          // Điểm viền
          canvas.drawCircle(p, 4.5, paintPointBorder);
          // Điểm lõi trắng
          canvas.drawCircle(p, 2.5, paintPoint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress || oldDelegate.data != data;
  }
}
