import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Background handler (harus top-level function) ──────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages ditangani otomatis oleh sistem (notification payload).
  // Simpan ke history lokal saat user buka app berikutnya via _syncFromPayload.
}

class WarningThreshold {
  static const double tempMin = 26.0;
  static const double tempMax = 32.0;
  static const double phMin = 7.5;
  static const double phMax = 8.5;
}

enum NotificationHistoryType { danger, warning }

class NotificationHistoryItem {
  final String message;
  final NotificationHistoryType type;
  final DateTime timestamp;
  final bool isRead;

  const NotificationHistoryItem({
    required this.message,
    required this.type,
    required this.timestamp,
    required this.isRead,
  });

  factory NotificationHistoryItem.fromJson(Map<String, dynamic> json) {
    return NotificationHistoryItem(
      message: json['message'] as String? ?? '',
      type: (json['type'] as String? ?? '') == NotificationHistoryType.warning.name
          ? NotificationHistoryType.warning
          : NotificationHistoryType.danger,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  NotificationHistoryItem copyWith({bool? isRead}) {
    return NotificationHistoryItem(
      message: message,
      type: type,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _channelId = 'early_warning_channel';
  static const String _channelName = 'Early Warning System';
  static const String _channelDescription =
      'Notifikasi bahaya dan peringatan dini kualitas air tambak';
  static const String _historyKey = 'notification_history';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  bool _initialized = false;

  Stream<int> get unreadCountStream => _unreadCountController.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    // ── Local notification plugin (untuk tampilkan FCM saat foreground) ──
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );
    await _notifications.initialize(initializationSettings);

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();

    // ── FCM background handler ──────────────────────────────
    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);

    // ── FCM foreground handler ──────────────────────────────
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // ── Handle message saat app dibuka dari notif ───────────
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // ── Cek initial message (app terminated → tap notif) ────
    final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _saveMessageToHistory(initialMessage);
    }

    _initialized = true;
    await refreshUnreadCount();
  }

  // ── Foreground: tampilkan local notif + simpan history ────
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _saveMessageToHistory(message);

    final data = message.data;
    final notification = message.notification;
    final title = notification?.title ?? data['title']?.toString() ?? 'AquaMonitor';
    final body = notification?.body ?? data['body']?.toString() ?? '';
    if (body.isEmpty) return;

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  // ── Saat user tap notif dari background ───────────────────
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    await _saveMessageToHistory(message);
  }

  // ── Simpan FCM payload ke SharedPreferences history ───────
  Future<void> _saveMessageToHistory(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;

    final body = notification?.body ?? data['body'] ?? '';
    if (body.isEmpty) return;

    final typeStr = data['type'] ?? 'danger';
    final type = typeStr == 'warning'
        ? NotificationHistoryType.warning
        : NotificationHistoryType.danger;

    final tsRaw = data['timestamp'];
    final timestamp = tsRaw != null
        ? DateTime.fromMillisecondsSinceEpoch(int.tryParse(tsRaw) ?? 0)
        : DateTime.now();

    final item = NotificationHistoryItem(
      message: body,
      type: type,
      timestamp: timestamp,
      isRead: false,
    );

    await _addHistoryItem(item);
  }

  // ── History CRUD (sama seperti sebelumnya) ────────────────
  Future<List<NotificationHistoryItem>> getHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final rawItems =
        preferences.getStringList(_historyKey) ?? const <String>[];

    final items = rawItems
        .map((raw) {
          try {
            return NotificationHistoryItem.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<NotificationHistoryItem>()
        .toList();

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  Future<void> markAllAsRead() async {
    final items = await getHistory();
    await _saveHistory(
        items.map((item) => item.copyWith(isRead: true)).toList());
  }

  Future<void> clearHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_historyKey);
    _unreadCountController.add(0);
  }

  Future<void> refreshUnreadCount() async {
    final history = await getHistory();
    _unreadCountController.add(history.where((item) => !item.isRead).length);
  }

  Future<int> getUnreadCount() async {
    final history = await getHistory();
    return history.where((item) => !item.isRead).length;
  }

  Future<void> _addHistoryItem(NotificationHistoryItem item) async {
    final history = await getHistory();
    final updated = [item, ...history].take(100).toList();
    await _saveHistory(updated);
  }

  Future<void> _saveHistory(List<NotificationHistoryItem> items) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _historyKey,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
    _unreadCountController.add(items.where((item) => !item.isRead).length);
  }
}
