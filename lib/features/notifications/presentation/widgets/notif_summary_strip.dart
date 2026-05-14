import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';

/// v102 DS v1 — three-up summary strip at the top of the
/// Notifications screen.
///
/// Each card carries a tone (success / danger / brand), a corner
/// icon, an optional big number, a short title, and a one-line
/// subtitle. The summary is purely informational — tapping it does
/// not (yet) scroll-to-section. Owner can wire that in a follow-up.
class NotifSummaryStrip extends StatelessWidget {
  const NotifSummaryStrip({
    super.key,
    required this.criticalCount,
    required this.unreadCount,
    required this.batteryStable,
  });

  final int criticalCount;
  final int unreadCount;
  final bool batteryStable;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight gives all three cards the same height via the
    // tallest card's intrinsic measurement, but explicitly bounds
    // vertical for the Row so we don't depend on stretch behaviour
    // inside an unbounded ListView slot (which was silently
    // collapsing the rest of the page on real devices).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Expanded(
          child: _SummaryCard(
            tone: batteryStable ? ZynColors.success : ZynColors.warning,
            toneSoft: batteryStable
                ? ZynColors.successSoft
                : ZynColors.warningSoft,
            icon: batteryStable
                ? Icons.battery_full_rounded
                : Icons.battery_alert_rounded,
            footerIcon: batteryStable
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            title: batteryStable ? 'بطارية مستقرة' : 'البطارية تحتاج انتباه',
            value: null,
            subtitle:
                batteryStable ? 'الحالة العامة ممتازة' : 'راجع التنبيهات الحرجة',
          ),
        ),
        const SizedBox(width: ZynSpacing.sm),
        Expanded(
          child: _SummaryCard(
            tone: ZynColors.danger,
            toneSoft: ZynColors.dangerSoft,
            icon: Icons.priority_high_rounded,
            footerIcon: null,
            title: 'حرجة',
            value: '$criticalCount',
            subtitle: 'تحتاج انتباهك',
          ),
        ),
        const SizedBox(width: ZynSpacing.sm),
        Expanded(
          child: _SummaryCard(
            tone: ZynColors.primary500,
            toneSoft: ZynColors.primary50,
            icon: Icons.notifications_active_rounded,
            footerIcon: null,
            title: 'غير مقروء',
            value: '$unreadCount',
            subtitle: 'إجمالي الإشعارات',
          ),
        ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.tone,
    required this.toneSoft,
    required this.icon,
    required this.footerIcon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final Color tone;
  final Color toneSoft;
  final IconData icon;
  final IconData? footerIcon;
  final String title;
  final String? value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZynSpacing.md),
      decoration: BoxDecoration(
        color: toneSoft,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(
          color: tone.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top icon — tone-coloured filled circle. Column's
          // crossAxisAlignment.start places it on the start edge
          // automatically; the previous Align wrapper was eating
          // the column's vertical layout in some contexts.
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tone, size: 16),
          ),
          const SizedBox(height: ZynSpacing.sm),
          if (value != null) ...[
            Text(
              value!,
              style: TextStyle(
                color: tone,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.0,
                letterSpacing: -0.4,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            title,
            style: TextStyle(
              color: ZynColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (footerIcon != null) ...[
                Icon(footerIcon, color: tone, size: 12),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZynColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
