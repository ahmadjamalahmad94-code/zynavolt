import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../data/energy_chart_models.dart';
import 'chart_palette.dart';

/// Honest energy summary that lives below the curve chart.
///
/// v77 final polish — the previous version stacked a production-vs-
/// consumption bar AND a 4-segment composition bar AND a 3-tile KPI
/// row. The first two said overlapping things, and the KPI tiles
/// didn't share the visual language of the notifications-screen hero
/// cards (pale tinted surface, corner-floating icon badge, big
/// numeral). This version collapses to two confident bands:
///
///   1. One composition bar with all four flows (الإنتاج / الاستهلاك
///      / البطارية / الشبكة), zero-value segments hidden.
///   2. A 2×2 grid of four tinted hero stat tiles in the same visual
///      language as the notifications-screen summary cards.
///
/// Every value is read off `EnergyChartSeries` totals — no derivations
/// happen here; the math comes from the canonical server-side energy
/// helpers via the v56 statistics endpoint.
class EnergySplitSection extends StatelessWidget {
  const EnergySplitSection({super.key, required this.series});

  final EnergyChartSeries series;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BandHeader(
          icon: Icons.stacked_bar_chart_outlined,
          label: 'توزيع طاقة الفترة',
          trailingValue: _totalKwhLabel(
            series.productionKwh +
                series.consumptionKwh +
                series.batteryInKwh +
                series.gridInKwh,
          ),
        ),
        const SizedBox(height: 14),
        _CompositionBar(series: series),
        const SizedBox(height: 22),
        _HeroTilesGrid(series: series),
      ],
    );
  }

  static String _totalKwhLabel(double v) {
    if (v < 0.001) return '—';
    if (v >= 1000) return '${v.toStringAsFixed(0)} kWh';
    if (v >= 100) return '${v.toStringAsFixed(0)} kWh';
    if (v >= 10) return '${v.toStringAsFixed(1)} kWh';
    return '${v.toStringAsFixed(2)} kWh';
  }
}

/// Calm band-title row: small badge icon on the leading edge, Arabic
/// title, optional trailing total pill that anchors the eye.
class _BandHeader extends StatelessWidget {
  const _BandHeader({
    required this.icon,
    required this.label,
    this.trailingValue,
  });

  final IconData icon;
  final String label;
  final String? trailingValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.indigoSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child:
              Icon(icon, color: AppTheme.indigoPrimary, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.softInk,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.1,
            ),
          ),
        ),
        if (trailingValue != null && trailingValue != '—')
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.softBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppTheme.line.withValues(alpha: 0.7),
              ),
            ),
            child: Text(
              trailingValue!,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.1,
              ),
            ),
          ),
      ],
    );
  }
}

/// One elegant 4-segment composition bar — production / consumption /
/// battery-in / grid-in. Zero-value segments are dropped entirely so
/// the bar honestly reflects what actually flowed during the period.
class _CompositionBar extends StatelessWidget {
  const _CompositionBar({required this.series});
  final EnergyChartSeries series;

  @override
  Widget build(BuildContext context) {
    final raw = [
      _LabelledSegment(
        'الإنتاج',
        ChartPalette.production,
        series.productionKwh,
        series.productionSharePercent,
      ),
      _LabelledSegment(
        'الاستهلاك',
        ChartPalette.consumption,
        series.consumptionKwh,
        series.consumptionSharePercent,
      ),
      _LabelledSegment(
        'البطارية',
        ChartPalette.battery,
        series.batteryInKwh,
        series.batterySharePercent,
      ),
      _LabelledSegment(
        'الشبكة',
        ChartPalette.grid,
        series.gridInKwh,
        series.gridSharePercent,
      ),
    ];
    final visible = raw.where((s) => s.kwh > 0.001).toList();
    if (visible.isEmpty) return const _EmptyBar();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 14,
          decoration: BoxDecoration(
            color: AppTheme.line.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Row(
              children: [
                for (final seg in visible)
                  Expanded(
                    flex: (seg.percent * 10).round().clamp(1, 1000),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            seg.color.withValues(alpha: 0.95),
                            seg.color.withValues(alpha: 0.78),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final seg in visible)
              _CompositionLabel(
                color: seg.color,
                label: seg.label,
                percent: seg.percent,
              ),
          ],
        ),
      ],
    );
  }
}

class _CompositionLabel extends StatelessWidget {
  const _CompositionLabel({
    required this.color,
    required this.label,
    required this.percent,
  });

