import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Để dùng HapticFeedback
import 'package:flutter_vision/flutter_vision.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:light_sensor/light_sensor.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_map/flutter_map.dart'; // Import bản đồ
import 'package:latlong2/latlong.dart';       // Import tọa độ
import 'admin_screen.dart';
late List<CameraDescription> _cameras;

Future<void> main() async {
  // 1. Đảm bảo Flutter đã sẵn sàng
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2.  BẬT NGUỒN FIREBASE (ĐỂ DÙNG ĐĂNG NHẬP/ĐĂNG KÝ CHO NGƯỜI KHIẾM THỊ)
  try {
    await Firebase.initializeApp();
    print("Đã kết nối Firebase thành công!");
  } catch (e) {
    print(" Lỗi kết nối Firebase: $e");
  }

  // 3. Khởi tạo Camera
  try {
    _cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Lỗi Camera: ${e.description}');
  }
  
  // 4. Chạy App
  runApp(const MatAiApp());
}

class MatAiApp extends StatelessWidget {
  const MatAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mắt Thần AI',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.cyanAccent,
      ),
      home: const WelcomeScreen(),
    );
  }
}

// ==========================================
// PHẦN GIAO DIỆN MỚI: CHỌN TRƯỚC - NHẬP SAU
// ==========================================

