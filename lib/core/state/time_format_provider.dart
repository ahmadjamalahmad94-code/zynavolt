import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/backend_time.dart';

/// v99d — App-wide time-format preference (12-hour ص/م vs 24-hour).
///
/// Why a separate provider — the formatter helpers in `backend_time.dart`
/// are pure top-level functions (no Riverpod context), so they consult
/// a static field `TimeFormatPref.current`. This provider is what KEEPS
/// that static field in sync with the user's persisted choice:
///
///   * On boot, [TimeFormatPrefController] reads the saved value from
///     [FlutterSecureStorage] (the same storage layer we already use
///     for tokens), parses it, and writes it into `TimeFormatPref.current`.
///   * Whenever the settings screen calls [setPref], we update the
///     static field FIRST (so the next formatter call uses it), then
///     persist asynchronously.
///
/// Surface used by the UI:
///   * `ref.watch(timeFormatPrefProvider)` → current enum value
///   * `ref.read(timeFormatPrefProvider.notifier).setPref(...)` → write
class TimeFormatPrefController extends StateNotifier<TimeFormatPref> {
  TimeFormatPrefController(this._storage) : super(TimeFormatPref.current) {
    _hydrate();
  }

  final FlutterSecureStorage _storage;

  static const _key = 'solardeye.time_format_pref';

  Future<void> _hydrate() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return;
      final parsed = raw == 'h24' ? TimeFormatPref.h24 : TimeFormatPref.h12;
      TimeFormatPref.set(parsed);
      if (mounted) state = parsed;
    } catch (_) {
      // Swallow — falling back to the in-memory default is fine.
    }
  }

  Future<void> setPref(TimeFormatPref next) async {
    if (next == state) return;
    TimeFormatPref.set(next);
    state = next;
    try {
      await _storage.write(key: _key, value: next == TimeFormatPref.h24 ? 'h24' : 'h12');
    } catch (_) {
      // Persistence failures are non-fatal — the in-memory flag is
      // already correct for this session.
    }
  }
}

final timeFormatPrefProvider =
    StateNotifierProvider<TimeFormatPrefController, TimeFormatPref>((ref) {
  return TimeFormatPrefController(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  );
});
