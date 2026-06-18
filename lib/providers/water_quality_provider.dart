// ============================================================
// Provider: WaterQualityProvider
//
// Sumber data dapat dipilih:
//   DataSource.firebase  → data real dari Firebase (PRODUKSI)
//   DataSource.simulated → data dummy timer       (DEVELOPMENT)
//
// Ganti baris 'dataSource: DataSource.simulated' menjadi
// 'dataSource: DataSource.firebase' untuk switch ke Firebase.
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/water_quality_model.dart';
import '../utils/des_algorithm.dart';
import '../services/firebase_service.dart';

// ── Enum: pilihan sumber data ──────────────────────────────
enum DataSource { firebase, simulated }

// ── Enum: status koneksi ──────────────────────────────────
enum ConnectionStatus { connecting, connected, disconnected, error }

class WaterQualityProvider extends ChangeNotifier {

  // ==========================================================
  // KONFIGURASI — ubah di sini untuk switch Firebase ↔ simulasi
  // ==========================================================
  static const DataSource _dataSource = DataSource.firebase;

  // ── Konfigurasi DES ────────────────────────────────────────
  DESConfig _tempDesConfig = const DESConfig(alpha: 0.5, beta: 0.5);
  DESConfig _phDesConfig = const DESConfig(alpha: 0.5, beta: 0.5);
  DESConfig _turbDesConfig = const DESConfig(alpha: 0.5, beta: 0.5);

  DESConfig get tempDesConfig => _tempDesConfig;
  DESConfig get phDesConfig => _phDesConfig;
  DESConfig get turbDesConfig => _turbDesConfig;

  int _dataVersion = 0;
  int get dataVersion => _dataVersion;

  void updateTempDESConfig({required double alpha, required double beta}) {
    _tempDesConfig = DESConfig(
      alpha: alpha.clamp(0.01, 0.99),
      beta:  beta.clamp(0.01, 0.99),
    );
    _computeForecasts();
    _dataVersion++;
    notifyListeners();
  }

  void updatePhDESConfig({required double alpha, required double beta}) {
    _phDesConfig = DESConfig(
      alpha: alpha.clamp(0.01, 0.99),
      beta:  beta.clamp(0.01, 0.99),
    );
    _computeForecasts();
    _dataVersion++;
    notifyListeners();
  }

  void updateTurbDESConfig({required double alpha, required double beta}) {
    _turbDesConfig = DESConfig(
      alpha: alpha.clamp(0.01, 0.99),
      beta:  beta.clamp(0.01, 0.99),
    );
    _computeForecasts();
    _dataVersion++;
    notifyListeners();
  }

  // ── Data saat ini ──────────────────────────────────────────
  WaterQualityModel? _current;
  WaterQualityModel? get current => _current;

  // ── Riwayat data (maks 24 pembacaan) ─────────────────────
  final List<WaterQualityModel> _history = [];
  List<WaterQualityModel> get history => List.unmodifiable(_history);

  // ── Hasil DES ─────────────────────────────────────────────
  DESResult? _tempForecast;
  DESResult? _phForecast;
  DESResult? _turbForecast;

  DESResult? get tempForecast => _tempForecast;
  DESResult? get phForecast   => _phForecast;
  DESResult? get turbForecast => _turbForecast;

  List<double> get tempPredictions => _tempForecast?.forecast ?? [];
  List<double> get phPredictions   => _phForecast?.forecast   ?? [];
  List<double> get turbPredictions => _turbForecast?.forecast ?? [];

  // ── Status koneksi & loading ──────────────────────────────
  ConnectionStatus _connectionStatus = ConnectionStatus.connecting;
  ConnectionStatus get connectionStatus => _connectionStatus;

  bool get isLoading =>
      _connectionStatus == ConnectionStatus.connecting && _current == null;

  /// Pesan yang ditampilkan ke UI saat data belum tersedia.
  String get statusMessage {
    switch (_connectionStatus) {
      case ConnectionStatus.connecting:
        return 'Menunggu data...';
      case ConnectionStatus.disconnected:
        return 'Koneksi terputus. Memeriksa ulang...';
      case ConnectionStatus.error:
        return _lastError ?? 'Terjadi kesalahan. Coba lagi.';
      case ConnectionStatus.connected:
        return 'Terhubung';
    }
  }

  String? _lastError;

  // ── Internal ──────────────────────────────────────────────
  StreamSubscription<WaterQualityModel>? _firebaseSubscription;
  Timer? _simulationTimer;
  Timer? _firebaseFallbackTimer;
  final _random = Random();

  // ==========================================================
  // KONSTRUKTOR
  // ==========================================================
  WaterQualityProvider() {
    if (_dataSource == DataSource.firebase) {
      _startFirebaseListener();
    } else {
      _startSimulation();
    }
  }

  // ==========================================================
  // FIREBASE — listener real-time
  // ==========================================================
  void _startFirebaseListener() {
    _connectionStatus = ConnectionStatus.connecting;
    notifyListeners();

    _firebaseFallbackTimer?.cancel();
    _firebaseFallbackTimer = Timer(const Duration(seconds: 8), () {
      if (_current != null) return;
      _lastError = 'Firebase belum mengirim data valid. Menggunakan data simulasi sementara.';
      _connectionStatus = ConnectionStatus.disconnected;
      _startSimulation();
    });

    _firebaseSubscription = FirebaseService()
        .sensorStream()
        .listen(
          // ── Data masuk ──────────────────────────────────
          (model) async {
            _firebaseFallbackTimer?.cancel();
            _connectionStatus = ConnectionStatus.connected;
            _lastError = null;
            await _syncLiveAndHistory(model);
          },
          // ── Error koneksi / parse ────────────────────────
          onError: (Object error) {
            _lastError = error.toString();

            // Bedakan error koneksi vs error lainnya
            final msg = error.toString().toLowerCase();
            _connectionStatus = msg.contains('connection') ||
                    msg.contains('network') ||
                    msg.contains('failed host')
                ? ConnectionStatus.disconnected
                : ConnectionStatus.error;

            notifyListeners();
          },
          // ── Stream ditutup (jarang terjadi) ─────────────
          onDone: () {
            _connectionStatus = ConnectionStatus.disconnected;
            notifyListeners();
          },
          cancelOnError: false, // jangan hentikan stream saat error
        );
  }

