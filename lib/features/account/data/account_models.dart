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
    required this.planChangeRequest,
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
      // v66: server advertises whether the mobile plan-change request
      // surface is enabled. We default to `false` if the key is absent
      // (older backends) so the action stays hidden honestly.
      planChangeRequest: j['plan_change_request'] == true,
      mobileApiSections: sections,
    );
  }

  final bool profileUpdate;
  final bool passwordChange;
  final bool logoutAllRefreshTokens;
  final bool accountDeletion;

  /// v66: server-declared support for submitting a plan-change
  /// request through `POST /api/mobile/account/subscription/request-change`.
  /// When `false` the mobile UI must keep the action hidden.
  final bool planChangeRequest;

  final List<String> mobileApiSections;
}

/// v66: one row in `GET /api/mobile/account → available_plans[]`.
/// Shape mirrors `AccountPlan` plus an `is_current` flag the server
/// computes against the user's tenant. We expose them as a dedicated
/// class so the screen can render the marker without sharing logic
/// with the current-plan card.
class AvailablePlan {
  AvailablePlan({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.price,
    required this.currency,
    required this.maxDevices,
    required this.features,
    required this.isCurrent,
  });

  factory AvailablePlan.fromJson(Map<String, dynamic> json) {
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
      rawFeatures.forEach((k, v) {
        if (v == true) features.add(k.toString());
      });
    }

    return AvailablePlan(
      id: iOrNull(json['id']),
      code: (json['code'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? '').toString(),
      nameEn: (json['name_en'] ?? '').toString(),
      price: dOrNull(json['price']),
      currency: (json['currency'] ?? '').toString(),
      maxDevices: iOrNull(json['max_devices']),
      features: features,
      isCurrent: json['is_current'] == true,
    );
  }

  final int? id;
  final String code;
  final String nameAr;
  final String nameEn;
  final double? price;
  final String currency;
  final int? maxDevices;
  final List<String> features;
  final bool isCurrent;

  String displayName({String preferred = 'ar'}) {
    if (preferred == 'ar' && nameAr.isNotEmpty) return nameAr;
    if (preferred == 'en' && nameEn.isNotEmpty) return nameEn;
    if (nameAr.isNotEmpty) return nameAr;
    if (nameEn.isNotEmpty) return nameEn;
    return code;
  }
}

/// v66: projection of an open `SupportCase(case_type='plan_change_request')`
/// exposed via `GET /api/mobile/account → pending_plan_change_request`.
///
/// `requestedPlanId` is best-effort — when the server can't resolve the
/// stored subject's plan name against the current catalog (e.g. plan
/// renamed admin-side) the id is `null` but the textual name still
/// renders.
class PendingPlanChangeRequest {
  PendingPlanChangeRequest({
    required this.id,
    required this.status,
    required this.requestedPlanId,
    required this.requestedPlanName,
    required this.message,
    required this.createdAt,
  });

  factory PendingPlanChangeRequest.fromJson(Map<String, dynamic> json) {
    int? iOrNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) return int.tryParse(v);
      return null;
    }

    String? sOrNull(Object? v) {
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    return PendingPlanChangeRequest(
      id: iOrNull(json['id']) ?? 0,
      status: (json['status'] ?? '').toString(),
      requestedPlanId: iOrNull(json['requested_plan_id']),
      requestedPlanName: (json['requested_plan_name'] ?? '').toString(),
      message: sOrNull(json['message']),
      createdAt: sOrNull(json['created_at']),
    );
  }

  final int id;
  final String status;
  final int? requestedPlanId;
  final String requestedPlanName;
  final String? message;
  final String? createdAt;
}

/// v76: one row in `GET /api/mobile/account → quotas[]`.
///
/// Mirrors the backend `_mobile_quotas_payload` contract — 11 locked keys.
/// `remaining` is `null` when `isUnlimited == true`; otherwise it's a
/// non-negative number. `percent` is a 0–100 float (the backend clamps
/// `>100` cases for us). `status` is one of `'active'`, `'inactive'`,
/// or `'paused'` (read-only — the mobile UI only renders, never mutates).
class AccountQuota {
  AccountQuota({
    required this.key,
    required this.label,
    required this.description,
    required this.limit,
    required this.used,
    required this.remaining,
    required this.percent,
    required this.isUnlimited,
    required this.resetPeriod,
    required this.status,
    required this.sourceLabel,
  });

  factory AccountQuota.fromJson(Map<String, dynamic> json) {
    double d(Object? v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String && v.isNotEmpty) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    double? dOrNull(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String && v.isNotEmpty) return double.tryParse(v);
      return null;
    }

    return AccountQuota(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      limit: d(json['limit']),
      used: d(json['used']),
      // Backend sends `null` when unlimited, otherwise a number.
      remaining: dOrNull(json['remaining']),
      percent: d(json['percent']),
      isUnlimited: json['is_unlimited'] == true,
      resetPeriod: (json['reset_period'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      sourceLabel: (json['source_label'] ?? '').toString(),
    );
  }

  final String key;
  final String label;
  final String description;
  final double limit;
  final double used;
  final double? remaining;
  final double percent;
  final bool isUnlimited;
  final String resetPeriod;
  final String status;
  final String sourceLabel;

  /// Convenience: 0.0–1.0 progress fraction for the soft progress bar.
  /// Unlimited quotas always read as `0.0` so the bar stays calm.
  double get progress {
    if (isUnlimited) return 0.0;
    final p = percent / 100.0;
    if (p.isNaN || p.isInfinite) return 0.0;
    if (p < 0) return 0.0;
    if (p > 1) return 1.0;
    return p;
  }

  bool get isActive => status == 'active';
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
    required this.availablePlans,
    required this.pendingPlanChangeRequest,
    required this.quotas,
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

    // v66: available_plans is always a list (defensive empty when absent).
    final rawPlans = json['available_plans'];
    final availablePlans = <AvailablePlan>[];
    if (rawPlans is List) {
      for (final entry in rawPlans) {
        if (entry is Map) {
          availablePlans.add(
            AvailablePlan.fromJson(entry.cast<String, dynamic>()),
          );
        }
      }
    }

    // v66: pending_plan_change_request is `null` OR a single dict.
    PendingPlanChangeRequest? pending;
    final rawPending = json['pending_plan_change_request'];
    if (rawPending is Map) {
      pending = PendingPlanChangeRequest.fromJson(
        rawPending.cast<String, dynamic>(),
      );
    }

    // v76: quotas is always a list (defensive empty when absent or
    // when the server skipped it for users without a tenant).
    final rawQuotas = json['quotas'];
    final quotas = <AccountQuota>[];
    if (rawQuotas is List) {
      for (final entry in rawQuotas) {
        if (entry is Map) {
          quotas.add(AccountQuota.fromJson(entry.cast<String, dynamic>()));
        }
      }
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
      availablePlans: availablePlans,
      pendingPlanChangeRequest: pending,
      quotas: quotas,
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

  /// v66: every active plan the user could request — empty list when
  /// the server returned none. The current plan is marked via
  /// `AvailablePlan.isCurrent`.
  final List<AvailablePlan> availablePlans;

  /// v66: most recent `open` plan-change request — `null` when none
  /// is pending. The mobile screen shows a banner when this is set
  /// and hides the "request change" action.
  final PendingPlanChangeRequest? pendingPlanChangeRequest;

  /// v76: subscriber-visible quota rows, one per active tenant quota.
  /// Empty when the user has no tenant or when the server returned no
  /// rows. The mobile screen hides the quotas card when this is empty.
  final List<AccountQuota> quotas;
}
