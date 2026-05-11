# Arabic fonts for Zynavolt Mobile (v60 → v95)

**v95 status: Alexandria is wired and active.** All nine Alexandria
weight `.ttf` files ship in this folder, are declared in `pubspec.yaml`,
and the theme's `fontFamily` is set to `'Alexandria'`. Every screen
inherits this through `ThemeData`, so all Arabic copy renders in
Alexandria — no widget changes needed.

## Current wiring (v95)

- **Files**: each weight ships as its own `.ttf` under `assets/fonts/`:
  `Alexandria-Thin` (100) · `ExtraLight` (200) · `Light` (300) ·
  `Regular` (400) · `Medium` (500) · `SemiBold` (600) · `Bold` (700) ·
  `ExtraBold` (800) · `Black` (900). Flutter resolves any
  `fontWeight: FontWeight.wXXX` request straight to the matching cut.
- **pubspec.yaml** declares all nine weights under one `Alexandria`
  family — see the `flutter.fonts` block for the exact entries.
- **Theme**: `lib/app/app_theme.dart` sets `fontFamily: 'Alexandria'` on
  the base `ThemeData(useMaterial3: true, …)`. All inherited text styles
  (AppBar titles, buttons, inputs, cards, body copy) pick this up
  automatically — no screen-level override anywhere in `lib/`.

## Family rationale

**Alexandria** — modern Arabic / Latin display family. Renders cleanly
at every weight, has the visual sophistication the brand targets, and
pairs neatly with the existing indigo/violet palette.

If a future maintainer wants to swap families, drop the new TTFs, update
the `family:` and `asset:` lines in `pubspec.yaml`, and change the
`fontFamily` string in `app_theme.dart`. Nothing else is wired by name.

## Verify on device

```
flutter clean
flutter pub get
flutter run --dart-define=SOLARDEYE_API_BASE_URL=https://solardeye.onrender.com
```

Sanity check on real Android: Arabic body text should look noticeably
different from the previous Roboto fallback — Alexandria has wider
counters, a more open `ا`, and a sharper kashida. Western digits in
load values / energy units stay legible — Alexandria has matching Latin
glyphs and does not fall back mid-line.
