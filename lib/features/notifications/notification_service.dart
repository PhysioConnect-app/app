import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_strings.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  static Future<void> initialize() async {
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Do NOT request permissions on init — show our own rationale dialog first.
    const initDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: initAndroid,
      iOS: initDarwin,
    );
    await _localNotifications.initialize(initSettings);
  }

  /// Shows a rationale dialog, then requests iOS permission only if the user
  /// taps Allow. Call this once after the user has seen the dashboard.
  static Future<void> requestPermissionsWithExplanation(
    BuildContext context,
    AppStrings s,
  ) async {
    final allowed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(s.notifPermTitle),
        content: Text(s.notifPermBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.notifPermNotNow),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.notifPermAllow),
          ),
        ],
      ),
    );
    if (allowed != true) return;

    final iosPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  static Future<void> showLocalReminder({
    required String title,
    required String body,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'physio_channel',
          'PhysioConnect Alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> saveFcmToken(String? token) async {
    if (token == null) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token}).eq('id', uid);
    } catch (_) {}
  }
}
