// ============================================================
// Page: Prediksi (Prediction)
// Displays fl_chart line chart with historical + DES forecast.
// ============================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/water_quality_provider.dart';
import '../models/water_quality_model.dart';
import '../utils/des_algorithm.dart';
import '../theme/app_theme.dart';
import '../widgets/prediction_analysis_card.dart';

class _PredictionSnapshot {
  final int dataVersion;
  final bool isLoading;
  final List<double> temperatures;
  final List<double> phs;
  final List<double> tdsList;
  final List<DateTime> timestamps;
  final DESResult? tempForecast;
  final DESResult? phForecast;
  final DESResult? tdsForecast;
  final double currentTemperature;
  final double currentPh;
  final double currentTds;
  final String statusMessage;

  const _PredictionSnapshot({
    required this.dataVersion,
    required this.isLoading,
    required this.temperatures,
    required this.phs,
    required this.tdsList,
    required this.timestamps,
    required this.tempForecast,
    required this.phForecast,
    required this.tdsForecast,
    required this.currentTemperature,
    required this.currentPh,
    required this.currentTds,
    required this.statusMessage,
  });
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage>
    with SingleTickerProviderStateMixin {
  // 0 = Suhu, 1 = pH, 2 = TDS
  int _selectedParameter = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() => _selectedParameter = _tabController.index);
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<WaterQualityProvider, _PredictionSnapshot>(
      selector: (_, provider) => _PredictionSnapshot(
        dataVersion: provider.dataVersion,
        isLoading: provider.isLoading,
        temperatures: provider.history.map((h) => h.temperature).toList(),
        phs: provider.history.map((h) => h.ph).toList(),
        tdsList: provider.history.map((h) => h.tds).toList(),
        timestamps: provider.history.map((h) => h.timestamp).toList(),
        tempForecast: provider.tempForecast,
        phForecast: provider.phForecast,
        tdsForecast: provider.tdsForecast,
        currentTemperature: provider.current?.temperature ?? 0,
        currentPh: provider.current?.ph ?? 0,
        currentTds: provider.current?.tds ?? 0,
        statusMessage: provider.statusMessage,
      ),
      shouldRebuild: (previous, next) =>
          previous.dataVersion != next.dataVersion ||
          previous.isLoading != next.isLoading ||
          previous.statusMessage != next.statusMessage,
      builder: (context, snapshot, _) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundLight,
            appBar: AppBar(
              title: const Text('Prediksi Tren',
              style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: AppTheme.accentTeal,
              tabs: const [
                Tab(text: 'Suhu'),
                Tab(text: 'pH'),
                Tab(text: 'TDS'),
              ],
            ),
          ),
          body: SafeArea(
            top: false,
            left: true,
            right: true,
            bottom: false,
            child: snapshot.isLoading && snapshot.temperatures.isEmpty
                ? _buildLoading(snapshot.statusMessage)
                : snapshot.temperatures.isEmpty
                    ? _buildEmptyState(snapshot.statusMessage)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _ParameterChartView(
                            label: 'Suhu Air (°C)',
                            color: const Color(0xFFFF6B6B),
                            history: snapshot.temperatures,
                            timestamps: snapshot.timestamps,
                            forecast: snapshot.tempForecast,
                            currentValue: snapshot.currentTemperature,
                            parameterName: 'Suhu Air',
                            unit: '°C',
                            safeMin: WaterThreshold.tempMin,
                            safeMax: WaterThreshold.tempMax,
                            decimalPlaces: 1,
                          ),
                          _ParameterChartView(
                            label: 'pH Air',
                            color: const Color(0xFF6BCB77),
                            history: snapshot.phs,
                            timestamps: snapshot.timestamps,
                            forecast: snapshot.phForecast,
                            currentValue: snapshot.currentPh,
                            parameterName: 'pH Air',
                            unit: '',
                            safeMin: WaterThreshold.phMin,
                            safeMax: WaterThreshold.phMax,
                            decimalPlaces: 2,
                          ),
                          _ParameterChartView(
                            label: 'TDS (ppm)',
                            color: AppTheme.accentTeal,
                            history: snapshot.tdsList,
                            timestamps: snapshot.timestamps,
                            forecast: snapshot.tdsForecast,
                            currentValue: snapshot.currentTds,
                            parameterName: 'TDS',
                            unit: 'ppm',
                            safeMin: WaterThreshold.tdsMin,
                            safeMax: WaterThreshold.tdsMax,
                            decimalPlaces: 1,
                          ),
                        ],
                      ),
          ),
        );
      },
    );
  }

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textGray,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Private sub-widget: one parameter's full chart + legend + DES info
// ─────────────────────────────────────────────────────────────
class _ParameterChartView extends StatelessWidget {
  final String label;
  final Color color;
  final List<double> history;
  final List<DateTime> timestamps;  // actual sensor timestamps
  final DESResult? forecast;
  final double currentValue;
  final String parameterName;
  final String unit;
  final double safeMin;
  final double safeMax;
  final int decimalPlaces;

