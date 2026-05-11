import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import '../../devices/state/selected_device_provider.dart';
import 'load_models.dart';

class LoadsRepository {
  LoadsRepository(this._api);

  final ApiClient _api;

  /// `deviceId` is forwarded to the backend as `?device_id=…` when present.
  /// If omitted, the backend returns the user's full catalog with
  /// `scope.mode = "all"`.
  Future<LoadsPage> list({int? deviceId}) async {
    final response = await _api.get(
      '/api/mobile/loads',
      query: deviceId != null ? {'device_id': deviceId} : null,
    );
    return LoadsPage.fromJson(response.data);
  }

  /// v86: `POST /api/mobile/loads/:id/toggle` with `{is_enabled: bool}`.
  ///
  /// The backend's response includes `control_type: 'persisted_preference'`
  /// and `executed_hardware_command: false` — toggling a load only updates
  /// the saved preference. It does NOT command a relay / inverter.
  ///
  /// Returns the freshly-updated UserLoad parsed from the response, so
  /// the UI can update locally without waiting for a list re-fetch.
  Future<UserLoad> toggle(int id, {required bool enabled}) async {
    final response = await _api.post(
      '/api/mobile/loads/$id/toggle',
      body: {'is_enabled': enabled},
    );
    final raw = (response.data['load'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return UserLoad.fromJson(raw);
  }

  /// v93: `POST /api/mobile/loads` — creates a new load. Required server
  /// fields: name + power. Optional: priority, device_id, is_enabled.
  /// Returns the freshly-created `UserLoad`.
  Future<UserLoad> create({
    required String name,
    required double powerW,
    int priority = 1,
    int? deviceId,
    bool isEnabled = true,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'power_w': powerW,
      'priority': priority,
      'is_enabled': isEnabled,
    };
    if (deviceId != null) body['device_id'] = deviceId;
    final response = await _api.post('/api/mobile/loads', body: body);
    final raw = (response.data['load'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return UserLoad.fromJson(raw);
  }

  /// v93: `PATCH /api/mobile/loads/:id` — updates safe fields only.
  /// Pass `null` for any field the caller doesn't want to touch.
  Future<UserLoad> update(
    int id, {
    String? name,
    double? powerW,
    int? priority,
    int? deviceId,
    bool? isEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (powerW != null) body['power_w'] = powerW;
    if (priority != null) body['priority'] = priority;
    if (deviceId != null) body['device_id'] = deviceId;
    if (isEnabled != null) body['is_enabled'] = isEnabled;
    final response = await _api.patch('/api/mobile/loads/$id', body: body);
    final raw = (response.data['load'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return UserLoad.fromJson(raw);
  }

  /// v93: `DELETE /api/mobile/loads/:id` — removes the load from the
  /// user's saved catalog. Like every other load action, this only
  /// updates the persisted preference — it does NOT power down any
  /// physical device.
  Future<void> delete(int id) async {
    await _api.delete('/api/mobile/loads/$id');
  }
}

final loadsRepositoryProvider = Provider<LoadsRepository>((ref) {
  return LoadsRepository(ref.watch(apiClientProvider));
});

/// v53: scope filter for the Loads screen.
/// `all` → backend returns the user's full catalog.
/// `activeDevice` → backend filters to the user's currently-active device
/// (resolved via [effectiveDeviceIdProvider]). When no device is active,
/// this falls back to `all` so the list never silently shows nothing.
enum LoadsScopeFilter { all, activeDevice }

final loadsScopeFilterProvider =
    StateProvider<LoadsScopeFilter>((ref) => LoadsScopeFilter.all);

/// Filter-aware list provider. Watches both the scope-filter state and
/// (when relevant) the active-device id, so changing either auto-refetches.
final loadsListProvider = FutureProvider<LoadsPage>((ref) {
  final filter = ref.watch(loadsScopeFilterProvider);
  if (filter == LoadsScopeFilter.activeDevice) {
    final id = ref.watch(effectiveDeviceIdProvider);
    if (id != null) {
      return ref.watch(loadsRepositoryProvider).list(deviceId: id);
    }
  }
  return ref.watch(loadsRepositoryProvider).list();
});
