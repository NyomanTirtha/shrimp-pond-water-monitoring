import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/water_quality_model.dart';
import '../utils/des_algorithm.dart';

class WarningThreshold {
  static const double tempMin = 26.0;
  static const double tempMax = 32.0;
  static const double phMin = 7.5;
  static const double phMax = 8.5;
  static const double turbidityMin = 30.0;
  static const double turbidityMax = 100.0;
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

  static const Duration _cooldown = Duration(minutes: 5);
  static const String _channelId = 'early_warning_channel';
  static const String _channelName = 'Early Warning System';
  static const String _channelDescription =
      'Notifikasi bahaya dan peringatan dini kualitas air tambak';
  static const String _historyKey = 'notification_history';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Map<String, DateTime> _lastShownAt = {};
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  bool _initialized = false;

  Stream<int> get unreadCountStream => _unreadCountController.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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

    _initialized = true;
    await refreshUnreadCount();
  }

  Future<List<NotificationHistoryItem>> getHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final rawItems = preferences.getStringList(_historyKey) ?? const <String>[];

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
    await _saveHistory(items.map((item) => item.copyWith(isRead: true)).toList());
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

  Future<void> checkLiveReading(WaterQualityModel data) async {
    await initialize();

    if (data.temperature < WarningThreshold.tempMin ||
        data.temperature > WarningThreshold.tempMax) {
      await _showWithCooldown(
        key: 'live_temperature',
        title: 'Bahaya: Suhu Air Tidak Aman',
        body:
            'Suhu saat ini ${data.temperature.toStringAsFixed(1)}°C, di luar batas aman 26-32°C.',
        type: NotificationHistoryType.danger,
      );
    }

    if (data.ph < WarningThreshold.phMin || data.ph > WarningThreshold.phMax) {
      await _showWithCooldown(
        key: 'live_ph',
        title: 'Bahaya: pH Air Tidak Aman',
        body:
            'pH saat ini ${data.ph.toStringAsFixed(2)}, di luar batas aman 7.5-8.5.',
        type: NotificationHistoryType.danger,
      );
    }

    if (data.turbidity < WarningThreshold.turbidityMin || data.turbidity > WarningThreshold.turbidityMax) {
      await _showWithCooldown(
        key: 'live_turbidity',
        title: 'Bahaya: Kekeruhan Tinggi',
        body:
            'Kekeruhan saat ini ${data.turbidity.toStringAsFixed(1)} NTU, melebihi batas aman 30 NTU.',
        type: NotificationHistoryType.danger,
      );
    }
  }

  Future<void> checkForecasts({
    required DESResult? tempForecast,
    required DESResult? phForecast,
    required DESResult? turbidityForecast,
  }) async {
    await initialize();

    await _checkForecastRange(
      key: 'forecast_temperature',
      parameterName: 'Suhu',
      unit: '°C',
      forecast: tempForecast,
      min: WarningThreshold.tempMin,
      max: WarningThreshold.tempMax,
      decimals: 1,
    );

    await _checkForecastRange(
      key: 'forecast_ph',
      parameterName: 'pH',
      unit: '',
      forecast: phForecast,
      min: WarningThreshold.phMin,
      max: WarningThreshold.phMax,
      decimals: 2,
    );

    await _checkForecastRange(
      key: 'forecast_turbidity',
      parameterName: 'Kekeruhan',
      unit: 'NTU',
      forecast: turbidityForecast,
      min: WarningThreshold.turbidityMin,
      max: WarningThreshold.turbidityMax,
      decimals: 1,
    );
  }

  Future<void> _checkForecastRange({
    required String key,
    required String parameterName,
    required String unit,
    required DESResult? forecast,
    double? min,
    double? max,
    required int decimals,
  }) async {
    final values = forecast?.forecast ?? const <double>[];

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final belowMin = min != null && value < min;
      final aboveMax = max != null && value > max;

      if (!belowMin && !aboveMax) continue;

      final formattedValue = value.toStringAsFixed(decimals);
      final unitSuffix = unit.isEmpty ? '' : unit;
      final direction = belowMin ? 'turun ke' : 'menyentuh';
      final offset = i < (forecast?.forecastOffsets.length ?? 0)
          ? forecast!.forecastOffsets[i]
          : Duration(minutes: (i + 1) * 10);
      final offsetText = offset.inMinutes >= 60
          ? '${offset.inHours} jam ${offset.inMinutes % 60} menit'
          : '${offset.inMinutes} menit';

      await _showWithCooldown(
        key: key,
        title: 'Peringatan Dini: $parameterName',
        body:
            'Peringatan Dini: $parameterName diprediksi akan $direction $formattedValue$unitSuffix dalam $offsetText ke depan!',
        type: NotificationHistoryType.warning,
      );
      return;
    }
  }

  Future<void> _showWithCooldown({
    required String key,
    required String title,
    required String body,
    required NotificationHistoryType type,
  }) async {
    final now = DateTime.now();
    final lastShown = _lastShownAt[key];

    if (lastShown != null && now.difference(lastShown) < _cooldown) return;

    _lastShownAt[key] = now;
    await _addHistoryItem(
      NotificationHistoryItem(
        message: body,
        type: type,
        timestamp: now,
        isRead: false,
      ),
    );

    await _notifications.show(
      key.hashCode & 0x7fffffff,
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
