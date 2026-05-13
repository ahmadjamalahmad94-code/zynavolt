import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/weather/data/weather_models.dart';

void main() {
  group('WeatherSnapshot.fromJson', () {
    test('parses a complete available payload', () {
      final s = WeatherSnapshot.fromJson(const {
        'available': true,
        'device': {
          'id': 42,
          'name': 'Roof Inverter',
          'timezone': 'Asia/Hebron',
        },
        'current': {
          'temperature_c': 28.4,
          'wind_speed': 3.2,
          'cloud_cover_percent': 35,
          'precipitation_probability_percent': 5,
          'condition_ar': 'غائم جزئيًا',
          'category': 'partly_cloudy',
          'icon': '⛅',
          'code': 2,
          'current_time': '2026-05-12T10:00:00',
        },
        'sun': {
          'sunrise_time': '05:14',
          'sunset_time': '19:42',
          'effective_sunrise_time': '05:14',
          'effective_sunset_time': '18:42',
        },
        'next_hour': {
          'time': '2026-05-12T11:00:00',
          'temperature': 29.0,
          'cloud_cover': 40,
          'precipitation_probability': 5,
          'condition_ar': 'غائم جزئيًا',
          'category': 'partly_cloudy',
          'icon': '⛅',
          'solar_rating': 'إنتاج متوسط',
          'advice': 'يفضل تخفيف الأحمال الثقيلة.',
        },
        'day_parts': {
          'morning': {
            'time': '2026-05-12T09:00:00',
            'temperature': 26.0,
            'cloud_cover': 20,
            'condition_ar': 'مشمس',
            'category': 'sunny',
            'icon': '☀️',
            'solar_rating': 'إنتاج قوي',
            'advice': 'وقت ممتاز.',
          },
          'noon': {
            'time': '2026-05-12T12:00:00',
            'temperature': 29.5,
            'condition_ar': 'غائم جزئيًا',
            'icon': '⛅',
          },
          'afternoon': null,
        },
        'timeline': [
          {
            'time_label': '8:00 ص',
            'temperature': 25.0,
            'cloud_cover': 18,
            'condition_ar': 'مشمس',
            'icon': '☀️',
            'solar_rating': 'إنتاج قوي',
            'advice': 'وقت ممتاز.',
          },
          {
            'time_label': '10:00 ص',
            'temperature': 27.5,
            'cloud_cover': 22,
            'condition_ar': 'غائم جزئيًا',
            'icon': '⛅',
            'solar_rating': 'إنتاج متوسط',
            'advice': 'يفضل تخفيف الأحمال الثقيلة.',
          },
        ],
        'generated_at': '2026-05-12T10:00:00',
      });

      expect(s.available, isTrue);
      expect(s.device.id, 42);
      expect(s.device.name, 'Roof Inverter');
      expect(s.device.timezone, 'Asia/Hebron');

      expect(s.current, isNotNull);
      expect(s.current!.temperatureC, 28.4);
      expect(s.current!.windSpeed, 3.2);
      expect(s.current!.cloudCoverPercent, 35.0);
      expect(s.current!.precipitationProbabilityPercent, 5.0);
      expect(s.current!.conditionAr, 'غائم جزئيًا');
      expect(s.current!.category, 'partly_cloudy');
      expect(s.current!.icon, '⛅');
      expect(s.current!.code, 2);

      expect(s.sun, isNotNull);
      expect(s.sun!.sunriseTime, '05:14');
      expect(s.sun!.sunsetTime, '19:42');
      expect(s.sun!.effectiveSunsetTime, '18:42');

      expect(s.nextHour, isNotNull);
      expect(s.nextHour!.solarRating, 'إنتاج متوسط');

      expect(s.dayParts, isNotNull);
      expect(s.dayParts!.morning, isNotNull);
      expect(s.dayParts!.morning!.icon, '☀️');
      expect(s.dayParts!.noon!.conditionAr, 'غائم جزئيًا');
      // null afternoon stays null — never fabricated.
      expect(s.dayParts!.afternoon, isNull);

      expect(s.timeline.length, 2);
      expect(s.timeline.first.timeLabel, '8:00 ص');
      expect(s.timeline.first.solarRating, 'إنتاج قوي');

      expect(s.reason, isNull);
      expect(s.message, isNull);
      expect(s.generatedAt, '2026-05-12T10:00:00');
    });

    test('unavailable payload preserves reason + message + device', () {
      final s = WeatherSnapshot.fromJson(const {
        'available': false,
        'reason': 'station_coords_unavailable',
        'message': 'Weather data is not available for this device yet.',
        'device': {
          'id': 7,
          'name': 'New Device',
          'timezone': '',
        },
        'generated_at': '2026-05-12T10:00:00',
      });

      expect(s.available, isFalse);
      expect(s.reason, 'station_coords_unavailable');
      expect(s.message, 'Weather data is not available for this device yet.');
      expect(s.device.id, 7);
      expect(s.device.name, 'New Device');
      // Locked: no fabricated current / sun / timeline when unavailable.
      expect(s.current, isNull);
      expect(s.sun, isNull);
      expect(s.nextHour, isNull);
      expect(s.dayParts, isNull);
      expect(s.timeline, isEmpty);
    });

    test('unavailable payload supports weather_unreachable reason', () {
      final s = WeatherSnapshot.fromJson(const {
        'available': false,
        'reason': 'weather_unreachable',
        'message': 'Weather service could not be reached right now.',
        'device': {'id': 42, 'name': 'X', 'timezone': 'Asia/Hebron'},
        'generated_at': '2026-05-12T10:00:00',
      });
      expect(s.available, isFalse);
      expect(s.reason, 'weather_unreachable');
      expect(s.current, isNull);
    });

    test('completely empty payload yields a safe snapshot, not an exception',
        () {
      final s = WeatherSnapshot.fromJson(const {});
      expect(s.available, isFalse);
      expect(s.reason, isNull);
      expect(s.message, isNull);
      expect(s.current, isNull);
      expect(s.timeline, isEmpty);
      expect(s.device.id, 0);
      expect(s.device.name, '');
    });

    test('coerces stringified numbers + null defensively', () {
      final s = WeatherSnapshot.fromJson(const {
        'available': true,
        'device': {'id': '42', 'name': 'X', 'timezone': 'UTC'},
        'current': {
          'temperature_c': '28.4',
          'wind_speed': null,
          'cloud_cover_percent': '35',
          'icon': '⛅',
        },
        'sun': {'sunrise_time': '', 'sunset_time': '19:42'},
        'timeline': [],
        'generated_at': '2026-05-12T10:00:00',
      });
      expect(s.device.id, 42);
      expect(s.current!.temperatureC, 28.4);
      expect(s.current!.windSpeed, isNull);
      expect(s.current!.cloudCoverPercent, 35.0);
      // Empty string sunrise normalises to null so the UI shows `—`.
      expect(s.sun!.sunriseTime, isNull);
      expect(s.sun!.sunsetTime, '19:42');
    });

    test('non-list timeline degrades to empty list', () {
      final s = WeatherSnapshot.fromJson(const {
        'available': true,
        'device': {'id': 1, 'name': 'X', 'timezone': 'UTC'},
        'current': {'icon': '☀️'},
        'sun': {},
        'timeline': 'not a list',
      });
      expect(s.timeline, isEmpty);
    });

    test('next_hour can be null even when available=true', () {
      final s = WeatherSnapshot.fromJson(const {
        'available': true,
        'device': {'id': 1, 'name': 'X', 'timezone': 'UTC'},
        'current': {'icon': '☀️'},
        'sun': {},
        'next_hour': null,
        'day_parts': {},
        'timeline': [],
      });
      expect(s.available, isTrue);
      expect(s.nextHour, isNull);
    });
  });

  group('WeatherSlot.displayTime', () {
    test('prefers Arabic time_label when present', () {
      final slot = WeatherSlot.fromJson(const {
        'time_label': '8:00 ص',
        'time': '2026-05-12T08:00:00',
        'icon': '☀️',
      });
      expect(slot.displayTime, '8:00 ص');
    });

    test('falls back to ISO HH:MM when time_label missing', () {
      final slot = WeatherSlot.fromJson(const {
        'time': '2026-05-12T09:30:00',
        'icon': '☀️',
      });
      expect(slot.displayTime, '09:30');
    });

    test('empty when neither field is usable', () {
      final slot = WeatherSlot.fromJson(const {'icon': '☀️'});
      expect(slot.displayTime, '');
    });
  });
}
