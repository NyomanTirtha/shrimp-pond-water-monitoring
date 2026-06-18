// ============================================================
// Service: FirebaseService
// Menghubungkan aplikasi ke Firebase Realtime Database.
//
// Struktur data di Firebase yang diharapkan:
//
//   smart_buoy/
//   ├── live/
//   │   ├── temp    : 29.5
//   │   ├── pH      : 7.8
//   │   ├── turb    : 42.0    (NTU)
//   │   ├── kondisi : "Keruh" (label kualitatif, opsional)
//   │   └── ts      : 1714920000000
//   └── history/
//       └── -PushIdRandom/
//           ├── temp
//           ├── pH
//           ├── turb
//           └── ts
//
// Ubah kLivePath / kHistoryPath jika struktur Firebase Anda berbeda.
// ============================================================

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/water_quality_model.dart';

/// Path root di Firebase Realtime Database.
const String kLivePath = 'smart_buoy/live';
const String kHistoryPath = 'smart_buoy/history';

class FirebaseService {
  // Singleton — satu instance untuk seluruh app
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final DatabaseReference _liveRef =
      FirebaseDatabase.instance.ref(kLivePath);
  final DatabaseReference _historyRef =
      FirebaseDatabase.instance.ref(kHistoryPath);

  // ── Stream real-time ─────────────────────────────────────
  /// Mengembalikan [Stream<WaterQualityModel>] yang memancarkan
  /// data baru setiap kali nilai sensor berubah di Firebase.
  ///
  /// Error handling:
  ///   • Jika data null / field kosong → event tidak dipancarkan.
  ///   • Jika koneksi terputus → stream otomatis resume saat online.
  Stream<WaterQualityModel> sensorStream() {
    return liveStream();
  }

  Stream<WaterQualityModel> liveStream() {
    return _liveRef.onValue.transform(
      StreamTransformer.fromHandlers(
        handleData: (event, sink) {
          try {
            final data = event.snapshot.value;

            // ── Validasi: data harus ada dan berupa Map ────
            if (data == null) {
              sink.addError('Firebase data kosong di path: $kLivePath');
              return;
            }
            if (data is! Map) {
              sink.addError('Format data Firebase tidak valid di path: $kLivePath');
              return;
            }
            final map = Map<String, dynamic>.from(data);

            // ── Validasi: field wajib harus ada ───────────
            if (!map.containsKey('temp') ||
                !map.containsKey('pH')) {
              sink.addError(
                'Field Firebase wajib tidak lengkap. Butuh: temp, pH',
              );
              return;
            }

            sink.add(_modelFromSmartBuoyMap(map));
          } catch (e) {
            // Jangan propagate error agar stream tidak berhenti
            // Error dicatat di provider melalui onError
            sink.addError('Firebase parse error: $e');
          }
        },
        handleError: (error, stackTrace, sink) {
          sink.addError('Firebase connection error: $error');
        },
      ),
    );
  }

  Future<List<WaterQualityModel>> fetchLastHistory({int limit = 10}) async {
    final snapshot = await _historyRef.limitToLast(limit).get();
    final data = snapshot.value;

    if (data == null || data is! Map) {
      return [_defaultReading()];
    }

    final readings = <WaterQualityModel>[];
    final entries = data.entries.toList();

    for (final entry in entries) {
      final value = entry.value;
      if (value is! Map) continue;

      try {
        readings.add(_modelFromSmartBuoyMap(Map<String, dynamic>.from(value)));
      } catch (_) {
        continue;
      }
    }

    readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return readings.isEmpty ? [_defaultReading()] : readings;
  }

  List<double> historyTemperatures(List<WaterQualityModel> history) {
    if (history.isEmpty) return [_defaultReading().temperature];
    return history.map((reading) => reading.temperature).toList();
  }

  // ── Utilitas: konversi aman ke double ────────────────────
  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toMilliseconds(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static WaterQualityModel _modelFromSmartBuoyMap(Map<String, dynamic> map) {
    final timestamp = _toMilliseconds(map['ts']);

    return WaterQualityModel(
      temperature: _toDouble(map['temp']),
      ph: _toDouble(map['pH']),
      // turb opsional agar kompatibel dengan data history lama (tanpa turbidity).
      turbidity: _toDouble(map['turb']),
      timestamp: timestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : DateTime.now(),
    );
  }

  static WaterQualityModel _defaultReading() {
    return WaterQualityModel(
      temperature: 29.0,
      ph: 7.8,
      turbidity: 20.0,
      timestamp: DateTime.now(),
    );
  }

  // ── Tulis data (untuk testing / debugging) ───────────────
  /// Gunakan ini untuk mengirim data dummy ke Firebase
  /// saat hardware IoT belum siap.
  Future<void> writeDummyData({
    required double suhu,
    required double ph,
    required double turbidity,
  }) async {
    await _liveRef.set({
      'temp': suhu,
      'pH': ph,
      'turb': turbidity,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
