// ============================================================
// Widget: GaugeCard
// Indikator busur (arc gauge) 270° untuk satu parameter.
// Menampilkan: ikon + judul, nilai di tengah busur, label min/max,
// badge status (aman/bahaya), dan teks rentang aman.
// Warna mengikuti sistem warna aplikasi (status: aman/bahaya).
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/water_quality_model.dart';
import '../theme/app_theme.dart';

class GaugeCard extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final String unit;
  final int decimals;
  final Color color;
  final IconData icon;
  final ParameterStatus status;
  final String safeRangeText;

  const GaugeCard({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.icon,
    required this.status,
    required this.safeRangeText,
    this.unit = '',
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Fraksi posisi jarum (0..1) terhadap rentang skala gauge.
    final fraction = max > min
        ? ((value - min) / (max - min)).clamp(0.0, 1.0)
        : 0.0;
    final label = statusLabel(status);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          children: [
            // ── Judul + ikon parameter ───────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: AppTheme.textGray,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppTheme.primaryBlue, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Gauge + nilai tengah + label min/max ─────────
            SizedBox(
              height: 110,
              child: CustomPaint(
                painter: _GaugePainter(
                  fraction: fraction,
                  color: color,
                  trackColor: color.withOpacity(0.15),
                ),
                child: Stack(
                  children: [
                    // Nilai di tengah busur
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            value.toStringAsFixed(decimals),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: color,
                              height: 1,
                            ),
                          ),
                          if (unit.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                unit,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textGray,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Label batas bawah (min) — sudut kiri bawah
                    Positioned(
                      left: 4,
                      bottom: 2,
                      child: Text(
                        min.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGray,
                        ),
                      ),
                    ),
                    // Label batas atas (max) — sudut kanan bawah
                    Positioned(
                      right: 4,
                      bottom: 2,
                      child: Text(
                        max.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Badge status (aman/bahaya) ───────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == ParameterStatus.safe
                        ? Icons.check_circle_rounded
                        : Icons.warning_rounded,
                    color: color,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // ── Teks rentang aman ────────────────────────────
            Text(
              'Rentang aman: $safeRangeText',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Painter busur gauge ──────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double fraction; // 0..1
  final Color color;
  final Color trackColor;

  _GaugePainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  // Busur 270° dengan celah di bawah:
  // mulai 135° (kiri-bawah) menyapu searah jarum jam ke 45° (kanan-bawah).
  static const double _startAngle = 3 * pi / 4; // 135°
  static const double _sweepTotal = 3 * pi / 2; // 270°
  static const double _stroke = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final side = min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (side - _stroke) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // Track (latar busur)
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(arcRect, _startAngle, _sweepTotal, false, trackPaint);

    // Nilai (busur berwarna sesuai status)
    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      arcRect,
      _startAngle,
      _sweepTotal * fraction,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.trackColor != trackColor;
}
