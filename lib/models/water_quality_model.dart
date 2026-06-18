// ============================================================
// Model: WaterQualityModel
// Representation of a real-time water quality reading.
// Add more fields here to extend to Firebase payload easily.
// ============================================================

import 'package:flutter/material.dart';

/// Represents the status level of a parameter reading.
enum ParameterStatus { safe, warning, danger }

/// Safe threshold ranges for shrimp pond parameters.
/// Update these constants to match your research / literature.
class WaterThreshold {
  // Suhu (Temperature) in °C
  static const double tempMin = 26.0;
  static const double tempMax = 32.0;

  // pH Air
  static const double phMin = 7.5;
  static const double phMax = 8.5;

  // Kekeruhan (Turbidity) dalam NTU
  static const double turbMin = 0.0;
  static const double turbMax = 100.0;
}

/// A single snapshot of all sensor readings.
class WaterQualityModel {
  final double temperature; // °C
  final double ph; // dimensionless
  final double turbidity; // NTU
  final DateTime timestamp;

  const WaterQualityModel({
    required this.temperature,
    required this.ph,
    required this.turbidity,
    required this.timestamp,
  });

  // ----------------------------------------------------------
  // Status helpers – extend logic here for more nuanced rules
  // ----------------------------------------------------------

  ParameterStatus get temperatureStatus {
    if (temperature < WaterThreshold.tempMin ||
        temperature > WaterThreshold.tempMax) {
      return ParameterStatus.danger;
    }
    return ParameterStatus.safe;
  }

  ParameterStatus get phStatus {
    if (ph < WaterThreshold.phMin || ph > WaterThreshold.phMax) {
      return ParameterStatus.danger;
    }
    return ParameterStatus.safe;
  }

  ParameterStatus get turbidityStatus {
    if (turbidity < WaterThreshold.turbMin ||
        turbidity > WaterThreshold.turbMax) {
      return ParameterStatus.danger;
    }
    return ParameterStatus.safe;
  }

  /// Label kualitatif kejernihan air berdasarkan nilai NTU.
  String get turbidityLabel {
    if (turbidity < 25.0) return 'Jernih';
    if (turbidity < 100.0) return 'Keruh';
    return 'Sangat Keruh';
  }

  bool hasSameSensorValues(WaterQualityModel other) {
    return temperature == other.temperature &&
        ph == other.ph &&
        turbidity == other.turbidity;
  }
}

// ----------------------------------------------------------
// UI helpers independent of the model class
// ----------------------------------------------------------
Color statusColor(ParameterStatus status) {
  switch (status) {
    case ParameterStatus.safe:
      return const Color(0xFF2ECC71);
    case ParameterStatus.warning:
      return const Color(0xFFF39C12);
    case ParameterStatus.danger:
      return const Color(0xFFE74C3C);
  }
}

String statusLabel(ParameterStatus status) {
  switch (status) {
    case ParameterStatus.safe:
      return 'Aman';
    case ParameterStatus.warning:
      return 'Waspada';
    case ParameterStatus.danger:
      return 'Bahaya';
  }
}
