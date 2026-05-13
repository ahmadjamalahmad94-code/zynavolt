import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/devices/data/device_diagnostics_models.dart';

void main() {
  // ─── DeviceReadingRow ───────────────────────────────────────────
  group('DeviceReadingRow.fromJson', () {
    test('parses a complete payload', () {
      final r = DeviceReadingRow.fromJson(const {
        'id': 999,
        'device_id': 42,
        'created_at': '2026-05-11T10:00:00.123456',
        'solar_power': 1230,
        'home_load': 410.5,
        'battery_soc': 78,
        'battery_power': -200,
        'grid_power': 0,
        'inverter_power': 1430,
        'daily_production': 12.5,
        'monthly_production': 345.0,
        'total_production': 9876.5,
        'status_text': 'النظام يعمل',
        'pv1_power': 600,
        'pv2_power': 630,
        'pv3_power': null,
        'pv4_power': null,
        'inverter_temp': 41.2,
        'dc_temp': null,
        'grid_voltage': 230,
        'grid_frequency': 50.0,
      });
      expect(r.id, 999);
      expect(r.createdAt, '2026-05-11T10:00:00.123456');
      expect(r.solarPowerW, 1230);
      expect(r.homeLoadW, 410.5);
      expect(r.batterySocPercent, 78);
      expect(r.batteryPowerW, -200);
      expect(r.gridPowerW, 0);
      expect(r.inverterPowerW, 1430);
      expect(r.dailyProductionKwh, 12.5);
      expect(r.statusText, 'النظام يعمل');
    });

    test('coerces stringified numbers + null values defensively', () {
      final r = DeviceReadingRow.fromJson(const {
        'id': '17',
        'created_at': '2026-05-11T08:00:00',
        'solar_power': '500',
        'home_load': null,
        'battery_soc': '50.5',
      });
      expect(r.id, 17);
      expect(r.solarPowerW, 500);
      expect(r.homeLoadW, 0);
      expect(r.batterySocPercent, 50.5);
    });

    test('completely empty payload yields a zero row, not an exception',
        () {
      final r = DeviceReadingRow.fromJson(const {});
      expect(r.id, 0);
      expect(r.createdAt, isNull);
      expect(r.solarPowerW, 0);
      expect(r.homeLoadW, 0);
      expect(r.statusText, '');
    });

    test('non-numeric strings degrade to 0 instead of throwing', () {
      final r = DeviceReadingRow.fromJson(const {
        'id': 'oops',
        'solar_power': 'mystery',
        'battery_soc': '',
      });
      expect(r.id, 0);
      expect(r.solarPowerW, 0);
      expect(r.batterySocPercent, 0);
    });
  });

  // ─── DeviceAlert ────────────────────────────────────────────────
  group('DeviceAlert.fromJson + localizer', () {
    test('parses both v52 alert keys the backend currently emits', () {
      final low = DeviceAlert.fromJson(const {
        'level': 'warning',
        'key': 'battery_low',
        'message': 'Battery is below 20%.',
      });
      final zero = DeviceAlert.fromJson(const {
        'level': 'info',
        'key': 'solar_zero',
        'message': 'Solar production is currently zero.',
      });
      expect(low.level, 'warning');
      expect(low.key, 'battery_low');
      expect(zero.key, 'solar_zero');
    });

    test('Arabic message localizer maps the v52 keys', () {
      final low = DeviceAlert(
        level: 'warning',
        key: 'battery_low',
        message: 'Battery is below 20%.',
      );
      final zero = DeviceAlert(
        level: 'info',
        key: 'solar_zero',
        message: 'Solar production is currently zero.',
      );
      expect(alertMessageArabic(low), 'البطارية أقل من 20٪.');
      expect(alertMessageArabic(zero), 'لا يوجد إنتاج شمسي حالياً.');
      expect(alertTitleArabic(low), 'البطارية منخفضة');
      expect(alertTitleArabic(zero), 'الإنتاج الشمسي صفر');
    });

    test('unknown key falls back to the raw backend message', () {
      final future = DeviceAlert(
        level: 'critical',
        key: 'grid_outage',
        message: 'Grid power has been unavailable for 5 minutes.',
      );
      expect(
        alertMessageArabic(future),
        'Grid power has been unavailable for 5 minutes.',
      );
    });

    test('unknown key + empty message falls back to a calm Arabic stub',
        () {
      final empty = DeviceAlert(
        level: 'info',
        key: 'mystery_event',
        message: '',
      );
      expect(alertMessageArabic(empty), 'تنبيه من الجهاز.');
      expect(alertTitleArabic(empty), 'تنبيه');
    });

    test('case + whitespace normalisation on level / key', () {
      final a = DeviceAlert.fromJson(const {
        'level': '  WARNING  ',
        'key': 'BATTERY_LOW',
      });
      expect(a.level, 'warning');
      expect(a.key, 'battery_low');
      expect(alertMessageArabic(a), 'البطارية أقل من 20٪.');
    });
  });
}
