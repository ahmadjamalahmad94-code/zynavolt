import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/zyn_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../devices/state/selected_device_provider.dart';
import '../data/energy_chart_models.dart';
import '../data/energy_chart_repository.dart';
import 'widgets/anchor_navigator.dart';
import 'widgets/chart_legend.dart';
import 'widgets/energy_split_bars.dart';
import 'widgets/power_curve_chart.dart';
import 'widgets/range_selector.dart';

/// v77 — premium advanced energy visualization card.
///
/// Surface contract (Home tab):
///   * Lives below the smart insights card, above the footer chip.
///   * Self-contained scope (day/month) + anchor state so refreshing
///     the Home dashboard doesn't reset the user's chart selection.
///   * Reuses the existing v56 `/statistics` endpoint via
///     `energyChartSeriesProvider` — no new HTTP path, no parallel
///     data model, no forked energy math.
///
/// Honesty rules baked in:
///   * Year / total chips render disabled (no backend support today).
///   * SOC is a period mean reference line, not a fake per-bucket trace.
///   * Battery / Grid show up only in the lower summary bars, never as
///     fake time-series lines on the curve.
class HomeEnergyChartCard extends ConsumerStatefulWidget {
  const HomeEnergyChartCard({super.key});

  @override
  ConsumerState<HomeEnergyChartCard> createState() =>
      _HomeEnergyChartCardState();
}

