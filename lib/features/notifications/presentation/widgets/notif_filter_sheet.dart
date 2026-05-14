import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../data/notification_bucket.dart';

/// v102 DS v1 — bottom sheet filter for the Notifications screen.
///
/// Carries two settings:
///   * `unreadOnly` — when on, only unread items are shown.
///   * `buckets`   — the subset of buckets to display. An empty set
///     is treated as "show all" by the parent.
///
/// Pop's return value is a [NotifFilterResult]; `null` means cancel.
class NotifFilterResult {
  const NotifFilterResult({
    required this.unreadOnly,
    required this.buckets,
  });

  final bool unreadOnly;
  final Set<NotificationBucket> buckets;
}

class NotifFilterSheet extends StatefulWidget {
  const NotifFilterSheet({
    super.key,
    required this.initialUnreadOnly,
    required this.initialBuckets,
  });

  final bool initialUnreadOnly;
  final Set<NotificationBucket> initialBuckets;

  @override
  State<NotifFilterSheet> createState() => _NotifFilterSheetState();
}

class _NotifFilterSheetState extends State<NotifFilterSheet> {
  late bool _unreadOnly = widget.initialUnreadOnly;
  late Set<NotificationBucket> _buckets = {...widget.initialBuckets};

  @override
  Widget build(BuildContext context) {
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
            const Text(
              'فلترة الإشعارات',
              style: TextStyle(
                color: ZynColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: ZynSpacing.lg),
            // Unread-only toggle row.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ZynSpacing.md,
                vertical: ZynSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: ZynColors.surfaceAlt,
                borderRadius: BorderRadius.circular(ZynRadii.inner),
                border: Border.all(color: ZynColors.line),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'غير المقروء فقط',
                      style: TextStyle(
                        color: ZynColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: _unreadOnly,
                    activeThumbColor: ZynColors.primary500,
                    onChanged: (v) => setState(() => _unreadOnly = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZynSpacing.lg),
            const Text(
              'الأقسام',
              style: TextStyle(
                color: ZynColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ZynSpacing.sm),
            Wrap(
              spacing: ZynSpacing.sm,
              runSpacing: ZynSpacing.sm,
              children: [
                for (final b in NotificationBucket.values)
                  _BucketChip(
                    bucket: b,
                    selected: _buckets.contains(b),
                    onTap: () => setState(() {
                      if (_buckets.contains(b)) {
                        _buckets.remove(b);
                      } else {
                        _buckets.add(b);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: ZynSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _unreadOnly = false;
                      _buckets = {};
                    }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZynColors.muted,
                      side: const BorderSide(color: ZynColors.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZynRadii.inner),
                      ),
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: const Text('مسح الكل'),
                  ),
                ),
                const SizedBox(width: ZynSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      NotifFilterResult(
                        unreadOnly: _unreadOnly,
                        buckets: _buckets,
                      ),
                    ),
                    child: const Text('تطبيق'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BucketChip extends StatelessWidget {
  const _BucketChip({
    required this.bucket,
    required this.selected,
    required this.onTap,
  });

  final NotificationBucket bucket;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (tone, _, icon) = _styleFor(bucket);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZynRadii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZynSpacing.md,
            vertical: ZynSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? tone.withValues(alpha: 0.14) : ZynColors.surface,
            borderRadius: BorderRadius.circular(ZynRadii.pill),
            border: Border.all(
              color: selected ? tone : ZynColors.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? tone : ZynColors.muted,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                notificationBucketLabel(bucket),
                style: TextStyle(
                  color: selected ? tone : ZynColors.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, Color, IconData) _styleFor(NotificationBucket b) {
    return switch (b) {
      NotificationBucket.critical => (
        ZynColors.danger,
        ZynColors.dangerSoft,
        Icons.priority_high_rounded,
      ),
      NotificationBucket.suggestion => (
        ZynColors.accent,
        ZynColors.accentSoft,
        Icons.auto_awesome_rounded,
      ),
      NotificationBucket.update => (
        ZynColors.info,
        ZynColors.infoSoft,
        Icons.notifications_outlined,
      ),
    };
  }
}
