// Mirror of GET /api/mobile/location-catalog data envelope.
//
// Field names taken verbatim from `_location_payload()` in
// `app/blueprints/mobile_api.py`. Defensive parsing — unknown keys ignored,
// missing optional fields default to safe empty values so a partial payload
// never throws.

class LocationCatalog {
  LocationCatalog({
    required this.countries,
    required this.phonePrefixes,
    required this.timezoneGroups,
  });

  factory LocationCatalog.fromJson(Map<String, dynamic> json) {
    final rawCountries = (json['countries'] as List?) ?? const [];
    final rawPhones = (json['phone_prefixes'] as List?) ?? const [];
    final rawGroups = (json['timezone_groups'] as List?) ?? const [];
    return LocationCatalog(
      countries: rawCountries
          .whereType<Map<String, dynamic>>()
          .map(CatalogCountry.fromJson)
          .where((c) => c.code.isNotEmpty)
          .toList(growable: false),
      phonePrefixes: rawPhones
          .whereType<Map<String, dynamic>>()
          .map(CatalogPhonePrefix.fromJson)
          .where((p) => p.dial.isNotEmpty)
          .toList(growable: false),
      timezoneGroups: rawGroups
          .whereType<Map<String, dynamic>>()
          .map(CatalogTimezoneGroup.fromJson)
          .toList(growable: false),
    );
  }

  final List<CatalogCountry> countries;
  final List<CatalogPhonePrefix> phonePrefixes;
  final List<CatalogTimezoneGroup> timezoneGroups;

  /// Flat timezone list derived from [timezoneGroups]. Each entry carries
  /// both the raw `tz` value (what the backend expects) and a localised
  /// label suitable for display.
  List<CatalogTimezoneItem> flatTimezones() {
    final out = <CatalogTimezoneItem>[];
    for (final g in timezoneGroups) {
      for (final item in g.items) {
        out.add(item);
      }
    }
    return out;
  }

  /// Look up a country by its localised display name (Arabic or English).
  /// Returns `null` if no match — the calling UI then falls back to a
  /// "current value not in catalog" placeholder.
  CatalogCountry? findCountryByName(String? name) {
    final needle = (name ?? '').trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final c in countries) {
      if (c.nameAr.trim().toLowerCase() == needle) return c;
      if (c.nameEn.trim().toLowerCase() == needle) return c;
    }
    return null;
  }

  /// Look up a country by its ISO-2 code.
  CatalogCountry? findCountryByCode(String? code) {
    final needle = (code ?? '').trim().toUpperCase();
    if (needle.isEmpty) return null;
    for (final c in countries) {
      if (c.code == needle) return c;
    }
    return null;
  }

  bool hasTimezone(String? tz) {
    final needle = (tz ?? '').trim();
    if (needle.isEmpty) return false;
    return flatTimezones().any((t) => t.tz == needle);
  }

  bool hasPhonePrefix(String? dial) {
    final needle = (dial ?? '').trim();
    if (needle.isEmpty) return false;
    return phonePrefixes.any((p) => p.dial == needle);
  }
}

class CatalogCountry {
  CatalogCountry({
    required this.code,
    required this.dial,
    required this.nameAr,
    required this.nameEn,
    required this.timezone,
  });

  factory CatalogCountry.fromJson(Map<String, dynamic> json) => CatalogCountry(
        code: (json['code'] ?? '').toString().toUpperCase(),
        dial: (json['dial'] ?? '').toString(),
        nameAr: (json['name_ar'] ?? '').toString(),
        nameEn: (json['name_en'] ?? '').toString(),
        timezone: (json['timezone'] ?? '').toString(),
      );

  final String code;
  final String dial;
  final String nameAr;
  final String nameEn;
  final String timezone;

  String label(String lang) {
    final name = lang == 'en' ? nameEn : nameAr;
    return name.isNotEmpty ? name : code;
  }
}

class CatalogPhonePrefix {
  CatalogPhonePrefix({
    required this.code,
    required this.dial,
    required this.label,
  });

  factory CatalogPhonePrefix.fromJson(Map<String, dynamic> json) =>
      CatalogPhonePrefix(
        code: (json['code'] ?? '').toString().toUpperCase(),
        dial: (json['dial'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
      );

  final String code;
  final String dial;
  final String label;
}

class CatalogTimezoneGroup {
  CatalogTimezoneGroup({
    required this.groupAr,
    required this.groupEn,
    required this.items,
  });

  factory CatalogTimezoneGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return CatalogTimezoneGroup(
      groupAr: (json['group_ar'] ?? '').toString(),
      groupEn: (json['group_en'] ?? '').toString(),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(CatalogTimezoneItem.fromJson)
          .where((i) => i.tz.isNotEmpty)
          .toList(growable: false),
    );
  }

  final String groupAr;
  final String groupEn;
  final List<CatalogTimezoneItem> items;
}

class CatalogTimezoneItem {
  CatalogTimezoneItem({
    required this.tz,
    required this.labelAr,
    required this.labelEn,
  });

  factory CatalogTimezoneItem.fromJson(Map<String, dynamic> json) =>
      CatalogTimezoneItem(
        tz: (json['tz'] ?? '').toString(),
        labelAr: (json['label_ar'] ?? '').toString(),
        labelEn: (json['label_en'] ?? '').toString(),
      );

  final String tz;
  final String labelAr;
  final String labelEn;

  String label(String lang) {
    final raw = lang == 'en' ? labelEn : labelAr;
    return raw.isNotEmpty ? raw : tz;
  }
}
