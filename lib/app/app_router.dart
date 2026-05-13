import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/state/app_session.dart';
import '../features/account/presentation/account_screen.dart';
import '../features/account/presentation/change_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/devices/presentation/device_detail_screen.dart';
import '../features/devices/presentation/devices_screen.dart';
import '../features/loads/presentation/loads_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/notifications/presentation/notification_settings_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/app_settings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/statistics/presentation/statistics_screen.dart';
import '../features/support/presentation/support_case_detail_screen.dart';
import '../features/support/presentation/support_create_case_screen.dart';
import '../features/support/presentation/support_screen.dart';
import '../features/weather/presentation/weather_screen.dart';

class AppRoutes {
  const AppRoutes._();
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String devices = '/devices';
  // v63: weather promoted into the bottom nav (replaces support).
  static const String weather = '/weather';
  static const String notifications = '/notifications';
  static const String support = '/support';
  static const String more = '/more';
  static const String profile = '/profile';
  static const String loads = '/loads';
  static const String account = '/account';
  static const String settings = '/settings';
  // v57: subscriber statistics + reports surfaces. Statistics consumes
  // the v56 `/api/v1/devices/<id>/statistics` endpoint; reports is an
  // honest placeholder until a mobile-side reports API arrives.
  static const String statistics = '/statistics';
  static const String reports = '/reports';
  static const String notificationSettings = '/notifications/settings';
  static const String supportCreate = '/support/new';
  static const String changePassword = '/account/change-password';

  /// Build a typed path for the device-detail screen. Kept outside the
  /// bottom-nav shell so it has full-screen real estate and a normal back
  /// button — same pattern as [profile].
  static String deviceDetail(int id) => '/devices/$id';

  /// Build a typed path for a single support case (mail thread or
  /// ticket). `kind` is always `'message'` or `'ticket'`, taken from the
  /// case summary, never user-typed.
  static String supportCase(String kind, int id) => '/support/$kind/$id';
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
        // v54: allow /register alongside /login while unauthenticated
        // so a new user can self-register without being bounced back
        // to the login screen.
        if (loc == AppRoutes.login || loc == AppRoutes.register) {
          return null;
        }
        return AppRoutes.login;
      }
      // authenticated — v53: first-run subscribers (whose backend
      // onboarding state is still incomplete) are routed into
      // /onboarding instead of /home. Subscribers who already
      // completed onboarding never see this redirect because their
      // AuthUser.onboardingCompleted flag is true.
      final user = session.user;
      final needsOnboarding =
          user != null && !user.isAdmin && !user.onboardingCompleted;

      if (needsOnboarding) {
        // Allow profile + change-password mid-flow so the user can
        // satisfy the "complete profile" stage without being bounced
        // back to the onboarding root immediately.
        final allowedDuringOnboarding = <String>{
          AppRoutes.onboarding,
          AppRoutes.profile,
          AppRoutes.changePassword,
        };
        if (!allowedDuringOnboarding.contains(loc)) {
          return AppRoutes.onboarding;
        }
        return null;
      }

      if (loc == AppRoutes.splash ||
          loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.onboarding) {
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
      // v54: subscriber self-registration. Reachable only while the
      // session is unauthenticated — the redirect above bounces an
      // already-signed-in user back to /home if they hit /register
      // directly (e.g. from a deep link).
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      // v53: first-run onboarding for subscriber users. The redirect
      // above gates entry — this route is only reachable when the
      // session is authenticated and onboarding is not yet complete.
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
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
      // v51: account + subscription overview — read-only, opened from More.
      GoRoute(
        path: AppRoutes.account,
        builder: (_, _) => const AccountScreen(),
      ),
      // v89: change-password screen.
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      // v55: app settings/info — read-only, opened from More.
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const AppSettingsScreen(),
      ),
      // v57: subscriber statistics — minimal screen consuming the v56
      // backend endpoint. Outside the bottom-nav shell so the user
      // gets a normal back arrow to wherever they came from (More tab,
      // device detail, etc.).
      GoRoute(
        path: AppRoutes.statistics,
        builder: (_, _) => const StatisticsScreen(),
      ),
      // v57: subscriber reports — honest placeholder. PDF / CSV
      // export and self-sufficiency / share derivations live on the
      // web today; this screen is the mobile section anchor so the
      // navigation feels complete.
      GoRoute(
        path: AppRoutes.reports,
        builder: (_, _) => const ReportsScreen(),
      ),
      // v87: notification settings editor (master + channels + per-section
      // toggles). Opened from the Notifications screen AppBar.
      GoRoute(
        path: AppRoutes.notificationSettings,
        builder: (_, _) => const NotificationSettingsScreen(),
      ),
      // v50: support case detail (read-only thread). Kept outside the
      // bottom-nav shell so a back arrow returns to the support list.
      GoRoute(
        path: '/support/:kind/:id',
        builder: (_, state) {
          final kind = state.pathParameters['kind'] ?? '';
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return SupportCaseDetailScreen(kind: kind, id: id);
        },
      ),
      // v88: new support case (subject + body + priority + kind). Lives
      // outside the shell so the form has full-screen real estate.
      GoRoute(
        path: AppRoutes.supportCreate,
        builder: (_, _) => const SupportCreateCaseScreen(),
      ),
      // v63: support list — moved out of the bottom-nav shell. Reached
      // from the "الدعم" tile in More via `context.push(...)`, which
      // gives the screen a back-arrow AppBar instead of the bottom-nav
      // shell. The bottom-nav slot it used to occupy now hosts Weather.
      GoRoute(
        path: AppRoutes.support,
        builder: (_, _) => const SupportScreen(),
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
          // v63: Weather tab — backed by the v62
          // `/api/v1/devices/<id>/weather` endpoint.
          GoRoute(
            path: AppRoutes.weather,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: WeatherScreen()),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: NotificationsScreen()),
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
