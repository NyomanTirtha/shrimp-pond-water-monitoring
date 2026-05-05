import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  static const String _devicesPath = 'devices';
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _syncToken();

    _messaging.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    _initialized = true;
  }

  Future<void> _syncToken() async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final sanitized = token.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final deviceRef = FirebaseDatabase.instance.ref('$_devicesPath/$sanitized');

    await deviceRef.set({
      'fcmToken': token,
      'platform': Platform.operatingSystem,
      'updatedAt': ServerValue.timestamp,
    });
  }
}
