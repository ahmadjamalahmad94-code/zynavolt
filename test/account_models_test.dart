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

    // v66: ── available_plans + pending_plan_change_request ──────────

    test('parses available_plans list with is_current marker', () {
      final s = AccountSnapshot.fromJson(const {
        'available_plans': [
          {
            'id': 1, 'code': 'basic', 'name_ar': 'أساسي', 'name_en': 'Basic',
            'price': 0.0, 'currency': 'USD', 'max_devices': 1,
            'features': ['can_view_dashboard'],
            'is_current': true,
          },
          {
            'id': 2, 'code': 'pro', 'name_ar': 'برو', 'name_en': 'Pro',
            'price': 29.0, 'currency': 'USD', 'max_devices': 3,
            'features': ['can_view_dashboard', 'can_use_telegram'],
            'is_current': false,
          },
        ],
      });

      expect(s.availablePlans.length, 2);
      final basic = s.availablePlans.first;
      expect(basic.id, 1);
      expect(basic.code, 'basic');
      expect(basic.nameAr, 'أساسي');
      expect(basic.nameEn, 'Basic');
      expect(basic.price, 0.0);
      expect(basic.currency, 'USD');
      expect(basic.maxDevices, 1);
      expect(basic.features, ['can_view_dashboard']);
      expect(basic.isCurrent, isTrue);
      expect(basic.displayName(), 'أساسي');

      final pro = s.availablePlans.last;
      expect(pro.id, 2);
      expect(pro.isCurrent, isFalse);
      expect(pro.features, ['can_view_dashboard', 'can_use_telegram']);
    });

    test('available_plans is empty when the key is absent', () {
      final s = AccountSnapshot.fromJson(const {});
      expect(s.availablePlans, isEmpty);
    });

    test('available_plans gracefully drops non-map entries', () {
      final s = AccountSnapshot.fromJson(const {
        'available_plans': [
          {'id': 1, 'code': 'basic', 'is_current': true},
          'not a map',
          null,
          {'id': 2, 'code': 'pro', 'is_current': false},
        ],
      });
      // Garbage entries are skipped; the two valid plans remain.
      expect(s.availablePlans.length, 2);
      expect(s.availablePlans.first.id, 1);
      expect(s.availablePlans.last.id, 2);
    });

    test('pending_plan_change_request parses the full payload', () {
      final s = AccountSnapshot.fromJson(const {
        'pending_plan_change_request': {
          'id': 555,
          'status': 'open',
          'requested_plan_id': 2,
          'requested_plan_name': 'Pro',
          'message': 'أرغب بالترقية',
          'created_at': '2026-05-12T12:00:00',
        },
      });
      final p = s.pendingPlanChangeRequest;
      expect(p, isNotNull);
      expect(p!.id, 555);
      expect(p.status, 'open');
      expect(p.requestedPlanId, 2);
      expect(p.requestedPlanName, 'Pro');
      expect(p.message, 'أرغب بالترقية');
      expect(p.createdAt, '2026-05-12T12:00:00');
    });

    test('pending_plan_change_request is null when absent or null', () {
      final a = AccountSnapshot.fromJson(const {});
      expect(a.pendingPlanChangeRequest, isNull);
      final b = AccountSnapshot.fromJson(const {
        'pending_plan_change_request': null,
      });
      expect(b.pendingPlanChangeRequest, isNull);
    });

    test('pending_plan_change_request handles missing optional fields', () {
      // requested_plan_id is `null` when the server couldn't resolve
      // the plan name (rename / deactivation). message is `null` when
      // the user didn't supply one. Both must not crash the parser.
      final s = AccountSnapshot.fromJson(const {
        'pending_plan_change_request': {
          'id': 9,
          'status': 'open',
          'requested_plan_id': null,
          'requested_plan_name': 'DeletedPlanName',
          'message': null,
          'created_at': '2026-05-12T12:00:00',
        },
      });
      final p = s.pendingPlanChangeRequest!;
      expect(p.requestedPlanId, isNull);
      expect(p.requestedPlanName, 'DeletedPlanName');
      expect(p.message, isNull);
      expect(p.createdAt, '2026-05-12T12:00:00');
    });

    test('capabilities advertises plan_change_request', () {
      final on = AccountSnapshot.fromJson(const {
        'capabilities': {'plan_change_request': true},
      });
      expect(on.capabilities.planChangeRequest, isTrue);

      // Older backends without the key default to `false` so the
      // mobile UI keeps the action hidden honestly.
      final off = AccountSnapshot.fromJson(const {
        'capabilities': {},
      });
      expect(off.capabilities.planChangeRequest, isFalse);
    });

    // v76: ── quotas[] ───────────────────────────────────────────────

    test('parses a populated quotas list (limit + remaining + percent)', () {
      final s = AccountSnapshot.fromJson(const {
        'quotas': [
          {
            'key': 'support_cases_limit',
            'label': 'تذاكر الدعم',
            'description': 'عدد التذاكر الشهري',
            'limit': 10.0,
            'used': 4.0,
            'remaining': 6.0,
            'percent': 40.0,
            'is_unlimited': false,
            'reset_period': 'monthly',
            'status': 'active',
            'source_label': 'من الخطة',
          },
        ],
      });

      expect(s.quotas.length, 1);
      final q = s.quotas.first;
      expect(q.key, 'support_cases_limit');
      expect(q.label, 'تذاكر الدعم');
      expect(q.description, 'عدد التذاكر الشهري');
      expect(q.limit, 10.0);
      expect(q.used, 4.0);
      expect(q.remaining, 6.0);
      expect(q.percent, 40.0);
      expect(q.isUnlimited, isFalse);
      expect(q.resetPeriod, 'monthly');
      expect(q.status, 'active');
      expect(q.sourceLabel, 'من الخطة');
      expect(q.isActive, isTrue);
      // progress = percent / 100, clamped to [0, 1].
      expect(q.progress, closeTo(0.40, 0.0001));
    });

    test('unlimited quota → remaining is null, progress reads 0', () {
      final s = AccountSnapshot.fromJson(const {
        'quotas': [
          {
            'key': 'api_calls_limit',
            'label': 'زيارات API',
            'description': '',
            'limit': 100.0,
            'used': 42.0,
            'remaining': null,
            'percent': 0.0,
            'is_unlimited': true,
            'reset_period': 'monthly',
            'status': 'active',
            'source_label': 'معدل لهذا المشترك',
          },
        ],
      });
      final q = s.quotas.first;
      expect(q.isUnlimited, isTrue);
      expect(q.remaining, isNull);
      // Unlimited quotas always read as a calm 0.0 progress so the bar
      // never tells the user they're "almost out" of something infinite.
      expect(q.progress, 0.0);
      // Honest numbers still surface for the "X used" line.
      expect(q.used, 42.0);
      expect(q.limit, 100.0);
    });

    test('quotas is empty when the key is absent', () {
      final s = AccountSnapshot.fromJson(const {});
      expect(s.quotas, isEmpty);
    });

    test('quotas gracefully drops non-map entries', () {
      final s = AccountSnapshot.fromJson(const {
        'quotas': [
          {
            'key': 'a',
            'label': 'A',
            'limit': 1.0,
            'used': 0.0,
            'remaining': 1.0,
            'percent': 0.0,
            'is_unlimited': false,
            'reset_period': 'monthly',
            'status': 'active',
          },
          'not a map',
          null,
          42,
        ],
      });
      expect(s.quotas.length, 1);
      expect(s.quotas.first.key, 'a');
    });

    test('quotas coerces stringified numbers + missing fields', () {
      final s = AccountSnapshot.fromJson(const {
        'quotas': [
          {
            'key': 'devices_limit',
            'label': 'الأجهزة',
            // String-encoded numbers (defensive against future serializer
            // changes / Android Bundle round-trips).
            'limit': '5',
            'used': '2',
            'remaining': '3',
            'percent': '40',
            'is_unlimited': false,
            // Missing reset_period + status + source_label.
          },
        ],
      });
      final q = s.quotas.first;
      expect(q.limit, 5.0);
      expect(q.used, 2.0);
      expect(q.remaining, 3.0);
      expect(q.percent, 40.0);
      expect(q.resetPeriod, '');
      expect(q.status, '');
      expect(q.sourceLabel, '');
    });

    test('progress clamps out-of-range percents into [0, 1]', () {
      final s = AccountSnapshot.fromJson(const {
        'quotas': [
          {
            'key': 'over',
            'label': 'Over',
            'limit': 10.0,
            'used': 15.0,
            'remaining': 0.0,
            'percent': 150.0, // backend should clamp, but be defensive
            'is_unlimited': false,
            'status': 'active',
          },
          {
            'key': 'under',
            'label': 'Under',
            'limit': 10.0,
            'used': 0.0,
            'remaining': 10.0,
            'percent': -5.0,
            'is_unlimited': false,
            'status': 'active',
          },
        ],
      });
      expect(s.quotas[0].progress, 1.0);
      expect(s.quotas[1].progress, 0.0);
    });

    test('inactive quota is reflected via isActive=false', () {
      final s = AccountSnapshot.fromJson(const {
        'quotas': [
          {
            'key': 'support_cases_limit',
            'label': 'تذاكر الدعم',
            'limit': 0.0,
            'used': 0.0,
            'remaining': 0.0,
            'percent': 0.0,
            'is_unlimited': false,
            'status': 'inactive',
          },
        ],
      });
      expect(s.quotas.first.isActive, isFalse);
      expect(s.quotas.first.status, 'inactive');
    });
  });
}
