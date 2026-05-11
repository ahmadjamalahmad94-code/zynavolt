# SolarDeye Mobile API Contract — v1 (proposed)

> **Task name:** `v36-mobile-full-client-api-audit`
> **Date:** 2026-05-10
> **Companion docs:** [mobile_mvp_plan.md](mobile_mvp_plan.md), [api_readiness_audit.md](api_readiness_audit.md)
> **Status:** Proposed contract. Endpoints marked **EXISTS** are live today. Endpoints marked **NEW** are planned and require backend implementation in a separate scoped task — they are **not** built by this audit. Endpoints marked **REUSE** are already JSON but currently session-bound and need a Bearer mount before mobile can use them.

---

## 0. Conventions

### 0.1 Base

- Base URL: `https://<backend-host>/api/v1` (production), `http://localhost:5000/api/v1` (local dev).
- All paths in this document are relative to that base.
- All endpoints accept `?lang=ar|en` for translatable copy; default `ar`.
- All endpoints include a `Locale: ar|en` query echo in `meta` when applicable.

### 0.2 Authentication

- Bearer token in `Authorization: Bearer <access_token>`.
- Access tokens expire in **15 min** (configurable via `MOBILE_ACCESS_TOKEN_SECONDS`).
- Refresh tokens are valid for **30 days** (configurable via `MOBILE_REFRESH_TOKEN_DAYS`).
- On `401 auth_required` for any non-auth endpoint, the client refreshes once via `POST /auth/refresh`, then replays the original request, then surfaces the error if it still fails.
- The same handlers also accept Flask session cookies for the OpenAPI browser viewer; mobile must always send Bearer.

### 0.3 Response envelope

Success:

```json
{
  "ok": true,
  "data": { ... },
  "meta": { ... },
  "errors": [],
  "message": "..."          // optional
}
```

Error:

```json
{
  "ok": false,
  "message": "Human-readable error in current locale.",
  "code": "snake_case_error_code",
  "errors": [ "optional", "field-level", "details" ]
}
```

Every response also carries:

- `X-RateLimit-Limit: 300`
- `X-RateLimit-Window: 300` (5-minute window)
- `X-Content-Type-Options: nosniff`

Clients should respect 429 if/when a limiter is enforced.

### 0.4 Pagination

Query: `?page=<int, default 1>&page_size=<int, default 30, max 100>` (`limit` is also accepted as a `page_size` alias).

Meta:

```json
"meta": {
  "page": 1,
  "page_size": 30,
  "total": 142,
  "pages": 5,
  "has_next": true,
  "has_prev": false
}
```

### 0.5 Datetimes

All timestamps are UTC ISO-8601 strings (`2026-05-10T08:14:32`). Server is naive UTC; clients localise to `user.timezone`.

### 0.6 Standard error codes

`auth_required`, `missing_credentials`, `invalid_credentials`, `invalid_refresh_token`, `device_not_found`, `invalid_date_range`, `support_case_not_found`, `support_case_closed`, `missing_support_fields`, `missing_reply_body`, `missing_push_token`, `quota_exceeded`, `admin_required`, plus future: `validation_failed`, `rate_limited`, `forbidden`, `conflict`.

### 0.7 Headers the client always sends

- `Authorization: Bearer <token>` (when authenticated).
- `Accept: application/json`.
- `Accept-Language: ar` or `en` (echoed by server for telemetry).
- `X-App-Version: <semver>` (telemetry; backend ignores gracefully).
- `X-App-Platform: android` (telemetry).

---

## 1. Auth

### 1.1 `POST /auth/login` — **EXISTS**

Body:

```json
{ "username": "ahmad", "password": "...", "device_label": "Pixel 8" }
```

Response 200:

```json
{
  "ok": true,
  "data": {
    "access_token": "...",
    "token_type": "Bearer",
    "expires_in": 900,
    "account_restricted": false,
    "restriction_reason": "",
    "restriction_message": "",
    "can_write": true,
    "user": { "id": 7, "username": "ahmad", "full_name": "...", "role": "user", "is_admin": false, "is_active": true },
    "refresh_token": "...",
    "refresh_expires_in_days": 30
  },
  "meta": { "api_version": "v1" },
  "errors": []
}
```

Errors: `missing_credentials` 400, `invalid_credentials` 401.

### 1.2 `POST /auth/refresh` — **EXISTS**

