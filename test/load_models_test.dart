import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/loads/data/load_models.dart';

void main() {
  group('UserLoad', () {
    test('parses a complete payload from /api/mobile/loads items', () {
      final load = UserLoad.fromJson(const {
        'id': 11,
        'name': 'سخّان الماء',
        'power_w': 1200.0,
        'priority': 2,
        'is_enabled': true,
        'device_id': 42,
        'created_at': '2026-05-01T08:00:00',
        'control_type': 'persisted_preference',
        'execution_note': 'Toggling a load only changes the saved preference.',
      });

      expect(load.id, 11);
      expect(load.name, 'سخّان الماء');
      expect(load.powerW, 1200.0);
      expect(load.priority, 2);
      expect(load.isEnabled, isTrue);
      expect(load.deviceId, 42);
      expect(load.createdAt, '2026-05-01T08:00:00');
    });

    test('handles a minimal payload defensively', () {
      final load = UserLoad.fromJson(const {'id': 7});
      expect(load.id, 7);
      expect(load.name, '');
      expect(load.powerW, 0.0);
      expect(load.priority, 1);
      expect(load.isEnabled, isFalse);
      expect(load.deviceId, isNull);
      expect(load.createdAt, isNull);
    });

    test('power_w parses from string and int', () {
      final fromString = UserLoad.fromJson(const {'id': 1, 'power_w': '850.5'});
      final fromInt = UserLoad.fromJson(const {'id': 2, 'power_w': 700});
      expect(fromString.powerW, 850.5);
      expect(fromInt.powerW, 700.0);
    });

    test('device_id accepts null/empty/string variants', () {
      expect(
        UserLoad.fromJson(const {'id': 1, 'device_id': null}).deviceId,
        isNull,
      );
      expect(
        UserLoad.fromJson(const {'id': 1, 'device_id': ''}).deviceId,
        isNull,
      );
      expect(
        UserLoad.fromJson(const {'id': 1, 'device_id': '5'}).deviceId,
        5,
      );
      expect(
        UserLoad.fromJson(const {'id': 1, 'device_id': 9}).deviceId,
        9,
      );
    });
  });

  group('LoadsPage', () {
    test('parses items + total + scope (device mode)', () {
      final page = LoadsPage.fromJson(const {
        'items': [
          {'id': 1, 'name': 'مكيّف', 'power_w': 2000, 'priority': 1, 'is_enabled': true},
          {'id': 2, 'name': 'ثلاجة', 'power_w': 200, 'priority': 3, 'is_enabled': false},
        ],
        'total': 2,
        'device': {'id': 42, 'name': 'Roof Inverter'},
        'scope': {'mode': 'device', 'device_id': 42},
      });

      expect(page.items.length, 2);
      expect(page.items.first.name, 'مكيّف');
      expect(page.items.last.isEnabled, isFalse);
      expect(page.total, 2);
      expect(page.scope.mode, 'device');
      expect(page.scope.deviceId, 42);
      expect(page.scope.isAll, isFalse);
      expect(page.deviceName, 'Roof Inverter');
    });

    test('parses an empty feed (mode "all")', () {
      final page = LoadsPage.fromJson(const {
        'items': [],
        'total': 0,
        'device': null,
        'scope': {'mode': 'all', 'device_id': null},
      });
      expect(page.items, isEmpty);
      expect(page.total, 0);
      expect(page.scope.isAll, isTrue);
      expect(page.deviceName, '');
    });

    test('handles a missing items list defensively', () {
      final page = LoadsPage.fromJson(const {
        'total': 0,
        'scope': {'mode': 'all'},
      });
      expect(page.items, isEmpty);
      expect(page.scope.isAll, isTrue);
    });

    test('unknown / extra fields do not break parsing', () {
      final page = LoadsPage.fromJson(const {
        'items': [
          {
            'id': 1,
            'name': 'A',
            'power_w': 100,
            'priority': 1,
            'is_enabled': true,
            'future_extra': {'k': 'v'},
            'control_type': 'persisted_preference',
            'execution_note': '...',
          },
        ],
        'total': 1,
        'scope': {'mode': 'all'},
        'unrelated_top_level': 'x',
      });
      expect(page.items.length, 1);
      expect(page.items.first.id, 1);
      expect(page.items.first.name, 'A');
    });
  });

  group('LoadsScope', () {
    test('treats empty mode + null device as "all"', () {
      final scope = LoadsScope.fromJson(const {});
      expect(scope.mode, '');
      expect(scope.deviceId, isNull);
      expect(scope.isAll, isTrue);
    });

    test('recognises device-scoped responses', () {
      final scope = LoadsScope.fromJson(const {
        'mode': 'device',
        'device_id': 99,
      });
      expect(scope.isAll, isFalse);
      expect(scope.deviceId, 99);
    });
  });
}
