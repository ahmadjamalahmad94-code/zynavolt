import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

/// v100-fonts (TEMPORARY) — App-wide Arabic font preference.
///
/// Mirrors the [TimeFormatPref] pattern: a tiny enum + a static
/// `current` field that the theme reads, with a Riverpod provider
/// that hydrates from secure storage on boot and persists changes.
///
/// **REMOVE THIS FILE + the Settings card + the `google_fonts`
/// dependency once the owner has picked a permanent font.**
///
/// Why an enum instead of a free-form string: a closed set lets
/// the Settings UI render a sample-text radio list deterministically
/// and prevents typos that would silently fall back to the system
/// font.

enum AppFontPref {
  /// Bundled `assets/fonts/Alexandria-*.ttf`, declared in
  /// pubspec.yaml. The current default — calm, modern, Latin-based
  /// design that handles Arabic well.
  alexandria(
    storageKey: 'alexandria',
    arabicLabel: 'الإسكندرية (الافتراضي)',
    sampleText: 'مرحبًا بعودتك — منصّة إدارة الطاقة الشمسية',
  ),

  /// Cairo — extremely popular Arabic geometric sans, Google's
  /// answer to the "modern Arabic UI" niche. Used by many
  /// regional fintech apps.
  cairo(
    storageKey: 'cairo',
    arabicLabel: 'القاهرة (Cairo)',
    sampleText: 'مرحبًا بعودتك — منصّة إدارة الطاقة الشمسية',
  ),

  /// Tajawal — clean, contemporary, slightly humanist. Often
  /// used for marketing surfaces.
  tajawal(
    storageKey: 'tajawal',
    arabicLabel: 'تجوال (Tajawal)',
    sampleText: 'مرحبًا بعودتك — منصّة إدارة الطاقة الشمسية',
  ),

  /// Almarai — soft, friendly, more rounded than Cairo. Reads
  /// well at small sizes.
  almarai(
    storageKey: 'almarai',
    arabicLabel: 'المرعي (Almarai)',
    sampleText: 'مرحبًا بعودتك — منصّة إدارة الطاقة الشمسية',
  ),

  /// IBM Plex Sans Arabic — corporate-grade, even spacing,
  /// designed for technical interfaces.
  ibmPlex(
    storageKey: 'ibm_plex_sans_arabic',
    arabicLabel: 'IBM Plex Sans Arabic',
    sampleText: 'مرحبًا بعودتك — منصّة إدارة الطاقة الشمسية',
  ),

  /// Readex Pro — modern, friendly, large x-height. Great for
  /// data-dense screens.
  readexPro(
    storageKey: 'readex_pro',
    arabicLabel: 'Readex Pro',
    sampleText: 'مرحبًا بعودتك — منصّة إدارة الطاقة الشمسية',
  ),

  /// Noto Sans Arabic — Google's universal Arabic. Conservative
  /// but reliable.
  notoArabic(
    storageKey: 'noto_sans_arabic',
    arabicLabel: 'Noto Sans Arabic',
    sampleText: 'مرحبًا بعودتك — منصّة إدارة الطاقة الشمسية',
  ),

  /// El Messiri — distinctive humanist Arabic with personality.
  /// More expressive than the others; good for a brand statement.
  elMessiri(
    storageKey: 'el_messiri',
    arabicLabel: 'المسيري (El Messiri)',
    sampleText: 'مرحبًا بعودتك — منصّة إدارة الطاقة الشمسية',
  );

  const AppFontPref({
    required this.storageKey,
    required this.arabicLabel,
    required this.sampleText,
  });

  /// String written to secure storage. Never use the enum's
  /// `name` directly so renaming the enum constant doesn't break
  /// hydrated user choices.
  final String storageKey;

  /// Label rendered in the Settings UI.
  final String arabicLabel;

  /// Sample text shown beneath the label so the user can see
  /// how the font looks before selecting.
  final String sampleText;

  /// Currently-active preference. The theme reads this each
  /// `build`, so changing it (via [set]) + rebuilding the
  /// MaterialApp swaps the font app-wide.
  static AppFontPref _current = AppFontPref.alexandria;
  static AppFontPref get current => _current;
  static void set(AppFontPref next) {
    _current = next;
  }

