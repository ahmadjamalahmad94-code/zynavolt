import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/design/zyn_tokens.dart';

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

  // v102d — owner-asked: anchor "الرئيسية" in the visual centre of
  // the bar so the floating bubble sits on the home tab as the
  // hub. Index 2 is the centre slot in a 5-tab bar regardless of
  // RTL/LTR (the Directionality flips render order, but the middle
  // index stays the middle).
  static const List<_Tab> _tabs = [
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
      label: 'الرئيسية',
      iconActive: Icons.dashboard_rounded,
      iconInactive: Icons.dashboard_outlined,
      route: AppRoutes.home,
    ),
    _Tab(
      label: 'البطارية',
      iconActive: Icons.battery_charging_full_rounded,
      iconInactive: Icons.battery_charging_full_outlined,
      route: AppRoutes.batteryLab,
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
    // v102d — Home moved to the centre slot; fall back to it instead
    // of index 0 (which is now "المزيد").
    return HomeShell._tabs.indexWhere((t) => t.route == AppRoutes.home);
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

/// v102d — navy bar matching the hero strip. PhysicalShape keeps
/// the drop shadow tracing the notched silhouette; inside, a
/// gradient + faint sun-and-rays watermark mirror the page hero.
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
      color: ZynColors.navy900,
      elevation: 10,
      shadowColor: ZynColors.navy900.withValues(alpha: 0.40),
      clipper: _NotchedBarClipper(
        notchCentreX: notchCentreX,
        notchRadius: _ZynBottomNav.notchRadius,
        cornerRadius: _ZynBottomNav.barCornerRadius,
      ),
      child: Stack(
        children: [
          // Hero-style navy gradient overlaid on the solid navy900
          // fill so the bar reads as a continuation of the hero
          // strip at the top of the screen.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: ZynColors.navyHero),
            ),
          ),
          // Quiet sun-and-rays watermark — same vocabulary as the
          // hero, scaled for the shorter bar.
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _BottomNavWatermark()),
            ),
          ),
          // Top inner highlight — single hairline of light along
          // the upper edge so the bar feels lifted off the page.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.20),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: SizedBox(
              height: _ZynBottomNav.barHeight,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// v102d — bar-sized watermark. A soft sun bloom in one corner,
/// short rays, and a tiny solar-panel strip on the opposite side.
/// All at low alpha (0.05–0.10) over the navy gradient.
class _BottomNavWatermark extends CustomPainter {
  const _BottomNavWatermark();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sun bloom — leading side (right in RTL, left in LTR; we
    // paint at fixed canvas coords).
    final sunCx = w * 0.92;
    final sunCy = h * 0.50;
    final sunR = h * 0.30;

    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(sunCx, sunCy), radius: sunR * 2.6),
      );
    canvas.drawCircle(Offset(sunCx, sunCy), sunR * 2.6, halo);

    final sun = Paint()..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(Offset(sunCx, sunCy), sunR, sun);

    final rayPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final start = Offset(
        sunCx + math.cos(angle) * sunR * 1.30,
        sunCy + math.sin(angle) * sunR * 1.30,
      );
      final end = Offset(
        sunCx + math.cos(angle) * sunR * 1.55,
        sunCy + math.sin(angle) * sunR * 1.55,
      );
      canvas.drawLine(start, end, rayPaint);
    }

    // Tiny solar-panel strip on the trailing side.
    canvas.save();
    canvas.translate(w * 0.04, h * 0.55);
    canvas.transform(_skew(skewX: -0.30, skewY: 0.14).storage);

    final panel = Paint()..color = Colors.white.withValues(alpha: 0.05);
    final cell = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    final p1 = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-4, -14, 56, 22),
      const Radius.circular(3),
    );
    canvas.drawRRect(p1, panel);
    for (var i = 1; i < 4; i++) {
      final x = -4 + (56.0 * i / 4);
      canvas.drawLine(Offset(x, -14), Offset(x, 8), cell);
    }
    canvas.drawLine(const Offset(-4, -3), const Offset(52, -3), cell);

    canvas.restore();
  }

  Matrix4 _skew({required double skewX, required double skewY}) {
    return Matrix4.identity()
      ..setEntry(0, 1, skewX)
      ..setEntry(1, 0, skewY);
  }

  @override
  bool shouldRepaint(covariant _BottomNavWatermark oldDelegate) => false;
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
    // v102d — light text/icon tones since the bar surface is now
    // the navy hero gradient. The active tab's icon lives in the
    // floating white bubble above; only its label shows in the bar.
    final color = active
        ? Colors.white
        : Colors.white.withValues(alpha: 0.62);
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
      shadowColor: ZynColors.primary700.withValues(alpha: 0.40),
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
                ZynColors.primary50.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: Icon(
            icon,
            color: ZynColors.primary700,
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
