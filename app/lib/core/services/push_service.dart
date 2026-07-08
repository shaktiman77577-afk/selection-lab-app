// lib/core/services/push_service.dart
//
// Firebase Cloud Messaging: permission request, "all_users" topic subscribe,
// foreground/background/terminated notification handling, and tap-to-navigate
// using the same course/mock/descriptive/url action system as hero slides.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import '../navigation/nav_key.dart';
import '../network/api_service.dart';
import '../../presentation/screens/courses/course_detail_screen.dart';
import '../../presentation/screens/mock/mock_series_detail_screen.dart';
import '../../presentation/screens/descriptive/descriptive_series_detail_screen.dart';

const String _kChannelId = 'high_importance_channel';
const String _kChannelName = 'General Notifications';

final FlutterLocalNotificationsPlugin _localNotifs =
    FlutterLocalNotificationsPlugin();

/// Must be top-level (required by FCM for background isolate handling).
/// The system tray already shows background/terminated notifications
/// automatically (FCM payload includes a "notification" block) — nothing
/// else is needed here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifs.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(jsonDecode(payload));
          _handleNavigation(data);
        } catch (_) {}
      },
    );

    const channel = AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: 'Selection Lab updates and announcements',
      importance: Importance.high,
    );
    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Every install joins the broadcast topic — no device-token DB needed.
    await messaging.subscribeToTopic('all_users');

    // Foreground: FCM does not auto-show a banner, so we show one ourselves.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifs.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });

    // App was backgrounded, user tapped the system notification.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNavigation(message.data);
    });

    // App was fully closed; user tapped the notification that launched it.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleNavigation(initialMessage.data);
      });
    }
  }

  static Future<void> _handleNavigation(Map<String, dynamic> data) async {
    final type = (data['type'] ?? '').toString();
    final targetId = (data['target_id'] ?? '').toString();
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    switch (type) {
      case 'mock':
        final id = int.tryParse(targetId);
        if (id != null) {
          nav.push(MaterialPageRoute(
              builder: (_) => MockSeriesDetailScreen(seriesId: id)));
        }
        break;
      case 'descriptive':
        final id = int.tryParse(targetId);
        if (id != null) {
          nav.push(MaterialPageRoute(
              builder: (_) => DescriptiveSeriesDetailScreen(seriesId: id)));
        }
        break;
      case 'course':
        final id = int.tryParse(targetId);
        if (id != null) {
          try {
            final res = await ApiService.get('/courses/$id');
            final course = (res is Map && res['course'] != null)
                ? Map<String, dynamic>.from(res['course'])
                : Map<String, dynamic>.from(res as Map);
            nav.push(MaterialPageRoute(
                builder: (_) => CourseDetailScreen(course: course)));
          } catch (_) {}
        }
        break;
      case 'url':
        if (targetId.trim().isNotEmpty) {
          final uri = Uri.tryParse(targetId.trim());
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        break;
      default:
        break;
    }
  }
}
