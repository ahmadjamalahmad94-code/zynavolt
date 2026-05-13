import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/devices/data/device_provider_models.dart';

void main() {
  group('ProviderOption.fromJson', () {
    test('parses a complete v45 payload row', () {
      final p = ProviderOption.fromJson(const {
        'code': 'deye',
        'display_name': 'Deye Cloud',
        'name': 'Deye Cloud',
        'support_tier': 'live-supported',
        'support_tier_label': 'مدعوم',
        'support_tier_label_en': 'Supported',
        'fields': [
          {
            'name': 'deye_app_id',
            'label': 'Deye App ID',
            'required': true,
            'secret': false,
          },
          {
            'name': 'deye_app_secret',
            'label': 'سر تطبيق Deye',
            'required': true,
            'secret': true,
          },
          {
            'name': 'battery_capacity_kwh',
            'label': 'سعة البطارية',
            'required': false,
            'secret': false,
          },
        ],
        'notes_ar': 'المزوّد الأساسي.',
      });

      expect(p.code, 'deye');
      expect(p.displayName, 'Deye Cloud');
      expect(p.supportTier, 'live-supported');
      expect(p.supportTierLabel, 'مدعوم');
      expect(p.notesAr, 'المزوّد الأساسي.');
      expect(p.fields, hasLength(3));
      expect(p.fields[1].secret, isTrue);
      expect(p.requiredFields, hasLength(2));
      expect(
        p.requiredFields.map((f) => f.name).toList(),
        ['deye_app_id', 'deye_app_secret'],
      );
    });

    test('legacy / partial payload still parses (missing tier fields)',
        () {
      final p = ProviderOption.fromJson(const {
        'code': 'unknown_provider',
        'name': 'Old Provider',
        // no support_tier, no fields, no notes
      });
      expect(p.code, 'unknown_provider');
      expect(p.displayName, 'Old Provider');
      expect(p.supportTier, '');
      expect(p.supportTierLabel, '');
      expect(p.fields, isEmpty);
      expect(p.requiredFields, isEmpty);
      expect(p.notesAr, '');
    });

    test('non-list fields are coerced to empty list', () {
      final p = ProviderOption.fromJson(const {
        'code': 'x',
        'fields': 'oops, not a list',
      });
      expect(p.fields, isEmpty);
    });

    test('display_name falls back to name when missing', () {
      final p = ProviderOption.fromJson(const {
        'code': 'enphase',
        'name': 'Enphase Enlighten',
      });
      expect(p.displayName, 'Enphase Enlighten');
    });

    test('field labels default to the raw name when label is missing',
        () {
      final p = ProviderOption.fromJson(const {
        'code': 'x',
        'fields': [
          {'name': 'site_id', 'required': true},
        ],
      });
      expect(p.fields, hasLength(1));
      expect(p.fields.first.label, 'site_id');
    });
  });

  group('ProviderFieldSpec.fromJson', () {
    test('defaults required + secret to false when absent', () {
      final f = ProviderFieldSpec.fromJson(const {'name': 'x', 'label': 'X'});
      expect(f.required, isFalse);
      expect(f.secret, isFalse);
    });

    test('explicit required + secret booleans are honored', () {
      final f = ProviderFieldSpec.fromJson(const {
        'name': 'api_key',
        'label': 'مفتاح API',
        'required': true,
        'secret': true,
      });
      expect(f.required, isTrue);
      expect(f.secret, isTrue);
    });
  });
}
