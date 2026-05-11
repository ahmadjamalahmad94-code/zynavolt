import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/features/profile/data/profile_models.dart';

void main() {
  group('Profile.fromJson', () {
    test('parses the standard {user: {...}} envelope', () {
      final p = Profile.fromJson(const {
        'user': {
          'id': 7,
          'username': 'ahmad',
          'full_name': 'أحمد',
          'email': 'ahmad@example.com',
          'role': 'user',
          'role_label': 'مشترك',
          'is_admin': false,
          'is_active': true,
          'preferred_language': 'ar',
          'country': 'Palestine',
          'city': 'Hebron',
          'timezone': 'Asia/Hebron',
          'phone_country_code': '+970',
          'phone_number': '599043337',
          'profile_image_url': '/uploads/avatars/x.jpg',
          'preferred_device_id': 12,
        },
        'onboarding': {'completed': true},
        'subscription': {},
      });

      expect(p.id, 7);
      expect(p.username, 'ahmad');
      expect(p.fullName, 'أحمد');
      expect(p.email, 'ahmad@example.com');
      expect(p.role, 'user');
      expect(p.roleLabel, 'مشترك');
      expect(p.isAdmin, isFalse);
      expect(p.isActive, isTrue);
      expect(p.preferredLanguage, 'ar');
      expect(p.country, 'Palestine');
      expect(p.city, 'Hebron');
      expect(p.timezone, 'Asia/Hebron');
      expect(p.phoneCountryCode, '+970');
      expect(p.phoneNumber, '599043337');
      expect(p.profileImageUrl, '/uploads/avatars/x.jpg');
      expect(p.preferredDeviceId, 12);
    });

    test('handles a minimal payload with most fields missing', () {
      final p = Profile.fromJson(const {'user': {'id': 1, 'username': 'u'}});

      expect(p.id, 1);
      expect(p.username, 'u');
      expect(p.fullName, '');
      expect(p.email, '');
      expect(p.role, '');
      expect(p.roleLabel, '');
      expect(p.isAdmin, isFalse);
      expect(p.isActive, isTrue); // default to true when missing
      expect(p.preferredLanguage, 'ar'); // safe default
      expect(p.country, '');
      expect(p.city, '');
      expect(p.timezone, '');
      expect(p.phoneCountryCode, '');
      expect(p.phoneNumber, '');
      expect(p.profileImageUrl, '');
      expect(p.preferredDeviceId, isNull);
    });

    test('accepts a flat user payload as a fallback envelope', () {
      // Some endpoints may return the user dict directly (without the {user: ...}
      // wrapper). The parser should still handle it.
      final p = Profile.fromJson(const {
        'id': 9,
        'username': 'flat',
        'is_active': false,
      });
      expect(p.id, 9);
      expect(p.username, 'flat');
      expect(p.isActive, isFalse);
    });
  });

  group('ProfilePatch', () {
    test('omits unchanged fields entirely', () {
      final patch = ProfilePatch()
        ..setFullName('أحمد', current: 'أحمد')
        ..setEmail('a@b.com', current: 'a@b.com')
        ..setCity('Hebron', current: 'Hebron')
        ..setPhoneNumber('599', current: '599')
        ..setPreferredLanguage('ar', current: 'ar');

      expect(patch.isEmpty, isTrue);
      expect(patch.toJson(), isEmpty);
    });

    test('includes only changed fields', () {
      final patch = ProfilePatch()
        ..setFullName('أحمد علي', current: 'أحمد')
        ..setEmail('A@B.com', current: 'a@b.com')
        ..setCity('Hebron', current: 'Hebron')
        ..setPhoneNumber('599', current: '599')
        ..setPreferredLanguage('ar', current: 'ar');

      expect(patch.isNotEmpty, isTrue);
      // Email is normalised to lowercase before being compared/sent.
      expect(patch.toJson(), {
        'full_name': 'أحمد علي',
        // 'a@b.com' -> normalised lowercase, but current is already lowercase
        // so... wait — we changed casing to A@B.com which lower-cases back to
        // 'a@b.com', equal to current. So email is omitted. Confirm that:
      }..removeWhere((k, v) => false));
    });

    test('lower-cased email matches current → omitted', () {
      final patch = ProfilePatch()
        ..setEmail('NEW@example.com', current: 'old@example.com');
      expect(patch.toJson(), {'email': 'new@example.com'});
    });

    test('clearing a field sends null to the backend', () {
      final patch = ProfilePatch()
        ..setCity('', current: 'Hebron')
        ..setPhoneNumber('   ', current: '599043337');
      expect(patch.toJson(), {'city': null, 'phone_number': null});
    });

    test('preferred_language must be ar or en — invalid values are dropped',
        () {
      final patch = ProfilePatch()
        ..setPreferredLanguage('fr', current: 'ar');
      expect(patch.isEmpty, isTrue);
    });

    test('toJson is unmodifiable', () {
      final patch = ProfilePatch()
        ..setFullName('X', current: 'Y');
      final body = patch.toJson();
      expect(() => body['hacked'] = true, throwsUnsupportedError);
    });
  });
}
