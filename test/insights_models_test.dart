import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/insights/data/insights_models.dart';

void main() {
  group('InsightsSnapshot.fromJson', () {
    test('parses a complete available payload', () {
      final s = InsightsSnapshot.fromJson(const {
        'available': true,
        'device': {
          'id': 42,
          'name': 'Roof Inverter',
          'timezone': 'Asia/Hebron',
        },
        'weather_context': {
          'condition_ar': 'غائم جزئيًا',
          'icon': '⛅',
          'cloud_cover_percent': 35.0,
        },
        'solar_prediction': {
          'sunset_time': '19:42',
          'effective_sunset_time': '18:42',
          'time_to_full_hours': 1.5,
          'will_full_before_sunset': true,
          'verdict': 'سيتم شحن البطارية قبل الغروب',
          'advice': 'الوضع جيد.',
        },
        'energy_advice': {
          'headline': '🟢 مطمئن',
          'detail': 'يمكن تشغيل الأحمال الخفيفة باعتدال.',
          'level': 'good',
        },
        'generated_at': '2026-05-12T10:00:00',
      });

      expect(s.available, isTrue);
      expect(s.device.id, 42);
      expect(s.device.name, 'Roof Inverter');
      expect(s.device.timezone, 'Asia/Hebron');

      expect(s.weatherContext, isNotNull);
      expect(s.weatherContext!.conditionAr, 'غائم جزئيًا');
      expect(s.weatherContext!.icon, '⛅');
      expect(s.weatherContext!.cloudCoverPercent, 35.0);
      expect(s.weatherContext!.isEmpty, isFalse);

      expect(s.solarPrediction, isNotNull);
      expect(s.solarPrediction!.sunsetTime, '19:42');
      expect(s.solarPrediction!.effectiveSunsetTime, '18:42');
      expect(s.solarPrediction!.timeToFullHours, 1.5);
      expect(s.solarPrediction!.willFullBeforeSunset, isTrue);
      expect(s.solarPrediction!.verdict, 'سيتم شحن البطارية قبل الغروب');
      expect(s.solarPrediction!.advice, 'الوضع جيد.');
      // v79: payload without explicit `is_night` / `sun_state` keys
      // defaults to a daytime view so older backends keep working.
      expect(s.solarPrediction!.isNight, isFalse);
      expect(s.solarPrediction!.sunState, 'day');

      expect(s.energyAdvice, isNotNull);
      expect(s.energyAdvice!.headline, '🟢 مطمئن');
      expect(s.energyAdvice!.detail, 'يمكن تشغيل الأحمال الخفيفة باعتدال.');
      expect(s.energyAdvice!.level, 'good');
      expect(s.energyAdvice!.isEmpty, isFalse);

      expect(s.reason, isNull);
      expect(s.message, isNull);
      expect(s.generatedAt, '2026-05-12T10:00:00');
    });

    test('unavailable payload preserves reason + device, drops blocks', () {
      final s = InsightsSnapshot.fromJson(const {
        'available': false,
        'reason': 'reading_unavailable',
        'message': 'No recent reading is available for this device yet.',
        'device': {
          'id': 7,
          'name': 'New Device',
          'timezone': '',
        },
        'generated_at': '2026-05-12T10:00:00',
      });

      expect(s.available, isFalse);
      expect(s.reason, 'reading_unavailable');
      expect(s.message,
          'No recent reading is available for this device yet.');
      expect(s.device.id, 7);
      // Locked: insight blocks must be null when unavailable.
      expect(s.weatherContext, isNull);
      expect(s.solarPrediction, isNull);
      expect(s.energyAdvice, isNull);
    });

    test('unavailable payload supports all three known reason codes', () {
      for (final reason in [
        'reading_unavailable',
        'station_coords_unavailable',
        'weather_unreachable',
      ]) {
        final s = InsightsSnapshot.fromJson({
          'available': false,
          'reason': reason,
          'message': 'Backend message $reason.',
          'device': {'id': 1, 'name': 'X', 'timezone': 'UTC'},
          'generated_at': '2026-05-12T10:00:00',
        });
        expect(s.available, isFalse);
        expect(s.reason, reason);
        expect(s.weatherContext, isNull);
      }
    });

    test('completely empty payload yields a safe snapshot, not an exception',
        () {
      final s = InsightsSnapshot.fromJson(const {});
      expect(s.available, isFalse);
      expect(s.reason, isNull);
      expect(s.message, isNull);
      expect(s.weatherContext, isNull);
      expect(s.solarPrediction, isNull);
      expect(s.energyAdvice, isNull);
      expect(s.device.id, 0);
      expect(s.device.name, '');
    });

    test('coerces stringified numbers + null fields defensively', () {
      final s = InsightsSnapshot.fromJson(const {
        'available': true,
        'device': {'id': '42', 'name': 'X', 'timezone': 'UTC'},
        'weather_context': {
          'condition_ar': '',
          'icon': '',
          'cloud_cover_percent': '35',
        },
        'solar_prediction': {
          'sunset_time': '',
          'effective_sunset_time': null,
          'time_to_full_hours': '1.5',
          'will_full_before_sunset': false,
          'verdict': null,
          'advice': '',
        },
        'energy_advice': {
          'headline': '🟢 مطمئن',
          'detail': '',
          'level': 'GOOD',
        },
        'generated_at': '2026-05-12T10:00:00',
      });
      expect(s.device.id, 42);
      // Empty string sunrise/verdict/advice normalise to null so the
      // UI can branch without checking length.
      expect(s.weatherContext!.cloudCoverPercent, 35.0);
      expect(s.solarPrediction!.sunsetTime, isNull);
      expect(s.solarPrediction!.effectiveSunsetTime, isNull);
      expect(s.solarPrediction!.timeToFullHours, 1.5);
      expect(s.solarPrediction!.verdict, isNull);
      expect(s.solarPrediction!.advice, isNull);
      // Level normalises case.
      expect(s.energyAdvice!.level, 'good');
    });

    test('unknown level value falls back to "unknown"', () {
      final s = InsightsSnapshot.fromJson(const {
        'available': true,
        'device': {'id': 1, 'name': 'X', 'timezone': 'UTC'},
        'energy_advice': {
          'headline': '?',
          'detail': '?',
          'level': 'speculative_future_code',
        },
      });
      expect(s.energyAdvice!.level, 'unknown');
    });

    test('empty / null inner blocks degrade to safe defaults', () {
      // `available=true` but with missing inner objects — should not
      // crash; the screen will show whatever is present and skip the
      // empty parts.
      final s = InsightsSnapshot.fromJson(const {
        'available': true,
        'device': {'id': 1, 'name': 'X', 'timezone': 'UTC'},
        'weather_context': null,
        'solar_prediction': null,
        'energy_advice': null,
      });
      expect(s.available, isTrue);
      // weather_context falls back to empty (isEmpty=true), not null.
      expect(s.weatherContext, isNotNull);
      expect(s.weatherContext!.isEmpty, isTrue);
      // solar_prediction / energy_advice come back null when the
      // map is null.
      expect(s.solarPrediction, isNull);
      expect(s.energyAdvice, isNull);
    });
  });

  group('InsightsWeatherContext.isEmpty', () {
    test('true when every field is empty/null', () {
      final w = InsightsWeatherContext.fromJson(const {});
      expect(w.isEmpty, isTrue);
    });

    test('false as soon as one field has content', () {
      expect(
        InsightsWeatherContext.fromJson(const {'icon': '☀️'}).isEmpty,
        isFalse,
      );
      expect(
        InsightsWeatherContext.fromJson(const {'condition_ar': 'مشمس'}).isEmpty,
        isFalse,
      );
      expect(
        InsightsWeatherContext.fromJson(const {'cloud_cover_percent': 0})
            .isEmpty,
        isFalse,
      );
    });
  });

  group('InsightsEnergyAdvice.isEmpty', () {
    test('true when both headline and detail are empty', () {
      final a = InsightsEnergyAdvice.fromJson(const {
        'headline': '',
        'detail': '',
        'level': 'good',
      });
      expect(a.isEmpty, isTrue);
    });

    test('false when at least one of headline/detail has content', () {
      expect(
        InsightsEnergyAdvice.fromJson(const {
          'headline': '🟢 مطمئن',
          'detail': '',
          'level': 'good',
        }).isEmpty,
        isFalse,
      );
    });
  });

  // ─── v79: night-state parsing ─────────────────────────────────────────

  group('InsightsSolarPrediction.fromJson (v79 night state)', () {
    test('parses is_night=true and sun_state=night from a night payload',
        () {
      final s = InsightsSnapshot.fromJson(const {
        'available': true,
        'device': {'id': 1, 'name': 'X', 'timezone': 'Asia/Hebron'},
        'solar_prediction': {
          'sunset_time': '19:00',
          'effective_sunset_time': '18:00',
          // v78 mapper forces these at night — verified here.
          'time_to_full_hours': null,
          'will_full_before_sunset': false,
          'verdict': 'فترة ليلية',
          'advice': 'البطارية تحمل النظام حتى الشروق.',
          'is_night': true,
          'sun_state': 'night',
        },
      });
      final p = s.solarPrediction!;
      expect(p.isNight, isTrue);
      expect(p.sunState, 'night');
      // Sunset-coupled values cleared by the backend mapper.
      expect(p.timeToFullHours, isNull);
      expect(p.willFullBeforeSunset, isFalse);
      // Verdict + advice still surface so the card has something to
      // show during the night.
      expect(p.verdict, 'فترة ليلية');
      expect(p.advice, 'البطارية تحمل النظام حتى الشروق.');
    });

    test('missing night fields default to daytime view (backward compat)',
        () {
      final s = InsightsSnapshot.fromJson(const {
        'available': true,
        'device': {'id': 1, 'name': 'X', 'timezone': 'UTC'},
        'solar_prediction': {
          'sunset_time': '19:00',
          'effective_sunset_time': '18:00',
          'time_to_full_hours': 1.2,
          'will_full_before_sunset': true,
          'verdict': 'سيتم شحن البطارية قبل الغروب',
          'advice': 'الوضع جيد.',
        },
      });
      final p = s.solarPrediction!;
      expect(p.isNight, isFalse);
      expect(p.sunState, 'day');
    });

    test('sun_state falls back to is_night when missing or unknown', () {
      // Backend with `is_night=true` but no `sun_state` (e.g. a
      // future stripped payload) → mobile derives `'night'` from
      // `is_night`.
      final nightWithoutSunState = InsightsSnapshot.fromJson(const {
        'available': true,
        'device': {'id': 1, 'name': 'X', 'timezone': 'UTC'},
        'solar_prediction': {
          'is_night': true,
        },
      });
      expect(nightWithoutSunState.solarPrediction!.sunState, 'night');

      // Garbage `sun_state` value → also derived from `is_night`.
      final gibberish = InsightsSnapshot.fromJson(const {
        'available': true,
        'device': {'id': 1, 'name': 'X', 'timezone': 'UTC'},
        'solar_prediction': {
          'is_night': false,
          'sun_state': 'gibberish',
        },
      });
      expect(gibberish.solarPrediction!.sunState, 'day');
    });

    test('sun_state is parsed case-insensitively and trimmed', () {
      final s = InsightsSnapshot.fromJson(const {
        'available': true,
        'device': {'id': 1, 'name': 'X', 'timezone': 'UTC'},
        'solar_prediction': {
          'is_night': false,
          'sun_state': '  NIGHT  ',
        },
      });
      // The string was parsed cleanly even though `is_night` is
      // false — both fields are surfaced verbatim so the UI can
      // pick whichever is more convenient.
      expect(s.solarPrediction!.sunState, 'night');
    });

    test('is_night is not propagated when available=false', () {
      // Locked: when the envelope is unavailable, the whole
      // prediction block is null — the night flag has no meaning
      // outside a successful insights payload.
      final s = InsightsSnapshot.fromJson(const {
        'available': false,
        'reason': 'reading_unavailable',
        'device': {'id': 1, 'name': 'X', 'timezone': 'UTC'},
      });
      expect(s.solarPrediction, isNull);
    });
  });
}
