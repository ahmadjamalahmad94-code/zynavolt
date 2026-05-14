import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/state/app_session.dart';
import '../../../core/state/auto_refresh.dart';
import '../../../core/utils/backend_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../auth/data/auth_models.dart';
import '../../charts/data/energy_chart_repository.dart';
import '../../charts/presentation/home_energy_chart_card.dart';
import '../../dashboard/data/dashboard_models.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../devices/data/device_models.dart';
import '../../devices/state/selected_device_provider.dart';
import '../../insights/data/insights_repository.dart';
import '../../insights/presentation/insights_card.dart';
import '../../statistics/data/statistics_repository.dart';

// The Zynavolt logo lives at `assets/branding/zynavolt_logo.png`. Both
// `_BrandWordmark` and `_HubBadge` consume it via `Image.asset(...,
// errorBuilder:)` so the screen still renders cleanly with a text "Z"
// fallback when the asset is missing during dev.
const String _kBrandLogoPath = 'assets/branding/zynavolt_logo.png';

/// Home tab — premium read-only Zynavolt dashboard.
///
/// Every numeric / text value comes verbatim from the existing
/// `dashboardProvider` payload (`cards.*` / `latest.*` / `device.*`).
/// The Flutter layer only formats and lays out — it never derives,
/// recomputes, or interprets signs as business labels (no "charging"
/// / "exporting" / "saving" claims). No charts. No animated power-flow
/// graph. The "Energy Flow" card is a static decorative diagram.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // v46: Home has no AppBar — the gradient hero card *is* the page
    // header. Status bar icons forced dark via AnnotatedRegion since the
    // gradient backdrop is pale-indigo (light).
    // v101 — Home auto-refreshes every 30 s. Pulls fresh dashboard,
    // insights, and chart series in lockstep so the mid-screen split
    // tiles don't drift out of sync with the hero / energy chart.
    // The scope pauses on background and refreshes immediately on
    // resume if the data is stale (see AutoRefreshScope docs).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AutoRefreshScope(
          interval: const Duration(seconds: 30),
          targets: [
            dashboardProvider,
            insightsProvider,
            statisticsProvider,
            energyChartSeriesProvider,
          ],
          child: const _ScreenBackground(child: _HomeBody()),
        ),
      ),
    );
  }
}

