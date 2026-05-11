import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/api_providers.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../data/device_models.dart';
import '../data/devices_repository.dart';

/// Stored selected-device id, persisted via [SecureTokenStorage]. The raw
/// value lives here; consumers that want the resolved-with-fallback id
/// should watch [effectiveDeviceIdProvider] instead.
class SelectedDeviceController extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async {
    final storage = ref.read(secureTokenStorageProvider);
    return storage.readSelectedDeviceId();
  }

  Future<void> select(int id) async {
    final storage = ref.read(secureTokenStorageProvider);
    await storage.writeSelectedDeviceId(id);
    state = AsyncData(id);
  }

  Future<void> clear() async {
    final storage = ref.read(secureTokenStorageProvider);
    await storage.clearSelectedDeviceId();
    state = const AsyncData(null);
  }
}

final selectedDeviceProvider =
    AsyncNotifierProvider<SelectedDeviceController, int?>(
  SelectedDeviceController.new,
);

/// Effective active device id, resolved by the fallback chain:
///
///   1. stored selection, if it still appears in the devices list;
///   2. else `bootstrap.activeDeviceId`, if it appears in the devices list;
///   3. else the first device in the list;
///   4. else `null`.
///
/// Returns `null` while the devices list is still loading and no other
/// signal is available yet — screens render their loading/empty state.
final effectiveDeviceIdProvider = Provider<int?>((ref) {
  final stored = ref.watch(selectedDeviceProvider).valueOrNull;
  final devices =
      ref.watch(devicesListProvider).valueOrNull ?? const <Device>[];
  final bootstrap = ref.watch(bootstrapProvider).valueOrNull;

  bool exists(int id) => devices.any((d) => d.id == id);

  if (stored != null && exists(stored)) {
    return stored;
  }
  final fromBootstrap = bootstrap?.activeDeviceId;
  if (fromBootstrap != null && exists(fromBootstrap)) {
    return fromBootstrap;
  }
  if (devices.isNotEmpty) {
    return devices.first.id;
  }
  return null;
});

/// Convenience: the [Device] object that backs [effectiveDeviceIdProvider].
/// Returns `null` if the devices list has not loaded yet or the resolved
/// id is no longer in the list.
final effectiveDeviceProvider = Provider<Device?>((ref) {
  final id = ref.watch(effectiveDeviceIdProvider);
  if (id == null) return null;
  final devices =
      ref.watch(devicesListProvider).valueOrNull ?? const <Device>[];
  for (final d in devices) {
    if (d.id == id) return d;
  }
  return null;
});
