import 'services/token_storage.dart';
import 'services/session_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Bổ sung import
import 'screens/driver/driver_home.dart';
import 'app_theme.dart';
import 'screens/driver/driver_login_screen.dart';
import 'Screens/splash_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/firebase_notification_service.dart';

final _navigatorKey = GlobalKey<NavigatorState>();



void main() async { // THÊM TỪ KHÓA ASYNC

  // 1. Đảm bảo Flutter Widgets đã được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();
  // Khởi tạo firebase
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(
    FirebaseNotificationService.firebaseMessagingBackgroundHandler,
  );

  await FirebaseNotificationService.init();


  // Non-sensitive preferences remain here; credentials use TokenStorage.
  await SharedPreferences.getInstance();
  try {
    await TokenStorage.instance.readVehicleSession();
  } on TokenStorageException {
    // Keep the stored session; opening vehicle mode can retry later.
  }

  runApp(const BelucarApp());
}

class BelucarApp extends StatelessWidget {
  const BelucarApp({super.key});

  @override
  Widget build(BuildContext context) {
    SessionAuth.onExpired = () {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Do not navigate away from a newer login completed during cleanup.
        if (await TokenStorage.instance.readAccessToken() != null) return;
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
      });
    };
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      initialRoute: "/splash", // Luôn bắt đầu từ Splash Screen

      routes: {
        "/splash": (_) => const SplashScreen(),
        "/login": (_) => const DriverLoginScreen(),
        "/home": (_) => const DriverHomeScreen(),
      },
      // title: 'BeluCar',
      theme: AppTheme.theme,
      // home: const SplashScreen(), // Đã chuyển sang initialRoute
    );
  }
}
