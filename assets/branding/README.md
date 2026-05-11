# Zynavolt branding assets

Drop the official Zynavolt logo here:

    assets/branding/zynavolt_logo.png

The app uses this single PNG in these places (as of v59):

- Splash screen (large rounded square)
- Login screen header (rounded square)
- Home hero wordmark (small, rounded)
- Energy-flow hub badge on Home (small, circular)
- App Settings → brand card (small, rounded)

If the file is missing, each of those falls back to a calm sun-icon
placeholder via `Image.asset(..., errorBuilder: ...)` so the build never
breaks. To swap the logo, just replace the PNG — no code change required.

## Spec

- Format: PNG (RGBA, transparent or matte navy)
- Recommended source: 1024 × 1024 (Flutter scales down crisply)
- Aspect ratio: 1:1 (square)
- File name (exact, case-sensitive): `zynavolt_logo.png`

## Verification after dropping the file

1. `flutter clean && flutter pub get`
2. `flutter run --dart-define=SOLARDEYE_API_BASE_URL=https://solardeye.onrender.com`
3. Confirm the logo appears on:
   - Splash (cold start)
   - Login (signed-out cold start)
   - Home hero card (header)
   - Home energy-flow hub (centre badge)
   - More → إعدادات التطبيق → top brand card

## Future asset slots (do not add until needed)

- `assets/branding/zynavolt_wordmark.png` (long-form wordmark)
- Android launcher icons (`android/app/src/main/res/mipmap-*/`)
  — generated from this logo; left untouched in this commit so the
  default Flutter mipmap regeneration tooling can be wired up later.

## Arabic font slot (v46)

The app currently renders Arabic text in `Roboto` (the Flutter default).
A nicer Arabic-first family like **Cairo** or **Tajawal** can be wired in
without any code change beyond `app/app_theme.dart`:

1. Drop the `.ttf` weight files under:

       assets/branding/fonts/Cairo/Cairo-Regular.ttf
       assets/branding/fonts/Cairo/Cairo-Bold.ttf
       assets/branding/fonts/Cairo/Cairo-Black.ttf

2. Register them in `pubspec.yaml`:

       fonts:
         - family: Cairo
           fonts:
             - asset: assets/branding/fonts/Cairo/Cairo-Regular.ttf
             - asset: assets/branding/fonts/Cairo/Cairo-Bold.ttf
               weight: 700
             - asset: assets/branding/fonts/Cairo/Cairo-Black.ttf
               weight: 900

3. Change the `fontFamily: 'Roboto'` line in `lib/app/app_theme.dart`
   to `fontFamily: 'Cairo'`. All text inherits through the theme, so no
   widget-level changes are needed.

Until the font asset ships, the theme stays on the system fallback so
builds never break.
