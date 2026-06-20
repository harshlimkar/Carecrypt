import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  FirebaseMessaging? get _fcm => kIsWeb ? null : FirebaseMessaging.instance;
  RealtimeChannel? _realtimeChannel;

  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notifications => _notificationController.stream;

  Future<void> initialize() async {
    if (kIsWeb) return;
    // Request FCM permissions
    await _fcm?.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Local notifications init
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel
    const channel = AndroidNotificationChannel(
      'carecrypt_alerts',
      'CareCrypt Alerts',
      description: 'Healthcare security notifications',
      importance: Importance.high,
      enableVibration: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // FCM foreground handler
    FirebaseMessaging.onMessage.listen(_handleFcmMessage);
  }

  Future<void> subscribeToUserNotifications(String userId) async {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = Supabase.instance.client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            _notificationController.add(newRecord);
            _showLocalNotification(newRecord);
          },
        )
        .subscribe();
  }

  Future<void> _handleFcmMessage(RemoteMessage message) async {
    _notificationController.add(message.data);
    await _showLocalNotification({
      'type': message.data['type'] ?? 'alert',
      'message': message.notification?.body ?? message.data['message'] ?? '',
    });
  }

  Future<void> _showLocalNotification(Map<String, dynamic> data) async {
    if (kIsWeb) return;
    final type = data['type'] as String? ?? 'alert';
    final message = data['message'] as String? ?? 'You have a new notification';

    final (title, icon) = switch (type) {
      'lab_request' => ('Lab Request', '🔬'),
      'lab_approved' => ('Lab Request Approved', '✅'),
      'report_uploaded' => ('Lab Report Ready', '📋'),
      'prescription_generated' => ('New Prescription', '💊'),
      'medicine_dispensed' => ('Medicine Dispensed', '✅'),
      'treatment_updated' => ('Treatment Updated', '🩺'),
      'diagnosis_updated' => ('Diagnosis Updated', '📝'),
      'security_alert' => ('⚠️ Security Alert', '🚨'),
      _ => ('CareCrypt', '🔔'),
    };

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '$icon $title',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'carecrypt_alerts',
          'CareCrypt Alerts',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    // Navigate based on notification type (handled by router)
  }

  Future<void> unsubscribe() async {
    await _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  void dispose() {
    _notificationController.close();
    unsubscribe();
  }
}
