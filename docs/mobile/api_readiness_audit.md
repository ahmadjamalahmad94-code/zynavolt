# SolarDeye — API Readiness Audit for Mobile (v36)

> **Task name:** `v36-mobile-full-client-api-audit`
> **Date:** 2026-05-10
> **Scope:** Read-only audit of the existing Flask backend at `C:/Users/Ahmad/Desktop/solardeya/`. No backend code modifications were made. No locked surfaces were inspected for editability.
> **Companion docs:** [mobile_mvp_plan.md](mobile_mvp_plan.md), [mobile_api_contract_v1.md](mobile_api_contract_v1.md)

---

## 0. Method

Routes were enumerated by grepping every `@<bp>.(route|get|post|put|delete|patch)` decorator across `app/blueprints/*.py` and inspecting the corresponding handler. JSON return paths were confirmed by checking for `jsonify`, `api_ok`, or `make_response` with JSON payloads. HTML return paths were confirmed by checking for `render_template`. The legacy `main_compat.py` is a pure URL-rule alias layer for backward URL stability and is not counted as an additional surface.

`openapi.json` (`app/blueprints/openapi_api.py::_spec`) is treated as the **declared** mobile API surface. Anything outside it is a candidate for screen-scraping or for promotion to v1.

The full route map referenced below was extracted from the file `app/blueprints/*.py` on the audit date.

## 1. Existing surfaces overview

The backend exposes three logical groups:

| Group | URL prefix | Purpose | Mobile-usable today? |
|---|---|---|---|
| **Mobile JSON v1** | `/api/v1/*` | Purpose-built mobile API. JSON envelope, Bearer auth. | **Yes**, partially (see §2). |
| **Web AJAX JSON** | `/api/live`, `/api/fleet/*`, `/notifications/feed`, `/notifications/log-fragment`, `/notifications/mark-read`, `/admin/support-command-center/*.json`, `/notifications/test*` | JSON endpoints used by the existing web UI (mostly cookie/session-authenticated). | **Partially** — some are reusable, some are admin-only or session-bound (see §2.2 and §3.10). |
| **HTML pages** | `/login`, `/register`, `/dashboard`, `/devices/manage`, `/loads`, `/notifications`, `/account/profile`, `/account/subscription`, `/portal/support`, ... | Server-rendered Jinja templates. Not consumable by mobile. | **No** — explicitly out of scope; mobile must not screen-scrape these. |

## 2. Existing routes usable by mobile

These are the JSON endpoints the Flutter client can adopt **today** without any backend change.

### 2.1 Auth (`/api/v1/auth/*`) — `app/blueprints/mobile_auth_api.py`

| Method | Path | Handler | Notes |
|---|---|---|---|
| POST | `/api/v1/auth/login` | `mobile_login` | Username/email + password → access + refresh tokens. |
| POST | `/api/v1/auth/refresh` | `mobile_refresh` | Refresh token → new access token. 30-day refresh TTL by default. |
| POST | `/api/v1/auth/logout` | `mobile_logout` | Revoke a single refresh token. |
| GET | `/api/v1/auth/me` | `mobile_me` | Current user with `account_restricted` + `can_write` flags. |

Tokens: HMAC-signed via `itsdangerous.URLSafeTimedSerializer` (15-min default access TTL, configurable). Refresh tokens stored hashed in `mobile_refresh_token`. See `app/services/mobile_auth.py`.

### 2.2 Mobile bootstrap & summary (`/api/v1/mobile/*`) — `app/blueprints/mobile_api.py`

| Method | Path | Handler | Notes |
|---|---|---|---|
| GET | `/api/v1/mobile/bootstrap` | `bootstrap` | Returns user, permissions, navigation pages (from `portal_pages`), provider catalog, CSRF token. The single screen-load endpoint after login. |
| GET | `/api/v1/mobile/summary` | `summary` | Active device + latest reading. Today this is **session-derived**: it uses `get_current_device()` which reads `session['current_device_id']`. For mobile (no cookie) this falls back to user-only scope and may not match the desired active device. **Gap** — see §3.1. |
| GET | `/api/v1/mobile/notifications` | `notifications` | Last 30 NotificationEvents for the current user. Lighter than `/api/v1/notifications` and lacks pagination. Use `/api/v1/notifications` for the feed screen. |
| GET | `/api/v1/mobile/health` | `health` | Unauthenticated. Useful for connectivity probing. |

