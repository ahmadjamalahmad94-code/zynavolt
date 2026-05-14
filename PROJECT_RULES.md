# PROJECT_RULES.md — Zynavolt mobile

Single source of truth for the **conventions, design rules, removal/
addition checklists, and temporary trial-features** that shape this
codebase. Grep by tag (e.g. `#removal`, `#design`, `#temporary`) to
jump to the section you need. Update this file whenever a rule
changes — never let conventions live only in commit messages.

---

## Tag index

| Tag | What it covers |
|---|---|
| `#design` | Visual / UI rules, design tokens, component patterns |
| `#removal` | How to safely delete temporary or deprecated code |
| `#addition` | Conventions for adding new screens / features |
| `#workflow` | Git, commits, analyzer, build, deploy |
| `#convention` | Coding conventions (naming, imports, file structure) |
| `#temporary` | Trial features marked for future removal |
| `#backend` | Backend (Flask) ↔ mobile contract conventions |
| `#branding` | Brand assets (logo, launcher icon, fonts) |
| `#a11y` | Accessibility, RTL, font scaling |
| `#perf` | Performance / bundle-size considerations |

---

## 1. Design system v100 — `#design`

The single source of design vocabulary lives in
`lib/core/design/`. Two files, never edit them inline in screens:

```
lib/core/design/zyn_tokens.dart      — colors, spacing, radii, shadows, typography
lib/core/design/zyn_components.dart  — ZynCard, ZynActionTile, ZynChip, ZynButton, …
```

### 1.1 Eight SaaS-app design principles
(distilled from Linear / Stripe / Mercury / Cash App / Revolut / Tesla /
Notion — full description in `zyn_tokens.dart` header)

1. **Surface hierarchy** — page → card → tile (each level has its own
   gradient + shadow profile). No flat squares.
2. **Limited palette, strategic accent** — one brand colour (indigo)
   plus semantic accents (success / warning / danger / cyan / violet)
   used only to signal state, not for decoration.
3. **Strong typography hierarchy** — 5 sizes, 3 weights. Numbers always
   `tabularFigures()`. Arabic uses Alexandria.
4. **Generous, predictable spacing** — 4-pt grid: xs/sm/md/lg/xl.
5. **3-D depth without skeuomorphism** — multi-layer shadows + thin
   inner-edge highlights. No bevels.
6. **Touch targets ≥ 44 pt** — every tappable surface, even chips.
7. **One focal point per screen** — the hero card is the strongest
   visual; nothing else competes.
8. **Always-on edge states** — every screen ships `loading` + `empty`
   + `error` paths. Never a silent blank surface.

### 1.2 Page shell pattern — every new screen `#design` `#addition`

```dart
return Scaffold(
  backgroundColor: Colors.transparent,
  appBar: AppBar(
    title: const Text('...'),
    backgroundColor: Colors.transparent,   // page gradient flows under it
    scrolledUnderElevation: 0,             // no surface tint on scroll
    actions: [...],
  ),
  body: DecoratedBox(
    decoration: const BoxDecoration(gradient: AppTheme.pageBackdropGradient),
    child: SafeArea(
      child: <body>,
    ),
  ),
);
```

**Or** use the canonical helper:

```dart
return ZynPage(
  appBar: AppBar(...),
  child: <body>,
);
```

### 1.3 Card / tile shorthand `#design`

```dart
ZynCard(
  accent: AppTheme.success,           // optional tint
  child: Column(children: [...]),
)

ZynStatTile(
  icon: Icons.bolt_rounded,
  tone: AppTheme.warning,
  label: 'الاستهلاك',
  value: '4.2 kWh',
)

ZynActionTile(
  icon: Icons.science_rounded,
  label: 'مختبر البطارية',
  subtitle: 'تحليلات SOC والمدخل الخارجي.',
  tone: AppTheme.success,
  badge: 'جديد',
  onTap: () => context.push(AppRoutes.batteryLab),
)
```

### 1.4 Hero card pattern — dark navy `#design`

For prominent surfaces (login brand panel, More hero, Battery Lab
state hero):

```dart
Container(
  decoration: zynHeroOuterDecoration(radius: 24),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: DecoratedBox(
      decoration: const BoxDecoration(gradient: ZynColors.heroGradient),
      child: Stack(children: [
        // 1. radial bloom in a corner (cyan/indigo/violet variants)
        // 2. top hairline specular sheen
        // 3. content padded inside
      ]),
    ),
  ),
);
```

