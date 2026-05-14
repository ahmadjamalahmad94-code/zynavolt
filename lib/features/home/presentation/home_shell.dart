import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';

/// Bottom-nav shell hosting the five top-level tabs.
///
/// v102 — Reactive floating-bubble design (owner's reference image
/// 2026-05-14): the selected tab's icon rides on a floating white
/// circle that sits ABOVE the bar; the bar itself has a smooth
/// circular notch cut into its top edge under the bubble. As the
/// user switches tabs, the bubble and the notch glide along the
/// bar to the new tab's centre with an eased animation. Unselected
/// tabs render as flat icon+label stacks inside the bar.
///
/// v102+ — global popup-dismiss guard. Any modal sheet / dialog /
/// popup opened from a routed screen (without `useRootNavigator:
/// true`) lives on the shell's inner navigator. When the user
/// navigates between tabs (or any in-shell route change), the
/// guard pops every `PopupRoute` on top of the current page so a
/// sheet from one tab can't bleed across to another. Two hookups:
///
///   * tab tap → synchronous pop BEFORE `context.go(...)` so the
///     user never sees the old popup on the new tab even for a
///     single frame;
///   * any location change detected during `build` → a deferred
///     pop via `addPostFrameCallback` as a backstop for non-tab
///     navigation (push, go from inside a sheet, etc.).
///
/// Earlier v99f used a permanent Home FAB at the centre; this
/// supersedes it.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

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

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Last location we rendered against. Compared on every build
  /// so we can detect any in-shell route change and dismiss
  /// modals on a post-frame callback.
  String? _lastLocation;

  int _indexFor(String location) {
    for (var i = 0; i < HomeShell._tabs.length; i++) {
      if (location.startsWith(HomeShell._tabs[i].route)) return i;
    }
    return 0;
  }

  /// Pops every PopupRoute (bottom sheets, dialogs, modals) from
  /// the shell's inner navigator while leaving page routes
  /// untouched. Safe to call without checking — if there's
  /// nothing to pop the predicate stops immediately.
  void _dismissAnyOpenPopups() {
    shellNavigatorKey.currentState
        ?.popUntil((route) => route is! PopupRoute);
  }

  void _onTabSelected(int i) {
    // Synchronous dismiss BEFORE navigation so the new tab never
    // even briefly renders behind a stale sheet from the old one.
    _dismissAnyOpenPopups();
    context.go(HomeShell._tabs[i].route);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);

    // Backstop: any location change (push, replace, programmatic
    // go from inside a sheet, etc.) that wasn't routed through
    // `_onTabSelected` still triggers a popup dismissal once the
    // current frame finishes painting.
    if (_lastLocation != null && _lastLocation != location) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dismissAnyOpenPopups();
      });
    }
    _lastLocation = location;

    return Scaffold(
      // `extendBody: true` lets the floating bubble overlap the bottom
      // of the page content cleanly; the bar's clipper paints opaque
      // white so the area behind the bar itself stays hidden.
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: _ZynBottomNav(
        selectedIndex: index,
        tabs: HomeShell._tabs,
        onTabSelected: _onTabSelected,
      ),
    );
  }
}

class _ZynBottomNav extends StatefulWidget {
  const _ZynBottomNav({
    required this.selectedIndex,
    required this.tabs,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final List<_Tab> tabs;
  final ValueChanged<int> onTabSelected;

  /// Tunables — keep these grouped so future visual tweaks don't
  /// require reading the whole layout block.
  static const double barHeight = 70;
  static const double bubbleSize = 56;
  static const double bubbleOverlap = 26;
  static const double notchRadius = 34;
  static const double barCornerRadius = 30;

  @override
  State<_ZynBottomNav> createState() => _ZynBottomNavState();
}

class _ZynBottomNavState extends State<_ZynBottomNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late Animation<double> _animatedPos;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _animatedPos =
        AlwaysStoppedAnimation<double>(widget.selectedIndex.toDouble());
  }