### 2.3 Devices (`/api/v1/devices/*`) — `app/blueprints/mobile_devices_api.py`

| Method | Path | Handler |
|---|---|---|
| GET | `/api/v1/devices` (and `/`) | `devices_list` (paginated) |
| GET | `/api/v1/devices/<int:device_id>` | `device_detail` (device + latest reading) |
| GET | `/api/v1/devices/<int:device_id>/latest` | `device_latest` |
| GET | `/api/v1/devices/<int:device_id>/history` | `device_history` (paginated, ISO date filtering) |
| GET | `/api/v1/devices/<int:device_id>/alerts` | `device_alerts` (server-derived, today: low battery + zero solar) |

Identifiers (`external_device_id`, `device_uid`, `station_id`) are **masked by default** via `mask_identifier`. There is no current `?include_private=1` toggle on the route — it is parameter-supported in `_device_payload` but not exposed.

### 2.4 Notifications (`/api/v1/notifications/*`) — `app/blueprints/mobile_notifications_api.py`

| Method | Path | Handler |
|---|---|---|
| GET | `/api/v1/notifications` (and `/`) | `notification_list` (paginated; `?unread=1` filter) |
| POST | `/api/v1/notifications/mark-read` | `mark_read` (single, list, or all) |
| POST | `/api/v1/notifications/push-tokens` | `register_push_token` (FCM/APNs) |
| DELETE / POST | `/api/v1/notifications/push-tokens` (and `/push-tokens/unregister`) | `unregister_push_token` |

Push tokens stored in `mobile_push_token` (id, user_id, platform, token, token_hash, device_label, app_version, is_active, last_seen_at, revoked_at).

### 2.5 Support (`/api/v1/support/*`) — `app/blueprints/mobile_support_api.py`

| Method | Path | Handler |
|---|---|---|
| GET | `/api/v1/support/cases` | `support_cases` (paginated; `?type=` and `?status=` filters; merges `InternalMailThread` + `SupportTicket`) |
| GET | `/api/v1/support/cases/<kind>/<int:case_id>` | `support_case_detail` (with messages) |
| POST | `/api/v1/support/cases` | `create_support_case` (consumes `support_cases_limit` quota) |
| POST | `/api/v1/support/cases/<kind>/<int:case_id>/reply` | `reply_support_case` |
| POST | `/api/v1/support/cases/<kind>/<int:case_id>/reopen` | `reopen_support_case` |
| GET | `/api/v1/support/canned-replies` | `canned_replies` (admin-gated) |

### 2.6 OpenAPI

- `GET /api/v1/openapi.json` and `GET /api/v1/docs` (HTML, session-bound) — already published.

### 2.7 Web AJAX endpoints that *could* be reused

These return JSON today but were designed for the web UI. They are **session-authenticated** (cookie). Reusing them from mobile is possible only after they accept Bearer tokens via the same `user_from_bearer_or_session()` plumbing the v1 endpoints use. Until then, treat them as web-only.

| Path | File | Why useful |
|---|---|---|
| `/api/live` | `app/blueprints/energy.py:292` | Rich live snapshot incl. `sun_phase`, `weather`, `actual_surplus`, `solar_prediction`. Server-computed values — exactly what mobile should consume rather than recompute. |
| `/api/fleet/select` | `app/blueprints/fleet_api.py:224` | Select active device. |
| `/api/fleet/summary` | `app/blueprints/fleet_api.py:257` | Compact rail data for the multi-device strip. |
| `/api/devices/<id>/live-summary` | `app/blueprints/fleet_api.py:342` | Per-device live snapshot. |
| `/api/fleet/overview` | `app/blueprints/fleet_api.py:405` | Aggregate overview. |
| `/api/devices/<id>/notifications-preview` | `app/blueprints/fleet_api.py:443` | Chip alert badge. |
| `/notifications/feed` | `app/blueprints/notifications_routes.py:564` | Aggregated notification groups (top 5 + unread counts). |
| `/notifications/mark-read` | `app/blueprints/notifications_routes.py:599` | Group/event/all mark-read. |
| `/notifications/log-fragment` | `app/blueprints/notifications_routes.py:203` | Returns rendered HTML fragment — **not** mobile-friendly. |

