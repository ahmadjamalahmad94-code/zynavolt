import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';

/// Bottom-nav shell hosting the five top-level tabs.
///
/// v99f — visual redesign per the owner's reference image:
///   * 4 flat icon+label tabs live in the bar (two on each side).
///   * The "الرئيسية" (Home) tab is rendered as a large FLOATING
///     circular indigo button that sits ABOVE the bar — the visual
///     focal point of the nav.
///   * `extendBody: true` lets the floating button overlap the
///     content area cleanly.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  /// Tab definitions. The order here is the navigation index order;
  /// the FAB-style centre slot is always tab index 0 (Home), and the
  /// four flat slots in the bar are indices 1..4. The bar widget
  /// arranges them with two on each side of the centre button.
  static const List<_Tab> _tabs = [
    _Tab(
      label: 'الرئيسية',
      iconActive: Icons.dashboard_rounded,
      iconInactive: Icons.dashboard_outlined,
      route: AppRoutes.home,
    ),
    _Tab(
      label: 'الأجهزة',
      iconActive: Icons.solar_power_rounded,
      iconInactive: Icons.solar_power_outlined,
      route: AppRoutes.devices,
    ),
    _Tab(
      label: 'الطقس',
      iconActive: Icons.cloud_rounded,
      iconInactive: Icons.cloud_outlined,
      route: AppRoutes.weather,
    ),
    _Tab(
      label: 'الإشعارات',
      iconActive: Icons.notifications_rounded,
      iconInactive: Icons.notifications_none_outlined,
      route: AppRoutes.notifications,
    ),
    _Tab(
      label: 'المزيد',
      iconActive: Icons.apps_rounded,
      iconInactive: Icons.more_horiz_rounded,
      route: AppRoutes.more,
    ),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);

    return Scaffold(
      // v99f — `extendBody: true` allows the floating Home button to
      // overlap the bottom of the page content without clipping. The
      // bar widget itself paints an opaque white background so the
      // content underneath the bar stays hidden as expected.
      extendBody: true,
      body: child,
      bottomNavigationBar: _ZynavoltBottomNav(
        selectedIndex: index,
        tabs: _tabs,
        onTabSelected: (i) => context.go(_tabs[i].route),
      ),
    );
  }
}

/// v99f — bottom nav with a floating centre Home button.
///
/// Layout:
///   ╭──────────────────────────────────────╮
///   │           ⦿  (floating Home)         │      ← 28 px overflow
///   │ ┌──────┬──────┬──────┬──────┐        │
///   │ │ Tab1 │ Tab2 │ Tab3 │ Tab4 │        │      ← 70 px bar
///   │ └──────┴──────┴──────┴──────┘        │
///   ╰──────────────────────────────────────╯
class _ZynavoltBottomNav extends StatelessWidget {
  const _ZynavoltBottomNav({
    required this.selectedIndex,
    required this.tabs,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final List<_Tab> tabs;
  final ValueChanged<int> onTabSelected;

  /// The Home tab is always the first entry (index 0). The four
  /// flat slots are derived from the remaining tabs.
  static const int _homeIndex = 0;

  /// FAB-style button geometry.
  static const double _fabSize = 64;
  static const double _fabOverflow = 28;
  static const double _barHeight = 70;

  @override
  Widget build(BuildContext context) {
    // Split the four "flat" tabs into a left half and a right half
    // around the centre Home button. Two on each side so the bar
    // reads symmetrically.
    final flatTabs = [for (var i = 0; i < tabs.length; i++) if (i != _homeIndex) i];
    final leftHalf = flatTabs.sublist(0, flatTabs.length ~/ 2);
    final rightHalf = flatTabs.sublist(flatTabs.length ~/ 2);

    final mediaPadding = MediaQuery.of(context).padding.bottom;
    final totalHeight = _barHeight + _fabOverflow + mediaPadding;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barHeight + mediaPadding,
            child: _BarSurface(
              tabs: tabs,
              leftHalf: leftHalf,
              rightHalf: rightHalf,
              selectedIndex: selectedIndex,
              onTabSelected: onTabSelected,
              bottomPadding: mediaPadding,
            ),
          ),
          // Centre floating Home button
          Positioned(
            top: 0,
            child: _HomeFab(
              size: _fabSize,
              active: selectedIndex == _homeIndex,
              icon: tabs[_homeIndex].iconActive,
              onTap: () => onTabSelected(_homeIndex),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarSurface extends StatelessWidget {
  const _BarSurface({
    required this.tabs,
    required this.leftHalf,
    required this.rightHalf,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.bottomPadding,
  });

  final List<_Tab> tabs;
  final List<int> leftHalf;
  final List<int> rightHalf;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.indigoPrimary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left half — flat tabs
          for (final i in leftHalf)
            Expanded(
              child: _FlatTab(
                tab: tabs[i],
                active: selectedIndex == i,
                onTap: () => onTabSelected(i),
              ),
            ),
          // Gap reserved for the floating Home button.
          const SizedBox(width: 72),
          // Right half — flat tabs
          for (final i in rightHalf)
            Expanded(
              child: _FlatTab(
                tab: tabs[i],
                active: selectedIndex == i,
                onTap: () => onTabSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _FlatTab extends StatelessWidget {
  const _FlatTab({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? AppTheme.indigoPrimary : AppTheme.faintMuted.withValues(alpha: 0.85);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? tab.iconActive : tab.iconInactive,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                tab.label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeFab extends StatelessWidget {
  const _HomeFab({
    required this.size,
    required this.active,
    required this.icon,
    required this.onTap,
  });

  final double size;
  final bool active;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6366F1),
              Color(0xFF4338CA),
            ],
          ),
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
          boxShadow: [
            // Indigo glow
            BoxShadow(
              color: AppTheme.indigoPrimary.withValues(alpha: 0.50),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            // Outer ambient
            BoxShadow(
              color: const Color(0xFF4338CA).withValues(alpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab({
    required this.label,
    required this.iconActive,
    required this.iconInactive,
    required this.route,
  });

  final String label;
  final IconData iconActive;
  final IconData iconInactive;
  final String route;
}
