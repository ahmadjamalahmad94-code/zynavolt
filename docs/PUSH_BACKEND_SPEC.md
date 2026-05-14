# Push Notifications — Backend Spec (v101)

**Status:** spec only — no backend code has been written yet.
**Audience:** the person (or LLM) who implements this on
`C:\Users\Ahmad\Desktop\solardeya\` (Flask + SQLAlchemy +
PostgreSQL on Render).
**Source of truth:** this document. The mobile half is already
shipped (`F:\solardeya-mobile` commits `b296ed9`, `fa20435`,
`931c3fe`). When the spec and the mobile code disagree, fix the
spec first then re-review.

---

## 0. TL;DR

The mobile app already gets an FCM token at launch. We need the
backend to:

1. Accept the token over a new authenticated endpoint and store it.
2. When a notification rule fires (battery low, day deficit, etc.),
   *also* send an FCM push to every active token belonging to the
   user — alongside the existing Telegram / SMS dispatch.

A `MobilePushToken` model **already exists** in
`app/models.py:512`. Most of Phase A.8 is just wiring the endpoint
and a thin Firebase Admin SDK adapter.

---

## 1. Goal

End-to-end story from the user's perspective:

* User installs Zynavolt → first launch → Android prompts
  "Allow Zynavolt to send notifications?" → user taps Allow.
* The mobile `PushService` fetches an FCM token from Google and
  POSTs it to the backend.
* Backend stores it in `mobile_push_token`, scoped to the
  authenticated `AppUser`, deduped by `token_hash`.
* Hours later, the user's battery hits 15% and the existing
  `dispatch_notification(...)` runs. Today it fans out to Telegram
  and SMS. After this work it *also* fans out to FCM, hitting every
  active token for that user.
* The owner can see push deliveries in the existing
  `notification_log` table (channel = `'push'`).
* On the device, the OS shows the system notification. Tap → opens
  the app (deep linking is Phase D, out of scope here).

Non-goals for this spec:
* iOS / APNs (Android-only for now).
* Per-rule push toggles in Settings UI (Phase D).
* Background data-only messages (we send `notification` payloads
  only, so Android draws the system tray entry automatically).
* Rich notifications (images, action buttons).
* Topic-based broadcasting — every send is per-user-tokens.

---

## 2. Database

### 2.1 Existing model — DO NOT recreate

`app/models.py:512-526` already declares:

```python
class MobilePushToken(db.Model):
    __tablename__ = 'mobile_push_token'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('app_user.id'),
                        nullable=False, index=True)
    platform = db.Column(db.String(30), nullable=False,
                         default='android', index=True)
    token = db.Column(db.Text, nullable=False)
    token_hash = db.Column(db.String(128), unique=True,
                           nullable=False, index=True)
    device_label = db.Column(db.String(160), nullable=True)
    app_version = db.Column(db.String(60), nullable=True)
    is_active = db.Column(db.Boolean, default=True, nullable=False,
                          index=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow,
                           index=True)
    last_seen_at = db.Column(db.DateTime, nullable=True, index=True)
    revoked_at = db.Column(db.DateTime, nullable=True, index=True)
