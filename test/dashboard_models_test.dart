import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/dashboard/data/dashboard_models.dart';

void main() {
  group('DashboardSnapshot', () {
    test('parses a complete payload from /api/mobile/dashboard', () {
      final snapshot = DashboardSnapshot.fromJson(const {
        'scope': {
          'mode': 'device',
          'device_id': 12,
          'is_all_devices': false,
        },
        'device': {
          'id': 12,
          'name': 'Roof Inverter',
          'connection_status': 'ok',
        },
        'cards': {
          'solar_power_w': 1234.5,
          'home_load_w': 870.0,
          'battery_soc_percent': 78.4,
          'battery_power_w': -240.0,
          'grid_power_w': 0.0,
          'inverter_power_w': 1100.0,
          'daily_production_kwh': 6.7,
          'monthly_production_kwh': 142.0,
          'total_production_kwh': 4321.5,
        },
        'latest': {
          'created_at': '2026-05-11T10:00:00.123456',
          'status_text': 'النظام يعمل',
        },
        'empty': false,
        'generated_at': '2026-05-11T10:01:00',
      });

      expect(snapshot.scope.mode, 'device');
      expect(snapshot.scope.deviceId, 12);
      expect(snapshot.scope.isAllDevices, isFalse);
      expect(snapshot.deviceName, 'Roof Inverter');
      expect(snapshot.deviceConnectionStatus, 'ok');
      expect(snapshot.cards.solarPowerW, 1234.5);
      expect(snapshot.cards.homeLoadW, 870.0);
      expect(snapshot.cards.batterySocPercent, 78.4);
      expect(snapshot.cards.batteryPowerW, -240.0);
      expect(snapshot.cards.gridPowerW, 0.0);
      expect(snapshot.cards.dailyProductionKwh, 6.7);
      expect(snapshot.cards.totalProductionKwh, 4321.5);
      expect(snapshot.latest.statusText, 'النظام يعمل');
      expect(snapshot.latest.createdAt, '2026-05-11T10:00:00.123456');
      expect(snapshot.empty, isFalse);
      expect(snapshot.generatedAt, '2026-05-11T10:01:00');
    });

    test('handles a minimal payload with optional fields missing', () {
      final snapshot = DashboardSnapshot.fromJson(const {
        'empty': true,
        'generated_at': '2026-05-11T10:00:00',
      });

      expect(snapshot.scope.mode, '');
      expect(snapshot.scope.deviceId, isNull);
      expect(snapshot.scope.isAllDevices, isFalse);
      expect(snapshot.deviceName, '');
      expect(snapshot.deviceConnectionStatus, '');
      expect(snapshot.cards.solarPowerW, 0.0);
      expect(snapshot.cards.batterySocPercent, 0.0);
      expect(snapshot.cards.totalProductionKwh, 0.0);
      expect(snapshot.latest.statusText, '');
      expect(snapshot.latest.createdAt, isNull);
      expect(snapshot.empty, isTrue);
      expect(snapshot.generatedAt, '2026-05-11T10:00:00');
    });

    test('fleet (all-devices) payload is recognised via scope', () {
      final snapshot = DashboardSnapshot.fromJson(const {
        'scope': {
          'mode': 'all',
          'device_id': null,
          'is_all_devices': true,
        },
        'cards': {
          'solar_power_w': 5000,
          'home_load_w': 1500,
          'battery_soc_percent': 65,
          'battery_power_w': 0,
          'grid_power_w': -2400,
          'inverter_power_w': 4900,
          'daily_production_kwh': 22,
          'monthly_production_kwh': 600,
          'total_production_kwh': 18000,
        },
        'empty': false,
        'generated_at': '2026-05-11T10:00:00',
      });

      expect(snapshot.scope.mode, 'all');
      expect(snapshot.scope.isAllDevices, isTrue);
      expect(snapshot.deviceName, '');
      // Numbers parse from int as well as double.
      expect(snapshot.cards.solarPowerW, 5000.0);
      expect(snapshot.cards.gridPowerW, -2400.0);
      expect(snapshot.cards.dailyProductionKwh, 22.0);
    });
  });

  group('DashboardCards.empty', () {
    test('returns zero across the board', () {
      final c = DashboardCards.empty();
      expect(c.solarPowerW, 0);
      expect(c.homeLoadW, 0);
      expect(c.batterySocPercent, 0);
      expect(c.batteryPowerW, 0);
      expect(c.gridPowerW, 0);
      expect(c.inverterPowerW, 0);
      // v93r — generator field defaults to zero on empty.
      expect(c.generatorPowerW, 0);
      expect(c.dailyProductionKwh, 0);
      expect(c.monthlyProductionKwh, 0);
      expect(c.totalProductionKwh, 0);
    });
  });

  group('DashboardCards generator field (v93r)', () {
    test('parses generator_power_w from the server payload', () {
      final c = DashboardCards.fromJson({
        'solar_power_w': 7,
        'grid_power_w': 0,
        'battery_power_w': 641,
        'generator_power_w': 997,
      });
      expect(c.generatorPowerW, 997);
      expect(c.gridPowerW, 0);
      expect(c.solarPowerW, 7);
    });

    test('defaults to zero when the field is missing', () {
      final c = DashboardCards.fromJson({
        'solar_power_w': 1000,
      });
      // Older server builds didn't include the field; new field
      // must not throw and must report 0 W so the generator card
      // stays muted.
      expect(c.generatorPowerW, 0);
    });
  });
}
