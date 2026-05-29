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
import '../widgets/parameter_card.dart';

class _DashboardSnapshot {
  final WaterQualityModel? current;
  final bool isLoading;
  final String statusMessage;

  const _DashboardSnapshot({
    required this.current,
    required this.isLoading,
    required this.statusMessage,
  });
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<WaterQualityProvider, _DashboardSnapshot>(
      selector: (_, provider) => _DashboardSnapshot(
        current: provider.current,
        isLoading: provider.isLoading,
        statusMessage: provider.statusMessage,
      ),
      shouldRebuild: (previous, next) =>
          previous.current != next.current ||
          previous.isLoading != next.isLoading ||
          previous.statusMessage != next.statusMessage,
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
                    ? _buildEmptyState(snapshot.statusMessage)
                    : ListView(
                        children: [
                          const SizedBox(height: 16),
                          _buildSummaryBanner(context, current),
                          const SizedBox(height: 8),
                          ParameterCard(
                            title: 'Suhu Air',
                            value: current.temperature.toStringAsFixed(1),
                            unit: '°C',
                            icon: Icons.thermostat_rounded,
                            status: current.temperatureStatus,
                            safeRangeText:
                                '${WaterThreshold.tempMin}–${WaterThreshold.tempMax} °C',
                          ),
                          ParameterCard(
                            title: 'pH Air',
                            value: current.ph.toStringAsFixed(2),
                            unit: '',
                            icon: Icons.science_rounded,
                            status: current.phStatus,
                            safeRangeText:
                                '${WaterThreshold.phMin}–${WaterThreshold.phMax}',
                          ),
                          ParameterCard(
                            title: 'TDS',
                            value: current.tds.toStringAsFixed(1),
                            unit: 'ppm',
                            icon: Icons.opacity_rounded,
                            status: current.tdsStatus,
                            safeRangeText:
                                '${WaterThreshold.tdsMin.toInt()}–${WaterThreshold.tdsMax.toInt()} ppm',
                          ),
                          const SizedBox(height: 16),
                          _buildLastUpdated(current.timestamp),
                          const SizedBox(height: 24),
                        ],
                      ),
          ),
        );
      },
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

  // ── Overall status banner ─────────────────────────────────
  Widget _buildSummaryBanner(BuildContext context, WaterQualityModel data) {
    final allSafe = data.temperatureStatus == ParameterStatus.safe &&
        data.phStatus == ParameterStatus.safe &&
        data.tdsStatus == ParameterStatus.safe;

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

  // ── Timestamp ─────────────────────────────────────────────
  Widget _buildLastUpdated(DateTime ts) {
    final formatted =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
    return Center(
      child: Text(
        'Terakhir diperbarui: $formatted',
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textGray,
        ),
      ),
    );
  }
}