Body: `{ "refresh_token": "..." }`. Response: same shape as login but **without** a new refresh token.
Errors: `invalid_refresh_token` 401.

### 1.3 `POST /auth/logout` — **EXISTS**

Body: `{ "refresh_token": "..." }`. Response: `{"ok": true, "data": {"revoked": true}, ...}`.

### 1.4 `GET /auth/me` — **EXISTS** (needs enrichment)

Today returns `id, username, full_name, email, role, is_admin, is_active, account_restricted, restriction_reason, can_write`.

**Proposed enrichment** (additive only, breaks no client):

```json
{
  "id": 7,
  "username": "ahmad",
  "full_name": "...",
  "email": "...",
  "phone_country_code": "+970",
  "phone_number": "599...",
  "country": "...",
  "city": "...",
  "timezone": "Asia/Hebron",
  "preferred_language": "ar",
  "profile_image_url": "/uploads/avatars/...",
  "role": "user",
  "is_admin": false,
  "is_active": true,
  "account_restricted": false,
  "restriction_reason": "",
  "can_write": true,
  "onboarding_completed": true,
  "last_login_at": "2026-05-10T07:00:00"
}
```

### 1.5 `POST /auth/register` — **NEW**

Mirror of HTML `POST /register`. Body uses the same field names as the HTML form so backend reuse is trivial:

```json
{
  "username": "ahmad",
  "full_name": "أحمد",
  "email": "ahmad@example.com",
  "password": "...",
  "confirm_password": "...",
  "country_code": "PS",
  "country": "Palestine",
  "city": "Hebron",
  "timezone": "Asia/Hebron",
  "phone_country_code": "+970",
  "phone_number": "599...",
  "preferred_language": "ar",
  "has_energy_system": "yes",
  "preferred_device_type": "deye",
  "next_step": "setup"
}
```

Response 201: same envelope as `/auth/login` (creates user, signs in, returns tokens).
Errors: `validation_failed` 400 with `errors: [{field, code, message}]`; `username_taken` 409; `email_taken` 409; `weak_password` 400.

### 1.6 `GET /auth/username-check?username=ahmad` — **REUSE**

Already returns JSON at `/register/username-check`. Should be re-mounted (or proxied) at `/api/v1/auth/username-check` for consistency.

### 1.7 Forgot password — **OUT OF MVP**

No backend route exists. Out of v36 scope.

---

## 2. Bootstrap & app shell

### 2.1 `GET /mobile/bootstrap` — **EXISTS** (needs minor enrichment)

Today:

```json
{
  "version": "10.1",
  "csrf_token": "...",
  "user": { "id": 7, "username": "...", "full_name": "...", "role": "user", "role_label": "..." },
  "permissions": { "can_manage_devices": true, ... },
  "navigation": [ { "key": "...", "endpoint": "...", "label": "...", "icon": "...", "group": "...", "order": 100 } ],
  "providers": [ { "code": "deye", "name": "Deye", "auth_mode": "...", "category": "...", "status": "..." } ]
}
```

**Proposed additions (additive):**

```json
{
  "server_time_utc": "2026-05-10T08:00:00",
  "user_timezone": "Asia/Hebron",
  "user_language": "ar",
  "user_country": "Palestine",
  "user_city": "Hebron",
  "active_device_id": 12,
  "feature_flags": {
    "can_manage_devices": true,
    "can_use_telegram": true,
    "can_use_sms": true,
    "can_view_diagnostics": false
  }
}
```

`active_device_id` is the resolved active-device id (from `preferred_device_id` → first owned). Mobile should treat it as a hint and persist its own client-side selection.

### 2.2 `GET /mobile/health` — **EXISTS**

Unauthenticated. Useful for connectivity probing in the splash screen.

---

## 3. Profile

### 3.1 `GET /profile` — **NEW** (alias of enriched `/auth/me`)

Same payload as §1.4. Convenience separation so the client can refetch profile alone after a write.

### 3.2 `PATCH /profile` — **NEW**

Body (all fields optional; only sent fields are written):

```json
{
  "username": "...",
  "full_name": "...",
  "email": "...",
  "phone_country_code": "+970",
  "phone_number": "599...",
  "country": "...",
  "city": "...",
  "timezone": "Asia/Hebron",
  "preferred_language": "ar"
}
```

