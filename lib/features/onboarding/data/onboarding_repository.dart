import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'onboarding_models.dart';

/// v53 — thin client for the subscriber onboarding contract under
/// `mobile_core_api_bp`. The backend exposes three verbs on
/// `/api/mobile/onboarding`:
///
///   GET    → returns `{ onboarding, user }` where `onboarding`
///            matches `_onboarding_payload(user)`.
///   POST   → upserts onboarding fields; same response shape as GET
///            so the UI can refresh in-place. Whitelist:
///              onboarding_step, onboarding_completed,
///              selected_device_id, preferred_device_type,
///              system_basics.
///   PATCH  → identical handler to POST per the backend route
///            registration — kept here as a method for parity with
///            other repositories.
///
/// The mobile screen never sends `selected_device_id` or
/// `preferred_device_type` from onboarding — those are owned by the
/// add-device flow (`POST /api/mobile/devices`) which the user runs
/// inside the same onboarding session. We only ever PATCH the step
/// pointer + the final completion flag from here.
class OnboardingRepository {
  OnboardingRepository(this._api);

  final ApiClient _api;

  /// `GET /api/mobile/onboarding` → parsed [OnboardingState].
  Future<OnboardingState> fetch() async {
    final response = await _api.get('/api/mobile/onboarding');
    final payload = (response.data['onboarding'] as Map?)
            ?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return OnboardingState.fromJson(payload);
  }

  /// Advances the backend step pointer. The backend accepts any value
  /// in its whitelist (welcome/profile/device/notifications/finish/
  /// done/explore_services) — mobile uses welcome → device → finish →
  /// done so the web admin view shows a recognisable trail.
  Future<OnboardingState> setStep(String step) async {
    final response = await _api.post(
      '/api/mobile/onboarding',
      body: {'onboarding_step': step},
    );
    final payload = (response.data['onboarding'] as Map?)
            ?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return OnboardingState.fromJson(payload);
  }

  /// Marks the user as fully onboarded. The backend auto-sets the
  /// step to `done` when no step is sent alongside `completed=true`.
  Future<OnboardingState> markComplete() async {
    final response = await _api.post(
      '/api/mobile/onboarding',
      body: {'onboarding_completed': true},
    );
    final payload = (response.data['onboarding'] as Map?)
            ?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return OnboardingState.fromJson(payload);
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(apiClientProvider));
});

/// Onboarding snapshot for the current signed-in user. Invalidated
/// after each substep (add-device, setup, sync) so the screen
/// re-derives the next visible stage from fresh backend state.
final onboardingStateProvider = FutureProvider<OnboardingState>((ref) {
  return ref.watch(onboardingRepositoryProvider).fetch();
});