enum UserMode { none, blind, family }

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  UserMode _mode = UserMode.none; // Mặc định chưa chọn gì
  bool isLoginMode = true; // biến xem biết là chế độ đăng nhập hay đăng ký
  // Controller nhập liệu
  final _blindUserController = TextEditingController();
  final _blindPassController = TextEditingController();
  final _blindConfirmPassController = TextEditingController();
  final _familyIdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Nút Back nhỏ ở góc trên để quay lại màn hình chọn (chỉ hiện khi đã chọn mode)
      appBar: _mode == UserMode.none 
          ? null 
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: _mode == UserMode.blind ? Colors.cyanAccent : Colors.blue[900]),
                onPressed: () => setState(() => _mode = UserMode.none), // Quay lại bước 1
              ),
            ),
      extendBodyBehindAppBar: true,
      // Hiệu ứng chuyển cảnh mượt mà
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _buildBody(),
      ),
    );
  }
  // Hàm hiển thị hộp thoại nhập mã PIN cho admin
  void _showAdminPinDialog() {
    final TextEditingController pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900], // Nền tối cho ngầu
        title: const Text("NHẬP MÃ QUẢN TRỊ", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: pinController,
          obscureText: true, // Ẩn số nhập vào
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Nhập mã PIN bí mật...",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Nút Hủy
            child: const Text("Hủy", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              // 👇 Đặt mật khẩu của bạn ở đây (Ví dụ: 9999)
              if (pinController.text == "2005") { 
                Navigator.pop(context); // Tắt bảng nhập
                // Chuyển sang trang Admin
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen()));
              } else {
                // Nhập sai thì báo lỗi
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Sai mã PIN rồi!"), backgroundColor: Colors.red)
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            child: const Text("Xác nhận", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  Widget _buildBody() {
    switch (_mode) {
      case UserMode.none:
        return _buildSelectionScreen();
      case UserMode.blind:
        return _buildBlindInputScreen();
      case UserMode.family:
        return _buildFamilyInputScreen();
    }
  }

  // --- BƯỚC 1: MÀN HÌNH CHỌN VAI TRÒ ---
  Widget _buildSelectionScreen() {
    return Row(
      key: const ValueKey("Selection"),
      children: [
        // NỬA TRÁI: NGƯỜI KHIẾM THỊ (Màu Đen)
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _mode = UserMode.blind),
            child: Container(
              color: Colors.black,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility, size: 80, color: Colors.cyanAccent),
                  SizedBox(height: 20),
                  Text("DÀNH CHO\nNGƯỜI KHIẾM THỊ", 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),
          ),
        ),
        // NỬA PHẢI: NGƯỜI THÂN (Màu Trắng)
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _mode = UserMode.family),
            // nhấn giữ để hiển thị ra trang admin
            onLongPress: () {
               // Gọi hộp thoại nhập mã PIN thay vì vào thẳng
               _showAdminPinDialog(); 
            },
            child: Container(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.family_restroom, size: 80, color: Colors.blue[900]),
                  const SizedBox(height: 20),
                  Text("DÀNH CHO\nNGƯỜI THÂN", 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blue[900], fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- MÀN HÌNH BƯỚC 2A: ĐĂNG NHẬP / ĐĂNG KÝ (NGƯỜI KHIẾM THỊ) ---
  Widget _buildBlindInputScreen() {
    return Container(
      key: const ValueKey("BlindInput"),
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.all(30),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.visibility, size: 60, color: Colors.cyanAccent),
              const SizedBox(height: 20),
              
              // Tiêu đề thay đổi theo chế độ
              Text(
                isLoginMode ? "ĐĂNG NHẬP" : "ĐĂNG KÝ TÀI KHOẢN", 
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 24, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 40),

              // Ô 1: Tài khoản (Email)
              TextField(
                controller: _blindUserController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Tên tài khoản (viết liền không dấu)",
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                  prefixIcon: Icon(Icons.person, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),

              // Ô 2: Mật khẩu
              TextField(
                controller: _blindPassController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Mật khẩu",
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                  prefixIcon: Icon(Icons.lock, color: Colors.grey),
                ),
              ),
              
              // Ô 3: Nhập lại mật khẩu (CHỈ HIỆN KHI ĐĂNG KÝ)
              if (!isLoginMode) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _blindConfirmPassController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Nhập lại mật khẩu",
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                    prefixIcon: Icon(Icons.lock_reset, color: Colors.grey),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Nút Chính (Đăng nhập hoặc Đăng ký) - ĐÃ CẬP NHẬT FIREBASE
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  // Thêm chữ async để dùng được Firebase
                  onPressed: () async { 
                    // 1. Lấy thông tin nhập vào
                    String username = _blindUserController.text.trim();
                    String password = _blindPassController.text.trim();

                    // MẸO QUAN TRỌNG: Tự động thêm đuôi email giả
                    String fakeEmail = "$username@matthan.com"; 

                    // Kiểm tra rỗng
                    if (username.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập đủ thông tin!")));
                      return;
                    }

                    try {
                      if (isLoginMode) {
                        // --- LOGIC ĐĂNG NHẬP ---
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đang đăng nhập...")));
                        
                        // Gửi email giả lên Firebase để đăng nhập
                        await FirebaseAuth.instance.signInWithEmailAndPassword(
                          email: fakeEmail, 
                          password: password
                        );
                        
                        // Thành công -> Vào Camera
                        if (mounted) {
                           Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const YoloScreen()));
                        }

                      } else {
                        // --- LOGIC ĐĂNG KÝ ---
                        String confirmPass = _blindConfirmPassController.text.trim();
                        
                        if (password != confirmPass) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mật khẩu nhập lại không khớp!")));
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đang tạo tài khoản...")));

                        // 1. Tạo tài khoản Authentication
                        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                          email: fakeEmail, 
                          password: password
                        );

                        // 2.  LƯU THÔNG TIN VÀO DATABASE
                        // Lấy ID riêng của user vừa tạo
                        String uid = userCredential.user!.uid; 

                        await FirebaseFirestore.instance.collection('users').doc(uid).set({
                          'username': username,      // Lưu tên gốc (ví dụ: thanh)
                          'email': fakeEmail,        // Lưu email giả
                          'role': 'blind',           // Đánh dấu là Người khiếm thị
                          'created_at': DateTime.now(), // Ngày tạo
                          'device_info': 'Android',  // (Tùy chọn)
                        });

                        // Đăng ký xong -> Vào Camera luôn
                        if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đăng ký thành công!")));
                           Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const YoloScreen()));
                        }
                      }
                    } on FirebaseAuthException catch (e) {
                      // Xử lý lỗi tiếng Việt
                      String message = "Đã có lỗi xảy ra.";
                      if (e.code == 'user-not-found' || e.code == 'invalid-credential') message = "Sai tên đăng nhập hoặc mật khẩu.";
                      else if (e.code == 'wrong-password') message = "Sai mật khẩu.";
                      else if (e.code == 'email-already-in-use') message = "Tên tài khoản này đã có người dùng.";
                      else if (e.code == 'weak-password') message = "Mật khẩu quá yếu (cần trên 6 ký tự).";

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
                      }
                    } catch (e) {
                      print(e);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
                  child: Text(
                    isLoginMode ? "VÀO ỨNG DỤNG" : "ĐĂNG KÝ NGAY", 
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Nút Chuyển đổi qua lại
              TextButton(
                onPressed: () {
                  // Đảo ngược trạng thái (Đang Login -> Đăng ký và ngược lại)
                  setState(() {
                    isLoginMode = !isLoginMode;
                  });
                },
                child: Text(
                  isLoginMode 
                    ? "Chưa có tài khoản? Đăng ký ngay" 
                    : "Đã có tài khoản? Quay lại đăng nhập",
                  style: const TextStyle(color: Colors.white70, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- BƯỚC 2B: NHẬP Dữ LIỆU Bên NGƯỜI THÂN ---
  Widget _buildFamilyInputScreen() {
    return Container(
      key: const ValueKey("FamilyInput"),
      width: double.infinity,
      height: double.infinity,
      color: Colors.white, 
      padding: const EdgeInsets.all(30),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.family_restroom, size: 60, color: Colors.blue[900]),
              const SizedBox(height: 20),
              Text("THEO DÕI NGƯỜI THÂN", style: TextStyle(color: Colors.blue[900], fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Nhập ID của người bạn muốn theo dõi", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              
              TextField(
                controller: _familyIdController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: "Ví dụ: User_12345",
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.qr_code, color: Colors.blueGrey),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // 1. Lấy tên người cần tìm
                    String targetName = _familyIdController.text.trim();

                    if (targetName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập ID người thân!")));
                      return;
                    }

                    // 2. Chuyển sang màn hình Bản đồ
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => TrackingScreen(targetName: targetName)
                    ));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                  child: const Text("BẮT ĐẦU THEO DÕI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PHẦN CAMERA & AI 
// ==========================================

class YoloScreen extends StatefulWidget {
  const YoloScreen({super.key});

  @override
  State<YoloScreen> createState() => _YoloScreenState();
}

class _YoloScreenState extends State<YoloScreen> {
  late CameraController controller;
  late FlutterVision vision;
  late FlutterTts flutterTts;
  
  bool isLoaded = false;
  bool isDetecting = false;
  
  // Quản lý Flash
  bool isFlashOn = false;
  bool isAutoFlash = false;
  StreamSubscription<int>? _lightSensorSubscription;

  bool isPaused = false;
  bool isEcoMode = false;

  List<Map<String, dynamic>> yoloResults = [];
  CameraImage? cameraImage;
  int frameCounter = 0;
  Size? screenSize;

  List<Map<String, dynamic>> detectionHistory = [];
  String lastSpokenTag = "";
  bool isSpeaking = false;
  DateTime lastDangerAlert = DateTime.now();

  final Map<String, String> dictionary = {
    'person': 'Người', 'bicycle': 'Xe đạp', 'car': 'Ô tô', 'motorcycle': 'Xe máy',
    'bus': 'Xe buýt', 'truck': 'Xe tải', 'bench': 'Ghế dài', 'cat': 'Con mèo',
    'dog': 'Con chó', 'bottle': 'Cái chai', 'cup': 'Cái cốc', 'chair': 'Cái ghế',
    'couch': 'Sofa', 'bed': 'Giường', 'dining table': 'Bàn ăn', 'tv': 'Ti vi',
    'laptop': 'Máy tính', 'mouse': 'Con chuột', 'keyboard': 'Bàn phím',
    'cell phone': 'Điện thoại', 'refrigerator': 'Tủ lạnh', 'book': 'Sách',
    'clock': 'Đồng hồ', 'vase': 'Bình hoa', 'scissors': 'Cái kéo', 'fan': 'Cái quạt'
  };

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("vi-VN");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setQueueMode(1); 

    if (_cameras.isEmpty) return;
    controller = CameraController(_cameras[0], ResolutionPreset.high);
    await controller.initialize();
    await controller.setFlashMode(FlashMode.off);

    // Kích hoạt cảm biến ánh sáng
    _startLightSensor();

    vision = FlutterVision();
    await vision.loadYoloModel(
      labels: 'assets/labels.txt',
      modelPath: 'assets/yolov8n.tflite',
      modelVersion: "yolov8",
      quantization: false,
      numThreads: 2,
      useGpu: true,
    );

    setState(() {
      isLoaded = true;
    });

    controller.startImageStream((image) {
      if (isPaused) return;
      frameCounter++;
      int interval = isEcoMode ? 10 : 2; 
      if (!isDetecting && frameCounter % interval == 0) {
        isDetecting = true;
        yoloOnFrame(image);
      }
    });
    _startSharingLocation();
  }

  // Hàm lắng nghe cảm biến ánh sáng (Chuẩn 3.0.2)
  void _startLightSensor() async {
    if (await LightSensor.hasSensor()) {
      _lightSensorSubscription = LightSensor.luxStream().listen((lux) {
        if (!isAutoFlash) return; 

        if (lux < 10 && !isFlashOn) {
          controller.setFlashMode(FlashMode.torch);
          setState(() => isFlashOn = true);
        } 
        else if (lux > 15 && isFlashOn) {
          controller.setFlashMode(FlashMode.off);
          setState(() => isFlashOn = false);
        }
      });
    }
  }

  Future<void> yoloOnFrame(CameraImage cameraImage) async {
    this.cameraImage = cameraImage;
    final result = await vision.yoloOnFrame(
      bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
      imageHeight: cameraImage.height,
      imageWidth: cameraImage.width,
      iouThreshold: 0.4,
      confThreshold: 0.4,
      classThreshold: 0.4,
    );
    
    if (mounted) {
      screenSize = MediaQuery.of(context).size;
      if (result.isEmpty) lastSpokenTag = ""; 

      setState(() {
        yoloResults = result;
        for (var detection in result) {
           if ((detection['box'][4] ?? 0.0) > 0.6) {
             detectionHistory.insert(0, {'tag': detection['tag'], 'timestamp': DateTime.now()});
             if (detectionHistory.length > 50) detectionHistory.removeLast();
           }
        }
        isDetecting = false;
      });

      if (screenSize != null) {
        processVoiceSmart(result, screenSize!);
      }
    }
  }

  Future<void> processVoiceSmart(List<Map<String, dynamic>> results, Size screen) async {
    if (results.isEmpty || isSpeaking) return;

    Map<String, dynamic>? priorityObj;
    String priorityStatus = "";

    double imageWidth = cameraImage!.height.toDouble();
    double imageHeight = cameraImage!.width.toDouble();
    double scaleY = screen.height / imageHeight;

    for (var result in results) {
      dynamic box = result["box"];
      double y1 = box[1]; double y2 = box[3];
      if (box[2] < 2.0) { y1 *= imageHeight; y2 *= imageHeight; }
      
      double finalHeight = (y2 - y1) * scaleY;
      String distText = estimateDistance(finalHeight, screen.height, result['tag']);

      if (distText.contains("Rất gần")) {
        priorityObj = result;
        priorityStatus = "DANGER";
        
        // 📳 RUNG CẢNH BÁO (Dùng HapticFeedback có sẵn)
        if (DateTime.now().difference(lastDangerAlert).inMilliseconds > 1000) {
          // Rung mạnh 2 cái liên tiếp cho chú ý
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 150), () => HapticFeedback.heavyImpact());
          lastDangerAlert = DateTime.now();
        }
        break; 
      }
    }

    if (priorityObj == null && results.isNotEmpty) {
      priorityObj = results.first;
      priorityStatus = "NORMAL";
    }

    if (priorityObj != null) {
      String tag = priorityObj['tag'];
      if (tag == lastSpokenTag) return; 

      dynamic box = priorityObj["box"];
      double x1 = box[0]; double x2 = box[2];
      if (x2 < 2.0) { x1 *= imageWidth; x2 *= imageWidth; }
      double centerX = (x1 + x2) / 2;
      
      String position = "phía trước";
      if (centerX < imageWidth * 0.35) position = "bên trái";
      else if (centerX > imageWidth * 0.65) position = "bên phải";

      String vnName = dictionary[tag] ?? tag;
      String textToSay = "";

      if (priorityStatus == "DANGER") {
        textToSay = "Cẩn thận! $vnName $position, rất gần!";
      } else {
        textToSay = "Thấy $vnName $position";
      }

      lastSpokenTag = tag; 
      await _speak(textToSay);
    }
  }

  Future<void> _speak(String text) async {
    isSpeaking = true;
    await flutterTts.speak(text);
    await flutterTts.awaitSpeakCompletion(true);
    isSpeaking = false;
  }

  void toggleFlashMode() async {
    if (!isFlashOn && !isAutoFlash) {
      await controller.setFlashMode(FlashMode.torch);
      setState(() { isFlashOn = true; isAutoFlash = false; });
      _speak("Đèn bật");
    } else if (isFlashOn && !isAutoFlash) {
      setState(() { isFlashOn = false; isAutoFlash = true; }); 
      _speak("Chế độ đèn tự động");
    } else {
      await controller.setFlashMode(FlashMode.off);
      setState(() { isFlashOn = false; isAutoFlash = false; });
      _speak("Đèn tắt");
    }
  }

  void toggleEcoMode() {
    setState(() => isEcoMode = !isEcoMode);
    _speak(isEcoMode ? "Đã bật tiết kiệm pin" : "Đã tắt tiết kiệm pin");
  }

  void togglePause() {
    setState(() {
      isPaused = !isPaused;
      if (!isPaused) {
        yoloResults.clear();
        lastSpokenTag = "";
      }
    });
  }

  void goBack() => Navigator.pop(context);

  void showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(15),
            child: Text("LỊCH SỬ QUÉT", style: TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: detectionHistory.length,
              itemBuilder: (ctx, i) {
                var item = detectionHistory[i];
                String name = dictionary[item['tag']] ?? item['tag'];
                String time = "${item['timestamp'].hour}:${item['timestamp'].minute}:${item['timestamp'].second}";
                return ListTile(
                  leading: const Icon(Icons.history, color: Colors.white70),
                  title: Text(name, style: const TextStyle(color: Colors.white)),
                  trailing: Text(time, style: const TextStyle(color: Colors.grey)),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  String estimateDistance(double boxHeight, double screenHeight, String label) {
    double ratio = boxHeight / screenHeight; 
    double factor = 1.0;
    if (['person', 'door', 'refrigerator'].contains(label)) factor = 0.75; 
    else if (['cup', 'bottle', 'phone', 'mouse'].contains(label)) factor = 0.15; 
    else if (['tv', 'monitor', 'laptop'].contains(label)) factor = 0.6; 
    else factor = 0.55;

    double meters = factor / ratio;
    if (meters < 0.5) return "Rất gần (<0.5m) ⚠️";
    return "~${meters.toStringAsFixed(1)}m";
  }

  @override
  void dispose() {
    _lightSensorSubscription?.cancel();
    controller.dispose();
    vision.closeYoloModel();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. CAMERA
          LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              var scale = size.aspectRatio * controller.value.aspectRatio;
              if (scale < 1) scale = 1 / scale;
              return FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.previewSize?.height ?? 480,
                  height: controller.value.previewSize?.width ?? 640,
                  child: CameraPreview(controller),
                ),
              );
            },
          ),
          
          // 2. VẼ KHUNG
          if (!isEcoMode)
            LayoutBuilder(
               builder: (context, constraints) {
                 return Stack(
                   children: displayBoxesAroundRecognizedObjects(
                     Size(constraints.maxWidth, constraints.maxHeight)
                   ),
                 );
               }
            ),

          // 3. TIẾT KIỆM PIN
          if (isEcoMode)
            Container(
              color: Colors.black.withOpacity(0.9),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Icon(Icons.eco, color: Colors.green, size: 80), SizedBox(height: 10), Text("Đang chạy ngầm...", style: TextStyle(color: Colors.green, fontSize: 16))]),
              ),
            ),

          // 4. HEADER
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: goBack),
                  const Expanded(child: Text("ĐANG QUÉT...", textAlign: TextAlign.center, style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 10)]))),
                  IconButton(icon: const Icon(Icons.history, color: Colors.orange, size: 30), onPressed: showHistory),
                ],
              ),
            ),
          ),

          // 5. FOOTER
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: "flash",
                  backgroundColor: isAutoFlash ? Colors.blue : (isFlashOn ? Colors.yellow : Colors.grey),
                  onPressed: toggleFlashMode,
                  child: Icon(
                    isAutoFlash ? Icons.flash_auto : (isFlashOn ? Icons.flash_on : Icons.flash_off),
                    color: Colors.white
                  ),
                ),
                FloatingActionButton(
                  heroTag: "eco", backgroundColor: isEcoMode ? Colors.green : Colors.grey[800], onPressed: toggleEcoMode, child: const Icon(Icons.eco, color: Colors.white)
                ),
                FloatingActionButton(heroTag: "pause", backgroundColor: isPaused ? Colors.red : Colors.blue, onPressed: togglePause, child: Icon(isPaused ? Icons.play_arrow : Icons.pause)),
              ],
            ),
          )
        ],
      ),
    );
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty || cameraImage == null) return [];

    double imageWidth = cameraImage!.height.toDouble(); 
    double imageHeight = cameraImage!.width.toDouble(); 
    double scaleX = screen.width / imageWidth;
    double scaleY = screen.height / imageHeight;
    double scale = scaleX > scaleY ? scaleX : scaleY;
    double offsetX = (screen.width - imageWidth * scale) / 2;
    double offsetY = (screen.height - imageHeight * scale) / 2;

    return yoloResults.map((result) {
      dynamic box = result["box"];
      double x1 = box[0]; double y1 = box[1];
      double x2 = box[2]; double y2 = box[3];
      String tag = result['tag'];

      if (x2 < 2.0) { x1 *= imageWidth; x2 *= imageWidth; y1 *= imageHeight; y2 *= imageHeight; }

      double finalLeft = x1 * scale + offsetX;
      double finalTop = y1 * scale + offsetY;
      double finalWidth = (x2 - x1) * scale;
      double finalHeight = (y2 - y1) * scale;

      String distance = estimateDistance(finalHeight, screen.height, tag);
      Color boxColor = distance.contains("Rất gần") ? Colors.redAccent : Colors.cyanAccent;
      String vnName = dictionary[tag] ?? tag;

      double centerX = (x1 + x2) / 2;
      String posStr = "";
      if (centerX < imageWidth * 0.35) posStr = "⬅ Trái";
      else if (centerX > imageWidth * 0.65) posStr = "Phải ➡";
      
      return Positioned(
        left: finalLeft, top: finalTop, width: finalWidth, height: finalHeight,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: boxColor, width: 2.5)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: boxColor.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text("$vnName $posStr\n$distance", style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
  // --- HÀM GỬI VỊ TRÍ GPS ---
  Future<void> _startSharingLocation() async {
    // 1. Kiểm tra quyền GPS
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return; // Nếu từ chối thì thôi
    }

    // 2. Lấy ID người dùng hiện tại
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 3. Lắng nghe vị trí di chuyển (Real-time)
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, // Độ chính xác cao
        distanceFilter: 10, // Di chuyển 10m mới gửi tin 1 lần (tiết kiệm pin)
      ),
    ).listen((Position position) {
      // 4. Gửi tọa độ lên Firebase
      FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'location': {
          'lat': position.latitude,  // Vĩ độ
          'lng': position.longitude, // Kinh độ
          'timestamp': DateTime.now(), // Thời gian cập nhật
        },
        'status': 'online', // Đánh dấu đang online
      });
      print("📍 Đã cập nhật vị trí: ${position.latitude}, ${position.longitude}");
    });
  }
}
// ---------------------------------------------
// 🗺️ MÀN HÌNH BẢN ĐỒ (DÀNH CHO NGƯỜI THÂN)
// ---------------------------------------------