Response 200: enriched user payload.
Errors: `validation_failed` 400, `username_taken` 409, `email_taken` 409.

### 3.3 `POST /profile/password` — **NEW**

```json
{ "current_password": "...", "new_password": "...", "confirm_password": "..." }
```

Response: `{ "ok": true, "data": { "changed": true } }`.
Errors: `invalid_current_password` 401, `weak_password` 400, `password_mismatch` 400.

### 3.4 `POST /profile/avatar` — **NEW**

Multipart `multipart/form-data` with `file=<image>`. Allow `image/png`, `image/jpeg`, `image/webp`. Max 5 MB. Server re-encodes.
Response: `{ "ok": true, "data": { "profile_image_url": "/uploads/avatars/..." } }`.

### 3.5 `DELETE /profile/avatar` — **NEW**

Response: `{ "ok": true, "data": { "profile_image_url": null } }`.

---

## 4. Devices

### 4.1 `GET /devices` — **EXISTS**

Paginated list. Item shape:

```json
{
  "id": 12,
  "name": "...",
  "device_type": "deye",
  "api_provider": "deye",
  "connection_status": "ok",
  "last_connected_at": "2026-05-10T07:50:00",
  "is_active": true,
  "plant_name": "...",
  "timezone": "Asia/Hebron",
  "identifiers": {
    "external_device_id": "ABC***",
    "device_uid": "DEY***",
    "station_id": "ST***"
  }
}
```

### 4.2 `GET /devices/<id>` — **EXISTS**

Returns `{ "device": {...}, "latest": {...full Reading...} }`.

### 4.3 `GET /devices/<id>/latest` — **EXISTS**

Full Reading payload.

### 4.4 `GET /devices/<id>/history?from=&to=&page=&page_size=` — **EXISTS**

ISO-8601 dates, default last 7 days.

### 4.5 `GET /devices/<id>/alerts` — **EXISTS**

Server-derived alerts. Today: `battery_low`, `solar_zero`. Schema:

```json
{ "items": [ { "level": "warning|info|danger", "key": "...", "message": "..." } ] }
```

### 4.6 `POST /devices/<id>/select` — **NEW**

Sets `AppUser.preferred_device_id` to `<id>` for the current user (after ownership check). Replaces the cookie-based `/devices/select/<id>`.
Response: `{ "ok": true, "data": { "preferred_device_id": 12 } }`.
Errors: `device_not_found` 404, `forbidden` 403.

### 4.7 `POST /devices` — **NEW**

Mirrors web "add device" form. Body:

```json
{
  "name": "...",
  "device_type": "deye",
  "api_provider": "deye",
  "api_base_url": "...",
  "external_device_id": "...",
  "device_uid": "...",
  "station_id": "...",
  "plant_name": "...",
  "timezone": "Asia/Hebron",
  "auth_mode": "wizard|config|api_key",
  "credentials": { "deye_email": "...", "deye_password": "..." },
  "notes": "..."
}
```

Response 201: full device payload (with **unmasked** identifiers, since the caller just supplied them).
Errors: `validation_failed` 400, `device_uid_conflict` 409.

### 4.8 `PATCH /devices/<id>` — **NEW**

Same fields as §4.7, all optional. Response: full device payload.

### 4.9 `POST /devices/<id>/toggle` — **NEW**

Toggle `is_active`. Response: `{ "ok": true, "data": { "id": 12, "is_active": false } }`.

### 4.10 `GET /devices/fleet/summary` — **REUSE**

Lift `app/blueprints/fleet_api.py::api_fleet_summary` into v1 with Bearer auth. Returns the compact rail snapshot used on web (status, latest, icon, last_seen_at, age_seconds).

### 4.11 `GET /devices/<id>/live-summary` — **REUSE**

Lift `fleet_api.py::api_device_live_summary` into v1 with Bearer auth.

---

## 5. Loads

All endpoints require `device_id` either in the path or as a query parameter. There is no aggregate "all devices" mode on mobile.

### 5.1 `GET /loads?device_id=<int>` — **NEW**

```json
{
  "items": [
    { "id": 1, "name": "Fridge", "power_w": 150, "priority": 1, "is_enabled": true, "device_id": 12, "created_at": "..." }
  ],
  "device_id": 12,
  "night_max_load_w": 500
}
```

### 5.2 `POST /loads?device_id=<int>` — **NEW**

