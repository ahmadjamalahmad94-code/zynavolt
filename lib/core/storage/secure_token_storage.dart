import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage for the access + refresh tokens.
///
/// Backed by [FlutterSecureStorage] (Android Keystore on real devices).
/// No plaintext fallback. If a future test environment needs an in-memory
/// double, inject it via [SecureTokenStorage.testInstance].
class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? secureStorage})
      : _storage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _inMemory = null;

  /// For unit tests only — wires the secure storage to an in-memory fake.
  factory SecureTokenStorage.testInstance(
    Map<String, String> backingStore,
  ) {
    return SecureTokenStorage._inMemory(backingStore);
  }

  SecureTokenStorage._inMemory(Map<String, String> backingStore)
      : _storage = const FlutterSecureStorage(),
        _inMemory = backingStore;

  static const String _kAccess = 'solardeye.access_token';
  static const String _kRefresh = 'solardeye.refresh_token';

  final FlutterSecureStorage _storage;
  final Map<String, String>? _inMemory;

  Future<String?> readAccessToken() async {
    if (_inMemory != null) return _inMemory[_kAccess];
    return _storage.read(key: _kAccess);
  }

  Future<String?> readRefreshToken() async {
    if (_inMemory != null) return _inMemory[_kRefresh];
    return _storage.read(key: _kRefresh);
  }

  Future<void> writeAccessToken(String value) async {
    if (_inMemory != null) {
      _inMemory[_kAccess] = value;
      return;
    }
    await _storage.write(key: _kAccess, value: value);
  }

  Future<void> writeRefreshToken(String value) async {
    if (_inMemory != null) {
      _inMemory[_kRefresh] = value;
      return;
    }
    await _storage.write(key: _kRefresh, value: value);
  }

  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await writeAccessToken(accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await writeRefreshToken(refreshToken);
    }
  }

  Future<void> clearAll() async {
    if (_inMemory != null) {
      _inMemory.remove(_kAccess);
      _inMemory.remove(_kRefresh);
      return;
    }
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
