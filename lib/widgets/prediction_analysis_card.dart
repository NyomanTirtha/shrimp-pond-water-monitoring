// ============================================================
// Widget: PredictionAnalysisCard
// Menampilkan analisis tekstual cerdas berdasarkan hasil DES.
//
// Parameter:
//   parameterName  – nama parameter (e.g., "Suhu Air")
//   unit           – satuan (e.g., "°C", "NTU")
//   currentValue   – nilai terakhir aktual dari sensor
//   predictedValue – nilai prediksi DES pertama (F+1)
//   safeMin        – batas bawah aman
//   safeMax        – batas atas aman
//   thresholdPct   – persentase perubahan yang dianggap "signifikan"
//                    (default 5% dari range aman)
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Enum tren ─────────────────────────────────────────────────
// Urutan prioritas dari tinggi ke rendah:
//   danger (Prioritas 1) → riseSignificant / fallSignificant / stable (Prioritas 2)
enum _TrendType { danger, riseSignificant, fallSignificant, stable }

// ─── Model hasil analisis (mudah diperluas untuk skripsi) ──────
class AnalysisResult {
  final _TrendType trend;
  final double changeValue;   // selisih absolut: predictedValue - currentValue
  final double changePct;     // persentase perubahan terhadap currentValue
  final bool outOfSafeRange;  // apakah prediksi keluar dari rentang aman
  final String message;
  final String recommendation;

  const AnalysisResult({
    required this.trend,
    required this.changeValue,
    required this.changePct,
    required this.outOfSafeRange,
    required this.message,
    required this.recommendation,
  });
}

// ─── Fungsi analisis (pure function, mudah diuji) ──────────────
//
// SISTEM PRIORITAS PESAN:
//   1. Safety Check  → jika predictedValue di luar [safeMin, safeMax]
//                      tampilkan pesan BAHAYA, abaikan tren.
//   2. Trend Check   → hanya jika nilai prediksi AMAN,
//                      tampilkan analisis DES (naik / turun / stabil).
//
AnalysisResult analyzeParameter({
  required String parameterName,
  required double currentValue,
  required double predictedValue,
  required double safeMin,
  required double safeMax,
  double thresholdPct = 5.0,  // threshold signifikan = 5%
}) {
  final double changeValue = predictedValue - currentValue;
  final double changePct =
      currentValue != 0 ? (changeValue / currentValue).abs() * 100 : 0;
  final bool outOfSafeRange =
      predictedValue < safeMin || predictedValue > safeMax;

  // ── PRIORITAS 1: Safety Check ──────────────────────────────
  // Jika prediksi berada di luar rentang aman, hentikan analisis
  // tren dan langsung tampilkan pesan bahaya.
  if (outOfSafeRange) {
    final String zone = predictedValue < safeMin ? 'terlalu rendah' : 'terlalu tinggi';
    return AnalysisResult(
      trend: _TrendType.danger,
      changeValue: changeValue,
      changePct: changePct,
      outOfSafeRange: true,
      message:
          'PERINGATAN: $parameterName diprediksi $zone (${predictedValue.toStringAsFixed(2)}) '
          'dan berada di zona berbahaya. Segera lakukan penanganan!',
      recommendation:
          'Hentikan aktivitas normal dan periksa sumber masalah. '
          'Pastikan aerasi, kualitas pakan, dan sumber air masuk dicek segera.',
    );
  }

  // ── PRIORITAS 2: Trend Check (hanya jika nilai AMAN) ────────
  _TrendType trend;
  String message;
  String recommendation;

  if (changePct >= thresholdPct && changeValue > 0) {
    // Naik signifikan
    trend = _TrendType.riseSignificant;
    message = 'Tren $parameterName menunjukkan kenaikan '
        '(+${changeValue.toStringAsFixed(2)}).'
        ' Nilai masih dalam rentang aman.';
    recommendation =
        'Pastikan sirkulasi air berjalan baik untuk menjaga kestabilan.';
  } else if (changePct >= thresholdPct && changeValue < 0) {
    // Turun signifikan
    trend = _TrendType.fallSignificant;
    message = 'Tren $parameterName cenderung menurun '
        '(${changeValue.toStringAsFixed(2)}).'
        ' Nilai masih dalam rentang aman.';
    recommendation =
        'Pantau terus kondisi air. Segera cek jika penurunan berlanjut.';
  } else {
    // Stabil
    trend = _TrendType.stable;
    message =
        '$parameterName diprediksi stabil pada '
        '${predictedValue.toStringAsFixed(2)} untuk beberapa waktu ke depan.';
    recommendation = 'Pertahankan kondisi pengelolaan air saat ini.';
  }

  return AnalysisResult(
    trend: trend,
    changeValue: changeValue,
    changePct: changePct,
    outOfSafeRange: false,
    message: message,
    recommendation: recommendation,
  );
}

