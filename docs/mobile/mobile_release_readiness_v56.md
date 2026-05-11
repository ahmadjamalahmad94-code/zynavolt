# Zynavolt Mobile — Release-Readiness Audit (v56)

This document is a snapshot of the mobile app as of v56. It is **purely
informational**: no code in this commit changes behaviour. Use it as a
pre-release checklist when preparing the first internal-test or Play
Console Internal Testing build.

The backend repository (`C:/Users/Ahmad/Desktop/solardeya`) was **not
touched** during the v50–v56 work block, and is not changed by this doc.

---

## 1. Versions shipped to date

Each version landed as its own commit on `main` and represents a single
focused, read-only-by-default capability.

| Tag | Title | Read-only? |
| --- | --- | --- |
| v37 | Establish Flutter foundation (routing, theme, Dio, secure storage) | n/a |
| v38 | Selected-device context | yes |
| v39 | Verify real backend connection | yes |
| v39b | Zynavolt branding labels | yes |
| v40 | Read-only mobile dashboard | yes |
| v41 | Read-only notifications feed | mostly (mark-read writes only) |
| v42 | Mobile profile read + edit | edit only |
| v43 | Navigation & safety polish | yes |
| v44 | Location-catalog profile controls | edit only |
| v45 | Rebuild energy flow as fixed-grid board | yes |
| v46 | Branding / typography / spacing polish | yes |
| v47 | Read-only device details | yes |
| v48 | Read-only loads foundation | yes |
| v49 | Honest energy-flow direction animation (solar / home directional; battery / grid pulse) | yes |
| v50 | Read-only support foundation (list + thread) | yes |
| v51 | Read-only account & subscription | yes |
| v52 | Polished device details (sectioning, status, latest tiles) | yes |
| v53 | Polished loads (search + scope filter) | yes |
| v54 | Polished notifications feed (filter + humanized time + accent bar) | yes |
| v55 | Read-only app settings & info | yes |
| v56 | This release-readiness doc | docs only |

---

## 2. Screens — current state

| Screen | Route | Source endpoints | Status |
| --- | --- | --- | --- |
| Splash | `/splash` | (local; AppSession restore) | ready |
| Login | `/login` | `POST /api/mobile/auth/login`, `/refresh` | ready |
| Home (Dashboard) | `/home` | `GET /api/mobile/dashboard`, `/bootstrap` | ready |
| Energy flow board | (inside Home) | `dashboard` only — no per-component endpoint | ready |
| Devices list | `/devices` | `GET /api/mobile/devices` | ready |
| Device details | `/devices/:id` | `GET /api/mobile/devices/:id` | ready (v52 polish) |
| Loads | `/loads` | `GET /api/mobile/loads[?device_id=]` | ready (v53 polish) |
| Notifications | `/notifications` | `GET /api/mobile/notifications`, `/:id/read`, `/read-all` | ready (v54 polish) |
| Support inbox | `/support` | `GET /api/v1/support/cases` | ready (v50) |
| Support thread | `/support/:kind/:id` | `GET /api/v1/support/cases/:kind/:id` | ready (v50) |
| Profile | `/profile` | `GET/PATCH /api/mobile/profile` + location catalog | ready (edit) |
| Account & subscription | `/account` | `GET /api/mobile/account` | ready (v51) |
| App settings | `/settings` | (local + `GET /api/mobile/health` button) | ready (v55) |
| More tab | `/more` | session info + health check + nav tiles | ready |
| Health check | (in More + Settings) | `GET /api/mobile/health` | ready |

All routes outside `/login` and `/splash` are gated by
`AppSession.phase == authenticated` via the `routerProvider` redirect.

### Strictly read-only screens
Device details, Loads, Notifications (read side), Support (list + thread),
Account/Subscription, App settings, Health check, Energy flow board.

### Write-allowed screens (limited)
- Login: `POST /auth/login` only.
- Profile: `PATCH /profile`.
- Notifications: `POST /:id/read`, `/read-all` (server-confirmed).
- Logout: `POST /auth/logout` from More.

