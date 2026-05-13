import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/charts/data/energy_chart_models.dart';
import 'package:solardeye_mobile/features/charts/data/energy_chart_repository.dart';
import 'package:solardeye_mobile/features/statistics/data/statistics_models.dart';

void main() {
  group('ChartScope', () {
    test('day and month are supported, year and total are not', () {
      expect(ChartScope.day.isSupported, isTrue);
      expect(ChartScope.month.isSupported, isTrue);
      expect(ChartScope.year.isSupported, isFalse);
      expect(ChartScope.total.isSupported, isFalse);
    });

    test('apiView returns the correct query value for supported scopes', () {
      expect(ChartScope.day.apiView, 'day');
      expect(ChartScope.month.apiView, 'month');
    });

    test('apiView throws for unsupported scopes so we never silently fake data',
        () {
      expect(() => ChartScope.year.apiView, throwsStateError);
      expect(() => ChartScope.total.apiView, throwsStateError);
    });

    test('arabicLabel covers all four scopes', () {
      expect(ChartScope.day.arabicLabel, 'يوم');
      expect(ChartScope.month.arabicLabel, 'شهر');
      expect(ChartScope.year.arabicLabel, 'سنة');
      expect(ChartScope.total.arabicLabel, 'الإجمالي');
    });
  });

  group('EnergyChartSeries.fromStatistics', () {
    test('maps a day-view payload into samples + totals', () {
      final snap = StatisticsSnapshot.fromJson(const {
        'view': 'day',
        'anchor': '2026-05-12',
        'title_hint': 'يوم 2026-05-12',
        'totals': {
          'production_kwh': 12.4,
          'consumption_kwh': 9.8,
          'battery_in_kwh': 3.0,
          'grid_in_kwh': 1.2,
          'avg_battery_soc': 64.0,
          'max_solar_w': 1820.0,
          'samples': 96,
          'data_gaps': 0,
        },
        'buckets': {
          'labels': ['08:00', '09:00', '10:00'],
          'production_kwh': [0.4, 1.1, 2.3],
          'consumption_kwh': [0.6, 0.9, 1.0],
        },
        'empty': false,
        'generated_at': '2026-05-12T11:00:00',
      });
      final s = EnergyChartSeries.fromStatistics(
        snap,
        scope: ChartScope.day,
        anchor: '2026-05-12',
      );

      expect(s.samples.length, 3);
      expect(s.samples.first.label, '08:00');
      expect(s.samples.first.productionKwh, 0.4);
      expect(s.samples.first.consumptionKwh, 0.6);
      expect(s.productionKwh, 12.4);
      expect(s.consumptionKwh, 9.8);
      expect(s.batteryInKwh, 3.0);
      expect(s.gridInKwh, 1.2);
      expect(s.avgSocPercent, 64.0);
      expect(s.maxSolarW, 1820.0);
      expect(s.empty, isFalse);
      expect(s.scope, ChartScope.day);
    });

    test('mismatched bucket lengths degrade to the shortest array', () {
      // Defensive: even if the server ever shipped uneven arrays, the
      // mapper picks the shortest count so the chart never indexes
      // past the end of one of the lists.
      final snap = StatisticsSnapshot.fromJson(const {
        'view': 'day',
        'buckets': {
          'labels': ['08:00', '09:00', '10:00'],
          'production_kwh': [0.4, 1.1],
          'consumption_kwh': [0.6, 0.9, 1.0, 1.3],
        },
      });
      final s = EnergyChartSeries.fromStatistics(
        snap,
        scope: ChartScope.day,
        anchor: '2026-05-12',
      );
      expect(s.samples.length, 2);
    });

    test('empty=true on the snapshot or empty buckets surfaces empty=true', () {
      final emptyFlag = StatisticsSnapshot.fromJson(const {
        'view': 'day',
        'buckets': {'labels': [], 'production_kwh': [], 'consumption_kwh': []},
        'empty': true,
      });
      expect(
        EnergyChartSeries.fromStatistics(
          emptyFlag,
          scope: ChartScope.day,
          anchor: '2026-05-12',
        ).empty,
        isTrue,
      );

      // Even if the backend forgets to set `empty=true`, an entirely
      // empty bucket payload still degrades to `empty=true` on the
      // chart series so the UI hides the curve gracefully.
      final emptyBuckets = StatisticsSnapshot.fromJson(const {
        'view': 'day',
        'buckets': {'labels': [], 'production_kwh': [], 'consumption_kwh': []},
      });
      expect(
        EnergyChartSeries.fromStatistics(
          emptyBuckets,
          scope: ChartScope.day,
          anchor: '2026-05-12',
        ).empty,
        isTrue,
      );
    });

    test('peakKwh returns the max across both visible series', () {
      final snap = StatisticsSnapshot.fromJson(const {
        'buckets': {
          'labels': ['a', 'b', 'c'],
          'production_kwh': [0.5, 1.5, 3.2],
          'consumption_kwh': [0.7, 2.4, 1.1],
        },
      });
      final s = EnergyChartSeries.fromStatistics(
        snap,
        scope: ChartScope.day,
        anchor: '2026-05-12',
      );
      expect(s.peakKwh, 3.2);
    });

    test('peakKwh is 0 when no samples exist', () {
      final snap = StatisticsSnapshot.fromJson(const {
        'buckets': {'labels': [], 'production_kwh': [], 'consumption_kwh': []},
      });
      expect(
        EnergyChartSeries.fromStatistics(
          snap,
          scope: ChartScope.day,
          anchor: '2026-05-12',
        ).peakKwh,
        0.0,
      );
    });

    test('split share percentages clamp to [0, 100] and reflect totals', () {
      final snap = StatisticsSnapshot.fromJson(const {
        'totals': {
          'production_kwh': 10.0,
          'consumption_kwh': 8.0,
          'battery_in_kwh': 1.0,
          'grid_in_kwh': 1.0,
          'samples': 24,
        },
        'buckets': {
          'labels': ['x'],
          'production_kwh': [1.0],
          'consumption_kwh': [0.5],
        },
      });
      final s = EnergyChartSeries.fromStatistics(
        snap,
        scope: ChartScope.day,
        anchor: '2026-05-12',
      );
      // Denominator = 10 + 8 + 1 + 1 = 20.
      expect(s.productionSharePercent, closeTo(50.0, 0.0001));
      expect(s.consumptionSharePercent, closeTo(40.0, 0.0001));
      expect(s.batterySharePercent, closeTo(5.0, 0.0001));
      expect(s.gridSharePercent, closeTo(5.0, 0.0001));
    });

    test('all-zero totals keep shares numerically stable', () {
      // The internal denominator is floored at 0.01 so division stays
      // safe — but every share still rounds to ~0%, never NaN/inf.
      final snap = StatisticsSnapshot.fromJson(const {
        'totals': {
          'production_kwh': 0.0,
          'consumption_kwh': 0.0,
          'battery_in_kwh': 0.0,
          'grid_in_kwh': 0.0,
          'samples': 0,
        },
        'buckets': {'labels': [], 'production_kwh': [], 'consumption_kwh': []},
      });
      final s = EnergyChartSeries.fromStatistics(
        snap,
        scope: ChartScope.day,
        anchor: '2026-05-12',
      );
      expect(s.productionSharePercent.isFinite, isTrue);
      expect(s.consumptionSharePercent.isFinite, isTrue);
      expect(s.productionSharePercent, lessThan(1));
      expect(s.consumptionSharePercent, lessThan(1));
    });
  });

  group('EnergyChartQuery (via toStatisticsQuery)', () {
    // The repository delegates to the existing `statisticsProvider`
    // family — quick sanity check that the mapping preserves the
    // identity tuple so caching stays effective across mounts.
    test('preserves deviceId / view / anchor', () {
      const q = EnergyChartQuery(
        deviceId: 42,
        scope: ChartScope.month,
        anchor: '2026-05-01',
      );
      final s = q.toStatisticsQuery();
      expect(s.deviceId, 42);
      expect(s.view, 'month');
      expect(s.anchor, '2026-05-01');
    });

    test('equality + hashCode are value-based', () {
      const a = EnergyChartQuery(
        deviceId: 1,
        scope: ChartScope.day,
        anchor: '2026-05-12',
      );
      const b = EnergyChartQuery(
        deviceId: 1,
        scope: ChartScope.day,
        anchor: '2026-05-12',
      );
      const c = EnergyChartQuery(
        deviceId: 1,
        scope: ChartScope.month,
        anchor: '2026-05-12',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}
