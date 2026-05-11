# Arabic fonts for Zynavolt Mobile (v60)

This folder is the canonical drop location for an Arabic font family.
**No font files are bundled in the repo today.** The app falls back to
the platform `Roboto` until a real font asset ships, so builds and
tests keep working in the meantime.

## Why we don't bundle a font in git

The widely-used Arabic families (Cairo, Tajawal, …) are released under
their own licenses, and copying TTFs from the system or downloading them
into a repo is the wrong place for it. This file documents the wiring
recipe so a maintainer with a properly-licensed source can drop the
files and ship a new build in one PR.

## Drop location

For each weight you want to bundle:

```
assets/fonts/Cairo/Cairo-Regular.ttf
assets/fonts/Cairo/Cairo-Bold.ttf
assets/fonts/Cairo/Cairo-Black.ttf
```

(Substitute `Tajawal` if you choose Tajawal instead — the wiring below
only needs the family name changed.)

## Wiring steps

1. **Drop the .ttf files** under `assets/fonts/<Family>/` exactly as
   listed above.
2. **Declare them in `pubspec.yaml`** under the existing `flutter:`
   block. The `assets:` line for `assets/branding/` already exists —
   add a new sibling section:

   ```yaml
   flutter:
     uses-material-design: true
     assets:
       - assets/branding/
     fonts:
       - family: Cairo
         fonts:
           - asset: assets/fonts/Cairo/Cairo-Regular.ttf
           - asset: assets/fonts/Cairo/Cairo-Bold.ttf
             weight: 700
           - asset: assets/fonts/Cairo/Cairo-Black.ttf
             weight: 900
   ```

3. **Flip the theme** in [`lib/app/app_theme.dart`](../../lib/app/app_theme.dart)
   from `fontFamily: 'Roboto'` to `fontFamily: 'Cairo'`. The whole app
   inherits through the theme — no widget changes needed.
4. **Verify on device** (Arabic numerals + body copy + chips) with:

   ```
   flutter clean
   flutter pub get
   flutter run --dart-define=SOLARDEYE_API_BASE_URL=https://solardeye.onrender.com
   ```

## Spec

| Field | Recommendation |
| --- | --- |
| Format | TTF (or OTF — change the file extension consistently in `pubspec.yaml`) |
| Weights | Regular (400), Bold (700), Black (900) is enough for the current UI |
| Hinting | Whatever the official release ships — no manual editing |
| Subset | Full Arabic — the UI mixes Arabic + Western digits / unit symbols |

## What v60 does *not* do

* Does not download a font.
* Does not check in font binaries.
* Does not change `fontFamily` away from `Roboto` yet.
* Does not break existing builds — the README is documentation only.
