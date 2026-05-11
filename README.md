# Zynavolt Mobile (Flutter)

> Branding note: the user-facing product is **Zynavolt**. Zynavolt mobile
> currently connects to the existing **SolarDeye backend API** during the
> transition; technical references to the backend repo, namespace, env
> variables and storage keys still use the `solardeye` / `SOLARDEYE_*`
> identifiers on purpose.

Android-first Arabic-RTL Flutter client for **Zynavolt**, the solar
monitoring platform. The app is a thin presentation layer; **the Flask
backend is the single source of truth**. The mobile app:

- Talks only to `/api/mobile/*` (Bearer-authenticated JSON).
- Never connects to the database.
- Never duplicates energy / scheduler / notification / weather logic.
- Renders server-computed values; it does not derive them.

This repo is currently the **v37 foundation** — architecture, theme, API
client, auth flow, navigation shell, and honest placeholders for the five
top-level tabs. The full UI (dashboard visuals, charts, settings, loads,
support chat) is intentionally not built yet.

---

## Requirements

- Flutter `3.41.x` (Dart `^3.11.5`). Tested with `Flutter 3.41.9 stable`.
- Android SDK + emulator (or a physical Android 6.0+ device).
- A running SolarDeye backend exposing `/api/mobile/*`.

## Run

```sh
flutter pub get
flutter analyze
flutter test
flutter run             # launches on the first available device/emulator
```

To pick a specific device:

```sh
flutter devices
flutter run -d <id>
```

## Configuring the backend base URL

There is one config knob: `lib/app/app_config.dart::AppConfig.apiBaseUrl`.

The default is the **Android emulator host loopback**:

```
http://10.0.2.2:5000
```

Override it at build/run time with `--dart-define`:

```sh
# Local Flask backend on the same machine, Android emulator
flutter run --dart-define=SOLARDEYE_API_BASE_URL=http://10.0.2.2:5000

# Physical Android device on the same Wi-Fi as the backend host
flutter run --dart-define=SOLARDEYE_API_BASE_URL=http://192.168.1.50:5000

# Staging / prod
flutter build apk --release \
  --dart-define=SOLARDEYE_API_BASE_URL=https://api.solardeye.example.com
```

`AndroidManifest.xml` enables `usesCleartextTraffic="true"` so HTTP calls to
`10.0.2.2` work in development. Production releases should narrow this with a
`network_security_config.xml` that allows cleartext only for dev hosts (or
ship HTTPS-only). This is documented as a follow-up; v37 leaves it as-is so
the emulator works out of the box.

### Connecting to a real SolarDeye backend

The backend must be running and reachable from the device's network:

1. **Start the Flask backend** on the development machine — the mobile app
   does not bundle one.
2. **Pick the right base URL** for the target device:

   | Device target | URL pattern | Example |
   |---|---|---|
   | Android **emulator** (AVD) | `http://10.0.2.2:<port>` | `http://10.0.2.2:5000` |
   | Physical Android device | `http://<host-LAN-IP>:<port>` | `http://192.168.1.50:5000` |
   | Staging / production | HTTPS public URL | `https://api.solardeye.example.com` |

   `10.0.2.2` is a special address inside the Android emulator that always
   routes to the host machine's `localhost`. It will not work on a real phone.
3. **Launch with that URL:**

   ```sh
   flutter run --dart-define=SOLARDEYE_API_BASE_URL=http://10.0.2.2:5000
   ```
4. **Quick sanity check inside the app:** sign in, then open the More tab and
   tap "تحقّق من الاتصال". The button calls `GET /api/mobile/health` with no
   Bearer token and shows the real success or failure message verbatim — it
   does not fake success.

### If something goes wrong

The app surfaces backend errors honestly. The most common ones during dev:

| Symptom in app | Likely cause | Fix |
|---|---|---|
| "تعذّر الاتصال بالخادم. تحقق من اتصال الإنترنت." | Wrong base URL, Flask not running, firewall blocking the port, or wrong network. Equivalent to a TCP "connection refused" / "network unreachable". | Confirm Flask is listening on `0.0.0.0:5000` (not just `127.0.0.1:5000`); confirm device & host are on the same Wi-Fi; on a physical device use the host's LAN IP, not `10.0.2.2`. |
| "اسم المستخدم أو كلمة المرور غير صحيحة." (`code: invalid_credentials`) | Wrong username or password. | Try valid credentials. The backend never tells you which one is wrong — by design. |
| "تسجيل الدخول مطلوب." / `auth_required` 401 returned after splash | The stored access token expired *and* the refresh token is also invalid (revoked, expired, or never persisted). | The app silently drops you to the login screen — sign in again. No banner is shown for this case; that is intentional. |
| The session restores but every screen shows red errors | Tokens are valid but the backend is missing the v2 `/api/mobile/*` routes you expect. | Confirm the backend exposes the new `/api/mobile/*` namespace (not just the legacy `/api/v1/*`). The mobile app calls `/api/mobile/*` only. |
| "انتهت مهلة الاتصال بالخادم." | Backend is slow or unreachable on the configured port. | Increase `AppConfig.connectTimeoutMs` / `receiveTimeoutMs` for slow networks or fix the network path. |
| 401 immediately on `تحقّق من الاتصال` | Should not happen — `/api/mobile/health` is unauthenticated and the call uses `skipAuth()`. If you see this, the route on the backend is gated by something it should not be. | Inspect the backend `protect_routes` allowlist for `/api/mobile/`. |

