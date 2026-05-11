# Zynavolt Mobile — v80 Baseline Summary

Final summary of the v57–v80 polish block. This is the formal RC-readable
baseline: every commit below has passed `flutter analyze` (0 issues) and
`flutter test` (75 / 75) at the moment it landed.

---

## 1. Commit range

| Version | Hash | Title |
| --- | --- | --- |
| v57 | `bab23e9` | fix device details and arabize account labels |
| v58 | `2239e7a` | establish mobile design system tokens |
| v59 | `0f60ccf` | prepare mobile brand assets |
| v60 | `041d1a1` | prepare Arabic typography assets |
| v61 | `fbc7bff` | polish mobile screen scaffolds |
| v62 | `6b841c2` | refine premium home dashboard visuals |
| v63 | `9abee7e` | polish device details experience |
| v64 | `3139d6f` | polish loads visual experience |
| v65 | `0372686` | polish notifications center visuals |
| v66 | `b04267d` | polish read-only support experience |
| v67 | `c4e2e9d` | polish account subscription experience |
| v68 | `70369cf` | polish profile editing experience |
| v69 | `563daf0` | reorganize more screen experience |
| v70 | `2dd2d0c` | polish app settings screen |
| v71 | `c1a903e` | unify mobile loading empty error states |
| v72 | `c8678ec` | add subtle mobile micro interactions |
| v73 | `acf66e3` | improve mobile accessibility readability |
| v74 | `8fbed59` | harden responsive mobile layouts |
| v75 | `f514968` | polish Arabic mobile copy |
| v76 | `5796870` | clarify read-only feature states |
| v77 | `969f442` | document mobile UI consistency audit |
| v78 | `58dda00` | add mobile release candidate smoke checklist |
| v79 | `ead299b` | clean mobile UI implementation details |
| v80 | *this commit* | document mobile baseline summary |

24 commits, every one passes QA.

## 2. Features ready in the v80 baseline

| Surface | State |
| --- | --- |
| Auth (login, refresh, secure-storage session) | ✅ ready |
| Home dashboard (real `/api/mobile/dashboard`) | ✅ ready, no fake data |
| Fixed-grid energy board (no overflow, no drift) | ✅ ready |
| Honest flow direction (solar / home directional; battery sign-based; grid pulse) | ✅ ready |
| Devices list | ✅ ready |
| Device Details (read-only, no blank state) | ✅ ready |
| Loads list + search + scope filter | ✅ ready (read-only) |
| Notifications feed + mark-read + read-all | ✅ ready |
| Notification category chips Arabized | ✅ ready |
| Support inbox + read-only thread + read-only notice | ✅ ready |
| Account & subscription (Arabized labels, sections) | ✅ ready (read-only) |
| Profile (read + safe edit) | ✅ ready |
| More tab (grouped: الحساب / التطبيق / التشخيص) | ✅ ready |
| App Settings (brand, version, base URL, health check, language note) | ✅ ready |
| Health check (`GET /api/mobile/health`) | ✅ ready (More + Settings) |
| Logout (clears caches + storage) | ✅ ready |
| Shared `AppRefreshButton`, `ReadOnlyNotice`, `formatDateTime`, `formatDate`, `AccountLabels`, `NotificationLabels` | ✅ adopted across screens |
| Design tokens (spacing scale, shadows, gradients, glass) | ✅ available in `app_theme.dart` |

## 3. Known gaps (carried forward)

1. **`assets/branding/zynavolt_logo.png`** is still missing. The whole UI
   gracefully falls back to a calm sun-icon tile via `errorBuilder`.
   Drop the 1024×1024 PNG to ship the real brand.
2. **Arabic font (Cairo / Tajawal)** is not bundled. App renders in
   `Roboto`. Wiring recipe documented in
   [`assets/fonts/README.md`](../../assets/fonts/README.md).
3. **Notification settings** (Telegram / SMS / per-device) — not wired
   yet; backend exposes them but UI is out of scope for v80.
