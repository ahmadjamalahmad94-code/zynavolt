import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/devices/data/device_detail_models.dart';

void main() {
  group('DeviceDetailSnapshot', () {
    test('parses a complete payload from /api/mobile/devices/<id>', () {
      final snapshot = DeviceDetailSnapshot.fromJson(const {
        'device': {
          'id': 42,
          'name': 'Roof Inverter',
          'device_type': 'deye',
          'api_provider': 'deye',
          'connection_status': 'ok',
          'last_connected_at': '2026-05-11T10:00:00',
          'is_active': true,
          'plant_name': 'House A',
          'timezone': 'Asia/Hebron',
          'created_at': '2025-12-01T08:00:00',
          'updated_at': '2026-05-11T09:55:00',
          'auth_mode': 'wizard',
          'safe_settings': {
            'battery_capacity_kwh': '5.12',
            'battery_reserve_percent': '20',
          },
        },
        'latest': {
          'id': 999,
          'created_at': '2026-05-11T10:00:00.123456',
          'status_text': 'النظام يعمل',
          'solar_power': 1234.5,
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
      });

      expect(snapshot.device.id, 42);
      expect(snapshot.device.name, 'Roof Inverter');
      expect(snapshot.device.deviceType, 'deye');
      expect(snapshot.device.apiProvider, 'deye');
      expect(snapshot.device.connectionStatus, 'ok');
      expect(snapshot.device.isActive, isTrue);
      expect(snapshot.device.plantName, 'House A');
      expect(snapshot.device.timezone, 'Asia/Hebron');
      expect(snapshot.device.lastConnectedAt, '2026-05-11T10:00:00');
      expect(snapshot.device.createdAt, '2025-12-01T08:00:00');
      expect(snapshot.device.updatedAt, '2026-05-11T09:55:00');
      expect(snapshot.device.safeSettings, {
        'battery_capacity_kwh': '5.12',
        'battery_reserve_percent': '20',
      });

      expect(snapshot.latest.hasReading, isTrue);
      expect(snapshot.latest.statusText, 'النظام يعمل');
      expect(snapshot.latest.createdAt, '2026-05-11T10:00:00.123456');
      expect(snapshot.latest.solarPowerW, 1234.5);
      expect(snapshot.latest.homeLoadW, 870.0);
      expect(snapshot.latest.batterySocPercent, 78.4);
      expect(snapshot.latest.batteryPowerW, -240.0);
      expect(snapshot.latest.gridPowerW, 0.0);
    });

    test('handles a minimal payload with no latest reading', () {
      final snapshot = DeviceDetailSnapshot.fromJson(const {
        'device': {
          'id': 7,
          'name': '',
        },
        'latest': null,
        'cards': {},
      });

      expect(snapshot.device.id, 7);
      expect(snapshot.device.name, '');
      expect(snapshot.device.deviceType, '');
      expect(snapshot.device.apiProvider, '');
      expect(snapshot.device.connectionStatus, '');
      expect(snapshot.device.isActive, isFalse);
      expect(snapshot.device.lastConnectedAt, isNull);
      expect(snapshot.device.createdAt, isNull);
      expect(snapshot.device.updatedAt, isNull);
      expect(snapshot.device.safeSettings, isEmpty);

      expect(snapshot.latest.hasReading, isFalse);
      expect(snapshot.latest.statusText, '');
      expect(snapshot.latest.createdAt, isNull);
      expect(snapshot.latest.solarPowerW, 0.0);
      expect(snapshot.latest.batterySocPercent, 0.0);
    });

    test('unknown / extra fields in the payload do not break parsing', () {
      final snapshot = DeviceDetailSnapshot.fromJson(const {
        'device': {
          'id': 1,
          'name': 'X',
          'future_feature': {'nested': 'value'},
          'experimental_flag': true,
        },
        'latest': {
          'created_at': '2026-05-11T10:00:00',
          'future_metric': 9999,
        },
        'cards': {
          'solar_power_w': 100,
          'home_load_w': 50,
          'battery_soc_percent': 30,
          'battery_power_w': 0,
          'grid_power_w': 50,
        },
        'unrelated_top_level': 'ignored',
      });

      expect(snapshot.device.id, 1);
      expect(snapshot.device.name, 'X');
      expect(snapshot.latest.hasReading, isTrue);
      expect(snapshot.latest.solarPowerW, 100.0);
      expect(snapshot.latest.batterySocPercent, 30.0);
    });

    test('safe_settings skips null/empty values defensively', () {
      final snapshot = DeviceDetailSnapshot.fromJson(const {
        'device': {
          'id': 5,
          'name': 'A',
          'safe_settings': {
            'battery_capacity_kwh': '5',
            'battery_reserve_percent': '',
            'irrelevant': null,
          },
        },
        'latest': null,
        'cards': {},
      });

      expect(snapshot.device.safeSettings, {'battery_capacity_kwh': '5'});
    });
  });

  group('DeviceLatestSummary.empty', () {
    test('returns zero across the board', () {
      final l = DeviceLatestSummary.empty();
      expect(l.hasReading, isFalse);
      expect(l.solarPowerW, 0);
      expect(l.homeLoadW, 0);
      expect(l.batterySocPercent, 0);
      expect(l.batteryPowerW, 0);
      expect(l.gridPowerW, 0);
      expect(l.createdAt, isNull);
      expect(l.statusText, '');
    });
  });

  // ── v45 — provider support tier ──────────────────────────────────
  group('DeviceDetail.providerSupportTier (v45)', () {
    test('parses backend-provided tier fields', () {
      final snapshot = DeviceDetailSnapshot.fromJson(const {
        'device': {
          'id': 1,
          'device_type': 'deye',
          'api_provider': 'deye',
          'is_active': true,
          'provider_support_tier': 'live-supported',
          'provider_support_tier_label': 'مدعوم',
        },
        'latest': null,
      });
      expect(snapshot.device.providerSupportTier, 'live-supported');
      expect(snapshot.device.providerSupportTierLabel, 'مدعوم');
    });

    test('legacy backend without tier fields → null (UI hides badge)', () {
      final snapshot = DeviceDetailSnapshot.fromJson(const {
        'device': {
          'id': 1,
          'device_type': 'deye',
          'is_active': true,
        },
        'latest': null,
      });
      expect(snapshot.device.providerSupportTier, isNull);
      expect(snapshot.device.providerSupportTierLabel, isNull);
    });

    test('empty / whitespace tier fields → null', () {
      final snapshot = DeviceDetailSnapshot.fromJson(const {
        'device': {
          'id': 1,
          'device_type': 'deye',
          'is_active': true,
          'provider_support_tier': '',
          'provider_support_tier_label': '   ',
        },
        'latest': null,
      });
      expect(snapshot.device.providerSupportTier, isNull);
      expect(snapshot.device.providerSupportTierLabel, isNull);
    });
  });
}