  @override
  void didUpdateWidget(covariant _ZynBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animatedPos = Tween<double>(
        begin: _animatedPos.value,
        end: widget.selectedIndex.toDouble(),
      ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
      _ac
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaPad = MediaQuery.of(context).padding.bottom;
    final totalHeight =
        _ZynBottomNav.barHeight + _ZynBottomNav.bubbleOverlap + mediaPad;

    return SizedBox(
      height: totalHeight,
      child: AnimatedBuilder(
        animation: _animatedPos,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              // Convert the animated tab index (0..tabs.length-1) into
              // the horizontal pixel position of that slot's centre.
              // Slot width = full width / number of tabs. The RTL flip
              // is handled by Directionality further up; we compute
              // logical positions left-to-right here.
              final slotWidth = constraints.maxWidth / widget.tabs.length;
              final logicalCentre =
                  (_animatedPos.value + 0.5) * slotWidth;
              final isRtl = Directionality.of(context) == TextDirection.rtl;
              final centreX = isRtl
                  ? constraints.maxWidth - logicalCentre
                  : logicalCentre;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Bar surface with a circular notch carved out of the
                  // top edge under the active tab's centre.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _ZynBottomNav.barHeight + mediaPad,
                    child: _NotchedBarSurface(
                      notchCentreX: centreX,
                      bottomPadding: mediaPad,
                      child: Row(
                        children: [
                          for (int i = 0; i < widget.tabs.length; i++)
                            Expanded(
                              child: _FlatTab(
                                tab: widget.tabs[i],
                                active: widget.selectedIndex == i,
                                onTap: () => widget.onTabSelected(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Floating bubble — same x as the notch, riding the
                  // bar's top edge.
                  Positioned(
                    top: 0,
                    left: centreX - _ZynBottomNav.bubbleSize / 2,
                    width: _ZynBottomNav.bubbleSize,
                    height: _ZynBottomNav.bubbleSize,
                    child: _Bubble(
                      icon: widget
                          .tabs[widget.selectedIndex].iconActive,
                      onTap: () => widget
                          .onTabSelected(widget.selectedIndex),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// White bar with rounded ends + a circular notch cut into the top
/// edge under the active tab. Uses [PhysicalShape] so the drop
/// shadow follows the notch silhouette automatically.
class _NotchedBarSurface extends StatelessWidget {
  const _NotchedBarSurface({
    required this.notchCentreX,
    required this.bottomPadding,
    required this.child,
  });

  final double notchCentreX;
  final double bottomPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PhysicalShape(
      color: Colors.white,
      elevation: 8,
      shadowColor: AppTheme.indigoPrimary.withValues(alpha: 0.35),
      clipper: _NotchedBarClipper(
        notchCentreX: notchCentreX,
        notchRadius: _ZynBottomNav.notchRadius,
        cornerRadius: _ZynBottomNav.barCornerRadius,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SizedBox(
          height: _ZynBottomNav.barHeight,
          child: child,
        ),
      ),
    );
  }
}

class _NotchedBarClipper extends CustomClipper<Path> {
  const _NotchedBarClipper({
    required this.notchCentreX,
    required this.notchRadius,
    required this.cornerRadius,
  });

  final double notchCentreX;
  final double notchRadius;
  final double cornerRadius;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final nr = notchRadius;
    final cx = notchCentreX.clamp(nr + r + 4, w - nr - r - 4);

    // Smooth-edge offset — gives the notch's lips a gentle approach
    // into the bar surface instead of a hard kink.
    const lip = 8.0;

    final p = Path();
    // Start just after the top-left rounded corner.
    p.moveTo(r, 0);
    // Travel along the top edge to the start of the notch.
    p.lineTo(cx - nr - lip, 0);
    // Curve gently down into the notch's left lip.
    p.quadraticBezierTo(cx - nr, 0, cx - nr + 2, 6);
    // Arc the notch (a semicircle that scoops down into the bar).
    p.arcToPoint(
      Offset(cx + nr - 2, 6),
      radius: Radius.circular(nr),
      clockwise: false,
    );
    // Curve back up to the top edge after the notch.
    p.quadraticBezierTo(cx + nr, 0, cx + nr + lip, 0);
    // Continue along the top edge to the top-right corner.
    p.lineTo(w - r, 0);
    // Top-right rounded corner.
    p.arcToPoint(
      Offset(w, r),
      radius: Radius.circular(r),
    );
    // Right edge.
    p.lineTo(w, h - r);
    // Bottom-right rounded corner.
    p.arcToPoint(
      Offset(w - r, h),
      radius: Radius.circular(r),
    );
    // Bottom edge.
    p.lineTo(r, h);
    // Bottom-left rounded corner.
    p.arcToPoint(
      Offset(0, h - r),
      radius: Radius.circular(r),
    );
    // Left edge.
    p.lineTo(0, r);
    // Top-left rounded corner — closes the shape.
    p.arcToPoint(
      Offset(r, 0),
      radius: Radius.circular(r),
    );
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant _NotchedBarClipper oldClipper) {
    return oldClipper.notchCentreX != notchCentreX ||
        oldClipper.notchRadius != notchRadius ||
        oldClipper.cornerRadius != cornerRadius;
  }
}

/// One slot inside the bar — icon stacked over label. The active
/// slot hides its in-bar icon (the floating bubble carries the icon
/// instead) and shows only the label so the visual weight matches
/// the reference design.
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
    final color = active
        ? AppTheme.indigoPrimary
        : AppTheme.faintMuted.withValues(alpha: 0.85);
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        highlightShape: BoxShape.rectangle,
        containedInkWell: true,
        child: SizedBox(
          height: _ZynBottomNav.barHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Reserve the icon's vertical slot for unselected tabs;
              // selected tabs spend that slot under the floating
              // bubble (which sits above the bar) and leave a gap so
              // the label centres nicely below.
              SizedBox(
                height: 24,
                child: active
                    ? const SizedBox.shrink()
                    : Icon(tab.iconInactive, color: color, size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                tab.label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
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

/// The floating bubble that carries the active tab's icon and rides
/// the notch in the bar. Tapping it (the same tab again) is a
/// harmless re-fire of [_ZynBottomNav.onTabSelected].
class _Bubble extends StatelessWidget {
  const _Bubble({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: AppTheme.indigoPrimary.withValues(alpha: 0.40),
      child: InkResponse(
        onTap: onTap,
        radius: _ZynBottomNav.bubbleSize / 2,
        customBorder: const CircleBorder(),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Subtle inner gradient so the bubble doesn't look flat.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                AppTheme.indigoSoft.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: Icon(
            icon,
            color: AppTheme.indigoPrimary,
            size: 26,
          ),
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