### Intentionally absent (out of scope this phase)
- Plan / billing changes.
- Account deletion.
- Password change.
- Logout-all refresh tokens.
- Load toggle / hardware control.
- Scheduler manipulation.
- Notification settings (Telegram / SMS / per-device).
- Push notifications / FCM.
- Offline database / queue.
- Charts.

---

## 3. Backend dependency

The app consumes the Flask `mobile_core_api_bp` blueprint
(`/api/mobile/*`) and `mobile_support_api_bp` (`/api/v1/support/*`)
exclusively. No direct database access, no web HTML scraping.

All endpoints are Bearer-authed via `flutter_secure_storage`-held tokens,
except `GET /api/mobile/health` and `POST /api/mobile/auth/*`.

### Render base URL

The default is the Android-emulator-friendly `http://10.0.2.2:5000`. For
release builds and real devices, the URL is supplied at build time:

```
flutter build apk --dart-define=SOLARDEYE_API_BASE_URL=https://solardeye.onrender.com
flutter run -d <device-id> --dart-define=SOLARDEYE_API_BASE_URL=https://solardeye.onrender.com
```

The current verified production URL is **`https://solardeye.onrender.com`**.

Mobile users never see secrets, API keys, refresh tokens, or admin
identifiers — the auth interceptor attaches `Bearer` headers from secure
storage and refreshes once on 401 before redirecting to login.

---

## 4. Known gaps before public release

Tracked here so they don't get forgotten. Each is **non-blocking** for
internal testing but should be resolved before a public store release.

### 4.1 Brand assets
- **`assets/branding/zynavolt_logo.png`** — currently absent from the
  repo. Every consumer of the logo path uses `Image.asset(...,
  errorBuilder: ...)` with a sun-icon / "Z" fallback, so the app builds
  and renders cleanly without it. Drop a 1024×1024 PNG here before
  release.

### 4.2 Arabic typography
- No `fonts:` section in `pubspec.yaml`. `app_theme.dart` falls back to
  `Roboto`. The wiring recipe for **Cairo** / **Tajawal** is documented
  in `assets/branding/README.md` and in `app_theme.dart` itself —
  one-line code change once the font ttf is dropped under
  `assets/branding/fonts/Cairo/`.

### 4.3 Network security configuration
- `android/app/src/main/res/xml/network_security_config.xml` is **not**
  customized; the app uses the platform default (Android 9+: HTTPS-only,
  with no cleartext exceptions). The current Render base URL is HTTPS,
  so no exception is needed. If a future LAN test target ever uses
  plain HTTP, add a localized cleartext exception there — do **not**
  flip `usesCleartextTraffic="true"` globally.

### 4.4 Localization
- The app ships Arabic-only. `flutter_localizations` is declared as a
  dependency but no ARB files are wired yet. All visible strings are
  hard-coded Arabic. English / additional locales are a separate phase.

### 4.5 Push notifications
- Not wired. No Firebase / FCM. Notifications are pulled from
  `GET /api/mobile/notifications` on demand and on pull-to-refresh.

### 4.6 Destructive actions
- **Intentionally absent** by project policy. Add only with explicit
  user-facing confirmation flows when scoped in a future version.

### 4.7 Logo / launcher icons
- Android launcher icons in `android/app/src/main/res/mipmap-*/` are the
  default Flutter raster. Regenerate from the Zynavolt logo (e.g. via
  `flutter_launcher_icons`) before public release.

### 4.8 Bundle identifier / package name
- Current `applicationId` is the foundation default. **Do not change
  here** — coordinate with backend's signing / Play Console identity
  before any public push.

---

## 5. Smoke checklist — real Android device

Run with:
```
F:\flutter\bin\flutter.bat run -d <device-id> --dart-define=SOLARDEYE_API_BASE_URL=https://solardeye.onrender.com
```

For each of the following, verify the behaviour on a physical device
before declaring an internal build ready:

### Auth & session
- [ ] Cold launch → splash → login (when not signed in).
- [ ] Cold launch → splash → home (when signed in, token still valid).
- [ ] Login with valid credentials succeeds; router redirects to Home.
- [ ] Login with bad credentials shows a clear Arabic error message.
- [ ] App restart preserves session (token survives in Android Keystore).
- [ ] Logout from More → returns to login, clears session.

