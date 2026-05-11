# SolarDeye Mobile — MVP Plan (v36)

> **Task name:** `v36-mobile-full-client-api-audit`
> **Status:** Documentation phase only. **No Flutter code, no backend logic changes, no UI changes** are produced by this task.
> **Date:** 2026-05-10
> **Companion docs:** [api_readiness_audit.md](api_readiness_audit.md), [mobile_api_contract_v1.md](mobile_api_contract_v1.md)
> **Design source (canonical):** `docs/design/v35_solardeye_ui_ux_consistency_system.md` in the backend repo (`C:/Users/Ahmad/Desktop/solardeya`).
> **Note:** These docs live in the mobile repo (`F:/solardeya-mobile`) because the backend repo (`C:/.../solardeya`) is currently out of disk space. They reference the backend codebase by path.

---

## 1. Mission

Build a Flutter Android-first mobile client that lets a SolarDeye subscriber complete the **full user journey** — register → onboard → connect a device → view live energy → manage loads → manage notifications → contact support → manage subscription → manage profile — entirely from the phone.

The web app and the mobile app share **one backend, one database, one source of truth**. The mobile client is a presentation layer; it **never** re-derives solar/energy figures and **never** writes through a side channel.

## 2. Non-negotiables

These are absolute rules for every PR in this initiative.

1. **No duplicate business logic in the app.** Energy calculations, surplus prediction, sun phase, weather context, threshold engine, scheduler, dispatch, dedup — all stay server-side. The app reads computed values from the API.
2. **One database.** No mobile-only DB. Local storage on the phone is for offline cache + queued writes only, and is invalidated by `updated_at` timestamps from the backend.
3. **Backend-stable surfaces only.** The hard-locked surfaces from v35 (Flow Graph, scheduler, notification dispatch/dedup, `_live_fleet_rail.html`, `dashboard.html`, settings save engine) are **not touched** by mobile work. Mobile consumes JSON; it does not change how the web renders.
4. **Honest UI.** If a control is global (e.g., notification settings), the mobile screen says global. No fake per-device toggles. (See v35 §10.14.)
5. **Arabic-RTL-first.** Default locale is `ar`. English is a runtime toggle via the existing `?lang=en` plumbing.
6. **Single API surface.** All mobile traffic uses `/api/v1/*`. No screen-scraping HTML pages. If a feature needs a JSON endpoint that does not exist yet, that endpoint is added to the backend in a separate, scoped task before the screen ships.
7. **No features that mutate billing on-device** in MVP (plan upgrades route through a support ticket, mirroring the web `/account/subscription/request-change` flow).
8. **Notifications settings are global today.** The push channel is per-device for delivery, but the *settings* (thresholds, hours, channels) remain global per user — the mobile UI must say so until a server-side per-device settings phase ships.

## 3. Audience and platform

- **Primary persona.** Arabic-speaking solar plant owner / subscriber in Palestine and surrounding region. Owns 1–N devices (typically Deye, plus other providers from the supported catalog). Limited bandwidth and intermittent connectivity is realistic.
- **Platform.** Flutter, Android-first. iOS is technically reachable from the same codebase but is **not** an MVP target. No web build of the Flutter app — the existing Flask web is the desktop/web surface.
- **Min Android.** API 23 (Android 6.0). Target latest stable.
- **Locale.** `ar` default, `en` secondary. RTL by default; layout direction follows `Localizations.localeOf(context)`.