  final Color color;
  final String label;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${percent.toStringAsFixed(0)}%',
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _LabelledSegment {
  const _LabelledSegment(this.label, this.color, this.kwh, this.percent);
  final String label;
  final Color color;
  final double kwh;
  final double percent;
}

/// 2×2 grid of hero stat tiles — matches the SolarDeye notifications
/// screen card language: pale tinted surface, large bold value, label
/// underneath, glyph badge floating in the leading-top corner.
///
/// The four tiles are: production / consumption / battery-in / grid-
/// in. Peak solar W is intentionally omitted here because it's a
/// power measurement (W, not kWh) and would create a unit mismatch
/// with the surrounding tiles; if a user wants the W peak they see
/// it in the chart tooltip / hero metric area.
class _HeroTilesGrid extends StatelessWidget {
  const _HeroTilesGrid({required this.series});
  final EnergyChartSeries series;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _HeroStatTile(
                tone: const _TileTone(
                  surface: Color(0xFFECFDF5), // mint cream
                  border: Color(0xFFA7F3D0),
                  icon: Color(0xFF059669),
                ),
                icon: Icons.wb_sunny_outlined,
                label: 'الإنتاج',
                value: _kwhValue(series.productionKwh),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HeroStatTile(
                tone: const _TileTone(
                  surface: Color(0xFFFFFBEB), // warm cream
                  border: Color(0xFFFDE68A),
                  icon: Color(0xFFD97706),
                ),
                icon: Icons.bolt_outlined,
                label: 'الاستهلاك',
                value: _kwhValue(series.consumptionKwh),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _HeroStatTile(
                tone: const _TileTone(
                  surface: Color(0xFFF0F9FF), // sky cream
                  border: Color(0xFFBAE6FD),
                  icon: Color(0xFF0284C7),
                ),
                icon: Icons.battery_charging_full_outlined,
                label: 'إلى البطارية',
                value: _kwhValue(series.batteryInKwh),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HeroStatTile(
                tone: const _TileTone(
                  surface: Color(0xFFFAF5FF), // violet cream
                  border: Color(0xFFE9D5FF),
                  icon: Color(0xFF7C3AED),
                ),
                icon: Icons.cable_outlined,
                label: 'من الشبكة',
                value: _kwhValue(series.gridInKwh),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static _TileValue _kwhValue(double v) {
    if (v < 0.001) return const _TileValue.empty();
    if (v >= 1000) {
      return _TileValue(numeral: v.toStringAsFixed(0), unit: 'kWh');
    }
    if (v >= 100) {
      return _TileValue(numeral: v.toStringAsFixed(0), unit: 'kWh');
    }
    if (v >= 10) {
      return _TileValue(numeral: v.toStringAsFixed(1), unit: 'kWh');
    }
    return _TileValue(numeral: v.toStringAsFixed(2), unit: 'kWh');
  }
}

class _TileTone {
  const _TileTone({
    required this.surface,
    required this.border,
    required this.icon,
  });
  final Color surface;
  final Color border;
  final Color icon;
}

class _TileValue {
  const _TileValue({required this.numeral, required this.unit});
  const _TileValue.empty()
      : numeral = '—',
        unit = '';
  final String numeral;
  final String unit;
  bool get isEmpty => numeral == '—';
}

class _HeroStatTile extends StatelessWidget {
  const _HeroStatTile({
    required this.tone,
    required this.icon,
    required this.label,
    required this.value,
  });

  final _TileTone tone;
  final IconData icon;
  final String label;
  final _TileValue value;

  @override
  Widget build(BuildContext context) {
    // v99d — distinct glossy card with crisp border, multi-layer
    // shadow + a gradient surface so each tile reads as its own
    // surface and never blends into a neighbour. The icon is now
    // a filled gradient glyph (instead of an outlined one in a
    // soft square) so the tone token reads on the icon itself.
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            tone.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.border, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: tone.icon.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row — label on leading edge, floating glyph badge on
          // trailing edge.
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: tone.icon,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tone.icon,
                      tone.icon.withValues(alpha: 0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: tone.icon.withValues(alpha: 0.42),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Big numeral + small unit — the headline of the tile.
          if (value.isEmpty)
            Text(
              '—',
              style: TextStyle(
                color: AppTheme.faintMuted.withValues(alpha: 0.7),
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value.numeral,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -0.3,
                  ),
                ),
                if (value.unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Text(
                    value.unit,
                    style: TextStyle(
                      color: AppTheme.faintMuted
                          .withValues(alpha: 0.95),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyBar extends StatelessWidget {
  const _EmptyBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: AppTheme.line.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: const Text(
        'لا يوجد توزيع لهذه الفترة',
        style: TextStyle(
          color: AppTheme.faintMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
