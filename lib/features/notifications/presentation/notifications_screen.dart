import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/state/app_session.dart';
import '../../../core/utils/backend_time.dart';
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
///
/// v96 redesign — "scan first, details on demand":
///   * AppBar carries title + filter + help + refresh + settings actions
///     (no big explanation cards live in the main flow anymore).
///   * Slim sticky-feeling header: scope tabs + 1-line unread summary
///     row + (only on Energy) one horizontal category chip strip.
///   * Compact list tiles: badge + 1-line title + 1-line summary + short
///     time + tiny unread dot. Tap → full-detail BottomSheet.
///   * Read/unread filter and category filter live in a BottomSheet
///     opened from the AppBar — no permanent filter bars on screen.
///
/// All long copy (the v92 hero card, the "push notifications coming
/// later" note, and the scope intro paragraph) moved into the
/// help BottomSheet so the main scroll stays light.
///
/// Mark-read writes still go through the backend; the UI never marks
/// locally without a server-confirmed response. The 10-second silent
/// poller from v96 is preserved so the feed stays live without flicker.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

  /// Which top-level tab is selected. Defaults to App so the feed opens
  /// on the section that's most likely to need attention day-to-day.
  NotificationScope _scope = NotificationScope.app;

  /// Local category filter inside the Energy tab.
  EnergyCategory _energyCategory = EnergyCategory.all;

  /// Once `true`, the smart auto-jump is disabled — we never override a
  /// deliberate tab choice.
  bool _userPickedScope = false;

  /// Belt-and-suspenders alongside [_userPickedScope]. Set to `true`
  /// after the first auto-jump fires.
  bool _autoSwitched = false;

  /// 10-second auto-refresh polling cadence (v96).
  static const Duration _pollInterval = Duration(seconds: 10);

  /// Single Timer guarded by [_pollTimer == null] so screen rebuilds
  /// can never accidentally start a second poller.
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_pollInterval, _tick);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }

  void _tick(Timer _) {
    if (!mounted) return;
    final current = ref.read(notificationsControllerProvider).valueOrNull;
    if (current == null) return;
    if (current.isLoadingMore || current.isMarkingAll) return;
    ref.read(notificationsControllerProvider.notifier).silentRefresh();
  }

  void _onScopePicked(NotificationScope s) {
    setState(() {
      _scope = s;
      _userPickedScope = true;
    });
  }

  /// If the current scope is empty but the other has items, jump to the
  /// populated tab — but only on the first load of this session.
  void _maybeAutoSwitchScope(NotificationsFeedState state) {
    if (_userPickedScope || _autoSwitched) return;
    var appCount = 0;
    var energyCount = 0;
    for (final n in state.items) {
      if (classifyNotification(n) == NotificationScope.energy) {
        energyCount++;
      } else {
        appCount++;
      }
    }
    NotificationScope? target;
    if (_scope == NotificationScope.app && appCount == 0 && energyCount > 0) {
      target = NotificationScope.energy;
    } else if (_scope == NotificationScope.energy &&
        energyCount == 0 &&
        appCount > 0) {
      target = NotificationScope.app;
    }
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _scope = target!;
        _autoSwitched = true;
      });
    });
  }

  // ── Sheet openers ──────────────────────────────────────────────────

  Future<void> _openHelpSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => const _HelpSheet(),
    );
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => _FilterSheet(
        scope: _scope,
        unreadOnly: _unreadOnly,
        energyCategory: _energyCategory,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _unreadOnly = result.unreadOnly;
      _energyCategory = result.energyCategory;
    });
  }

  Future<void> _openDetailSheet(AppNotification n) async {
    // v96: resolve the profile timezone so the detail sheet can show
    // it honestly. The notification times themselves are converted via
    // the device local TZ (see `_humanizeTimestamp` docs for why), but
    // surfacing the profile string lets the user verify what the
    // system thinks their zone is.
    final userTimezone =
        ref.read(appSessionProvider).user?.timezone ?? '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => _DetailSheet(
        notification: n,
        userTimezone: userTimezone,
        onMarkRead: () => _runMarkOne(n.id),
      ),
    );
  }

  // ── Mark-read actions ──────────────────────────────────────────────

  Future<void> _runMarkOne(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(notificationsControllerProvider.notifier)
          .markRead(id);
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('تعذّر التحديث: $e')));
    }
  }

  Future<void> _runMarkAll() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final changed = await ref
          .read(notificationsControllerProvider.notifier)
          .markAllRead();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
          changed > 0
              ? 'تم تعليم $changed إشعاراً كمقروء.'
              : 'لا توجد إشعارات غير مقروءة.',
        ),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('تعذّر التحديث: $e')));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationsControllerProvider);
    final filtersActive =
        _unreadOnly || (_scope == NotificationScope.energy &&
            _energyCategory != EnergyCategory.all);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            tooltip: 'تصفية',
            icon: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_list),
                if (filtersActive)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.violet,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _openFilterSheet,
          ),
          IconButton(
            tooltip: 'شرح',
            icon: const Icon(Icons.help_outline),
            onPressed: _openHelpSheet,
          ),
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
            data: (state) {
              _maybeAutoSwitchScope(state);
              return _FeedBody(
                state: state,
                scope: _scope,
                unreadOnly: _unreadOnly,
                energyCategory: _energyCategory,
                onScopeChanged: _onScopePicked,
                onEnergyCategoryChanged: (c) =>
                    setState(() => _energyCategory = c),
                onMarkAll: _runMarkAll,
                onTileTap: _openDetailSheet,
                onClearFilters: () => setState(() {
                  _unreadOnly = false;
                  _energyCategory = EnergyCategory.all;
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Loading / error scroll wrappers ────────────────────────────────────

class _LoadingScroll extends StatelessWidget {
  const _LoadingScroll();
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      children: const [AppLoading(message: 'جارٍ تحميل الإشعارات...')],
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
      children: [AppErrorState(error: error, onRetry: onRetry)],
    );
  }
}

// ── Feed body ──────────────────────────────────────────────────────────

class _FeedBody extends ConsumerWidget {
  const _FeedBody({
    required this.state,
    required this.scope,
    required this.unreadOnly,
    required this.energyCategory,
    required this.onScopeChanged,
    required this.onEnergyCategoryChanged,
    required this.onMarkAll,
    required this.onTileTap,
    required this.onClearFilters,
  });
  final NotificationsFeedState state;
  final NotificationScope scope;
  final bool unreadOnly;
  final EnergyCategory energyCategory;
  final ValueChanged<NotificationScope> onScopeChanged;
  final ValueChanged<EnergyCategory> onEnergyCategoryChanged;
  final VoidCallback onMarkAll;
  final void Function(AppNotification) onTileTap;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Partition the flat backend feed into the two scopes first.
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

    final List<AppNotification> categoryFiltered;
    if (scope == NotificationScope.energy &&
        energyCategory != EnergyCategory.all) {
      categoryFiltered = scopedItems
          .where((n) => classifyEnergyCategory(n) == energyCategory)
          .toList(growable: false);
    } else {
      categoryFiltered = scopedItems;
    }

    final unreadInScope =
        categoryFiltered.where((n) => !n.isRead).length;
    final visible = unreadOnly
        ? categoryFiltered.where((n) => !n.isRead).toList(growable: false)
        : categoryFiltered;
    final hasItems = visible.isNotEmpty;
    final showLoadMore = hasItems && !unreadOnly && state.hasMore;
    final otherScope = scope == NotificationScope.app
        ? NotificationScope.energy
        : NotificationScope.app;
    final otherScopeItems =
        otherScope == NotificationScope.energy ? energyItems : appItems;

    final bool filtersActive = unreadOnly ||
        (scope == NotificationScope.energy &&
            energyCategory != EnergyCategory.all);

    final leading = <Widget>[
      _ScopeTabs(
        scope: scope,
        appUnread: appItems.where((n) => !n.isRead).length,
        energyUnread: energyItems.where((n) => !n.isRead).length,
        onChanged: onScopeChanged,
      ),
      const SizedBox(height: 10),
      _CompactSummaryBar(
        unreadCount: unreadInScope,
        isMarkingAll: state.isMarkingAll,
        onMarkAll: state.unreadCount == 0 || state.isMarkingAll
            ? null
            : onMarkAll,
      ),
      if (scope == NotificationScope.energy) ...[
        const SizedBox(height: 8),
        _CompactCategoryStrip(
          selected: energyCategory,
          onChanged: onEnergyCategoryChanged,
        ),
      ],
      if (filtersActive) ...[
        const SizedBox(height: 6),
        _ActiveFiltersChip(
          unreadOnly: unreadOnly,
          energyCategory:
              scope == NotificationScope.energy ? energyCategory : null,
          onClear: onClearFilters,
        ),
      ],
      const SizedBox(height: 10),
    ];

    final headerCount = leading.length;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: headerCount +
          (hasItems ? visible.length : 1) +
          (showLoadMore ? 1 : 0),
      separatorBuilder: (_, index) {
        // No spacer between leading widgets (they include their own
        // SizedBox padding); only between list rows.
        if (index < headerCount - 1) return const SizedBox.shrink();
        return const SizedBox(height: 8);
      },
      itemBuilder: (context, index) {
        if (index < headerCount) return leading[index];
        if (!hasItems) {
          return _EmptyStateCard(
            scope: scope,
            unreadOnly: unreadOnly,
            energyCategory: scope == NotificationScope.energy
                ? energyCategory
                : null,
            otherScopeUnread:
                otherScopeItems.where((n) => !n.isRead).length,
            otherScopeTotal: otherScopeItems.length,
            onJumpToOther: otherScopeItems.isNotEmpty
                ? () => onScopeChanged(otherScope)
                : null,
          );
        }
        final listIndex = index - headerCount;
        if (listIndex < visible.length) {
          final n = visible[listIndex];
          return _CompactTile(
            notification: n,
            energyAccent: scope == NotificationScope.energy,
            onTap: () => onTileTap(n),
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
}

// ── Compact summary bar ────────────────────────────────────────────────

/// Single-row replacement for the old big `_HeaderCard`. Renders the
/// unread count (or a green "all read" tick) and a tiny inline
/// "اقرأ الكل" link when there's work to do.
class _CompactSummaryBar extends StatelessWidget {
  const _CompactSummaryBar({
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Icon(
            hasUnread
                ? Icons.notifications_active_outlined
                : Icons.check_circle_outline,
            size: 16,
            color: hasUnread ? AppTheme.indigoPrimary : AppTheme.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasUnread
                  ? '$unreadCount غير مقروء'
                  : 'كل الإشعارات مقروءة',
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (hasUnread)
            InkWell(
              onTap: onMarkAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMarkingAll)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.done_all,
                          size: 14, color: AppTheme.indigoPrimary),
                    const SizedBox(width: 4),
                    const Text(
                      'اقرأ الكل',
                      style: TextStyle(
                        color: AppTheme.indigoPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Compact horizontal category strip (Energy tab only) ────────────────

class _CompactCategoryStrip extends StatelessWidget {
  const _CompactCategoryStrip({
    required this.selected,
    required this.onChanged,
  });

  final EnergyCategory selected;
  final ValueChanged<EnergyCategory> onChanged;

  static const _categories = [
    EnergyCategory.all,
    EnergyCategory.battery,
    EnergyCategory.load,
    EnergyCategory.sunWeather,
    EnergyCategory.reports,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final c = _categories[i];
          return _MicroPill(
            label: energyCategoryLabel(c),
            selected: c == selected,
            onTap: () => onChanged(c),
          );
        },
      ),
    );
  }
}

/// Smaller, slimmer pill — used in the compact category strip and the
/// filter sheet. Visually lighter than the v94 `_Pill`.
class _MicroPill extends StatelessWidget {
  const _MicroPill({
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny "filters active — clear" hint that surfaces when read-state or
/// category filters are narrowing the visible list. Tapping it resets
/// every filter at once so the user is never stuck with an empty view
/// because they forgot a chip is still on.
class _ActiveFiltersChip extends StatelessWidget {
  const _ActiveFiltersChip({
    required this.unreadOnly,
    required this.energyCategory,
    required this.onClear,
  });

  final bool unreadOnly;
  final EnergyCategory? energyCategory;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (unreadOnly) 'غير مقروء',
      if (energyCategory != null && energyCategory != EnergyCategory.all)
        energyCategoryLabel(energyCategory!),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onClear,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.violet.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.violet.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_alt_outlined,
                  size: 14, color: AppTheme.violet),
              const SizedBox(width: 6),
              Text(
                'تصفية: ${parts.join(' • ')}',
                style: const TextStyle(
                  color: AppTheme.violet,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.close, size: 13, color: AppTheme.violet),
              const SizedBox(width: 2),
              const Text(
                'مسح',
                style: TextStyle(
                  color: AppTheme.violet,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compact notification tile ──────────────────────────────────────────

/// Much shorter notification card — the v96 redesign's centrepiece.
/// One-line title + one-line summary + short time + tiny unread dot.
/// Tap opens [_DetailSheet] for the full body.
class _CompactTile extends StatelessWidget {
  const _CompactTile({
    required this.notification,
    required this.onTap,
    this.energyAccent = false,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final bool energyAccent;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final unread = !n.isRead;
    final title = n.title.isNotEmpty ? n.title : '—';
    final time = _humanizeTimestamp(n.createdAt);

    final Color accentColor;
    if (unread) {
      accentColor = AppTheme.violet;
    } else if (energyAccent) {
      accentColor = AppTheme.emerald;
    } else {
      accentColor = Colors.transparent;
    }

    final Color iconBg;
    final Color iconColor;
    final IconData icon;
    if (energyAccent) {
      icon = _energyIconFor(n);
      iconBg = AppTheme.emerald.withValues(alpha: 0.12);
      iconColor = AppTheme.emerald;
    } else {
      icon = _appIconFor(n);
      iconBg = AppTheme.indigoSoft;
      iconColor = AppTheme.indigoPrimary;
    }

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
              // Compact left accent stripe — only paints when meaningful.
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(AppTheme.radiusCard),
                  ),
                ),
              ),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  background:
                      unread ? const Color(0xFFFAF8FF) : AppTheme.surface,
                  borderColor:
                      unread ? const Color(0xFFE9E2FF) : AppTheme.line,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(icon, size: 16, color: iconColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontSize: 13,
                                fontWeight: unread
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            if (n.message.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _summary(n.message),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.softInk,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: const TextStyle(
                              color: AppTheme.faintMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (unread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.violet,
                                shape: BoxShape.circle,
                              ),
                            )
                          else
                            const SizedBox(width: 8, height: 8),
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

/// Collapse multi-line backend bodies into a single line for the list.
String _summary(String message) {
  final flat = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat;
}

/// Pick a coarse icon for an Energy-tab tile based on the energy
/// sub-category. Used only for the compact icon badge in the list — the
/// full event_type / source_type is shown in the detail sheet.
IconData _energyIconFor(AppNotification n) {
  switch (classifyEnergyCategory(n)) {
    case EnergyCategory.battery:
      return Icons.battery_charging_full_outlined;
    case EnergyCategory.load:
      return Icons.bolt_outlined;
    case EnergyCategory.sunWeather:
      return Icons.wb_sunny_outlined;
    case EnergyCategory.reports:
      return Icons.summarize_outlined;
    case EnergyCategory.other:
    case EnergyCategory.all:
      return Icons.bolt_outlined;
  }
}

IconData _appIconFor(AppNotification n) {
  final src = n.sourceType.toLowerCase();
  final ev = n.eventType.toLowerCase();
  if (src.contains('support') ||
      ev.contains('support') ||
      ev.contains('ticket') ||
      ev.contains('case')) {
    return Icons.support_agent_outlined;
  }
  if (src.contains('account') ||
      ev.contains('account') ||
      ev.contains('subscription') ||
      ev.contains('plan')) {
    return Icons.person_outline;
  }
  if (src.contains('device') || ev.contains('device')) {
    return Icons.solar_power_outlined;
  }
  return Icons.notifications_none_outlined;
}

// ── Scope tabs (segmented control) ─────────────────────────────────────

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
        borderRadius: BorderRadius.circular(12),
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
              // Deliberately shorter than the canonical title from
              // [notificationScopeTitle] — the full "متابعة الطاقة
              // والأحمال" gets clipped to "...ولا" once the unread
              // count badge appears next to it inside the segmented
              // control. The shorter "الطاقة والأحمال" preserves
              // meaning and leaves room for a two-digit badge.
              label: 'الطاقة والأحمال',
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
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : AppTheme.indigoSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: AppTheme.indigoPrimary,
                      fontSize: 10,
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

// ── Empty state ────────────────────────────────────────────────────────

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.scope,
    required this.unreadOnly,
    required this.energyCategory,
    required this.otherScopeUnread,
    required this.otherScopeTotal,
    required this.onJumpToOther,
  });

  final NotificationScope scope;
  final bool unreadOnly;

  /// The active Energy-tab category — used to tailor the empty-state
  /// copy when a specific filter is on. `null` (or `all`) renders the
  /// generic Energy empty state.
  final EnergyCategory? energyCategory;
  final int otherScopeUnread;
  final int otherScopeTotal;
  final VoidCallback? onJumpToOther;

  String get _title {
    if (scope == NotificationScope.energy) {
      switch (energyCategory) {
        case EnergyCategory.battery:
          return 'لا توجد تنبيهات للبطارية حالياً.';
        case EnergyCategory.load:
          return 'لا توجد تنبيهات للأحمال حالياً.';
        case EnergyCategory.sunWeather:
          return 'لا توجد تنبيهات للشمس والطقس حالياً.';
        case EnergyCategory.reports:
          return 'لا توجد تقارير طاقة حالياً.';
        case EnergyCategory.other:
        case EnergyCategory.all:
        case null:
          return 'لا توجد تنبيهات طاقة حالياً.';
      }
    }
    return 'لا توجد إشعارات تطبيق حالياً.';
  }

  String get _subtitle {
    if (scope == NotificationScope.energy) {
      switch (energyCategory) {
        case EnergyCategory.battery:
        case EnergyCategory.load:
        case EnergyCategory.sunWeather:
        case EnergyCategory.other:
          return 'جرّب كل الفئات أو انتظر وصول تنبيه جديد.';
        case EnergyCategory.reports:
          return 'جرّب كل الفئات أو انتظر وصول تقرير جديد.';
        case EnergyCategory.all:
        case null:
          return 'ستظهر هنا تنبيهات البطارية، الأحمال، الشمس والطقس '
              'عند توفرها.';
      }
    }
    // v44 audit polish: explicitly redirect the user to the Energy tab
    // for sun / weather / loads / battery notifications. Real-user
    // testing showed people expected those alerts to appear in the App
    // tab and didn't realise they live in the Energy tab. The single
    // updated subtitle stays Arabic-only and avoids implying that
    // anything has disappeared.
    return 'ستظهر هنا رسائل الدعم والحساب والمزامنة. '
        'تنبيهات الشمس والطقس والأحمال والبطارية تظهر '
        'في تبويب «الطاقة والأحمال».';
  }

  /// Additional honest line appended only when the read-state filter
  /// is hiding rows from the user. Returns `null` when no extra
  /// explanation is needed.
  String? get _unreadHint =>
      unreadOnly ? 'الفلتر الحالي يعرض غير المقروء فقط.' : null;

  @override
  Widget build(BuildContext context) {
    final otherTitle = scope == NotificationScope.app
        ? notificationScopeTitle(NotificationScope.energy)
        : notificationScopeTitle(NotificationScope.app);
    final hasOther = onJumpToOther != null && otherScopeTotal > 0;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppEmptyState(
            icon: unreadOnly
                ? Icons.mark_email_read_outlined
                : (scope == NotificationScope.energy
                    ? Icons.bolt_outlined
                    : Icons.notifications_none_outlined),
            title: _title,
            subtitle: _subtitle,
          ),
          if (_unreadHint != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.violet.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.violet.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined,
                      size: 14, color: AppTheme.violet),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _unreadHint!,
                      style: const TextStyle(
                        color: AppTheme.violet,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasOther) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.indigoSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(
                  color: AppTheme.indigoBright.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    otherScopeUnread > 0
                        ? 'يوجد $otherScopeUnread إشعار في $otherTitle.'
                        : 'يوجد $otherScopeTotal إشعار في $otherTitle.',
                    style: const TextStyle(
                      color: AppTheme.indigoPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: AppTheme.formControlHeight,
                    child: FilledButton.icon(
                      onPressed: onJumpToOther,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text('عرض $otherTitle'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Load more button ───────────────────────────────────────────────────

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

// ── Bottom sheets ──────────────────────────────────────────────────────

/// "Scan first, details on demand" — tap a [_CompactTile] and the full
/// title + message body + technical fields render here. Mark-as-read is
/// surfaced as the primary action when the row is unread.
class _DetailSheet extends StatelessWidget {
  const _DetailSheet({
    required this.notification,
    required this.userTimezone,
    required this.onMarkRead,
  });

  final AppNotification notification;

  /// Profile timezone string (e.g. `Asia/Hebron`). Empty when the user
  /// has no profile TZ configured. Shown in the KV block for honesty —
  /// the actual time conversion path still goes through device local
  /// (see `_humanizeTimestamp` docs).
  final String userTimezone;
  final Future<void> Function() onMarkRead;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final unread = !n.isRead;
    final tag = NotificationLabels.chipLabel(
      eventType: n.eventType,
      sourceType: n.sourceType,
    );
    final isEnergy = n.sourceType.toLowerCase() == 'energy' ||
        classifyNotification(n) == NotificationScope.energy;
    final accent =
        isEnergy ? AppTheme.emerald : AppTheme.indigoPrimary;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEnergy
                          ? _energyIconFor(n)
                          : _appIconFor(n),
                      size: 18,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tag.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                color: accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          isEnergy
                              ? 'متابعة الطاقة والأحمال'
                              : 'إشعارات التطبيق',
                          style: const TextStyle(
                            color: AppTheme.faintMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(unread: unread),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        n.title.isNotEmpty ? n.title : '—',
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.4,
                        ),
                      ),
                      if (n.message.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          n.message,
                          style: const TextStyle(
                            color: AppTheme.softInk,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 1.65,
                          ),
                        ),
                      ],
                      // v44 phase 2: polished Arabic summary block for
                      // the backend-supported scheduled energy events.
                      // Renders nothing (zero-height) when the payload
                      // is missing or the event_type is unsupported, so
                      // legacy notifications keep their original layout.
                      _PayloadSummary(notification: n),
                      const SizedBox(height: 14),
                      _DetailKvBlock(
                        notification: n,
                        userTimezone: userTimezone,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (unread)
                    Expanded(
                      child: SizedBox(
                        height: AppTheme.formControlHeight,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await onMarkRead();
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.done, size: 18),
                          label: const Text('تحديد كمقروء'),
                        ),
                      ),
                    ),
                  if (unread) const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: AppTheme.formControlHeight,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('إغلاق'),
                      ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.unread});
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final tone = unread ? AppTheme.violet : AppTheme.success;
    final label = unread ? 'غير مقروء' : 'مقروء';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// v44 phase 2: polished Arabic detail block for scheduled energy
/// events whose backend payload is supported in phase 1a.
///
/// Renders **nothing** (zero-height `SizedBox.shrink`) when:
///   * the notification has no `payload` (legacy rows, support /
///     account / app notifications, live events without a structured
///     echo), or
///   * the `event_type` is not on the phase 1a whitelist
///     (`periodic_day`, `periodic_night`, `pre_sunset`, `daily_report`).
///
/// Every cell goes through [NotificationLabels.format…] so empty or
/// malformed payload values render the friendly Arabic placeholder
/// `غير متوفر` instead of leaking raw English slugs to the user.
class _PayloadSummary extends StatelessWidget {
  const _PayloadSummary({required this.notification});

  final AppNotification notification;

  /// Whitelist of `event_type` values the v44 phase 1a backend mirror
  /// actually populates. Anything outside this set is treated as
  /// "no summary to render" — the technical section still shows the
  /// raw event_type for support tracing.
  static const Set<String> _supportedEventTypes = {
    'periodic_day',
    'periodic_night',
    'pre_sunset',
    'daily_report',
  };

  @override
  Widget build(BuildContext context) {
    final payload = notification.payload;
    final ev = notification.eventType.trim().toLowerCase();
    if (payload == null || !_supportedEventTypes.contains(ev)) {
      return const SizedBox.shrink();
    }

    final rows = <_PayloadRow>[];
    switch (ev) {
      case 'periodic_day':
      case 'periodic_night':
        rows.addAll([
          _PayloadRow('نسبة البطارية',
              NotificationLabels.formatSocPercent(payload['soc'])),
          _PayloadRow('الإنتاج الشمسي الحالي',
              NotificationLabels.formatWatts(payload['solar_w'])),
          _PayloadRow('استهلاك المنزل الحالي',
              NotificationLabels.formatWatts(payload['home_w'])),
        ]);
        final weather = payload['weather_summary'];
        if (weather != null &&
            weather.toString().trim().isNotEmpty) {
          rows.add(_PayloadRow('ملخص الطقس',
              NotificationLabels.formatFreeText(weather)));
        }
        break;
      case 'pre_sunset':
        rows.addAll([
          _PayloadRow('الوقت المتبقي للغروب',
              NotificationLabels.formatMinutes(payload['minutes_to_sunset'])),
          _PayloadRow('نسبة البطارية الآن',
              NotificationLabels.formatSocPercent(payload['soc_now'])),
          _PayloadRow(
            'اكتمال الشحن قبل الغروب',
            NotificationLabels.formatWillFullBeforeSunset(
              payload['will_full_before_sunset'],
            ),
          ),
          _PayloadRow(
            'الوقت المتوقع للشحن الكامل',
            NotificationLabels.formatHours(payload['time_to_full_hours']),
          ),
        ]);
        break;
      case 'daily_report':
        rows.addAll([
          _PayloadRow('إنتاج اليوم السابق',
              NotificationLabels.formatKwh(payload['yesterday_kwh'])),
          _PayloadRow('إنتاج الشهر',
              NotificationLabels.formatKwh(payload['month_kwh'])),
          _PayloadRow('الإجمالي التراكمي',
              NotificationLabels.formatKwh(payload['lifetime_kwh'])),
        ]);
        break;
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.emerald.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.emerald.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.insights_outlined,
                    size: 14,
                    color: AppTheme.emerald,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ملخص التنبيه',
                    style: TextStyle(
                      color: AppTheme.emerald,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              _PayloadRowWidget(row: rows[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayloadRow {
  const _PayloadRow(this.label, this.value);
  final String label;
  final String value;
}

class _PayloadRowWidget extends StatelessWidget {
  const _PayloadRowWidget({required this.row});
  final _PayloadRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            row.label,
            style: const TextStyle(
              color: AppTheme.softInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: SelectableText(
            row.value,
            textAlign: TextAlign.start,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// v97: KV block is now stateful so it can host a collapsible
/// "تفاصيل تقنية" section. The user-facing rows always use Arabic
/// labels + mapped Arabic values; the raw English slugs only appear
/// when the user explicitly expands the technical section.
class _DetailKvBlock extends StatefulWidget {
  const _DetailKvBlock({
    required this.notification,
    required this.userTimezone,
  });

  final AppNotification notification;
  final String userTimezone;

  @override
  State<_DetailKvBlock> createState() => _DetailKvBlockState();
}

class _DetailKvBlockState extends State<_DetailKvBlock> {
  bool _techExpanded = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final created = _exactTimestamp(n.createdAt);
    final read = _exactTimestamp(n.readAt);

    // v97: every user-facing value goes through the Arabic localiser.
    // Raw English slugs only appear inside the collapsed technical
    // section below.
    final eventLabel = NotificationLabels.eventTypeLabel(n.eventType);
    final sourceLabel = NotificationLabels.sourceTypeLabel(n.sourceType);
    final statusLabel = NotificationLabels.statusLabel(n.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.softBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          _KvRow(label: 'نوع التنبيه', value: eventLabel),
          _KvRow(label: 'المصدر', value: sourceLabel),
          if (n.sourceId != null)
            _KvRow(label: 'رقم المرجع', value: '#${n.sourceId}'),
          _KvRow(label: 'الحالة', value: statusLabel),
          if (created != null)
            _KvRow(label: 'وقت الإنشاء', value: created),
          if (read != null)
            _KvRow(label: 'وقت القراءة', value: read),
          if (widget.userTimezone.isNotEmpty)
            _KvRow(label: 'نطاق الملف الشخصي', value: widget.userTimezone),
          const SizedBox(height: 6),
          _TechDetailsToggle(
            expanded: _techExpanded,
            onTap: () => setState(() => _techExpanded = !_techExpanded),
          ),
          if (_techExpanded) ...[
            const SizedBox(height: 6),
            _TechDetailsPanel(notification: n),
          ],
        ],
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: SelectableText(
              value,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// v97: collapsed-by-default disclosure row for the technical details
/// panel. Tap to reveal the raw English `event_type` / `source_type` /
/// `status` slugs — useful for support agents tracing an issue back to
/// the backend payload without polluting the normal user-facing rows.
class _TechDetailsToggle extends StatelessWidget {
  const _TechDetailsToggle({required this.expanded, required this.onTap});
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.terminal,
                  size: 14, color: AppTheme.faintMuted),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'تفاصيل تقنية',
                  style: TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(
                  Icons.expand_more,
                  size: 16,
                  color: AppTheme.faintMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapsed-by-default diagnostics panel for support agents tracing a
/// notification back to its backend payload. Only visible after the
/// user taps [_TechDetailsToggle].
///
/// v44 audit polish:
///   * Row labels are now fully Arabic (via
///     [NotificationLabels.technicalRowLabel]) so the panel no longer
///     leaks English identifiers as labels in an Arabic-first surface.
///     The **values** stay raw — that is the diagnostic payload.
///   * The previous forced-LTR wrapper around the rows is gone:
///     Arabic labels follow the parent screen's natural RTL flow, and
///     Latin values inside an RTL cell are bidi-isolated by Flutter
///     automatically, so the row reads cleanly without it.
///   * Empty values render as the calm Arabic placeholder
///     `لا يوجد` instead of a bare em-dash that reads as foreign
///     punctuation inside an Arabic-first surface.
class _TechDetailsPanel extends StatelessWidget {
  const _TechDetailsPanel({required this.notification});
  final AppNotification notification;

  /// Calm Arabic placeholder for missing raw values. Distinct from
  /// [NotificationLabels.payloadEmpty] (`غير متوفر`, payload summary)
  /// and [NotificationLabels.emptyFieldLabel] (`غير محدد`, primary
  /// metadata) so each surface has a tonally appropriate fallback.
  static const String _missing = 'لا يوجد';

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Arabic intro — keeps the panel clearly secondary and
          // signals to the user that what follows is technical, not
          // for normal reading.
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.faintMuted.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.code,
                  size: 11,
                  color: AppTheme.faintMuted,
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'حقول للتشخيص الفني فقط',
                  style: TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _RawKvRow(
            label: NotificationLabels.technicalRowLabel('id'),
            value: '#${n.id}',
          ),
          _RawKvRow(
            label: NotificationLabels.technicalRowLabel('event_type'),
            value: n.eventType.isEmpty ? _missing : n.eventType,
          ),
          _RawKvRow(
            label: NotificationLabels.technicalRowLabel('source_type'),
            value: n.sourceType.isEmpty ? _missing : n.sourceType,
          ),
          _RawKvRow(
            label: NotificationLabels.technicalRowLabel('source_id'),
            value: n.sourceId == null ? _missing : '#${n.sourceId}',
          ),
          _RawKvRow(
            label: NotificationLabels.technicalRowLabel('status'),
            value: n.status.isEmpty ? _missing : n.status,
          ),
          _RawKvRow(
            label: NotificationLabels.technicalRowLabel('is_read'),
            value: NotificationLabels.boolLabel(n.isRead),
          ),
        ],
      ),
    );
  }
}

/// Raw KV row for [_TechDetailsPanel].
///
/// v44 audit polish: the row now displays an Arabic label (resolved
/// by [NotificationLabels.technicalRowLabel]) on the leading side
/// and the raw backend value on the trailing side. The label keeps
/// its visual subordination (lighter tone, smaller font, w500
/// weight) so it doesn't compete with the Arabic primary metadata
/// rendered immediately above the panel.
class _RawKvRow extends StatelessWidget {
  const _RawKvRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.faintMuted.withValues(alpha: 0.85),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: SelectableText(
              value,
              style: const TextStyle(
                color: AppTheme.softInk,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter sheet — read-state + (when scope=energy) category. Returned
/// via Navigator.pop so the caller can apply the new selection in one
/// `setState` call.
class _FilterResult {
  const _FilterResult({
    required this.unreadOnly,
    required this.energyCategory,
  });
  final bool unreadOnly;
  final EnergyCategory energyCategory;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.scope,
    required this.unreadOnly,
    required this.energyCategory,
  });

  final NotificationScope scope;
  final bool unreadOnly;
  final EnergyCategory energyCategory;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late bool _unreadOnly;
  late EnergyCategory _energyCategory;

  @override
  void initState() {
    super.initState();
    _unreadOnly = widget.unreadOnly;
    _energyCategory = widget.energyCategory;
  }

  void _reset() {
    setState(() {
      _unreadOnly = false;
      _energyCategory = EnergyCategory.all;
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      _FilterResult(
        unreadOnly: _unreadOnly,
        energyCategory: _energyCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnergy = widget.scope == NotificationScope.energy;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'تصفية الإشعارات',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('مسح'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const _SheetSectionLabel(label: 'حالة القراءة'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MicroPill(
                  label: 'الكل',
                  selected: !_unreadOnly,
                  onTap: () => setState(() => _unreadOnly = false),
                ),
                _MicroPill(
                  label: 'غير المقروء',
                  selected: _unreadOnly,
                  onTap: () => setState(() => _unreadOnly = true),
                ),
              ],
            ),
            if (isEnergy) ...[
              const SizedBox(height: 14),
              const _SheetSectionLabel(label: 'فئة الطاقة'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in const [
                    EnergyCategory.all,
                    EnergyCategory.battery,
                    EnergyCategory.load,
                    EnergyCategory.sunWeather,
                    EnergyCategory.reports,
                  ])
                    _MicroPill(
                      label: energyCategoryLabel(c),
                      selected: _energyCategory == c,
                      onTap: () => setState(() => _energyCategory = c),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: AppTheme.formControlHeight,
              child: FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('تطبيق'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.faintMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Help sheet — keeps the v92 explanation text accessible without
/// pushing it into the main scroll. Includes the energy hero summary,
/// the "push notifications coming later" honesty note, and a brief
/// scope reminder.
class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'كيف يعمل تبويب الإشعارات',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _HelpBlock(
                  icon: Icons.notifications_outlined,
                  tone: AppTheme.indigoPrimary,
                  title: notificationScopeTitle(NotificationScope.app),
                  body: notificationScopeIntro(NotificationScope.app),
                ),
                const SizedBox(height: 10),
                _HelpBlock(
                  icon: Icons.bolt_outlined,
                  tone: AppTheme.emerald,
                  title: notificationScopeTitle(NotificationScope.energy),
                  body: 'تظهر هنا تنبيهات الطاقة والأحمال التي يحفظها '
                      'النظام: البطارية، الأحمال، الشمس، الفائض، '
                      'والتقارير الدورية.',
                ),
                const SizedBox(height: 10),
                _HelpBlock(
                  icon: Icons.notifications_paused_outlined,
                  tone: AppTheme.amber,
                  title: 'إشعارات الجوال المباشرة',
                  body: 'إشعارات الجوال المباشرة ستُفعّل في مرحلة لاحقة. '
                      'حالياً تظهر التنبيهات داخل التطبيق فقط، وتُحدَّث '
                      'كل عشر ثوانٍ تلقائياً أثناء فتح هذه الشاشة.',
                ),
                const SizedBox(height: 10),
                _HelpBlock(
                  icon: Icons.schedule,
                  tone: AppTheme.faintMuted,
                  title: 'النطاق الزمني للتنبيهات',
                  body: 'تُحفظ أوقات التنبيهات على الخادم بصيغة UTC، '
                      'وتُعرض على هذه الشاشة بحسب توقيت جهازك. '
                      'إذا اخترتَ نطاقاً زمنياً مختلفاً في ملفك الشخصي '
                      'فقد يختلف العرض حتى تتوفر تحويلات النطاقات '
                      'الزمنية الكاملة في تحديث لاحق.',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: AppTheme.formControlHeight,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('إغلاق'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpBlock extends StatelessWidget {
  const _HelpBlock({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tone,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppTheme.softInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timestamp helpers ──────────────────────────────────────────────────

/// v97: thin wrappers around the shared parser in
/// `core/utils/backend_time.dart`. The actual UTC-aware logic lives
/// there so Home, Notifications, Device Detail, Support, and Account
/// all render backend timestamps consistently. Keeping the
/// `_humanize…` / `_exact…` names here makes the call sites in this
/// screen unchanged.
String _humanizeTimestamp(String? iso) => formatBackendRelative(iso);
String? _exactTimestamp(String? iso) => formatBackendExact(iso);
