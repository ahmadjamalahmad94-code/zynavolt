import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/state/auto_refresh.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/notification_bucket.dart';
import '../data/notification_models.dart';
import '../state/notifications_controller.dart';
import 'widgets/notif_detail_sheet.dart';
import 'widgets/notif_filter_sheet.dart';
import 'widgets/notif_header.dart';
import 'widgets/notif_search_bar.dart';
import 'widgets/notif_section_header.dart';
import 'widgets/notif_summary_strip.dart';
import 'widgets/notif_tile.dart';

/// v102 DS v1 — Notifications screen, rebuilt from scratch.
///
/// Visual layer follows the 2026-05-14 reference image: header
/// (title + subtitle + avatar), search bar (filter + AI sparkle +
/// search), three summary stat cards (battery / critical / unread),
/// and three semantic sections (Critical / Suggestions / Updates)
/// rendered in a single scroll instead of the v96 App/Energy tabs.
///
/// What this rewrite explicitly preserves from v96:
///   * The `notificationsControllerProvider` data flow.
///   * `silentRefresh()` polling on a 60 s timer, paused on app
///     background via `appLifecycleProvider`.
///   * Mark-read via `NotificationsController.markRead(id)` — the
///     UI never mutates the local list optimistically; the server
///     response is the source of truth.
///   * Deep-link from a tapped push lands here (the route hasn't
///     moved). The push overlay's `_refreshNotificationsInbox`
///     hook continues to call `silentRefresh()` so the inbox stays
///     in sync with arriving pushes.
///   * Phase D's push toggle / banner / logout-revoke wiring is
///     untouched.
///
/// What's deliberately gone:
///   * App / Energy tabs (the new design is a single scroll).
///   * Help bottom sheet (the long explanation cards).
///   * Auto-jump scope switcher (`_userPickedScope`, `_autoSwitched`).
///   * Energy-category chip strip.
///   * Heavy filter UI inside a fixed top bar (filters live in a
///     compact button-opened sheet now).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // ── Filter state ────────────────────────────────────────────────
  bool _unreadOnly = false;
  Set<NotificationBucket> _buckets = const {};
  String _query = '';

  // ── Polling ─────────────────────────────────────────────────────
  /// v101 — same 60 s silent-poll cadence approved by the owner.
  static const Duration _pollInterval = Duration(seconds: 60);
  Timer? _pollTimer;
  DateTime _lastTick = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }

  void _startTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _doTick());
  }

  void _stopTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _doTick() {
    if (!mounted) return;
    final current = ref.read(notificationsControllerProvider).valueOrNull;
    if (current == null) return;
    if (current.isLoadingMore || current.isMarkingAll) return;
    ref.read(notificationsControllerProvider.notifier).silentRefresh();
    _lastTick = DateTime.now();
  }

  // ── Sheet openers ───────────────────────────────────────────────

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<NotifFilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ZynColors.surface,
      builder: (_) => NotifFilterSheet(
        initialUnreadOnly: _unreadOnly,
        initialBuckets: _buckets,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _unreadOnly = result.unreadOnly;
      _buckets = result.buckets;
    });
  }

  Future<void> _openDetailSheet(
    AppNotification notification,
    NotificationBucket bucket,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ZynColors.surface,
      builder: (_) => NotifDetailSheet(
        notification: notification,
        bucket: bucket,
        onMarkRead: () => _markRead(notification.id),
      ),
    );
  }

  Future<void> _markRead(int id) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(notificationsControllerProvider.notifier).markRead(id);
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Lifecycle — pause polling on background, fire immediate refresh
    // on resume when the last tick is stale.
    ref.listen<AppLifecycleState>(appLifecycleProvider, (prev, next) {
      switch (next) {
        case AppLifecycleState.resumed:
          final stale =
              DateTime.now().difference(_lastTick) >= _pollInterval;
          if (stale) _doTick();
          if (_pollTimer == null) _startTimer();
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
        case AppLifecycleState.hidden:
        case AppLifecycleState.detached:
          _stopTimer();
      }
    });

    final feed = ref.watch(notificationsControllerProvider);
    final filtersActive = _unreadOnly || _buckets.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: ZynColors.pageBackdrop),
        child: SafeArea(
          child: RefreshIndicator(
            color: ZynColors.primary500,
            onRefresh: () => ref
                .read(notificationsControllerProvider.notifier)
                .refresh(),
            child: feed.when(
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 80),
                children: const [
                  AppLoading(message: 'جارٍ تحميل الإشعارات…'),
                ],
              ),
              error: (err, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(ZynSpacing.lg),
                children: [
                  AppErrorState(
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
                ],
              ),
              data: (state) => _buildList(state, filtersActive),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(NotificationsFeedState state, bool filtersActive) {
    final grouped = _groupAndFilter(state.items);
    final criticalCount = grouped[NotificationBucket.critical]?.length ?? 0;
    final batteryStable = criticalCount == 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        ZynSpacing.lg,
        ZynSpacing.md,
        ZynSpacing.lg,
        ZynSpacing.xxxl,
      ),
      children: [
        NotifHeader(
          unreadCount: state.unreadCount,
          onAvatarTap: () => context.go(AppRoutes.more),
        ),
        const SizedBox(height: ZynSpacing.lg),
        NotifSearchBar(
          query: _query,
          onQueryChanged: (q) => setState(() => _query = q),
          onFilterTap: _openFilterSheet,
          filtersActive: filtersActive,
        ),
        const SizedBox(height: ZynSpacing.lg),
        NotifSummaryStrip(
          criticalCount: criticalCount,
          unreadCount: state.unreadCount,
          batteryStable: batteryStable,
        ),
        const SizedBox(height: ZynSpacing.xl),

        // Three buckets, in priority order.
        for (final bucket in NotificationBucket.values)
          if ((grouped[bucket] ?? const []).isNotEmpty) ...[
            NotifSectionHeader(
              label: notificationBucketLabel(bucket),
              count: grouped[bucket]!.length,
              tone: _toneFor(bucket),
              icon: _iconFor(bucket),
            ),
            const SizedBox(height: ZynSpacing.md),
            for (final n in grouped[bucket]!) ...[
              NotifTile(
                notification: n,
                bucket: bucket,
                onTap: () => _openDetailSheet(n, bucket),
              ),
              const SizedBox(height: ZynSpacing.sm),
            ],
            const SizedBox(height: ZynSpacing.lg),
          ],

        if (_isAllEmpty(grouped))
          Padding(
            padding: const EdgeInsets.only(top: ZynSpacing.xxxl),
            child: _EmptyState(filtersActive: filtersActive),
          ),

        if (state.hasMore && !filtersActive)
          Padding(
            padding: const EdgeInsets.only(top: ZynSpacing.md),
            child: Center(
              child: state.isLoadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ZynColors.primary500,
                      ),
                    )
                  : OutlinedButton(
                      onPressed: () => ref
                          .read(notificationsControllerProvider.notifier)
                          .loadMore(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ZynColors.primary700,
                        side: BorderSide(
                          color: ZynColors.primary500.withValues(alpha: 0.30),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(ZynRadii.pill),
                        ),
                      ),
                      child: const Text('تحميل المزيد'),
                    ),
            ),
          ),
      ],
    );
  }

  Map<NotificationBucket, List<AppNotification>> _groupAndFilter(
    List<AppNotification> items,
  ) {
    final q = _query.trim().toLowerCase();
    final groups = <NotificationBucket, List<AppNotification>>{};
    for (final n in items) {
      if (_unreadOnly && n.isRead) continue;
      if (q.isNotEmpty &&
          !n.title.toLowerCase().contains(q) &&
          !n.message.toLowerCase().contains(q)) {
        continue;
      }
      final bucket = classifyBucket(n);
      if (_buckets.isNotEmpty && !_buckets.contains(bucket)) continue;
      groups.putIfAbsent(bucket, () => []).add(n);
    }
    return groups;
  }

  bool _isAllEmpty(Map<NotificationBucket, List<AppNotification>> groups) {
    for (final list in groups.values) {
      if (list.isNotEmpty) return false;
    }
    return true;
  }

  Color _toneFor(NotificationBucket b) => switch (b) {
        NotificationBucket.critical => ZynColors.danger,
        NotificationBucket.suggestion => ZynColors.accent,
        NotificationBucket.update => ZynColors.info,
      };

  IconData _iconFor(NotificationBucket b) => switch (b) {
        NotificationBucket.critical => Icons.priority_high_rounded,
        NotificationBucket.suggestion => Icons.auto_awesome_rounded,
        NotificationBucket.update => Icons.update_rounded,
      };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtersActive});

  final bool filtersActive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZynColors.primary50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              color: ZynColors.primary500,
              size: 28,
            ),
          ),
          const SizedBox(height: ZynSpacing.md),
          Text(
            filtersActive
                ? 'لا إشعارات تطابق الفلتر'
                : 'لا توجد إشعارات بعد',
            style: const TextStyle(
              color: ZynColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            filtersActive
                ? 'جرّب تخفيف الفلتر أو مسح البحث.'
                : 'النظام الذكي يتابع طاقتك ويُعلِمك عند الحاجة.',
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
