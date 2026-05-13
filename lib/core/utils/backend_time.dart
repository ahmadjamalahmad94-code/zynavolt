/// Shared UTC-aware ISO parser + formatters for backend timestamps.
///
/// Background — the 3-hour problem
/// --------------------------------
/// The Flask backend persists timestamps as naive UTC (`datetime.utcnow()`)
/// and serialises them with `.isoformat()`, which produces strings such
/// as `2026-05-11T10:00:00.123456` — no `Z`, no `±HH:MM` offset. Dart's
/// [DateTime.tryParse] reads any string without a timezone designator
/// as **device-local**, so every "last reading" / "آخر اتصال" /
/// "آخر تحديث" field in the app was being shown as UTC wall-time
/// dressed up as local — three hours behind for users in `Asia/Hebron`
/// during summer.
///
/// The honest fix in a no-package environment
/// ------------------------------------------
/// 1. Detect the missing timezone suffix and reinterpret the string as
///    UTC before further work.
/// 2. Convert to the **device** timezone via `.toLocal()` — correct for
///    every user whose device clock matches their physical location
///    (the overwhelming majority).
///
/// What this helper does NOT attempt
/// ---------------------------------
/// * It does **not** convert by IANA name (e.g. `Asia/Hebron`).
///   Dart's standard library cannot do that without the `timezone`
///   package, which the repo deliberately does not depend on.
/// * It does **not** hand-code regional offsets — there is no
///   `Asia/Hebron == UTC+2` fake conversion table in this codebase.
/// * Users whose profile timezone differs from their device timezone
///   will still see device-local time. That mismatch is surfaced to
///   the user in the Notifications detail sheet (a `نطاق الملف الشخصي`
///   row) and in the help-sheet's timezone note. A future change
///   either adopts the `timezone` package or gets a backend
///   `display_time_local` field — that work is out of scope here.
///
/// Every screen that renders a backend timestamp must go through one
/// of the helpers in this file (directly or via the thin wrappers in
/// [lib/core/utils/timestamp.dart]).
library;

/// Parse a backend ISO-8601 timestamp into a `DateTime` whose `.toLocal()`
/// produces correct wall-clock time on the user's device.
///
/// Behaviour:
///   * `null` or empty input → `null`.
///   * Strings carrying `Z` or `±HH:MM` (or `±HHMM`) — parsed honestly,
///     timezone preserved.
///   * Strings without a timezone designator — treated as **UTC** (the
///     backend writes naive UTC). `Z` is appended before parsing.
///   * Malformed strings → `null` (callers decide whether to fall back
///     to the raw input or to a placeholder).
DateTime? parseBackendIso(String? iso) {
  if (iso == null) return null;
  final trimmed = iso.trim();
  if (trimmed.isEmpty) return null;

  final hasTz = trimmed.endsWith('Z') ||
      // ±HH:MM or ±HHMM appearing at the very end of the string
      RegExp(r'[+\-]\d{2}:?\d{2}$').hasMatch(trimmed);
  final normalised = hasTz ? trimmed : '${trimmed}Z';
  return DateTime.tryParse(normalised);
}

/// v99c — Convert a 24-hour `hour` into 12-hour wall-clock + an
/// Arabic period marker (`ص` morning / `م` afternoon-evening).
///   * 00 → 12 ص   (midnight)
///   * 01–11 → 1..11 ص
///   * 12 → 12 م   (noon)
///   * 13–23 → 1..11 م
({int hour12, String marker}) _to12h(int hour24) {
  final marker = hour24 < 12 ? 'ص' : 'م';
  var h = hour24 % 12;
  if (h == 0) h = 12;
  return (hour12: h, marker: marker);
}

/// `YYYY-MM-DD  h:mm ص/م` (12-hour clock with Arabic period) in
/// device-local time. Returns `null` for null/empty input, and the
/// raw input string when parsing fails — that preserves the old
/// `formatDateTime` contract used by device / support / account
/// screens.
String? formatBackendDateTime(String? iso) {
  final parsed = parseBackendIso(iso);
  if (parsed == null) {
    return _passThrough(iso);
  }
  final local = parsed.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final t = _to12h(local.hour);
  final hh = t.hour12.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d  $hh:$mm ${t.marker}';
}

/// `YYYY-MM-DD` in device-local time. Used for fields where the
/// wall-clock time of day is not meaningful (subscription expiry,
/// trial-end date, etc.).
String? formatBackendDate(String? iso) {
  final parsed = parseBackendIso(iso);
  if (parsed == null) {
    return _passThrough(iso);
  }
  final local = parsed.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Compact `h:mm ص/م` (12-hour clock with Arabic period) in
/// device-local time. Used by the Home hero's "آخر قراءة" pill.
String? formatBackendHm(String? iso) {
  final parsed = parseBackendIso(iso);
  if (parsed == null) {
    return _passThrough(iso);
  }
  final local = parsed.toLocal();
  final t = _to12h(local.hour);
  final hh = t.hour12.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm ${t.marker}';
}

/// Full `YYYY-MM-DD  h:mm:ss ص/م` in device-local time. Used by
/// the Notifications detail sheet's "وقت الإنشاء" / "وقت القراءة"
/// rows.
String? formatBackendExact(String? iso) {
  final parsed = parseBackendIso(iso);
  if (parsed == null) {
    return _passThrough(iso);
  }
  final local = parsed.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final t = _to12h(local.hour);
  final hh = t.hour12.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final ss = local.second.toString().padLeft(2, '0');
  return '$y-$mo-$d  $hh:$mm:$ss ${t.marker}';
}

/// Arabic-friendly "humanised" relative timestamp:
///   * Today               → `h:mm ص/م`
///   * Yesterday           → `أمس h:mm ص/م`
///   * Older (same year)   → `MM-DD  h:mm ص/م`
///   * Older (other year)  → `YYYY-MM-DD  h:mm ص/م`
///
/// `now` defaults to [DateTime.now] but can be injected for tests.
/// Returns `—` for null/empty input, and the raw input (truncated at
/// the first dot) when parsing fails — the same fallback behaviour the
/// Notifications screen has always used.
String formatBackendRelative(String? iso, {DateTime? now}) {
  final parsed = parseBackendIso(iso);
  if (parsed == null) {
    if (iso == null) return '—';
    final t = iso.trim();
    if (t.isEmpty) return '—';
    final dot = t.indexOf('.');
    return dot > 0 ? t.substring(0, dot) : t;
  }
  final local = parsed.toLocal();
  final nowVal = now ?? DateTime.now();
  final today = DateTime(nowVal.year, nowVal.month, nowVal.day);
  final dayOf = DateTime(local.year, local.month, local.day);
  final daysAgo = today.difference(dayOf).inDays;
  final t12 = _to12h(local.hour);
  final hh = t12.hour12.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final timeText = '$hh:$mm ${t12.marker}';
  if (daysAgo == 0) return timeText;
  if (daysAgo == 1) return 'أمس $timeText';
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  if (local.year == nowVal.year) return '$mo-$d  $timeText';
  return '${local.year}-$mo-$d  $timeText';
}

/// Used when `parseBackendIso` returns null — return the original raw
/// input (or `null` for null/empty) so existing callers that relied on
/// the old `DateTime.tryParse(raw) == null → raw` fallback in
/// `formatDateTime` keep working.
String? _passThrough(String? iso) {
  if (iso == null) return null;
  final trimmed = iso.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}