/// Decorative full-screen vertical gradient that gives Home a calm
/// indigo-tinted "energy app" feel without painting anywhere else in
/// the app.
class _ScreenBackground extends StatelessWidget {
  const _ScreenBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE0E7FF), // pale indigo
            Color(0xFFF1F5FF),
            Color(0xFFF8FAFC), // soft bg
          ],
          stops: [0.0, 0.35, 0.85],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final activeDevice = ref.watch(effectiveDeviceProvider);
    final activeDeviceId = ref.watch(effectiveDeviceIdProvider);
    final dashboard = ref.watch(dashboardProvider);

    return RefreshIndicator(
      color: AppTheme.indigoPrimary,
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        // v75: also refresh the insights card so pull-to-refresh
        // updates the "what should I do right now?" guidance
        // alongside the live cards.
        ref.invalidate(insightsProvider);
        // v77: invalidate the advanced energy chart's underlying
        // statistics + derived series so the curve and the period
        // split bars also re-fetch on pull-to-refresh. We invalidate
        // both layers because the chart provider memoizes on its
        // own EnergyChartQuery key.
        ref.invalidate(statisticsProvider);
        ref.invalidate(energyChartSeriesProvider);
        await ref.read(dashboardProvider.future);
      },
      child: ListView(
        // v46: no AppBar above, SafeArea already accounts for the status
        // bar — just a small 12 dp breathing margin before the hero.
        // v62: bump bottom padding so the last card has room to breathe
        // above the home-indicator gesture area on tall phones.
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          _HomeHero(
            user: session.user,
            device: activeDevice,
            snapshot: dashboard.valueOrNull,
            onRefresh: () {
              ref.invalidate(dashboardProvider);
              // v75: pair the hero refresh button with the
              // insights provider so the user sees both fresh.
              ref.invalidate(insightsProvider);
              // v77: also refresh the advanced energy chart layers so
              // tapping the hero refresh button feels consistent with
              // pull-to-refresh.
              ref.invalidate(statisticsProvider);
              ref.invalidate(energyChartSeriesProvider);
            },
          ),
          const SizedBox(height: 12),
          if (activeDeviceId == null)
            const _NoDeviceState()
          else
            dashboard.when(
              loading: _LoadingBlock.new,
              error: (err, _) => _ErrorBlock(
                error: err is ApiException
                    ? err
                    : ApiException(
                        message: 'تعذّر تحميل بيانات اللوحة.',
                        kind: ApiErrorKind.unknown,
                      ),
                onRetry: () => ref.invalidate(dashboardProvider),
              ),
              data: (snapshot) => _DashboardBody(snapshot: snapshot),
            ),
        ],
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.user,
    required this.device,
    required this.snapshot,
    required this.onRefresh,
  });

  final AuthUser? user;
  final Device? device;
  final DashboardSnapshot? snapshot;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final greetingName = u == null
        ? ''
        : (u.fullName.isNotEmpty ? u.fullName : u.username);
    // v97: route through the shared UTC-aware parser in
    // `core/utils/backend_time.dart`. Previously this used a naive
    // substring of the ISO string, which displayed the backend's
    // UTC wall-clock as if it were local time — three hours behind
    // for users in Asia/Hebron during summer.
    final lastReading = formatBackendHm(snapshot?.latest.createdAt);
    final deviceName = device == null
        ? null
        : (device!.name.isNotEmpty ? device!.name : '#${device!.id}');
    // v85: surface today's production directly in the hero so the hero
    // becomes more than a name + greeting. Value is server-computed
    // (cards.daily_production_kwh) — no client-side derivation.
    final daily = snapshot?.cards.dailyProductionKwh ?? 0;
    final dailyText = daily > 0 ? '${_fmtKwh(daily)} kWh اليوم' : null;

    // v99b — exact-replica hero per the owner's reference design:
    //   * deep night-sky gradient (#0E1A2E → #1B2C4A) instead of
    //     the previous indigo gradient
    //   * sun + tilted solar-panel illustration anchored on the LEFT
    //     drawn via CustomPaint so we don't need an image asset
    //   * top row: refresh circle button on the LEFT, "ZYNAVOLT" mark
    //     on the RIGHT (mirrors the design, which is RTL-aware)
    //   * centred greeting with a wave 👋 emoji, three pills stacked
    //     in the right column (kWh today / device / last reading)
    // v99d — Hero collapsed to a tight 2-row layout that's ~40 % shorter
    // than v99c. Row 1 carries the brand chrome (refresh + greeting +
    // wordmark on a single line); Row 2 holds the pills inline. The
    // sun illustration sits behind everything as glass-tinted backdrop
    // art. Multi-layer shadows + a subtle top highlight give the card
    // genuine 3-D depth instead of the previous flat slab.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          // Close shadow — defines the card edge
          BoxShadow(
            color: const Color(0xFF0E1A2E).withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          // Diffuse ambient — gives the floating-glass feel
          BoxShadow(
            color: const Color(0xFF1B2C4A).withValues(alpha: 0.22),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF1B2C4A), Color(0xFF152340), Color(0xFF0E1A2E)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Sun + solar-panel illustration anchored on the LEFT,
              // softly faded so it's an atmospheric backdrop, not the
              // visual focal point.
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 150,
                child: Opacity(
                  opacity: 0.85,
                  child: CustomPaint(painter: _SunPanelsPainter()),
                ),
              ),
              // Top-edge specular highlight — fakes the look of glass
              // catching the light at the upper rim of the card.
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
                        Colors.white.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Row 1: refresh · greeting · brand on ONE line so
                    // the hero stays low-profile.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _HeroIconButton(
                          icon: Icons.refresh,
                          tooltip: 'تحديث',
                          onPressed: onRefresh,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            greetingName.isNotEmpty
                                ? 'مرحبًا، $greetingName 👋'
                                : 'مرحبًا بعودتك 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const _BrandWordmark(),
                      ],
                    ),
                    const SizedBox(height: 9),
                    // Row 2: pills inline, wrapping only when necessary.
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        if (dailyText != null)
                          _HeroPill(
                            icon: Icons.wb_sunny_outlined,
                            text: dailyText,
                          ),
                        _HeroPill(
                          icon: Icons.person_outline,
                          text: deviceName ?? 'لم يتم اختيار جهاز',
                        ),
                        if (lastReading != null)
                          _HeroPill(
                            icon: Icons.schedule_outlined,
                            text: 'آخر قراءة $lastReading',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// v99b — Hand-painted sun + solar panels for the hero illustration.
/// Drawn with `CustomPaint` so the home screen doesn't depend on a
/// raster asset and the colours track the dark hero gradient.
class _SunPanelsPainter extends CustomPainter {
  const _SunPanelsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sun — soft glow + warm core in the upper-right of the painter
    // box, so it sits visually between the panels and the rising
    // brand wordmark.
    final sunCenter = Offset(w * 0.78, h * 0.36);
    final sunRadius = h * 0.18;

    // Outer halo
    final halo = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFC766).withValues(alpha: 0.45),
              const Color(0xFFFFC766).withValues(alpha: 0.00),
            ],
          ).createShader(
            Rect.fromCircle(center: sunCenter, radius: sunRadius * 2.4),
          );
    canvas.drawCircle(sunCenter, sunRadius * 2.4, halo);

    // Sun core (warm yellow / amber gradient)
    final sun = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFE5A6), const Color(0xFFFFB347)],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));
    canvas.drawCircle(sunCenter, sunRadius, sun);

    // Solar panels — two tilted rounded rectangles in the lower half,
    // tinted with subtle grid lines. We draw with a transform to
    // achieve the perspective tilt without trigonometry headaches.
    canvas.save();
    canvas.translate(w * 0.30, h * 0.62);
    canvas.transform(_skewMatrix(skewX: -0.35, skewY: 0.18).storage);

    final panelBase = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3B5A8C), Color(0xFF24385F)],
      ).createShader(const Rect.fromLTWH(0, 0, 130, 60));
    final panelBorder = Paint()
      ..color = const Color(0xFF6B86B5).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final cellLine = Paint()
      ..color = const Color(0xFF6B86B5).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // First (rear) panel
    final p1 = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-10, -36, 130, 60),
      const Radius.circular(6),
    );
    canvas.drawRRect(p1, panelBase);
    canvas.drawRRect(p1, panelBorder);
    // Cell grid for p1
    for (var i = 1; i < 4; i++) {
      final x = -10 + (130.0 * i / 4);
      canvas.drawLine(Offset(x, -36), Offset(x, 24), cellLine);
    }
    canvas.drawLine(const Offset(-10, -6), const Offset(120, -6), cellLine);

    // Second (front) panel slightly lower
    final p2 = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-22, 14, 138, 56),
      const Radius.circular(6),
    );
    canvas.drawRRect(p2, panelBase);
    canvas.drawRRect(p2, panelBorder);
    for (var i = 1; i < 4; i++) {
      final x = -22 + (138.0 * i / 4);
      canvas.drawLine(Offset(x, 14), Offset(x, 70), cellLine);
    }
    canvas.drawLine(const Offset(-22, 42), const Offset(116, 42), cellLine);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SunPanelsPainter oldDelegate) => false;
}

/// Helper for `Canvas.transform` — Flutter's API wants a flat
/// `Float64List` of 16 doubles representing a 4×4 column-major
/// matrix. This builds an X/Y skew transform.
Matrix4 _skewMatrix({required double skewX, required double skewY}) {
  return Matrix4.identity()
    ..setEntry(0, 1, skewX)
    ..setEntry(1, 0, skewY);
}

class _BrandWordmark extends StatelessWidget {
  const _BrandWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            _kBrandLogoPath,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Z',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'ZYNAVOLT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
          ),
        ),
      ],
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, color: Colors.white, size: 16),
          ),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top-level edge states ───────────────────────────────────────────────

class _NoDeviceState extends StatelessWidget {
  const _NoDeviceState();

  @override
  Widget build(BuildContext context) {
    // v62: elevate the state cards so they have the same presence as the
    // hero + flow board above. Uses the v58 design-system softShadow.
    return const AppCard(
      elevated: true,
      padding: EdgeInsets.symmetric(vertical: 28),
      child: AppEmptyState(
        icon: Icons.solar_power_outlined,
        title: 'لم يتم اختيار جهاز بعد',
        subtitle: 'اختر جهازاً من تبويب الأجهزة لعرض بيانات الطاقة.',
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      elevated: true,
      padding: EdgeInsets.symmetric(vertical: 36),
      child: AppLoading(message: 'جارٍ تحميل بيانات الجهاز...'),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error, required this.onRetry});
  final ApiException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: AppErrorState(error: error, onRetry: onRetry),
    );
  }
}

