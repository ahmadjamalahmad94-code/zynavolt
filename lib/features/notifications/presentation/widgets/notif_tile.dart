import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../../../core/utils/backend_time.dart';
import '../../data/notification_bucket.dart';
import '../../data/notification_models.dart';

/// v102 DS v1 — notification tile, calm operational variant.
///
/// Matches the 2026-05-14 reference image: a predominantly WHITE
/// card with a thin tone-coloured border, a soft circular icon
/// chip on the leading edge, the title + a one-or-two-line
/// description, a small tone-coloured pill below, and the
/// timestamp anchored to the trailing column. Unread items get a
/// very faint tinted background (alpha ~0.06) so the whole screen
/// doesn't wash in any one tone.
///
/// Earlier drafts wrapped a `Stack` + `PositionedDirectional`
/// accent strip that bled past the card's rounded corners on
/// device. Dropped in this pass — the colour signal comes from
/// border + icon + pill, not from a separate overlay.
class NotifTile extends StatelessWidget {
  const NotifTile({
    super.key,
    required this.notification,
    required this.bucket,
    required this.onTap,
  });

  final AppNotification notification;
  final NotificationBucket bucket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (tone, icon, chipLabel) = _bucketStyle(bucket, notification);
    final time = _formatTimestamp(notification.createdAt);
    final isUnread = !notification.isRead;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        child: Ink(
          decoration: BoxDecoration(
            color: isUnread
                ? tone.withValues(alpha: 0.06)
                : ZynColors.surface,
            borderRadius: BorderRadius.circular(ZynRadii.card),
            border: Border.all(
              color: tone.withValues(alpha: isUnread ? 0.30 : 0.16),
              width: 1,
            ),
            boxShadow: ZynShadows.soft(),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ZynSpacing.md,
              ZynSpacing.md,
              ZynSpacing.md,
              ZynSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconChip(tone: tone, icon: icon),
                const SizedBox(width: ZynSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (isUnread) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: tone,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              notification.title.isEmpty
                                  ? '—'
                                  : notification.title,
                              style: const TextStyle(
                                color: ZynColors.ink,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (notification.message.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          notification.message,
                          style: const TextStyle(
                            color: ZynColors.inkSoft,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (chipLabel.isNotEmpty) ...[
                        const SizedBox(height: ZynSpacing.sm),
                        _ChipLabel(tone: tone, text: chipLabel),
                      ],
                    ],
                  ),
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(width: ZynSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      time,
                      style: const TextStyle(
                        color: ZynColors.faint,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Returns `(tone, leading icon, chip label)`.
  (Color, IconData, String) _bucketStyle(
    NotificationBucket b,
    AppNotification n,
  ) {
    final ev = n.eventType.toLowerCase();
    IconData icon;
    if (ev.contains('battery')) {
      icon = Icons.battery_full_rounded;
    } else if (ev.contains('weather')) {
      icon = Icons.cloud_outlined;
    } else if (ev.contains('load')) {
      icon = Icons.bolt_rounded;
    } else if (ev.contains('solar') || ev.contains('sunset')) {
      icon = Icons.wb_sunny_rounded;
    } else if (ev.contains('inverter') || ev.contains('overheat')) {
      icon = Icons.thermostat_rounded;
    } else if (ev.contains('grid')) {
      icon = Icons.electrical_services_rounded;
    } else if (ev.contains('report')) {
      icon = Icons.insert_chart_outlined_rounded;
    } else if (ev.contains('support')) {
      icon = Icons.support_agent_rounded;
    } else if (ev.contains('account') || ev.contains('login')) {
      icon = Icons.person_outline_rounded;
    } else {
      icon = switch (b) {
        NotificationBucket.critical => Icons.priority_high_rounded,
        NotificationBucket.suggestion => Icons.auto_awesome_rounded,
        NotificationBucket.update => Icons.notifications_outlined,
      };
    }

    final chipLabel = switch (b) {
      NotificationBucket.critical => _chipForCritical(ev),
      NotificationBucket.suggestion => 'تحسين الأداء',
      NotificationBucket.update => _chipForUpdate(ev),
    };

    final tone = switch (b) {
      NotificationBucket.critical => ZynColors.danger,
      NotificationBucket.suggestion => ZynColors.accent,
      NotificationBucket.update => ZynColors.info,
    };
    return (tone, icon, chipLabel);
  }

  String _chipForCritical(String ev) {
    if (ev.contains('inverter') || ev.contains('overheat')) return 'الأجهزة';
    if (ev.contains('weather')) return 'الطقس';
    if (ev.contains('grid')) return 'الشبكة';
    return 'النظام الذكي';
  }

  String _chipForUpdate(String ev) {
    if (ev.contains('report')) return 'تقارير';
    if (ev.contains('battery')) return 'البطارية';
    if (ev.contains('solar')) return 'الإنتاج';
    if (ev.contains('weather')) return 'الطقس';
    if (ev.contains('load')) return 'الأحمال';
    return 'تحديث';
  }

  String _formatTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    return formatBackendHm(iso) ?? '';
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.tone, required this.icon});

  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: tone, size: 20),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.tone, required this.text});

  final Color tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZynRadii.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: tone,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}