  const _ParameterChartView({
    required this.label,
    required this.color,
    required this.history,
    required this.timestamps,
    required this.forecast,
    required this.currentValue,
    required this.parameterName,
    required this.unit,
    required this.safeMin,
    required this.safeMax,
    required this.decimalPlaces,
  });

  // ── Helpers: format label sumbu X ──────────────────────────

  /// Format DateTime → "HH:mm" (atau "HH:mm:ss" jika interval < 1 menit)
  String _formatTime(DateTime dt, Duration interval) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (interval.inSeconds < 60) {
      final ss = dt.second.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    return '$hh:$mm';
  }

  /// Interval antar pembacaan sensor (dihitung di provider dari timestamp
  /// history). Fallback ke 10 menit bila belum tersedia.
  Duration _readingInterval() {
    return forecast?.sensorInterval ?? const Duration(minutes: 10);
  }

  /// Ubah jumlah periode prediksi menjadi label durasi, mis. "+30 mnt".
  /// Fallback ke basis 15 menit bila interval sensor tak terdeteksi.
  String _periodLabel(int forecastPeriod) {
    final interval = _readingInterval();
    final step =
        interval.inSeconds > 0 ? interval : const Duration(minutes: 15);
    final total = step * forecastPeriod;
    if (total.inMinutes >= 60) {
      final h = total.inHours;
      final m = total.inMinutes % 60;
      return m == 0 ? '+${h}j' : '+${h}j ${m}m';
    } else if (total.inMinutes >= 1) {
      return '+${total.inMinutes} mnt';
    } else {
      return '+${total.inSeconds} dtk';
    }
  }

  String _formatValue(double value) {
    final suffix = unit.isEmpty ? '' : ' $unit';
    return '${value.toStringAsFixed(decimalPlaces)}$suffix';
  }

  List<double> _chartValues() {
    final values = <double>[
      ...history.where((value) => value.isFinite),
    ];
    final prediction = forecast?.forecast.where((value) => value.isFinite);
    if (prediction != null) {
      values.addAll(prediction);
    }
    return values.isEmpty ? <double>[0] : values;
  }

  double _minValue(List<double> values) {
    var result = values.first;
    for (final value in values.skip(1)) {
      if (value < result) result = value;
    }
    return result;
  }

  double _maxValue(List<double> values) {
    var result = values.first;
    for (final value in values.skip(1)) {
      if (value > result) result = value;
    }
    return result;
  }

  double _axisPadding(double minValue, double maxValue) {
    final span = maxValue - minValue;
    if (span > 0) {
      return span * 0.15;
    }
    final base = maxValue.abs() * 0.1;
    return base > 0 ? base : 1;
  }

  List<FlSpot> _buildForecastSpots(DESResult? result) {
    if (result == null || result.forecast.isEmpty || history.isEmpty) {
      return const <FlSpot>[];
    }

    final lastHistoryIndex = history.length - 1;
    final spots = <FlSpot>[];

    for (var i = 0; i < result.forecast.length; i++) {
      if (i >= result.forecastPeriods.length) break;
      spots.add(
        FlSpot(
          (lastHistoryIndex + result.forecastPeriods[i]).toDouble(),
          result.forecast[i],
        ),
      );
    }

    return spots;
  }

