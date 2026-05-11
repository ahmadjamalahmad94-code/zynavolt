import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/notification_models.dart';
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

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationsControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(notificationsControllerProvider.notifier).refresh();
                ScaffoldMessenger.of(ctx)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      content: Text('جارٍ التحديث...'),
                    ),
                  );
              },
            ),
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
              unreadOnly: _unreadOnly,
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
    required this.unreadOnly,
    required this.onFilterChanged,
  });
  final NotificationsFeedState state;
  final bool unreadOnly;
  final ValueChanged<bool> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = unreadOnly
        ? state.items.where((n) => !n.isRead).toList(growable: false)
        : state.items;
    final hasItems = visible.isNotEmpty;
    final showLoadMore = !unreadOnly && state.hasMore;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount:
          3 + (hasItems ? visible.length : 1) + (showLoadMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _HeaderCard(
            unreadCount: state.unreadCount,
            isMarkingAll: state.isMarkingAll,
            onMarkAll: state.unreadCount == 0 || state.isMarkingAll
                ? null
                : () => _runMarkAll(context, ref),
          );
        }
        if (index == 1) {
          return _FilterRow(
            unreadOnly: unreadOnly,
            unreadCount: state.unreadCount,
            onChanged: onFilterChanged,
          );
        }
        if (index == 2) {
          return const _ScopeNotice(
            text: 'إعدادات الإشعارات حالياً عامة وليست لكل جهاز.',
          );
        }
        final listIndex = index - 3;
        if (!hasItems) {
          return AppCard(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: AppEmptyState(
              icon: unreadOnly
                  ? Icons.mark_email_read_outlined
                  : Icons.notifications_none_outlined,
              title: unreadOnly
                  ? 'لا توجد إشعارات غير مقروءة'
                  : 'لا توجد إشعارات بعد',
              subtitle: unreadOnly
                  ? 'كل إشعاراتك الحالية مقروءة.'
                  : 'سيظهر كل إشعار جديد من النظام أو من فريق الدعم هنا.',
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
        // Trailing "load more" button — hidden in unread-only mode since
        // server-side pagination doesn't filter by read state.
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScopeNotice extends StatelessWidget {
  const _ScopeNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.indigoSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: AppTheme.indigoPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.softInk,
                fontSize: 12,
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
    final tag = notification.eventType.isNotEmpty
        ? notification.eventType
        : (notification.sourceType.isNotEmpty
            ? notification.sourceType
            : '');

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