The "تشخيص المطوّر" card on the More tab shows the auth phase, the raw
stored selected-device id, the resolved effective device id, and the last
restore error — useful while wiring up against a real backend.

## Authentication flow

`AppSessionController` (`lib/core/state/app_session.dart`) drives the router.

1. **Cold start** → splash. The controller calls `restore()`:
   - reads access token from `flutter_secure_storage`
   - if present, calls `GET /api/mobile/auth/me`
   - on success → `AppSessionPhase.authenticated` (`HomeShell`)
   - on `401` the `ApiClient` interceptor tries `POST /api/mobile/auth/refresh`
     once with the stored refresh token; on success it replays the original
     request, on failure it clears tokens and notifies the controller
   - on any other failure → `AppSessionPhase.unauthenticated` with `lastError`
2. **Login** (`POST /api/mobile/auth/login`) stores tokens, calls `/me`, lifts
   the session to `authenticated`. `GoRouter` redirects automatically.
3. **Logout** revokes the refresh token (`POST /api/mobile/auth/logout`) and
   clears local storage.

Tokens are stored in `flutter_secure_storage`, backed by Android Keystore via
encrypted shared preferences (`AndroidOptions(encryptedSharedPreferences: true)`).
Plain `SharedPreferences` is never used for tokens.

## Architecture

```
lib/
├── main.dart                    # ProviderScope + SolarDeyeApp
├── app/
│   ├── solar_deye_app.dart      # MaterialApp.router, RTL Directionality
│   ├── app_router.dart          # GoRouter, session-driven redirects
│   ├── app_theme.dart           # v35 palette → Material 3 ThemeData
│   └── app_config.dart          # apiBaseUrl + telemetry headers
├── core/
│   ├── api/
│   │   ├── api_client.dart      # Dio + Bearer attach + 401 refresh
│   │   ├── api_exception.dart   # Centralised error model
│   │   └── api_response.dart    # Backend envelope { ok, data, meta, ... }
│   ├── storage/
│   │   └── secure_token_storage.dart
│   ├── state/
│   │   ├── app_session.dart     # Auth phase, session controller
│   │   └── api_providers.dart   # Cross-feature Riverpod re-exports
│   └── widgets/
│       ├── app_loading.dart
│       ├── app_empty_state.dart
│       ├── app_error_state.dart
│       └── app_card.dart
└── features/
    ├── auth/
    │   ├── data/
    │   │   ├── auth_models.dart
    │   │   └── auth_repository.dart
    │   └── presentation/login_screen.dart
    ├── bootstrap/
    │   └── data/
    │       ├── bootstrap_models.dart
    │       └── bootstrap_repository.dart
    ├── devices/
    │   ├── data/
    │   │   ├── device_models.dart
    │   │   └── devices_repository.dart
    │   └── presentation/devices_screen.dart
    ├── home/
    │   └── presentation/
    │       ├── home_shell.dart    # Bottom-nav with 5 tabs
    │       └── home_screen.dart
    ├── notifications/presentation/notifications_screen.dart
    ├── support/presentation/support_screen.dart
    ├── more/presentation/more_screen.dart
    └── splash/presentation/splash_screen.dart
```

### Bottom navigation

| ICON tab | Route | Screen |
|---|---|---|
| الرئيسية   | `/home`          | `HomeScreen` (bootstrap call + welcome) |
| الأجهزة    | `/devices`       | `DevicesScreen` (`/api/mobile/devices`) |
| الإشعارات | `/notifications` | placeholder |
| الدعم      | `/support`       | placeholder |
| المزيد     | `/more`          | profile summary + sign out |

### Packages

The minimum set for a clean foundation:

| Package | Why |
|---|---|
| `flutter_riverpod` | Single state-management story; small surface, no codegen. |
| `dio` | Needed for request/response interceptors (Bearer attach + 401 refresh), per-request timeouts, structured `DioException` to map onto `ApiException`. The plain `http` package would need a hand-rolled wrapper for all of that. |
| `flutter_secure_storage` | Android Keystore-backed token storage. |
| `go_router` | Declarative routing so notification deep-links can map onto screens later without rewriting the navigator. |
| `flutter_localizations` | Material/Cupertino Arabic locale. |

Deliberately not added in v37: chart libraries, Firebase / FCM, offline DB
(`drift` / `sqflite`), WebSocket, animations packages.

## What is intentionally **not** in v37

- Full dashboard / live data view (will use `/api/mobile/dashboard` and
  `/api/mobile/live` later).
- Flow Graph (web-only, locked).
- Charts of any kind.
- Notification settings UI (settings are global on the backend; per-device
  toggles are explicitly forbidden until a backend schema phase ships).
- Loads CRUD UI.
- Support chat composer.
- Mock / fake data anywhere.

## Honest placeholders

Empty tabs render `AppEmptyState` with a calm, honest line such as:

> سيتم تحميل البيانات من واجهات Zynavolt API.

No fake metrics, no mocked solar numbers, no decorative dashboards.

## Testing

```sh
flutter test
```

The current test suite covers `AppLoading`, `AppEmptyState`, and
`AppErrorState` to lock in the shape of the shared widgets. It does not yet
hit the network — that comes in v38 with proper repository mocks.
