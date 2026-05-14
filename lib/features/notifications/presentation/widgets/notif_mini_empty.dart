import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../data/notification_bucket.dart';

/// v102 DS v1 — compact "this section is empty" placeholder.
///
/// Used inside the Notifications screen when a bucket has no
/// items so the section header still has a body underneath. Keeps
/// the screen's structure visible (three sections) even on a quiet
/// day, instead of collapsing to a screen that reads as "Critical
/// Alerts only".
///
/// Single row, ~64 dp tall, tone-tinted check icon + a short
/// label like "لا اقتراحات جديدة".
class NotifMiniEmpty extends StatelessWidget {
  const NotifMiniEmpty({super.key, required this.bucket});

  final NotificationBucket bucket;

  @override
  Widget build(BuildContext context) {
    final tone = switch (bucket) {
      NotificationBucket.critical => ZynColors.danger,
      NotificationBucket.suggestion => ZynColors.accent,
      NotificationBucket.update => ZynColors.info,
    };
    final label = switch (bucket) {
      NotificationBucket.critical => 'لا تنبيهات حرجة الآن — حالة النظام جيدة.',
      NotificationBucket.suggestion =>
          'لا توجد اقتراحات جديدة في الوقت الحالي.',
      NotificationBucket.update => 'لا تحديثات دورية حديثة.',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: tone,
              size: 16,
            ),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ZynColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
