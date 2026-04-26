// ============================================================
// Widget: ParameterCard
// Reusable card showing a single water quality parameter.
// ============================================================

import 'package:flutter/material.dart';
import '../models/water_quality_model.dart';
import '../theme/app_theme.dart';

class ParameterCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final ParameterStatus status;
  final String safeRangeText;

  const ParameterCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.status,
    required this.safeRangeText,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final label = statusLabel(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ── Icon badge ─────────────────────────────────
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.primaryBlue, size: 28),
              ),
              const SizedBox(width: 16),

              // ── Values ─────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            unit,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rentang aman: $safeRangeText',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textGray,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Status badge ───────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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
}
