// ============================================================
// Utility: Double Exponential Smoothing (DES)
// Method: Holt's Linear Trend Method
//
// Formulas (plug into your skripsi):
//   Level:   L_t = α * y_t + (1 - α) * (L_{t-1} + T_{t-1})
//   Trend:   T_t = β * (L_t - L_{t-1}) + (1 - β) * T_{t-1}
//   Forecast: ŷ_{t+m} = L_t + m * T_t
//
// Parameters:
//   alpha (α): Smoothing factor for level      [0 < α < 1]
//   beta  (β): Smoothing factor for trend      [0 < β < 1]
// ============================================================

class DESResult {
  final List<double> smoothedValues; // fitted values for historical data
  final List<double> forecast; // future predictions
  final double alpha;
  final double beta;

  const DESResult({
    required this.smoothedValues,
    required this.forecast,
    required this.alpha,
    required this.beta,
  });
}

class DESAlgorithm {
  /// Run Double Exponential Smoothing over [data].
  ///
  /// [alpha]    – level smoothing factor (default 0.3)
  /// [beta]     – trend smoothing factor (default 0.1)
  /// [periods]  – how many future periods to predict (default 6)
  ///
  /// Returns a [DESResult] containing smoothed history + forecast.
  static DESResult run(
    List<double> data, {
    double alpha = 0.3,
    double beta = 0.1,
    int periods = 6,
  }) {
    assert(alpha > 0 && alpha < 1, 'alpha must be between 0 and 1');
    assert(beta > 0 && beta < 1, 'beta must be between 0 and 1');
    assert(data.length >= 2, 'Need at least 2 data points');

    // ── Initialisation ─────────────────────────────────────
    double level = data[0];
    double trend = data[1] - data[0];

    final List<double> smoothed = [];

    // ── Smoothing pass ─────────────────────────────────────
    for (int t = 0; t < data.length; t++) {
      final double prevLevel = level;
      // Level update
      level = alpha * data[t] + (1 - alpha) * (level + trend);
      // Trend update
      trend = beta * (level - prevLevel) + (1 - beta) * trend;
      // Fitted value (one-step-ahead from previous state)
      smoothed.add(prevLevel + trend);
    }

    // ── Forecast ───────────────────────────────────────────
    final List<double> forecast = List.generate(
      periods,
      (m) => level + (m + 1) * trend,
    );

    return DESResult(
      smoothedValues: smoothed,
      forecast: forecast,
      alpha: alpha,
      beta: beta,
    );
  }
}
