import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../data/weather_models.dart';

/// v102 DS v1 — sunrise + sunset card.
///
/// Two columns: sunrise on the (reading-start) side in soft
/// amber, sunset on the (reading-end) side in cool indigo.
/// Each column carries the time + a helper line:
///   * sunrise: when solar production usually kicks in
///   * sunset:  how long until darkness
///
/// Helper text comes from [computeProductionKickInLabel] and
/// [computeDarknessInLabel] which are passed in as plain
/// strings — the screen computes them once from the
/// `effective_sunrise_time` / `effective_sunset_time` payload
/// so the card stays a pure presentation widget.
class SunTimesCard extends StatelessWidget {
  const SunTimesCard({
    super.key,
    required this.sun,
    required this.productionKickInLabel,
    required this.darknessInLabel,
  });

  final WeatherSun sun;
  final String productionKickInLabel;
  final String darknessInLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.soft(),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _SunColumn(
                label: 'الشروق',
                time: sun.sunriseTime ?? '—',
                helper: productionKickInLabel,
                tone: ZynColors.warning,
                icon: Icons.wb_twilight_rounded,
              ),
            ),
            VerticalDivider(
              color: ZynColors.line,
              width: 24,
              thickness: 1,
            ),
            Expanded(
              child: _SunColumn(
                label: 'الغروب',
                time: sun.sunsetTime ?? '—',
                helper: darknessInLabel,
                tone: ZynColors.accent,
                icon: Icons.nightlight_round,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SunColumn extends StatelessWidget {
  const _SunColumn({
    required this.label,
    required this.time,
    required this.helper,
    required this.tone,
    required this.icon,
  });

  final String label;
  final String time;
  final String helper;
  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tone, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: tone,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          time,
          style: const TextStyle(
            color: ZynColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.0,
            fontFeatures: [FontFeature.tabularFigures()],
            letterSpacing: -0.3,
          ),
          textDirection: TextDirection.ltr,
        ),
        if (helper.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            helper,
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
