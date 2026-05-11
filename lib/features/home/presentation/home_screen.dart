import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/state/app_session.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../auth/data/auth_models.dart';
import '../../dashboard/data/dashboard_models.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../devices/data/device_models.dart';
import '../../devices/state/selected_device_provider.dart';

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
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الرئيسية'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: const _ScreenBackground(child: _HomeBody()),
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
        await ref.read(dashboardProvider.future);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, kToolbarHeight - 6, 16, 32),
        children: [
          _HomeHero(
            user: session.user,
            device: activeDevice,
            snapshot: dashboard.valueOrNull,
            onRefresh: () => ref.invalidate(dashboardProvider),
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
    final lastReading = _formatHm(snapshot?.latest.createdAt);
    final deviceName = device == null
        ? null
        : (device!.name.isNotEmpty ? device!.name : '#${device!.id}');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusGlass),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppTheme.indigoPrimary, AppTheme.indigoBright],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.indigoPrimary.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _BrandWordmark(),
              const Spacer(),
              _HeroIconButton(
                icon: Icons.refresh,
                tooltip: 'تحديث',
                onPressed: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            greetingName.isNotEmpty
                ? 'مرحباً بعودتك، $greetingName'
                : 'مرحباً بعودتك',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HeroPill(
                icon: Icons.solar_power_outlined,
                text: deviceName ?? 'لم يتم اختيار جهاز',
              ),
              if (lastReading != null)
                _HeroPill(
                  icon: Icons.schedule,
                  text: 'آخر قراءة $lastReading',
                ),
            ],
          ),
        ],
      ),
    );
  }
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
    return const AppCard(
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
      children.add(const _ScopeNotice(
        text:
            'هذه البيانات من ملخص النظام المتاح حالياً، وليست لجهاز واحد بعينه.',
      ));
      children.add(const SizedBox(height: 10));
    }

    if (snapshot.empty) {
      children.add(const AppCard(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'لا توجد قراءة متاحة لهذا الجهاز بعد',
          subtitle:
              'سيظهر آخر تحديث هنا فور وصوله من الخادم — لا حسابات داخل التطبيق.',
        ),
      ));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    if (snapshot.latest.statusText.isNotEmpty) {
      children.add(_StatusBanner(text: snapshot.latest.statusText));
      children.add(const SizedBox(height: 12));
    }

    children.addAll([
      _EnergyFlowCard(snapshot: snapshot),
      const SizedBox(height: 12),
      _BatteryCard(cards: cards),
      const SizedBox(height: 12),
      _ProductionCard(cards: cards),
      const SizedBox(height: 12),
      _FooterMetaChip(snapshot: snapshot),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7D2FE)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.indigoPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.indigoSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.insights_outlined,
                color: AppTheme.indigoPrimary, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'حالة النظام',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.45,
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
          const Icon(Icons.info_outline,
              size: 16, color: AppTheme.indigoPrimary),
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
          const _CardHeader(
            icon: Icons.bolt_outlined,
            title: 'تدفق الطاقة الآن',
            subtitle: 'بيانات لحظية من الخادم.',
          ),
          const SizedBox(height: 10),
          // _FlowDiagram self-sizes from the virtual canvas aspect
          // (1000 × 840), so no explicit AspectRatio wrapper is needed.
          // The server status text lives in `_StatusBanner` *above* this
          // card, never inside the hub — keeps the hub from overflowing.
          _FlowDiagram(
            cards: cards,
            flags: flags,
            animation: _controller,
          ),
        ],
      ),
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
  });

  factory _FlowActivity.fromCards(DashboardCards c) => _FlowActivity(
        solar: c.solarPowerW > 0,
        home: c.homeLoadW > 0,
        battery: c.batterySocPercent > 0 || c.batteryPowerW.abs() > 0,
        grid: c.gridPowerW.abs() > 0,
      );

  final bool solar;
  final bool home;
  final bool battery;
  final bool grid;

  List<bool> get asList => [solar, grid, battery, home]; // matches painter
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
  static const int solarRow = 0,    solarCol = 0;
  static const int gridRow  = 0,    gridCol  = 2;
  static const int hubRow   = 1,    hubCol   = 1;
  static const int batteryRow = 2,  batteryCol = 0;
  static const int homeRow  = 2,    homeCol  = 2;

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

  /// All four connector paths in board-pixel coordinates. Pure function
  /// of the board size — same math the placements use, so anchors line
  /// up exactly with the node cards.
  static List<Path> connectors(Size board) {
    final solar = nodeBounds(solarRow, solarCol, board);
    final grid = nodeBounds(gridRow, gridCol, board);
    final hub = nodeBounds(hubRow, hubCol, board);
    final battery = nodeBounds(batteryRow, batteryCol, board);
    final home = nodeBounds(homeRow, homeCol, board);

    return [
      _curve(cardAnchor(solar, hub), hubCornerFor(solar, hub)),
      _curve(cardAnchor(grid, hub), hubCornerFor(grid, hub)),
      _curve(cardAnchor(battery, hub), hubCornerFor(battery, hub)),
      _curve(cardAnchor(home, hub), hubCornerFor(home, hub)),
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
    return [
      cardAnchor(solar, hub),
      cardAnchor(grid, hub),
      cardAnchor(battery, hub),
      cardAnchor(home, hub),
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
    required this.animation,
  });

  final DashboardCards cards;
  final _FlowActivity flags;
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
            _BoardSpec.solarRow, _BoardSpec.solarCol, board);
        final gridRect = _BoardSpec.nodeBounds(
            _BoardSpec.gridRow, _BoardSpec.gridCol, board);
        final hubRect = _BoardSpec.nodeBounds(
            _BoardSpec.hubRow, _BoardSpec.hubCol, board);
        final batteryRect = _BoardSpec.nodeBounds(
            _BoardSpec.batteryRow, _BoardSpec.batteryCol, board);
        final homeRect = _BoardSpec.nodeBounds(
            _BoardSpec.homeRow, _BoardSpec.homeCol, board);

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
                      activeFlags: flags.asList,
                    ),
                  ),
                ),
              ),
              // Hub (centre).
              _place(
                hubRect,
                const _FlowHubCard(),
              ),
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
class _AnimatedFlowPainter extends CustomPainter {
  _AnimatedFlowPainter({
    required this.phase,
    required this.activeFlags,
  });

