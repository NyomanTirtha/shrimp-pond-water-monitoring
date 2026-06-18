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
  final List<double> turbidities;
  final List<DateTime> timestamps;
  final DESResult? tempForecast;
  final DESResult? phForecast;
  final DESResult? turbForecast;
  final double currentTemperature;
  final double currentPh;
  final double currentTurbidity;
  final String statusMessage;

  const _PredictionSnapshot({
    required this.dataVersion,
    required this.isLoading,
    required this.temperatures,
    required this.phs,
    required this.turbidities,
    required this.timestamps,
    required this.tempForecast,
    required this.phForecast,
    required this.turbForecast,
    required this.currentTemperature,
    required this.currentPh,
    required this.currentTurbidity,
    required this.statusMessage,
  });
}

class PredictionPage extends StatefulWidget {
  /// Parameter yang diminta dari luar (Dashboard): 0 = Suhu, 1 = pH.
  /// Saat nilainya berubah, tab otomatis berpindah ke parameter tersebut.
  final ValueNotifier<int>? parameterTab;

  const PredictionPage({super.key, this.parameterTab});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage>
    with SingleTickerProviderStateMixin {
  // 0 = Suhu, 1 = pH
  int _selectedParameter = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initial = widget.parameterTab?.value ?? 0;
    _selectedParameter = initial;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initial)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() => _selectedParameter = _tabController.index);
        }
      });
    widget.parameterTab?.addListener(_onParameterTabRequested);
  }

  // Dipanggil saat Dashboard meminta membuka parameter tertentu.
  void _onParameterTabRequested() {
    final idx = widget.parameterTab?.value ?? 0;
    if (idx != _tabController.index) {
      _tabController.animateTo(idx);
    }
  }

  @override
  void dispose() {
    widget.parameterTab?.removeListener(_onParameterTabRequested);
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
        turbidities: provider.history.map((h) => h.turbidity).toList(),
        timestamps: provider.history.map((h) => h.timestamp).toList(),
        tempForecast: provider.tempForecast,
        phForecast: provider.phForecast,
        turbForecast: provider.turbForecast,
        currentTemperature: provider.current?.temperature ?? 0,
        currentPh: provider.current?.ph ?? 0,
        currentTurbidity: provider.current?.turbidity ?? 0,
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

    final interval = _readingInterval();

    // ── Jendela tampilan: tampilkan hanya histori TERBARU agar chart tidak
    // terlalu padat. Dengan ratusan titik, sumbu X jadi sangat terkompresi
    // sehingga jam (terutama bagian prediksi) saling menimpa / hilang.
    // Membatasi ke ~24 titik (≈4 jam pada interval 10 menit) membuat semua
    // jam—termasuk horizon prediksi +30 menit—muat & terbaca. Riwayat penuh
    // tetap ada di halaman Riwayat.
    const int maxChartPoints = 24;
    final int startIdx =
        history.length > maxChartPoints ? history.length - maxChartPoints : 0;
    final List<double> viewHistory = history.sublist(startIdx);
    final List<DateTime> viewTimestamps = timestamps.length == history.length
        ? timestamps.sublist(startIdx)
        : timestamps;
    final int lastViewIdx = viewHistory.length - 1;

    // Build spots for historical line (terindeks ulang dari 0).
    final histSpots = viewHistory.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    // Build spots for DES forecast (ditambahkan setelah histori jendela).
    final forecastSpots = <FlSpot>[];
    if (forecast != null) {
      for (var i = 0;
          i < forecast!.forecast.length &&
              i < forecast!.forecastPeriods.length;
          i++) {
        final v = forecast!.forecast[i];
        if (!v.isFinite) continue;
        forecastSpots.add(
          FlSpot((lastViewIdx + forecast!.forecastPeriods[i]).toDouble(), v),
        );
      }
    }
    final forecastLineSpots =
        forecastSpots.isNotEmpty ? [histSpots.last, ...forecastSpots] : <FlSpot>[];

    final lastTimestamp =
        viewTimestamps.isNotEmpty ? viewTimestamps.last : DateTime.now();
    final forecastLabelByX = <int, DateTime>{};
    if (forecast != null) {
      for (var i = 0; i < forecast!.forecastPeriods.length; i++) {
        final period = forecast!.forecastPeriods[i];
        forecastLabelByX[lastViewIdx + period] =
            lastTimestamp.add(interval * period);
      }
    }

    // Skala Y dihitung dari nilai pada jendela + prediksi.
    final chartValues = <double>[
      ...viewHistory.where((v) => v.isFinite),
      if (forecast != null) ...forecast!.forecast.where((v) => v.isFinite),
    ];
    final safeValues = chartValues.isEmpty ? <double>[0] : chartValues;
    final dataMin = _minValue(safeValues);
    final dataMax = _maxValue(safeValues);
    final padding = _axisPadding(dataMin, dataMax);
    final chartMinY = dataMin - padding;
    final chartMaxY = dataMax + padding;

    // ── Sumbu Y: satu interval tetap (= jarak garis grid) agar angka tidak
    // menumpuk. Range dibagi 4 → ~5 label. ──────────────────────────────
    final double yInterval =
        ((chartMaxY - chartMinY) / 4).clamp(0.0001, double.infinity);

    // ── Sumbu X: label histori dibuat ~5 merata, lalu jam prediksi
    // (+30 menit) ditambahkan agar bagian masa depan selalu berlabel.
    // Label histori yang terlalu rapat dengan prediksi pertama dibuang.
    final int histGap = (lastViewIdx / 4).ceil().clamp(1, 1 << 30);
    final Set<int> visibleLabelXs = {0};
    for (int x = histGap; x <= lastViewIdx; x += histGap) {
      visibleLabelXs.add(x);
    }
    final List<int> forecastXs = forecastLabelByX.keys.toList()..sort();
    final int firstForecastX =
        forecastXs.isNotEmpty ? forecastXs.first : (lastViewIdx + 1);
    visibleLabelXs.removeWhere((x) =>
        x != 0 && x <= lastViewIdx && (firstForecastX - x) < histGap * 0.7);
    visibleLabelXs.addAll(forecastXs);

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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
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
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 10,
                    tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    getTooltipColor: (touchedSpot) =>
                        AppTheme.textDark.withValues(alpha: 0.92),
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
                      interval: yInterval,
                      getTitlesWidget: (v, meta) {
                        // Sembunyikan label tepat di batas atas/bawah agar
                        // tidak terpotong / menempel ke tepi chart.
                        if (v <= meta.min || v >= meta.max) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          v.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textGray),
                        );
                      },
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

                        // Hanya tampilkan label pada indeks terpilih yang
                        // jaraknya sudah dijamin agar tidak tabrakan.
                        if (!visibleLabelXs.contains(idx)) {
                          return const SizedBox.shrink();
                        }

                        if (idx <= lastViewIdx) {
                          // ── Label historis ────────────────────────────
                          final ts = (idx < viewTimestamps.length)
                              ? viewTimestamps[idx]
                              : DateTime.now().subtract(
                                  interval * (lastViewIdx - idx));
                          return _rotatedLabel(
                            _formatTime(ts, interval),
                            AppTheme.textGray,
                            FontWeight.w400,
                          );
                        } else {
                          // ── Label prediksi ────────────────────────────
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
                  // ── Garis data aktual (historis) ──────────────
                  LineChartBarData(
                    spots: histSpots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    preventCurveOverShooting: true,
                    // Gradien garis: lebih terang → warna penuh
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.55), color],
                    ),
                    barWidth: 3,
                    // Titik hanya pada nilai terkini (titik terakhir histori)
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, bar) =>
                          spot.x == histSpots.last.x,
                      getDotPainter: (spot, pct, bar, idx) =>
                          FlDotCirclePainter(
                        radius: 4.5,
                        color: color,
                        strokeWidth: 2.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    // Area gradien lembut di bawah garis
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.22),
                          color.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                  // ── Garis prediksi (putus-putus) ──────────────
                  if (forecastLineSpots.isNotEmpty)
                    LineChartBarData(
                      spots: forecastLineSpots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      preventCurveOverShooting: true,
                      color: color.withValues(alpha: 0.7),
                      barWidth: 2.5,
                      dashArray: [5, 5],
                      dotData: FlDotData(
                        show: true,
                        // Sembunyikan titik sambungan pertama (titik 'sekarang')
                        checkToShowDot: (spot, bar) =>
                            spot.x != forecastLineSpots.first.x,
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(
                          radius: 3.5,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: color,
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
        dot(c: color.withValues(alpha: 0.65), dashed: true),
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
              color: AppTheme.primaryBlue.withValues(alpha: 0.12),
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
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
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
                        : AppTheme.surfaceBlue.withValues(alpha: 0.4));

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
                                ? AppTheme.statusDanger.withValues(alpha: 0.12)
                                : AppTheme.statusSafe.withValues(alpha: 0.12),
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
                      color: AppTheme.statusDanger.withValues(alpha: 0.4)),
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
