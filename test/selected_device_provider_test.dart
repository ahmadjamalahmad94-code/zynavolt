import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/core/state/app_session.dart';
import 'package:solardeye_mobile/core/storage/secure_token_storage.dart';
import 'package:solardeye_mobile/features/devices/state/selected_device_provider.dart';

ProviderContainer _container(Map<String, String> backingStore) {
  final storage = SecureTokenStorage.testInstance(backingStore);
  return ProviderContainer(
    overrides: [
      secureTokenStorageProvider.overrideWithValue(storage),
    ],
  );
}

void main() {
  group('SelectedDeviceController', () {
    test('initializes from storage when an id is persisted', () async {
      final store = <String, String>{
        'solardeye.selected_device_id': '42',
      };
      final container = _container(store);
      addTearDown(container.dispose);

      final value = await container.read(selectedDeviceProvider.future);
      expect(value, 42);
    });

    test('initializes to null when storage is empty', () async {
      final container = _container({});
      addTearDown(container.dispose);

      final value = await container.read(selectedDeviceProvider.future);
      expect(value, isNull);
    });

    test('select(id) persists to storage and updates state', () async {
      final store = <String, String>{};
      final container = _container(store);
      addTearDown(container.dispose);

      // Drive the AsyncNotifier through its initial build first.
      await container.read(selectedDeviceProvider.future);

      await container.read(selectedDeviceProvider.notifier).select(7);

      expect(container.read(selectedDeviceProvider).valueOrNull, 7);
      expect(store['solardeye.selected_device_id'], '7');
    });

    test('clear() removes the persisted id and emits null', () async {
      final store = <String, String>{
        'solardeye.selected_device_id': '99',
      };
      final container = _container(store);
      addTearDown(container.dispose);

      await container.read(selectedDeviceProvider.future);
      await container.read(selectedDeviceProvider.notifier).clear();

      expect(container.read(selectedDeviceProvider).valueOrNull, isNull);
      expect(store.containsKey('solardeye.selected_device_id'), isFalse);
    });
  });

  group('SecureTokenStorage selected device id', () {
    test('clearAll() also removes the persisted device id', () async {
      final store = <String, String>{
        'solardeye.access_token': 'a',
        'solardeye.refresh_token': 'r',
        'solardeye.selected_device_id': '12',
      };
      final storage = SecureTokenStorage.testInstance(store);

      await storage.clearAll();

      expect(store, isEmpty);
      expect(await storage.readSelectedDeviceId(), isNull);
    });

    test('readSelectedDeviceId returns null for non-numeric values',
        () async {
      final store = <String, String>{
        'solardeye.selected_device_id': 'not-a-number',
      };
      final storage = SecureTokenStorage.testInstance(store);

      expect(await storage.readSelectedDeviceId(), isNull);
    });
  });
}
