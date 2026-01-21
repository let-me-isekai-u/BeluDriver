import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart'; //debugPrint

// Hàm ghi nhật ký (Log) đơn giản để dễ theo dõi trong Terminal
void appLog(String tag, String msg) {
  debugPrint('[$tag] $msg');
}


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {

  // --- Animation Controllers ---
  late AnimationController _logoController;
  late Animation<double> _scaleAnimation;

  static const Duration _minDisplayDuration = Duration(seconds: 3);
  late final DateTime _splashStart;

  @override
  void initState() {
    super.initState();
    appLog('SPLASH', 'initState called. Setting up animations.');

    _splashStart = DateTime.now();


    // Khởi tạo Animation cho hiệu ứng Logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // Bắt đầu kiểm tra xác thực ngay khi màn hình được tạo
    _checkAuth();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _ensureMinDisplay() async {
    final elapsed = DateTime.now().difference(_splashStart);
    if (elapsed < _minDisplayDuration){
      await Future.delayed(_minDisplayDuration - elapsed);
    }
  }

  // LOGIC KIỂM TRA XÁC THỰC
  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString("accessToken"); // Lấy cả Access Token
    final refreshToken = prefs.getString("refreshToken");

    appLog('AUTH', '--- Starting Token Check ---');
    appLog('AUTH', 'Access Token Exists: ${accessToken != null}');
    appLog('AUTH', 'Refresh Token Exists: ${refreshToken != null}');

    // Thêm delay 1.5 giây để người dùng kịp thấy Splash Screen
    await Future.delayed(const Duration(milliseconds: 1500));

    // BƯỚC 1: CÓ ACCESS TOKEN → VERIFY
    if (accessToken != null) {
      appLog('AUTH', 'Found Access Token -> Verifying...');

      try {
        final res = await ApiService.getDriverProfile(accessToken: accessToken);

        if (res.statusCode == 200) {
          appLog('AUTH', 'Access Token VALID -> Go to Home.');
          await _ensureMinDisplay();
          _goToHome();
          return;
        }

        // Token sai / hết hạn
        if (res.statusCode == 401) {
          appLog('AUTH', 'Access Token EXPIRED -> Try Refresh.');
          await prefs.remove("accessToken");
          // rơi xuống bước refresh
        }
      } catch (e) {
        appLog('AUTH', 'Verify token ERROR: $e');
        await prefs.remove("accessToken");
      }
    }

    // BƯỚC 2: KIỂM TRA REFRESH TOKEN
    if (refreshToken == null) {
      // Không có cả hai token -> Bắt đăng nhập
      appLog('AUTH', 'No tokens found -> Go to Login.');
      _goToLogin();
      return;
    }

    // BƯỚC 3: GỌI API REFRESH
    // Nếu không có Access Token nhưng có Refresh Token -> Thử làm mới
    appLog('AUTH', 'Access Token missing, attempting Refresh Token...');

    try {
      final res = await ApiService.refreshToken(refreshToken: refreshToken);
      appLog('AUTH', 'Refresh API Status: ${res.statusCode}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        final newAccessToken = data["accessToken"];
        final newRefreshToken = data["refreshToken"];

        if (newAccessToken != null && newRefreshToken != null) {
          await prefs.setString("accessToken", newAccessToken);
          await prefs.setString("refreshToken", newRefreshToken);
          appLog('AUTH', 'Refresh SUCCESS -> New tokens saved -> Go to Home.');
          await _ensureMinDisplay();
          _goToHome();
          return;
        } else {
          // 200 Ok nhưng token mới bị thiếu trong body
          appLog('AUTH', 'Refresh 200 but missing new tokens in body. Clearing tokens -> Go to Login.');
          _goToLoginAndClear(prefs);
          return;
        }
      } else {
        // Lỗi Refresh: 401, 403, 500
        String message = "Unknown Error";
        try {
          final errorBody = jsonDecode(res.body);
          message = errorBody["message"] ?? message;
        } catch (_) {}
        appLog('AUTH', 'Refresh FAILED (${res.statusCode}): $message. Clearing tokens -> Go to Login.');
        _goToLoginAndClear(prefs);
      }
    } catch (e) {
      // Lỗi kết nối mạng, timeout, hoặc lỗi parse JSON
      appLog('AUTH', 'Refresh ERROR (Network/Parsing): $e. Clearing tokens -> Go to Login.');
      _goToLoginAndClear(prefs);
    }
  }

  // Hàm dọn dẹp token và chuyển hướng
  Future<void> _goToLoginAndClear(SharedPreferences prefs) async {
    await prefs.remove("accessToken");
    await prefs.remove("refreshToken");
    _goToLogin();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/login");
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/home");
  }


  // Trong _SplashScreenState
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset(
          'lib/assets/tet_splash.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

}