  // ==========================================================
  // SIMULASI — data dummy timer (Development)
  // ==========================================================
  void _startSimulation() {
    _simulationTimer?.cancel();
    _connectionStatus = ConnectionStatus.connected;

    // Buat 13 data awal
    for (int i = 12; i >= 0; i--) {
      _addReading(_simulateReading(
        timestamp: DateTime.now().subtract(Duration(minutes: i * 5)),
      ));
    }

    // Refresh tiap 5 detik
    _simulationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _addReading(_simulateReading()),
    );
  }

  WaterQualityModel _simulateReading({DateTime? timestamp}) {
    final base = _history.isEmpty
        ? WaterQualityModel(
            temperature: 29.0,
            ph: 7.8,
            turbidity: 40.0,
            timestamp: DateTime.now(),
          )
        : _history.last;

    double clamp(double v, double lo, double hi) => v.clamp(lo, hi);

    return WaterQualityModel(
      temperature:
          clamp(base.temperature + (_random.nextDouble() * 1.0 - 0.5), 24, 35),
      ph:  clamp(base.ph + (_random.nextDouble() * 0.3 - 0.15), 6.5, 9.5),
      turbidity:
          clamp(base.turbidity + (_random.nextDouble() * 8.0 - 4.0), 0, 400),
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  // ==========================================================
  // SHARED — menambah pembacaan baru ke history
  // ==========================================================
  void _addReading(WaterQualityModel model) {
    if (_current?.hasSameSensorValues(model) ?? false) return;

    _history.add(model);
    if (_history.length > 24) _history.removeAt(0); // simpan 24 terakhir
    _current = model;
    _computeForecasts();
    _dataVersion++;
    notifyListeners();
  }

  Future<void> _syncLiveAndHistory(WaterQualityModel liveModel) async {
    final hasSameLiveValues = _current?.hasSameSensorValues(liveModel) ?? false;
    if (hasSameLiveValues && _history.isNotEmpty) return;

    try {
      final history = await FirebaseService().fetchLastHistory(limit: 24);
      _history
        ..clear()
        ..addAll(history);

      if (_history.isEmpty || !_history.last.hasSameSensorValues(liveModel)) {
        _history.add(liveModel);
      }
      if (_history.length > 24) {
        _history.removeRange(0, _history.length - 24);
      }

      _current = liveModel;
      _computeForecasts();
      _dataVersion++;
      notifyListeners();
    } catch (e) {
      _lastError = 'Gagal mengambil history Firebase: $e';
      _connectionStatus = ConnectionStatus.error;
      _addReading(liveModel);
    }
  }

  // ==========================================================
  // DES — hitung ulang setiap ada data baru
  // ==========================================================
  void _computeForecasts() {
    if (_history.length < 2) return;

    final temps   = _history.map((h) => h.temperature).toList();
    final phs     = _history.map((h) => h.ph).toList();
    final turbs   = _history.map((h) => h.turbidity).toList();

    // Interval sensor DIKUNCI 10 menit (lihat DESConfig.sensorInterval) agar
    // horizon prediksi selalu tepat 30 menit. Sebelumnya interval dideteksi
    // dari median jarak timestamp, tetapi data real-time yang tidak selalu
    // rapi 10 menit membuat label horizon ikut berubah-ubah (mis. "10 menit",
    // "40 menit"). Periode [3] × 10 menit = 30 menit.
    _tempForecast = DESAlgorithm.run(temps, config: _tempDesConfig);
    _phForecast = DESAlgorithm.run(phs, config: _phDesConfig);
    _turbForecast = DESAlgorithm.run(turbs, config: _turbDesConfig);
  }

  // ── Shortcut calculateDES() standalone ───────────────────
  List<double> getTempPredictions(List<double> dataHistoris) =>
      calculateDES(dataHistoris, config: _tempDesConfig);
  List<double> getPhPredictions(List<double> dataHistoris) =>
      calculateDES(dataHistoris, config: _phDesConfig);
  List<double> getTurbPredictions(List<double> dataHistoris) =>
      calculateDES(dataHistoris, config: _turbDesConfig);

  // ==========================================================
  // REFRESH MANUAL — dipanggil dari gesture tarik (pull-to-refresh)
  // ==========================================================
  /// Memuat ulang data dari sumber aktif.
  ///
  /// • Firebase  → re-subscribe listener agar live + history diambil ulang.
  /// • Simulasi  → tambahkan satu pembacaan baru.
  ///
  /// Mengembalikan [Future] agar bisa langsung dipakai pada
  /// `RefreshIndicator.onRefresh` di UI.
  Future<void> refresh() async {
    if (_dataSource == DataSource.firebase) {
      await _firebaseSubscription?.cancel();
      _firebaseSubscription = null;
      _startFirebaseListener();
      // Beri jeda singkat agar indikator refresh terlihat & data
      // sempat masuk kembali dari Firebase sebelum indikator hilang.
      await Future.delayed(const Duration(milliseconds: 700));
    } else {
      _addReading(_simulateReading());
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================
  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    _simulationTimer?.cancel();
    _firebaseFallbackTimer?.cancel();
    super.dispose();
  }
}
