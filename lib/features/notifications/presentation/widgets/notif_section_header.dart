import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';

/// v102 DS v1 — section header for each notification bucket.
///
/// "تنبيهات حرجة [4]"-style row. The label and count badge sit
/// on the (right in RTL) reading-start side; a small tone-coloured
/// icon dot precedes them. Generous horizontal padding inside the
/// row gives the section a clear vertical break between buckets
/// without needing a divider line.
class NotifSectionHeader extends StatelessWidget {
  const NotifSectionHeader({
    super.key,
    required this.label,
    required this.count,
    required this.tone,
    required this.icon,
  });

  final String label;
  final int count;
  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZynSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tone, size: 13),
          ),
          const SizedBox(width: ZynSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              color: ZynColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: ZynSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(ZynRadii.pill),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.0,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
