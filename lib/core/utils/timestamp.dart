/// Shared timestamp formatters (v79).
///
/// Replaces 3 near-identical local copies that lived in
/// `device_detail_screen.dart`, `support_case_detail_screen.dart`, and
/// `account_screen.dart`. No behavior change — just one source of truth.
///
/// Both functions accept a nullable ISO-8601 string and return:
///   * `null` when input is null or empty;
///   * the raw input when `DateTime.tryParse` fails (so the user still
///     sees what the server sent);
///   * a formatted local-time string otherwise.
library;

/// `YYYY-MM-DD  HH:mm` — date + 24-hour clock, local time.
String? formatDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d  $hh:$mm';
}

/// `YYYY-MM-DD` — date only, local time. Used by the Account screen for
/// subscription expiry / trial-end dates where the wall-clock time of
/// day is not meaningful.
String? formatDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
