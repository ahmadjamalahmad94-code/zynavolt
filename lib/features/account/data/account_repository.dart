import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'account_models.dart';
import 'plan_change_models.dart';

class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  /// GET /api/mobile/account — single payload with user, role,
  /// subscription, device counts, and capabilities.
  Future<AccountSnapshot> fetch() async {
    final response = await _api.get('/api/mobile/account');
    return AccountSnapshot.fromJson(response.data);
  }

  /// v89: `POST /api/mobile/account/change-password` with
  /// `{current_password, new_password}`. Returns `{changed: true}` on
  /// success, or throws an [ApiException] (e.g. `invalid_current_password`,
  /// `weak_password`, `missing_field`).
  ///
  /// Passwords are never logged or cached.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '/api/mobile/account/change-password',
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  /// v89: `POST /api/mobile/account/logout-all` — revokes every refresh
  /// token issued to the user. The active access token stays valid until
  /// it naturally expires (the backend marks this in
  /// `access_tokens_revoked: false`). Returns the count of revoked
  /// refresh tokens.
  Future<int> logoutAll() async {
    final response = await _api.post(
      '/api/mobile/account/logout-all',
      body: const <String, dynamic>{},
    );
    final v = response.data['revoked_refresh_tokens'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  /// v66: `POST /api/mobile/account/subscription/request-change` —
  /// submits a plan-change request. Mirrors the v65 backend contract:
  ///
  ///   * `plan_id` — required; target plan id from `available_plans[]`.
  ///   * `message` — optional short user note (server caps at 240 chars).
  ///
  /// The backend persists the request as a SupportCase and returns the
  /// **refreshed account payload** so the mobile UI updates in-place.
  /// Honest semantics: this does NOT switch the plan immediately and
  /// does NOT charge anything — the admin team triages each request.
  ///
  /// Throws an [ApiException] on `plan_id_required` / `plan_id_invalid`
  /// (400) or `plan_not_found` (404) so the calling screen can surface
  /// the backend message directly.
  Future<AccountSnapshot> submitPlanChangeRequest({
    required int planId,
    String? message,
  }) async {
    final body = <String, dynamic>{'plan_id': planId};
    final trimmed = (message ?? '').trim();
    if (trimmed.isNotEmpty) {
      body['message'] = trimmed;
    }
    final response = await _api.post(
      '/api/mobile/account/subscription/request-change',
      body: body,
    );
    return AccountSnapshot.fromJson(response.data);
  }

  /// v91 — preview the two v87 plan-change scenarios for a target
  /// plan WITHOUT mutating anything. Returns the full math + policy
  /// classification (`upgrade` / `downgrade` / `lateral`) so the
  /// preview screen can branch identically to the web flow.
  ///
  /// `GET /api/mobile/account/plan-change/preview?plan_id=<id>`
  ///
  /// Throws an [ApiException] on `plan_id_required` /
  /// `plan_id_invalid` / `internal_error`. The caller normally
  /// handles `blocked_reason` inside the returned preview rather
  /// than as an exception (the backend returns 200 with a
  /// `blocked_reason` field for soft blocks like "no active
  /// subscription" or "same plan already active").
  Future<PlanChangePreview> previewPlanChange({required int planId}) async {
    final response = await _api.get(
      '/api/mobile/account/plan-change/preview',
      query: {'plan_id': '$planId'},
    );
    return PlanChangePreview.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }

  /// v91 — commit to a scenario from the mobile client.
  ///
  /// `POST /api/mobile/account/plan-change/confirm`
  ///
  /// Body fields:
  ///   * `plan_id` — target plan id
  ///   * `mode`    — 'same_duration' or 'reduced_days'
  ///
  /// Outcomes (all returned with 200 except blocked, which is 400
  /// — both shapes parse cleanly into [PlanChangeConfirmResult]):
  ///   * `applied`          — plan switched immediately
  ///   * `payment_required` — invoice issued; call
  ///                          [createCheckoutSession] next to open
  ///                          the Stripe-hosted page
  ///   * `blocked`          — refusal (e.g. forbidden combo)
  Future<PlanChangeConfirmResult> confirmPlanChange({
    required int planId,
    required String mode,
  }) async {
    final response = await _api.post(
      '/api/mobile/account/plan-change/confirm',
      body: {'plan_id': planId, 'mode': mode},
    );
    final raw = response.data;
    final map = raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
    // Backend returns either `{ok:true, data:{…}}` (success) or
    // `{ok:false, code:'…', message:'…', data:{…}}` (blocked).
    // Both carry the canonical fields inside `data`.
    final inner = (map['data'] is Map)
        ? (map['data'] as Map).cast<String, dynamic>()
        : map;
    return PlanChangeConfirmResult.fromJson(inner);
  }

  /// v91 — create a Stripe Checkout Session for an outstanding
  /// plan-change invoice and receive the hosted-page URL.
  ///
  /// `POST /api/mobile/account/plan-change/checkout`
  ///
  /// Throws an [ApiException] on `case_id_required` /
  /// `case_not_found` / `case_not_pending_payment` (409) /
  /// `no_pending_invoice` / `stripe_not_ready` / `stripe_error`.
  Future<PlanChangeCheckoutSession> createCheckoutSession({
    required int caseId,
  }) async {
    final response = await _api.post(
      '/api/mobile/account/plan-change/checkout',
      body: {'case_id': caseId},
    );
    return PlanChangeCheckoutSession.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(apiClientProvider));
});

final accountSnapshotProvider = FutureProvider<AccountSnapshot>((ref) {
  return ref.watch(accountRepositoryProvider).fetch();
});
