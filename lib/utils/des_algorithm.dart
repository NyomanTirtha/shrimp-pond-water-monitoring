// ============================================================
// Utility: Double Exponential Smoothing (DES)
// Method: Holt's Linear Trend Method
//
// Rumus (untuk skripsi):
//   Level:    L_t = α · y_t + (1 − α) · (L_{t−1} + T_{t−1})
//   Trend:    T_t = β · (L_t − L_{t−1}) + (1 − β) · T_{t−1}
//   Forecast: ŷ_{t+m} = L_t + m · T_t
//
// Parameter:
//   alpha (α): faktor pemulusan level  [0 < α < 1]
//   beta  (β): faktor pemulusan tren   [0 < β < 1]
// ============================================================

// ─── Konfigurasi parameter DES ─────────────────────────────
// Ubah nilai di sini untuk menyesuaikan alpha/beta skripsi Anda.
class DESConfig {
  final double alpha;
  final double beta;
  final List<int> forecastPeriods;
  final Duration sensorInterval;

  const DESConfig({
    this.alpha  = 0.5,  // default sesuai spesifikasi
    this.beta   = 0.5,
    this.forecastPeriods = const [3, 6, 9],
    this.sensorInterval = const Duration(minutes: 10),
  }) : assert(alpha > 0 && alpha < 1, 'alpha harus antara 0 dan 1'),
       assert(beta  > 0 && beta  < 1, 'beta harus antara 0 dan 1');

  int get periods => forecastPeriods.length;

  /// Salinan config dengan sebagian field diganti.
  DESConfig copyWith({
    double? alpha,
    double? beta,
    List<int>? forecastPeriods,
    Duration? sensorInterval,
  }) {
    return DESConfig(
      alpha: alpha ?? this.alpha,
      beta: beta ?? this.beta,
      forecastPeriods: forecastPeriods ?? this.forecastPeriods,
      sensorInterval: sensorInterval ?? this.sensorInterval,
    );
  }
}

// ─── Model hasil DES ──────────────────────────────────────
class DESResult {
  /// Nilai fitted (hasil smoothing) untuk data historis.
  final List<double> smoothedValues;

  /// Nilai prediksi m periode ke depan (F+1 … F+periods).
  final List<double> forecast;

  final double alpha;
  final double beta;
  final List<int> forecastPeriods;
  final Duration sensorInterval;

  const DESResult({
    required this.smoothedValues,
    required this.forecast,
    required this.alpha,
    required this.beta,
    required this.forecastPeriods,
    required this.sensorInterval,
  });

  List<Duration> get forecastOffsets {
    return forecastPeriods.map((m) => sensorInterval * m).toList();
  }
}

// ─── Fungsi utama: calculateDES ───────────────────────────
// Menerima List<double> dataHistoris dan mengembalikan
// List<double> dataPrediksi (F+1 … F+periods).
//
// Keamanan data:
//   • Jika dataHistoris < 2, kembalikan list kosong (tidak crash).
//   • Nilai prediksi tidak diclamp agar grafik tetap jujur.
//
List<double> calculateDES(
  List<double> dataHistoris, {
  DESConfig config = const DESConfig(),
}) {
  // ── Validasi keamanan data ─────────────────────────────
  if (dataHistoris.length < 2) return [];

  final result = DESAlgorithm.run(dataHistoris, config: config);
  return result.forecast;
}

// ─── Kelas DESAlgorithm (inti komputasi) ──────────────────
class DESAlgorithm {
  /// Jalankan DES pada [data] menggunakan konfigurasi [config].
  ///
  /// Mengembalikan [DESResult] berisi smoothed history + forecast.
  static DESResult run(
    List<double> data, {
    DESConfig config = const DESConfig(),
  }) {
    // ── Validasi — kembalikan kosong daripada crash ────────
    if (data.length < 2) {
      return DESResult(
        smoothedValues: [],
        forecast: [],
        alpha: config.alpha,
        beta: config.beta,
        forecastPeriods: config.forecastPeriods,
        sensorInterval: config.sensorInterval,
      );
    }

    final double alpha   = config.alpha;
    final double beta    = config.beta;
    final forecastPeriods = config.forecastPeriods;

    // ── Inisialisasi (Holt's method) ──────────────────────
    // L_1 = y_1
    // T_1 = y_2 − y_1  (estimasi tren awal)
    double level = data[0];
    double trend = data[1] - data[0];

    final List<double> smoothed = [];

    // ── Iterasi smoothing ──────────────────────────────────
    for (int t = 0; t < data.length; t++) {
      final double prevLevel = level;
      final double prevTrend = trend;

      // L_t = α · y_t + (1 − α) · (L_{t−1} + T_{t−1})
      level = alpha * data[t] + (1 - alpha) * (level + trend);

      // T_t = β · (L_t − L_{t−1}) + (1 − β) · T_{t−1}
      trend = beta * (level - prevLevel) + (1 - beta) * trend;

      // Fitted value = L_{t−1} + T_{t−1}  (prediksi satu langkah sebelumnya)
      smoothed.add(prevLevel + prevTrend);
    }

    // ── Forecast: ŷ_{t+m} = L_t + m · T_t ────────────────
    final List<double> forecast = forecastPeriods
        .where((m) => m > 0)
        .map((m) => level + m * trend)
        .toList();

    return DESResult(
      smoothedValues: smoothed,
      forecast: forecast,
      alpha: alpha,
      beta: beta,
      forecastPeriods: forecastPeriods,
      sensorInterval: config.sensorInterval,
    );
  }
}
