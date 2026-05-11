import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_models.dart';
import '../data/notifications_repository.dart';

/// In-memory feed state for the Notifications tab. Holds the accumulated
/// items across pages, the latest unread count, the pagination cursor, and
/// flags for in-flight load-more / mark-all actions.
///
/// All mutations write through to the backend and only update local state
/// from the *server's* response — never optimistically.
class NotificationsFeedState {
  const NotificationsFeedState({
    required this.items,
    required this.unreadCount,
    required this.meta,
    required this.isLoadingMore,
    required this.isMarkingAll,
  });

  const NotificationsFeedState.empty()
      : items = const [],
        unreadCount = 0,
        meta = null,
        isLoadingMore = false,
        isMarkingAll = false;

  final List<AppNotification> items;
  final int unreadCount;
  final NotificationPageMeta? meta;
  final bool isLoadingMore;
  final bool isMarkingAll;

  bool get hasMore => meta?.hasNext == true;
  int get currentPage => meta?.page ?? 0;

  NotificationsFeedState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    NotificationPageMeta? meta,
    bool? isLoadingMore,
    bool? isMarkingAll,
  }) =>
      NotificationsFeedState(
        items: items ?? this.items,
        unreadCount: unreadCount ?? this.unreadCount,
        meta: meta ?? this.meta,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isMarkingAll: isMarkingAll ?? this.isMarkingAll,
      );
}

class NotificationsController extends AsyncNotifier<NotificationsFeedState> {
  static const int _pageSize = 20;

  NotificationsRepository get _repo =>
      ref.read(notificationsRepositoryProvider);

  @override
  Future<NotificationsFeedState> build() async {
    final page = await _repo.fetchPage(page: 1, pageSize: _pageSize);
    return NotificationsFeedState(
      items: page.items,
      unreadCount: page.unreadCount,
      meta: page.meta,
      isLoadingMore: false,
      isMarkingAll: false,
    );
  }

  /// Pull-to-refresh — re-fetch page 1 and replace the accumulated list.
  Future<void> refresh() async {
    state = const AsyncLoading<NotificationsFeedState>();
    state = await AsyncValue.guard(() async {
      final page = await _repo.fetchPage(page: 1, pageSize: _pageSize);
      return NotificationsFeedState(
        items: page.items,
        unreadCount: page.unreadCount,
        meta: page.meta,
        isLoadingMore: false,
        isMarkingAll: false,
      );
    });
  }

  /// "تحميل المزيد" — appends the next page if [hasMore] is true and we
  /// are not already loading. Errors are surfaced via `state.error`.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _repo.fetchPage(
        page: current.currentPage + 1,
        pageSize: _pageSize,
      );
      state = AsyncData(current.copyWith(
        items: [...current.items, ...next.items],
        unreadCount: next.unreadCount,
        meta: next.meta,
        isLoadingMore: false,
      ));
    } catch (e, st) {
      state = AsyncError<NotificationsFeedState>(e, st);
    }
  }

  /// Marks one notification as read. Updates local state ONLY after the
  /// backend confirms via the response envelope.
  Future<bool> markRead(int notificationId) async {
    final current = state.valueOrNull;
    if (current == null) return false;
    final result = await _repo.markRead(notificationId);
    final updatedItems = current.items.map((n) {
      if (n.id != notificationId) return n;
      final fromServer = result.notification;
      if (fromServer != null) return fromServer;
      // Backend confirmed the call but returned no body — fall back to a
      // local copy that reflects the documented effect.
      return n.copyWith(isRead: true, status: 'read');
    }).toList(growable: false);
    state = AsyncData(current.copyWith(
      items: updatedItems,
      unreadCount: result.unreadCount,
    ));
    return true;
  }

  /// Marks every notification as read (server-side); on success rewrites the
  /// local list with `is_read=true` and zeroes the unread count.
  Future<int> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null || current.isMarkingAll) return 0;
    state = AsyncData(current.copyWith(isMarkingAll: true));
    try {
      final result = await _repo.markAllRead();
      final updatedItems = current.items
          .map((n) => n.isRead
              ? n
              : n.copyWith(isRead: true, status: 'read'))
          .toList(growable: false);
      state = AsyncData(current.copyWith(
        items: updatedItems,
        unreadCount: result.unreadCount,
        isMarkingAll: false,
      ));
      return result.changed;
    } catch (e, st) {
      state = AsyncError<NotificationsFeedState>(e, st);
      rethrow;
    }
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsFeedState>(
  NotificationsController.new,
);