### 1.5 Floating-pill button pattern `#design`

Wrap any FAB in a shadow `Container` so the indigo halo lifts the
button off the page (used in Devices, Loads, Support):

```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(999),
    boxShadow: [BoxShadow(
      color: AppTheme.indigoPrimary.withValues(alpha: 0.45),
      blurRadius: 18, offset: const Offset(0, 8),
    )],
  ),
  child: FloatingActionButton.extended(
    backgroundColor: AppTheme.indigoPrimary,
    elevation: 0,                       // we own the shadow above
    icon: const Icon(Icons.add_rounded),
    label: const Text('...', style: TextStyle(fontWeight: FontWeight.w900)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    onPressed: () { ... },
  ),
);
```

### 1.6 Forbidden visual patterns `#design`

* ❌ Flat `Container(color: AppTheme.softBg)` page bodies — must use
  `pageBackdropGradient`.
* ❌ Hard-coded hex colours in screen widgets — use `AppTheme.*` /
  `ZynColors.*` / a tone parameter.
* ❌ Magic spacing numbers — use `ZynSpacing.*` (`xs`, `sm`, `md`,
  `lg`, `xl`, `xxl`, `xxxl`).
* ❌ `Card()` widget — always `ZynCard` or hand-rolled `Container`
  with `zynGlassCardDecoration(...)`.
* ❌ `Icon(Icons.foo)` without a colour token — pass an explicit
  colour from the design system.
* ❌ `Text('123 W')` without `fontFeatures: [FontFeature.tabularFigures()]`
  on numeric values — they jitter on hourly updates otherwise.

---

## 2. Addition rules — `#addition`

### 2.1 New screen checklist

1. Wrap in `ZynPage` (or hand-rolled equivalent — see 1.2).
2. AppBar must be transparent + `scrolledUnderElevation: 0`.
3. Empty / loading / error states are **mandatory**, not optional.
   Use `AppLoading`, `AppErrorState`, `AppEmptyState` (or `ZynEmptyState`).
4. Pull-to-refresh: every data screen wraps its scroll in
   `RefreshIndicator(color: AppTheme.indigoPrimary, ...)`.
5. Add the route to `lib/app/app_router.dart` only — never instantiate
   screens via `Navigator.push(...)` from a button (use `context.push`).
6. If the screen surfaces user-targeted info, audit RTL by running on
   an emulator with system locale = English to confirm the layout
   flips correctly.

### 2.2 New mobile API call checklist `#backend` `#addition`

1. Backend: register the path in
   `app/blueprints/mobile_api.py::_MOBILE_GET_ROUTES` (or the
   matching POST/PATCH dict). Without this the catch-all 404
   handler shadows the new endpoint.
2. Auth: `_require_bearer_user()` — never allow unauthenticated.
3. Response envelope: `api_ok(payload, meta={'api_version': 'v1', 'namespace': 'api/mobile'})`.
4. Mobile: data layer goes in `lib/features/<feature>/data/`:
   - `*_models.dart` — typed `fromJson` constructors, every field
     nullable on the receiver side (server may omit).
   - `*_repository.dart` — `ApiClient.get(...)` + `Riverpod` provider.
5. Riverpod provider key: when the data is device-scoped, watch
   `effectiveDeviceIdProvider` so changing the active device
   refetches automatically.
6. Test: at minimum verify the endpoint is in the allowed-methods
   registry and the helpers it uses are imported. Pattern lives in
   `tests/test_v100_battery_lab_mobile.py`.

### 2.3 New widget naming `#convention`

* Public reusable widget → `ZynFoo` in `lib/core/design/zyn_components.dart`.
* Screen-private widget → `_FooBar` (underscore prefix) in the same file.
* Helper extending an existing pattern → put it next to its caller,
  not in design-system files.

---

## 3. Removal rules — `#removal`

### 3.1 Generic "removing temporary code" workflow

When killing a feature or trial widget:

1. **Search every reference** before deleting the source file:
   ```
   Grep("FooClass", glob: "**/*.dart")
   ```
2. **Delete in this order**:
   a. UI call sites (the widget rendered in screens)
   b. Riverpod providers + repositories
   c. The model / enum source file
   d. The pubspec dependency (if added solely for this feature)
