import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

class NotificationService {
  static const String channelId = 'trip_channel';
  static const String channelName = 'TravelX Trip Notifications';
  static const String channelDescription =
      'Ongoing trip tracking, alerts, and travel updates';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize plugin & channel
  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (kDebugMode) {
        print('Tapped notification: ${response.payload}');
      }
    });

    // Create channel once
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max, // ⚡ Highest → banner + sound + dropdown
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    if (kDebugMode) {
      print('NotificationService initialized with channel: $channelId');
    }
  }

  /// Show/update ongoing notification (persistent, interactive)
  static Future<void> showOngoing(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true, // 🔒 persistent
      autoCancel: false,
      enableVibration: true,
      playSound: true,
      showWhen: true,
      category: AndroidNotificationCategory.service,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'STOP_TRIP',
          'Stop Trip',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
      styleInformation: BigTextStyleInformation(''), // supports long body text
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _plugin.show(
      0, // fixed ID → updates ongoing instead of stacking
      title,
      body,
      details,
      payload: 'ongoing',
    );

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 300, 200, 300]);
    }
  }

  /// Show one-shot alert (dismissible)
  static Future<void> showOneShot(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      autoCancel: true,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique ID
      title,
      body,
      details,
      payload: 'oneshot',
    );

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500);
    }
  }

  /// Cancel ongoing trip notification
  static Future<void> cancelOngoing() async {
    await _plugin.cancel(0);
    if (kDebugMode) print('Cancelled ongoing trip notification');
  }
}
