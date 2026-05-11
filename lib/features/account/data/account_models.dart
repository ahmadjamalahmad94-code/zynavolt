// Mirror of GET /api/mobile/account.
//
// Backend builder: `_account_payload` in `app/blueprints/mobile_api.py`.
// v51 is **read-only**: no profile/password mutation, no billing actions,
// no logout-all, no delete. Capabilities are surfaced verbatim from the
// server so the UI never claims a feature the backend hasn't enabled.

class AccountRole {
  AccountRole({required this.code, required this.label, required this.isAdmin});

  factory AccountRole.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return AccountRole(
      code: (j['code'] ?? '').toString(),
      label: (j['label'] ?? '').toString(),
      isAdmin: j['is_admin'] == true,
    );
  }

  final String code;
  final String label;
  final bool isAdmin;
}

class AccountPlan {
  AccountPlan({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.price,
    required this.currency,
    required this.maxDevices,
    required this.features,
  });

  factory AccountPlan.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return AccountPlan.empty();
    int? iOrNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) return int.tryParse(v);
      return null;
    }

    double? dOrNull(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String && v.isNotEmpty) return double.tryParse(v);
      return null;
    }

    final rawFeatures = json['features'];
    final features = <String>[];
    if (rawFeatures is List) {
      for (final e in rawFeatures) {
        if (e == null) continue;
        features.add(e.toString());
      }
    } else if (rawFeatures is Map) {
      // Defensive: if the backend ever switches to a map of flag → bool,
      // keep the truthy flags' names so the UI still shows something.
      rawFeatures.forEach((k, v) {
        if (v == true) features.add(k.toString());
      });
    }

    return AccountPlan(
      id: iOrNull(json['id']),
      code: (json['code'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? '').toString(),
      nameEn: (json['name_en'] ?? '').toString(),
      price: dOrNull(json['price']),
      currency: (json['currency'] ?? '').toString(),
      maxDevices: iOrNull(json['max_devices']),
      features: features,
    );
  }

  static AccountPlan empty() => AccountPlan(
        id: null,
        code: '',
        nameAr: '',
        nameEn: '',
        price: null,
        currency: '',
        maxDevices: null,
        features: const [],
      );

  final int? id;
  final String code;
  final String nameAr;
  final String nameEn;
  final double? price;
  final String currency;
  final int? maxDevices;
  final List<String> features;

  /// Convenience: best-effort Arabic-first display name with code fallback.
  String displayName({String preferred = 'ar'}) {
    if (preferred == 'ar' && nameAr.isNotEmpty) return nameAr;
    if (preferred == 'en' && nameEn.isNotEmpty) return nameEn;
    if (nameAr.isNotEmpty) return nameAr;
    if (nameEn.isNotEmpty) return nameEn;
    return code;
  }

  bool get hasName =>
      nameAr.isNotEmpty || nameEn.isNotEmpty || code.isNotEmpty;
}

class AccountSubscription {
  AccountSubscription({
    required this.tenantId,
    required this.status,
    required this.expiresAt,
    required this.trialEndsAt,
    required this.maxDevices,
    required this.plan,
  });

  factory AccountSubscription.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    int? iOrNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) return int.tryParse(v);
      return null;
    }

    return AccountSubscription(
      tenantId: iOrNull(j['tenant_id']),
      status: (j['status'] ?? '').toString(),
      expiresAt: j['expires_at']?.toString(),
      trialEndsAt: j['trial_ends_at']?.toString(),
      maxDevices: iOrNull(j['max_devices']),
      plan: AccountPlan.fromJson(
        (j['plan'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  final int? tenantId;
  final String status;
  final String? expiresAt;
  final String? trialEndsAt;
  final int? maxDevices;
  final AccountPlan plan;

  bool get isTrial => trialEndsAt != null && trialEndsAt!.isNotEmpty;
}

class AccountDeviceCounts {
  AccountDeviceCounts({
    required this.total,
    required this.active,
    required this.selectedDeviceId,
  });

  factory AccountDeviceCounts.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    int i(Object? v, {int fallback = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    int? iOrNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) return int.tryParse(v);
      return null;
    }

    return AccountDeviceCounts(
      total: i(j['total']),
      active: i(j['active']),
      selectedDeviceId: iOrNull(j['selected_device_id']),
    );
  }

  final int total;
  final int active;
  final int? selectedDeviceId;
}

class AccountCapabilities {
  AccountCapabilities({
    required this.profileUpdate,
    required this.passwordChange,
    required this.logoutAllRefreshTokens,
    required this.accountDeletion,
    required this.mobileApiSections,
  });

  factory AccountCapabilities.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    final rawSections = j['mobile_api_sections'];
    final sections = <String>[];
    if (rawSections is List) {
      for (final e in rawSections) {
        if (e != null) sections.add(e.toString());
      }
    }
    return AccountCapabilities(
      profileUpdate: j['profile_update'] == true,
      passwordChange: j['password_change'] == true,
      logoutAllRefreshTokens: j['logout_all_refresh_tokens'] == true,
      accountDeletion: j['account_deletion'] == true,
      mobileApiSections: sections,
    );
  }

  final bool profileUpdate;
  final bool passwordChange;
  final bool logoutAllRefreshTokens;
  final bool accountDeletion;
  final List<String> mobileApiSections;
}

class AccountSnapshot {
  AccountSnapshot({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    required this.subscription,
    required this.devices,
    required this.capabilities,
  });

  factory AccountSnapshot.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    int i(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return AccountSnapshot(
      userId: i(user['id']),
      username: (user['username'] ?? '').toString(),
      fullName: (user['full_name'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      role: AccountRole.fromJson(
        (json['role'] as Map?)?.cast<String, dynamic>(),
      ),
      subscription: AccountSubscription.fromJson(
        (json['subscription'] as Map?)?.cast<String, dynamic>(),
      ),
      devices: AccountDeviceCounts.fromJson(
        (json['devices'] as Map?)?.cast<String, dynamic>(),
      ),
      capabilities: AccountCapabilities.fromJson(
        (json['capabilities'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  final int userId;
  final String username;
  final String fullName;
  final String email;
  final AccountRole role;
  final AccountSubscription subscription;
  final AccountDeviceCounts devices;
  final AccountCapabilities capabilities;
}
