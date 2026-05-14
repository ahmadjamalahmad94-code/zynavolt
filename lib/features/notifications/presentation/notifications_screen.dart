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
import 'widgets/notif_mini_empty.dart';
import 'widgets/notif_search_bar.dart';
import 'widgets/notif_section_header.dart';
import 'widgets/loads_recommendations_strip.dart';
import 'widgets/notif_summary_strip.dart';
import 'widgets/notif_tile.dart';
import 'widgets/smart_decision_card.dart';

/// v102 DS v1 — Notifications screen.
///
/// Single scroll, three permanently-visible buckets (critical /
/// suggestion / update). When a bucket has no items it renders a
/// compact "all quiet" placeholder via [NotifMiniEmpty] so the
/// screen's three-section structure stays visible.
///
/// Auto mark-read
/// --------------
/// Once the screen has data and the user has either lingered for
/// a short debounce window OR scrolled inside the list, every
/// currently-loaded unread notification is marked read in a
/// single parallel batch via the existing
/// `NotificationsController.markRead` path. Behaviour:
///
///   * Fires at most once per State instance (i.e. once per
///     screen-visit). New unread items that arrive via push
///     afterwards stay unread until the user opens them or
///     re-enters the screen.
///   * Throttled by either a 2 s post-data debounce OR an
///     8 dp scroll-offset threshold, whichever happens first.
///   * Backend writes happen via the same per-item endpoint the
///     detail sheet uses (no new API). `Future.wait` fires them
///     in parallel and the controller's local state updates as
///     each response lands, so the unread counter and tile
///     styling decay smoothly instead of jumping at the end.
///   * Failures are swallowed silently — auto mark-read is a
///     comfort feature, not a critical operation.
///
/// Manual mark-read from the detail sheet is unchanged. The
/// `markRead` controller method is the same source of truth for
/// both paths.
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

  // ── Polling (unchanged from Phase 2) ────────────────────────────
  static const Duration _pollInterval = Duration(seconds: 60);
  Timer? _pollTimer;
  DateTime _lastTick = DateTime.now();

  // ── Auto mark-read ──────────────────────────────────────────────
  static const Duration _autoMarkDebounce = Duration(seconds: 2);
  static const double _scrollThreshold = 8;
  late final ScrollController _scrollCtrl;
  Timer? _autoMarkTimer;
  bool _autoMarkFired = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _autoMarkTimer?.cancel();
    _autoMarkTimer = null;
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
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

  // ── Auto mark-read helpers ──────────────────────────────────────

  void _onScroll() {
    if (_autoMarkFired) return;
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.offset > _scrollThreshold) {
      // The user has clearly seen the list — flush the debounce
      // and fire immediately.
      _autoMarkTimer?.cancel();
      _autoMarkTimer = null;
      _fireAutoMarkRead();
    }
  }

  void _scheduleAutoMarkRead() {
    if (_autoMarkFired) return;
    if (_autoMarkTimer != null && _autoMarkTimer!.isActive) return;
    _autoMarkTimer = Timer(_autoMarkDebounce, _fireAutoMarkRead);
  }

  Future<void> _fireAutoMarkRead() async {
    _autoMarkTimer = null;
    if (_autoMarkFired || !mounted) return;
    final feed = ref.read(notificationsControllerProvider).valueOrNull;
    if (feed == null) return;
    final unreadIds = [
      for (final n in feed.items)
        if (!n.isRead) n.id,
    ];
    if (unreadIds.isEmpty) return;
    _autoMarkFired = true;
    final ctrl = ref.read(notificationsControllerProvider.notifier);
    // Fire in parallel; per-item failures are swallowed so one bad
    // response can't tank the batch. The controller updates local
    // state per response so the unread counter decays smoothly.
    await Future.wait(
      unreadIds.map(
        (id) => ctrl
            .markRead(id)
            .catchError((Object _, StackTrace _) => false),
      ),
    );
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
    // Lifecycle — pause polling on background, fire immediate
    // refresh on resume when the last tick is stale.
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

    // Whenever fresh data lands with unread items, schedule the
    // debounce. The debounce is a one-shot per State instance —
    // see `_autoMarkFired` for why we don't refire across data
    // updates after the user has been seen-by-us.
    ref.listen<AsyncValue<NotificationsFeedState>>(
      notificationsControllerProvider,
      (prev, next) {
        if (_autoMarkFired) return;
        next.whenData((state) {
          final hasUnread = state.items.any((n) => !n.isRead);
          if (hasUnread) _scheduleAutoMarkRead();
        });
      },
    );

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
    final allEmpty = _isAllEmpty(grouped);

    return ListView(
      controller: _scrollCtrl,
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

        // All three sections, always.
        //
        // The "اقتراحات ذكية" section gets a special top slot: the
        // SmartDecisionCard pulls live system advice from
        // `/api/v1/devices/<id>/insights` — the same `smart_engine`
        // output the web dashboard renders. Notification-bucket
        // tiles classified as suggestions render below it. A
        // placeholder for the upcoming Loads Recommendations
        // sub-section also lives here; it sits dark / "قيد التطوير"
        // until backend Heavy v10.5.X ships per LOADS_BACKEND_SPEC.md.
        for (final bucket in NotificationBucket.values) ...[
          NotifSectionHeader(
            label: notificationBucketLabel(bucket),
            count: grouped[bucket]?.length ?? 0,
            tone: _toneFor(bucket),
            icon: _iconFor(bucket),
          ),
          const SizedBox(height: ZynSpacing.md),
          if (bucket == NotificationBucket.suggestion) ...[
            const SmartDecisionCard(),
            const SizedBox(height: ZynSpacing.md),
            const LoadsRecommendationsStrip(),
            // Suggestion-classified notifications (if any)
            // render BELOW the Smart Decision + Loads strip.
            // No mini-empty here — the section already carries
            // two persistent content blocks (decision + loads)
            // so claiming "لا اقتراحات جديدة" would contradict
            // what's on screen.
            if ((grouped[bucket] ?? const []).isNotEmpty) ...[
              const SizedBox(height: ZynSpacing.md),
              for (final n in grouped[bucket]!) ...[
                NotifTile(
                  notification: n,
                  bucket: bucket,
                  onTap: () => _openDetailSheet(n, bucket),
                ),
                const SizedBox(height: ZynSpacing.sm),
              ],
            ],
          ] else if ((grouped[bucket] ?? const []).isEmpty)
            NotifMiniEmpty(bucket: bucket)
          else
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

        // Big empty state only when filters are narrowing the
        // result to zero — without a filter, the three
        // mini-empties already speak for the state.
        if (filtersActive && allEmpty)
          Padding(
            padding: const EdgeInsets.only(top: ZynSpacing.xl),
            child: _FilteredEmptyState(),
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
                          color: ZynColors.primary500
                              .withValues(alpha: 0.30),
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

/// v102 DS v1 — placeholder for the upcoming Loads Recommendations
class _FilteredEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: ZynColors.primary50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.filter_alt_off_rounded,
              color: ZynColors.primary500,
              size: 24,
            ),
          ),
          const SizedBox(height: ZynSpacing.md),
          const Text(
            'لا إشعارات تطابق الفلتر',
            style: TextStyle(
              color: ZynColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'جرّب تخفيف الفلتر أو مسح البحث.',
            style: TextStyle(
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
