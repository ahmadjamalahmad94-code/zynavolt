// User-facing Arabic labels for the raw English / snake_case slugs that
// appear inside the /api/mobile/account payload.
//
// The backend surfaces three kinds of internal identifiers we don't want
// shoved at the user verbatim:
//
//   1) plan-feature flags    (`can_manage_devices`, `can_use_telegram`, …)
//   2) mobile-API section ids (`auth`, `devices`, `loads`, …)
//   3) role codes             (`admin`, `manager`, `owner`, `user`)
//
// For (1) and (2) the backend has no `_ar` companion field — the slug is
// the only thing on the wire. For (3) the server emits a translated
// `role.label` already, but if that label is empty we still want a clean
// Arabic fallback instead of showing the raw code.
//
// Unknown future slugs fall back to the raw key so users still see
// *something* informative until a translation lands. Adding a new mapping
// later requires no other code change — just an entry in one of the maps
// below.

class AccountLabels {
  const AccountLabels._();

  /// Subscription plan-feature flags. Sourced from
  /// `app/services/subscriptions.py::seed_default_plans` features_json
  /// and from `app/__init__.py::_default_permissions_for_role`.
  static const Map<String, String> _planFeatures = {
    'can_manage_devices': 'إدارة الأجهزة',
    'can_manage_integrations': 'إدارة التكاملات',
    'can_use_telegram': 'استخدام تيليجرام',
    'can_use_sms': 'استخدام الرسائل SMS',
    'can_view_diagnostics': 'عرض التشخيص',
    'can_view_api_explorer': 'مستكشف الواجهة البرمجية',
    'can_manage_users': 'إدارة المستخدمين',
    'can_manage_support': 'إدارة الدعم',
    'can_manage_finance': 'إدارة الفواتير',
    'can_manage_subscriptions': 'إدارة الاشتراكات',
    'can_view_logs': 'عرض السجلات',
    'can_configure_integrations': 'ضبط التكاملات',
  };

  /// Mobile API section slugs returned in `capabilities.mobile_api_sections`.
  static const Map<String, String> _apiSections = {
    'auth': 'المصادقة',
    'profile': 'الملف الشخصي',
    'onboarding': 'التهيئة',
    'dashboard': 'الرئيسية',
    'devices': 'الأجهزة',
    'loads': 'الأحمال',
    'notifications': 'الإشعارات',
    'support': 'الدعم',
    'account': 'الحساب',
  };

  /// Account role codes. Backend usually emits an Arabic `role.label`
  /// already — this is only used when `label` comes back empty.
  static const Map<String, String> _roles = {
    'admin': 'مدير',
    'manager': 'مشرف',
    'owner': 'مالك',
    'user': 'مستخدم',
  };

  /// v76: quota reset-period codes returned in
  /// `account.quotas[].reset_period`. Empty string is treated as
  /// "never resets" and shown as a calm dash — not "غير معروف".
  static const Map<String, String> _quotaResetPeriods = {
    'daily': 'يومي',
    'weekly': 'أسبوعي',
    'monthly': 'شهري',
    'yearly': 'سنوي',
    'annual': 'سنوي',
    'never': 'بدون إعادة تعيين',
  };

  /// v76: quota status codes returned in `account.quotas[].status`.
  static const Map<String, String> _quotaStatuses = {
    'active': 'نشطة',
    'inactive': 'غير نشطة',
    'paused': 'موقوفة',
  };

  /// Convert a quota reset-period slug to its Arabic label. Falls back
  /// to the raw value so unknown future periods still render readable.
  static String quotaResetPeriodLabel(String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return '—';
    return _quotaResetPeriods[normalized] ?? code;
  }

  /// Convert a quota status code to its Arabic label.
  static String quotaStatusLabel(String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return '—';
    return _quotaStatuses[normalized] ?? code;
  }

  /// Convert a plan-feature slug to its Arabic label. Falls back to the
  /// raw slug so unknown future keys still render *something* readable,
  /// not an empty chip.
  static String planFeatureLabel(String slug) {
    final normalized = slug.trim().toLowerCase();
    return _planFeatures[normalized] ?? slug;
  }

  /// Convert a mobile-API section slug to its Arabic label.
  static String apiSectionLabel(String slug) {
    final normalized = slug.trim().toLowerCase();
    return _apiSections[normalized] ?? slug;
  }

  /// Convert a role code to its Arabic label (fallback only).
  static String roleLabel(String code) {
    final normalized = code.trim().toLowerCase();
    return _roles[normalized] ?? code;
  }
}
