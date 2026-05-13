// v53: mirrors `_onboarding_payload(user)` from
// `web/app/blueprints/mobile_api.py`. The backend payload shape is:
//
//   {
//     "completed":               bool,
//     "step":                    str  (welcome|profile|device|notifications
//                                       |finish|done|explore_services),
//     "needs_profile_location":  bool,
//     "needs_device_link":       bool,
//     "system_basics":           { selected_device_id, preferred_device_type,
//                                   battery_capacity_kwh,
//                                   battery_reserve_percent },
//     "device_state":            { selected_device_id,
//                                   current_device: {...} | null,
//                                   devices: {total, active, ...} }
//   }
//
// The mobile model carries only the fields the onboarding screen
// actually reads — the rest is intentionally dropped so the model
// stays a small, testable parser. The backend keeps emitting them
// for other surfaces (account screen, system basics card, etc.)
// which have their own model files.

class OnboardingState {
  OnboardingState({
    required this.completed,
    required this.step,
    required this.needsProfileLocation,
    required this.needsDeviceLink,
    required this.selectedDeviceId,
    required this.currentDeviceName,
    required this.currentConnectionStatus,
    required this.currentIsActive,
    required this.totalDevices,
  });

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    final deviceState =
        (json['device_state'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final current =
        (deviceState['current_device'] as Map?)?.cast<String, dynamic>();
    final devices =
        (deviceState['devices'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    // Backend defaults `step` to "welcome" when not set, but a missing
    // key still lands here — fall back to "welcome" so the UI's switch
    // statement always matches a known stage.
    final rawStep = (json['step'] ?? '').toString().trim().toLowerCase();

    return OnboardingState(
      completed: json['completed'] == true,
      step: rawStep.isEmpty ? 'welcome' : rawStep,
      needsProfileLocation: json['needs_profile_location'] == true,
      needsDeviceLink: json['needs_device_link'] == true,
      selectedDeviceId: _asNullableInt(deviceState['selected_device_id']) ??
          _asNullableInt(current?['id']),
      currentDeviceName: (current?['name'] ?? '').toString(),
      currentConnectionStatus:
          (current?['connection_status'] ?? '').toString().trim().toLowerCase(),
      currentIsActive: current?['is_active'] == true,
      totalDevices: _asInt(devices['total']),
    );
  }

  /// Synthetic "fresh signup" default used when the backend is
  /// unreachable at cold start — keeps the onboarding screen from
  /// crashing and shows the welcome stage instead of a blank page.
  factory OnboardingState.unknown() => OnboardingState(
        completed: false,
        step: 'welcome',
        needsProfileLocation: true,
        needsDeviceLink: true,
        selectedDeviceId: null,
        currentDeviceName: '',
        currentConnectionStatus: '',
        currentIsActive: false,
        totalDevices: 0,
      );

  final bool completed;

  /// One of `welcome`, `profile`, `device`, `notifications`, `finish`,
  /// `done`, `explore_services`. The mobile screen does not branch on
  /// this directly — it derives the next visible stage from the
  /// boolean flags below — but the value is forwarded back on PATCH
  /// so the backend keeps its own step pointer current.
  final String step;

  /// True when the user is missing country/city/timezone. The screen
  /// surfaces a banner pointing at the existing `/profile` editor;
  /// mobile does not fork a separate profile-completion form.
  final bool needsProfileLocation;

  /// True when the user has zero devices attached. The screen shows
  /// the "add your first device" CTA in this case.
  final bool needsDeviceLink;

  /// Currently-selected (preferred) device id, when present.
  final int? selectedDeviceId;

  /// Display name of the currently-selected device, used for the
  /// honest copy in the setup/sync cards.
  final String currentDeviceName;

  /// Connection status of the currently-selected device. Used to
  /// decide whether to surface the "complete setup" vs. "sync now"
  /// CTA. Empty string when there is no current device.
  final String currentConnectionStatus;

  /// Whether the currently-selected device is active.
  final bool currentIsActive;

  /// Convenience: total devices the user owns (active + inactive).
  final int totalDevices;

  // ── Derived view-state helpers ─────────────────────────────────────

  /// True when the currently-selected device still needs provider
  /// credentials. Matches the device-detail screen's own gate.
  bool get needsProviderSetup =>
      selectedDeviceId != null &&
      currentConnectionStatus == 'setup_required';

  /// True when the device is set up but has not connected successfully
  /// at least once. The UI then offers a "try first sync now" CTA.
  bool get needsFirstSync =>
      selectedDeviceId != null &&
      currentConnectionStatus.isNotEmpty &&
      currentConnectionStatus != 'setup_required' &&
      currentConnectionStatus != 'ok';
}

int _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
  return 0;
}

int? _asNullableInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }
  return null;
}
