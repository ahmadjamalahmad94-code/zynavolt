import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/profile/data/location_catalog_models.dart';

void main() {
  group('LocationCatalog.fromJson', () {
    test('parses a complete catalog payload', () {
      final catalog = LocationCatalog.fromJson(const {
        'countries': [
          {
            'code': 'PS',
            'dial': '+970',
            'name_ar': 'فلسطين',
            'name_en': 'Palestine',
            'timezone': 'Asia/Hebron',
          },
          {
            'code': 'JO',
            'dial': '+962',
            'name_ar': 'الأردن',
            'name_en': 'Jordan',
            'timezone': 'Asia/Amman',
          },
        ],
        'phone_prefixes': [
          {'code': 'PS', 'dial': '+970', 'label': 'PS +970'},
          {'code': 'JO', 'dial': '+962', 'label': 'JO +962'},
        ],
        'cities': {},
        'timezones': ['Asia/Hebron', 'Asia/Amman'],
        'timezone_groups': [
          {
            'group_ar': 'الخليج / الشرق الأوسط',
            'group_en': 'Gulf / Middle East',
            'items': [
              {
                'tz': 'Asia/Hebron',
                'label_ar': 'فلسطين (Asia/Hebron)',
                'label_en': 'Palestine (Asia/Hebron)',
              },
              {
                'tz': 'Asia/Amman',
                'label_ar': 'الأردن (Asia/Amman)',
                'label_en': 'Jordan (Asia/Amman)',
              },
            ],
          },
        ],
      });

      expect(catalog.countries, hasLength(2));
      expect(catalog.countries.first.code, 'PS');
      expect(catalog.countries.first.label('ar'), 'فلسطين');
      expect(catalog.countries.first.label('en'), 'Palestine');
      expect(catalog.phonePrefixes, hasLength(2));
      expect(catalog.phonePrefixes.first.dial, '+970');
      expect(catalog.timezoneGroups, hasLength(1));
      expect(catalog.flatTimezones(), hasLength(2));
      expect(catalog.flatTimezones().first.tz, 'Asia/Hebron');
      expect(catalog.flatTimezones().first.label('ar'),
          'فلسطين (Asia/Hebron)');
    });

    test('handles a missing/partial payload defensively', () {
      final catalog = LocationCatalog.fromJson(const {});
      expect(catalog.countries, isEmpty);
      expect(catalog.phonePrefixes, isEmpty);
      expect(catalog.timezoneGroups, isEmpty);
      expect(catalog.flatTimezones(), isEmpty);
    });

    test('skips countries with empty code and prefixes with empty dial', () {
      final catalog = LocationCatalog.fromJson(const {
        'countries': [
          {'code': '', 'dial': '+1', 'name_ar': 'X', 'name_en': 'X'},
          {'code': 'US', 'dial': '+1', 'name_ar': 'الولايات', 'name_en': 'USA'},
        ],
        'phone_prefixes': [
          {'code': 'US', 'dial': '+1', 'label': 'US +1'},
          {'code': 'XX', 'dial': '', 'label': 'invalid'},
        ],
      });
      expect(catalog.countries, hasLength(1));
      expect(catalog.countries.first.code, 'US');
      expect(catalog.phonePrefixes, hasLength(1));
      expect(catalog.phonePrefixes.first.dial, '+1');
    });
  });

  group('lookup helpers', () {
    final catalog = LocationCatalog.fromJson(const {
      'countries': [
        {
          'code': 'PS',
          'dial': '+970',
          'name_ar': 'فلسطين',
          'name_en': 'Palestine',
          'timezone': 'Asia/Hebron',
        },
        {
          'code': 'JO',
          'dial': '+962',
          'name_ar': 'الأردن',
          'name_en': 'Jordan',
          'timezone': 'Asia/Amman',
        },
      ],
      'phone_prefixes': [
        {'code': 'PS', 'dial': '+970', 'label': 'PS +970'},
      ],
      'timezone_groups': [
        {
          'group_ar': 'X',
          'group_en': 'X',
          'items': [
            {'tz': 'Asia/Hebron', 'label_ar': 'فلسطين', 'label_en': 'PS'},
          ],
        },
      ],
    });

    test('findCountryByName matches Arabic names', () {
      final c = catalog.findCountryByName('فلسطين');
      expect(c, isNotNull);
      expect(c!.code, 'PS');
    });

    test('findCountryByName matches English names', () {
      final c = catalog.findCountryByName('Jordan');
      expect(c, isNotNull);
      expect(c!.code, 'JO');
    });

    test('findCountryByName returns null on no match', () {
      expect(catalog.findCountryByName('Atlantis'), isNull);
      expect(catalog.findCountryByName(''), isNull);
      expect(catalog.findCountryByName(null), isNull);
    });

    test('findCountryByCode is case-insensitive', () {
      expect(catalog.findCountryByCode('ps')!.nameAr, 'فلسطين');
      expect(catalog.findCountryByCode('PS')!.nameAr, 'فلسطين');
      expect(catalog.findCountryByCode('zz'), isNull);
    });

    test('hasTimezone reflects the flat timezone list', () {
      expect(catalog.hasTimezone('Asia/Hebron'), isTrue);
      expect(catalog.hasTimezone('Mars/Olympus'), isFalse);
      expect(catalog.hasTimezone(null), isFalse);
    });

    test('hasPhonePrefix reflects the prefixes list', () {
      expect(catalog.hasPhonePrefix('+970'), isTrue);
      expect(catalog.hasPhonePrefix('+999'), isFalse);
      expect(catalog.hasPhonePrefix(''), isFalse);
    });
  });
}
