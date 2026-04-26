// ============================================================
// Provider: WaterQualityProvider
//
// Currently uses simulated (dummy) data.
// To connect Firebase, replace `_fetchData()` with a
// FirebaseDatabase.instance.ref('sensor').onValue.listen(...)
// stream and call `notifyListeners()` on each update.
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/water_quality_model.dart';
import '../utils/des_algorithm.dart';

class WaterQualityProvider extends ChangeNotifier {
  // ── Current (latest) reading ────────────────────────────
  WaterQualityModel? _current;
  WaterQualityModel? get current => _current;

  // ── Historical data for chart (last N readings) ─────────
  final List<WaterQualityModel> _history = [];
  List<WaterQualityModel> get history => List.unmodifiable(_history);

  // ── DES forecast results ─────────────────────────────────
  DESResult? _tempForecast;
  DESResult? _phForecast;
  DESResult? _turbidityForecast;

  DESResult? get tempForecast => _tempForecast;
  DESResult? get phForecast => _phForecast;
  DESResult? get turbidityForecast => _turbidityForecast;

  // ── Loading / error state ────────────────────────────────
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  // ── Simulation timer ─────────────────────────────────────
  Timer? _timer;
  final _random = Random();

  WaterQualityProvider() {
    _initSimulatedData();
    // Refresh every 5 seconds (replace with Firebase stream later)
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchData());
  }

  // ----------------------------------------------------------
  // Initialise with a history of 12 readings for the chart
  // ----------------------------------------------------------
  void _initSimulatedData() {
    for (int i = 12; i >= 0; i--) {
      _history.add(_simulateReading(
        timestamp: DateTime.now().subtract(Duration(minutes: i * 5)),
      ));
    }
    _current = _history.last;
    _isLoading = false;
    _computeForecasts();
    notifyListeners();
  }

  // ----------------------------------------------------------
  // Simulate a new reading (swap this with Firebase later)
  // ----------------------------------------------------------
  WaterQualityModel _simulateReading({DateTime? timestamp}) {
    final base = _history.isEmpty
        ? WaterQualityModel(
            temperature: 29.0,
            ph: 7.8,
            turbidity: 60.0,
            timestamp: DateTime.now(),
          )
        : _history.last;

    double clamp(double v, double min, double max) => v.clamp(min, max);

    return WaterQualityModel(
      temperature:
          clamp(base.temperature + (_random.nextDouble() * 1.0 - 0.5), 24, 35),
      ph: clamp(base.ph + (_random.nextDouble() * 0.3 - 0.15), 6.5, 9.5),
      turbidity:
          clamp(base.turbidity + (_random.nextDouble() * 8.0 - 4.0), 10, 150),
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  // ----------------------------------------------------------
  // Fetch / refresh data  ← REPLACE BODY with Firebase stream
  // ----------------------------------------------------------
  void _fetchData() {
    try {
      final reading = _simulateReading();
      _history.add(reading);
      if (_history.length > 24) _history.removeAt(0); // keep last 24 readings
      _current = reading;
      _computeForecasts();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ----------------------------------------------------------
  // Run DES on the historical series for each parameter
  // ----------------------------------------------------------
  void _computeForecasts() {
    if (_history.length < 2) return;

    final temps = _history.map((h) => h.temperature).toList();
    final phs = _history.map((h) => h.ph).toList();
    final turbs = _history.map((h) => h.turbidity).toList();

    _tempForecast = DESAlgorithm.run(temps, periods: 6);
    _phForecast = DESAlgorithm.run(phs, periods: 6);
    _turbidityForecast = DESAlgorithm.run(turbs, periods: 6);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