```json
{ "name": "Fridge", "power_w": 150, "priority": 1 }
```

Response 201: load payload.
Errors: `validation_failed` 400, `device_not_owned` 403.

### 5.3 `POST /loads/<load_id>/toggle` — **NEW**

Body none. Response: load payload with toggled `is_enabled`.
Errors: `load_not_found` 404 (also returned if the row does not belong to the caller — never leak existence).

### 5.4 `DELETE /loads/<load_id>` — **NEW**

Response: `{ "ok": true, "data": { "deleted": true } }`.

### 5.5 `POST /loads/settings/night-max` — **NEW**

Body: `{ "night_max_load_w": 500 }`. Persists to the global `Setting` row `night_max_load_w` (matches current web semantics — value is global, not per-device).
Response: `{ "ok": true, "data": { "night_max_load_w": 500 } }`.
The mobile UI must label this as global until v33-κ (per-device settings phase) ships.

---

## 6. Notifications

### 6.1 `GET /notifications?page=&page_size=&unread=1` — **EXISTS**

Item shape:

```json
{
  "id": 88,
  "type": "support",
  "source_type": "ticket",
  "source_id": 12,
  "title": "...",
  "message": "...",
  "url": "/portal/support",
  "status": "new|delivered|read",
  "is_read": false,
  "created_at": "...",
  "read_at": null
}
```

### 6.2 `POST /notifications/mark-read` — **EXISTS**

Body: `{ "ids": [88, 89] }` or `{}` (empty body marks all unread for the user).
Response: `{ "ok": true, "data": { "changed": 2 } }`.

### 6.3 `POST /notifications/push-tokens` — **EXISTS**

Body:

```json
{
  "token": "<FCM token>",
  "platform": "android",
  "device_label": "Pixel 8",
  "app_version": "1.0.0"
}
```

Response: `{ "ok": true, "data": { "registered": true, "platform": "android" } }`.

### 6.4 `DELETE /notifications/push-tokens` (also `POST /push-tokens/unregister`) — **EXISTS**

Body: `{ "token": "..." }`.
Response: `{ "ok": true, "data": { "unregistered": true } }`.

### 6.5 `GET /notifications/groups` — **NEW** (lift from `/notifications/feed`)

Aggregated mail / ticket / system groups for the bell-icon UI. Mirror of `_aggregated_notification_groups` payload, with Bearer auth.

```json
{
  "items": [ { "kind": "ticket|message|system", "key": "...", "subject": "...", "status": "...", "unread": 3, "last_at": "..." } ],
  "unread_total": 7,
  "unread_mail": 4,
  "unread_ticket": 3
}
```

### 6.6 `GET /notifications/settings` — **NEW** (read-only)

Returns the global notification settings tree as a flat key/value JSON object derived from the `Setting` table. Mobile MVP screen renders read-only mirror with a "Global settings — managed on web" banner.

```json
{
  "global": { "notifications_enabled": true },
  "channels": { "telegram_bound": true, "sms_configured": false },
  "periodic_day": { "enabled": true, "interval_minutes": 60, "channel": "telegram", ... },
  "periodic_night": { ... },
  "pre_sunset": { ... },
  "weather": { ... },
  "battery_test": { ... },
  "loads": { ... },
  "report": { ... },
  "discharge": { ... },
  "critical_sms": { ... },
  "thresholds": { "charge": [...], "discharge": [...], "night_load": [300, 400, 500] }
}
```

### 6.7 `GET /notifications/log?device_id=&page=` — **NEW** (lift from `/notifications/log-fragment`)

Paginated `NotificationLog` rows scoped to user / device. Mirror of the existing fragment but as JSON.

---

## 7. Channels (Telegram / SMS)

### 7.1 `GET /channels` — **NEW** (read-only)

```json
{
  "telegram": {
    "bound": true,
    "chat_id_present": true,
    "webhook_url": "https://.../telegram/webhook",
    "webhook_status": "ok|stale|missing",
    "last_error": null
  },
  "sms": {
    "configured": true,
    "sender": "...",
    "recipients_count": 2
  }
}
```

### 7.2 Test sends — **OUT OF MVP**

`POST /channels/test/telegram`, `POST /channels/test/sms` are deferred. The current web routes are HTML POSTs and trigger real send-side effects; mobile MVP does not expose them.

