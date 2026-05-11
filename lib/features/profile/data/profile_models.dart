// Mirror of GET /api/mobile/profile data envelope.
//
// Fields taken verbatim from the backend `_profile_payload` builder in
// `app/blueprints/mobile_api.py`. Defensive parsing — unknown keys ignored,
// missing optional values default to empty/null so a partial payload never
// throws.

class Profile {
  Profile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    required this.roleLabel,
    required this.isAdmin,
    required this.isActive,
    required this.preferredLanguage,
    required this.country,
    required this.city,
    required this.timezone,
    required this.phoneCountryCode,
    required this.phoneNumber,
    required this.profileImageUrl,
    required this.preferredDeviceId,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? json;
    return Profile(
      id: (user['id'] ?? 0) as int,
      username: (user['username'] ?? '').toString(),
      fullName: (user['full_name'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      role: (user['role'] ?? '').toString(),
      roleLabel: (user['role_label'] ?? '').toString(),
      isAdmin: user['is_admin'] == true,
      isActive: user['is_active'] != false, // default to true if missing
      preferredLanguage: (user['preferred_language'] ?? 'ar').toString(),
      country: (user['country'] ?? '').toString(),
      city: (user['city'] ?? '').toString(),
      timezone: (user['timezone'] ?? '').toString(),
      phoneCountryCode: (user['phone_country_code'] ?? '').toString(),
      phoneNumber: (user['phone_number'] ?? '').toString(),
      profileImageUrl: (user['profile_image_url'] ?? '').toString(),
      preferredDeviceId: user['preferred_device_id'] is int
          ? user['preferred_device_id'] as int
          : null,
    );
  }

  final int id;
  final String username;
  final String fullName;
  final String email;
  final String role;
  final String roleLabel;
  final bool isAdmin;
  final bool isActive;
  final String preferredLanguage;
  final String country;
  final String city;
  final String timezone;
  final String phoneCountryCode;
  final String phoneNumber;
  final String profileImageUrl;
  final int? preferredDeviceId;
}

/// Builder for `PATCH /api/mobile/profile`. Only fields that the user
/// actually changed are included in the JSON body. Anything not added
/// here is **not sent**.
///
/// v44 adds catalog-validated setters (country code, timezone, phone
/// country code). Each catalog setter sends the value the backend
/// validates against `find_country` / `timezones_for_template()` /
/// `phone_prefixes_for_template()` — the UI is responsible for picking
/// values from the live catalog (`locationCatalogProvider`).
class ProfilePatch {
  ProfilePatch();

  final Map<String, Object?> _body = <String, Object?>{};

  /// Returns the JSON body, including only the fields the caller actually
  /// changed. An empty map means there is nothing to PATCH.
  Map<String, Object?> toJson() => Map.unmodifiable(_body);

  bool get isEmpty => _body.isEmpty;
  bool get isNotEmpty => _body.isNotEmpty;

  /// `_setIfChanged` writes the cleaned value when it differs from the
  /// current profile value, and converts the empty string to `null` so the
  /// backend can clear nullable columns honestly (matches its own
  /// `or None` cleaning).
  void setFullName(String? next, {required String current}) {
    _setIfChanged('full_name', next, current);
  }

  void setEmail(String? next, {required String current}) {
    _setIfChanged('email', next, current, normalize: (s) => s.toLowerCase());
  }

  void setPhoneNumber(String? next, {required String current}) {
    _setIfChanged('phone_number', next, current);
  }

  void setCity(String? next, {required String current}) {
    _setIfChanged('city', next, current);
  }

  void setPreferredLanguage(String next, {required String current}) {
    if (next != current && (next == 'ar' || next == 'en')) {
      _body['preferred_language'] = next;
    }
  }

  /// Sends `country_code` (ISO-2). Backend will resolve to the localised
  /// `country` name automatically and may auto-suggest a matching dial /
  /// timezone if those fields are empty. Pass `null` or empty to keep the
  /// current value.
  void setCountryCode(String? next, {required String current}) {
    final cleaned = (next ?? '').trim().toUpperCase();
    if (cleaned == current.trim().toUpperCase()) return;
    if (cleaned.isEmpty) return; // never *clear* country via PATCH from UI
    _body['country_code'] = cleaned;
  }

  /// Catalog-validated timezone (e.g. `Asia/Hebron`). Backend rejects
  /// values outside `timezones_for_template()` with `invalid_timezone`.
  void setTimezone(String? next, {required String current}) {
    final cleaned = (next ?? '').trim();
    if (cleaned == current.trim()) return;
    if (cleaned.isEmpty) return;
    _body['timezone'] = cleaned;
  }

  /// Phone country dial (e.g. `+970`). Backend rejects values outside
  /// `phone_prefixes_for_template()` with `invalid_phone_country_code`.
  void setPhoneCountryCode(String? next, {required String current}) {
    final cleaned = (next ?? '').trim();
    if (cleaned == current.trim()) return;
    if (cleaned.isEmpty) return;
    _body['phone_country_code'] = cleaned;
  }

  void _setIfChanged(
    String key,
    String? rawNext,
    String current, {
    String Function(String)? normalize,
  }) {
    final cleaned = (rawNext ?? '').trim();
    final normalized = normalize == null ? cleaned : normalize(cleaned);
    if (normalized == current.trim()) return;
    _body[key] = normalized.isEmpty ? null : normalized;
  }
}
