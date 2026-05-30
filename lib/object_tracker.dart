import 'dart:math' as math;

/// Đại diện cho một vật thể đang được theo vết.
class TrackedObject {
  final String id;
  final String tag;
  List<double> box; // [x1, y1, x2, y2, confidence]
  final DateTime firstDetected;
  DateTime lastSeen;
  int framesSinceLastSeen;
  bool isUploaded;
  bool isAddedToHistory;
  bool isSpoken;
  String? lastSpokenDistance;
  DateTime lastSpokenTime;

  TrackedObject({
    required this.id,
    required this.tag,
    required this.box,
    required this.firstDetected,
    required this.lastSeen,
    this.framesSinceLastSeen = 0,
    this.isUploaded = false,
    this.isAddedToHistory = false,
    this.isSpoken = false,
    this.lastSpokenDistance,
    required this.lastSpokenTime,
  });

  double get x1 => box[0];
  double get y1 => box[1];
  double get x2 => box[2];
  double get y2 => box[3];
  double get confidence => box[4];

  math.Point<double> get centroid {
    return math.Point((x1 + x2) / 2, (y1 + y2) / 2);
  }
}

/// Trình quản lý theo vết vật thể qua từng frame.
class ObjectTracker {
  final List<TrackedObject> _trackedObjects = [];
  int _nextId = 1;

  // Cấu hình số frame tối đa hoặc thời gian tối đa để giữ vật thể khi mất dấu
  final int maxAgeFrames = 5;
  final Duration maxAgeDuration = const Duration(seconds: 2);

  List<TrackedObject> get trackedObjects => _trackedObjects;

  /// Tìm vật thể theo vết bằng ID.
  TrackedObject? find(String id) {
    for (var obj in _trackedObjects) {
      if (obj.id == id) return obj;
    }
    return null;
  }

  /// Cập nhật trạng thái theo vết dựa trên kết quả nhận diện mới.
  void update(List<Map<String, dynamic>> detections) {
    // 1. Tăng số frame không thấy của tất cả vật thể đang theo dõi
    for (var obj in _trackedObjects) {
      obj.framesSinceLastSeen++;
    }

    // 2. So khớp từng detection mới với các vật thể đang theo dõi
    for (var det in detections) {
      final String tag = det['tag'] ?? '';
      final List<double> detBox = List<double>.from(det['box'] ?? [0.0, 0.0, 0.0, 0.0, 0.0]);

      TrackedObject? bestMatch;
      double bestScore = 0.0;

      for (var obj in _trackedObjects) {
        if (obj.tag != tag) continue;

        double iou = _calculateIoU(obj.box, detBox);
        double dist = _calculateCentroidDistance(obj.box, detBox);

        // Chấm điểm so khớp:
        // - Ưu tiên IoU lớn (độ đè chồng của khung bounding box)
        // - Nếu không đè chồng nhiều nhưng khoảng cách tâm rất gần (trong khoảng cách 0.2)
        double score = 0.0;
        if (iou > 0.15) {
          score = iou; // Điểm từ 0.15 -> 1.0
        } else if (dist < 0.20) {
          score = (0.20 - dist) * 0.5; // Điểm từ 0.0 -> 0.1
        }

        if (score > bestScore) {
          bestScore = score;
          bestMatch = obj;
        }
      }

      if (bestMatch != null && bestScore > 0.0) {
        // So khớp thành công, cập nhật thông tin vật thể
        bestMatch.box = detBox;
        bestMatch.lastSeen = DateTime.now();
        bestMatch.framesSinceLastSeen = 0;
        det['tracker_id'] = bestMatch.id;
      } else {
        // Không tìm thấy vật thể cũ phù hợp, tạo một vật thể theo vết mới
        String newId = "${tag}_${_nextId++}";
        var newObj = TrackedObject(
          id: newId,
          tag: tag,
          box: detBox,
          firstDetected: DateTime.now(),
          lastSeen: DateTime.now(),
          lastSpokenTime: DateTime.now().subtract(const Duration(minutes: 5)), // Cho phép nói ngay lập tức
        );
        _trackedObjects.add(newObj);
        det['tracker_id'] = newId;
      }
    }

    // 3. Loại bỏ những vật thể không xuất hiện trong thời gian dài
    _trackedObjects.removeWhere((obj) {
      return obj.framesSinceLastSeen > maxAgeFrames ||
          DateTime.now().difference(obj.lastSeen) > maxAgeDuration;
    });
  }

  /// Xoá toàn bộ lịch sử theo vết (dùng khi tạm dừng camera).
  void clear() {
    _trackedObjects.clear();
    _nextId = 1;
  }

  // Hàm tính IoU (Intersection over Union) giữa hai Bounding Box
  double _calculateIoU(List<double> boxA, List<double> boxB) {
    double xA = math.max(boxA[0], boxB[0]);
    double yA = math.max(boxA[1], boxB[1]);
    double xB = math.min(boxA[2], boxB[2]);
    double yB = math.min(boxA[3], boxB[3]);

    double interArea = math.max(0.0, xB - xA) * math.max(0.0, yB - yA);
    if (interArea == 0.0) return 0.0;

    double boxAArea = (boxA[2] - boxA[0]) * (boxA[3] - boxA[1]);
    double boxBArea = (boxB[2] - boxB[0]) * (boxB[3] - boxB[1]);

    double unionArea = boxAArea + boxBArea - interArea;
    if (unionArea <= 0.0) return 0.0;

    return interArea / unionArea;
  }

  // Hàm tính khoảng cách Euclid giữa hai trọng tâm Bounding Box
  double _calculateCentroidDistance(List<double> boxA, List<double> boxB) {
    double centerAx = (boxA[0] + boxA[2]) / 2;
    double centerAy = (boxA[1] + boxA[3]) / 2;
    double centerBx = (boxB[0] + boxB[2]) / 2;
    double centerBy = (boxB[1] + boxB[3]) / 2;

    return math.sqrt(math.pow(centerAx - centerBx, 2) + math.pow(centerAy - centerBy, 2));
  }
}