// ─── Dashboard body ─────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.snapshot});
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cards = snapshot.cards;
    final children = <Widget>[];

    if (snapshot.scope.isAllDevices) {
      children.add(
        const _ScopeNotice(
          text:
              'هذه البيانات من ملخص النظام المتاح حالياً، وليست لجهاز واحد بعينه.',
        ),
      );
      children.add(const SizedBox(height: 10));
    }

    if (snapshot.empty) {
      children.add(
        const AppCard(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'لا توجد قراءة متاحة لهذا الجهاز بعد',
            subtitle:
                'سيظهر آخر تحديث هنا فور وصوله من الخادم — لا حسابات داخل التطبيق.',
          ),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    // v99b — the standalone _StatusBanner is gone; its content
    // ("حالة النظام · متصل بالشبكة") now lives in the header of
    // _EnergyFlowCard per the reference design. The card receives
    // the status text directly via `snapshot.latest.statusText`.

    children.addAll([
      _EnergyFlowCard(snapshot: snapshot),
      const SizedBox(height: 12),
      _BatteryCard(cards: cards),
      const SizedBox(height: 12),
      _ProductionCard(cards: cards),
      const SizedBox(height: 12),
      // v75: smart insights card. Consumes `insightsProvider` which
      // is already device-scoped via `effectiveDeviceIdProvider`, so
      // it stays in sync with the live cards above without an extra
      // device hop. The card self-handles loading / unavailable /
      // error so we don't gate it on the dashboard's AsyncValue.
      const InsightsHomeCard(),
      const SizedBox(height: 12),
      // v77: advanced energy visualization (power curve + period
      // split). Self-contained scope/anchor state lives inside the
      // card so refreshing Home doesn't reset the user's selection.
      // The card reuses the v56 statistics endpoint via
      // `energyChartSeriesProvider` — no new backend path.
      const HomeEnergyChartCard(),
      const SizedBox(height: 12),
      _FooterMetaChip(snapshot: snapshot),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

// v99b — `_StatusBanner` deleted. Its content ("حالة النظام · متصل
// بالشبكة") is now part of `_FlowCardHeader` inside `_EnergyFlowCard`,
// matching the reference design where the status indicator sits at
// the top of the same card as the flow graph itself.

class _ScopeNotice extends StatelessWidget {
  const _ScopeNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.indigoSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppTheme.indigoPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.softInk,
                fontSize: 12,
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

// ─── Animated Energy Flow Card ──────────────────────────────────────────

/// "تدفق الطاقة الآن" — animated mobile-only flow card with four corner
/// node cards around a central inverter hub. L-shaped dashed connector
/// lines flow toward the hub when their node is *active* (non-zero
/// reading). When inactive they render as a thin static grey line.
///
/// This is **not** the web Flow Graph and shares no code with it. The four
/// numeric values are rendered verbatim from the existing `cards` payload
/// — no surplus, day/night, or direction logic in Flutter. "Active" simply
/// means "this reading has activity worth highlighting" — a UI signal,
/// not a semantic claim.
class _EnergyFlowCard extends StatefulWidget {
  const _EnergyFlowCard({required this.snapshot});
  final DashboardSnapshot snapshot;

  @override
  State<_EnergyFlowCard> createState() => _EnergyFlowCardState();
}

class _EnergyFlowCardState extends State<_EnergyFlowCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Single shared ticker — only the painter rebuilds per frame.
    // 1.5 s per dash cycle gives a calm, steady "energy is moving" feel
    // without drawing the eye away from the values.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.snapshot.cards;
    final flags = _FlowActivity.fromCards(cards);
    // v49: per-connector motion modes — see `_FlowMotion.fromCards` for
    // the exact direction rules (towardHub for solar, awayFromHub for
    // home, pulse for battery/grid because no direction field exists in
    // the backend payload).
    final motion = _FlowMotion.fromCards(cards);

    // v99b — header now matches the reference design: the system
    // status text + green dot live on the right of the card,
    // a small chart-style icon on the left. The "تدفق الطاقة الآن"
    // subtitle is gone — the visual flow speaks for itself.
    final statusText = widget.snapshot.latest.statusText;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppTheme.radiusGlass),
        border: Border.all(color: AppTheme.line),
        boxShadow: [
          BoxShadow(
            color: AppTheme.indigoPrimary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FlowCardHeader(statusText: statusText),
          const SizedBox(height: 10),
          // _FlowDiagram self-sizes from the virtual canvas aspect
          // (1000 × 840), so no explicit AspectRatio wrapper is needed.
          _FlowDiagram(
            cards: cards,
            flags: flags,
            motion: motion,
            animation: _controller,
          ),
        ],
      ),
    );
  }
}

/// v99b — flow-card header matching the reference design.
/// Right side carries the "حالة النظام" title with the status text
/// + a breathing green dot underneath; left side renders a small
/// chart-style glyph in an indigo-tinted square.
class _FlowCardHeader extends StatelessWidget {
  const _FlowCardHeader({required this.statusText});
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final hasStatus = statusText.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: small line-chart icon in a tinted square.
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.indigoSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.indigoPrimary.withValues(alpha: 0.18),
              width: 0.8,
            ),
          ),
          child: const Icon(
            Icons.timeline_outlined,
            color: AppTheme.indigoPrimary,
            size: 17,
          ),
        ),
        const Spacer(),
        // Right: stacked "حالة النظام" + status text with dot.
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'حالة النظام',
              style: TextStyle(
                color: AppTheme.faintMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasStatus ? statusText : 'لا توجد قراءة',
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasStatus ? AppTheme.success : AppTheme.faintMuted,
                    boxShadow: hasStatus
                        ? [
                            BoxShadow(
                              color: AppTheme.success.withValues(alpha: 0.45),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Coarse activity flags for each connector. Decorative only — never
/// claims direction, never claims charging/discharging/exporting.
class _FlowActivity {
  const _FlowActivity({
    required this.solar,
    required this.home,
    required this.battery,
    required this.grid,
    required this.generator,
  });

  factory _FlowActivity.fromCards(DashboardCards c) => _FlowActivity(
    solar: c.solarPowerW > 0,
    home: c.homeLoadW > 0,
    battery: c.batterySocPercent > 0 || c.batteryPowerW.abs() > 0,
    grid: c.gridPowerW.abs() > 0,
    // v93r — generator card lights up when AC-IN > 5 W (real
    // measurement or station-tier inference). Below that, the
    // card stays muted so a stray watt of noise doesn't flicker.
    generator: c.generatorPowerW > 5,
  );

  final bool solar;
  final bool home;
  final bool battery;
  final bool grid;
  final bool generator;

  /// Order: [solar, grid, battery, home, generator] — matches the
  /// painter's connector order from `_BoardSpec.connectors`.
  List<bool> get asList => [solar, grid, battery, home, generator];
}

// ─── Connector motion ────────────────────────────────────────────────────
//
// v49: the connector animation no longer paints a one-way scroll on every
// active line. Energy direction is only animated when we can derive it
// safely from the backend payload. For everything else the connector
// "pulses in place" so the screen never implies a wrong direction.
//
//   none        — line is inactive (no power on this connector); thin
//                 muted static line; no motion.
//   pulse       — line is active but direction is uncertain; line breathes
//                 (opacity oscillates with the animation phase) so the
//                 user sees activity without an apparent travel direction.
//   towardHub   — dashes scroll from the node toward the central hub
//                 (e.g. solar production feeding the inverter).
//   awayFromHub — dashes scroll from the hub toward the node (e.g. home
//                 load being served by the inverter).
//
// Direction rules (verified against backend payload, not assumed):
//   solar   →  towardHub  when solar_power_w > 0
//              (solar production canonically feeds the inverter)
//   home    →  awayFromHub when home_load_w > 0
//              (the home consumes from the inverter, never feeds it)
//   battery →  direction is derived from the *sign* of battery_power_w.
//              Sign convention verified in the backend Deye client at
//              `app/services/deye_client.py` lines 311-319, where the
//              normalised output is documented inline:
//                battery_power > 0  →  charging   (hub → battery)
//                battery_power < 0  →  discharging (battery → hub)
//                battery_power == 0 →  idle / standby (explicit 0)
//              `_mobile_reading_cards` in the backend passes this through
//              unchanged via `_reading_number()`, so the mobile receives
//              the same convention.
//                charging   → awayFromHub
//                discharging → towardHub
//                exactly 0 + SoC present → pulse (battery present, idle)
//                exactly 0 + no SoC      → none
//   grid    →  pulse when there is any activity — the mobile API exposes
//              grid_power_w but not a direction field, so import vs.
//              export is not safe to imply.
enum _FlowMotionMode { none, pulse, towardHub, awayFromHub }

class _FlowMotion {
  const _FlowMotion({
    required this.solar,
    required this.grid,
    required this.battery,
    required this.home,
    required this.generator,
  });

  factory _FlowMotion.fromCards(DashboardCards c) {
    // v49b: battery direction derived from the verified sign of
    // battery_power_w — see the enum block above for the source link.
    final batteryPower = c.batteryPowerW;
    final _FlowMotionMode batteryMode;
    if (batteryPower > 0) {
      batteryMode = _FlowMotionMode.awayFromHub; // charging: hub → battery
    } else if (batteryPower < 0) {
      batteryMode = _FlowMotionMode.towardHub; // discharging: battery → hub
    } else if (c.batterySocPercent > 0) {
      batteryMode = _FlowMotionMode.pulse; // present but idle
    } else {
      batteryMode = _FlowMotionMode.none;
    }

    return _FlowMotion(
      solar: c.solarPowerW > 0
          ? _FlowMotionMode.towardHub
          : _FlowMotionMode.none,
      home: c.homeLoadW > 0
          ? _FlowMotionMode.awayFromHub
          : _FlowMotionMode.none,
      battery: batteryMode,
      grid: c.gridPowerW.abs() > 0
          ? _FlowMotionMode.pulse
          : _FlowMotionMode.none,
      // v93r — generator/external AC-IN is unidirectional INTO the
      // hub (the inverter never sends power back out the AC-IN
      // port on a residential Deye hybrid).
      generator: c.generatorPowerW > 5
          ? _FlowMotionMode.towardHub
          : _FlowMotionMode.none,
    );
  }

  final _FlowMotionMode solar;
  final _FlowMotionMode grid;
  final _FlowMotionMode battery;
  final _FlowMotionMode home;
  final _FlowMotionMode generator;

  /// Order: [solar, grid, battery, home, generator] — matches
  /// `_BoardSpec.connectors`.
  List<_FlowMotionMode> get asList => [solar, grid, battery, home, generator];
}

// ─── Fixed-grid board spec ───────────────────────────────────────────────

/// 3×3 grid energy board.
///
/// One source of truth: cell column/row fractions of the board's actual
/// pixel size. Every Rect (cell, node, hub) is derived from these
/// fractions; both the node `Positioned` placements *and* the connector
/// painter call the same `nodeBounds(row, col, board)` helper, so they
/// cannot drift relative to each other.
///
/// Layout:
///   ┌───────┬───────┬───────┐
///   │ solar │  ·    │ grid  │
///   ├───────┼───────┼───────┤
///   │  ·    │  hub  │   ·   │
///   ├───────┼───────┼───────┤
///   │battery│  ·    │ home  │
///   └───────┴───────┴───────┘
class _BoardSpec {
  const _BoardSpec._();

  /// Board's aspect ratio (width / height). 1.10 keeps the board only
  /// slightly wider than tall — enough vertical room for content yet
  /// short enough to leave the next card visible in the first viewport.
  static const double aspect = 1.10;

  /// Column widths as fractions of board width. Outer columns are wider
  /// than the middle one so the corner nodes have enough horizontal space.
  static const List<double> _colFracs = [0.35, 0.30, 0.35];

  /// Row heights as fractions of board height. The middle row gets the
  /// extra 40 % to give the hub presence.
  static const List<double> _rowFracs = [0.30, 0.40, 0.30];

  /// Padding inside each cell — gives node cards some breathing room from
  /// the cell edges and creates a visible gap between adjacent cells.
  static const double cellInset = 5.0;

  /// Returns the Rect for cell (row, col) in board-pixel coordinates.
  static Rect cell(int row, int col, Size board) {
    var x = 0.0;
    for (var c = 0; c < col; c++) {
      x += _colFracs[c] * board.width;
    }
    var y = 0.0;
    for (var r = 0; r < row; r++) {
      y += _rowFracs[r] * board.height;
    }
    return Rect.fromLTWH(
      x,
      y,
      _colFracs[col] * board.width,
      _rowFracs[row] * board.height,
    );
  }

  /// Cell rect inset by [cellInset] on all sides — used to place the
  /// node card and to anchor connector endpoints.
  static Rect nodeBounds(int row, int col, Size board) =>
      cell(row, col, board).deflate(cellInset);

  // Cell (row, col) for each node — fixed coordinates, never recomputed.
  static const int solarRow = 0, solarCol = 0;
  static const int gridRow = 0, gridCol = 2;
  static const int hubRow = 1, hubCol = 1;
  static const int batteryRow = 2, batteryCol = 0;
  static const int homeRow = 2, homeCol = 2;
  // v93r — Generator sits in the top-middle cell, naturally between
  // Solar (top-left) and Grid (top-right). The cell was previously
  // empty in the 3×3 grid; placing the generator there does not
  // disturb any existing card position.
  static const int generatorRow = 0, generatorCol = 1;

  /// Connector anchor on the hub-facing vertical edge of a corner node.
  /// Returns either the right-mid or left-mid edge depending on which
  /// side the hub sits.
  static Offset cardAnchor(Rect nodeRect, Rect hubRect) {
    final onLeftOfHub = nodeRect.center.dx < hubRect.center.dx;
    return Offset(
      onLeftOfHub ? nodeRect.right : nodeRect.left,
      nodeRect.center.dy,
    );
  }

  /// Corner of the hub closest to a corner node.
  static Offset hubCornerFor(Rect nodeRect, Rect hubRect) {
    final x = nodeRect.center.dx < hubRect.center.dx
        ? hubRect.left
        : hubRect.right;
    final y = nodeRect.center.dy < hubRect.center.dy
        ? hubRect.top
        : hubRect.bottom;
    return Offset(x, y);
  }

  /// Smooth single-curve connector path from a corner node's edge anchor
  /// to the matching hub corner. Quadratic bezier with the control point
  /// at the natural L-bend → clean elegant arc, no rough seams.
  static Path _curve(Offset start, Offset end) {
    final control = Offset(end.dx, start.dy);
    return Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
  }

  /// v93r — vertical card anchor for nodes that sit ABOVE or BELOW
  /// the hub (column-aligned). Returns the bottom-mid or top-mid
  /// edge of the node card depending on its position relative to
  /// the hub. The generator (top-middle) needs this because the
  /// existing `cardAnchor` returns left/right-mid which would
  /// anchor the line on the wrong edge for a column-aligned card.
  static Offset cardAnchorVertical(Rect nodeRect, Rect hubRect) {
    final onAboveHub = nodeRect.center.dy < hubRect.center.dy;
    return Offset(
      nodeRect.center.dx,
      onAboveHub ? nodeRect.bottom : nodeRect.top,
    );
  }

  /// v93r — hub edge anchor for a column-aligned node (top-mid /
  /// bottom-mid of the hub instead of a corner). Used by the
  /// generator connector.
  static Offset hubVerticalEdgeFor(Rect nodeRect, Rect hubRect) {
    final y = nodeRect.center.dy < hubRect.center.dy
        ? hubRect.top
        : hubRect.bottom;
    return Offset(hubRect.center.dx, y);
  }

  /// All connector paths in board-pixel coordinates. Pure function
  /// of the board size — same math the placements use, so anchors
  /// line up exactly with the node cards.
  ///
  /// Order: [solar, grid, battery, home, generator]. The generator
  /// path is the vertical line from the top-middle generator card
  /// down to the top edge of the hub.
  static List<Path> connectors(Size board) {
    final solar = nodeBounds(solarRow, solarCol, board);
    final grid = nodeBounds(gridRow, gridCol, board);
    final hub = nodeBounds(hubRow, hubCol, board);
    final battery = nodeBounds(batteryRow, batteryCol, board);
    final home = nodeBounds(homeRow, homeCol, board);
    final generator = nodeBounds(generatorRow, generatorCol, board);

    return [
      _curve(cardAnchor(solar, hub), hubCornerFor(solar, hub)),
      _curve(cardAnchor(grid, hub), hubCornerFor(grid, hub)),
      _curve(cardAnchor(battery, hub), hubCornerFor(battery, hub)),
      _curve(cardAnchor(home, hub), hubCornerFor(home, hub)),
      // v93r — straight vertical line for the generator → hub
      // connector. We still use `_curve` so the dash math + paint
      // pipeline matches the other four; the control point at
      // (end.dx, start.dy) collapses to a straight segment when
      // start and end share an x-coordinate.
      _curve(
        cardAnchorVertical(generator, hub),
        hubVerticalEdgeFor(generator, hub),
      ),
    ];
  }

  /// Card-side anchor dots — used by the painter to draw the small white-
  /// ringed circle where each connector meets the node card.
  static List<Offset> cardAnchors(Size board) {
    final solar = nodeBounds(solarRow, solarCol, board);
    final grid = nodeBounds(gridRow, gridCol, board);
    final hub = nodeBounds(hubRow, hubCol, board);
    final battery = nodeBounds(batteryRow, batteryCol, board);
    final home = nodeBounds(homeRow, homeCol, board);
    final generator = nodeBounds(generatorRow, generatorCol, board);
    return [
      cardAnchor(solar, hub),
      cardAnchor(grid, hub),
      cardAnchor(battery, hub),
      cardAnchor(home, hub),
      cardAnchorVertical(generator, hub),
    ];
  }
}

/// Fixed-grid energy board. The 5 node cells + the 4 connector paths are
/// **all derived from the same `_BoardSpec` math** for a given board size,
/// so the painter's lines always meet the cards at exactly the right
/// edge — no drift, no manual offsetting.
class _FlowDiagram extends StatelessWidget {
  const _FlowDiagram({
    required this.cards,
    required this.flags,
    required this.motion,
    required this.animation,
  });

  final DashboardCards cards;
  final _FlowActivity flags;
  final _FlowMotion motion;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = w / _BoardSpec.aspect;
        final board = Size(w, h);

        // Cell rects — single source of truth. Both the placements below
        // and the painter (via _BoardSpec.connectors / cardAnchors) read
        // these same shapes.
        final solarRect = _BoardSpec.nodeBounds(
          _BoardSpec.solarRow,
          _BoardSpec.solarCol,
          board,
        );
        final gridRect = _BoardSpec.nodeBounds(
          _BoardSpec.gridRow,
          _BoardSpec.gridCol,
          board,
        );
        final hubRect = _BoardSpec.nodeBounds(
          _BoardSpec.hubRow,
          _BoardSpec.hubCol,
          board,
        );
        final batteryRect = _BoardSpec.nodeBounds(
          _BoardSpec.batteryRow,
          _BoardSpec.batteryCol,
          board,
        );
        final homeRect = _BoardSpec.nodeBounds(
          _BoardSpec.homeRow,
          _BoardSpec.homeCol,
          board,
        );

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              // Animated connectors (background).
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (_, _) => CustomPaint(
                    painter: _AnimatedFlowPainter(
                      phase: animation.value,
                      modes: motion.asList,
                    ),
                  ),
                ),
              ),
              // Hub (centre).
              _place(hubRect, const _FlowHubCard()),
              // Solar (top-left).
              _place(
                solarRect,
                _FlowNodeCard(
                  icon: Icons.wb_sunny,
                  tone: AppTheme.warning,
                  label: 'الألواح',
                  value: _formatNodeValue(cards.solarPowerW),
                  active: flags.solar,
                ),
              ),
              // Grid (top-right).
              _place(
                gridRect,
                _FlowNodeCard(
                  icon: Icons.bolt_outlined,
                  tone: AppTheme.violet,
                  label: 'الشبكة',
                  value: _formatNodeValue(cards.gridPowerW),
                  active: flags.grid,
                ),
              ),
              // Battery (bottom-left) — SOC badge lives INSIDE the card.
              _place(
                batteryRect,
                _FlowNodeCard(
                  icon: Icons.battery_full,
                  tone: AppTheme.success,
                  label: 'البطارية',
                  value: _formatNodeValue(cards.batteryPowerW),
                  active: flags.battery,
                  socBadge: cards.batterySocPercent > 0
                      ? _formatSocBadge(cards.batterySocPercent)
                      : null,
                ),
              ),
              // Home (bottom-right).
              _place(
                homeRect,
                _FlowNodeCard(
                  icon: Icons.home_rounded,
                  tone: AppTheme.indigoPrimary,
                  label: 'البيت',
                  value: _formatNodeValue(cards.homeLoadW),
                  active: flags.home,
                ),
              ),
              // v93r — Generator (top-middle, between Solar + Grid).
              // The Deye AC-IN port carries either utility grid OR a
              // generator on residential hybrids; we surface its
              // wattage here so the user can see incoming external
              // power separate from the bidirectional grid card.
              // Cyan tone distinguishes it from solar (amber), grid
              // (violet), battery (green) and home (indigo).
              _place(
                _BoardSpec.nodeBounds(
                  _BoardSpec.generatorRow,
                  _BoardSpec.generatorCol,
                  board,
                ),
                _FlowNodeCard(
                  icon: Icons.power_outlined,
                  tone: AppTheme.cyan,
                  label: 'المولد',
                  value: _formatNodeValue(cards.generatorPowerW),
                  active: flags.generator,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _place(Rect r, Widget child) {
    return Positioned(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: child,
    );
  }
}

/// Connector painter. Reads paths and anchor points directly from
/// `_BoardSpec` using the canvas size — same math the cards use, so
/// alignment is guaranteed.
///
/// v49: paints each connector according to its [_FlowMotionMode]:
///   * none        → thin muted static line
///   * pulse       → solid line, opacity breathes (no apparent direction)
///   * towardHub   → dashes scroll from node toward hub
///   * awayFromHub → dashes scroll from hub toward node
class _AnimatedFlowPainter extends CustomPainter {
  _AnimatedFlowPainter({required this.phase, required this.modes});

  /// 0.0 .. 1.0 — drives both dash scrolling and pulse breathing.
  final double phase;

  /// Order: [solar, grid, battery, home] — matches `_BoardSpec.connectors`.
  final List<_FlowMotionMode> modes;

  static const double _dashLen = 4.5;
  static const double _gapLen = 7.5;
  static const double _strokeWActive = 2.4;
  static const double _strokeWPulse = 2.2;
  static const double _strokeWInactive = 1.2;
  static const double _anchorR = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paths = _BoardSpec.connectors(size);
    final anchors = _BoardSpec.cardAnchors(size);

    // Lines first, anchor dots on top so the join reads as a clean weld.
    for (var i = 0; i < paths.length; i++) {
      _drawPath(canvas, paths[i], modes[i]);
    }
    for (var i = 0; i < anchors.length; i++) {
      _drawAnchor(canvas, anchors[i], modes[i]);
    }
  }

  void _drawAnchor(Canvas canvas, Offset point, _FlowMotionMode mode) {
    final active = mode != _FlowMotionMode.none;
    final color = active ? AppTheme.indigoBright : AppTheme.line;
    canvas.drawCircle(point, _anchorR, Paint()..color = color);
    canvas.drawCircle(
      point,
      _anchorR,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawPath(Canvas canvas, Path path, _FlowMotionMode mode) {
    switch (mode) {
      case _FlowMotionMode.none:
        _drawStatic(canvas, path);
        return;
      case _FlowMotionMode.pulse:
        _drawPulse(canvas, path);
        return;
      case _FlowMotionMode.towardHub:
        _drawDashes(canvas, path, reverse: false);
        return;
      case _FlowMotionMode.awayFromHub:
        _drawDashes(canvas, path, reverse: true);
        return;
    }
  }

  /// Inactive connector — thin muted static line.
  void _drawStatic(Canvas canvas, Path path) {
    final paint = Paint()
      ..color = AppTheme.line
      ..strokeWidth = _strokeWInactive
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  /// Pulse — line is active but direction is uncertain. Solid line whose
  /// opacity breathes with a sine wave on `phase`. No dashes, so the eye
  /// never sees a travel direction.
  void _drawPulse(Canvas canvas, Path path) {
    // Sine wave maps phase 0..1 → opacity 0.45..1.0. Always-visible base
    // (0.45) so the connector still reads as "connected" at trough.
    final wave = (math.sin(phase * 2 * math.pi) + 1) / 2; // 0..1
    final opacity = 0.45 + 0.55 * wave;
    final paint = Paint()
      ..color = AppTheme.indigoBright.withValues(alpha: opacity)
      ..strokeWidth = _strokeWPulse
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  /// Directional dash scroll. All `_BoardSpec` paths are drawn as
  /// `node anchor → hub corner`, so:
  ///   reverse: false → dashes travel along the natural direction
  ///                    (node → hub) = towardHub.
  ///   reverse: true  → dashes travel against it (hub → node) = awayFromHub.
  void _drawDashes(Canvas canvas, Path path, {required bool reverse}) {
    final paint = Paint()
      ..color = AppTheme.indigoBright
      ..strokeWidth = _strokeWActive
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const cycle = _dashLen + _gapLen;
    final rawShift = (phase * cycle) % cycle;
    // The path-iteration loop below moves dash positions from negative
    // distance up to `length`. As `rawShift` grows over time, `-rawShift`
    // shrinks (becomes more negative) and dashes appear to slide from
    // `length` toward `0` — i.e. from path end (hub) toward path start
    // (node). That visual direction is `awayFromHub`. To get the
    // opposite — dashes moving from node toward hub — we run the same
    // loop with the shift inverted, by replacing it with `cycle - shift`.
    final shift = reverse ? rawShift : (cycle - rawShift) % cycle;

    for (final metric in path.computeMetrics()) {
      final length = metric.length;
      var distance = -shift;
      while (distance < length) {
        final start = distance < 0 ? 0.0 : distance;
        final end = (distance + _dashLen).clamp(0.0, length).toDouble();
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), paint);
        }
        distance += cycle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedFlowPainter old) =>
      old.phase != phase || !_listEq(old.modes, modes);

  bool _listEq(List<_FlowMotionMode> a, List<_FlowMotionMode> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// One of the four corner cards. Premium soft-rounded white surface, with
/// active/inactive visual states. Optional [socBadge] renders a small "X%"
/// chip in the top-end corner (used for the battery card).
class _FlowNodeCard extends StatelessWidget {
  const _FlowNodeCard({
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
    required this.active,
    this.socBadge,
  });

  final IconData icon;
  final Color tone;
  final String label;
  final String value;
  final bool active;
  final String? socBadge;

  @override
  Widget build(BuildContext context) {
    final borderColor = active
        ? AppTheme.indigoBright.withValues(alpha: 0.45)
        : AppTheme.line;
    final iconColor = active ? tone : AppTheme.faintMuted;
    final valueColor = active ? AppTheme.ink : AppTheme.muted;

    // Battery row puts the icon next to the SOC chip — both INSIDE the
    // card. No floating Positioned anywhere — the chip can never drift.
    final hasSoc = socBadge != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: active ? 1.4 : 1.0),
        boxShadow: [
          BoxShadow(
            color: (active ? AppTheme.indigoPrimary : AppTheme.softInk)
                .withValues(alpha: active ? 0.10 : 0.04),
            blurRadius: active ? 14 : 7,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top row: icon (+ optional SOC chip for battery).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: active ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: iconColor, size: 12),
              ),
              if (hasSoc) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.indigoSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Text(
                    socBadge!,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppTheme.indigoPrimary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: valueColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                height: 1.05,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.faintMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centre inverter hub. **Intentionally simple** — only the Zynavolt logo
/// (or a brand fallback) and the "الانفرتر" label. The server's status
/// text is rendered by `_StatusBanner` above the flow card, never inside
/// the hub: keeping it out is what guarantees the hub can never overflow.
class _FlowHubCard extends StatelessWidget {
  const _FlowHubCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        // Subtle indigo glass gradient sets the hub apart from the four
        // pure-white satellite cards without adding visual noise.
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Colors.white, Color(0xFFF1F5FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.indigoBright.withValues(alpha: 0.55),
          width: 1.6,
        ),
        boxShadow: [
          // Outer indigo glow.
          BoxShadow(
            color: AppTheme.indigoPrimary.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
          // Tight inner-feel shadow for premium depth.
          BoxShadow(
            color: AppTheme.indigoPrimary.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo sits inside a soft indigo halo for extra emphasis.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.indigoPrimary.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.indigoSoft,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  _kBrandLogoPath,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.electric_meter_outlined,
                    color: AppTheme.indigoPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'الانفرتر',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.indigoPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// "1,587.0" / "0.0" / "−240.0" — comma thousands, one decimal, signed.
String _formatNodeValue(double w) {
  final neg = w < 0;
  final mag = w.abs();
  final str = mag.toStringAsFixed(1);
  final parts = str.split('.');
  final intPart = parts[0];
  final fracPart = parts.length > 1 ? '.${parts[1]}' : '';
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return '${neg ? '−' : ''}$buf$fracPart';
}

String _formatSocBadge(double p) {
  final clamped = p.clamp(0, 100);
  final str = clamped >= 100
      ? clamped.toStringAsFixed(0)
      : clamped.toStringAsFixed(0);
  return '$str%';
}

// ─── Battery card ────────────────────────────────────────────────────────

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.cards});
  final DashboardCards cards;

  @override
  Widget build(BuildContext context) {
    final soc = cards.batterySocPercent.clamp(0, 100).toDouble();
    final socClamped = soc / 100.0;

    // v99d — colour-grade the entire card against SoC band so the
    // battery's importance reads at a glance: success-green when
    // healthy, warm amber when mid, danger red when critical.
    final socColor = soc >= 50
        ? AppTheme.success
        : soc >= 20
        ? AppTheme.warning
        : AppTheme.danger;
    final batteryPower = cards.batteryPowerW;
    final (modeText, modeIcon) = batteryPower > 0
        ? ('شحن', Icons.bolt_rounded)
        : batteryPower < 0
        ? ('تفريغ', Icons.south_rounded)
        : ('خامل', Icons.pause_circle_filled_rounded);

    // v99d — Battery is now a hero-style card: ringed % display on
    // the left, mode + flow strip on the right, big gradient
    // capacity bar at the bottom. Multi-layer shadows + an inner
    // glow give it real depth instead of a flat sheet.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, socColor.withValues(alpha: 0.04)],
        ),
        border: Border.all(color: socColor.withValues(alpha: 0.22), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: socColor.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Soft accent glow in the top-right corner — gives the
            // card an unmistakable "premium" sheen.
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      socColor.withValues(alpha: 0.20),
                      socColor.withValues(alpha: 0.00),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: title + small icon, no subtitle (cuts
                  // height + visual noise).
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              socColor.withValues(alpha: 0.20),
                              socColor.withValues(alpha: 0.10),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: socColor.withValues(alpha: 0.32),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: socColor.withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.battery_charging_full_rounded,
                          color: socColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'البطارية',
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'مستوى الشحن والقدرة اللحظية',
                              style: TextStyle(
                                color: AppTheme.faintMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Mode pill (شحن / تفريغ / خامل) on the LEFT.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              socColor.withValues(alpha: 0.18),
                              socColor.withValues(alpha: 0.10),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: socColor.withValues(alpha: 0.30),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(modeIcon, size: 12, color: socColor),
                            const SizedBox(width: 4),
                            Text(
                              modeText,
                              style: TextStyle(
                                color: socColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Big SoC % left, signed wattage right.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: soc >= 100 || soc <= -100
                                  ? soc.toStringAsFixed(0)
                                  : soc.toStringAsFixed(1),
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                letterSpacing: -1.5,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                shadows: [
                                  Shadow(
                                    color: socColor.withValues(alpha: 0.18),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                            ),
                            TextSpan(
                              text: ' %',
                              style: TextStyle(
                                color: socColor,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'التدفق الآن',
                            style: TextStyle(
                              color: AppTheme.faintMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatWatts(batteryPower.abs()),
                            style: TextStyle(
                              color: socColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Glossy capacity bar — track has an inset, fill is
                  // a gradient with a glow underneath.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFE5E7EB),
                            const Color(0xFFF1F5F9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                            spreadRadius: -1,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: socClamped,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    socColor.withValues(alpha: 0.85),
                                    socColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: socColor.withValues(alpha: 0.45),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Top inner highlight on the fill — fakes
                          // glass reflection on the wet/glossy bar.
                          FractionallySizedBox(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: socClamped,
                            heightFactor: 0.5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.40),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(999),
                                  topRight: Radius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Production card ─────────────────────────────────────────────────────

class _ProductionCard extends StatelessWidget {
  const _ProductionCard({required this.cards});
  final DashboardCards cards;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8FBFF)],
        ),
        border: Border.all(color: AppTheme.line, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.indigoPrimary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: Icons.bar_chart_rounded,
            title: 'الإنتاج',
            subtitle: 'إجمالي الطاقة المنتجة كما يحتسبها الخادم',
            accent: AppTheme.warning,
          ),
          const SizedBox(height: 14),
          // v99d — three glossy tiles instead of dot+divider columns.
          // Each tile is its own surface with a tinted top-edge
          // accent + soft inner gradient so the three periods read
          // as distinct cards, not three rows in a newspaper.
          Row(
            children: [
              Expanded(
                child: _ProductionCol(
                  label: 'اليوم',
                  valueText: _formatKwh(cards.dailyProductionKwh),
                  tone: AppTheme.warning,
                  icon: Icons.wb_sunny_rounded,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _ProductionCol(
                  label: 'الشهر',
                  valueText: _formatKwh(cards.monthlyProductionKwh),
                  tone: AppTheme.indigoPrimary,
                  icon: Icons.calendar_month_rounded,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _ProductionCol(
                  label: 'الإجمالي',
                  valueText: _formatKwh(cards.totalProductionKwh),
                  tone: AppTheme.success,
                  icon: Icons.public_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductionCol extends StatelessWidget {
  const _ProductionCol({
    required this.label,
    required this.valueText,
    required this.tone,
    required this.icon,
  });

  final String label;
  final String valueText;
  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    // v99d — glossy production tile. Multi-layer gradient + accent
    // glow + 2-px top inner highlight gives each period a real
    // "card" feel instead of a newspaper column.
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tone.withValues(alpha: 0.10), tone.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: tone.withValues(alpha: 0.25), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tone, tone.withValues(alpha: 0.75)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: tone.withValues(alpha: 0.42),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valueText,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// v99d — `_VDivider` removed. The glossy production tiles use a
// fixed spacing instead of a thin divider, so the helper no longer
// has a call site.

// ─── Footer chip ─────────────────────────────────────────────────────────

class _FooterMetaChip extends StatelessWidget {
  const _FooterMetaChip({required this.snapshot});
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final reading = _formatIsoUtc(snapshot.latest.createdAt);
    final generated = _formatIsoUtc(snapshot.generatedAt);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 14, color: AppTheme.faintMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'آخر قراءة: $reading',
                  style: const TextStyle(
                    color: AppTheme.softInk,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // v73: bumped fontSize 10.5 → 11 for readability.
                  'وقت الاستجابة: $generated',
                  style: const TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared mini bits ───────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// v99d — optional accent colour. When provided, the icon square
  /// inherits a gradient tinted with the accent so each card has a
  /// distinct colour identity (battery = success, production =
  /// warning, etc.). Callers that don't pass an accent fall back
  /// to the original flat indigo soft square so existing usages
  /// stay byte-compatible.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppTheme.indigoPrimary;
    final hasAccent = accent != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: hasAccent ? 34 : 30,
          height: hasAccent ? 34 : 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: hasAccent
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tint.withValues(alpha: 0.18),
                      tint.withValues(alpha: 0.08),
                    ],
                  )
                : null,
            color: hasAccent ? null : AppTheme.indigoSoft,
            borderRadius: BorderRadius.circular(hasAccent ? 11 : 9),
            border: hasAccent
                ? Border.all(color: tint.withValues(alpha: 0.22), width: 0.8)
                : null,
          ),
          child: Icon(icon, color: tint, size: hasAccent ? 17 : 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Pure formatters (display only — no business logic) ─────────────────

String _formatWatts(double w) {
  if (w == 0) return '0 W';
  final sign = w < 0 ? '−' : '';
  final mag = w.abs();
  final str = mag >= 100 ? mag.toStringAsFixed(0) : mag.toStringAsFixed(1);
  return '$sign$str W';
}

// v100 — `_formatPercent` removed (no remaining call sites since
// `_BatteryCard` now inlines its own Text.rich rendering).

String _formatKwh(double k) {
  if (k == 0) return '0 kWh';
  final str = k >= 100 ? k.toStringAsFixed(0) : k.toStringAsFixed(2);
  return '$str kWh';
}

String _formatIsoUtc(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  // v99c — route through the canonical 12-hour Arabic formatter so
  // the footer's "آخر قراءة" / "وقت الاستجابة" rows match the rest
  // of the app's time format. Falls back to the raw input on parse
  // failure (legacy contract).
  return formatBackendExact(iso) ?? iso;
}

/// v97: the local `_formatHm` was replaced by [formatBackendHm] from
/// `core/utils/backend_time.dart`, which routes through the same
/// UTC-aware parser the Notifications screen uses. The previous
/// naive substring approach displayed UTC wall-clock as if it were
/// device-local time.
//
/// v85: render kWh values compactly for the hero pill. <100 keeps one
/// decimal so small days still feel precise; ≥100 drops the decimal.
String _fmtKwh(double v) {
  if (v == 0) return '0';
  if (v >= 100) return v.toStringAsFixed(0);
  if (v >= 10) return v.toStringAsFixed(1);
  return v.toStringAsFixed(2);
}