3. **Run `flutter analyze`** — must be 0 errors before commit.
4. **Update README / docs** — every README that referenced the
   removed feature gets updated in the same commit.
5. **Commit** with a message that documents what was removed AND why,
   so a future bisect understands the intent.

### 3.2 Removing the font picker — `#temporary` `#removal`

Specific to the v100-fonts trial in
`lib/core/state/font_pref.dart`. Once a winner is chosen:

1. **If Alexandria wins** (the bundled default):
   - Delete `lib/core/state/font_pref.dart`.
   - Delete `_FontCard` + `_FontOption` + `_Radio` from
     `lib/features/settings/presentation/app_settings_screen.dart`.
   - Remove `import 'font_pref.dart'` from three files:
     - `lib/app/solar_deye_app.dart`
     - `lib/app/app_theme.dart`
     - `lib/features/settings/presentation/app_settings_screen.dart`
   - Remove the `font:` parameter from `AppTheme.light(...)` and
     restore the v99c hard-coded `fontFamily: 'Alexandria'` lines.
   - Drop `google_fonts: ^6.2.1` from `pubspec.yaml`.

2. **If a Google Fonts variant wins** (Cairo / Tajawal / etc.):
   - Either:
     a) **Bundle it** — download the .ttf weights, place under
        `assets/fonts/<Name>/`, declare in `pubspec.yaml > flutter.fonts`,
        update `AppTheme.light(...)` to set `fontFamily: '<Name>'`.
        Then drop `google_fonts` and follow path (1) above.
     b) **Keep `google_fonts`** for that single font — call
        `GoogleFonts.<name>TextTheme(...)` once in `app_theme.dart`,
        delete the picker UI but keep the import.

### 3.3 Removing the language card — `#temporary` `#removal`

`_LanguageCard` in `app_settings_screen.dart` is a placeholder
notice. When real Arabic/English switching ships:

* Replace the card with a real radio (Arabic / English).
* Wire to a new `LocalePref` enum + Riverpod provider (mirror
  `TimeFormatPref`).
* Make `solar_deye_app.dart`'s `Directionality.textDirection` flip
  with the active locale.
* Remove the "coming soon" copy.

---

## 4. Workflow — `#workflow`

### 4.1 Git rules

* **NEVER `git add .`** — always specify files explicitly. Stops
  accidental commits of `.env`, screenshots, scratch files.
* **NEVER skip hooks** (`--no-verify`, `--no-gpg-sign`) unless the
  user explicitly asks.
* **NEVER push --force** without explicit permission.
* **NEVER amend** an existing commit — always create a new one.
  After a hook failure, fix and create a fresh commit.
* Mobile repo has **no remote** by design — commits stay local.
  Web repo's `origin/main` is push-deploy via Render.

### 4.2 Commit message style

```
v<version>: short imperative summary (≤ 70 chars)

Why this commit exists (1–3 sentences).

Changes:
  * file1 — what changed
  * file2 — what changed

Notes for the next reader (gotchas, follow-up work, etc.).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

* Include a `Co-Authored-By` trailer when Claude Code wrote the
  commit.
* Never use emojis in commit messages unless the user asks.

### 4.3 Analyzer gate `#workflow`

Before committing:

```bash
flutter analyze --no-pub
```

Must be **0 errors**. Warnings/infos that pre-date your work are
OK to leave; never introduce new ones in your own files.

### 4.4 Branding regenerate `#branding` `#workflow`

When replacing `assets/branding/zynavolt_app_icon.png`:

```bash
flutter pub get
dart run flutter_launcher_icons
```

Then commit the regenerated `android/app/src/main/res/mipmap-*` and
`drawable-*hdpi/ic_launcher_foreground.png` files together with the
new source PNG.

---

## 5. Branding rules — `#branding`

### 5.1 Two-file convention

```
assets/branding/zynavolt_logo.png       ← used INSIDE the app
assets/branding/zynavolt_app_icon.png   ← Android launcher icon source
```

These can be the same artwork; `_logo.png` is just a copy so
existing widget code (`Image.asset('assets/branding/zynavolt_logo.png', ...)`)
finds it under its historical filename without code changes.

### 5.2 In-app brand call sites

Every place that renders the logo:

