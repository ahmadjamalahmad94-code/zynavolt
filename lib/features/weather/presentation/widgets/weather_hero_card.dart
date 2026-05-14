import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../data/weather_models.dart';

/// v102 DS v1 — Weather hero card.
///
/// One focal card per screen, per Modern Mobile SaaS Energy DS:
/// soft sky-blue gradient surface, big temperature on one side,
/// a subtle stylised sun-and-clouds CustomPainter on the other
/// (data first — artwork stays at low opacity so it never steals
/// focus). Beneath the temperature is a metadata row (cloud %,
/// wind, precip %) and a small inset card showing today's solar
/// production so far — all from REAL backend data, never faked.
///
/// Inputs:
///   * [current] — `weather.current` block (temp, wind, cloud,
///     precip, condition_ar, icon).
///   * [productionKwhToday] — optional kWh number from
///     `/statistics?view=day`. When null, the inset card is
///     hidden honestly instead of showing a fake "0.0".
class WeatherHeroCard extends StatelessWidget {
  const WeatherHeroCard({
    super.key,
    required this.current,
    required this.productionKwhToday,
    required this.productionVerdict,
  });

  final WeatherCurrent current;

  /// Today's solar production so far, in kilowatt-hours. Null
  /// when statistics isn't available yet — hide the inset card.
  final double? productionKwhToday;

  /// Short Arabic verdict for the inset card subtitle, e.g.
  /// "ممتاز" / "متوسط" / "ضعيف". Sourced from `next_hour`'s
  /// `solar_rating` so the wording stays consistent with the
  /// rest of the screen.
  final String? productionVerdict;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: ZynColors.skyHero,
        borderRadius: BorderRadius.circular(ZynRadii.hero),
        boxShadow: ZynShadows.med(tint: ZynColors.primary500),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ZynRadii.hero),
        child: Stack(
          children: [
            // Subtle artwork — sun + clouds + tiny solar bars on
            // the leading side (left in LTR / right in RTL).
            // Owner brief: subtle, doesn't steal data focus.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _HeroArtwork(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZynSpacing.lg,
                ZynSpacing.lg,
                ZynSpacing.lg,
                ZynSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopRow(current: current),
                  const SizedBox(height: ZynSpacing.md),
                  _Divider(),
                  const SizedBox(height: ZynSpacing.md),
                  _MetaRow(current: current),
                  if (productionKwhToday != null) ...[
                    const SizedBox(height: ZynSpacing.md),
                    _ProductionInset(
                      kwh: productionKwhToday!,
                      verdict: productionVerdict,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.current});

  final WeatherCurrent current;

  @override
  Widget build(BuildContext context) {
    final temp = current.temperatureC;
    final tempText = temp == null ? '--' : temp.toStringAsFixed(1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tempText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      letterSpacing: -1.0,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 4, left: 4),
                    child: Text(
                      '°',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                current.conditionAr.isEmpty ? '—' : current.conditionAr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (current.icon.isNotEmpty)
          Text(
            current.icon,
            style: const TextStyle(fontSize: 36, height: 1.0),
          ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.current});

  final WeatherCurrent current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetaItem(
            icon: Icons.cloud_outlined,
            label: 'الغيوم',
            value:
                '${(current.cloudCoverPercent ?? 0).toStringAsFixed(0)}%',
          ),
        ),
        Expanded(
          child: _MetaItem(
            icon: Icons.air_rounded,
            label: 'الرياح',
            value:
                '${(current.windSpeed ?? 0).toStringAsFixed(1)} كم/س',
          ),
        ),
        Expanded(
          child: _MetaItem(
            icon: Icons.water_drop_outlined,
            label: 'المطر',
            value:
                '${(current.precipitationProbabilityPercent ?? 0).toStringAsFixed(0)}%',
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.2,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ProductionInset extends StatelessWidget {
  const _ProductionInset({required this.kwh, required this.verdict});

  final double kwh;
  final String? verdict;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(ZynRadii.card),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZynColors.success.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.show_chart_rounded,
              color: ZynColors.success,
              size: 18,
            ),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'إنتاج شمسي اليوم',
                  style: TextStyle(
                    color: ZynColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if ((verdict ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      verdict!,
                      style: const TextStyle(
                        color: ZynColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: ZynColors.line,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kwh.toStringAsFixed(1),
                style: const TextStyle(
                  color: ZynColors.success,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'kWh',
                style: TextStyle(
                  color: ZynColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Subtle hero artwork — a sun disk with rays + two clouds + a
/// row of stylised solar bars. Painted at low alpha so the
/// temperature reads clearly. Positioned on the leading side
/// (left in LTR / right in RTL) so the temperature on the
/// trailing side stays unobstructed.
class _HeroArtwork extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sun
    final sunPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final sunCx = w * 0.18;
    final sunCy = h * 0.30;
    final sunR = math.min(w, h) * 0.10;
    canvas.drawCircle(Offset(sunCx, sunCy), sunR, sunPaint);

    // Sun rays — short tapered triangles
    final rayPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final start = Offset(
        sunCx + math.cos(angle) * sunR * 1.25,
        sunCy + math.sin(angle) * sunR * 1.25,
      );
      final end = Offset(
        sunCx + math.cos(angle) * sunR * 1.7,
        sunCy + math.sin(angle) * sunR * 1.7,
      );
      canvas.drawLine(start, end, rayPaint);
    }

    // Two soft clouds
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    _drawCloud(canvas, cloudPaint, Offset(w * 0.30, h * 0.40), sunR * 0.55);
    _drawCloud(canvas, cloudPaint, Offset(w * 0.10, h * 0.55), sunR * 0.45);

    // Tiny solar-panel bars near the lower-leading edge
    final barPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final barBaseY = h * 0.82;
    for (var i = 0; i < 4; i++) {
      final x = w * 0.05 + i * (w * 0.05);
      final barH = h * 0.06 + (i.isEven ? 4 : -2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, barBaseY - barH, w * 0.035, barH),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }
  }

  void _drawCloud(Canvas canvas, Paint paint, Offset c, double r) {
    canvas.drawCircle(c, r, paint);
    canvas.drawCircle(Offset(c.dx + r * 0.8, c.dy + r * 0.1), r * 0.9, paint);
    canvas.drawCircle(Offset(c.dx - r * 0.8, c.dy + r * 0.1), r * 0.85, paint);
    canvas.drawCircle(Offset(c.dx + r * 0.3, c.dy - r * 0.6), r * 0.7, paint);
  }

  @override
  bool shouldRepaint(covariant _HeroArtwork oldDelegate) => false;
}
