import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../data/weather_models.dart';

/// v102 DS v1 — "الساعة القادمة" card.
///
/// Shows the next-hour forecast slot from `/weather` + the
/// computed `solar_rating` ("إنتاج قوي" / "متوسط" / "ضعيف") in
/// a tone-coloured progress-style pill, plus the slot's
/// `advice` line below.
///
/// When the slot is null (backend doesn't have a forecast for
/// the next hour — e.g. at night), the card hides honestly.
class NextHourCard extends StatelessWidget {
  const NextHourCard({super.key, required this.slot});

  final WeatherSlot? slot;

  @override
  Widget build(BuildContext context) {
    final s = slot;
    if (s == null) {
      return _UnavailableShell(
        message: 'لا توجد بيانات لساعة لاحقة الآن.',
      );
    }
    final tone = _toneForRating(s.solarRating);
    final timeLabel = s.timeLabel ?? '—';
    final temp =
        s.temperature == null ? '--' : s.temperature!.toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.soft(),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.access_time_rounded,
                  color: tone,
                  size: 16,
                ),
              ),
              const SizedBox(width: ZynSpacing.md),
              const Expanded(
                child: Text(
                  'الساعة القادمة',
                  style: TextStyle(
                    color: ZynColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      color: ZynColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.icon.isNotEmpty) ...[
                        Text(
                          s.icon,
                          style: const TextStyle(fontSize: 14, height: 1.0),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '$temp°',
                        style: const TextStyle(
                          color: ZynColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (s.solarRating.isNotEmpty) ...[
            const SizedBox(height: ZynSpacing.md),
            _RatingPill(rating: s.solarRating, tone: tone),
          ],
          if (s.advice.isNotEmpty) ...[
            const SizedBox(height: ZynSpacing.sm),
            Text(
              s.advice,
              style: const TextStyle(
                color: ZynColors.inkSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ],
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

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating, required this.tone});

  final String rating;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZynSpacing.md,
        vertical: ZynSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZynRadii.pill),
        border: Border.all(
          color: tone.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        rating,
        style: TextStyle(
          color: tone,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

class _UnavailableShell extends StatelessWidget {
  const _UnavailableShell({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            color: ZynColors.muted,
            size: 16,
          ),
          const SizedBox(width: ZynSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
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
