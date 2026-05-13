import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/onboarding/data/onboarding_models.dart';

void main() {
  group('OnboardingState.fromJson', () {
    test('parses a fully-loaded first-run payload', () {
      final s = OnboardingState.fromJson(const {
        'completed': false,
        'step': 'welcome',
        'needs_profile_location': true,
        'needs_device_link': true,
        'system_basics': {},
        'device_state': {
          'selected_device_id': null,
          'current_device': null,
          'devices': {'total': 0, 'active': 0},
        },
      });
      expect(s.completed, isFalse);
      expect(s.step, 'welcome');
      expect(s.needsProfileLocation, isTrue);
      expect(s.needsDeviceLink, isTrue);
      expect(s.selectedDeviceId, isNull);
      expect(s.currentDeviceName, '');
      expect(s.currentConnectionStatus, '');
      expect(s.currentIsActive, isFalse);
      expect(s.totalDevices, 0);
      expect(s.needsProviderSetup, isFalse);
      expect(s.needsFirstSync, isFalse);
    });

    test('flags provider-setup when current device is setup_required', () {
      final s = OnboardingState.fromJson(const {
        'completed': false,
        'step': 'device',
        'needs_profile_location': false,
        'needs_device_link': false,
        'device_state': {
          'selected_device_id': 42,
          'current_device': {
            'id': 42,
            'name': 'سطح المنزل',
            'connection_status': 'setup_required',
            'is_active': true,
          },
          'devices': {'total': 1, 'active': 1},
        },
      });
      expect(s.needsProfileLocation, isFalse);
      expect(s.needsDeviceLink, isFalse);
      expect(s.selectedDeviceId, 42);
      expect(s.currentDeviceName, 'سطح المنزل');
      expect(s.currentConnectionStatus, 'setup_required');
      expect(s.currentIsActive, isTrue);
      expect(s.needsProviderSetup, isTrue);
      expect(s.needsFirstSync, isFalse);
      expect(s.totalDevices, 1);
    });

    test(
        'flags first-sync needed when setup is complete but never connected',
        () {
      final s = OnboardingState.fromJson(const {
        'completed': false,
        'step': 'device',
        'needs_profile_location': false,
        'needs_device_link': false,
        'device_state': {
          'selected_device_id': 7,
          'current_device': {
            'id': 7,
            'name': 'الجهاز الرئيسي',
            'connection_status': 'pending',
            'is_active': true,
          },
          'devices': {'total': 1, 'active': 1},
        },
      });
      expect(s.needsProviderSetup, isFalse);
      expect(s.needsFirstSync, isTrue);
    });

    test('hides setup + sync when the device is fully connected', () {
      final s = OnboardingState.fromJson(const {
        'completed': false,
        'step': 'finish',
        'needs_profile_location': false,
        'needs_device_link': false,
        'device_state': {
          'selected_device_id': 7,
          'current_device': {
            'id': 7,
            'connection_status': 'ok',
            'is_active': true,
          },
          'devices': {'total': 1, 'active': 1},
        },
      });
      expect(s.needsProviderSetup, isFalse);
      expect(s.needsFirstSync, isFalse);
    });

    test('lowercases connection_status and step defensively', () {
      final s = OnboardingState.fromJson(const {
        'completed': false,
        'step': '  WELCOME  ',
        'device_state': {
          'current_device': {
            'id': 1,
            'connection_status': 'SETUP_REQUIRED',
            'is_active': true,
          },
        },
      });
      expect(s.step, 'welcome');
      expect(s.currentConnectionStatus, 'setup_required');
      expect(s.needsProviderSetup, isTrue);
    });

    test('empty step defaults to welcome', () {
      final s = OnboardingState.fromJson(const {});
      expect(s.step, 'welcome');
      expect(s.completed, isFalse);
      expect(s.needsProfileLocation, isFalse);
      expect(s.needsDeviceLink, isFalse);
      expect(s.selectedDeviceId, isNull);
    });

    test('completed=true round-trips without flipping flags', () {
      final s = OnboardingState.fromJson(const {
        'completed': true,
        'step': 'done',
        'needs_profile_location': false,
        'needs_device_link': false,
        'device_state': {
          'current_device': {
            'id': 9,
            'connection_status': 'ok',
            'is_active': true,
          },
          'devices': {'total': 2, 'active': 2},
        },
      });
      expect(s.completed, isTrue);
      expect(s.step, 'done');
      expect(s.totalDevices, 2);
    });

    test('falls back to current_device.id when selected_device_id missing',
        () {
      final s = OnboardingState.fromJson(const {
        'device_state': {
          'current_device': {
            'id': 314,
            'connection_status': 'ok',
            'is_active': true,
          },
        },
      });
      expect(s.selectedDeviceId, 314);
    });

    test('OnboardingState.unknown() is a safe welcome stub', () {
      final s = OnboardingState.unknown();
      expect(s.completed, isFalse);
      expect(s.step, 'welcome');
      expect(s.needsProfileLocation, isTrue);
      expect(s.needsDeviceLink, isTrue);
      expect(s.selectedDeviceId, isNull);
      expect(s.totalDevices, 0);
    });
  });
}
