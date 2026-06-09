// ============================================================
// Page: Dashboard
// Shows real-time sensor readings as Parameter Cards.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/water_quality_provider.dart';
import '../models/water_quality_model.dart';
import '../pages/notification_history_page.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/des_algorithm.dart';
import '../widgets/gauge_card.dart';

class _DashboardSnapshot {
  final WaterQualityModel? current;
  final bool isLoading;
  final String statusMessage;
  final DESResult? tempForecast;
  final DESResult? phForecast;
  final DESResult? turbForecast;
  final int dataVersion;

  const _DashboardSnapshot({
    required this.current,
    required this.isLoading,
    required this.statusMessage,
    required this.tempForecast,
    required this.phForecast,
    required this.turbForecast,
    required this.dataVersion,
  });
}

class DashboardPage extends StatelessWidget {
  /// Dipanggil saat user menekan "Selengkapnya" pada ringkasan prediksi.
  /// Argumen: 0 = Suhu, 1 = pH. Dipakai untuk pindah ke halaman Prediksi.
  final void Function(int parameterIndex)? onOpenPrediction;

  const DashboardPage({super.key, this.onOpenPrediction});

  @override
  Widget build(BuildContext context) {
    return Selector<WaterQualityProvider, _DashboardSnapshot>(
      selector: (_, provider) => _DashboardSnapshot(
        current: provider.current,
        isLoading: provider.isLoading,
        statusMessage: provider.statusMessage,
        tempForecast: provider.tempForecast,
        phForecast: provider.phForecast,
        turbForecast: provider.turbForecast,
        dataVersion: provider.dataVersion,
      ),
      shouldRebuild: (previous, next) =>
          previous.current != next.current ||
          previous.isLoading != next.isLoading ||
          previous.statusMessage != next.statusMessage ||
          previous.dataVersion != next.dataVersion,
      builder: (context, snapshot, _) {
        final current = snapshot.current;
        return Scaffold(
          backgroundColor: AppTheme.backgroundLight,
          appBar: AppBar(
            title: const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            actions: [
              _buildNotificationButton(context),
            ],
          ),
          body: SafeArea(
            top: false,
            left: true,
            right: true,
            bottom: false,
            child: current == null && snapshot.isLoading
                ? _buildLoading(snapshot.statusMessage)
                : current == null
                    ? _buildRefreshable(
                        context,
                        child: _buildEmptyState(snapshot.statusMessage),
                      )
                    : _buildRefreshable(
                        context,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 16),
                            _buildSummaryBanner(context, current),
                            const SizedBox(height: 8),
                            // ── Indikator gauge (busur) ──────────
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GaugeCard(
                                      title: 'Suhu Air',
                                      value: current.temperature,
                                      min: 0,
                                      max: 50,
                                      unit: '°C',
                                      decimals: 1,
                                      color: statusColor(
                                          current.temperatureStatus),
                                      icon: Icons.thermostat_rounded,
                                      status: current.temperatureStatus,
                                      safeRangeText:
                                          '${WaterThreshold.tempMin}–${WaterThreshold.tempMax} °C',
                                    ),
                                  ),
                                  Expanded(
                                    child: GaugeCard(
                                      title: 'pH Air',
                                      value: current.ph,
                                      min: 0,
                                      max: 14,
                                      decimals: 2,
                                      color: statusColor(current.phStatus),
                                      icon: Icons.science_rounded,
                                      status: current.phStatus,
                                      safeRangeText:
                                          '${WaterThreshold.phMin}–${WaterThreshold.phMax}',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // ── Gauge kekeruhan (baris kedua) ────
                            /*
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GaugeCard(
                                      title: 'Kekeruhan',
                                      value: current.turbidity,
                                      min: 0,
                                      max: 400,
                                      unit: 'NTU',
                                      decimals: 0,
                                      color:
                                          statusColor(current.turbidityStatus),
                                      icon: Icons.opacity_rounded,
                                      status: current.turbidityStatus,
                                      safeRangeText:
                                          '≤ ${WaterThreshold.turbMax.toStringAsFixed(0)} NTU',
                                    ),
                                  ),
                                  const Expanded(child: SizedBox()),
                                ],
                              ),
                            ),
                            */
                            const SizedBox(height: 16),
                            _buildPredictionSection(
                              context,
                              current,
                              snapshot.tempForecast,
                              snapshot.phForecast,
                              snapshot.turbForecast,
                            ),
                            const SizedBox(height: 16),
                            _buildLastUpdated(current.timestamp),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
          ),
        );
      },
    );
  }

  // ── Pembungkus pull-to-refresh ────────────────────────────
  // Membungkus [child] dengan RefreshIndicator. Saat ditarik ke bawah,
  // memanggil provider.refresh() untuk memuat ulang data Firebase.
  Widget _buildRefreshable(BuildContext context, {required Widget child}) {
    return RefreshIndicator(
      onRefresh: () => context.read<WaterQualityProvider>().refresh(),
      color: AppTheme.primaryBlue,
      child: child,
    );
  }

  Widget _buildNotificationButton(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService().unreadCountStream,
      initialData: 0,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return FutureBuilder<int>(
          future: NotificationService().getUnreadCount(),
          builder: (context, countSnapshot) {
            final count = countSnapshot.data ?? unreadCount;

            return IconButton(
              tooltip: 'Riwayat Notifikasi',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationHistoryPage(),
                  ),
                );
                await NotificationService().refreshUnreadCount();
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_rounded),
                  if (count > 0)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppTheme.statusDanger,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
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
    // LayoutBuilder + SingleChildScrollView agar tetap bisa ditarik
    // (pull-to-refresh) walau isinya hanya satu baris pesan.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tarik ke bawah untuk memuat ulang',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Overall status banner ─────────────────────────────────
  Widget _buildSummaryBanner(BuildContext context, WaterQualityModel data) {
    final allSafe = data.temperatureStatus == ParameterStatus.safe &&
        data.phStatus == ParameterStatus.safe;

    final color = allSafe ? AppTheme.statusSafe : AppTheme.statusDanger;
    final message =
        allSafe ? 'Semua parameter dalam kondisi aman ✓' : 'Ada parameter yang perlu perhatian!';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(
              allSafe ? Icons.verified_rounded : Icons.warning_amber_rounded,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ringkasan prediksi (singkat) ──────────────────────────
  // Menampilkan prediksi terdekat untuk Suhu & pH, masing-masing
  // dengan tombol "Selengkapnya" yang membuka halaman Prediksi pada
  // tab parameter terkait (0 = Suhu, 1 = pH).
  Widget _buildPredictionSection(
    BuildContext context,
    WaterQualityModel current,
    DESResult? tempForecast,
    DESResult? phForecast,
    DESResult? turbForecast,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Judul seksi ──────────────────────────────────
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  size: 18, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Prediksi Singkat',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPredictionCard(
            paramIndex: 0,
            title: 'Suhu Air',
            icon: Icons.thermostat_rounded,
            currentValue: current.temperature,
            forecast: tempForecast,
            unit: '°C',
            decimals: 1,
            safeMin: WaterThreshold.tempMin,
            safeMax: WaterThreshold.tempMax,
          ),
          const SizedBox(height: 10),
          _buildPredictionCard(
            paramIndex: 1,
            title: 'pH Air',
            icon: Icons.science_rounded,
            currentValue: current.ph,
            forecast: phForecast,
            unit: '',
            decimals: 2,
            safeMin: WaterThreshold.phMin,
            safeMax: WaterThreshold.phMax,
          ),
          /*
          const SizedBox(height: 10),
          _buildPredictionCard(
            paramIndex: 2,
            title: 'Kekeruhan',
            icon: Icons.opacity_rounded,
            currentValue: current.turbidity,
            forecast: turbForecast,
            unit: 'NTU',
            decimals: 0,
            safeMin: WaterThreshold.turbMin,
            safeMax: WaterThreshold.turbMax,
          ),
          */
        ],
      ),
    );
  }