class _HomeEnergyChartCardState
    extends ConsumerState<HomeEnergyChartCard> {
  ChartScope _scope = ChartScope.day;
  late DateTime _anchor;

  static DateTime _todayDateOnly() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _anchor = _todayDateOnly();
  }

  // ── anchor formatting / stepping ──────────────────────────────────

  String get _anchorIso {
    final y = _anchor.year.toString().padLeft(4, '0');
    final m = _anchor.month.toString().padLeft(2, '0');
    final d = _anchor.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _setScope(ChartScope next) {
    if (next == _scope || !next.isSupported) return;
    setState(() => _scope = next);
  }

  void _stepAnchor(int delta) {
    setState(() {
      switch (_scope) {
        case ChartScope.day:
          _anchor = _anchor.add(Duration(days: delta));
          break;
        case ChartScope.month:
          _anchor = DateTime(_anchor.year, _anchor.month + delta, 1);
          break;
        case ChartScope.year:
        case ChartScope.total:
          break; // disabled chips never reach here
      }
    });
  }

  bool get _canGoForward {
    final today = _todayDateOnly();
    if (_scope == ChartScope.day) {
      return _anchor.isBefore(today);
    }
    if (_scope == ChartScope.month) {
      final next = DateTime(_anchor.year, _anchor.month + 1, 1);
      final thisMonth = DateTime(today.year, today.month, 1);
      return !next.isAfter(thisMonth);
    }
    return false;
  }

  Future<void> _pickAnchor() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(_anchor.year - 5, 1, 1),
      lastDate: _todayDateOnly(),
    );
    if (picked == null) return;
    setState(() => _anchor = DateTime(picked.year, picked.month, picked.day));
  }

  // ── card frame ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final deviceId = ref.watch(effectiveDeviceIdProvider);

    // Explicit RTL wrapping: every label, chip, arrow, and summary
    // row inside this card is Arabic — locking the directionality
    // here guarantees the layout reads naturally regardless of how
    // the parent route was configured.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        // v77 art-direction polish: generous symmetrical padding so
        // the card breathes; the chart no longer sits flush against
        // the rounded edge and the bands have proper rhythm.
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        decoration: BoxDecoration(
          color: ZynColors.surface,
          borderRadius:
              BorderRadius.circular(ZynRadii.xl + 4), // 22
          border: Border.all(color: ZynColors.line.withValues(alpha: 0.8)),
          boxShadow: ZynShadows.soft(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardHeader(scope: _scope),
            const SizedBox(height: 18),
            ChartRangeSelector(
              value: _scope,
              onChanged: _setScope,
            ),
            const SizedBox(height: 14),
            ChartAnchorNavigator(
              scope: _scope,
              anchor: _anchor,
              canGoForward: _canGoForward,
              onPrevious: () => _stepAnchor(-1),
              onNext: () => _stepAnchor(1),
              onTapAnchor: _pickAnchor,
            ),
            const SizedBox(height: 18),
            if (deviceId == null)
              const _ChartStatePanel(
                icon: Icons.solar_power_outlined,
                title: 'لا يوجد جهاز محدد',
                subtitle:
                    'اختر جهازاً من قائمة الأجهزة لعرض منحنى الطاقة.',
              )
            else
              _ChartBody(
                query: EnergyChartQuery(
                  deviceId: deviceId,
                  scope: _scope,
                  anchor: _anchorIso,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Calm title row.
///
/// v77 polish: the previous version carried a redundant scope pill
/// next to the title — the active chip in the range selector below
/// already communicates the scope. We replaced it with a quiet "live"
/// dot so the header reads as a confident product surface, not a
/// state readout.
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.scope});
  final ChartScope scope;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                ZynColors.primary50,
                ZynColors.primary500.withValues(alpha: 0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: ZynColors.primary500.withValues(alpha: 0.16),
            ),
          ),
          child: const Icon(
            Icons.show_chart_rounded,
            color: ZynColors.primary700,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'منحنى القدرة',
                style: TextStyle(
                  color: ZynColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: 0.1,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'تتبع الإنتاج والاستهلاك خلال الفترة',
                style: TextStyle(
                  color: ZynColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        // Calm "live" dot — six pixels of mint with a soft halo. Reads
        // as "this card breathes with the device" without claiming a
        // websocket stream we don't have.
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: ZynColors.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: ZynColors.success.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: ZynColors.success,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: ZynColors.success.withValues(alpha: 0.45),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'حيّ',
                style: TextStyle(
                  color: ZynColors.success,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartBody extends ConsumerWidget {
  const _ChartBody({required this.query});
  final EnergyChartQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(energyChartSeriesProvider(query));
    return snap.when(
      loading: () => const _ChartLoading(),
      error: (err, _) => _ChartStatePanel(
        icon: Icons.error_outline_rounded,
        title: 'تعذّر تحميل بيانات المنحنى',
        subtitle: err is ApiException
            ? err.message
            : 'حاول التحديث بعد لحظات.',
        action: TextButton.icon(
          onPressed: () =>
              ref.invalidate(energyChartSeriesProvider(query)),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('إعادة المحاولة'),
        ),
      ),
      data: (series) {
        if (series.empty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (series.titleHint.isNotEmpty)
                _TitleHintRow(text: series.titleHint),
              const SizedBox(height: 12),
              const _ChartStatePanel(
                icon: Icons.cloud_off_outlined,
                title: 'لا توجد قراءات لهذه الفترة',
                subtitle:
                    'تظهر القراءات بعد أوّل مزامنة من الجهاز.',
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (series.titleHint.isNotEmpty) ...[
              _TitleHintRow(text: series.titleHint),
              const SizedBox(height: 12),
            ],
            _HeroMetricRow(series: series),
            const SizedBox(height: 14),
            ChartLegend(series: series),
            const SizedBox(height: 18),
            PowerCurveChart(series: series),
            const SizedBox(height: 20),
            const _BandSeparator(),
            const SizedBox(height: 20),
            EnergySplitSection(series: series),
          ],
        );
      },
    );
  }
}

/// Hero metric pair above the legend — anchors the card on one
/// trustworthy headline number (total production for the period) with
/// the matching consumption value as a sibling. This is the "current
/// point summary" the art-direction addendum calls for; it makes the
/// card feel centered on a hero value rather than reading as a
/// generic legend-and-chart block.
class _HeroMetricRow extends StatelessWidget {
  const _HeroMetricRow({required this.series});
  final EnergyChartSeries series;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: ZynColors.success,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'إجمالي الإنتاج',
                    style: TextStyle(
                      color: ZynColors.muted.withValues(alpha: 0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _fmtKwh(series.productionKwh),
                    style: const TextStyle(
                      color: ZynColors.ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'kWh',
                    style: TextStyle(
                      color: ZynColors.muted.withValues(alpha: 0.95),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Right side: paired secondary metric (consumption), tonal but
        // not as loud as the hero number. Keeps the band balanced.
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الاستهلاك',
                  style: TextStyle(
                    color: ZynColors.muted.withValues(alpha: 0.95),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: ZynColors.warning,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _fmtKwh(series.consumptionKwh),
                  style: const TextStyle(
                    color: ZynColors.inkSoft,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'kWh',
                  style: TextStyle(
                    color: ZynColors.muted.withValues(alpha: 0.95),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static String _fmtKwh(double v) {
    if (v.isNaN || v.isInfinite) return '0';
    if (v >= 1000) return v.toStringAsFixed(0);
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}

/// Soft blue/indigo "current period" accent above the legend — the
/// addendum calls for the current-time/anchor strip to be visually
/// distinct without being loud. We render it as a low-saturation pill
/// with a calendar glyph so the user reads it as "the data below is
/// for this window".
class _TitleHintRow extends StatelessWidget {
  const _TitleHintRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: ZynColors.primary50.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: ZynColors.primary500.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 13,
              color: ZynColors.primary700.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: ZynColors.primary700.withValues(alpha: 0.95),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft tonal separator between the chart and the summary band — a
/// 1-px line that fades into the page background at both ends so it
/// doesn't draw the eye the way a flat hairline does. Premium apps
/// rarely use a single hard rule; a fade keeps the rhythm calm.
class _BandSeparator extends StatelessWidget {
  const _BandSeparator();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZynColors.line.withValues(alpha: 0.0),
            ZynColors.line.withValues(alpha: 0.85),
            ZynColors.line.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: ZynColors.primary700,
        ),
      ),
    );
  }
}

/// Calm fallback panel for loading/empty/error/no-device states.
///
/// v77 art-direction polish — the panel now uses a double-ring icon
/// frame (soft outer halo + filled inner badge) so the empty state
/// reads as "informed", not "broken", while sharing the same calm
/// indigo palette as the rest of the card.
class _ChartStatePanel extends StatelessWidget {
  const _ChartStatePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ZynColors.primary50.withValues(alpha: 0.35),
            ZynColors.bg.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(ZynRadii.card + 4),
        border: Border.all(color: ZynColors.line.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZynColors.primary50.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: ZynColors.primary50,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(icon, color: ZynColors.primary700, size: 19),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ZynColors.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.6,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            action!,
          ],
        ],
      ),
    );
  }
}