```

**Implementer task:** verify whether any code already references this
model. Grep `MobilePushToken` across `app/`. If references exist,
follow the existing pattern; if not, this is the first wiring.

### 2.2 New columns? — none required

The existing schema covers everything we need. Specifically:
* `token_hash` — SHA-256 hex of `token` lets us upsert by hash
  without putting the full token in an index.
* `is_active` + `revoked_at` — soft-delete on logout / 404 from
  Google ("UNREGISTERED" response means the install is gone).
* `last_seen_at` — bumped on every successful POST so we can prune
  tokens that haven't been re-registered in N days.
* `device_label` + `app_version` — optional metadata so the user's
  notification settings page (Phase D) can show "Pixel 7 — v1.2.3".

### 2.3 No companion log table needed

`NotificationLog` (`app/models.py:190-203`) already has a `channel`
column with default `'telegram'`. Reuse it for push by passing
`channel='push'` to `log_notification(...)`.

### 2.4 Migration

The repo does **not** use Alembic or Flask-Migrate. Schema is
created via `db.create_all()` at app startup
(`app/__init__.py:185-187`), with a `_migrate_database()` helper
right after for any post-create touch-ups.

Since `MobilePushToken` already exists in the model file:

* On a fresh DB → `create_all()` will create the table at boot.
* On the existing production DB on Render → the table may not yet
  exist if `MobilePushToken` was added to `models.py` after the
  last deploy. Verify with the implementer: if it isn't there,
  *no migration script is needed* — `create_all()` is idempotent
  and will create missing tables on the next deploy.

If columns ever need to be added later, follow the existing
`_migrate_database()` pattern (raw SQL `ALTER TABLE ... ADD COLUMN
IF NOT EXISTS ...` against the bound engine).

---

## 3. Endpoints

Two new endpoints under the existing mobile blueprint
(`app/blueprints/mobile_api.py`).

### 3.1 `POST /api/mobile/account/push-token`

Register or refresh an FCM token for the authenticated user.

**Auth:** Bearer token, identical to every other `/api/mobile/*`
endpoint. Use `user_from_bearer_or_session()` from
`app/services/mobile_auth.py:102`. Return 401 if it returns `None`
or if `user.is_admin` is true (admins don't carry push tokens).

**Request body (JSON):**

```json
{
  "token": "<full FCM registration token, ~150-200 chars>",
  "platform": "android",
  "device_label": "Pixel 7 (optional)",
  "app_version": "1.0.0+1 (optional)"
}
```

* `token` (required, str) — the full FCM token from
  `FirebaseMessaging.instance.getToken()`.
* `platform` (required, str) — `"android"` for now. Validate
  against `{"android", "ios"}` so iOS is a one-line addition later.
* `device_label` (optional, str ≤ 160) — display string for the
  Settings → Devices list later.
* `app_version` (optional, str ≤ 60) — `pubspec.yaml`'s `version:`
  field, sent as-is.

**Behaviour:**

```
hash = sha256(token).hexdigest()
row  = MobilePushToken.query.filter_by(token_hash=hash).first()

if row:
    # Same install re-registering, or a token that survived a
    # logout. Bind it to the current user (in case the device
    # changed accounts) and bump last_seen_at.
    row.user_id      = user.id
    row.token        = token        # token sometimes mutates length
    row.platform     = platform
    row.device_label = device_label or row.device_label
    row.app_version  = app_version  or row.app_version
    row.is_active    = True
    row.revoked_at   = None
    row.last_seen_at = datetime.utcnow()
else:
    db.session.add(MobilePushToken(
        user_id=user.id,
        platform=platform,
        token=token,
        token_hash=hash,
        device_label=device_label,
        app_version=app_version,
        is_active=True,
        last_seen_at=datetime.utcnow(),
    ))

db.session.commit()
return jsonify({"status": "registered"}), 200
```

**Response codes:**

| Code | Body | When |
|---|---|---|
| 200 | `{"status": "registered"}` | Success (whether new row or update) |
| 400 | `{"error": "<msg>"}` | Missing / wrong-type `token`; bad `platform` value |
| 401 | `{"error": "unauthorized"}` | Bearer missing or invalid |
| 413 | `{"error": "token too long"}` | Token > 4096 chars (defensive cap) |
| 500 | `{"error": "server"}` | DB error; logged via existing app logger |

**Idempotency:** the same (token, user) → 200 every time. Never
returns 409 — re-registration is the normal case (every cold start
the mobile app POSTs the token).

### 3.2 `DELETE /api/mobile/account/push-token`

Used by the mobile app on logout to revoke the current install's
token, so notifications stop reaching a logged-out device.

**Auth:** same as above.

**Request body (JSON):**

```json
{ "token": "<full FCM token>" }
```

**Behaviour:**

```
hash = sha256(token).hexdigest()
row  = MobilePushToken.query.filter_by(
    token_hash=hash, user_id=user.id
).first()
if row:
    row.is_active  = False
    row.revoked_at = datetime.utcnow()
    db.session.commit()
return jsonify({"status": "revoked"}), 200   # always 200, idempotent
```

Returns 200 even if no row found — DELETE on a missing token is a
no-op, not an error.

### 3.3 Catch-all 404 registration

Because `mobile_api.py` has a catch-all 404 handler that shadows
unregistered paths (see `tests/test_v100_battery_lab_mobile.py`
for the existing pattern), **the new path must be added to the
mobile allowed-methods registry** (`_mobile_allowed_methods`
dict). The implementer should confirm by writing a test that calls
`mod._mobile_allowed_methods_for('/account/push-token')` and
asserts it isn't `None`.

---

## 4. Firebase Admin SDK integration

### 4.1 New dependency

Add to `requirements.txt`:

```
firebase-admin==6.6.0
```

Pin a major version. `google-auth==2.32.0` is already in
`requirements.txt` and `firebase-admin` brings its own pinned
range — verify no conflict when the implementer runs
`pip install -r requirements.txt`.

### 4.2 Initialization

New file: `app/services/push_dispatch.py`. Initialised exactly
once, lazily on first send (so the rest of the app boots even when
the credentials env var is missing in dev):

```python
import os
import firebase_admin
from firebase_admin import credentials, messaging

_initialized = False

def _ensure_init():
    global _initialized
    if _initialized:
        return
    cred_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
    if not cred_path:
        # No-op mode for dev without the service account.
        return
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(cred_path))
    _initialized = True
```

Notes:
* The Google convention env var name is
  `GOOGLE_APPLICATION_CREDENTIALS`. `firebase-admin` reads it on
  its own when called with no args, but explicit
  `credentials.Certificate(path)` is clearer in our context.
* `firebase_admin._apps` is the SDK's own initialised-apps
  registry. We check it so re-importing the module doesn't crash
  with "default app already initialised".

### 4.3 Send function

```python
def send_push_to_user(user_id: int, title: str, body: str,
                     data: dict | None = None) -> tuple[int, int]:
    """Returns (sent_count, failed_count)."""
    _ensure_init()
    if not _initialized:
        return (0, 0)   # silent no-op in dev

    rows = MobilePushToken.query.filter_by(
        user_id=user_id, is_active=True
    ).all()
    if not rows:
        return (0, 0)

    sent = 0
    failed = 0
    for row in rows:
        try:
            msg = messaging.Message(
                notification=messaging.Notification(
                    title=title, body=body,
                ),
                data={k: str(v) for k, v in (data or {}).items()},
                token=row.token,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        sound='default',
                        # icon=... left default; the launcher icon
                        # fallback is fine until we add a dedicated
                        # white-on-transparent notification icon.
                    ),
                ),
            )
            messaging.send(msg)
            sent += 1
            row.last_seen_at = datetime.utcnow()
        except messaging.UnregisteredError:
            row.is_active = False
            row.revoked_at = datetime.utcnow()
            failed += 1
        except Exception:
            # Log via the standard app logger (current_app.logger
            # if inside request, module logger otherwise). Don't
            # abort other tokens.
            failed += 1

    db.session.commit()
    return (sent, failed)
```

Key design decisions:
* **Synchronous loop**, no async / Celery. Matches existing
  Telegram / SMS dispatch (`notifications.py:641` is also
  synchronous). Render's free tier doesn't have a worker.
* **Per-token `messaging.send`**, not `send_multicast`. Multicast
  has stricter limits and obscures per-token errors. Token counts
  per user are tiny (typically 1-3) so the loop is fine.
* **Auto-prune on `UnregisteredError`** — Google's signal that the
  install is gone (uninstall, app data cleared, token rotated).
  Mark `is_active=False` so we stop trying.
* **`data` payload** stays string-only (FCM requires it) — used
  later for deep-link routing (e.g. `{"route": "/battery"}`).

---

## 5. Wiring into the existing rules processor

### 5.1 Channel enum

Today `dispatch_notification(...)` in
`app/blueprints/notifications.py:641` accepts these channel values:
`'telegram'`, `'sms'`, `'both'`, `'none'`. Extend to:

| Old | New |
|---|---|
| `'telegram'` | `'telegram'` |
| `'sms'` | `'sms'` |
| `'both'` | `'both'` (= telegram + sms, unchanged) |
| `'none'` | `'none'` |
| — new — | `'push'` |
| — new — | `'all'` (= telegram + sms + push) |

The current dispatch loop:

```python
for channel in (['telegram', 'sms'] if channel_pref == 'both'
                else [channel_pref]):
```

Updated:

```python
expanded = {
    'both': ['telegram', 'sms'],
    'all':  ['telegram', 'sms', 'push'],
}.get(channel_pref, [channel_pref])
for channel in expanded:
    if channel == 'telegram':
        ok, resp = send_telegram_message(settings, title, message)
    elif channel == 'sms':
        ok, resp = send_sms_message(settings, title, message)
    elif channel == 'push':
        sent, failed = send_push_to_user(
            user_id=_user_id, title=title, body=message,
        )
        ok = sent > 0
        resp = f'sent={sent} failed={failed}'
    else:
        continue
    log_notification(
        event_key + ':' + channel, rule_name, title, message,
        channel, 'success' if ok else 'danger', resp, force=True,
    )
```

### 5.2 Default rules

`default_notification_rules()` (notifications.py around line 51)
currently returns `'telegram'` as the default channel for every
rule. **Do not change defaults** — existing users would suddenly
get push for events they never opted into. Push opts in only:

* Per-user, when they call `PATCH /api/mobile/notifications/settings`
  with `'push'` or `'all'` for a specific rule.
* Phase D will add the UI for that PATCH; for now the only way to
  enable push is to update the user's `notification_settings` row
  directly in the DB.

### 5.3 Mirror to `NotificationEvent`

The current `mirror_energy_notification_to_center(...)` call at
the end of `dispatch_notification` already writes to
`notification_event` so the in-app inbox reflects every fire. No
change needed — the bell icon + inbox already light up regardless
of channel.

---

## 6. Env vars

| Var | Where | Purpose |
|---|---|---|
| `GOOGLE_APPLICATION_CREDENTIALS` | Local: `.env` (gitignored). Render: dashboard env var with file path on the deployed FS, **OR** `RENDER_SECRET_FILE` mount. | Path to the Firebase service-account JSON. |
| `PUSH_ENABLED` (optional) | Both | Boolean kill-switch — `false` makes `send_push_to_user` short-circuit even when credentials are present. Useful for staging or incident response. |

### 6.1 Render specifics

Render does **not** persist arbitrary files between deploys, and
the `GOOGLE_APPLICATION_CREDENTIALS` value should be a **path on
the deployed instance, not the JSON content**.

Two options for the implementer to choose between:

**A — Render Secret Files (recommended):**
1. Render dashboard → Service → Environment → "Add Secret File"
2. Filename: `firebase-service-account.json`
3. Paste the entire JSON content
4. Render mounts it at `/etc/secrets/firebase-service-account.json`
5. Set env var `GOOGLE_APPLICATION_CREDENTIALS=/etc/secrets/firebase-service-account.json`

**B — JSON-in-env-var:**
1. Single env var `FIREBASE_SERVICE_ACCOUNT_JSON` with the entire
   minified JSON pasted as the value.
2. `_ensure_init` parses with `json.loads()` and uses
   `credentials.Certificate(json_dict)`.

Option A is closer to Google's documented convention and keeps the
code single-path. The spec assumes A unless the implementer flags
a Render limitation.

### 6.2 `.env.example` update

Append to `C:\Users\Ahmad\Desktop\solardeya\.env.example`:

```
# Firebase Cloud Messaging — service account credentials.
# Obtain from Firebase Console → Project Settings → Service accounts
# → Generate new private key. NEVER commit the JSON file itself.
GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/zynavolt-firebase-adminsdk-xxx.json
# Optional kill-switch. Defaults to enabled when credentials exist.
PUSH_ENABLED=true
```

### 6.3 `render.yaml` update

Add to the `envVars:` block:

```yaml
      - key: GOOGLE_APPLICATION_CREDENTIALS
        value: /etc/secrets/firebase-service-account.json
      - key: PUSH_ENABLED
        value: true
```

The Secret File itself is NOT defined in `render.yaml` — it must
be added manually in the Render dashboard, because committing the
JSON to git is the exact thing we're avoiding.

---

## 7. Files to be modified

| File | Change |
|---|---|
| `app/models.py` | Probably no change (`MobilePushToken` already exists). Verify. |
| `app/blueprints/mobile_api.py` | Add `POST` and `DELETE /api/mobile/account/push-token` endpoints + register them in the allowed-methods dict. |
| `app/blueprints/notifications.py` | Extend `dispatch_notification(...)` channel switch with `'push'` and `'all'`. |
| `app/services/push_dispatch.py` | **New file** — `_ensure_init()` + `send_push_to_user(...)`. |
| `app/services/__init__.py` | Likely no change (the new module is imported by the dispatcher and the mobile_api blueprint). |
| `requirements.txt` | Append `firebase-admin==6.6.0`. |
| `.env.example` | Document the two new env vars. |
| `render.yaml` | Add the two new `envVars` entries. Do NOT add the Secret File definition. |
| `tests/test_v101_push_token_register.py` | **New file** — see §8. |
| `tests/test_v101_push_dispatch.py` | **New file** — see §8. |
| `HEAVY_V10_X_Y_PUSH_NOTIFICATIONS_RELEASE_NOTES.md` | **New file** at repo root, following the existing release-notes format (Highlights + New/changed files). Suffix `_X_Y` should bump the latest version on `main`. |

Files **not** to touch:
* `app/__init__.py` — `db.create_all()` already handles the table.
* `app/models.py` — `MobilePushToken` already declared.
* `app/services/mobile_auth.py` — auth helper unchanged.
* `app/blueprints/mobile_notifications_api.py` — separate
  notification-center blueprint, unrelated.

---

## 8. Local test plan

Mirror the pattern in `tests/test_v100_battery_lab_mobile.py`:
* Module-level imports from `app.*`
* `_make_flask_app()` helper for minimal config
* Mock external calls (`firebase_admin.messaging.send`)

### 8.1 `tests/test_v101_push_token_register.py`

Cases to cover:
1. **Happy path** — POST with valid token + bearer → 200,
   `mobile_push_token` row created with correct `user_id`,
   `is_active=True`.
2. **Re-register same token** — POST same token again → 200, row
   updated (`last_seen_at` bumped), no duplicate row.
3. **Re-register same token under different user** — token reassigns
   to the new `user_id`. (Edge case: shared device.)
4. **Missing `token` field** → 400.
5. **Empty `token`** → 400.
6. **Token over 4096 chars** → 413.
7. **No bearer** → 401.
8. **Admin user** → 401 (admins don't get push).
9. **Endpoint registered in mobile allowed-methods** — same assertion
   pattern as `test_battery_lab_endpoint_registered_in_allowed_methods`.

### 8.2 `tests/test_v101_push_dispatch.py`

Cases:
1. **No tokens for user** — `send_push_to_user(user_id, ...)` returns
   `(0, 0)`, no FCM call attempted.
2. **One active token** — `messaging.send` called once with correct
   `title`/`body`, returns `(1, 0)`.
3. **`UnregisteredError` from FCM** — token gets `is_active=False`,
   `revoked_at` set; returns `(0, 1)`.
4. **Multiple tokens, mixed outcomes** — 2 succeed, 1 fails → `(2, 1)`.
5. **No `GOOGLE_APPLICATION_CREDENTIALS`** — `(0, 0)` returned without
   calling Firebase, no exception.
6. **`dispatch_notification` with channel='push'** — calls
   `send_push_to_user`, writes a `notification_log` row with
   `channel='push'`.
7. **`dispatch_notification` with channel='all'** — fans out to
   telegram + sms + push, three log rows.

Mock strategy:
* `firebase_admin.messaging.send` → `unittest.mock.patch`.
* `firebase_admin.initialize_app` → patch to a no-op so tests don't
  need real credentials.
* `MobilePushToken` rows → seeded in an in-memory SQLite via the
  existing test app fixture (or via direct `db.session.add`).

### 8.3 Manual test on a phone

1. Confirm the implementer's local Flask is reachable from the
   phone (LAN IP, not localhost).
2. Set `GOOGLE_APPLICATION_CREDENTIALS=C:\Users\Ahmad\Documents\zynavolt-secrets\zynavolt-firebase-adminsdk-fbsvc-42ba73fa50.json`
   in the local `.env`.
3. `flask run --host 0.0.0.0` (or however the project starts dev).
4. On phone, `flutter run` against the local backend.
5. Watch the local Flask log for the POST to `/api/mobile/account/push-token`.
6. From a Python REPL or a `flask shell`:
   ```python
   from app.services.push_dispatch import send_push_to_user
   send_push_to_user(user_id=1, title='تجربة', body='مرحبا من السيرفر')
   ```
7. Phone should buzz with a system notification.

---

## 9. Render test plan

1. **Add the Secret File** in the Render dashboard:
   * Service → Environment → Secret Files → Add
   * Filename: `firebase-service-account.json`
   * Paste the entire JSON from
     `C:\Users\Ahmad\Documents\zynavolt-secrets\zynavolt-firebase-adminsdk-fbsvc-42ba73fa50.json`
2. **Add the env vars** (or commit them to `render.yaml`):
   * `GOOGLE_APPLICATION_CREDENTIALS=/etc/secrets/firebase-service-account.json`
   * `PUSH_ENABLED=true`
3. **Redeploy.** Watch the build log for `firebase-admin` install.
4. **Verify endpoint exists:**
   `curl -i -H 'Authorization: Bearer <real_token>' \
     https://<service>.onrender.com/api/mobile/account/push-token \
     -X POST -d '{"token":"fake","platform":"android"}' \
     -H 'Content-Type: application/json'`
   Expect 200.
5. **Check the table** — Render dashboard → Database → psql:
   `SELECT user_id, platform, is_active, last_seen_at FROM mobile_push_token;`
6. **Mobile end-to-end** — install the latest APK on the phone, log in,
   confirm `last_seen_at` is recent.
7. **Trigger a real rule** — manually drop a battery reading low enough
   to fire the existing rule, confirm the phone gets a notification
   AND the same event lands in the in-app inbox.
8. **Roll back plan** — set `PUSH_ENABLED=false` if anything goes
   sideways. Endpoint stays available; only the dispatcher silences.

---

## 10. Security & "do not commit" list

### 10.1 What MUST stay out of git (any repo)

* `zynavolt-firebase-adminsdk-*.json` — the cryptographic private
  key for sending notifications. Anyone with this file can spam
  every user on the platform. Currently lives at
  `C:\Users\Ahmad\Documents\zynavolt-secrets\` (mobile repo's
  `.gitignore` already covers the `*-firebase-adminsdk-*.json`
  pattern; mirror this in the backend repo's `.gitignore`).
* The contents of any `.env` file with the Render database URL or
  Firebase credentials.
* The Render Secret File once mounted on the server — never
  `cat /etc/secrets/...` into a log line or stack trace.

### 10.2 What's safe to commit

* `google-services.json` (mobile side) — embedded API key is
  scoped to one Firebase project + one package name. Public.
* `render.yaml` env-var entries with NO actual values
  (`generateValue: true`, or paths like
  `/etc/secrets/firebase-service-account.json`).
* The new endpoint code, the dispatcher, the model, the tests.
* This spec.

### 10.3 Code-level hardening

* `send_push_to_user` must NEVER include the FCM token in any log
  line (it's a per-install secret that lets anyone send to that
  device).
* The two endpoints log via the standard app logger but only with
  `user_id`, not the token. Use a 12-char prefix at most when
  debugging.
* `firebase-admin` errors that surface stack traces should be
  caught and logged with a generic "push send failed" message —
  Firebase exception strings sometimes echo the token.

### 10.4 Backend `.gitignore` additions

Append (the backend repo may already have some of these):

```
# Firebase service account — must never enter the repo.
*-firebase-adminsdk-*.json
serviceAccountKey.json
firebase-service-account*.json

# Local secret bundle (matches the path the mobile docs use).
zynavolt-secrets/
```

---

## 11. Out of scope for this spec (explicitly)

These will be separate PRs / specs once the foundation works:

* **Phase D — Settings UI** for per-rule push toggles (mobile +
  backend `notification_settings` schema additions if the existing
  rules dict can't express push-as-extra-channel cleanly).
* **Deep linking** from a tapped notification to the relevant
  screen (e.g., low-battery notification → Battery Lab tab).
  Requires `data.route` payload + a router-aware handler in
  `notifications_screen.dart`.
* **Topic / broadcast push** for app-wide announcements (e.g., new
  release notes). Today every send is per-user-tokens.
* **Localised payloads.** Today `title` and `body` are whatever the
  rule produces — Arabic strings work fine via UTF-8, but there's
  no `data.locale` switch yet.
* **iOS / APNs.** Owner explicitly chose Android-first; iOS adds
  Apple developer account, APNs key generation, and a different
  plist setup.
* **Rate limiting / dedupe across channels** — currently relies
  entirely on `notification_exists(event_key, dedupe_minutes)`
  inside `dispatch_notification`. Push goes through the same
  dedupe window as Telegram / SMS, which is the intended
  behaviour.

---

## 12. Open questions for the implementer

Things this spec doesn't decide because they depend on choices we
haven't made yet — answer in the implementation PR:

1. Does `mobile_push_token` already exist in the production DB on
   Render, or does this deploy create it via `create_all()`? Verify
   with a `\dt` in the Render psql console before merging.
2. Render Secret File vs. JSON-in-env-var (§6.1) — pick one.
3. Should `PUSH_ENABLED=false` cause the endpoint to also reject
   POSTs (with 503), or should it silently accept tokens but skip
   sends? Spec assumes the latter (accept tokens always; only
   gate the dispatcher).
4. When `send_push_to_user` returns `(0, 0)` because the user has
   no active tokens, do we still want a `notification_log` row with
   `status='skipped'`? Spec says no — only log actual send attempts.
5. What's the HEAVY version suffix for the release notes file? The
   most recent on `main` should be the source of truth.

---

## 13. Done definition

This Phase is "done" when:

* [ ] `MobilePushToken` table exists on the Render PostgreSQL DB.
* [ ] `POST /api/mobile/account/push-token` returns 200 and
      persists the row.
* [ ] `DELETE /api/mobile/account/push-token` flips `is_active=False`.
* [ ] `send_push_to_user(user_id, title, body)` from `flask shell`
      delivers a notification to the test phone.
* [ ] Setting a user's `notification_settings.charge['10']` to
      `'push'` and dropping a battery reading below 10 % triggers
      a phone notification.
* [ ] The two test files pass locally + in CI.
* [ ] A `HEAVY_V10_X_Y_PUSH_NOTIFICATIONS_RELEASE_NOTES.md` is
      committed with the Highlights + New/changed files sections.
* [ ] The mobile `_sendToBackend` stub in
      `lib/core/notifications/push_service.dart` is replaced with
      a real Dio call to the new endpoint, and a follow-up commit
      lands on `main` of the mobile repo.

The mobile-side switch from stub to real Dio call is technically
a separate commit on the mobile repo (`F:\solardeya-mobile`) — but
should land in the same PR window as the backend deploy so a user
running the latest mobile build always finds an endpoint to talk
to.
