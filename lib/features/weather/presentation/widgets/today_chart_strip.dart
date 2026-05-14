import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../data/weather_models.dart';

/// v102 DS v1 — "مخطط اليوم" horizontal strip.
///
/// Scrollable row of forecast tiles built from `weather.timeline`
/// (the 6 fixed hours the backend currently surfaces — 08, 10,
/// 12, 14, 16, 18). Each tile carries:
///   * the hour label (Arabic AM/PM via `time_label`)
///   * weather icon + temperature
///   * cloud %
///   * the slot's `solar_rating` chip (production verdict)
///
/// When the timeline is empty, the strip collapses to a single
/// honest placeholder line instead of fabricating values.
class TodayChartStrip extends StatelessWidget {
  const TodayChartStrip({super.key, required this.timeline});

  final List<WeatherSlot> timeline;

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
            'مخطط اليوم',
            style: TextStyle(
              color: ZynColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: ZynSpacing.sm),
        if (timeline.isEmpty)
          _emptyShell()
        else
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: ZynSpacing.xs,
              ),
              itemCount: timeline.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: ZynSpacing.sm),
              itemBuilder: (_, i) => _HourTile(slot: timeline[i]),
            ),
          ),
      ],
    );
  }

  Widget _emptyShell() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.timeline_rounded,
            color: ZynColors.muted,
            size: 16,
          ),
          SizedBox(width: ZynSpacing.sm),
          Expanded(
            child: Text(
              'لا توجد بيانات ساعات لعرضها الآن.',
              style: TextStyle(
                color: ZynColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HourTile extends StatelessWidget {
  const _HourTile({required this.slot});

  final WeatherSlot slot;

  @override
  Widget build(BuildContext context) {
    final tone = _toneForRating(slot.solarRating);
    final timeLabel = slot.timeLabel ?? '—';
    final temp = slot.temperature == null
        ? '--'
        : slot.temperature!.toStringAsFixed(1);
    final cloud = slot.cloudCover == null
        ? '—'
        : '${slot.cloudCover!.toStringAsFixed(0)}%';

    return Container(
      width: 96,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
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
            timeLabel,
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 8),
          if (slot.icon.isNotEmpty)
            Text(
              slot.icon,
              style: const TextStyle(fontSize: 22, height: 1.0),
            )
          else
            const Icon(
              Icons.cloud_outlined,
              color: ZynColors.muted,
              size: 22,
            ),
          const SizedBox(height: 6),
          Text(
            '$temp°',
            style: const TextStyle(
              color: ZynColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.0,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cloud,
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            textDirection: TextDirection.ltr,
          ),
          const Spacer(),
          if (slot.solarRating.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(ZynRadii.pill),
              ),
              child: Text(
                slot.solarRating,
                style: TextStyle(
                  color: tone,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Color _toneForRating(String rating) {
    if (rating.contains('قوي')) return ZynColors.success;
    if (rating.contains('متوسط')) return ZynColors.warning;
    if (rating.contains('ضعيف') || rating.contains('منخفض')) {
      return ZynColors.danger;
    }
    return ZynColors.muted;
  }
}
