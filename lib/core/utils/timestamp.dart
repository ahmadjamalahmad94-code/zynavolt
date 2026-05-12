/// Shared timestamp formatters (v79 → v97).
///
/// **v97**: these two functions are now thin wrappers around
/// [formatBackendDateTime] and [formatBackendDate] in
/// `lib/core/utils/backend_time.dart`. The actual UTC-aware parsing
/// logic lives there so every screen — Home, Notifications, Device
/// Detail, Support, Account — shares one source of truth and the
/// "naive ISO without `Z` was being treated as device-local" bug
/// stays fixed across the whole app.
///
/// Both functions still accept a nullable ISO-8601 string and return:
///   * `null` when input is null or empty;
///   * the raw input when parsing fails (so the user still sees what
///     the server sent);
///   * a formatted local-time string otherwise.
///
/// Existing call sites in
/// `lib/features/devices/presentation/device_detail_screen.dart`,
/// `lib/features/support/presentation/support_case_detail_screen.dart`,
/// and `lib/features/account/presentation/account_screen.dart` remain
/// unchanged — same function names, same return shape, just the
/// correct UTC-aware behaviour underneath.
library;

import 'backend_time.dart';

/// `YYYY-MM-DD  HH:mm` — date + 24-hour clock, device-local time, with
/// the v97 UTC-aware parser underneath. See [formatBackendDateTime].
String? formatDateTime(String? raw) => formatBackendDateTime(raw);

/// `YYYY-MM-DD` — date only, device-local time, with the v97
/// UTC-aware parser underneath. See [formatBackendDate].
String? formatDate(String? raw) => formatBackendDate(raw);