  Widget _buildPredictionCard({
    required int paramIndex,
    required String title,
    required IconData icon,
    required double currentValue,
    required DESResult? forecast,
    required String unit,
    required int decimals,
    required double safeMin,
    required double safeMax,
  }) {
    final hasForecast = forecast != null && forecast.forecast.isNotEmpty;
    final double? predicted = hasForecast ? forecast.forecast.first : null;
    final bool isDanger =
        predicted != null && (predicted < safeMin || predicted > safeMax);
    final Color accent = isDanger ? AppTheme.statusDanger : AppTheme.statusSafe;
    final String unitSuffix = unit.isEmpty ? '' : ' $unit';

    String fmt(double v) => v.toStringAsFixed(decimals);

    // Horizon prediksi (mis. "30 mnt ke depan") dihitung dari interval
    // sensor × periode prediksi pertama.
    final String? horizon =
        hasForecast ? _horizonLabel(forecast) : null;

    // Tren naik / turun / stabil dibanding nilai sekarang.
    final double diff = predicted != null ? predicted - currentValue : 0;
    final IconData trendIcon = diff > 0
        ? Icons.trending_up_rounded
        : diff < 0
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onOpenPrediction?.call(paramIndex),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryBlue),
              const SizedBox(width: 12),
              // ── Judul + nilai prediksi ───────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      horizon != null ? '$title • $horizon' : title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGray,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (!hasForecast)
                      const Text(
                        'Belum cukup data',
                        style:
                            TextStyle(fontSize: 13, color: AppTheme.textGray),
                      )
                    else
                      Row(
                        children: [
                          Text(
                            fmt(currentValue),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textGray,
                            ),
                          ),
                          Icon(trendIcon, size: 15, color: accent),
                          Text(
                            '${fmt(predicted!)}$unitSuffix',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // ── Status (titik + label) ───────────────────
              if (hasForecast) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isDanger ? 'Bahaya' : 'Aman',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.textGray,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Label horizon prediksi ────────────────────────────────
  // Menghitung jarak waktu prediksi pertama: interval sensor × periode.
  // Contoh hasil: "30 mnt ke depan", "1j ke depan", "45 dtk ke depan".
  String _horizonLabel(DESResult forecast) {
    final period = forecast.forecastPeriods.firstWhere(
      (m) => m > 0,
      orElse: () => 1,
    );
    final interval = forecast.sensorInterval.inSeconds > 0
        ? forecast.sensorInterval
        : const Duration(minutes: 15);
    final total = interval * period;

    if (total.inMinutes >= 60) {
      final h = total.inHours;
      final m = total.inMinutes % 60;
      return m == 0 ? '${h}j ke depan' : '${h}j ${m}m ke depan';
    } else if (total.inMinutes >= 1) {
      return '${total.inMinutes} mnt ke depan';
    } else {
      return '${total.inSeconds} dtk ke depan';
    }
  }

  // ── Timestamp ─────────────────────────────────────────────
  Widget _buildLastUpdated(DateTime ts) {
    const hariId = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
    ];
    const bulanId = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final hari = hariId[ts.weekday - 1]; // DateTime.weekday: 1=Senin … 7=Minggu
    final bulan = bulanId[ts.month - 1]; // DateTime.month: 1=Januari … 12=Desember
    final tanggal = '$hari, ${ts.day} $bulan ${ts.year}';
    final jam = ts.hour.toString().padLeft(2, '0');
    final menit = ts.minute.toString().padLeft(2, '0');
    final detik = ts.second.toString().padLeft(2, '0');
    final waktu = '$jam:$menit:$detik';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Label ──────────────────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.update_rounded,
                  size: 14,
                  color: AppTheme.textGray,
                ),
                const SizedBox(width: 6),
                Text(
                  'Terakhir diperbarui',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: AppTheme.textGray.withOpacity(0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Tanggal ────────────────────────────────────
            Text(
              tanggal,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 2),
            // ── Waktu (jam:menit:detik) ────────────────────
            Text(
              waktu,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
