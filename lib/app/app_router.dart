import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/state/app_session.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/devices/presentation/device_detail_screen.dart';
import '../features/devices/presentation/devices_screen.dart';
import '../features/loads/presentation/loads_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/support/presentation/support_screen.dart';

class AppRoutes {
  const AppRoutes._();
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/home';
  static const String devices = '/devices';
  static const String notifications = '/notifications';
  static const String support = '/support';
  static const String more = '/more';
  static const String profile = '/profile';
  static const String loads = '/loads';

  /// Build a typed path for the device-detail screen. Kept outside the
  /// bottom-nav shell so it has full-screen real estate and a normal back
  /// button — same pattern as [profile].
  static String deviceDetail(int id) => '/devices/$id';
}

/// GoRouter wired to [appSessionProvider]. Redirects are session-driven:
/// boot lands on /splash, splash resolves auth, the rest is gated by the
/// presence of a signed-in user in [AppSession].
final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(appSessionProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: ref.watch(appSessionListenableProvider),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final phase = session.phase;

      if (phase == AppSessionPhase.unknown) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }
      if (phase == AppSessionPhase.unauthenticated) {
        return loc == AppRoutes.login ? null : AppRoutes.login;
      }
      // authenticated
      if (loc == AppRoutes.splash || loc == AppRoutes.login) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginScreen(),
      ),
      // Profile is a focused detail screen — kept outside the bottom-nav
      // shell so it has full screen real estate during edit.
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, _) => const ProfileScreen(),
      ),
      // v47: device details — full-screen detail with normal back button,
      // outside the shell. Path parameter is the integer device id.
      GoRoute(
        path: '/devices/:id',
        builder: (_, state) {
          final raw = state.pathParameters['id'] ?? '';
          final id = int.tryParse(raw) ?? 0;
          return DeviceDetailScreen(deviceId: id);
        },
      ),
      // v48: loads — opened from the More tab as a focused list.
      GoRoute(
        path: AppRoutes.loads,
        builder: (_, _) => const LoadsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, _) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.devices,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: DevicesScreen()),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: NotificationsScreen()),
          ),
          GoRoute(
            path: AppRoutes.support,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: SupportScreen()),
          ),
          GoRoute(
            path: AppRoutes.more,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: MoreScreen()),
          ),
        ],
      ),
    ],
  );
});

/// A tiny [ChangeNotifier] adapter so go_router can re-evaluate redirects
/// when the session phase changes.
final appSessionListenableProvider = Provider<Listenable>((ref) {
  final notifier = _SessionListenable();
  ref.listen(appSessionProvider, (_, _) => notifier.tick(), fireImmediately: false);
  ref.onDispose(notifier.dispose);
  return notifier;
});

class _SessionListenable extends ChangeNotifier {
  void tick() => notifyListeners();
}