**Recommendation:** rather than letting mobile call cookie endpoints, lift the relevant payloads (sun phase, weather, solar prediction) into `/api/v1/mobile/summary` so the mobile contract stays clean. See §10.

## 3. Routes that return HTML only (gap surface)

These are the user journeys that have **no JSON equivalent** and that mobile cannot complete today without new endpoints.

### 3.1 Auth / register (HTML-only)

- `GET/POST /login`, `GET/POST /register` — `app/blueprints/auth.py`.
- `GET /register/username-check` (already JSON via `jsonify`) — usable as-is for live username availability checks.
- `POST /logout` — POST form, redirects. Mobile uses `/api/v1/auth/logout` instead.
- Google OAuth (`/auth/google/start`, `/auth/google/callback`) — browser-redirect flow, **not mobile-usable** without a deep-link callback design.

**Mobile gap:** **Register** has no JSON endpoint. Mobile must either (a) post `application/x-www-form-urlencoded` to `/register` and follow the redirect (fragile) or (b) gain a new `POST /api/v1/auth/register`. Option (b) is the contract. See [mobile_api_contract_v1.md §1.5](mobile_api_contract_v1.md#15-post-apiv1authregister-new).

### 3.2 Profile / current user

- `GET/POST /account/profile` — `app/blueprints/devices_routes.py:332`. Renders `account_profile.html`.
- `POST /admin/me/avatar`, `POST /admin/me/avatar/remove` — admin self-only.

**Mobile gap:** No `GET/PATCH /api/v1/profile`, no `POST /api/v1/profile/avatar`. `/api/v1/auth/me` returns a minimal subset (id, username, full_name, email, role, is_admin, is_active, account_restricted) and **omits** phone_country_code, phone_number, country, city, timezone, preferred_language, profile_image_url. These are required for the profile screen.

### 3.3 Devices CRUD (HTML-only)

- `POST /devices/select/<int:device_id>` — sets `session['current_device_id']`. Cookie-only.
- `GET/POST /devices/manage` — list + create.
- `GET/POST /devices/manage/<int:device_id>/edit`.
- `POST /devices/manage/<int:device_id>/toggle`.
- `GET/POST /onboarding`, `POST /onboarding/skip`.

**Mobile gap:** Mobile has **read-only** device endpoints today. Full CRUD (create / edit / delete / toggle / select active) does not exist under `/api/v1/devices/*`.

### 3.4 Loads CRUD (HTML-only)

- `GET/POST /loads` — `app/blueprints/energy.py:1781`. Single endpoint that handles `add`, `toggle`, `delete`, `save_night_limit` actions via a form `action` field.

**Mobile gap:** No JSON equivalent. The route also enforces strict device-scope protection (see v35 §10.18 — cross-device leakage fix) which the new endpoints must honour.

### 3.5 Notification settings

- `GET/POST /notifications` — `app/blueprints/notifications_routes.py:147`. Renders `notifications.html` and saves via `save_notification_settings_from_form` / `save_all_notification_settings_from_form`.
- `GET/POST /channels` — Telegram + SMS channel page.
- `POST /notifications/action` — preview/send a section test.
- `POST /notifications/test`, `POST /notifications/test-section` — test sends.
- `POST /telegram/menu/send` — interactive Telegram menu.
- `GET /alerts` — sync log dump (HTML).

**Mobile gap:** `notifications.html` is **the most complex subscriber surface** (v35 §5.1) and is hard-locked at the save engine. Mobile is **read-only** for settings in MVP (mirror values; no edits). No JSON read endpoint exists for the settings tree.

### 3.6 Telegram / SMS channels

- `GET/POST /channels` — Telegram bot token, SMS API key, webhook controls. HTML-only. Includes destructive operations (delete webhook, set webhook).

**Mobile gap:** Mobile MVP shows **read-only status** of channels (bound? configured? webhook ok?) — no edits, no test sends. This needs a small JSON wrapper.

### 3.7 Subscription / billing

- `GET /account/subscription` — `app/blueprints/billing.py:337`. Plan, days-left, quotas.
- `POST /account/subscription/request-change` — opens a `SupportCase(case_type='plan_change_request')`.

**Mobile gap:** No `GET /api/v1/account/subscription`. The mobile screen needs the plan summary, days-left ring, and quota table. The "request change" flow can reuse `POST /api/v1/support/cases` with the right `category`.

### 3.8 Notification center / mark-read (HTML + JSON mix)

- `GET /notification-center` and `/notifications/center` — HTML.
- `GET /notifications/feed` — JSON (groups, unread counts).
- `POST /notifications/mark-read` — JSON, session-authenticated.

**Mobile gap:** mobile uses `/api/v1/notifications` + `/api/v1/notifications/mark-read` instead. `/notifications/feed` returns aggregated groups (mail / ticket / system) which the v1 path does not provide. Consider lifting the aggregator into `/api/v1/notifications/groups` for the bell-icon experience.

### 3.9 Energy live JSON

- `GET /api/live` — already JSON, but session-auth. Server-computed sun phase, weather, prediction.

**Mobile gap:** This is the cleanest single source for the dashboard. Re-emit the same payload from `/api/v1/mobile/summary` (or a new `/api/v1/mobile/live`) with Bearer auth and **no recomputation** on the client.

### 3.10 Admin-only JSON

These exist under `/admin/support-command-center/*.json` and are admin-gated. Mobile is subscriber-only in MVP — these are **not** mobile candidates.

## 4. Auth / login / register / refresh / logout readiness

| Capability | Endpoint | Status |
|---|---|---|
| Login (username/password) | `POST /api/v1/auth/login` | **Ready** |
| Refresh access token | `POST /api/v1/auth/refresh` | **Ready** |
| Logout (revoke refresh) | `POST /api/v1/auth/logout` | **Ready** |
| Current user (minimal) | `GET /api/v1/auth/me` | **Partial** — missing phone, location, language, avatar URL. See §3.2. |
| Register | — | **Missing** — only HTML POST `/register`. Need `POST /api/v1/auth/register`. |
| Username availability check | `GET /register/username-check` | **Reusable** (returns JSON), but not under `/api/v1/*`. Recommend re-mounting at `GET /api/v1/auth/username-check`. |
| Forgot password | — | **Missing** entirely. Out of MVP. |
| Google OAuth | `GET /auth/google/start` | **Browser-only**. Out of MVP unless Android implements an in-app browser tab + custom callback scheme. |
| Bearer-aware before-request guard | `app/blueprints/auth.py::protect_routes` | **Ready** — already lets `/api/v1/*` (except `/docs`) bypass session redirects so handlers can return precise 401s. |

### Token model (already implemented, `app/services/mobile_auth.py`)

- Access token: HMAC-signed via `itsdangerous`, salt `solardeye-mobile-access-v1`. Default TTL 15 min (`MOBILE_ACCESS_TOKEN_SECONDS`).
- Refresh token: 48-byte URL-safe random, hashed (sha256) and stored in `mobile_refresh_token`. Default TTL 30 days (`MOBILE_REFRESH_TOKEN_DAYS`).
- `user_from_bearer_or_session()` — accepts both Bearer header and Flask session, so v1 endpoints work uniformly from mobile (Bearer) and from the OpenAPI viewer (session).

## 5. Current user / profile / location readiness

Available today via `/api/v1/auth/me`:

```
id, username, full_name, email, role, is_admin, is_active,
account_restricted, restriction_reason, can_write
```

**Missing for the profile screen** (all exist on `AppUser`, just not surfaced):

```
phone_country_code, phone_number, country, city, timezone,
preferred_language, profile_image_url, last_login_at,
oauth_provider, onboarding_completed, onboarding_step
```

**Missing as JSON for write paths:**

- `PATCH /api/v1/profile` (mirror of `POST /account/profile`).
- `POST /api/v1/profile/avatar` (multipart upload, mirror of `/admin/me/avatar`).
- `DELETE /api/v1/profile/avatar`.
- `POST /api/v1/profile/password` (separate from generic profile update so the client can show a dedicated form).

**Location source:** `clock_weather_context.py` already exposes `cwx_user_country`, `cwx_user_city`, `cwx_user_timezone` to templates. The mobile contract should expose the same fields on `/api/v1/profile` and on the bootstrap, so the in-app clock/weather pulls from the same source — **never** GPS or IP geolocation (v35 §10.20).

## 6. Device list and selected device readiness

| Capability | Endpoint | Status |
|---|---|---|
| List devices | `GET /api/v1/devices` | **Ready** |
| Device detail | `GET /api/v1/devices/<id>` | **Ready** |
| Latest reading | `GET /api/v1/devices/<id>/latest` | **Ready** |
| History | `GET /api/v1/devices/<id>/history` | **Ready** (date range, pagination) |
| Derived alerts | `GET /api/v1/devices/<id>/alerts` | **Ready** (basic: battery_low, solar_zero) |
| Select active device | `POST /devices/select/<id>` (cookie) or `POST /api/fleet/select` (cookie) | **Missing for mobile** — needs `POST /api/v1/devices/<id>/select` that updates a per-user preferred-device pointer (and ignores cookie). |
| Create device | `POST /devices/manage` (HTML) | **Missing** — needs `POST /api/v1/devices`. |
| Update device | `POST /devices/manage/<id>/edit` (HTML) | **Missing** — needs `PATCH /api/v1/devices/<id>`. |
| Toggle active | `POST /devices/manage/<id>/toggle` (HTML) | **Missing** — needs `POST /api/v1/devices/<id>/toggle`. |
| Delete device | (no route today) | **Missing** entirely on backend — out of MVP. |
| Multi-device fleet rail | `GET /api/fleet/summary` (cookie) | **Reusable** — could be promoted to `GET /api/v1/devices/fleet/summary`. |

**Selected-device semantics on mobile:** since mobile has no cookie session, the contract should treat the active device as **client state** by default, with an optional server-side preference (`AppUser.preferred_device_id`) that survives reinstalls. This means most endpoints that "use the active device" must accept a `?device_id=` query parameter in the v1 contract (already true for `/api/v1/devices/*`).

`/api/v1/mobile/summary` currently relies on `get_current_device()` which reads from cookie session. For mobile this returns the user's first device. **Recommended fix in v36-α scope:** change `/api/v1/mobile/summary` to honour an explicit `?device_id=` query parameter; if none, fall back to `user.preferred_device_id`, then to first owned device. (No locked surfaces touched.)

## 7. Live dashboard / mobile summary readiness

Available today (`/api/v1/mobile/summary`):

```
device: { id, name, type }
latest: { id, created_at, solar_power, home_load, battery_soc,
          battery_power, grid_power, inverter_power,
          daily_production, monthly_production, total_production,
          status_text }
```

**Missing vs. web `/api/live` (which is what powers the dashboard):**

```
day_phase                 ← already classified server-side
sun_phase                 ← phase + weather icon/label/advice
battery (insights)        ← battery_capacity_kwh, reserve %, runtime estimate
system_state, system_status
weather                   ← icon, condition_ar, temperature, cloud_cover,
                              next_hour, morning, noon, afternoon, timeline,
                              sunset_time, effective_sunset_time
actual_surplus
solar_prediction          ← sunset_time, time_to_full, verdict, advice
```

All of this is **already computed by the server** (`compute_sun_context`, `build_battery_insights`, `build_system_status`, `build_pre_sunset_prediction`, `compute_actual_solar_surplus`). The mobile contract should re-emit the same shape from `/api/v1/mobile/summary` (or a new `/api/v1/mobile/live`). **Do not** recompute on-device.

## 8. Notifications list / settings readiness

| Capability | Endpoint | Status |
|---|---|---|
| Feed (paginated) | `GET /api/v1/notifications?page=&page_size=&unread=` | **Ready** |
| Aggregated groups (mail / ticket / system) with unread counts | `GET /notifications/feed` (cookie) | **Reusable, needs Bearer mount** |
| Mark single / list / all read | `POST /api/v1/notifications/mark-read` | **Ready** |
| Register push token | `POST /api/v1/notifications/push-tokens` | **Ready** |
| Unregister push token | `DELETE /api/v1/notifications/push-tokens` | **Ready** |
| Read settings tree | — | **Missing** — no JSON read endpoint. The mobile MVP screen is **read-only** mirror; needs `GET /api/v1/notifications/settings`. |
| Save settings | `POST /notifications` (HTML, locked engine) | **Out of scope for mobile MVP.** v33-κ deferred plan applies. |
| Test send (Telegram / SMS) | `POST /notifications/test`, `POST /notifications/test-section` (HTML form) | **Out of scope for MVP.** Could be wrapped later. |
| Notification log (per device, paginated) | `GET /notifications/log-fragment` (HTML fragment) | **Not mobile-usable.** Could be lifted to `GET /api/v1/notifications/log` in a follow-up. |

## 9. Telegram / SMS channels readiness

Backend state lives in `Setting` rows (`telegram_bot_token`, `telegram_chat_id`, `telegram_api_url`, `sms_api_url`, `sms_api_key`, `sms_sender`, `sms_recipients`, `notifications_enabled`, etc.). All channel UI today is in `app/blueprints/notifications_routes.py::channels` (HTML).

| Capability | Status |
|---|---|
| Read channel-bound status (Telegram bound? SMS configured? webhook OK?) | **Missing** as JSON — needs `GET /api/v1/channels`. |
| Test Telegram | HTML POST only. Out of scope MVP. |
| Test SMS | HTML POST only. Out of scope MVP. |
| Set / delete Telegram webhook | HTML POST only. **Admin-style operation; do not expose to mobile in MVP.** |
| Per-user Telegram link (`telegram_link_service.py`) | Service exists; admin-only owner_key today. Out of MVP. |

## 10. Loads CRUD readiness

| Capability | Endpoint | Status |
|---|---|---|
| List loads (active device) | `GET /loads` (HTML) | **Missing** as JSON. |
| Add load | `POST /loads` action=add (HTML) | **Missing** as JSON. |
| Toggle load | `POST /loads` action=toggle | **Missing** as JSON. |
| Delete load | `POST /loads` action=delete | **Missing** as JSON. |
| Save night-max-load | `POST /loads` action=save_night_limit | **Missing** as JSON. |

The HTML route already has device-scope protection (v35 §10.18 — cross-device leakage fix and v33-γ ownership checks). Any new JSON endpoint **must reuse the same `_loads_current_scope` semantics** (or factor it into `app/services/`). Specifically:

- `device_id` is mandatory on add (or implicit via `?device_id=`).
- Toggle/delete validate `user_id` AND device scope.
- Aggregate mode (`__all__`) is a web concept; the mobile contract requires explicit `device_id` — no aggregate mode on phone.

## 11. Support tickets / messages readiness

Mature surface — already in `/api/v1/support/*`. Gaps:

| Capability | Status |
|---|---|
| List cases | **Ready** |
| Case detail with thread | **Ready** |
| Create case (mail or ticket) | **Ready** (consumes `support_cases_limit` quota) |
| Reply | **Ready** |
| Reopen | **Ready** |
| Canned-replies | **Admin-only**; subscriber should have **no** access (current behaviour is correct). |
| Attachments (download / upload) | **Missing** for mobile — `/support/attachments/<id>` is GET-only and session-auth (`app/blueprints/support.py:209`). New `POST /api/v1/support/cases/<kind>/<id>/attachments` and `GET .../<attachment_id>` (Bearer) are needed for parity. **Out of MVP** unless the user explicitly requests inline screenshots in support threads. |
| Plan-change request flow | **Ready via** `POST /api/v1/support/cases` with `category=plan_change_request`. |

## 12. Subscription / account readiness

| Capability | Endpoint | Status |
|---|---|---|
| View current subscription / plan / days-left / quota | `GET /account/subscription` (HTML) | **Missing** as JSON. Needs `GET /api/v1/account/subscription`. |
| List active plans | (template inlined) | **Missing** as JSON. Needs `GET /api/v1/account/plans`. |
| Request plan change | `POST /account/subscription/request-change` (HTML) | **Reachable** via `POST /api/v1/support/cases` (mirrors backend behaviour); a dedicated `POST /api/v1/account/subscription/request-change` would be cleaner. |
| Wallet ledger / payments | Admin-only HTML (`/admin/finance`). | **Out of MVP.** |
| Quota status | (template-rendered today) | Should be part of `GET /api/v1/account/subscription` via `quota_summary_rows(...)`. |

## 13. Weather / clock context readiness

Backend has `app/services/weather_service.py` (Open-Meteo, hard-locked) and `app/services/clock_weather_context.py` (profile-driven, no GPS/IP). Currently exposed only as Jinja context vars (`cwx_user_country`, `cwx_user_city`, `cwx_user_timezone`, `cwx_profile_url`).

| Capability | Status |
|---|---|
| Read user-saved location | **Missing** as JSON. Add to `GET /api/v1/auth/me` response or to a dedicated `/api/v1/profile`. |
| Read current weather + sun phase + advice | Computed in `/api/live` (cookie). **Missing** as Bearer JSON. Should be folded into `/api/v1/mobile/summary` payload. |
| Server time / timezone | **Missing** as JSON. Trivial — add `server_time_utc` and `user_timezone` to bootstrap. |

## 14. Security notes

- **Bearer-only endpoints.** `/api/v1/*` (except `/docs`) skip the session-redirect protector and respond with precise `401 auth_required` JSON instead. This is the contract; do not change it.
- **CSRF.** The session-cookie pages enforce CSRF; mobile (Bearer) does not need CSRF tokens. The bootstrap currently exposes `csrf_token` for symmetry — mobile clients should ignore it unless they are also driving a session cookie.
- **Identifier masking.** `mask_identifier` masks `external_device_id`, `device_uid`, `station_id` on device payloads. The mobile contract should keep masking by default; expose unmasked only on explicit `?include_private=1` and only to the device's owner.
- **Sanitisation.** All payloads pass through `sanitize_response_payload`. Keep this in any new endpoint.
- **Rate-limit headers.** `api_responses.py` advertises `X-RateLimit-Limit: 300` per `X-RateLimit-Window: 300` (5-minute) and `X-Content-Type-Options: nosniff`. There is **no enforced rate limiter** today — clients must back off on 429 if/when one is added.
- **Token storage (client side).** `flutter_secure_storage` (Android Keystore). Never put refresh tokens in `SharedPreferences`.
- **TLS.** Backend is fronted by Render (HTTPS). Mobile must refuse plaintext HTTP.
- **Account state.** `/api/v1/auth/me` returns `account_restricted` and `can_write`. The app must respect both — read-only mode when restricted, hide write affordances when `can_write=false`.
- **Permission gating.** `bootstrap.permissions` returns the user's effective permissions (RBAC). Hide screens accordingly.
- **Push tokens.** Tokens are stored hashed; raw token is also stored to allow FCM dispatch. The `mobile_push_token` table includes `is_active` and `revoked_at` — clients should re-register on each cold start to keep `last_seen_at` fresh.
- **Refresh-token scope.** A logout from one device revokes only that device's refresh token (per-row). There is **no global "log out everywhere"** endpoint — out of MVP, but worth flagging.
- **OAuth.** Google/Facebook flows are browser callbacks. Do **not** route them through a mobile WebView without PKCE + a custom redirect scheme — out of MVP.
- **Avatar uploads.** When a JSON `POST /api/v1/profile/avatar` is added, enforce content-type allowlist (`image/png`, `image/jpeg`, `image/webp`), max size, and re-encode server-side. Mirror what `_save_profile_image` does today.

## 15. Suggested API contract

The full per-endpoint contract is in [mobile_api_contract_v1.md](mobile_api_contract_v1.md). High-level shape:

- **Envelope** (already implemented, do not change):
  ```json
  { "ok": true, "data": {...}, "meta": {...}, "errors": [] }
  ```
  Errors:
  ```json
  { "ok": false, "message": "...", "code": "snake_case", "errors": [...] }
  ```
- **Pagination** (already implemented): `?page=&page_size=&limit=`. Response `meta` carries `page, page_size, total, pages, has_next, has_prev`.
- **Filtering**: query params, snake_case.
- **Auth**: `Authorization: Bearer <access_token>`.
- **Locale**: `?lang=ar|en` query param (server already honours this in many routes).
- **Idempotency**: client-supplied `Idempotency-Key` header on POSTs that mutate state (mark-read, support reply, push-token register). **Backend support not present today**; document as a future enhancement.
- **Versioning**: URL-versioned (`/api/v1`). Breaking changes go to `/api/v2`.

## 16. Loading / offline / error states

- **Initial bootstrap on cold start.** Single `GET /api/v1/mobile/bootstrap` call. Cache the response for the session; revalidate on app foreground after > 30 min idle.
- **Stale data badge.** Show "آخر تحديث HH:mm" on every screen that polls. If the last successful poll is > 5 min, show a warning chip; > 30 min, show an offline pill (matches `fleet_api` thresholds).
- **Skeleton placeholders** for first paint. Never spin a blocking spinner over the whole screen after the first render.
- **Optimistic updates** are allowed for mark-read only. Reverse on error.
- **Error envelope translation.** Build a single `ApiError → user message` table keyed by `code` (Arabic + English).
  Known codes today: `auth_required`, `missing_credentials`, `invalid_credentials`, `invalid_refresh_token`, `device_not_found`, `invalid_date_range`, `support_case_not_found`, `support_case_closed`, `missing_support_fields`, `missing_reply_body`, `missing_push_token`, `quota_exceeded`, `admin_required`.
- **Empty states.** Match v35 §7.2 — icon + one short Arabic line + optional CTA. No 400-px blank rectangles.
- **Network failure.** Always allow a "retry" affordance. Never crash the screen.

## 17. Arabic RTL mobile design notes

Direct application of v35 §3, §9 to the Flutter target:

1. **Default direction RTL.** `MaterialApp(locale: const Locale('ar'))`. Per-widget overrides for LTR-only tokens (DEYE, Asia/Hebron, +970 numbers).
2. **Type stack.** Bundle Cairo (Arabic) + system fallback for English / digits. Weights 400 / 600 / 800 / 900.
3. **Numerals.** Western 0-9 only. Apply `font-feature-settings: "tnum"` (Flutter: `fontFeatures: [FontFeature.tabularFigures()]`) on every numeric label.
4. **Form-field height.** 42 dp standard. 32 dp icon toggles. Match v35 §4.1 exactly.
5. **Helper text.** Single helper per field (Material `helperText`). Never combine with a popover. Matches v35 §10.1.
6. **Section tones.** Mirror the `tone-*` palette (`tone-day`, `tone-night`, `tone-sunset`, `tone-weather`, `tone-battery`, `tone-load`, `tone-report`, `tone-discharge`, `tone-content`, `tone-critical`, `tone-rules`) as Material `surfaceTint` colors. One palette source = one Dart constant file.
7. **Phone display.** `+970 | 599043337` — separator widget, never a typed character (matches v35 §3.6).
8. **Punctuation.** Arabic comma `،` for prose. ASCII `,` only inside LTR runs (e.g., timezones, `08:00,12:00`).
9. **No marketing hero blocks on mobile.** Match v35 §9.4 — denser than desktop, not airier.
10. **Compact icon-card pattern.** Notification routing chips (Telegram ✈ / SMS ✉) translate directly to a 3-column grid. Single shared legend chip on top of the section, exactly as on web (v35 §5.2).

## 18. What must not be touched in web

Hard locks reaffirmed from v35 §11 / Appendix D. The mobile audit and the eventual mobile build never modify any of these:

- **Flow Graph** template + JS + SVG (md5 `56124a8799a3bb800231d99d83f6d616`, 7,970 bytes).
- **`dashboard.html`** — wrappers may be added *above* (clock/weather, fleet rail, scope hint) for web purposes only; mobile work does not need to touch this file at all.
- **`_live_fleet_rail.html`** — fleet rail partial.
- **`app/scheduler/*`** — scheduler fan-out + cron logic.
- **`app/services/notifications/*`** — dispatch + dedup.
- **`app/blueprints/notifications.py::save_notification_settings_from_form`** — settings save engine.
- **`app/services/weather_service.py`** — Open-Meteo backend.
- **`app/blueprints/reports.py`** — PDF export pipeline.
- **The `Setting` model is global.** Mobile UI must not claim per-device isolation (v35 §10.14).
- **No GPS, no IP geolocation** on the user-portal surfaces (v35 §10.20). The mobile app must not request location permissions for clock / weather purposes either.
- **Web URL stability.** `main_compat.py` exists to keep legacy URLs working; do not delete those aliases.
- **Sidebar partial** branches on `g.is_admin` only (v35 §10.21). Mobile does not consume the sidebar; web side stays untouched.
- **Notification settings name=** attributes are sacred (v35 §11 rule 6 / 16). Mobile does not POST to `/notifications` form, so this is automatically respected — but any future "settings write from mobile" must come via a new JSON endpoint that calls the same save engine, not a re-implementation.

---

*End of API readiness audit. The corresponding contract is [mobile_api_contract_v1.md](mobile_api_contract_v1.md).*
