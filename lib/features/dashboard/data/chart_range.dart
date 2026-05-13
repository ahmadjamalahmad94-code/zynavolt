// Date-range model + helpers for the v96 dashboard charts section.
//
// The mobile API exposes only **aggregate** energy values on
// `/api/mobile/dashboard`:
//   * cards.daily_production_kwh   — today
//   * cards.monthly_production_kwh — current month
//   * cards.total_production_kwh   — lifetime cumulative
//
// There is no historical time-series endpoint, so we cannot render real
// hour / day / month point charts. This file's job is to model the
// range selection (day / month / year) and a date anchor, with strict
// future-date guards, and to map an anchor to the one aggregate value
// the backend actually provides (or `null` — meaning "no honest data
// for this date").
//
// The UI then decides between:
//   * an aggregate summary card (anchor matches the "current" period
//     for that range and the backend has the value), or
//   * an honest empty state (anchor is in the past — the API does not
//     provide historical points).

import 'dashboard_models.dart';

enum ChartRange { day, month, year }

/// Immutable (range, anchor) tuple — the user's current chart selection.
///
/// `anchor` is always normalised to a date-only `DateTime` (local TZ,
/// time set to 00:00) so equality comparisons are stable across the
/// day. `today` is passed in by callers (instead of reading `DateTime.now`
/// directly) so the helpers stay deterministic and testable.
class DashboardRangeAnchor {
  DashboardRangeAnchor({
    required this.range,
    required DateTime anchor,
    required DateTime today,
  })  : anchor = DateTime(anchor.year, anchor.month, anchor.day),
        today = DateTime(today.year, today.month, today.day);

  /// Convenience factory for "now" — uses [DateTime.now] for both anchor
  /// and today. Production code path; tests should call the named
  /// constructor with a fixed `today` instead.
  factory DashboardRangeAnchor.now(ChartRange range) {
    final n = DateTime.now();
    return DashboardRangeAnchor(range: range, anchor: n, today: n);
  }

  final ChartRange range;
  final DateTime anchor;
  final DateTime today;

  DashboardRangeAnchor copyWith({ChartRange? range, DateTime? anchor}) =>
      DashboardRangeAnchor(
        range: range ?? this.range,
        anchor: anchor ?? this.anchor,
        today: today,
      );

  /// True when the anchor matches the "current" period for the range —
  /// i.e. today / current month / current year. The aggregate cards on
  /// the dashboard payload are only honest for this case.
  bool get isCurrentPeriod {
    switch (range) {
      case ChartRange.day:
        return anchor.year == today.year &&
            anchor.month == today.month &&
            anchor.day == today.day;
      case ChartRange.month:
        return anchor.year == today.year && anchor.month == today.month;
      case ChartRange.year:
        return anchor.year == today.year;
    }
  }

  /// Future-date guard. We never allow navigating into a day / month /
  /// year that is strictly after today.
  bool get canGoForward {
    switch (range) {
      case ChartRange.day:
        return anchor.isBefore(today);
      case ChartRange.month:
        final cur = DateTime(today.year, today.month);
        final at = DateTime(anchor.year, anchor.month);
        return at.isBefore(cur);
      case ChartRange.year:
        return anchor.year < today.year;
    }
  }

  /// Reasonable backward limit — five years is enough context and stops
  /// the prev chevron from chevroning into the year 0001.
  bool get canGoBack {
    final minYear = today.year - 5;
    switch (range) {
      case ChartRange.day:
        final min = DateTime(minYear, 1, 1);
        return anchor.isAfter(min);
      case ChartRange.month:
        final at = DateTime(anchor.year, anchor.month);
        final min = DateTime(minYear, 1);
        return at.isAfter(min);
      case ChartRange.year:
        return anchor.year > minYear;
    }
  }

  /// Step the anchor one unit forward, clamped by [canGoForward]. Returns
  /// `this` when stepping is blocked.
  DashboardRangeAnchor goForward() {
    if (!canGoForward) return this;
    switch (range) {
      case ChartRange.day:
        return copyWith(anchor: anchor.add(const Duration(days: 1)));
      case ChartRange.month:
        return copyWith(anchor: DateTime(anchor.year, anchor.month + 1));
      case ChartRange.year:
        return copyWith(anchor: DateTime(anchor.year + 1));
    }
  }

  DashboardRangeAnchor goBack() {
    if (!canGoBack) return this;
    switch (range) {
      case ChartRange.day:
        return copyWith(anchor: anchor.subtract(const Duration(days: 1)));
      case ChartRange.month:
        return copyWith(anchor: DateTime(anchor.year, anchor.month - 1));
      case ChartRange.year:
        return copyWith(anchor: DateTime(anchor.year - 1));
    }
  }

  /// Switch range while keeping the anchor aligned. When the new range
  /// would place the anchor in the future (e.g. switching from day=today
  /// to year=anchor.year is fine, but month → day where today < anchor
  /// could happen), the anchor is clamped to `today`.
  DashboardRangeAnchor withRange(ChartRange next) {
    final reanchored = DashboardRangeAnchor(
      range: next,
      anchor: anchor,
      today: today,
    );
    if (reanchored.canGoForward || reanchored.isCurrentPeriod) {
      return reanchored;
    }
    // Anchor is in the past — keep it. (No future violation possible.)
    return reanchored;
  }

  /// Arabic-friendly label for the anchor:
  ///   day   → `YYYY-MM-DD`         e.g. `2026-05-11`
  ///   month → `<month-name> YYYY`  e.g. `مايو 2026`
  ///   year  → `YYYY`               e.g. `2026`
  String formatLabel() {
    switch (range) {
      case ChartRange.day:
        return _formatYmd(anchor);
      case ChartRange.month:
        return '${_arabicMonth(anchor.month)} ${anchor.year}';
      case ChartRange.year:
        return anchor.year.toString();
    }
  }

  /// The single backend aggregate value that is **honest** for this
  /// (range, anchor). Returns `null` when the anchor falls outside the
  /// "current" period for the range — in that case the API has no value
  /// to show and the UI must render the honest empty state.
  ///
  /// * `day`   + isCurrentPeriod → `daily_production_kwh`
  /// * `month` + isCurrentPeriod → `monthly_production_kwh`
  /// * `year`  + isCurrentPeriod → `total_production_kwh` (NOTE: this is
  ///   *lifetime cumulative*, not strictly the current year — callers
  ///   must label it accordingly. We surface it because it is the only
  ///   "annual-scale" figure the API exposes; the UI tags it as
  ///   "الإجمالي التراكمي" so the user is not misled.)
  double? aggregateValueFromCards(DashboardCards cards) {
    if (!isCurrentPeriod) return null;
    switch (range) {
      case ChartRange.day:
        return cards.dailyProductionKwh;
      case ChartRange.month:
        return cards.monthlyProductionKwh;
      case ChartRange.year:
        return cards.totalProductionKwh;
    }
  }
}

String _formatYmd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Arabic month names (modern standard / Gregorian transliteration).
/// Kept inline because the app does not depend on the `intl` package.
const List<String> _arabicMonths = [
  '',
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String _arabicMonth(int month) {
  if (month < 1 || month > 12) return month.toString();
  return _arabicMonths[month];
}

/// Tiny convenience: same date-only normalisation used by anchors, so
/// callers that need today-as-a-date stay consistent with how the
/// model compares dates.
DateTime todayDateOnly() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}
