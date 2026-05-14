import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../data/weather_models.dart';

/// v102 DS v1 — "فترات اليوم" strip.
///
/// Three sub-cards side-by-side: الصباح / الظهر / بعد الظهر.
/// Each carries the slot's icon, temperature, and Arabic
/// condition label. All from real `weather.day_parts` payload —
/// no faking. When the backend omits a slot, that column shows
/// an "—" placeholder so the strip's width stays consistent.
class DayPeriodsStrip extends StatelessWidget {
  const DayPeriodsStrip({super.key, required this.dayParts});

  final WeatherDayParts dayParts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ZynSpacing.xs,
            vertical: ZynSpacing.xs,
          ),
          child: Text(
            'فترات اليوم',
            style: TextStyle(
              color: ZynColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: ZynSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PeriodCard(
                  label: 'الصباح',
                  slot: dayParts.morning,
                ),
              ),
              const SizedBox(width: ZynSpacing.sm),
              Expanded(
                child: _PeriodCard(
                  label: 'الظهر',
                  slot: dayParts.noon,
                ),
              ),
              const SizedBox(width: ZynSpacing.sm),
              Expanded(
                child: _PeriodCard(
                  label: 'بعد الظهر',
                  slot: dayParts.afternoon,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.label, required this.slot});

  final String label;
  final WeatherSlot? slot;

  @override
  Widget build(BuildContext context) {
    final s = slot;
    final temp =
        s?.temperature == null ? '--' : s!.temperature!.toStringAsFixed(1);
    final condition =
        s == null || s.conditionAr.isEmpty ? '—' : s.conditionAr;
    final icon = s?.icon ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.soft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (icon.isNotEmpty)
            Text(
              icon,
              style: const TextStyle(fontSize: 22, height: 1.0),
            )
          else
            const Icon(
              Icons.cloud_outlined,
              color: ZynColors.muted,
              size: 22,
            ),
          const SizedBox(height: 8),
          Text(
            '$temp°',
            style: const TextStyle(
              color: ZynColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.0,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            condition,
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