---

## 8. Support

### 8.1 `GET /support/cases?type=&status=&page=&page_size=` — **EXISTS**

### 8.2 `GET /support/cases/<kind>/<int:case_id>` — **EXISTS**

Where `kind` ∈ `{message, mail, ticket}`.

### 8.3 `POST /support/cases` — **EXISTS**

Body:

```json
{
  "type": "message|ticket",
  "subject": "...",
  "body": "...",
  "priority": "low|normal|high",
  "category": "general|support|plan_change_request",
  "related_device_id": 12
}
```

Response 201: case payload with messages.
Errors: `missing_support_fields` 400, `quota_exceeded` 429.

### 8.4 `POST /support/cases/<kind>/<int:case_id>/reply` — **EXISTS**

Body: `{ "body": "...", "status": "open|resolved|closed" }`. `status` is honoured only for admins.
Errors: `support_case_not_found` 404, `support_case_closed` 409, `missing_reply_body` 400.

### 8.5 `POST /support/cases/<kind>/<int:case_id>/reopen` — **EXISTS**

### 8.6 `GET /support/canned-replies` — **EXISTS** (admin only)

### 8.7 Attachments — **OUT OF MVP**

`GET /support/attachments/<id>` exists today as session-auth. A Bearer-authenticated mirror plus `POST /support/cases/<kind>/<id>/attachments` (multipart) is a v36-δ phase item.

---

## 9. Account / subscription

### 9.1 `GET /account/subscription` — **NEW**

```json
{
  "tenant": { "id": 3, "display_name": "...", "status": "active" },
  "plan": { "id": 2, "code": "starter", "name_ar": "...", "name_en": "...", "price": 5.0, "currency": "USD", "duration_days_default": 30, "max_devices": 2 },
  "subscription": { "id": 11, "status": "active", "starts_at": "...", "ends_at": "...", "trial_ends_at": null },
  "days_left": 14,
  "pct_left": 47,
  "quotas": [
    { "key": "devices_limit", "label": "Devices", "limit_value": 2, "used_value": 1, "is_unlimited": false, "status": "active" }
  ],
  "pending_change_request": { "id": 99, "subject": "...", "created_at": "..." }
}
```

### 9.2 `GET /account/plans` — **NEW**

```json
{
  "items": [
    { "id": 1, "code": "free", "name_ar": "...", "name_en": "...", "price": 0, "currency": "USD", "max_devices": 1, "features": { "can_manage_devices": true, ... } }
  ]
}
```

### 9.3 `POST /account/subscription/request-change` — **NEW** (or use §8.3)

Convenience wrapper that creates a `SupportCase(case_type='plan_change_request')` for the current user with a target `plan_id` and optional `message`. Response: `{ "ok": true, "data": { "case_id": 99 } }`.

The same effect can be achieved via `POST /support/cases` with `category=plan_change_request`; the dedicated endpoint exists purely so the mobile screen does not need to know that internal mapping.

---

## 10. Live snapshot (richer dashboard payload)

### 10.1 `GET /mobile/summary?device_id=<int>` — **EXISTS** (needs enrichment)

Today returns minimal `{device, latest}`. **Proposed enriched payload** (mirrors the server-computed `/api/live` shape, no client-side recomputation):

```json
{
  "device": { "id": 12, "name": "...", "type": "deye", "is_active": true, "connection_status": "ok", "last_seen_at": "2026-05-10T08:14:00", "age_seconds": 60, "status": "online" },
  "latest": { ... full Reading payload as today ... },
  "battery": { "capacity_kwh": 5, "reserve_percent": 20, "soc_percent": 78, "runtime_estimate_minutes": 240 },
  "system_status": { "title": "...", "level": "ok|warn|critical", "message": "..." },
  "day_phase": { "phase": "...", "icon": "...", "label_ar": "...", "label_en": "..." },
  "sun_phase": { "phase": "...", "icon": "...", "label_ar": "...", "label_en": "...", "is_day_for_production": true, "is_night": false, "weather_icon": "...", "weather_label": "...", "weather_advice": "...", "weather_advice_level": "info|warn" },
  "weather": { "icon": "...", "condition_ar": "...", "temperature": 23.5, "cloud_cover": 30, "next_hour": "...", "morning": "...", "noon": "...", "afternoon": "...", "timeline": [...], "sunset_time": "18:42", "effective_sunset_time": "18:30" },
  "actual_surplus": 1240,
  "solar_prediction": { "sunset_time_label": "06:42 PM", "remaining_hours_text": "...", "time_to_full_text": "...", "verdict": "...", "will_full_before_sunset": true, "advice": "...", "weather_advice": "..." }
}
```

