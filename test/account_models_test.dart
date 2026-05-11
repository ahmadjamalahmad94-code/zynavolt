import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/account/data/account_models.dart';

void main() {
  group('AccountSnapshot', () {
    test('parses a complete payload from /api/mobile/account', () {
      final s = AccountSnapshot.fromJson(const {
        'user': {
          'id': 11,
          'username': 'ahmad',
          'full_name': 'أحمد',
          'email': 'ahmad@example.com',
        },
        'role': {
          'code': 'owner',
          'label': 'مالك',
          'is_admin': false,
        },
        'subscription': {
          'tenant_id': 3,
          'status': 'active',
          'expires_at': '2026-12-31T00:00:00',
          'trial_ends_at': null,
          'max_devices': 5,
          'plan': {
            'id': 2,
            'code': 'pro',
            'name_ar': 'محترف',
            'name_en': 'Pro',
            'price': 29.0,
            'currency': 'USD',
            'max_devices': 5,
            'features': ['multi_device', 'priority_support'],
          },
        },
        'devices': {
          'total': 2,
          'active': 1,
          'selected_device_id': 42,
        },
        'capabilities': {
          'profile_update': true,
          'password_change': true,
          'logout_all_refresh_tokens': true,
          'account_deletion': false,
          'mobile_api_sections': ['auth', 'devices', 'loads'],
        },
      });

      expect(s.userId, 11);
      expect(s.username, 'ahmad');
      expect(s.fullName, 'أحمد');
      expect(s.email, 'ahmad@example.com');
      expect(s.role.code, 'owner');
      expect(s.role.label, 'مالك');
      expect(s.role.isAdmin, isFalse);
      expect(s.subscription.tenantId, 3);
      expect(s.subscription.status, 'active');
      expect(s.subscription.expiresAt, '2026-12-31T00:00:00');
      expect(s.subscription.isTrial, isFalse);
      expect(s.subscription.maxDevices, 5);
      expect(s.subscription.plan.code, 'pro');
      expect(s.subscription.plan.nameAr, 'محترف');
      expect(s.subscription.plan.price, 29.0);
      expect(s.subscription.plan.currency, 'USD');
      expect(s.subscription.plan.features, ['multi_device', 'priority_support']);
      expect(s.devices.total, 2);
      expect(s.devices.active, 1);
      expect(s.devices.selectedDeviceId, 42);
      expect(s.capabilities.profileUpdate, isTrue);
      expect(s.capabilities.accountDeletion, isFalse);
      expect(s.capabilities.mobileApiSections,
          ['auth', 'devices', 'loads']);
    });

    test('handles a minimal payload defensively', () {
      final s = AccountSnapshot.fromJson(const {});
      expect(s.userId, 0);
      expect(s.username, '');
      expect(s.fullName, '');
      expect(s.email, '');
      expect(s.role.code, '');
      expect(s.role.isAdmin, isFalse);
      expect(s.subscription.status, '');
      expect(s.subscription.plan.hasName, isFalse);
      expect(s.devices.total, 0);
      expect(s.devices.active, 0);
      expect(s.devices.selectedDeviceId, isNull);
      expect(s.capabilities.profileUpdate, isFalse);
      expect(s.capabilities.mobileApiSections, isEmpty);
    });

    test('subscription with trial flag', () {
      final s = AccountSnapshot.fromJson(const {
        'subscription': {
          'status': 'trial',
          'trial_ends_at': '2026-06-15T00:00:00',
        },
      });
      expect(s.subscription.status, 'trial');
      expect(s.subscription.isTrial, isTrue);
      expect(s.subscription.trialEndsAt, '2026-06-15T00:00:00');
    });

    test('plan.displayName prefers Arabic, falls back to English then code', () {
      final arPlan = AccountPlan.fromJson(const {
        'name_ar': 'محترف',
        'name_en': 'Pro',
        'code': 'pro',
      });
      expect(arPlan.displayName(), 'محترف');
      expect(arPlan.displayName(preferred: 'en'), 'Pro');

      final enOnly = AccountPlan.fromJson(const {
        'name_en': 'Pro',
        'code': 'pro',
      });
      expect(enOnly.displayName(), 'Pro');

      final codeOnly = AccountPlan.fromJson(const {'code': 'pro'});
      expect(codeOnly.displayName(), 'pro');
    });

    test('plan.features parses both list and map-of-bools defensively', () {
      final listPlan = AccountPlan.fromJson(const {
        'features': ['a', 'b'],
      });
      expect(listPlan.features, ['a', 'b']);

      final mapPlan = AccountPlan.fromJson(const {
        'features': {'a': true, 'b': false, 'c': true},
      });
      expect(mapPlan.features.toSet(), {'a', 'c'});
    });

    test('unknown / extra fields do not break parsing', () {
      final s = AccountSnapshot.fromJson(const {
        'user': {'id': 1, 'future_field': 'X'},
        'subscription': {'plan': {'experimental_metric': 42}},
        'unknown_top': true,
      });
      expect(s.userId, 1);
      expect(s.subscription.plan.code, '');
    });
  });
}
