import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../../../core/utils/backend_time.dart';
import '../../data/notification_bucket.dart';
import '../../data/notification_models.dart';

/// v102 DS v1 — bottom sheet shown when the user taps a notification
/// tile. Renders the full title + message + a tone-coloured header
/// chip + an "تعليم كمقروء" CTA when the notification is still
/// unread.
///
/// Pure presentation; the parent owns mark-read side effects.
/// Returns from `Navigator.pop()` so callers can await it.
class NotifDetailSheet extends StatelessWidget {
  const NotifDetailSheet({
    super.key,
    required this.notification,
    required this.bucket,
    required this.onMarkRead,
  });

  final AppNotification notification;
  final NotificationBucket bucket;
  final Future<void> Function() onMarkRead;

  @override
  Widget build(BuildContext context) {
    final tone = switch (bucket) {
      NotificationBucket.critical => ZynColors.danger,
      NotificationBucket.suggestion => ZynColors.accent,
      NotificationBucket.update => ZynColors.info,
    };
    final mq = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: ZynSpacing.lg,
          right: ZynSpacing.lg,
          bottom: ZynSpacing.lg + mq.viewInsets.bottom,
          top: ZynSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(ZynRadii.pill),
                  ),
                  child: Text(
                    notificationBucketLabel(bucket),
                    style: TextStyle(
                      color: tone,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                ),
                const Spacer(),
                if (notification.createdAt != null)
                  Text(
                    formatBackendDateTime(notification.createdAt) ?? '',
                    style: const TextStyle(
                      color: ZynColors.faint,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    textDirection: TextDirection.ltr,
                  ),
              ],
            ),
            const SizedBox(height: ZynSpacing.md),
            Text(
              notification.title.isEmpty ? '—' : notification.title,
              style: const TextStyle(
                color: ZynColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            if (notification.message.isNotEmpty) ...[
              const SizedBox(height: ZynSpacing.sm),
              Text(
                notification.message,
                style: const TextStyle(
                  color: ZynColors.inkSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                ),
              ),
            ],
            const SizedBox(height: ZynSpacing.xl),
            if (!notification.isRead)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await onMarkRead();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('تعليم كمقروء'),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ZynColors.successSoft,
                  borderRadius: BorderRadius.circular(ZynRadii.inner),
                  border: Border.all(
                    color: ZynColors.success.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: ZynColors.success,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      notification.readAt == null
                          ? 'تم قراءة هذا الإشعار'
                          : 'قُرِئ في ${formatBackendDateTime(notification.readAt) ?? ''}',
                      style: const TextStyle(
                        color: ZynColors.success,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