When `device_id` is omitted, the server uses `AppUser.preferred_device_id`, then the user's first owned active device.

### 10.2 `GET /mobile/notifications` — **EXISTS**

Compatibility shim returning the latest 30 NotificationEvents. Use `/notifications` for the paginated feed; this endpoint is only kept so existing `bootstrap`-driven badges keep working.

---

## 11. Push delivery contract

The mobile client must:

1. Acquire FCM token on first run (and after each cold start).
2. `POST /notifications/push-tokens` with `token`, `platform=android`, `device_label`, `app_version`.
3. Re-register on token rotation (Firebase callback).
4. `DELETE /notifications/push-tokens` on logout / account switch.
5. Handle incoming FCM payloads as:

   ```json
   {
     "notification": { "title": "...", "body": "..." },
     "data": {
       "kind": "support|ticket|message|system|battery|weather|...",
       "source_type": "...",
       "source_id": "12",
       "url": "/portal/support",
       "event_id": "88"
     }
   }
   ```

   The `url` field is the in-app deep-link target; the `go_router` table maps the existing web URLs to mobile screens.

Server-side delivery wiring is out of this contract's scope.

---

## 12. Idempotency, retries, and ordering

- **Read endpoints** are safe to retry freely. Cache headers are not currently set; clients should rely on freshness conventions (poll cadence in §10).
- **Write endpoints** are idempotent for: `mark-read`, `push-tokens` (register/unregister), `select` device, `toggle` load. Retrying the same payload yields the same end state.
- **Non-idempotent writes**: `support/cases` create + reply (creates a new row each time). The client should debounce the submit button and show a pending state.
- **Future enhancement.** Add `Idempotency-Key` header support on non-idempotent POSTs. **Not implemented today.** Document only.

---

## 13. Privacy and data minimisation

- Device identifiers (`external_device_id`, `device_uid`, `station_id`) are masked by default. Only the device's owner can see them unmasked, and only via an explicit `?include_private=1` query param. **Not currently exposed**; add when needed.
- User `email` is returned to the user themself only.
- Notification payloads pass through `sanitize_response_payload` which strips known sensitive markers.
- Bearer tokens never appear in any response body.
- Mobile clients must not log full Bearer tokens or refresh tokens; truncate to last 6 chars in any debug build log.

---

## 14. What this contract does NOT cover

- Admin / staff endpoints (subscriber app only).
- Web AJAX endpoints used to drive Jinja templates (`/notifications/log-fragment`, etc.) — see audit §2.7 for the reuse list, but mobile must consume only `/api/v1/*`.
- Reports, statistics charts, PDF exports — out of MVP.
- Channel test sends, Telegram interactive menu, webhook controls — admin-style; out of MVP.
- Wallet / finance / payments — admin-only.
- Per-device notification settings — deferred (v33-κ schema work).
- iOS-specific endpoints — none expected.

---

## 15. Open questions for backend implementation

(Answered separately from the mobile work, in scoped backend tasks.)

1. Should `/api/v1/auth/register` reuse the existing `/register` handler verbatim, or is a thin wrapper preferred for cleaner JSON validation errors? (Recommend wrapper: extract validation into a service function used by both surfaces.)
2. For `POST /api/v1/devices/<id>/select`, should we also persist the selected provider/timezone overrides, or only update `preferred_device_id`? (Recommend: only `preferred_device_id`; provider/timezone live on the device row itself.)
3. Should `/api/v1/notifications/settings` (read-only) be derived from `Setting.query.all()` filtered by a known key prefix, or is a curated whitelist preferable? (Recommend whitelist — avoids leaking secret keys like `telegram_bot_token` into the mobile payload.)
4. For `POST /api/v1/profile/avatar`, should the upload reuse `_save_profile_image` directly, or move it to a service? (Recommend service extraction.)

---

*End of mobile API contract v1. Backend implementation of `NEW` and `REUSE` items is out of scope for `v36-mobile-full-client-api-audit` and must each be a separate scoped task.*
