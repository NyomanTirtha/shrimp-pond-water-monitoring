// ============================================================
// Page: Dashboard
// Shows real-time sensor readings as Parameter Cards.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/water_quality_provider.dart';
import '../models/water_quality_model.dart';
import '../theme/app_theme.dart';
import '../widgets/parameter_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WaterQualityProvider>(
      builder: (context, provider, _) {
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
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.current == null
                  ? const Center(child: Text('Data tidak tersedia'))
                  : ListView(
                      children: [
                        const SizedBox(height: 16),
                        _buildSummaryBanner(context, provider.current!),
                        const SizedBox(height: 8),
                        ParameterCard(
                          title: 'Suhu Air',
                          value: provider.current!.temperature.toStringAsFixed(1),
                          unit: '°C',
                          icon: Icons.thermostat_rounded,
                          status: provider.current!.temperatureStatus,
                          safeRangeText:
                              '${WaterThreshold.tempMin}–${WaterThreshold.tempMax} °C',
                        ),
                        ParameterCard(
                          title: 'pH Air',
                          value: provider.current!.ph.toStringAsFixed(2),
                          unit: '',
                          icon: Icons.science_rounded,
                          status: provider.current!.phStatus,
                          safeRangeText:
                              '${WaterThreshold.phMin}–${WaterThreshold.phMax}',
                        ),
                        ParameterCard(
                          title: 'Kekeruhan',
                          value: provider.current!.turbidity.toStringAsFixed(1),
                          unit: 'NTU',
                          icon: Icons.water_rounded,
                          status: provider.current!.turbidityStatus,
                          safeRangeText:
                              '${WaterThreshold.turbidityMin.toInt()}–${WaterThreshold.turbidityMax.toInt()} NTU',
                        ),
                        const SizedBox(height: 16),
                        _buildLastUpdated(provider.current!.timestamp),
                        const SizedBox(height: 24),
                      ],
                    ),
        );
      },
    );
  }

  // ── Overall status banner ─────────────────────────────────
  Widget _buildSummaryBanner(BuildContext context, WaterQualityModel data) {
    final allSafe = data.temperatureStatus == ParameterStatus.safe &&
        data.phStatus == ParameterStatus.safe &&
        data.turbidityStatus == ParameterStatus.safe;

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
