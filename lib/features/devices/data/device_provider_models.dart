// Mirror of GET /api/mobile/device-providers items.
//
// The backend's `_provider_payloads()` (see
// `web/app/blueprints/mobile_api.py:798+`) returns one entry per
// provider in the v45 catalog with:
//   * identity:     code / name / display_name / provider / category
//   * auth:         auth_mode / base_url
//   * tier (v45):   support_tier + support_tier_label (+ _en)
//   * status:       status (lifecycle string e.g. 'ready')
//   * fields:       fields[] — each has name / label / required / secret
//   * notes:        notes_ar / notes_en
//
// v48 only needs a subset for the add-device flow:
//   * code (used as `device_type` in the create POST)
//   * displayName (Arabic-friendly)
//   * supportTierLabel (the v45 Arabic badge)
//   * fields[] (rendered as informational chips so the user knows
//     which credentials will be needed in the web setup step)
//   * notes_ar (shown as a calm subtitle when present)

class ProviderOption {
  ProviderOption({
    required this.code,
    required this.displayName,
    required this.supportTier,
    required this.supportTierLabel,
    required this.fields,
    required this.notesAr,
  });

  factory ProviderOption.fromJson(Map<String, dynamic> json) => ProviderOption(
        code: (json['code'] ?? '').toString(),
        displayName: (json['display_name'] ?? json['name'] ?? '').toString(),
        // v45 — backend already localises the tier label. Falls back to
        // empty string when the backend predates v45 (UI hides the badge).
        supportTier: (json['support_tier'] ?? '').toString(),
        supportTierLabel:
            (json['support_tier_label'] ?? '').toString(),
        fields: _parseFields(json['fields']),
        notesAr: (json['notes_ar'] ?? '').toString(),
      );

  final String code;
  final String displayName;
  final String supportTier;
  final String supportTierLabel;
  final List<ProviderFieldSpec> fields;
  final String notesAr;

  /// Only the **required** credential fields, for the post-create
  /// "what you'll need next" preview. Optional fields are intentionally
  /// hidden in the v48 minimal flow.
  List<ProviderFieldSpec> get requiredFields =>
      fields.where((f) => f.required).toList(growable: false);
}

class ProviderFieldSpec {
  const ProviderFieldSpec({
    required this.name,
    required this.label,
    required this.required,
    required this.secret,
  });

  factory ProviderFieldSpec.fromJson(Map<String, dynamic> json) =>
      ProviderFieldSpec(
        name: (json['name'] ?? '').toString(),
        label: (json['label'] ?? json['name'] ?? '').toString(),
        required: json['required'] == true,
        secret: json['secret'] == true,
      );

  final String name;
  final String label;
  final bool required;
  final bool secret;
}

List<ProviderFieldSpec> _parseFields(Object? raw) {
  if (raw is! List) return const [];
  final out = <ProviderFieldSpec>[];
  for (final entry in raw) {
    if (entry is Map) {
      out.add(ProviderFieldSpec.fromJson(
        entry.map((k, v) => MapEntry(k.toString(), v)),
      ));
    }
  }
  return List<ProviderFieldSpec>.unmodifiable(out);
}