  /// Widget teks yang dirotasi ~25° untuk menghindari tabrakan antar label.
  Widget _rotatedLabel(String text, Color color, FontWeight weight) {
    return Transform.rotate(
      angle: -0.44, // ~25 derajat dalam radian
      alignment: Alignment.topRight,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8.5,
          color: color,
          fontWeight: weight,
          height: 1,
        ),
      ),
    );
  }

  @override

  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(child: Text('Belum ada data'));
    }

    // Build spots for historical line
    final histSpots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    // Build spots for DES forecast (appended after historical)
    final forecastSpots = _buildForecastSpots(forecast);
    final forecastLineSpots =
        forecastSpots.isNotEmpty ? [histSpots.last, ...forecastSpots] : <FlSpot>[];
    final interval = _readingInterval();
    final lastTimestamp = timestamps.isNotEmpty ? timestamps.last : DateTime.now();
    final forecastLabelByX = <int, DateTime>{};
    final chartValues = _chartValues();
    final dataMin = _minValue(chartValues);
    final dataMax = _maxValue(chartValues);
    final padding = _axisPadding(dataMin, dataMax);
    final chartMinY = dataMin - padding;
    final chartMaxY = dataMax + padding;

    if (forecast != null) {
      for (var i = 0; i < forecast!.forecastPeriods.length; i++) {
        final period = forecast!.forecastPeriods[i];
        forecastLabelByX[history.length - 1 + period] =
            lastTimestamp.add(interval * period);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header bersih ─────────────────────────────────
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Analisis & Tren Prediksi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textGray,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Chart ─────────────────────────────────────────
          Container(
            height: 260,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LineChart(
              LineChartData(
                minY: chartMinY,
                maxY: chartMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          _formatValue(spot.y),
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, meta) => Text(
                        v.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textGray),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      // Berikan cukup ruang vertikal untuk label yang dirotasi
                      reservedSize: 40,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        final idx = v.round();

                        if ((v - idx).abs() > 0.01) {
                          return const SizedBox.shrink();
                        }

                        // ── Hitung step (interval) antar label ──────────
                        // Tampilkan maks ~5 label historis di layar
                        final int labelStep =
                            (history.length / 5).ceil().clamp(1, 999);

                        if (idx < history.length) {
                          // ── Label historis ────────────────────────────
                          // Tampilkan hanya pada kelipatan labelStep;
                          // selalu tampilkan titik pertama dan terakhir.
                          final bool isFirst = idx == 0;
                          final bool isLast  = idx == history.length - 1;
                          if (!isFirst && !isLast && idx % labelStep != 0) {
                            return const SizedBox.shrink();
                          }
                          final ts = (idx < timestamps.length)
                              ? timestamps[idx]
                              : DateTime.now().subtract(
                                  interval * (history.length - 1 - idx));
                          return _rotatedLabel(
                            _formatTime(ts, interval),
                            AppTheme.textGray,
                            FontWeight.w400,
                          );
                        } else {
                          final forecastTime = forecastLabelByX[idx];
                          if (forecastTime == null) {
                            return const SizedBox.shrink();
                          }
                          return _rotatedLabel(
                            _formatTime(forecastTime, interval),
                            color,
                            FontWeight.w600,
                          );
                        }
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  // Historical actual line
                  LineChartBarData(
                    spots: histSpots,
                    isCurved: true,
                    color: color,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.08),
                    ),
                  ),
                  // Linker (dashed transition)
                  if (forecastLineSpots.isNotEmpty)
                    LineChartBarData(
                      spots: forecastLineSpots,
                      isCurved: false,
                      color: color.withOpacity(0.65),
                      barWidth: 2,
                      dashArray: [6, 4],
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: color,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Legend ────────────────────────────────
          _buildLegend(color),
          const SizedBox(height: 16),

          // ── Analisis Cerdas ───────────────────────────
          if (forecast != null && forecast!.forecast.isNotEmpty)
            PredictionAnalysisCard(
              parameterName: parameterName,
              unit: unit,
              currentValue: currentValue,
              predictedValue: forecast!.forecast.first,
              predictionLabel:
                  'Prediksi ${_periodLabel(forecast!.forecastPeriods.firstWhere((m) => m > 0, orElse: () => 1))}',
              safeMin: safeMin,
              safeMax: safeMax,
            ),
          const SizedBox(height: 24),

          // ── Forecast table ────────────────────────────
          if (forecast != null)
            _buildForecastTable(color, safeMin, safeMax),
        ],
      ),
    );
  }


  Widget _buildLegend(Color color) {
    Widget dot({required Color c, bool dashed = false}) => Container(
          width: 28,
          height: 3,
          decoration: BoxDecoration(
            color: dashed ? Colors.transparent : c,
            border: dashed ? Border.all(color: c) : null,
            borderRadius: BorderRadius.circular(2),
          ),
        );

    return Row(
      children: [
        dot(c: color),
        const SizedBox(width: 6),
        const Text('Data Aktual',
            style: TextStyle(fontSize: 11, color: AppTheme.textGray)),
        const SizedBox(width: 16),
        dot(c: color.withOpacity(0.65), dashed: true),
        const SizedBox(width: 6),
        const Text('Prediksi DES',
            style: TextStyle(fontSize: 11, color: AppTheme.textGray)),
      ],
    );
  }

  Widget _buildForecastTable(Color color, double safeMin, double safeMax) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Judul seksi ───────────────────────────────────
        const Text(
          'Nilai Prediksi ke Depan',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),

        // ── Tabel ──────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Table(
            border: TableBorder.all(
              color: AppTheme.primaryBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            columnWidths: const {
              0: FlexColumnWidth(1.1),  // Waktu
              1: FlexColumnWidth(1.8),  // Nilai prediksi
              2: FlexColumnWidth(1),    // Status
            },
            children: [
              // ── Header row ───────────────────────────────
              TableRow(
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.08),
                ),
                children: [
                  _headerCell('Waktu'),
                  _headerCell('Nilai Prediksi ($unit)'),
                  _headerCell('Status'),
                ],
              ),

              // ── Data rows ────────────────────────────────
              ...forecast!.forecast.asMap().entries.map((e) {
                final int step1 = e.key < forecast!.forecastPeriods.length
                    ? forecast!.forecastPeriods[e.key]
                    : e.key + 1;
                final double val = e.value;
                final bool isDanger = val < safeMin || val > safeMax;

                // Warna baris: merah muda jika bahaya, putih jika aman
                final Color rowBg = isDanger
                    ? const Color(0xFFFFEBEB)   // merah muda lembut
                    : (e.key.isEven
                        ? Colors.white
                        : AppTheme.surfaceBlue.withOpacity(0.4));

                final Color valueColor =
                    isDanger ? AppTheme.statusDanger : color;

                return TableRow(
                  decoration: BoxDecoration(color: rowBg),
                  children: [
                    // Kolom waktu
                    _dataCell(
                      _periodLabel(step1),
                      AppTheme.textGray,
                      FontWeight.w500,
                    ),
                    // Kolom nilai prediksi
                    _dataCell(
                      val.toStringAsFixed(decimalPlaces),
                      valueColor,
                      FontWeight.w700,
                    ),
                    // Kolom status
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDanger
                                ? AppTheme.statusDanger.withOpacity(0.12)
                                : AppTheme.statusSafe.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isDanger ? 'Bahaya' : 'Aman',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDanger
                                  ? AppTheme.statusDanger
                                  : AppTheme.statusSafe,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),

        // ── Keterangan rentang aman ───────────────────────────
        const SizedBox(height: 6),
        Row(
          children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEB),
                  border: Border.all(
                      color: AppTheme.statusDanger.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(2),
                )),
            const SizedBox(width: 6),
            Text(
              'Di luar rentang aman ($safeMin – $safeMax $unit)',
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textGray),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helper: sel header ──────────────────────────────────
  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryBlue,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ── Helper: sel data ───────────────────────────────────
  Widget _dataCell(String text, Color color, FontWeight weight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: weight,
          color: color,
        ),
      ),
    );
  }
}
