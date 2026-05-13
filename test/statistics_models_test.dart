import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/statistics/data/statistics_models.dart';

void main() {
  group('StatisticsSnapshot.fromJson', () {
    test('parses a complete day-view payload', () {
      final s = StatisticsSnapshot.fromJson(const {
        'view': 'day',
        'anchor': '2026-05-12',
        'title_hint': 'يوم 2026-05-12',
        'totals': {
          'production_kwh': 4.2,
          'consumption_kwh': 3.1,
          'battery_in_kwh': 0.8,
          'grid_in_kwh': 0.4,
          'avg_battery_soc': 55.5,
          'max_solar_w': 2100.0,
          'samples': 12,
          'data_gaps': 1,
        },
        'buckets': {
          'labels': ['09:00', '10:00', '11:00'],
          'production_kwh': [0.6, 1.5, 2.0],
          'consumption_kwh': [0.4, 0.8, 1.2],
        },
        'empty': false,
        'generated_at': '2026-05-12T10:00:00',
      });
      expect(s.view, 'day');
      expect(s.anchor, '2026-05-12');
      expect(s.titleHint, 'يوم 2026-05-12');
      expect(s.empty, isFalse);
      expect(s.generatedAt, '2026-05-12T10:00:00');

      expect(s.totals.productionKwh, 4.2);
      expect(s.totals.consumptionKwh, 3.1);
      expect(s.totals.batteryInKwh, 0.8);
      expect(s.totals.gridInKwh, 0.4);
      expect(s.totals.avgBatterySocPercent, 55.5);
      expect(s.totals.maxSolarW, 2100.0);
      expect(s.totals.samples, 12);
      expect(s.totals.dataGaps, 1);

      expect(s.buckets.labels, ['09:00', '10:00', '11:00']);
      expect(s.buckets.productionKwh, [0.6, 1.5, 2.0]);
      expect(s.buckets.consumptionKwh, [0.4, 0.8, 1.2]);
      expect(s.buckets.isEmpty, isFalse);
    });

    test('parses a month-view payload with year-month anchor', () {
      final s = StatisticsSnapshot.fromJson(const {
        'view': 'month',
        'anchor': '2026-05',
        'title_hint': 'شهر 2026-05',
        'totals': {
          'production_kwh': 145.6,
          'consumption_kwh': 128.4,
          'samples': 2400,
        },
        'buckets': {
          'labels': ['05/01', '05/02'],
          'production_kwh': [5.2, 4.8],
          'consumption_kwh': [4.5, 4.2],
        },
        'empty': false,
        'generated_at': '2026-05-12T10:00:00',
      });
      expect(s.view, 'month');
      expect(s.anchor, '2026-05');
      expect(s.titleHint, 'شهر 2026-05');
      expect(s.totals.productionKwh, 145.6);
      expect(s.buckets.labels, ['05/01', '05/02']);
    });

    test('empty payload yields a calm snapshot, not an exception', () {
      final s = StatisticsSnapshot.fromJson(const {});
      // Falls back to day view so the screen always renders something.
      expect(s.view, 'day');
      expect(s.anchor, '');
      expect(s.titleHint, '');
      expect(s.empty, isFalse); // backend explicit `empty` only
      expect(s.totals.productionKwh, 0);
      expect(s.totals.samples, 0);
      expect(s.buckets.isEmpty, isTrue);
    });

    test('coerces stringified numbers + null values defensively', () {
      final s = StatisticsSnapshot.fromJson(const {
        'view': 'DAY',
        'anchor': '2026-05-12',
        'totals': {
          'production_kwh': '4.2',
          'consumption_kwh': null,
          'samples': '12',
        },
        'buckets': {
          'labels': ['09:00', null],
          'production_kwh': ['0.6', null],
          'consumption_kwh': [0.4, 0.8],
        },
        'empty': false,
      });
      expect(s.view, 'day'); // normalised
      expect(s.totals.productionKwh, 4.2);
      expect(s.totals.consumptionKwh, 0.0);
      expect(s.totals.samples, 12);
      expect(s.buckets.labels, ['09:00', '']);
      expect(s.buckets.productionKwh, [0.6, 0.0]);
    });

    test('unknown view values fall back to day', () {
      final s = StatisticsSnapshot.fromJson(const {'view': 'year'});
      expect(s.view, 'day');
    });

    test('empty=true respected even when buckets carry residue', () {
      final s = StatisticsSnapshot.fromJson(const {
        'view': 'day',
        'totals': {'samples': 0},
        'buckets': {
          'labels': [],
          'production_kwh': [],
          'consumption_kwh': [],
        },
        'empty': true,
      });
      expect(s.empty, isTrue);
      expect(s.totals.samples, 0);
      expect(s.buckets.isEmpty, isTrue);
    });
  });

  group('StatisticsBuckets.isEmpty', () {
    test('true when every array is empty', () {
      final b = StatisticsBuckets.empty();
      expect(b.isEmpty, isTrue);
    });

    test('false as soon as any array has content', () {
      final b = StatisticsBuckets(
        labels: const ['09:00'],
        productionKwh: const [],
        consumptionKwh: const [],
      );
      expect(b.isEmpty, isFalse);
    });
  });

  group('StatisticsTotals defaults', () {
    test('empty() exposes a calm zero state', () {
      final t = StatisticsTotals.empty();
      expect(t.productionKwh, 0);
      expect(t.consumptionKwh, 0);
      expect(t.batteryInKwh, 0);
      expect(t.gridInKwh, 0);
      expect(t.avgBatterySocPercent, 0);
      expect(t.maxSolarW, 0);
      expect(t.samples, 0);
      expect(t.dataGaps, 0);
    });
  });
}
