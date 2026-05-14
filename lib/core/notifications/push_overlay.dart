import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../app/app_theme.dart';
import 'push_service.dart';

/// v101 Phase D — wraps the app's `MaterialApp.router` `builder:` so
/// every screen automatically gets:
///
///   1. A SnackBar that appears when a push arrives in the foreground
///      (Android FCM does not draw the system tray for foreground
///      messages by default; this fills the gap).
///   2. A side-effect listener that consumes
///      [pushTapStreamProvider] events and routes the user to the
///      screen named in the push's `data.route` payload.
///
/// Both behaviours are passive — they sit between `MaterialApp.router`
/// and the actual page tree without affecting layout.
class PushOverlay extends ConsumerStatefulWidget {
  const PushOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushOverlay> createState() => _PushOverlayState();
}

class _PushOverlayState extends ConsumerState<PushOverlay> {
  /// Used to show the SnackBar without a BuildContext that descends
  /// from a Scaffold — every routed screen has its own Scaffold so
  /// `ScaffoldMessenger.of(context)` resolves to the closest one.
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    // Banner: surface foreground messages as a tappable SnackBar.
    ref.listen<AsyncValue<PushBanner>>(pushBannerStreamProvider, (prev, next) {
      next.whenOrNull(data: _showBannerSnack);
    });

    // Tap handling: route to the screen named in `data['route']`,
    // falling back to the in-app notifications inbox when the payload
    // doesn't carry a hint.
    ref.listen<AsyncValue<Map<String, String>>>(
      pushTapStreamProvider,
      (prev, next) {
        next.whenOrNull(data: _routeForTap);
      },
    );

    return ScaffoldMessenger(
      key: _messengerKey,
      child: widget.child,
    );
  }

  void _showBannerSnack(PushBanner banner) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.indigoPrimary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        duration: const Duration(seconds: 5),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (banner.title.isNotEmpty)
              Text(
                banner.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (banner.body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                banner.body,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        action: SnackBarAction(
          label: 'فتح',
          textColor: Colors.white,
          onPressed: () => _routeForTap(banner.data),
        ),
      ),
    );
  }

  void _routeForTap(Map<String, String> data) {
    final route = _resolveRoute(data);
    if (route == null) return;
    final navContext = _messengerKey.currentContext;
    if (navContext == null || !mounted) return;
    // Use go() rather than push(): from a tap we want the destination
    // to *replace* whatever ephemeral screen the user was on (e.g.,
    // a half-open BottomSheet doesn't make sense as a back-target).
    GoRouter.of(navContext).go(route);
  }

  /// Map FCM `data` payload to a router path.
  ///
  /// The backend dispatcher attaches an `event_type` field to every
  /// push (see `app/services/push_dispatch.py` + the call site in
  /// `app/blueprints/notifications.py`). We translate the small set
  /// of types we currently emit into the natural destination screen.
  /// Unknown types fall back to the notifications inbox so the user
  /// still has somewhere meaningful to land.
  String? _resolveRoute(Map<String, String> data) {
    if (data.isEmpty) return AppRoutes.notifications;
    final explicit = data['route'];
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final eventType = data['event_type'];
    switch (eventType) {
      case 'battery_status':
      case 'night_discharge':
        return AppRoutes.batteryLab;
      case 'solar_status':
      case 'weather_alert':
        return AppRoutes.weather;
      case 'load_alert':
        return AppRoutes.loads;
      default:
        return AppRoutes.notifications;
    }
  }
}