4. **Push notifications / FCM** — not wired, by project rule.
5. **Offline DB / sync queue** — not wired, by project rule.
6. **No charts** — by project rule.
7. **Tablet / foldable layouts** — not specifically tuned.
8. **iOS** — Android-only target.
9. **Support endpoint prefix** — lives at `/api/v1/support/*` (not
   `/api/mobile/support/*`). Cosmetic backend divergence; mobile already
   handles it explicitly. Consolidating is a backend job.

## 4. Manual smoke checklist

See [`mobile_rc_smoke_checklist_v78.md`](mobile_rc_smoke_checklist_v78.md)
for the full checklist. The headline gates are:

* App launches → splash → login (or home if signed in).
* No screen renders silently blank in any state.
* No raw backend slugs anywhere (`can_*`, `auth`, `devices`, etc.).
* No English UI text except `Zynavolt`, `W` / `kW` / `kWh` / `%`, and
  the base URL in Settings.
* No layout overflow on phones 5"–6.7".
* Energy-flow direction honest in every device state.
* Logout returns to login with no cached previous-user data.

## 5. Do-not-touch rules (still in force)

| Rule | Status |
| --- | --- |
| Do not touch backend repo | ✅ honored |
| Do not touch web project | ✅ honored |
| Do not touch web Flow Graph | ✅ honored |
| Do not add fake data | ✅ honored |
| Do not add destructive actions | ✅ honored |
| Do not add charts | ✅ honored |
| Do not add Firebase / FCM | ✅ honored |
| Do not add offline DB | ✅ honored |
| Do not change package name / applicationId | ✅ honored |
| Do not use `git add .` | ✅ honored — explicit paths only |
| Arabic-first UI, no English visible text (with allowed exceptions) | ✅ honored |
| Do not push | ✅ honored — local commits only |

## 6. Next recommended phase (post-v80)

Pick whichever of these blocks gives the biggest user-visible jump for
your next milestone. Each is **safe** in the sense that it has been
scoped, has a clear wiring recipe in the repo, and does not require
backend changes.

1. **Real logo asset**. Drop `assets/branding/zynavolt_logo.png` and the
   four consumer surfaces (Splash, Login, Home, Settings) start rendering
   the real brand instantly. Regenerate Android launcher icons via
   `flutter_launcher_icons` after.

2. **Arabic font asset**. Drop Cairo (or Tajawal) ttfs under
   `assets/fonts/Cairo/`, add a `fonts:` section to `pubspec.yaml`, flip
   the single `fontFamily` line in `app_theme.dart`. Visual upgrade is
   significant.

3. **Localization (`flutter_localizations` + ARB)**. Move every visible
   string to `.arb` files so an `ar` / `en` toggle becomes possible.
   Today every string is hardcoded Arabic — the move is mechanical but
   high-volume. Plan a focused phase.

4. **Notification settings (read-only first)**. The backend exposes
   `/api/mobile/notifications/settings`. Build a v81 read-only viewer of
   Telegram / SMS / per-device channels. Editor lands in a later phase.

5. **Backend support-route consolidation** (backend phase). Move support
   endpoints from `/api/v1/support/*` to `/api/mobile/support/*` for
   prefix uniformity. Mobile changes are tiny (`support_repository.dart`
   path string) once the backend is ready.

6. **Energy-flow grid direction**. Once the backend exposes a
   `grid_direction` field, change `_FlowMotion.fromCards` (one mapping
   line) to make the grid connector directional. The painter already
   supports `towardHub` / `awayFromHub`.

---

## 7. Trust signals

* `flutter pub get` → green.
* `flutter analyze` → 0 issues.
* `flutter test` → 75 / 75 passes.
* `git status --porcelain` → only the v80 doc on `main` at tag time.
* `git log --oneline -30` → linear history, every commit tagged with its
  scope, no stray "fix typo" commits.

Treat this baseline as the canonical reference for any RC build cut from
the current `main` after v80 lands.
