import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';

/// v102 DS v1 — section header for each notification bucket.
///
/// "تنبيهات حرجة [4]"-style row: title on the (right, RTL) side,
/// tone-coloured count badge after the title, leading accent icon
/// on the (right-of-text in RTL) edge.
///
/// Per the screenshot the icon sits to the *inside* of the title
/// (i.e. between title and badge), so we render with the badge on
/// the (left in RTL) side as a circular pill.
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: tone, size: 18),
        const SizedBox(width: ZynSpacing.sm),
        Text(
          label,
          style: const TextStyle(
            color: ZynColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(width: ZynSpacing.sm),
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone,
            shape: BoxShape.circle,
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
    );
  }
}
