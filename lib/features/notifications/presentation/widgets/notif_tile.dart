import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../../../core/utils/backend_time.dart';
import '../../data/notification_bucket.dart';
import '../../data/notification_models.dart';

/// v102 DS v1 — unified notification tile.
///
/// Renders one [AppNotification] as a card with:
///   * a left-edge accent strip in the bucket's tone,
///   * a tone-tinted square icon on the (right in RTL) leading edge,
///   * title (single line, ellipsised),
///   * one-line summary (the message body, ellipsised to 2 lines),
///   * a small tone-coloured chip label naming the bucket / source,
///   * a faint timestamp on the (left in RTL) trailing column,
///   * an unread dot at the start of the title row when relevant.
///
/// Tap → [onTap]. The parent owns the detail-sheet open path so the
/// tile itself stays a pure presentation widget. No fixed height —
/// content can grow up to 2 lines without overflow.
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
    final (tone, toneSoft, icon, chipLabel) = _bucketStyle(bucket, notification);
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
            color: isUnread ? toneSoft : ZynColors.surface,
            borderRadius: BorderRadius.circular(ZynRadii.card),
            border: Border.all(
              color: isUnread
                  ? tone.withValues(alpha: 0.30)
                  : ZynColors.line,
              width: 1,
            ),
            boxShadow: ZynShadows.soft(tint: tone),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Accent strip — tone-coloured edge.
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: const BorderRadiusDirectional.only(
                      topStart: Radius.circular(ZynRadii.card),
                      bottomStart: Radius.circular(ZynRadii.card),
                    ),
                  ),
                ),
                // Body.
                Expanded(
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
                            children: [
                              Row(
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
                                        fontSize: 14,
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
                                const SizedBox(height: 4),
                                Text(
                                  notification.message,
                                  style: const TextStyle(
                                    color: ZynColors.inkSoft,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w400,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (chipLabel.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _ChipLabel(tone: tone, text: chipLabel),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: ZynSpacing.sm),
                        // Timestamp column.
                        if (time.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              time,
                              style: const TextStyle(
                                color: ZynColors.faint,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                fontFeatures: [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Returns `(strong tone, soft tone, leading icon, chip label)`.
  (Color, Color, IconData, String) _bucketStyle(
    NotificationBucket b,
    AppNotification n,
  ) {
    final ev = n.eventType.toLowerCase();
    // Smarter icon per event type when possible.
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
      // Bucket-default icon.
      icon = switch (b) {
        NotificationBucket.critical => Icons.priority_high_rounded,
        NotificationBucket.suggestion => Icons.auto_awesome_rounded,
        NotificationBucket.update => Icons.notifications_outlined,
      };
    }

    // Chip label — short categorical tag.
    final chipLabel = switch (b) {
      NotificationBucket.critical => _chipForCritical(ev),
      NotificationBucket.suggestion => 'تحسين الأداء',
      NotificationBucket.update => _chipForUpdate(ev),
    };

    final (tone, toneSoft) = switch (b) {
      NotificationBucket.critical => (ZynColors.danger, ZynColors.dangerSoft),
      NotificationBucket.suggestion => (ZynColors.accent, ZynColors.accentSoft),
      NotificationBucket.update => (ZynColors.info, ZynColors.infoSoft),
    };
    return (tone, toneSoft, icon, chipLabel);
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
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ZynRadii.tile),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
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
