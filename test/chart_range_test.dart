import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/dashboard/data/chart_range.dart';
import 'package:solardeye_mobile/features/dashboard/data/dashboard_models.dart';

void main() {
  // Fixed "today" so every assertion is deterministic regardless of when
  // the suite runs. 2026-05-11 matches the project's current real date.
  final today = DateTime(2026, 5, 11);

  DashboardRangeAnchor anchorAt(ChartRange range, DateTime at) =>
      DashboardRangeAnchor(range: range, anchor: at, today: today);

  group('formatLabel', () {
    test('day formats as YYYY-MM-DD', () {
      expect(
        anchorAt(ChartRange.day, DateTime(2026, 5, 11)).formatLabel(),
        '2026-05-11',
      );
      expect(
        anchorAt(ChartRange.day, DateTime(2025, 1, 3)).formatLabel(),
        '2025-01-03',
      );
    });

    test('month formats as <arabic month> YYYY', () {
      expect(
        anchorAt(ChartRange.month, DateTime(2026, 5, 11)).formatLabel(),
        'مايو 2026',
      );
      expect(
        anchorAt(ChartRange.month, DateTime(2026, 1, 1)).formatLabel(),
        'يناير 2026',
      );
      expect(
        anchorAt(ChartRange.month, DateTime(2025, 12, 31)).formatLabel(),
        'ديسمبر 2025',
      );
    });

    test('year formats as YYYY', () {
      expect(
        anchorAt(ChartRange.year, DateTime(2026, 5, 11)).formatLabel(),
        '2026',
      );
    });
  });

  group('isCurrentPeriod', () {
    test('day: only true for today', () {
      expect(anchorAt(ChartRange.day, today).isCurrentPeriod, isTrue);
      expect(
        anchorAt(ChartRange.day, today.subtract(const Duration(days: 1)))
            .isCurrentPeriod,
        isFalse,
      );
    });

    test('month: true for any day within current month', () {
      expect(
        anchorAt(ChartRange.month, DateTime(2026, 5, 1)).isCurrentPeriod,
        isTrue,
      );
      expect(
        anchorAt(ChartRange.month, DateTime(2026, 5, 30)).isCurrentPeriod,
        isTrue,
      );
      expect(
        anchorAt(ChartRange.month, DateTime(2026, 4, 30)).isCurrentPeriod,
        isFalse,
      );
    });

    test('year: true for any date within current year', () {
      expect(
        anchorAt(ChartRange.year, DateTime(2026, 1, 1)).isCurrentPeriod,
        isTrue,
      );
      expect(
        anchorAt(ChartRange.year, DateTime(2026, 12, 31)).isCurrentPeriod,
        isTrue,
      );
      expect(
        anchorAt(ChartRange.year, DateTime(2025, 12, 31)).isCurrentPeriod,
        isFalse,
      );
    });
  });

  group('future-date guard (canGoForward + goForward)', () {
    test('day: forward blocked at today', () {
      final atToday = anchorAt(ChartRange.day, today);
      expect(atToday.canGoForward, isFalse);
      expect(atToday.goForward().anchor, atToday.anchor);
    });

    test('day: forward allowed when anchor is before today', () {
      final past = anchorAt(
        ChartRange.day,
        today.subtract(const Duration(days: 3)),
      );
      expect(past.canGoForward, isTrue);
      expect(
        past.goForward().anchor,
        today.subtract(const Duration(days: 2)),
      );
    });

    test('month: forward blocked at current month', () {
      final atMonth = anchorAt(ChartRange.month, DateTime(2026, 5, 1));
      expect(atMonth.canGoForward, isFalse);
      expect(atMonth.goForward().anchor, atMonth.anchor);
    });

    test('month: forward steps to next month', () {
      final past = anchorAt(ChartRange.month, DateTime(2026, 3, 1));
      expect(past.canGoForward, isTrue);
      expect(past.goForward().anchor, DateTime(2026, 4, 1));
    });

    test('year: forward blocked at current year', () {
      final atYear = anchorAt(ChartRange.year, DateTime(2026, 5, 1));
      expect(atYear.canGoForward, isFalse);
    });

    test('year: forward steps to next year when in the past', () {
      final past = anchorAt(ChartRange.year, DateTime(2024, 5, 1));
      expect(past.canGoForward, isTrue);
      expect(past.goForward().anchor.year, 2025);
    });
  });

  group('goBack with backward limit', () {
    test('day: goBack steps one day', () {
      final a = anchorAt(ChartRange.day, today);
      expect(a.goBack().anchor, today.subtract(const Duration(days: 1)));
    });

    test('day: blocked 5 years back', () {
      final old = anchorAt(ChartRange.day, DateTime(2021, 1, 2));
      expect(old.canGoBack, isTrue);
      final older = anchorAt(ChartRange.day, DateTime(2021, 1, 1));
      // anchor == minDate → not strictly after, so blocked.
      expect(older.canGoBack, isFalse);
    });

    test('month: goBack rolls year boundary', () {
      final a = anchorAt(ChartRange.month, DateTime(2026, 1, 1));
      expect(a.goBack().anchor, DateTime(2025, 12, 1));
    });

    test('year: goBack steps one year', () {
      final a = anchorAt(ChartRange.year, DateTime(2026, 1, 1));
      expect(a.goBack().anchor.year, 2025);
    });
  });

  group('aggregateValueFromCards', () {
    final cards = DashboardCards(
      solarPowerW: 0,
      homeLoadW: 0,
      batterySocPercent: 0,
      batteryPowerW: 0,
      gridPowerW: 0,
      inverterPowerW: 0,
      dailyProductionKwh: 12.5,
      monthlyProductionKwh: 345.0,
      totalProductionKwh: 9876.5,
    );

    test('day=today returns daily kWh', () {
      expect(
        anchorAt(ChartRange.day, today).aggregateValueFromCards(cards),
        12.5,
      );
    });

    test('day in the past returns null (no historical API)', () {
      expect(
        anchorAt(ChartRange.day, DateTime(2026, 5, 10))
            .aggregateValueFromCards(cards),
        isNull,
      );
    });

    test('month=current returns monthly kWh', () {
      expect(
        anchorAt(ChartRange.month, DateTime(2026, 5, 1))
            .aggregateValueFromCards(cards),
        345.0,
      );
    });

    test('month in the past returns null', () {
      expect(
        anchorAt(ChartRange.month, DateTime(2026, 4, 1))
            .aggregateValueFromCards(cards),
        isNull,
      );
    });

    test('year=current returns total (lifetime) kWh', () {
      expect(
        anchorAt(ChartRange.year, DateTime(2026, 1, 1))
            .aggregateValueFromCards(cards),
        9876.5,
      );
    });

    test('year in the past returns null', () {
      expect(
        anchorAt(ChartRange.year, DateTime(2025, 1, 1))
            .aggregateValueFromCards(cards),
        isNull,
      );
    });
  });

  test('copyWith preserves today', () {
    final a = anchorAt(ChartRange.day, today);
    final b = a.copyWith(range: ChartRange.year);
    expect(b.today, today);
    expect(b.range, ChartRange.year);
    expect(b.anchor, today);
  });

  test('withRange keeps anchor but allows future-block to apply', () {
    final dayPast = anchorAt(ChartRange.day, DateTime(2026, 5, 10));
    final asMonth = dayPast.withRange(ChartRange.month);
    expect(asMonth.range, ChartRange.month);
    expect(asMonth.anchor, DateTime(2026, 5, 10));
    expect(asMonth.isCurrentPeriod, isTrue);
  });
}
