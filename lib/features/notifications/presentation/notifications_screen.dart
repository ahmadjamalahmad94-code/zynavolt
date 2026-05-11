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
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationsControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(title: const Text('الإشعارات')),
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
              onRetry: () =>
                  ref.read(notificationsControllerProvider.notifier).refresh(),
            ),
            data: (state) => _FeedBody(state: state),
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
  const _FeedBody({required this.state});
  final NotificationsFeedState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasItems = state.items.isNotEmpty;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 2 + (hasItems ? state.items.length : 1) + (state.hasMore ? 1 : 0),
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
          return const _ScopeNotice(
            text: 'إعدادات الإشعارات حالياً عامة وليست لكل جهاز.',
          );
        }
        final listIndex = index - 2;
        if (!hasItems) {
          return const AppCard(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: AppEmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'لا توجد إشعارات بعد',
              subtitle:
                  'سيظهر كل إشعار جديد من النظام أو من فريق الدعم هنا.',
            ),
          );
        }
        if (listIndex < state.items.length) {
          final n = state.items[listIndex];
          return _NotificationTile(
            notification: n,
            onTap: n.isRead
                ? null
                : () => _runMarkOne(context, ref, n.id),
          );
        }
        // Trailing "load more" button.
        return _LoadMoreButton(
          isLoading: state.isLoadingMore,
          onPressed: state.isLoadingMore
              ? null
              : () =>
                  ref.read(notificationsControllerProvider.notifier).loadMore(),
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
    final time = _formatIsoUtc(notification.createdAt);
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
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          background: unread ? const Color(0xFFF5F3FF) : AppTheme.surface,
          borderColor: unread ? const Color(0xFFDDD6FE) : AppTheme.line,
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
                        fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
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

String _formatIsoUtc(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  // Display server timestamp as-is — no client-side timezone math, no
  // "X minutes ago" interpretation. A future localisation phase will
  // add a locale-safe formatter.
  final dot = iso.indexOf('.');
  return dot > 0 ? iso.substring(0, dot) : iso;
}
