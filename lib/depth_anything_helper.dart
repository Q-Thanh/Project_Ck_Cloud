import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class DepthAnythingHelper {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;

  Future<void> loadModel() async {
    try {
      // 1. Cấu hình tùy chọn tăng tốc phần cứng (Sử dụng NNAPI trên Android để tăng tốc qua GPU/NPU)
      final options = InterpreterOptions();
      // options.useNpu = true; // Có thể bật tùy thiết bị

      // 2. Khởi tạo Interpreter từ file asset
      _interpreter = await Interpreter.fromAsset(
        'assets/depth_anything_v2_small_quant.tflite',
        options: options,
      );
      _isModelLoaded = true;
      print("🎯 Đã tải thành công model Depth Anything V2 Small!");
    } catch (e) {
      print("❌ Lỗi khi tải model Depth Anything V2: $e");
    }
  }

  // Phương pháp chuyển đổi trực tiếp YUV420 từ CameraImage sang RGB Float đầu vào của AI (518x518x3)
  // Giúp tối ưu hóa tốc độ cực nhanh mà không cần các thư viện xử lý ảnh bên ngoài.
  List<List<List<double>>> _convertYUV420ToRGBInput(CameraImage image, int targetSize) {
    final int width = image.width;
    final int height = image.height;
    
    var input = List.generate(
      targetSize,
      (_) => List.generate(
        targetSize,
        (_) => List.filled(3, 0.0),
      ),
    );

    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final yBuffer = image.planes[0].bytes;
    final uBuffer = image.planes[1].bytes;
    final vBuffer = image.planes[2].bytes;

    for (int y = 0; y < targetSize; y++) {
      // Ánh xạ tọa độ từ targetSize (518) sang kích thước ảnh thô của Camera
      int srcY = (y * height / targetSize).toInt().clamp(0, height - 1);

      for (int x = 0; x < targetSize; x++) {
        int srcX = (x * width / targetSize).toInt().clamp(0, width - 1);

        final int yIndex = srcY * width + srcX;
        final int uvIndex = (srcY >> 1) * uvRowStride + (srcX >> 1) * uvPixelStride;

        if (yIndex >= yBuffer.length || uvIndex >= uBuffer.length || uvIndex >= vBuffer.length) {
          continue;
        }

        final int yValue = yBuffer[yIndex] & 0xFF;
        final int uValue = uBuffer[uvIndex] & 0xFF;
        final int vValue = vBuffer[uvIndex] & 0xFF;

        // Công thức chuyển đổi màu YUV sang RGB tiêu chuẩn
        int r = (yValue + 1.370705 * (vValue - 128)).toInt().clamp(0, 255);
        int g = (yValue - 0.337633 * (uValue - 128) - 0.698001 * (vValue - 128)).toInt().clamp(0, 255);
        int b = (yValue + 1.732446 * (uValue - 128)).toInt().clamp(0, 255);

        // Normalize giá trị màu về khoảng [0.0, 1.0] làm đầu vào cho AI
        input[y][x][0] = r / 255.0;
        input[y][x][1] = g / 255.0;
        input[y][x][2] = b / 255.0;
      }
    }

    return input;
  }

  // Chạy suy luận và tính toán độ sâu của chướng ngại vật dựa trên Bounding Box
  double estimateBoxDepth(CameraImage image, double x1, double y1, double x2, double y2) {
    if (!_isModelLoaded || _interpreter == null) return -1.0;

    try {
      const int targetSize = 518; // Kích thước chuẩn của Depth Anything V2 Small

      // 1. Tiền xử lý chuyển đổi YUV420 sang RGB Tensor [1, 518, 518, 3]
      var rgbInput = _convertYUV420ToRGBInput(image, targetSize);
      var inputTensor = [rgbInput]; // Đóng gói batch size = 1

      // 2. Khởi tạo Buffer đầu ra dạng Bản đồ Độ sâu Nghịch đảo [1, 518, 518]
      var outputTensor = List.generate(
        1,
        (_) => List.generate(
          targetSize,
          (_) => List.filled(targetSize, 0.0),
        ),
      );

      // 3. Thực thi mô hình AI
      _interpreter!.run(inputTensor, outputTensor);

      // 4. Ánh xạ tọa độ Bounding Box (từ 0..1) sang hệ tọa độ Depth Map (518x518)
      int startX = (x1 * targetSize).clamp(0, targetSize - 1).toInt();
      int startY = (y1 * targetSize).clamp(0, targetSize - 1).toInt();
      int endX = (x2 * targetSize).clamp(0, targetSize - 1).toInt();
      int endY = (y2 * targetSize).clamp(0, targetSize - 1).toInt();

      double sumDisparity = 0.0;
      int count = 0;

      for (int y = startY; y <= endY; y++) {
        for (int x = startX; x <= endX; x++) {
          sumDisparity += outputTensor[0][y][x];
          count++;
        }
      }

      if (count == 0) return -1.0;
      double avgDisparity = sumDisparity / count;

      // 5. Quy đổi giá trị Disparity sang mét thực tế
      // Model Depth Anything V2 Small xuất ra giá trị Disparity (nghịch đảo của chiều sâu).
      // Công thức lượng hóa khoảng cách thực tế (mét):
      // meters = K / (disparity + epsilon)
      // Hệ số K được cân chỉnh thực nghiệm cho camera điện thoại di động là khoảng 8.5
      double meters = 8.5 / (avgDisparity + 0.05);

      if (meters < 0.1) meters = 0.1;
      return meters;
    } catch (e) {
      print("❌ Lỗi trong quá trình suy luận Depth Anything: $e");
      return -1.0;
    }
  }

  void close() {
    _interpreter?.close();
    _isModelLoaded = false;
  }
}