## 4. Architecture (high-level)

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter app (Android)                                      │
│                                                             │
│   UI layer  ───► Riverpod / Bloc state ───► Repositories    │
│                                              │              │
│                                              ▼              │
│                                       Dio HTTP client       │
│                                       + interceptors:       │
│                                         - Bearer token      │
│                                         - Refresh on 401    │
│                                         - Locale header     │
│                                         - Retry / backoff   │
│                                              │              │
└──────────────────────────────────────────────┼──────────────┘
                                               │
                                               ▼
              ┌─────────────────────────────────────────────┐
              │  Flask backend  (existing, unchanged)       │
              │                                             │
              │   /api/v1/auth/*   /api/v1/devices/*        │
              │   /api/v1/mobile/* /api/v1/notifications/*  │
              │   /api/v1/support/*                         │
              │   (gaps listed in api_readiness_audit.md)   │
              │                                             │
              │   Single DB · Scheduler · Dispatch · Dedup  │
              └─────────────────────────────────────────────┘
```

- **State management.** Riverpod (preferred) or Bloc — pick one and stick with it across MVP.
- **HTTP.** `dio` with interceptors. Tokens stored in `flutter_secure_storage`.
- **Local cache.** `drift` (SQLite) for read-side cache only (devices list, latest readings per device, notification list). Never the system of record.
- **Push.** Firebase Cloud Messaging (FCM). Token registered via `POST /api/v1/notifications/push-tokens` (already exists).
- **Routing.** `go_router` with deep links matching backend `direct_url` payloads (so a notification tap can open the right screen).

## 5. MVP scope (what ships in the first release)

A full subscriber journey. Each item maps to existing or planned API endpoints (see [api_readiness_audit.md](api_readiness_audit.md) for gap status).

### 5.1 Auth flow

- Welcome / language picker (default `ar`).
- Login (username + password).
- Register (full set of profile fields used by `auth.register`: username, full_name, email, password, country, city, timezone, phone_country_code + phone_number, preferred_language, has_energy_system, preferred_device_type).
- Forgot password (deferred — no backend route exists today; see audit §6).
- Google sign-in (out of MVP — current OAuth flow is browser-only callback to web).
- Logout.
- Token refresh (silent, on 401).

### 5.2 Onboarding

- "Do you have an energy system?" branch.
- If yes: device-type picker (uses provider catalog from `/api/v1/mobile/bootstrap`).
- Skip-to-explore path for users without a system yet.

### 5.3 Home / dashboard

- Active device + device switcher (multi-device users).
- Latest reading card (solar, load, battery SoC, grid).
- Today / total production figures from the latest `Reading`.
- System status pill (online / stale / offline derived from `last_seen_at` and the `connection_status` column — same thresholds as `fleet_api`: ≤5 min online, ≤30 min stale, else offline).
- **No reimplementation of the Flow Graph.** A simplified power-flow card shows the four directional values; the rich SVG stays on web.
- Sun phase + weather chip (uses `/api/v1/mobile/summary` + a future weather field; see audit §10).

### 5.4 Devices

- List devices owned by user (via `/api/v1/devices`).
- Select active device (mirrors `session['current_device_id']` semantically; mobile sends device id with each request that needs scoping, or persists last selection client-side until a `/select` endpoint is added — see contract §4.6).
- Device detail (latest reading + identifiers; identifiers are masked by default — see security notes).
- Device history (paginated `/api/v1/devices/{id}/history` already exists).
- Add / edit / delete device (currently HTML-only; see audit §3.4).

### 5.5 Live data

- One screen per active device, polling `/api/v1/devices/{id}/latest` at ≤ 15 s cadence (matches v35 §6.2 hard rule).
- PV string breakdown (pv1–pv4), inverter temp, grid voltage / frequency.
- Derived alerts strip via `/api/v1/devices/{id}/alerts`.

### 5.6 Notifications

- Notification feed (paginated) via `/api/v1/notifications`.
- Mark-read (single, list, all) via `/api/v1/notifications/mark-read`.
- Tap-to-open routes via `direct_url` (`go_router` deep-link mapping).
- Settings screen (read-only mirror in MVP; the existing settings save engine is hard-locked for UI changes — see audit §3.6).
- Push token register/unregister via `/api/v1/notifications/push-tokens`.

### 5.7 Channels (Telegram / SMS)

- Read-only summary of channel status (Telegram bot bound? SMS configured?).
- Test send (deferred to post-MVP; `notifications_test_send` is an HTML form today).
- Telegram link via deep-link to existing flow (post-MVP).

### 5.8 Loads

- List user's loads for the active device.
- Add / toggle / delete (gap — currently HTML-only; mobile JSON endpoints needed; see audit §3.5).
- Night max load limit display (read-only in MVP).

### 5.9 Support

- Inbox of cases (`/api/v1/support/cases` already exists).
- Open a case (message vs ticket).
- Reply.
- Reopen.

### 5.10 Subscription / account

- Current plan, days left, quota usage (gap — `/account/subscription` is HTML-only; needs a JSON shadow; see audit §3.7).
- Request plan change → opens a support ticket via the existing `/api/v1/support/cases` path with `category=plan_change_request` (mirrors web behaviour).
- No on-device upgrade-to-paid flow in MVP.

### 5.11 Profile

- View / edit profile fields (name, email, phone, country, city, timezone, preferred_language, password change).
- Avatar upload.
- Profile-driven clock + weather (server returns the user's saved location; the app does **not** ask for GPS or IP geolocation — this matches v35 §10.20).
- All of this is HTML-only today and is the largest single gap. See audit §3.3.

### 5.12 App-level

- Locale toggle ar / en (persisted locally + sent as `?lang=` to API for translated copy).
- Theme follows the SolarDeye palette (v35 §8). MVP is light theme only.
- Connectivity indicator and graceful offline state.
- Crash + non-fatal error reporting (Sentry or Crashlytics — pick one; pick before first beta).

## 6. Out of MVP (explicitly deferred)

- Admin / staff surfaces (mobile is subscriber-only).
- Per-device notification settings (requires schema change — v33-κ deferred plan).
- Telegram bot deep-link from inside the app (post-MVP).
- iOS build.
- Reports / Statistics page (large charts; not phone-friendly for MVP — link out to web).
- Live Flow Graph (locked; web-only).
- Real-time SMS / Telegram test sends from mobile.
- Plan upgrade / payment flow (handled by web + ops).
- Backups, system logs, finance — all admin-only.

## 7. Phasing

| Phase | Scope | Backend dependency |
|---|---|---|
| **v36-α** | Read-only client: bootstrap → dashboard → devices → live data → notifications feed → support read | Existing `/api/v1/*` endpoints. No new routes required. |
| **v36-β** | Profile + account JSON contracts: `/api/v1/profile`, `/api/v1/profile/avatar`, `/api/v1/account/subscription` | New JSON endpoints (see contract §3, §7). |
| **v36-γ** | Loads CRUD: `/api/v1/loads` | New JSON endpoints (see contract §5). |
| **v36-δ** | Support write parity with web: attachments, canned-replies for non-admin (read-only) | Minor extension to `/api/v1/support/*`. |
| **v36-ε** | Channel surfaces (Telegram/SMS read + test): `/api/v1/channels/*` | New JSON wrappers around existing channel state. |
| **v36-ζ** | Push polish: rich notifications, deep-link parity, badge counts | No backend change beyond what `/api/v1/notifications/*` already provides. |

Each phase is a separate scoped task. None of them touch the locked surfaces.

## 8. Visual language (consume v35, do not redesign)

The app uses the same tokens as the web (v35 §8.1):

- **Indigo primary** `#4338ca` / `#6366f1`.
- **Slate ink** `#0f172a`. Muted `#64748b`.
- **Tone palette** for notification cards: `tone-day`, `tone-night`, `tone-sunset`, `tone-weather`, `tone-battery`, `tone-load`, `tone-report`, `tone-discharge`, `tone-content`, `tone-critical`, `tone-rules`.
- **Type:** Cairo for Arabic, system stack for fallback.
- **Form control height:** 42 dp on Android (matches the 42 px web control height).
- **Card radius:** 12 dp on tile cards, 14 dp on hero/notice strips, 16 dp on glass cards.

Map onto Material 3 surfaces:

- `MaterialCardView` ≈ `.ns-card`. Apply tonal `surfaceTint` matching the v35 tone palette.
- `TextInputLayout.helperText` ≈ the single `<small>` helper rule (one helper per field, max).
- 3-column compact icon-card grid translates to a `RecyclerView` `GridLayoutManager` with span 3.
- `prof-hero-avatar-block` translates to `CircleAvatar` + trailing actions row.

(See v35 §9.5 for the existing Android compatibility notes — those are normative.)

## 9. RTL specifics

- `MaterialApp(locale: const Locale('ar'), supportedLocales: [Locale('ar'), Locale('en')])`.
- `Directionality(textDirection: TextDirection.rtl)` is the default. Screens that contain mixed LTR values (DEYE, Asia/Hebron, +970 numbers) wrap those tokens in `Directionality(textDirection: TextDirection.ltr, child: ...)` — same rule as v35 §3.5/§10.16.
- Numerals: keep Western digits `0–9` only (matches v35 §3.5).
- Arabic comma `،` in prose, ASCII `,` only inside LTR runs.
- Phone display canonical `+970 | 599043337` — render the `|` as a separator widget, never as a typed character.

## 10. Engineering ground rules

- **No business logic in the client.** If the answer to "what does this number mean?" depends on weather/sunset/battery curve, the *server* computes it and the client renders.
- **Idempotent writes.** Every POST that mutates state (mark-read, push-token register, support reply) must be safe to retry. The existing endpoints already meet this.
- **One repository per domain.** `AuthRepository`, `DevicesRepository`, `NotificationsRepository`, `SupportRepository`, `ProfileRepository`, `LoadsRepository`, `SubscriptionRepository`, `BootstrapRepository`. No cross-repo calls — the screen layer composes.
- **Telemetry headers.** Send `X-App-Version`, `X-App-Platform: android`, `X-App-Locale` on every request. Server already accepts and ignores extras gracefully.
- **CI gates.** `flutter analyze`, `flutter test`, build APK in debug mode. No real device test in CI.
- **Versioning.** Pin `dio`, `riverpod`, `drift`, `go_router`, `flutter_secure_storage` to specific versions in `pubspec.yaml`; review every minor bump.

## 11. Loading / offline / error UX

- **Loading.** Skeleton placeholders for first paint of dashboard / devices / notifications. Never block the whole screen on a single network call after first paint — degrade to "last cached at HH:mm" when fresh data is unavailable.
- **Offline.** Read-side: cached `devices`, last `latest` reading per device, last 50 notifications. Write-side: queue mark-read and push-token register; replay on reconnect. Loads CRUD and support reply are **not** queued — they show "no connection" and let the user retry.
- **Errors.** Map `ApiError.code` → user-facing Arabic copy via a translation table. Never show raw HTTP codes to the end user. Only show stack traces in debug builds.
- **Account-restricted.** When `account_restricted: true` (from `/api/v1/auth/me`), the app enters read-only mode and shows a sticky banner pointing at the subscription screen — same posture the web takes.
- **Token refresh.** On 401 from any non-auth endpoint, run `/auth/refresh` once, replay the original request, then bubble the error if it still fails. Never refresh in a loop.

## 12. Notes against the v35 hard locks

The mobile work touches **none** of these:

- `Flow Graph` template + JS + SVG (md5 `56124a8799a3bb800231d99d83f6d616`).
- `app/scheduler/*`.
- `app/services/notifications/__init__.py`, `app/services/notifications/utils.py`.
- `app/blueprints/notifications.py::save_notification_settings_from_form`.
- `app/services/weather_service.py` (consumed indirectly via `/api/v1/mobile/summary` + future weather field).
- `app/blueprints/reports.py` (PDF pipeline).
- `dashboard.html`, `_live_fleet_rail.html`.

If a mobile screen seems to need one of these, route it through a **separate scoped task** that justifies and isolates the change — never bundle it with the mobile UI work.

## 13. Definition of done — v36-α (read-only client)

- User can install the APK, register OR log in, see their dashboard, switch device, view live data, see notification feed, mark notifications read, view support cases, in Arabic, end-to-end, with no backend changes.
- All screens render correctly in RTL and in dark / power-saving conditions.
- Crash-free for a 30-min smoke session on a low-end Android (e.g., 3 GB RAM).
- No screen calls a `/api/v1/*` endpoint that doesn't exist in `openapi.json` today.
- The build passes `flutter analyze` with zero errors and a documented set of allowed warnings.
