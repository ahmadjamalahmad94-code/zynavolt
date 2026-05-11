# Zynavolt branding assets

Drop the official Zynavolt logo here:

    assets/branding/zynavolt_logo.png

The app uses this single PNG in three places:

- Splash screen (large)
- Home hero wordmark (small, rounded)
- Energy-flow hub badge on Home (small, circular)

If the file is missing, each of those falls back to a calm text "Z"
placeholder via `Image.asset(..., errorBuilder: ...)` so the build never
breaks. To swap the logo, just replace the PNG — no code change required.

## Spec

- Format: PNG (RGBA, transparent or matte navy)
- Recommended source: 1024 × 1024 (Flutter scales down crisply)
- Aspect ratio: 1:1 (square)

## Future asset slots (do not add until needed)

- `assets/branding/zynavolt_wordmark.png` (long-form wordmark)
- Android launcher icons (`android/app/src/main/res/mipmap-*/`)
  — generated from this logo; left untouched in this commit so the
  default Flutter mipmap regeneration tooling can be wired up later.