### Home (dashboard)
- [ ] Dashboard loads real values within ~2s on a normal connection.
- [ ] Cards show real W/kWh/% values; no fake numbers.
- [ ] Fixed-grid energy board renders without overflow at all common
      screen widths (5"–6.7").
- [ ] Energy-flow directions:
  - Solar → inverter when `solar_power_w > 0`.
  - Inverter → home when `home_load_w > 0`.
  - Battery: hub → battery when charging, battery → hub when
    discharging, pulse otherwise.
  - Grid: pulse only — no false direction.
- [ ] Status banner shows the server's `status_text` when present.

### Devices
- [ ] Devices tab lists owned devices with real connection status.
- [ ] Tap a device → opens Device Details.
- [ ] Device Details shows: name, plant, status pill, last connected,
      latest reading tiles, safe settings (if present), info & history.
- [ ] "تعيين كجهاز نشط" sets the active device locally; UI updates.
- [ ] Back button returns to Devices list cleanly.

### Loads
- [ ] More → الأحمال opens the loads list.
- [ ] List shows real loads; no fake examples.
- [ ] Search filters by name client-side.
- [ ] "كل الأحمال" / "الجهاز النشط" chips toggle the backend scope.
- [ ] Empty state shows when account has no loads.

### Notifications
- [ ] Feed loads real items.
- [ ] Read/unread visual is clear (left accent bar + dot).
- [ ] "اقرأ الكل" marks all read on the server; UI updates.
- [ ] "الكل / غير المقروء" filter pills toggle the local view.
- [ ] Timestamps render as today HH:mm / أمس HH:mm / older YYYY-MM-DD.

### Support
- [ ] Support tab loads real cases (or empty state).
- [ ] Tap a case → opens read-only thread.
- [ ] Admin replies render with the indigo "الدعم" header.
- [ ] User replies render with the muted "أنت" header.

### Account / subscription
- [ ] More → الحساب والاشتراك loads real role, plan, status, devices,
      capabilities.
- [ ] No destructive buttons visible.

### Profile
- [ ] More → الملف الشخصي loads current profile.
- [ ] Edits save; success / error are visible.

### Settings & health
- [ ] More → إعدادات التطبيق loads.
- [ ] App version / platform / base URL display correctly.
- [ ] "تحقّق من الاتصال" succeeds against the Render backend.
- [ ] Active-device summary is consistent with what Home shows.

### Misc
- [ ] No English UI text visible anywhere (Zynavolt brand + W/kW/kWh/%
      are the only Latin tokens).
- [ ] No layout overflow at any tested device size.
- [ ] RTL is consistent — back chevron points the right direction
      (towards `chevron_left` in directional contexts).

---

## 6. Out-of-scope confirmations (audit)

| Item | Status |
| --- | --- |
| Backend repo edits | **None.** Read-only inspection only. |
| Web project edits | **None.** Not touched. |
| Web Flow Graph edits | **None.** Not touched. |
| Fake/mocked data on screens | **None.** All values come from backend or are explicit "—" placeholders. |
| Destructive actions | **None.** Profile edit + mark-read are the only writes today. |
| Firebase / FCM / push tokens | **Not wired.** |
| Offline DB / queue | **Not present.** |
| `git add .` usage | **Never used.** All commits stage explicit paths. |
| Package name / applicationId change | **Not changed.** |

---

## 7. Next recommended phases (informational only)

Suggestions to consider after the first internal release lands:

1. **Brand assets**: drop the real `zynavolt_logo.png` + regenerate
   Android launcher icons.
2. **Cairo / Tajawal font**: enable per the recipe in
   `assets/branding/README.md`.
3. **Localization phase**: introduce `flutter_localizations` ARB and a
   minimal `ar` / `en` resource set; expose toggle in app settings.
4. **Push notifications**: once the backend exposes a push channel, wire
   FCM and surface a "تجريب" button in settings.
5. **Per-device notification settings**: read-only first, edit later.
6. **Device-detail latest-reading freshness**: show a relative "since"
   chip ("منذ X دقيقة") next to the timestamp.

These are *suggestions*. They do not need to land before the first
internal release; the app as-of-v56 is functional, calm, and read-only-
safe.
