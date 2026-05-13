import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';

/// Bottom-nav shell hosting the five top-level tabs.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  // v63: bottom nav now hosts Weather instead of Support. Support is
  // reached from the المزيد tab via `context.push(/support)` so the
  // user gets a back-arrow AppBar — the v61 audit recommended this
  // swap to avoid crowding the bar with a sixth destination.
  static const List<_Tab> _tabs = [
    _Tab(label: 'الرئيسية', icon: Icons.dashboard_outlined, route: AppRoutes.home),
    _Tab(label: 'الأجهزة', icon: Icons.solar_power_outlined, route: AppRoutes.devices),
    _Tab(label: 'الطقس', icon: Icons.cloud_outlined, route: AppRoutes.weather),
    _Tab(
      label: 'الإشعارات',
      icon: Icons.notifications_none_outlined,
      route: AppRoutes.notifications,
    ),
    _Tab(label: 'المزيد', icon: Icons.more_horiz, route: AppRoutes.more),
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
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].route),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _Tab {
  const _Tab({required this.label, required this.icon, required this.route});
  final String label;
  final IconData icon;
  final String route;
}
