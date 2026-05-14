import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../app/app_theme.dart';
import '../../features/notifications/state/notifications_controller.dart';
import 'push_service.dart';

/// v101 Phase D — wraps the app's `MaterialApp.router` `builder:` so
/// every screen automatically gets:
///
///   1. An in-app banner overlay that appears when a push arrives in
///      the foreground (Android FCM does not draw the system tray
///      for foreground messages by default; this fills the gap).
///   2. A side-effect listener that consumes
///      [pushTapStreamProvider] events and routes the user to the
///      screen named in the push's `data.route` payload.
///
/// Both behaviours are passive — they sit between `MaterialApp.router`
/// and the actual page tree without affecting layout.
///
/// Implementation note: an earlier draft used `ScaffoldMessenger` +
/// `SnackBar`. That was unreliable inside the nested-messenger setup
/// (`MaterialApp.router` already creates one; ours wrapping it on top
/// caused the `duration` to be ignored and the snackbar to stay on
/// screen until the app was killed). The current implementation
/// drives an [OverlayEntry] with an explicit [Timer] so the dismiss
/// is fully deterministic regardless of any messenger nesting.
class PushOverlay extends ConsumerStatefulWidget {
  const PushOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushOverlay> createState() => _PushOverlayState();
}

class _PushOverlayState extends ConsumerState<PushOverlay> {
  /// Used to find the nearest Overlay above us so the banner floats
  /// above the routed page tree without depending on a Scaffold.
  final GlobalKey _overlayHostKey = GlobalKey();

  OverlayEntry? _entry;
  Timer? _autoDismiss;

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _autoDismiss = null;
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Banner: surface foreground messages as a tappable overlay.
    // Also nudges the Notifications inbox controller so the new
    // event appears in the list immediately instead of waiting up
    // to 60 s for the next silent poll.
    ref.listen<AsyncValue<PushBanner>>(pushBannerStreamProvider, (prev, next) {
      next.whenOrNull(data: (banner) {
        _showBanner(banner);
        _refreshNotificationsInbox();
      });
    });

    // Tap handling: route to the screen named in `data['route']`,
    // falling back to the in-app notifications inbox when the payload
    // doesn't carry a hint. A tap also nudges the inbox so the new
    // event is fresh by the time the user lands on the Notifications
    // tab (the natural fallback destination).
    ref.listen<AsyncValue<Map<String, String>>>(
      pushTapStreamProvider,
      (prev, next) {
        next.whenOrNull(data: (data) {
          _routeForTap(data);
          _refreshNotificationsInbox();
        });
      },
    );

    // KeyedSubtree gives us a stable ancestor for the Overlay lookup
    // so the banner's OverlayEntry has somewhere to render.
    return KeyedSubtree(key: _overlayHostKey, child: widget.child);
  }

  /// Tells the notifications inbox controller to silent-refresh from
  /// the backend. Called whenever a push arrives or is tapped so the
  /// inbox doesn't lag behind the system tray. Best-effort — if the
  /// controller hasn't been mounted yet (e.g. the user has never
  /// opened the Notifications tab) the call is a no-op via the
  /// provider's lazy semantics.
  void _refreshNotificationsInbox() {
    try {
      ref.read(notificationsControllerProvider.notifier).silentRefresh();
    } catch (_) {
      // Controller may not exist yet; not an error.
    }
  }

  void _showBanner(PushBanner banner) {
    final ctx = _overlayHostKey.currentContext;
    if (ctx == null || !mounted) return;
    final overlay = Overlay.maybeOf(ctx, rootOverlay: true);
    if (overlay == null) return;

    // Tear down any banner currently on screen so a new push always
    // wins, instead of stacking on top of the previous one.
    _autoDismiss?.cancel();
    _entry?.remove();
    _entry = null;

    final entry = OverlayEntry(
      builder: (_) => _BannerWidget(
        banner: banner,
        onTap: () {
          _dismissBanner();
          _routeForTap(banner.data);
        },
        onClose: _dismissBanner,
      ),
    );
    overlay.insert(entry);
    _entry = entry;
    _autoDismiss = Timer(const Duration(seconds: 5), _dismissBanner);
  }

  void _dismissBanner() {
    _autoDismiss?.cancel();
    _autoDismiss = null;
    _entry?.remove();
    _entry = null;
  }

  void _routeForTap(Map<String, String> data) {
    final route = _resolveRoute(data);
    if (route == null) return;
    final navContext = _overlayHostKey.currentContext;
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

/// The visible banner widget. Slides down from the top, dismissable
/// by tap, by the explicit close button, or automatically after the
/// parent's 5-second timer.
class _BannerWidget extends StatefulWidget {
  const _BannerWidget({
    required this.banner,
    required this.onTap,
    required this.onClose,
  });

  final PushBanner banner;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.2),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ac, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Positioned(
      top: mq.padding.top + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [AppTheme.indigoPrimary, AppTheme.indigoBright],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  boxShadow: AppTheme.liftedShadow,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.banner.title.isNotEmpty)
                            Text(
                              widget.banner.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (widget.banner.body.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.banner.body,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'إغلاق',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
