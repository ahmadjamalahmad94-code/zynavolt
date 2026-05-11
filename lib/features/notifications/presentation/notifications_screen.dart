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

  /// v92: local category filter inside the Energy tab. Only meaningful
  /// when [_scope] is [NotificationScope.energy].
  EnergyCategory _energyCategory = EnergyCategory.all;

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
              energyCategory: _energyCategory,
              onScopeChanged: (s) => setState(() => _scope = s),
              onFilterChanged: (v) => setState(() => _unreadOnly = v),
              onEnergyCategoryChanged: (c) =>
                  setState(() => _energyCategory = c),
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
    required this.energyCategory,
    required this.onScopeChanged,
    required this.onFilterChanged,
    required this.onEnergyCategoryChanged,
  });
  final NotificationsFeedState state;
  final NotificationScope scope;
  final bool unreadOnly;
  final EnergyCategory energyCategory;
  final ValueChanged<NotificationScope> onScopeChanged;
  final ValueChanged<bool> onFilterChanged;
  final ValueChanged<EnergyCategory> onEnergyCategoryChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // v91: partition the flat backend feed into the two scopes first.
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

    // v92: local Energy category filter applies only inside the Energy tab.
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
    // v94: gate "تحميل المزيد" on actually having items in the current
    // tab. Previously the button rendered the empty-state widget twice
    // when `!hasItems && state.hasMore` — that's the "duplicate
    // placeholder cards" the user saw on real devices.
    final showLoadMore = hasItems && !unreadOnly && state.hasMore;
    // v94: when this tab is empty, surface an honest hint pointing to
    // the OTHER tab if it has items there. The empty card itself shows
    // exactly once (also fixed in itemBuilder below).
    final otherScope = scope == NotificationScope.app
        ? NotificationScope.energy
        : NotificationScope.app;
    final otherScopeItems =
        otherScope == NotificationScope.energy ? energyItems : appItems;

    // v92: build leading widgets eagerly so the layout can differ per
    // scope. App tab stays simple; Energy tab gets the hero card, the
    // mobile-alerts readiness note, and the category filter strip.
    final leading = <Widget>[
      _ScopeTabs(
        scope: scope,
        appUnread: appItems.where((n) => !n.isRead).length,
        energyUnread: energyItems.where((n) => !n.isRead).length,
        onChanged: onScopeChanged,
      ),
      _HeaderCard(
        unreadCount: unreadInScope,
        isMarkingAll: state.isMarkingAll,
        onMarkAll: state.unreadCount == 0 || state.isMarkingAll
            ? null
            : () => _runMarkAll(context, ref),
      ),
      if (scope == NotificationScope.energy)
        _EnergyHeroCard(latestEnergyItem: energyItems.firstOrNull),
      _ScopeIntro(scope: scope),
      if (scope == NotificationScope.energy)
        const _MobileAlertsReadinessCard(),
      if (scope == NotificationScope.energy)
        const _FilterSectionLabel(label: 'تصفية الفئة'),
      if (scope == NotificationScope.energy)
        _EnergyCategoryFilters(
          selected: energyCategory,
          onChanged: onEnergyCategoryChanged,
        ),
      const _FilterSectionLabel(label: 'حالة القراءة'),
      _FilterRow(
        unreadOnly: unreadOnly,
        unreadCount: unreadInScope,
        onChanged: onFilterChanged,
      ),
    ];

    final headerCount = leading.length;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: headerCount +
          (hasItems ? visible.length : 1) +
          (showLoadMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index < headerCount) return leading[index];
        // v94: only one extra index ever exists post-header — either
        // the single empty-state card, or the items + optional
        // load-more. The previous logic mistakenly returned the empty
        // card for every post-header index when `!hasItems && hasMore`.
        if (!hasItems) {
          return _EmptyStateCard(
            scope: scope,
            unreadOnly: unreadOnly,
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
          return _NotificationTile(
            notification: n,
            energyAccent: scope == NotificationScope.energy,
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

  // v94: empty-state copy moved into the `_EmptyStateCard` widget — that
  // widget knows both scopes' counts so it can suggest jumping tabs.

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

/// v94: tiny uppercase-style label that sits above each filter row so
/// the user knows which filter scope each pill cluster belongs to —
/// removes the "two `الكل` chips next to each other with no context"
/// confusion the previous layout had.
class _FilterSectionLabel extends StatelessWidget {
  const _FilterSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, top: 4),
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

  /// v94: vertical layout (icon row on top, label below) so the full
  /// label is always readable. The unread chip sits next to the icon
  /// instead of competing with the label for horizontal space — that
  /// was the root cause of "متابعة الطاقة والأحم..." clipping.
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
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: fg),
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
                        style: const TextStyle(
                          color: AppTheme.indigoPrimary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                style: TextStyle(
                  color: fg,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
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

/// v92: hero card for the Energy tab. Shows category chips and (if any
/// energy notifications are loaded) a tiny "آخر تنبيه" preview of the
/// most recent one. No fake data — purely a summary of the already-
/// fetched feed.
class _EnergyHeroCard extends StatelessWidget {
  const _EnergyHeroCard({required this.latestEnergyItem});
  final AppNotification? latestEnergyItem;

  @override
  Widget build(BuildContext context) {
    final latestTitle = latestEnergyItem?.title.trim();
    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_outlined,
                  color: AppTheme.emerald,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'متابعة الطاقة والأحمال',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'هنا تظهر تنبيهات البطارية، الأحمال، الشمس، والفائض.',
                      style: TextStyle(
                        color: AppTheme.faintMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              _CategoryPill(
                icon: Icons.battery_charging_full_outlined,
                label: 'البطارية',
                tone: AppTheme.emerald,
              ),
              _CategoryPill(
                icon: Icons.bolt_outlined,
                label: 'الأحمال',
                tone: AppTheme.indigoPrimary,
              ),
              _CategoryPill(
                icon: Icons.wb_sunny_outlined,
                label: 'الشمس',
                tone: AppTheme.warning,
              ),
              _CategoryPill(
                icon: Icons.cloud_outlined,
                label: 'الطقس',
                tone: AppTheme.cyan,
              ),
              _CategoryPill(
                icon: Icons.summarize_outlined,
                label: 'التقرير اليومي',
                tone: AppTheme.violet,
              ),
            ],
          ),
          if (latestTitle != null && latestTitle.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.softBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.history,
                      size: 14, color: AppTheme.faintMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'آخر تنبيه: $latestTitle',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tone),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// v92: honest "push notifications coming later" note. Prevents the user
/// from assuming they'll receive these alerts on the lock screen.
class _MobileAlertsReadinessCard extends StatelessWidget {
  const _MobileAlertsReadinessCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.notifications_paused_outlined,
              color: AppTheme.amber, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'إشعارات الجوال المباشرة ستُفعّل في مرحلة لاحقة. '
              'حالياً تظهر التنبيهات داخل التطبيق.',
              style: TextStyle(
                color: AppTheme.amber,
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

/// v92: local category-filter strip inside the Energy tab. Filters the
/// already-fetched list client-side via [classifyEnergyCategory] — no
/// extra backend round-trips.
class _EnergyCategoryFilters extends StatelessWidget {
  const _EnergyCategoryFilters({
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in _categories) ...[
            _Pill(
              label: energyCategoryLabel(c),
              selected: c == selected,
              onTap: () => onChanged(c),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// v94: single, honest empty state. Renders **once** per empty tab and
/// — when the other tab actually has items — surfaces a jump button so
/// the user isn't stuck staring at "no notifications" while their feed
/// sits in the other scope.
class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.scope,
    required this.unreadOnly,
    required this.otherScopeUnread,
    required this.otherScopeTotal,
    required this.onJumpToOther,
  });

  final NotificationScope scope;
  final bool unreadOnly;
  final int otherScopeUnread;
  final int otherScopeTotal;
  final VoidCallback? onJumpToOther;

  String get _title {
    if (unreadOnly) return 'لا توجد إشعارات غير مقروءة';
    if (scope == NotificationScope.energy) {
      return 'لا توجد تنبيهات طاقة أو أحمال حالياً.';
    }
    return 'لا توجد إشعارات تطبيق حالياً.';
  }

  String get _subtitle {
    if (unreadOnly) return 'كل إشعاراتك الحالية في هذا التبويب مقروءة.';
    if (scope == NotificationScope.energy) {
      return 'عند توفر تنبيهات البطارية أو الأحمال ستظهر هنا.';
    }
    return 'سيظهر كل إشعار جديد من النظام أو من فريق الدعم هنا.';
  }

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
          if (hasOther) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
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
                        ? 'يوجد $otherScopeUnread إشعار غير مقروء في تبويب "$otherTitle".'
                        : 'يوجد $otherScopeTotal إشعار في تبويب "$otherTitle".',
                    style: const TextStyle(
                      color: AppTheme.indigoPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: onJumpToOther,
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: Text('فتح "$otherTitle"'),
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    this.onTap,
    this.energyAccent = false,
  });

  final AppNotification notification;
  final VoidCallback? onTap;

  /// v92: render an emerald left-edge stripe for Energy-tab tiles so the
  /// reader can scan energy notifications at a glance. Unread items take
  /// precedence (violet) when both flags would apply.
  final bool energyAccent;

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

    final Color accentColor;
    if (unread) {
      accentColor = AppTheme.violet;
    } else if (energyAccent) {
      accentColor = AppTheme.emerald;
    } else {
      accentColor = Colors.transparent;
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
              // v54: left accent bar — strong visual cue for unread state.
              // v92: emerald variant when rendered in the Energy tab.
              Container(
                width: 4,
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
