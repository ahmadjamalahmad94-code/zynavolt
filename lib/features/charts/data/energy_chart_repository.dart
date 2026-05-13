// v77 — chart data provider.
//
// Thin adapter that wraps the existing `statisticsProvider` family. We
// intentionally do not introduce a new HTTP path or a new endpoint
// contract — the v56 statistics endpoint already serves the per-bucket
// arrays + period totals we need, and reusing it keeps cache
// invalidation and refresh semantics consistent with the standalone
// Statistics screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../statistics/data/statistics_repository.dart';
import 'energy_chart_models.dart';

/// Stable family key for the chart provider. Pairs the underlying
/// statistics query with the chart's UI-facing scope so the provider
/// can refuse to fetch unsupported scopes honestly (year / total).
class EnergyChartQuery {
  const EnergyChartQuery({
    required this.deviceId,
    required this.scope,
    required this.anchor,
  });

  final int deviceId;
  final ChartScope scope;
  final String anchor;

  StatisticsQuery toStatisticsQuery() => StatisticsQuery(
        deviceId: deviceId,
        view: scope.apiView,
        anchor: anchor,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EnergyChartQuery &&
          other.deviceId == deviceId &&
          other.scope == scope &&
          other.anchor == anchor);

  @override
  int get hashCode => Object.hash(deviceId, scope, anchor);
}

/// Future provider that returns a chart-shaped derivation of the
/// underlying statistics snapshot. Throws an `UnsupportedError` for
/// scopes the backend doesn't serve — the UI gates on
/// [ChartScope.isSupported] before reading this provider, so this is
/// strictly a safety net for accidental misuse.
final energyChartSeriesProvider =
    FutureProvider.family<EnergyChartSeries, EnergyChartQuery>((ref, q) async {
  if (!q.scope.isSupported) {
    throw UnsupportedError(
      'Chart scope "${q.scope.name}" is not backed by a real backend '
      'endpoint yet — the UI must keep that chip disabled.',
    );
  }
  final snapshot = await ref.watch(
    statisticsProvider(q.toStatisticsQuery()).future,
  );
  return EnergyChartSeries.fromStatistics(
    snapshot,
    scope: q.scope,
    anchor: q.anchor,
  );
});
