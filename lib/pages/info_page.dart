// ============================================================
// Page: Info
// Parameter safe thresholds + developer profile
// ============================================================

import 'package:flutter/material.dart';
import '../models/water_quality_model.dart';
import '../theme/app_theme.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Informasi',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        left: true,
        right: true,
        bottom: false,
        child: ListView(
          children: [
            const SizedBox(height: 16),
            _sectionHeader('Ambang Batas Parameter Aman'),
            const SizedBox(height: 8),
            _buildParameterTable(),
            const SizedBox(height: 24),
            _sectionHeader('Tentang Aplikasi'),
            const SizedBox(height: 8),
            _buildAboutCard(),
            const SizedBox(height: 24),
            _sectionHeader('Informasi Algoritma'),
            const SizedBox(height: 8),
            _buildAlgorithmCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  // ── Kartu Informasi Algoritma DES ────────────────────────────────
  Widget _buildAlgorithmCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Judul ──────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.functions_rounded,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Metode Prediksi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Deskripsi singkat ──────────────────────────────
              const Text(
                'Aplikasi ini menggunakan algoritma Double Exponential '
                'Smoothing (DES) untuk memprediksi tren kualitas air '
                'berdasarkan data historis sensor.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textGray,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),

              // ── Kotak rumus (scientific reference style) ────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label referensi
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Rumus DES — Holt’s Linear Trend Method',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Rumus
                    const Text(
                      'Lₜ = α · yₜ + (1 − α) · (Lₜ₋₁ + Tₜ₋₁)',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppTheme.primaryBlue,
                        height: 1.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'Tₜ = β · (Lₜ − Lₜ₋₁) + (1 − β) · Tₜ₋₁',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppTheme.primaryBlue,
                        height: 1.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'ŷₜ₊ₘ = Lₜ + m · Tₜ',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppTheme.primaryBlue,
                        height: 1.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Tabel keterangan parameter ──────────────────────
              _paramRow('α (alpha)', 'Faktor pemulusan level (0 < α < 1)'),
              _paramRow('β (beta)', 'Faktor pemulusan tren (0 < β < 1)'),
              _paramRow('Lₜ', 'Nilai level (rata-rata lokal) pada waktu t'),
              _paramRow('Tₜ', 'Nilai tren (kemiringan) pada waktu t'),
              _paramRow('ŷₜ₊ₘ', 'Nilai prediksi m langkah ke depan'),
              const SizedBox(height: 16),

              // ── Catatan tujuan untuk petambak ───────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.statusSafe.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.statusSafe.withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tips_and_updates_rounded,
                        color: AppTheme.statusSafe, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Algoritma ini membantu petambak mengantisipasi '
                        'perubahan Suhu, pH, dan Kekeruhan '
                        'secara dini, sehingga tindakan pencegahan dapat '
                        'dilakukan sebelum kondisi air menjadi berbahaya '
                        'bagi udang.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textDark,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper baris keterangan parameter rumus ────────────────────
  Widget _paramRow(String symbol, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              symbol,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
          const Text(' —  ',
              style: TextStyle(fontSize: 12, color: AppTheme.textGray)),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textGray,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterTable() {
    final rows = [
      _ThresholdRow(
        parameter: 'Suhu Air',
        unit: '°C',
        min: WaterThreshold.tempMin,
        max: WaterThreshold.tempMax,
        icon: Icons.thermostat_rounded,
        color: const Color(0xFFFF6B6B),
        note: 'Optimal untuk pertumbuhan udang vaname',
      ),
      _ThresholdRow(
        parameter: 'pH Air',
        unit: 'pH',
        min: WaterThreshold.phMin,
        max: WaterThreshold.phMax,
        icon: Icons.science_rounded,
        color: const Color(0xFF6BCB77),
        note: 'Mencegah stress dan kematian udang',
      ),
      _ThresholdRow(
        parameter: 'Kekeruhan',
        unit: 'NTU',
        min: WaterThreshold.turbMin,
        max: WaterThreshold.turbMax,
        icon: Icons.opacity_rounded,
        color: const Color(0xFFB08968),
        note: 'Air terlalu keruh menghambat oksigen & pakan',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: rows.map((r) => _buildThresholdCard(r)).toList(),
      ),
    );
  }

  Widget _buildThresholdCard(_ThresholdRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: row.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(row.icon, color: row.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row.parameter} (${row.unit})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(row.note,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textGray)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Aman',
                    style: TextStyle(fontSize: 10, color: AppTheme.textGray)),
                Text(
                  '${row.min} – ${row.max}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: row.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo-aplikasi.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AquaMonitor',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('v1.0.0',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Aplikasi monitoring kualitas air tambak udang berbasis IoT '
                'dengan prediksi tren menggunakan algoritma Double Exponential '
                'Smoothing (DES) / Metode Holt. Dikembangkan sebagai tugas '
                'akhir (skripsi).',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textGray, height: 1.6),
              ),
              const SizedBox(height: 12),
              _infoRow(Icons.sensors_rounded, 'Sensor', 'Suhu, pH, Kekeruhan'),
              _infoRow(Icons.cloud_rounded, 'Backend', 'Firebase Realtime DB'),
              _infoRow(Icons.analytics_rounded, 'Algoritma',
                  'Double Exponential Smoothing'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.lightBlue),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textGray,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Internal data class ──────────────────────────────────────
class _ThresholdRow {
  final String parameter;
  final String unit;
  final double min;
  final double max;
  final IconData icon;
  final Color color;
  final String note;

  const _ThresholdRow({
    required this.parameter,
    required this.unit,
    required this.min,
    required this.max,
    required this.icon,
    required this.color,
    required this.note,
  });
}