  /// Resolve the enum to a concrete `TextStyle` whose `fontFamily`
  /// matches the bundled / Google-fetched font. Returns the bundled
  /// Alexandria for the default; everything else routes through
  /// `google_fonts` (which downloads on first use, then caches).
  TextStyle toTextStyle({TextStyle? base}) {
    final initial = base ?? const TextStyle();
    if (this == AppFontPref.alexandria) {
      return initial.copyWith(fontFamily: 'Alexandria');
    }
    final getter = _googleFontsGetter[this];
    if (getter == null) {
      return initial.copyWith(fontFamily: 'Alexandria');
    }
    return getter(initial);
  }

  /// Apply the font to a whole `TextTheme` in one call. Used by
  /// `AppTheme.light()` so every text style in Material's typography
  /// scale picks up the new font at once.
  TextTheme applyToTextTheme(TextTheme base) {
    if (this == AppFontPref.alexandria) {
      return base.apply(fontFamily: 'Alexandria');
    }
    final getter = _googleTextThemeGetter[this];
    if (getter == null) {
      return base.apply(fontFamily: 'Alexandria');
    }
    return getter(base);
  }

  /// Map enum → google_fonts single-style helper. The
  /// `GoogleFonts.<name>(...)` callables take a NAMED `textStyle`
  /// parameter, not a positional one — so we wrap each in a lambda
  /// that adapts to the `TextStyle Function(TextStyle)` shape we
  /// actually want.
  static final Map<AppFontPref, TextStyle Function(TextStyle)>
      _googleFontsGetter = {
    AppFontPref.cairo: (s) => GoogleFonts.cairo(textStyle: s),
    AppFontPref.tajawal: (s) => GoogleFonts.tajawal(textStyle: s),
    AppFontPref.almarai: (s) => GoogleFonts.almarai(textStyle: s),
    AppFontPref.ibmPlex: (s) => GoogleFonts.ibmPlexSansArabic(textStyle: s),
    AppFontPref.readexPro: (s) => GoogleFonts.readexPro(textStyle: s),
    AppFontPref.notoArabic: (s) => GoogleFonts.notoSansArabic(textStyle: s),
    AppFontPref.elMessiri: (s) => GoogleFonts.elMessiri(textStyle: s),
  };

  /// Map enum → google_fonts text-theme helper. IBM Plex Sans
  /// Arabic doesn't ship a `*TextTheme` getter in google_fonts
  /// 6.x, so we synthesise one by `.apply(...)`-ing the requested
  /// font family onto the base text theme.
  static final Map<AppFontPref, TextTheme Function(TextTheme)>
      _googleTextThemeGetter = {
    AppFontPref.cairo: GoogleFonts.cairoTextTheme,
    AppFontPref.tajawal: GoogleFonts.tajawalTextTheme,
    AppFontPref.almarai: GoogleFonts.almaraiTextTheme,
    AppFontPref.ibmPlex: (base) => GoogleFonts.ibmPlexSansArabicTextTheme(base),
    AppFontPref.readexPro: GoogleFonts.readexProTextTheme,
    AppFontPref.notoArabic: GoogleFonts.notoSansArabicTextTheme,
    AppFontPref.elMessiri: GoogleFonts.elMessiriTextTheme,
  };

  static AppFontPref fromStorageKey(String? key) {
    if (key == null || key.isEmpty) return AppFontPref.alexandria;
    for (final v in AppFontPref.values) {
      if (v.storageKey == key) return v;
    }
    return AppFontPref.alexandria;
  }
}

/// Riverpod controller — same shape as `TimeFormatPrefController`.
class AppFontPrefController extends StateNotifier<AppFontPref> {
  AppFontPrefController(this._storage) : super(AppFontPref.current) {
    _hydrate();
  }

  final FlutterSecureStorage _storage;

  static const _key = 'solardeye.app_font_pref';

  Future<void> _hydrate() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return;
      final parsed = AppFontPref.fromStorageKey(raw);
      AppFontPref.set(parsed);
      if (mounted) state = parsed;
    } catch (_) {
      // Swallow — falling back to in-memory default is fine.
    }
  }

  Future<void> setPref(AppFontPref next) async {
    if (next == state) return;
    AppFontPref.set(next);
    state = next;
    try {
      await _storage.write(key: _key, value: next.storageKey);
    } catch (_) {
      // Persistence failures are non-fatal — the in-memory flag
      // is already correct for this session.
    }
  }
}

final appFontPrefProvider =
    StateNotifierProvider<AppFontPrefController, AppFontPref>((ref) {
  return AppFontPrefController(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  );
});