* `lib/features/splash/presentation/splash_screen.dart`
* `lib/features/auth/presentation/login_screen.dart`
* `lib/features/auth/presentation/register_screen.dart`
* `lib/features/home/presentation/home_screen.dart`
* `lib/features/settings/presentation/app_settings_screen.dart`

All use `Image.asset(..., errorBuilder: (...) => fallback)` so the
build never breaks if the asset is missing.

### 5.3 Adaptive icon settings

Configured in `pubspec.yaml > flutter_launcher_icons`:
```yaml
adaptive_icon_background: "#0E1A2E"   # brand navy
adaptive_icon_foreground: "assets/branding/zynavolt_app_icon.png"
min_sdk_android: 23
```

If the foreground crops awkwardly on Android 8+, adjust the
`<inset android:inset="..." />` in
`android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (default
16% — drop to 12% for tighter logos, raise to 20% for breathing room).

---

## 6. Active TEMPORARY items — `#temporary`

| Item | Source | When to remove |
|---|---|---|
| Font picker | `lib/core/state/font_pref.dart` + `_FontCard` in settings | After owner picks a permanent Arabic font |
| `google_fonts` dep | `pubspec.yaml` | Together with font picker (unless winner is a Google font we keep at runtime) |
| `_LanguageCard` placeholder | `lib/features/settings/presentation/app_settings_screen.dart:518+` | When real ar/en localization ships |
| `flutter_launcher_icons` dev dep | `pubspec.yaml` | Optional — keep if launcher icon may change again; otherwise drop after generating once |

---

## 7. Backend ↔ mobile contract — `#backend` `#convention`

* All mobile endpoints live under `/api/mobile/*` (the
  `mobile_core_api_bp` blueprint, `app/blueprints/mobile_api.py`).
* Every endpoint must be in the `_MOBILE_GET_ROUTES` (or
  `_MOBILE_POST_ROUTES`, etc.) registry, otherwise the catch-all
  404 handler shadows it.
* Auth: bearer token via `_require_bearer_user()`. Never accept
  cookie auth on a mobile route.
* Response envelope: `api_ok(payload)` for success,
  `api_error(message, code, status)` for failure. Both wrap the
  payload in `{ ok, data, meta, error }`.
* Device scope: `_mobile_device_scope(user)` returns
  `(mode, device, error)`. Honour `?device_id=N` query param.

---

## 8. State management — `#convention`

* Riverpod everywhere. Pattern reference: `time_format_provider.dart`,
  `font_pref.dart`, `dashboard_repository.dart`.
* Persistent prefs go through `FlutterSecureStorage` — same instance
  the auth tokens use, key namespace `solardeye.<name>`.
* Async data: `FutureProvider` if it's a one-shot fetch with manual
  invalidate, `StateNotifierProvider` if it has multiple related
  mutations.
* Auto-refetch on device change: watch `effectiveDeviceIdProvider`
  inside the provider.

### 8.1 Auto-refresh (`AutoRefreshScope`) — `#convention`

Live screens auto-refresh via `lib/core/state/auto_refresh.dart`. The
shared `WidgetsBindingObserver` is mounted exactly once from
`solar_deye_app.dart` (`ref.watch(appLifecycleObserverProvider)`).
Screens that want periodic refresh wrap their body in
`AutoRefreshScope(interval:, targets:, child:)` — the scope owns a
`Timer.periodic`, invalidates each target on tick, pauses while
the app is backgrounded, and fires an immediate tick on resume if
the previous tick is stale.

**Canonical cadence table** (owner-chosen 2026-05-14):

| Screen | Interval | Providers |
|---|---|---|
| Home | 30 s | `dashboardProvider`, `insightsProvider`, `statisticsProvider`, `energyChartSeriesProvider` |
| Battery Lab | 30 s | `batteryLabProvider` |
| Devices list | 60 s | `devicesListProvider` |
| Notifications inbox | 60 s | (custom `silentRefresh()` on the controller — does not use `AutoRefreshScope` so the feed never flickers) |
| Everything else | — | pull-to-refresh only |

**Rules:**

* Don't add `AutoRefreshScope` to non-live screens (settings, account,
  add-device flow). The extra invalidations waste data and battery.
* `targets:` is a non-const `List<ProviderOrFamily>` — provider
  instances aren't compile-time constants, so the list literal can't
  be `const`. Wrap individual values in `const Duration(...)` etc.
