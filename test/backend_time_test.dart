import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/core/utils/backend_time.dart';

/// v97 shared backend time parser tests.
///
/// Guards the "naive ISO without `Z` is treated as UTC" contract. The
/// production backend serialises timestamps via `datetime.utcnow()`
/// + `.isoformat()`, which emits strings with no timezone designator.
/// Dart's bare `DateTime.tryParse` reads those as device-local, which
/// is exactly the bug v97 fixes app-wide.
void main() {
  group('parseBackendIso', () {
    test('returns null for null / empty / whitespace input', () {
      expect(parseBackendIso(null), isNull);
      expect(parseBackendIso(''), isNull);
      expect(parseBackendIso('   '), isNull);
    });

    test('naive ISO (no tz) is interpreted as UTC, not device-local', () {
      final dt = parseBackendIso('2026-05-11T10:00:00.123456');
      expect(dt, isNotNull);
      // The parsed instant must be a UTC instant, NOT a device-local one.
      expect(dt!.isUtc, isTrue);
      expect(dt.toUtc().hour, 10);
      expect(dt.toUtc().minute, 0);
      expect(dt.toUtc().year, 2026);
      expect(dt.toUtc().month, 5);
      expect(dt.toUtc().day, 11);
    });

    test('explicit Z is preserved as UTC', () {
      final dt = parseBackendIso('2026-05-11T10:00:00Z');
      expect(dt, isNotNull);
      expect(dt!.isUtc, isTrue);
      expect(dt.toUtc().hour, 10);
    });

    test('explicit +HH:MM offset is preserved (parses to UTC instant)', () {
      // 10:00 in Asia/Hebron (UTC+02:00) == 08:00 UTC. Dart returns
      // local-zoned by default; converting toUtc() gives the canonical
      // UTC instant we can assert on.
      final dt = parseBackendIso('2026-05-11T10:00:00+02:00');
      expect(dt, isNotNull);
      final utc = dt!.toUtc();
      expect(utc.hour, 8);
      expect(utc.minute, 0);
    });

    test('explicit ±HHMM (no colon) offset is also detected', () {
      final dt = parseBackendIso('2026-05-11T10:00:00+0200');
      expect(dt, isNotNull);
      expect(dt!.toUtc().hour, 8);
    });

    test('truly malformed string returns null', () {
      expect(parseBackendIso('not-a-date'), isNull);
      expect(parseBackendIso('hello world'), isNull);
      // NOTE: Dart's `DateTime.tryParse` is quirkily lenient — it
      // *accepts* overflowed components like `2026-99-99` and rolls
      // them forward into a valid date. We rely on the same upstream
      // behaviour, so we do not assert null on overflows here.
    });
  });

  group('formatBackendHm', () {
    test('null / empty input returns null', () {
      expect(formatBackendHm(null), isNull);
      expect(formatBackendHm(''), isNull);
    });

    test('naive UTC input renders the device-local clock, not raw UTC', () {
      // We can't assert an exact hour without knowing the test host's
      // timezone, but we CAN assert two facts:
      //   1. The output is HH:mm shape (5 chars, single colon).
      //   2. It's NOT a naive substring of the input — for any host
      //      whose offset is non-zero, the local hour differs from
      //      the UTC hour.
      final out = formatBackendHm('2026-05-11T10:00:00.123456');
      expect(out, isNotNull);
      expect(out!, matches(RegExp(r'^\d{2}:\d{2}$')));
      // Local offset can be zero on some CI hosts → guard the inequality.
      final offsetHours = DateTime.now().timeZoneOffset.inHours;
      if (offsetHours != 0) {
        expect(out, isNot('10:00'),
            reason:
                'formatBackendHm must convert UTC → device-local, '
                'not pass UTC clock through verbatim');
      }
    });
  });

  group('formatBackendDateTime / formatBackendDate', () {
    test('null returns null; empty returns null', () {
      expect(formatBackendDateTime(null), isNull);
      expect(formatBackendDateTime(''), isNull);
      expect(formatBackendDate(null), isNull);
      expect(formatBackendDate(''), isNull);
    });

    test('malformed input passes through (preserves v79 contract)', () {
      expect(formatBackendDateTime('not-a-date'), 'not-a-date');
      expect(formatBackendDate('not-a-date'), 'not-a-date');
    });

    test('valid input renders YYYY-MM-DD HH:mm shape', () {
      final out = formatBackendDateTime('2026-05-11T10:00:00');
      expect(out, isNotNull);
      expect(out, matches(RegExp(r'^\d{4}-\d{2}-\d{2}  \d{2}:\d{2}$')));
    });

    test('formatBackendDate renders YYYY-MM-DD only', () {
      final out = formatBackendDate('2026-05-11T10:00:00');
      expect(out, isNotNull);
      expect(out, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });
  });

  group('formatBackendExact', () {
    test('renders YYYY-MM-DD HH:mm:ss', () {
      final out = formatBackendExact('2026-05-11T10:15:30');
      expect(out, isNotNull);
      expect(out, matches(RegExp(r'^\d{4}-\d{2}-\d{2}  \d{2}:\d{2}:\d{2}$')));
    });

    test('null / empty returns null', () {
      expect(formatBackendExact(null), isNull);
      expect(formatBackendExact(''), isNull);
    });
  });

  group('formatBackendRelative', () {
    test('null / empty returns dash placeholder', () {
      expect(formatBackendRelative(null), '—');
      expect(formatBackendRelative(''), '—');
    });

    test('today produces HH:mm', () {
      // Construct an ISO that maps to the *same local day* as the
      // injected `now`. Using a UTC instant + a known device offset
      // is fragile across CI hosts, so we craft the iso from `now`
      // itself.
      final now = DateTime(2026, 5, 11, 14, 30);
      // The iso we feed in must, after UTC-aware parsing + toLocal,
      // land on today. The simplest stable construction: write a
      // UTC ISO that represents the same instant as `now.toUtc()`.
      final asUtc = now.toUtc();
      final iso = '${asUtc.year.toString().padLeft(4, '0')}-'
          '${asUtc.month.toString().padLeft(2, '0')}-'
          '${asUtc.day.toString().padLeft(2, '0')}T'
          '${asUtc.hour.toString().padLeft(2, '0')}:'
          '${asUtc.minute.toString().padLeft(2, '0')}:'
          '${asUtc.second.toString().padLeft(2, '0')}';
      final out = formatBackendRelative(iso, now: now);
      expect(out, matches(RegExp(r'^\d{2}:\d{2}$')));
    });

    test('older same-year produces MM-DD HH:mm shape', () {
      final now = DateTime(2026, 12, 15);
      final asUtc = DateTime.utc(2026, 5, 11, 14, 30);
      final iso =
          '${asUtc.year}-05-11T14:30:00';
      final out = formatBackendRelative(iso, now: now);
      // The exact local hour depends on the host TZ, but the
      // `MM-DD  HH:mm` shape must hold.
      expect(out, matches(RegExp(r'^\d{2}-\d{2}  \d{2}:\d{2}$')));
    });

    test('different year produces YYYY-MM-DD HH:mm shape', () {
      final now = DateTime(2026, 12, 15);
      final out = formatBackendRelative('2024-01-02T10:00:00', now: now);
      expect(out, matches(RegExp(r'^\d{4}-\d{2}-\d{2}  \d{2}:\d{2}$')));
    });
  });
}
