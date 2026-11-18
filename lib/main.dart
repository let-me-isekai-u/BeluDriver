import 'services/token_storage.dart';
import 'services/session_auth.dart';
import 'services/driver_session_navigation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Bổ sung import
import 'screens/driver/driver_home.dart';
import 'app_theme.dart';
import 'screens/driver/driver_login_screen.dart';
import 'screens/splash_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/firebase_notification_service.dart';

final _navigatorKey = GlobalKey<NavigatorState>();
final _sessionNavigation = DriverSessionNavigation();

void main() async {
  // THÊM TỪ KHÓA ASYNC

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
    SessionAuth.onExpired = _sessionNavigation.driverExpired;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_sessionNavigation],
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