* For a flicker-free silent refresh (Notifications inbox pattern),
  listen to `appLifecycleProvider` directly and call a custom
  `silentRefresh()` on the controller — see
  `notifications_screen.dart` for the pattern.
* Pull-to-refresh stays on every screen that already had it. The
  auto-refresh is additive, not a replacement.

---

## 9. RTL & accessibility — `#a11y`

* The app is RTL-first. `solar_deye_app.dart` wraps the whole
  router in `Directionality(textDirection: TextDirection.rtl)`.
* Numeric values use `fontFeatures: [FontFeature.tabularFigures()]`
  so they don't jitter on live updates.
* Latin-token timestamps (e.g. `2026-05-13T18:55:53`) get
  `textDirection: TextDirection.ltr` on their `Text` widget so the
  hyphens and digits read in the natural Latin order.
* Touch targets ≥ 44 dp (iOS HIG / Android material guideline).
  Pills include vertical padding to clear this even when the visual
  height is smaller.

---

## 10. Performance / bundle — `#perf`

* `google_fonts` is a runtime-fetched dependency. After picking a
  permanent font, **bundle it** as `.ttf` to avoid the first-launch
  network call.
* Logo PNG should be max 1024×1024 (Flutter scales down crisply).
  The current `zynavolt_app_icon.png` is 95 KB at that resolution.
* `fl_chart` is heavyweight — use only inside chart-bearing screens
  (`features/charts/`, `features/battery_lab/`); never in a
  high-traffic shell widget.

---

## 11. Where things live — quick map

```
lib/
  app/
    app_config.dart           — env tokens, defaultLocale, base URL
    app_router.dart           — go_router routes (every screen registers here)
    app_theme.dart            — ThemeData + colour/spacing/shadow tokens
    solar_deye_app.dart       — MaterialApp.router (watches font/time prefs)
  core/
    api/                      — Dio client, ApiResponse envelope
    design/                   — Zyn* design system (tokens + components)
    state/                    — Riverpod providers shared across features
    utils/                    — pure helpers (backend_time, etc.)
    widgets/                  — legacy AppCard/AppLoading/AppEmptyState
                                (being phased out in favour of Zyn*)
  features/
    auth/                     — login, register
    splash/                   — boot splash
    home/                     — Home tab + Flow Graph + Hero
    devices/                  — list + detail + setup flows
    weather/
    notifications/
    insights/
    charts/                   — fl_chart wrappers (HomeEnergyChartCard, etc.)
    statistics/
    reports/
    profile/
    account/                  — subscription, plan-change, change-password
    loads/
    support/
    onboarding/
    settings/                 — app_settings_screen (font + time + lang)
    more/                     — More tab
    battery_lab/              — native Battery Lab (v100)
assets/
  branding/                   — logo + launcher icon source
  fonts/                      — bundled Alexandria weights
android/
  app/src/main/res/
    mipmap-*/                 — generated launcher icons
    drawable-*hdpi/           — generated adaptive foreground
```

---

## 12. Reports + retrospectives

When an overnight or large-scope work session lands, write a brief
report in this folder:

```
MORNING_REPORT_<version>.md
```

Latest: `MORNING_REPORT_v100.md`. Pattern: TL;DR → highlights →
commits → what's left. Reference this rules file for "the why" so
the report can stay short.

---

## Updating this file

When a rule changes:

1. Edit the relevant section.
2. Add a one-liner under section 13 (changelog) with the date and
   what shifted.
3. Tag the commit with `#rules` so it's easy to find later.

---

## 13. Changelog

* **2026-05-14** — Initial draft. Captures v100 design system, font
  picker trial, branding two-file convention, removal/addition
  workflows, backend contract, RTL/perf notes.
* **2026-05-14** — Added §8.1 (`AutoRefreshScope` + canonical cadence
  table) for v101 auto-refresh foundation. Home / Battery Lab at 30 s,
  Devices / Notifications at 60 s. All timers pause on background.
* **2026-05-14** — Android `applicationId` + `namespace` renamed
  `ps.solardeye.solardeye_mobile` → `com.zynavolt.app` for Firebase
  registration and Play Store identity. Done before publishing —
  applicationId is permanent post-publish. The internal Dart package
  name (`pubspec.yaml: name:`) is still `solardeye_mobile` and only
  affects test imports — kept as-is to avoid churning 28 test files.
