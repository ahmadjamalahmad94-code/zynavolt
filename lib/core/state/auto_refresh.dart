import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// v101 — App-wide auto-refresh foundation.
///
/// Purpose
/// -------
/// Before v101, every live screen (Home / Battery Lab / Devices) only
/// updated when the user dragged the list down. Owner feedback was that
/// the Home screen in particular felt stale because the readings sit on
/// a 30-second backend cadence but the mobile UI never re-fetched on
/// its own.
///
/// This file provides two pieces:
///
///   1. [appLifecycleProvider] — a [StateProvider] that exposes the
///      current [AppLifecycleState]. Watched (or listened to) by any
///      widget that needs to react to foreground / background.
///   2. [AutoRefreshScope] — a drop-in wrapper that owns a periodic
///      [Timer], invalidates a list of Riverpod providers on each tick,
///      pauses while the app is backgrounded, and refreshes immediately
///      on resume if the previous tick is older than [interval].
///
/// The owner explicitly chose conservative cadences in the v101 plan
/// (Home / Battery 30s; Devices / Notifications 60s) — they are NOT
/// hard-coded here, every screen passes its own.
///
/// The shared lifecycle observer is mounted once from
/// `solar_deye_app.dart` via [appLifecycleObserverProvider]. Screens
/// only need to wrap their body in [AutoRefreshScope].

/// Currently observed lifecycle state. Defaults to `resumed` because
/// the app is in the foreground when this provider is first read.
final appLifecycleProvider = StateProvider<AppLifecycleState>((ref) {
  return AppLifecycleState.resumed;
});

class _AppLifecycleObserver with WidgetsBindingObserver {
  _AppLifecycleObserver(this._ref);

  final Ref _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ref.read(appLifecycleProvider.notifier).state = state;
  }
}

/// Side-effecting provider that mounts a single [WidgetsBindingObserver]
/// for the lifetime of the app. `solar_deye_app.dart` `ref.watch`es
/// this so the observer is registered before any screen needs it.
///
/// Returns `void` — the value is never used; only the side effect of
/// `addObserver` matters.
final appLifecycleObserverProvider = Provider<void>((ref) {
  final observer = _AppLifecycleObserver(ref);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
  });
});

/// Wraps a screen body and silently re-invalidates [targets] every
/// [interval] while the app is in the foreground.
///
/// Usage:
/// ```dart
/// AutoRefreshScope(
///   targets: const [dashboardProvider, insightsProvider],
///   interval: const Duration(seconds: 30),
///   child: _HomeBody(),
/// )
/// ```
///
/// Behaviour:
/// * Starts the timer in `initState`.
/// * Invalidates each provider on every tick — Riverpod re-fetches via
///   the provider's own factory (no manual `await ref.read(...future)`
///   needed; the screen's `ref.watch` rebuilds when fresh data lands).
/// * Listens to [appLifecycleProvider] and cancels the timer on
///   `paused` / `inactive` / `hidden`. When the app resumes, if the
///   last successful tick was longer ago than [interval], it fires an
///   immediate tick before restarting the periodic timer.
/// * Cancels the timer in `dispose` so navigating away is clean.
///
/// This is for "passive" screens that are happy to flicker briefly on
/// re-fetch (the spinner is hidden by [RefreshIndicator] / cached data
/// patterns elsewhere). Screens that need a flicker-free silent refresh
/// (e.g. the Notifications inbox with its custom `silentRefresh` on
/// the controller) should listen to [appLifecycleProvider] directly
/// instead of using this wrapper.
class AutoRefreshScope extends ConsumerStatefulWidget {
  const AutoRefreshScope({
    super.key,
    required this.targets,
    required this.interval,
    required this.child,
  });

  /// Providers to invalidate on each tick. Each entry is anything that
  /// `ref.invalidate` accepts: a `Provider`, `FutureProvider`, family
  /// instance, etc.
  final List<ProviderOrFamily> targets;

  /// Cadence between ticks. Owner-chosen per screen — see
  /// `PROJECT_RULES.md` §13 for the canonical table.
  final Duration interval;

  final Widget child;

  @override
  ConsumerState<AutoRefreshScope> createState() => _AutoRefreshScopeState();
}

class _AutoRefreshScopeState extends ConsumerState<AutoRefreshScope> {
  Timer? _timer;
  DateTime _lastTick = DateTime.now();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant AutoRefreshScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interval != widget.interval) {
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    for (final target in widget.targets) {
      ref.invalidate(target);
    }
    _lastTick = DateTime.now();
  }

  void _onResume() {
    final stale = DateTime.now().difference(_lastTick) >= widget.interval;
    if (stale) _tick();
    if (_timer == null) _start();
  }

  void _onPause() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppLifecycleState>(appLifecycleProvider, (previous, next) {
      switch (next) {
        case AppLifecycleState.resumed:
          _onResume();
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
        case AppLifecycleState.hidden:
        case AppLifecycleState.detached:
          _onPause();
      }
    });
    return widget.child;
  }
}