// ─── Widget utama ─────────────────────────────────────────────
class PredictionAnalysisCard extends StatelessWidget {
  final String parameterName;
  final String unit;
  final double currentValue;
  final double predictedValue;  // nilai F+1 dari DES
  final double safeMin;
  final double safeMax;

  const PredictionAnalysisCard({
    super.key,
    required this.parameterName,
    required this.unit,
    required this.currentValue,
    required this.predictedValue,
    required this.safeMin,
    required this.safeMax,
  });

  @override
  Widget build(BuildContext context) {
    final result = analyzeParameter(
      parameterName: parameterName,
      currentValue: currentValue,
      predictedValue: predictedValue,
      safeMin: safeMin,
      safeMax: safeMax,
    );

    // ── Tentukan palet warna berdasarkan tren ────────────
    final Color accentColor = _accentColor(result);
    final Color bgColor = accentColor.withOpacity(0.07);
    final Color borderColor = accentColor.withOpacity(0.35);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          _buildHeader(result, accentColor),
          // ── Divider halus ────────────────────────────────
          Divider(height: 1, color: borderColor),
          // ── Body: pesan + rekomendasi ────────────────────
          _buildBody(result, accentColor),
          // ── Footer: peringatan out-of-range (kondisional) ─
          if (result.outOfSafeRange) _buildWarningBanner(safeMin, safeMax),
        ],
      ),
    );
  }

  // ── Header: judul + badge tren + chip perubahan ─────────────
  Widget _buildHeader(AnalysisResult result, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: [
          // Ikon status tren
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_trendIcon(result.trend), color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          // Judul
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analisis Cerdas',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textGray,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  parameterName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          // Chip perubahan nilai
          _ChangeChip(
            changeValue: result.changeValue,
            unit: unit,
            color: accent,
          ),
        ],
      ),
    );
  }

  // ── Body: pesan + rekomendasi ──────────────────────────────
  Widget _buildBody(AnalysisResult result, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pesan utama
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_graph_rounded, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  result.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Rekomendasi
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: AppTheme.textGray),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  result.recommendation,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGray,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Baris nilai saat ini vs prediksi
          _ValueCompareRow(
            currentValue: currentValue,
            predictedValue: predictedValue,
            unit: unit,
            accent: accent,
          ),
        ],
      ),
    );
  }

  // ── Banner peringatan jika prediksi di luar batas aman ──────
  Widget _buildWarningBanner(double min, double max) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.statusDanger.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.statusDanger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Nilai prediksi berada di luar rentang aman ($min – $max $unit). '
              'Perlu tindakan segera!',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.statusDanger,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────
  Color _accentColor(AnalysisResult r) {
    if (r.outOfSafeRange) return AppTheme.statusDanger;
    switch (r.trend) {
      case _TrendType.riseSignificant:
        return const Color(0xFFFF8C42);  // oranye hangat
      case _TrendType.fallSignificant:
        return const Color(0xFF5B8DEF);  // biru medium
      case _TrendType.stable:
        return AppTheme.statusSafe;      // hijau
        case _TrendType.danger:
    return Colors.red;
    }
  }

  IconData _trendIcon(_TrendType trend) {
    switch (trend) {
      case _TrendType.danger:
        return Icons.warning_amber_rounded;
      case _TrendType.riseSignificant:
        return Icons.trending_up_rounded;
      case _TrendType.fallSignificant:
        return Icons.trending_down_rounded;
      case _TrendType.stable:
        return Icons.trending_flat_rounded;
    }
  }
}

// ─── Sub-widget: chip perubahan nilai (+x.xx / -x.xx) ────────
class _ChangeChip extends StatelessWidget {
  final double changeValue;
  final String unit;
  final Color color;

  const _ChangeChip({
    required this.changeValue,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final sign = changeValue >= 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$sign${changeValue.toStringAsFixed(2)} $unit',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── Sub-widget: baris perbandingan nilai aktual vs prediksi ──
class _ValueCompareRow extends StatelessWidget {
  final double currentValue;
  final double predictedValue;
  final String unit;
  final Color accent;

  const _ValueCompareRow({
    required this.currentValue,
    required this.predictedValue,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ValueBox(
          label: 'Saat Ini',
          value: currentValue.toStringAsFixed(2),
          unit: unit,
          color: AppTheme.textGray,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded,
              size: 16, color: AppTheme.textGray),
        ),
        _ValueBox(
          label: 'Prediksi F+1',
          value: predictedValue.toStringAsFixed(2),
          unit: unit,
          color: accent,
          highlighted: true,
        ),
      ],
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool highlighted;

  const _ValueBox({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? color.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted ? color.withOpacity(0.3) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textGray)),
          const SizedBox(height: 2),
          Text(
            '$value $unit',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: highlighted ? color : AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