  /// 0.0 .. 1.0 — drives the dash phase shift.
  final double phase;

  /// Order: [solar, grid, battery, home] — matches `_BoardSpec.connectors`.
  final List<bool> activeFlags;

  static const double _dashLen = 4.5;
  static const double _gapLen = 7.5;
  static const double _strokeWActive = 2.4;
  static const double _strokeWInactive = 1.2;
  static const double _anchorR = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paths = _BoardSpec.connectors(size);
    final anchors = _BoardSpec.cardAnchors(size);

    // Lines first, anchor dots on top so the join reads as a clean weld.
    for (var i = 0; i < paths.length; i++) {
      _drawPath(canvas, paths[i], activeFlags[i]);
    }
    for (var i = 0; i < anchors.length; i++) {
      _drawAnchor(canvas, anchors[i], activeFlags[i]);
    }
  }

  void _drawAnchor(Canvas canvas, Offset point, bool active) {
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

  void _drawPath(Canvas canvas, Path path, bool active) {
    if (!active) {
      final paint = Paint()
        ..color = AppTheme.line
        ..strokeWidth = _strokeWInactive
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
      return;
    }

    final paint = Paint()
      ..color = AppTheme.indigoBright
      ..strokeWidth = _strokeWActive
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const cycle = _dashLen + _gapLen;
    final shift = (phase * cycle) % cycle;
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
      old.phase != phase || !_listEq(old.activeFlags, activeFlags);

  bool _listEq(List<bool> a, List<bool> b) {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
  final str =
      clamped >= 100 ? clamped.toStringAsFixed(0) : clamped.toStringAsFixed(0);
  return '$str%';
}

// ─── Battery card ────────────────────────────────────────────────────────

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.cards});
  final DashboardCards cards;

  @override
  Widget build(BuildContext context) {
    final socClamped =
        cards.batterySocPercent.clamp(0, 100).toDouble() / 100.0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: Icons.battery_full_outlined,
            title: 'البطارية',
            subtitle: 'مستوى الشحن وقدرة البطارية اللحظية.',
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatPercent(cards.batterySocPercent),
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'حالة الشحن',
                  style: TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_outlined,
                        size: 12, color: AppTheme.success),
                    const SizedBox(width: 4),
                    Text(
                      _formatWatts(cards.batteryPowerW),
                      style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: socClamped,
              minHeight: 10,
              backgroundColor: AppTheme.success.withValues(alpha: 0.12),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.success),
            ),
          ),
        ],
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: Icons.show_chart,
            title: 'الإنتاج',
            subtitle: 'إجمالي الطاقة المُنتَجة كما يحتسبها الخادم.',
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ProductionCol(
                  label: 'اليوم',
                  valueText: _formatKwh(cards.dailyProductionKwh),
                  tone: AppTheme.warning,
                ),
              ),
              const _VDivider(),
              Expanded(
                child: _ProductionCol(
                  label: 'الشهر',
                  valueText: _formatKwh(cards.monthlyProductionKwh),
                  tone: AppTheme.indigoPrimary,
                ),
              ),
              const _VDivider(),
              Expanded(
                child: _ProductionCol(
                  label: 'الإجمالي',
                  valueText: _formatKwh(cards.totalProductionKwh),
                  tone: AppTheme.violet,
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
  });

  final String label;
  final String valueText;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.faintMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valueText,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 36,
        color: AppTheme.line,
        margin: const EdgeInsets.symmetric(horizontal: 6),
      );
}

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
                  'وقت الاستجابة: $generated',
                  style: const TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 10.5,
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.indigoSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: AppTheme.indigoPrimary, size: 16),
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

String _formatPercent(double p) {
  final str =
      p >= 100 || p <= -100 ? p.toStringAsFixed(0) : p.toStringAsFixed(1);
  return '$str %';
}

String _formatKwh(double k) {
  if (k == 0) return '0 kWh';
  final str = k >= 100 ? k.toStringAsFixed(0) : k.toStringAsFixed(2);
  return '$str kWh';
}

String _formatIsoUtc(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  // No client-side timezone math — render as the server gave it, just
  // trimmed to seconds for compactness.
  final dot = iso.indexOf('.');
  return dot > 0 ? iso.substring(0, dot) : iso;
}

/// Compact "HH:MM" tail-extract from an ISO timestamp. Used by the hero's
/// "آخر قراءة HH:MM" pill. Falls back to the full ISO if the format
/// doesn't match, and to null for missing values.
String? _formatHm(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final tIdx = iso.indexOf('T');
  if (tIdx < 0 || tIdx + 6 > iso.length) return iso;
  return iso.substring(tIdx + 1, tIdx + 6);
}
