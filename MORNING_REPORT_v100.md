# v100 — Overnight Build Report

**Date:** 2026-05-14
**Branches:** `main` (web + mobile)
**Status:** Mobile commits local · Web commits pushed to `main`

> **See also:** [PROJECT_RULES.md](PROJECT_RULES.md) — the canonical
> tagged rules index (design / removal / addition / workflow /
> branding). Everything that recurs across reports lives there now.

---

## TL;DR (read this first)

1. ✅ **Battery Lab is now native** — opens inside the app, fetches from
   a new mobile endpoint, renders SoC hero + capacity tiles + AC-IN
   diagnostic + battery details + 48 h SoC chart.
2. ✅ **Design system v100** shipped — tokens + 9 base components live
   in `lib/core/design/`. Documented in-file.
3. ✅ **First-impression screens redesigned from scratch** — Splash,
   Login, Register all rebuilt on the v100 system with a dark navy
   brand hero + glossy form card.
4. ✅ **Devices list rebuilt** — glossy gradient tiles with filled
   gradient icon glyphs, accent borders, layered shadows.
5. ✅ **Visual-continuity pass** across ~12 remaining screens — every
   page now shares the same pale-indigo gradient backdrop instead of
   the old flat `softBg` colour, so the app reads as one continuous
   surface from Splash → Home → any tab.
6. ✅ **`flutter analyze` is clean** — 0 errors. 6 pre-existing
   informational warnings remain (unrelated to this redesign).

You said "بناء من الصفر مش ترقيع". Splash / Login / Register / Devices
list / Battery Lab / More are rebuilt from scratch. The remaining
screens got a coat of paint (gradient backdrop + transparent AppBar)
but their internal layouts are unchanged — those are the candidates
for a full rebuild in the next pass. See **"What's left"** below.

---

## 1. Battery Lab — full native flow

### Backend (`web`, pushed to main)

**Commit `c56008f`** — v100 endpoint:

`GET /api/mobile/battery-lab`
- Auth: bearer token (same `_require_bearer_user` as `/dashboard`)
- Scope: honours `?device_id=N`
- Response:
  ```
  scope:  { mode, device_id, device_name }
  latest: { ...reading basics... }
  battery_insights: { ...v93l..v93s full dict... }
  battery_details:  { ...build_battery_details... }
  hourly: [{time_label, time_iso, soc, power_w, voltage, current} × 48]
  generated_at: <iso utc>
  ```
- Tests: `tests/test_v100_battery_lab_mobile.py` (endpoint registered
  in the mobile allowed-methods registry; required helpers imported)

### Mobile (`mobile`, local commits)

**Commit `81eacf7`** — native screen + data layer:

- `lib/features/battery_lab/`
  - `data/battery_lab_models.dart` — full v93l..s field coverage
  - `data/battery_lab_repository.dart` — Riverpod async provider that
    auto-refetches on `effectiveDeviceIdProvider` change
  - `presentation/battery_lab_screen.dart` — renders:
    - Dark navy hero (SoC % + signed live-flow + mode chip + glossy
      capacity bar + ETA caption)
    - Capacity tiles (capacity / stored / usable / remaining /
      reserve / active power)
    - External AC-IN card (grid / generator / source label /
      feed-in / daily-charge / daily-discharge + relay-Break
      warning + station-inference note)
    - Battery details card (voltage / current / temp / cycles /
      SOH / Ah / status)
    - 48 h SoC line chart via `fl_chart` (smooth curve + soft fill)
- `lib/app/app_router.dart` — new `AppRoutes.batteryLab = '/battery-lab'`
- `lib/features/more/presentation/more_screen.dart` — Battery Lab
  tile now navigates in-app (no more `url_launcher`); "ويب" badge gone

---

## 2. Design System v100

### Research
I surveyed top-rated SaaS mobile apps in this space (Linear, Stripe,
Mercury, Cash App, Revolut, Tesla, Notion) and distilled the common
patterns into 8 principles, documented in the file header of
`lib/core/design/zyn_tokens.dart`. Short version:

1. Surface hierarchy: page → card → tile (each with its own
   gradient + shadow profile).
2. Limited palette, strategic accent (one brand + semantic colours).
3. Strong typography hierarchy (5 sizes, 3 weights, tabular figures).
4. 4-pt spacing grid.
5. 3-D depth without skeuomorphism (multi-layer shadows + thin
   inner highlights, no bevels).
6. ≥ 44 pt touch targets.
7. One focal point per screen.
8. Every screen ships empty / loading / error states.

### Files (`mobile`, commit `eed1fb5`)

- `lib/core/design/zyn_tokens.dart` — colours, spacing, radii,
  shadow stacks, gradient builders, text styles, decoration helpers.
- `lib/core/design/zyn_components.dart` — 9 base widgets:
  - `ZynPage`           — full-page scaffold (gradient backdrop)
  - `ZynCard`           — glossy gradient surface
  - `ZynCardHeader`     — icon tile + title + subtitle inside a card
  - `ZynSectionHeader`  — page-level section marker
  - `ZynStatTile`       — accent-toned stat tile
  - `ZynActionTile`     — tappable nav row with badge + chevron
  - `ZynChip`           — pill chip (light or dark variants)
  - `ZynBadge`          — small pill marker
  - `ZynButton`         — primary / secondary / danger gradient
  - `ZynEmptyState`     — illustration + headline + optional action

---

## 3. Screens redesigned from scratch