class TrackingScreen extends StatefulWidget {
  final String targetName; // Tên người cần theo dõi (ví dụ: thanh)
  const TrackingScreen({super.key, required this.targetName});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation; // Vị trí hiện tại của người khiếm thị
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _listenToLocation();
  }

  // Hàm lắng nghe dữ liệu từ Firebase
  void _listenToLocation() {
    // 1. Tìm trong danh sách users xem ai có tên giống targetName
    FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: widget.targetName)
        .limit(1) // Chỉ lấy 1 người
        .snapshots() // Lắng nghe liên tục (Real-time)
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data();
        if (data['location'] != null) {
          double lat = data['location']['lat'];
          double lng = data['location']['lng'];

          setState(() {
            _currentLocation = LatLng(lat, lng);
          });

          // Di chuyển camera đến vị trí mới (chỉ lần đầu hoặc khi bấm nút)
          if (_isFirstLoad) {
            _mapController.move(_currentLocation!, 15);
            _isFirstLoad = false;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Đang theo dõi: ${widget.targetName}"),
        backgroundColor: Colors.blue[900],
      ),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator()) // Đang tải...
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation!, // Vị trí ban đầu
                initialZoom: 15.0, // Độ phóng to
              ),
              children: [
                // 1. Lớp nền bản đồ (OpenStreetMap)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mat_ai_pro',
                ),
                // 2. Lớp Marker (Vị trí người thân)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 80,
                      height: 80,
                      child: const Column(
                        children: [
                          Icon(Icons.location_on, color: Colors.red, size: 40),
                          Text("Ở đây!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentLocation != null) {
            _mapController.move(_currentLocation!, 15); // Quay về vị trí
          }
        },
        backgroundColor: Colors.blue[900],
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}