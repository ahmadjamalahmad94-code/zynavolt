import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/reports/data/reports_models.dart';

void main() {
  group('ReportsSnapshot.fromJson', () {
    test('parses a complete day-view payload', () {
      final s = ReportsSnapshot.fromJson(const {
        'view': 'day',
        'anchor': '2026-05-12',
        'title_hint': 'يوم 2026-05-12',
        'summary': {
          'production_kwh': 10.0,
          'consumption_kwh': 10.0,
          'battery_in_kwh': 4.0,
          'grid_in_kwh': 2.0,
          'solar_share_percent': 60.0,
          'battery_share_percent': 20.0,
          'grid_share_percent': 20.0,
          'self_sufficiency_percent': 80.0,
          'average_load_w': 100.0,
          'solar_surplus_kwh': 4.0,
        },
        'empty': false,
        'generated_at': '2026-05-12T10:00:00',
      });

      expect(s.view, 'day');
      expect(s.anchor, '2026-05-12');
      expect(s.titleHint, 'يوم 2026-05-12');
      expect(s.empty, isFalse);
      expect(s.generatedAt, '2026-05-12T10:00:00');

      expect(s.summary.productionKwh, 10.0);
      expect(s.summary.consumptionKwh, 10.0);
      expect(s.summary.batteryInKwh, 4.0);
      expect(s.summary.gridInKwh, 2.0);
      expect(s.summary.solarSharePercent, 60.0);
      expect(s.summary.batterySharePercent, 20.0);
      expect(s.summary.gridSharePercent, 20.0);
      expect(s.summary.selfSufficiencyPercent, 80.0);
      expect(s.summary.averageLoadW, 100.0);
      expect(s.summary.solarSurplusKwh, 4.0);
    });

    test('parses a month-view payload with year-month anchor', () {
      final s = ReportsSnapshot.fromJson(const {
        'view': 'month',
        'anchor': '2026-05',
        'title_hint': 'شهر 2026-05',
        'summary': {
          'production_kwh': 145.6,
          'consumption_kwh': 128.4,
          'battery_in_kwh': 35.0,
          'grid_in_kwh': 13.4,
          'solar_share_percent': 70.0,
          'battery_share_percent': 19.0,
          'grid_share_percent': 11.0,
          'self_sufficiency_percent': 89.0,
          'average_load_w': 53.5,
          'solar_surplus_kwh': 55.6,
        },
        'empty': false,
        'generated_at': '2026-05-12T10:00:00',
      });
      expect(s.view, 'month');
      expect(s.anchor, '2026-05');
      expect(s.summary.productionKwh, 145.6);
      expect(s.summary.solarSurplusKwh, 55.6);
      expect(s.summary.averageLoadW, 53.5);
    });

    test('honest empty payload zeroes every derived metric', () {
      // Mirrors what the v59 backend returns when there are no
      // readings in the period: every metric is 0.0 and empty=true.
      final s = ReportsSnapshot.fromJson(const {
        'view': 'day',
        'anchor': '2026-05-12',
        'title_hint': 'يوم 2026-05-12',
        'summary': {
          'production_kwh': 0.0,
          'consumption_kwh': 0.0,
          'battery_in_kwh': 0.0,
          'grid_in_kwh': 0.0,
          'solar_share_percent': 0.0,
          'battery_share_percent': 0.0,
          'grid_share_percent': 0.0,
          // Honest empty: NOT 100% self-sufficiency.
          'self_sufficiency_percent': 0.0,
          'average_load_w': 0.0,
          'solar_surplus_kwh': 0.0,
        },
        'empty': true,
        'generated_at': '2026-05-12T10:00:00',
      });
      expect(s.empty, isTrue);
      expect(s.summary.productionKwh, 0.0);
      expect(s.summary.selfSufficiencyPercent, 0.0);
      expect(s.summary.solarSurplusKwh, 0.0);
    });

    test('completely missing payload yields a calm snapshot, not an exception',
        () {
      final s = ReportsSnapshot.fromJson(const {});
      expect(s.view, 'day'); // safe fallback
      expect(s.anchor, '');
      expect(s.titleHint, '');
      expect(s.empty, isFalse); // backend explicit flag only
      expect(s.summary.productionKwh, 0.0);
      expect(s.summary.selfSufficiencyPercent, 0.0);
    });

    test('coerces stringified numbers + null defensively', () {
      final s = ReportsSnapshot.fromJson(const {
        'view': 'DAY',
        'anchor': '2026-05-12',
        'summary': {
          'production_kwh': '4.2',
          'consumption_kwh': null,
          'self_sufficiency_percent': '80',
          'average_load_w': '',
        },
        'empty': false,
      });
      expect(s.view, 'day'); // normalised
      expect(s.summary.productionKwh, 4.2);
      expect(s.summary.consumptionKwh, 0.0);
      expect(s.summary.selfSufficiencyPercent, 80.0);
      expect(s.summary.averageLoadW, 0.0);
    });

    test('unknown view values fall back to day', () {
      final s = ReportsSnapshot.fromJson(const {'view': 'year'});
      expect(s.view, 'day');
    });

    test('view "MONTH" with extra whitespace normalises to month', () {
      final s = ReportsSnapshot.fromJson(const {'view': '  MONTH  '});
      expect(s.view, 'month');
    });
  });

  group('ReportsSummary', () {
    test('empty() exposes a calm zero state', () {
      final s = ReportsSummary.empty();
      expect(s.productionKwh, 0);
      expect(s.consumptionKwh, 0);
      expect(s.batteryInKwh, 0);
      expect(s.gridInKwh, 0);
      expect(s.solarSharePercent, 0);
      expect(s.batterySharePercent, 0);
      expect(s.gridSharePercent, 0);
      expect(s.selfSufficiencyPercent, 0);
      expect(s.averageLoadW, 0);
      expect(s.solarSurplusKwh, 0);
    });

    test('fromJson on null/missing summary block yields zeroes', () {
      final s = ReportsSummary.fromJson(null);
      expect(s.productionKwh, 0);
      expect(s.solarSurplusKwh, 0);
    });
  });
}