### Splash (`mobile`, commit `032f246`)
- Dark navy gradient with two radial blooms (cyan + violet)
- Gradient logo tile with 4-px white ring + indigo glow
- ZYNAVOLT wordmark @ 28 sp / w900 / 3-pt tracking
- Spinner in a faint glass ring container

### Login (`mobile`, commit `032f246`)
- `ZynPage` backdrop
- New `_BrandHero` panel: dark navy card + cyan corner bloom +
  top sheen + gradient logo tile
- Form in `ZynCard` with title / subtitle / fields / error banner
  / `ZynButton` primary CTA / register link
- Backend URL whisper at the bottom

### Register (`mobile`, commit `032f246`)
- Same shell as Login but with a violet bloom variant
- Original field widgets retained (they were already modular)
- Primary CTA now `ZynButton` (with person-add icon)
- Old `_Header` deleted; replaced by `_BrandHero`

### Devices list (`mobile`, commit `38672bd`)
- Gradient backdrop + transparent AppBar
- `_DeviceTile` rebuilt: glossy white → tinted gradient surface,
  1.4-px accent border when selected, two-layer shadow, 44-px
  filled-gradient icon glyph with indigo glow
- FAB wrapped in a shadow container for the lifted indigo halo

### Battery Lab (`mobile`, commit `81eacf7`)
- See section 1 above. All-new screen, design-system native.

### More (already redesigned in v99e + updated in v100)
- Battery Lab tile now opens the native screen instead of the web.

---

## 4. Visual-continuity pass (commit `a7715fe`)

Every screen that still rendered on the flat `AppTheme.softBg`
colour got the `pageBackdropGradient` treatment + transparent
AppBar + `scrolledUnderElevation: 0`. The app now reads as one
continuous gradient surface across:

- Weather
- Notifications + Notification Settings
- Statistics + Reports
- Profile + Account + Loads + Support
- Onboarding + App Settings
- Device Detail

FABs on Devices / Loads / Support got the same "glowing pill"
shadow treatment as v99d primary buttons.

**Important caveat:** This pass changed the page-shell only.
Internal layouts (forms, lists, cards inside these screens) are
**unchanged**. Those still use `AppCard` / hand-rolled containers
and are candidates for a full rebuild against `ZynCard` /
`ZynStatTile` / `ZynActionTile`. See **"What's left"** below.

---

## 5. Compilation status

`flutter analyze --no-pub` after all changes:
```
0 errors
6 informational warnings (pre-existing, unrelated to this redesign):
  • account_repository.dart — unnecessary_type_check / dead_code
  • plan_change_models.dart — dangling_library_doc_comments
  • account_screen.dart — prefer_final_fields
  • plan_change_preview_screen.dart — unnecessary_library_name
  • more_screen.dart — unused_element_parameter
```

Commit `a82b2ea` fixed the one error I introduced (a test that didn't
pass the new `generatorPowerW` field) and cleaned 3 of my own
warnings.

---

## 6. Commits (chronological)

### Web (pushed to main)
| SHA | Title |
|---|---|
| `c56008f` | v100: expose /api/mobile/battery-lab |

### Mobile (local, no remote configured)
| SHA | Title |
|---|---|
| `81eacf7` | v100 (mobile): native Battery Lab screen + route + data layer |
| `eed1fb5` | v100: design system — tokens + base component library |
| `032f246` | v100: migrate Splash + Login + Register to design system |
| `38672bd` | v100: migrate Devices list to new design system |
| `a7715fe` | v100: visual-continuity pass — gradient backdrop on remaining screens |
| `a82b2ea` | v100: analyzer cleanup |

---

## 7. What's left — explicit follow-up work

I made selective choices about depth-vs-breadth. Here's the
honest list of what's done vs what still needs from-scratch
rebuilding when you wake up:

### Done from scratch (rebuilt, not patched)
- Splash ✓
- Login ✓
- Register ✓
- Devices list ✓
- Battery Lab (new) ✓
- More (already done in v99e)
- Home (already done in v99d)

### Visual-continuity only (backdrop + AppBar — internal layout untouched)
The page shell now matches but the internal cards / forms still
use the older AppCard pattern. These are candidates for a full
rebuild against the v100 component library:

- Weather
- Notifications + Notification Settings
- Statistics
- Reports
- Profile
- Account / Subscription
- Loads (list + form sheet)
- Support (list + case detail + create case)
- Onboarding
- App Settings (the time-format card is already v100; the rest is older)
- Device Detail (substantial — multiple internal sections)

### Tasks I deliberately did NOT do
- **Mobile audit / stub completion.** I planned a full sweep for
  TODO comments, `'—'` placeholders, and missing endpoints but ran
  out of time. The next pass should grep for these and produce a
  punch list.
- **Replacing hand-rolled cards inside the migrated screens.** The
  v99d Home / More / Battery Lab still use hand-rolled gradient
  containers instead of `ZynCard`. They look right, but a future
  refactor should reduce them to design-system widgets for
  consistency.

---

## 8. Suggested next-morning checklist

1. `flutter run` — verify Splash → Login → Home flow visually.
2. Tap "مختبر البطارية" in More and confirm the native screen renders
   data (rather than launching the browser).
3. Sweep the Notifications / Profile / Account / Loads screens —
   their backdrops now match but the inner cards are old style. Pick
   the next 1–2 screens you want me to rebuild from scratch.
4. If anything visually feels off (spacing, colour, shadow strength),
   the tokens live in one file (`zyn_tokens.dart`) — tweaks cascade
   across the whole app.

---

Sleep well — looking forward to your review. 🌙
