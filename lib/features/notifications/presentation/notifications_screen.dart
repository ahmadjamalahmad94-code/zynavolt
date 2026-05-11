import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../data/notification_labels.dart';
import '../data/notification_models.dart';
import '../data/notification_scope.dart';
import '../state/notifications_controller.dart';

/// Real read-only feed backed by `GET /api/mobile/notifications`.
/// Mark-read writes go through the backend; UI never marks locally
/// without a server-confirmed response.
///
/// v54 polish:
///   * AppBar refresh button with snackbar feedback.
///   * Local "الكل / غير المقروء" filter pills (client-side only).
///   * Calmer humanized timestamps (today → `HH:mm`, yesterday →
///     `أمس HH:mm`, older → `YYYY-MM-DD HH:mm`).
///   * Stronger unread visual: a left accent bar in addition to the dot.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

  /// v91: which top-level tab is selected. Defaults to App so the feed
  /// opens on the section that's most likely to need attention day-to-day.
  NotificationScope _scope = NotificationScope.app;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationsControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          // v87: settings shortcut — opens the notification-settings editor.
          IconButton(
            tooltip: 'إعدادات الإشعارات',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(AppRoutes.notificationSettings),
          ),
          AppRefreshButton(
            onPressed: () =>
                ref.read(notificationsControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(notificationsControllerProvider.notifier).refresh(),
          child: feed.when(
            loading: () => const _LoadingScroll(),
            error: (err, _) => _ErrorScroll(
              error: err is ApiException
                  ? err
                  : ApiException(
                      message: 'تعذّر تحميل الإشعارات.',
                      kind: ApiErrorKind.unknown,
                    ),
              onRetry: () => ref
                  .read(notificationsControllerProvider.notifier)
                  .refresh(),
            ),
            data: (state) => _FeedBody(
              state: state,
              scope: _scope,
              unreadOnly: _unreadOnly,
              onScopeChanged: (s) => setState(() => _scope = s),
              onFilterChanged: (v) => setState(() => _unreadOnly = v),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingScroll extends StatelessWidget {
  const _LoadingScroll();
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      children: const [
        AppLoading(message: 'جارٍ تحميل الإشعارات...'),
      ],
    );
  }
}

class _ErrorScroll extends StatelessWidget {
  const _ErrorScroll({required this.error, required this.onRetry});
  final ApiException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        AppErrorState(error: error, onRetry: onRetry),
      ],
    );
  }
}

class _FeedBody extends ConsumerWidget {
  const _FeedBody({
    required this.state,
    required this.scope,
    required this.unreadOnly,
    required this.onScopeChanged,
    required this.onFilterChanged,
  });
  final NotificationsFeedState state;
  final NotificationScope scope;
  final bool unreadOnly;
  final ValueChanged<NotificationScope> onScopeChanged;
  final ValueChanged<bool> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // v91: partition the flat backend feed into the two scopes first, so
    // tabs / counters / list all stay consistent with a single source of
    // classification.
    final appItems = <AppNotification>[];
    final energyItems = <AppNotification>[];
    for (final n in state.items) {
      if (classifyNotification(n) == NotificationScope.energy) {
        energyItems.add(n);
      } else {
        appItems.add(n);
      }
    }

    final scopedItems =
        scope == NotificationScope.energy ? energyItems : appItems;
    final unreadInScope = scopedItems.where((n) => !n.isRead).length;
    final visible = unreadOnly
        ? scopedItems.where((n) => !n.isRead).toList(growable: false)
        : scopedItems;
    final hasItems = visible.isNotEmpty;
    // v91: hide the global "load more" while in unread-only filter (same
    // as before) AND while in the energy tab — since the loaded page
    // mixes both scopes, "load more" only makes sense as a global fetch.
    final showLoadMore = !unreadOnly && state.hasMore;

