import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'device_models.dart';

class DevicesRepository {
  DevicesRepository(this._api);

  final ApiClient _api;

  Future<List<Device>> list({int page = 1, int pageSize = 30}) async {
    final response = await _api.get(
      '/api/mobile/devices',
      query: {'page': page, 'page_size': pageSize},
    );
    final items = (response.data['items'] as List?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Device.fromJson)
        .toList();
  }

  /// v48: create a new subscriber device via
  /// `POST /api/mobile/devices`. The backend (see
  /// `_mobile_apply_device_fields` in `web/app/blueprints/mobile_api.py`)
  /// accepts only the identity fields here — provider credentials
  /// (e.g. `deye_app_id`, `deye_email`) are NOT processed by this
  /// endpoint and must be completed via the web portal afterwards.
  /// The newly created device is stamped with
  /// `connection_status='setup_required'` server-side.
  ///
  /// On success the device list is invalidated by the caller so the
  /// fresh row appears immediately.
  Future<Device> create({
    required String name,
    required String deviceType,
    String? plantName,
    String? timezone,
    double? batteryCapacityKwh,
    double? batteryReservePercent,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'device_type': deviceType,
    };
    if (plantName != null && plantName.trim().isNotEmpty) {
      body['plant_name'] = plantName.trim();
    }
    if (timezone != null && timezone.trim().isNotEmpty) {
      body['timezone'] = timezone.trim();
    }
    final safeSettings = <String, dynamic>{};
    if (batteryCapacityKwh != null) {
      safeSettings['battery_capacity_kwh'] = batteryCapacityKwh;
    }
    if (batteryReservePercent != null) {
      safeSettings['battery_reserve_percent'] = batteryReservePercent;
    }
    if (safeSettings.isNotEmpty) {
      body['safe_settings'] = safeSettings;
    }

    final response = await _api.post('/api/mobile/devices', body: body);
    // `_mobile_device_detail_payload` envelope; we surface only the
    // shared `Device` shape for the list refresh path.
    final deviceJson = (response.data['device'] as Map?)?.cast<String, dynamic>()
        ?? const <String, dynamic>{};
    return Device.fromJson(deviceJson);
  }

  /// v49: submit provider credential / setup fields for an existing
  /// device via `POST /api/mobile/devices/<id>/setup`. The backend
  /// whitelists keys against the device's provider spec
  /// (`required_fields + optional_fields`) — unknown keys are silently
  /// dropped server-side. Blank values are treated as "no change" so
  /// secret fields can be safely left empty when re-saving.
  ///
  /// Returns the updated [Device] payload so the caller can refresh.
  Future<Device> submitProviderSetup({
    required int deviceId,
    required Map<String, String> fields,
  }) async {
    final response = await _api.post(
      '/api/mobile/devices/$deviceId/setup',
      body: {'fields': fields},
    );
    final deviceJson = (response.data['device'] as Map?)?.cast<String, dynamic>()
        ?? const <String, dynamic>{};
    return Device.fromJson(deviceJson);
  }

  /// v50: trigger an immediate provider sync for a single device via
  /// `POST /api/mobile/devices/<id>/sync-now`. The backend reuses the
  /// existing `sync_now_internal` path, so:
  ///   * a successful call returns the same envelope as
  ///     `/api/mobile/devices/<id>` with the updated
  ///     `connection_status` (typically `'ok'`) and
  ///     `last_connected_at`;
  ///   * a `setup_not_ready` ApiException (HTTP 400) means readiness
  ///     gating failed — the user still has missing credentials;
  ///   * a `sync_failed` ApiException (HTTP 502) means the provider
  ///     itself rejected the attempt (bad credentials, network, etc.);
  ///   * a `device_inactive` ApiException (HTTP 400) means the device
  ///     is currently disabled and must be re-activated first.
  ///
  /// The caller surfaces the result honestly — never assumes success.
  Future<Device> submitSyncNow({required int deviceId}) async {
    final response = await _api.post(
      '/api/mobile/devices/$deviceId/sync-now',
    );
    final deviceJson = (response.data['device'] as Map?)?.cast<String, dynamic>()
        ?? const <String, dynamic>{};
    return Device.fromJson(deviceJson);
  }

  /// v51: edit a subscriber's device via `PATCH /api/mobile/devices/<id>`.
  ///
  /// Field whitelist (verified against `_mobile_apply_device_fields`
  /// in `web/app/blueprints/mobile_api.py:341`):
  ///   * ``name`` — required when non-null; backend rejects empty
  ///     with `missing_device_name` and >120 chars with
  ///     `device_name_too_long`.
  ///   * ``plant_name`` — optional, capped server-side at 120 chars;
  ///     empty string clears the field.
  ///   * ``battery_capacity_kwh`` — optional, validated to 0.1..1000.
  ///   * ``battery_reserve_percent`` — optional, validated to 0..100.
  ///
  /// **Not exposed by v51 edit**:
  ///   * ``device_type`` / ``provider_code`` — would re-resolve the
  ///     provider and invalidate stored credentials; we don't expose
  ///     provider switching from mobile.
  ///   * ``is_active`` — backend rejects with `unsupported_field` and
  ///     directs callers to the deactivate endpoint (DELETE).
  ///   * ``timezone`` — backend validates against catalog list and a
  ///     picker UI is out of v51 scope (follow-up gap).
  ///
  /// Returns the refreshed [Device] payload for list-row refresh.
  Future<Device> update({
    required int deviceId,
    String? name,
    String? plantName,
    double? batteryCapacityKwh,
    double? batteryReservePercent,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name.trim();
    if (plantName != null) body['plant_name'] = plantName.trim();
    final safeSettings = <String, dynamic>{};
    if (batteryCapacityKwh != null) {
      safeSettings['battery_capacity_kwh'] = batteryCapacityKwh;
    }
    if (batteryReservePercent != null) {
      safeSettings['battery_reserve_percent'] = batteryReservePercent;
    }
    if (safeSettings.isNotEmpty) {
      body['safe_settings'] = safeSettings;
    }

    final response = await _api.patch(
      '/api/mobile/devices/$deviceId',
      body: body,
    );
    final deviceJson =
        (response.data['device'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    return Device.fromJson(deviceJson);
  }

  /// v51: deactivate a subscriber's device via
  /// `DELETE /api/mobile/devices/<id>`.
  ///
  /// **Honest semantics** — this is NOT a hard delete. The backend
  /// (see `mobile_device_delete` in `web/app/blueprints/mobile_api.py`)
  /// flips `is_active = False`, clears the user's preferred-device
  /// pointer (replacing it with another owned device when available),
  /// and returns `{"deleted": false, "deactivated": true}`. The
  /// device row stays in the database — support can re-enable it.
  ///
  /// Mobile UI copy reflects this: the user sees "إلغاء التفعيل"
  /// language, not destructive "deletion" wording.
  Future<void> deactivate({required int deviceId}) async {
    await _api.delete('/api/mobile/devices/$deviceId');
  }
}

final devicesRepositoryProvider = Provider<DevicesRepository>((ref) {
  return DevicesRepository(ref.watch(apiClientProvider));
});

final devicesListProvider = FutureProvider<List<Device>>((ref) {
  return ref.watch(devicesRepositoryProvider).list();
});
