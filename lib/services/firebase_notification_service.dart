import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseNotificationService {
  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'High Importance Notifications';
  static const String _channelDescription = 'Notifications for driver updates';
  static const String _androidNotificationIcon = 'app_icon';

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNoti =
      FlutterLocalNotificationsPlugin();

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    await Firebase.initializeApp();
    print('[BG] Message received: ${message.messageId}');
  }

  static Future<void> init() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    try {
      await _messaging.subscribeToTopic('drivers');
      print('[FCM] Subscribed to topic: drivers');
    } catch (e) {
      print('[FCM] Failed to subscribe topic: $e');
    }

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
    );

    await _localNoti
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    const androidInit = AndroidInitializationSettings(_androidNotificationIcon);
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNoti.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (details) {},
    );

    FirebaseMessaging.onMessage.listen(_onMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
  }

  static Future<String?> getDeviceToken() async {
    try {
      final String? token = await _messaging.getToken();
      print('[FCM] Token: $token');
      return token;
    } catch (e) {
      print('[FCM] Failed to get token: $e');
      return null;
    }
  }

  static Future<void> _onMessage(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    final String? title =
        notification?.title ?? message.data['title']?.toString();
    final String? body = notification?.body ?? message.data['body']?.toString();

    if (title == null && body == null) {
      print('[FG] Message received without title/body');
      return;
    }

    try {
      await _localNoti.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            icon: _androidNotificationIcon,
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      print('[FG] Failed to show local notification: $e');
    }

    print('[FG] Received: $title');
  }

  static void _onMessageOpened(RemoteMessage message) {
    print('[OPEN] Notification tapped: ${message.notification?.title}');
  }
}