    final headerIndexes = 4; // tabs + header + intro + filter

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount:
          headerIndexes + (hasItems ? visible.length : 1) + (showLoadMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _ScopeTabs(
            scope: scope,
            appUnread: appItems.where((n) => !n.isRead).length,
            energyUnread: energyItems.where((n) => !n.isRead).length,
            onChanged: onScopeChanged,
          );
        }
        if (index == 1) {
          return _HeaderCard(
            unreadCount: unreadInScope,
            isMarkingAll: state.isMarkingAll,
            onMarkAll: state.unreadCount == 0 || state.isMarkingAll
                ? null
                : () => _runMarkAll(context, ref),
          );
        }
        if (index == 2) {
          return _ScopeIntro(scope: scope);
        }
        if (index == 3) {
          return _FilterRow(
            unreadOnly: unreadOnly,
            unreadCount: unreadInScope,
            onChanged: onFilterChanged,
          );
        }
        final listIndex = index - headerIndexes;
        if (!hasItems) {
          return AppCard(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: AppEmptyState(
              icon: unreadOnly
                  ? Icons.mark_email_read_outlined
                  : (scope == NotificationScope.energy
                      ? Icons.bolt_outlined
                      : Icons.notifications_none_outlined),
              title: _emptyTitle(scope: scope, unreadOnly: unreadOnly),
              subtitle:
                  _emptySubtitle(scope: scope, unreadOnly: unreadOnly),
            ),
          );
        }
        if (listIndex < visible.length) {
          final n = visible[listIndex];
          return _NotificationTile(
            notification: n,
            onTap: n.isRead
                ? null
                : () => _runMarkOne(context, ref, n.id),
          );
        }
        return _LoadMoreButton(
          isLoading: state.isLoadingMore,
          onPressed: state.isLoadingMore
              ? null
              : () => ref
                  .read(notificationsControllerProvider.notifier)
                  .loadMore(),
        );
      },
    );
  }

  String _emptyTitle({required NotificationScope scope, required bool unreadOnly}) {
    if (unreadOnly) return 'لا توجد إشعارات غير مقروءة';
    if (scope == NotificationScope.energy) {
      return 'لا توجد تنبيهات طاقة أو أحمال حالياً.';
    }
    return 'لا توجد إشعارات بعد';
  }

  String _emptySubtitle({required NotificationScope scope, required bool unreadOnly}) {
    if (unreadOnly) return 'كل إشعاراتك الحالية مقروءة.';
    if (scope == NotificationScope.energy) {
      return 'عند توفر تنبيهات البطارية أو الأحمال ستظهر هنا.';
    }
    return 'سيظهر كل إشعار جديد من النظام أو من فريق الدعم هنا.';
  }

  Future<void> _runMarkOne(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(notificationsControllerProvider.notifier)
          .markRead(id);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('تعذّر التحديث: $e')));
    }
  }

  Future<void> _runMarkAll(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final changed = await ref
          .read(notificationsControllerProvider.notifier)
          .markAllRead();
      messenger.showSnackBar(SnackBar(
        content: Text(
          changed > 0
              ? 'تم تعليم $changed إشعاراً كمقروء.'
              : 'لا توجد إشعارات غير مقروءة.',
        ),
      ));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('تعذّر التحديث: $e')));
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.unreadCount,
    required this.isMarkingAll,
    required this.onMarkAll,
  });

  final int unreadCount;
  final bool isMarkingAll;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasUnread ? AppTheme.indigoSoft : AppTheme.softBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasUnread
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none_outlined,
              size: 20,
              color: hasUnread ? AppTheme.indigoPrimary : AppTheme.faintMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasUnread
                      ? '$unreadCount إشعاراً غير مقروء'
                      : 'كل الإشعارات مقروءة',
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'يتم تحديث القائمة من خادم Zynavolt مباشرة.',
                  style: TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (hasUnread)
            TextButton.icon(
              onPressed: onMarkAll,
              icon: isMarkingAll
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all, size: 16),
              label: const Text('اقرأ الكل'),
            ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.unreadOnly,
    required this.unreadCount,
    required this.onChanged,
  });

  final bool unreadOnly;
  final int unreadCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Pill(
          label: 'الكل',
          selected: !unreadOnly,
          onTap: () => onChanged(false),
        ),
        const SizedBox(width: 8),
        _Pill(
          label: unreadCount > 0
              ? 'غير المقروء ($unreadCount)'
              : 'غير المقروء',
          selected: unreadOnly,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppTheme.indigoPrimary : AppTheme.surface;
    final fg = selected ? Colors.white : AppTheme.indigoPrimary;
    final border = selected
        ? AppTheme.indigoPrimary
        : AppTheme.indigoBright.withValues(alpha: 0.30);
    // v72: AnimatedContainer + AnimatedDefaultTextStyle so toggling the
    // "الكل / غير المقروء" filter glides instead of snapping.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// v91: segmented control for the two notification scopes. The unread
/// dot only renders when there's at least one unread in that bucket.
class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({
    required this.scope,
    required this.appUnread,
    required this.energyUnread,
    required this.onChanged,
  });

  final NotificationScope scope;
  final int appUnread;
  final int energyUnread;
  final ValueChanged<NotificationScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ScopeTab(
              icon: Icons.notifications_outlined,
              label: notificationScopeTitle(NotificationScope.app),
              selected: scope == NotificationScope.app,
              unreadCount: appUnread,
              onTap: () => onChanged(NotificationScope.app),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ScopeTab(
              icon: Icons.bolt_outlined,
              label: notificationScopeTitle(NotificationScope.energy),
              selected: scope == NotificationScope.energy,
              unreadCount: energyUnread,
              onTap: () => onChanged(NotificationScope.energy),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.unreadCount,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppTheme.indigoPrimary : Colors.transparent;
    final fg = selected ? Colors.white : AppTheme.muted;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white
                        : AppTheme.indigoSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: TextStyle(
                      color: selected
                          ? AppTheme.indigoPrimary
                          : AppTheme.indigoPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// v91: one-liner scope intro under the header card. Uses the
/// scope-specific copy from [notificationScopeIntro].
class _ScopeIntro extends StatelessWidget {
  const _ScopeIntro({required this.scope});
  final NotificationScope scope;

  @override
  Widget build(BuildContext context) {
    final isEnergy = scope == NotificationScope.energy;
    final accent =
        isEnergy ? AppTheme.emerald : AppTheme.indigoPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isEnergy ? Icons.bolt_outlined : Icons.info_outline,
            color: accent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              notificationScopeIntro(scope),
              style: TextStyle(
                color: accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final title = notification.title.isNotEmpty ? notification.title : '—';
    final message = notification.message;
    final time = _humanizeTimestamp(notification.createdAt);
    // v65: translate the raw event_type / source_type slug into a
    // user-facing Arabic chip label. Unknown slugs fall back to the raw
    // value so the chip never goes blank.
    final tag = NotificationLabels.chipLabel(
      eventType: notification.eventType,
      sourceType: notification.sourceType,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // v54: left accent bar — strong visual cue for unread state.
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: unread ? AppTheme.violet : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(AppTheme.radiusCard),
                  ),
                ),
              ),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  background:
                      unread ? const Color(0xFFF5F3FF) : AppTheme.surface,
                  borderColor:
                      unread ? const Color(0xFFDDD6FE) : AppTheme.line,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (unread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 6, left: 6),
                              decoration: const BoxDecoration(
                                color: AppTheme.violet,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontSize: 13.5,
                                fontWeight:
                                    unread ? FontWeight.w900 : FontWeight.w700,
                                height: 1.45,
                              ),
                            ),
                          ),
                          if (tag.isNotEmpty) _Chip(text: tag),
                        ],
                      ),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          message,
                          style: const TextStyle(
                            color: AppTheme.softInk,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.55,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.schedule,
                              size: 12, color: AppTheme.faintMuted),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: const TextStyle(
                              color: AppTheme.faintMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (!unread)
                            const Text(
                              'مقروء',
                              style: TextStyle(
                                color: AppTheme.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.indigoSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.indigoPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.isLoading, required this.onPressed});
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: AppTheme.formControlHeight,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more, size: 18),
          label: const Text('تحميل المزيد'),
        ),
      ),
    );
  }
}

/// Calm Arabic-friendly humanizer for server ISO timestamps.
///
///   * Today               → `HH:mm`
///   * Yesterday           → `أمس HH:mm`
///   * Older (same year)   → `MM-DD HH:mm`
///   * Older (other year)  → `YYYY-MM-DD HH:mm`
///
/// No "X minutes ago" interpretation — server time is rendered honestly
/// in the device's local timezone via [DateTime.toLocal].
String _humanizeTimestamp(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    // Backend value didn't parse — fall back to a truncated copy so the
    // user still sees something rather than a question mark.
    final dot = iso.indexOf('.');
    return dot > 0 ? iso.substring(0, dot) : iso;
  }
  final local = parsed.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dayOf = DateTime(local.year, local.month, local.day);
  final daysAgo = today.difference(dayOf).inDays;
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  if (daysAgo == 0) return '$hh:$mm';
  if (daysAgo == 1) return 'أمس $hh:$mm';
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  if (local.year == now.year) return '$mo-$d  $hh:$mm';
  return '${local.year}-$mo-$d  $hh:$mm';
}
