import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint("Notification tapped: ${details.payload}");
      },
    );

    // Request permissions (Android 13+)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Subscribe to the agency-wide topic
    await FirebaseMessaging.instance.subscribeToTopic('sparxtexh_agency');
    debugPrint("Subscribed to sparxtexh_agency topic");

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Foreground message received: ${message.notification?.title}");
      _showLocalNotification(message);
    });
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'agency_alerts',
      'Agency Alerts',
      channelDescription: 'Notifications for tasks, attendance, and month-closing',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF00FFA3), // Mint Green brand color
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformDetails,
      payload: message.data.toString(),
    );
  }
}

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for the background isolate
  // Note: DefaultFirebaseOptions is not imported here, but we can use the default or initialize without options if platform allows
  // For safety, we'll keep it simple as most devices don't strictly require options if google-services.json is present
  debugPrint("Background message received: ${message.notification?.title}");
}
