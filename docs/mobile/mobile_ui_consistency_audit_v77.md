# Zynavolt Mobile — UI Consistency Audit (v77)

Audit snapshot of the Flutter mobile app as of v77, after the v57–v76
visual-polish pass. Purely documentation — no code behavior is changed
by this file.

---

## 1. Screens & their states

| Screen | Route | AppBar | Refresh action | Empty / loading / error |
| --- | --- | --- | --- | --- |
| Splash | `/splash` | — | — | brand backdrop, calm spinner |
| Login | `/login` | — | — | inline error banner |
| Home (Dashboard) | `/home` | none | hero button | full ListView with state cards |
| Devices list | `/devices` | yes | (none) | scrollable loading/error/empty |
| Device Details | `/devices/:id` | yes | `AppRefreshButton` | scrollable loading/error/empty + invalid-id guard |
| Loads | `/loads` | yes | `AppRefreshButton` | scrollable loading/error/empty + search-result count |
| Notifications | `/notifications` | yes | `AppRefreshButton` | scrollable loading/error/empty |
| Support inbox | `/support` | yes | `AppRefreshButton` | scrollable loading/error/empty |
| Support thread | `/support/:kind/:id` | yes | `AppRefreshButton` | scrollable loading/error + `ReadOnlyNotice` |
| Profile | `/profile` | yes (default back) | — | loading + form |
| Account & subscription | `/account` | yes | `AppRefreshButton` | scrollable loading/error + `ReadOnlyNotice` |
| App Settings | `/settings` | yes | — | static content + on-demand health |
| More tab | `/more` | yes | — | grouped tiles |

Every screen with a `RefreshIndicator` now wraps its loading state in a
scrollable `ListView` so pull-to-refresh works in every state. No screen
in the app can render a silent blank body (v57 fix + v71 unification).

## 2. Design tokens (from v58)

Established in [`lib/app/app_theme.dart`](../../lib/app/app_theme.dart) +
[`lib/core/widgets/app_card.dart`](../../lib/core/widgets/app_card.dart).

* **Colors**: `ink`, `softInk`, `muted`, `faintMuted`, `line`, `softBg`,
  `surface`, `indigoPrimary`, `indigoBright`, `indigoSoft`, `violet`,
  `success`, `warning`, `danger`.
* **Spacing scale**: `space2 / 4 / 6 / 8 / 10 / 12 / 14 / 16 / 20 / 24 / 32`.
* **Radii**: `radiusInput=10`, `radiusCard=12`, `radiusHero=14`, `radiusGlass=16`.
* **Shadows**: `softShadow` (subtle, indigo-tinted) + `liftedShadow`
  (heavier, for hero / floating).
* **Gradients**: `brandGradient` (full saturation) + `pageBackdropGradient`
  (Splash / Login / Home backdrop).
* **Glass**: `glassSurface = white·0.96` + `glassBorder = line`.
* **`AppCard(elevated: true)`** — opt-in shadow on featured cards.

Consumers of `elevated: true` today: Home `_NoDeviceState`, `_LoadingBlock`,
`_ErrorBlock`; Device Details `_StatusCard`; Account `_SubscriptionCard`;
Settings `_BrandCard`.

## 3. Typography state

* `fontFamily: 'Roboto'` — system fallback. Arabic font wiring recipe is
  in [`assets/fonts/README.md`](../../assets/fonts/README.md) (v60). No
  font is bundled in git.
* Smallest visible font size: **11**. Anything below was bumped in v73.
* Heaviest weight in use: `FontWeight.w900` (hero / numbers).
* Numeric values that should remain monospaced (e.g. timestamp lines) use
  `fontFeatures: [FontFeature.tabularFigures()]`.

## 4. Brand asset gaps

| Asset | State | Action |
| --- | --- | --- |
| `assets/branding/zynavolt_logo.png` | **missing** | Drop a 1024×1024 PNG. Every consumer has a calm sun-icon fallback so the build never breaks. |
| Arabic font (Cairo / Tajawal) | **missing** | Drop ttfs under `assets/fonts/Cairo/`, declare in pubspec, flip the one line in `app_theme.dart`. |
| Android launcher icons | **stock Flutter** | Regenerate after the logo is dropped. |

All wiring is documented in:
* [`assets/branding/README.md`](../../assets/branding/README.md)
* [`assets/fonts/README.md`](../../assets/fonts/README.md)
* [`docs/mobile/mobile_release_readiness_v56.md`](mobile_release_readiness_v56.md) §4

## 5. Color-usage rules (in practice)

* **Brand indigo** owns: hero cards, primary CTAs, active chips/pills,
  active connector animation, status banners, refresh tooltips.
* **Violet** is reserved for grid-connector activity and the unread-dot
  accent in notifications.
* **Success green** = connected / mark-read confirmations / "active"
  badges on loads.
* **Warning amber** = solar (sun-tile) and partial / unknown state.
* **Danger red** = errors, sign-out CTA.
* **Faint-muted / muted** = labels, helper text, inactive icons.

Never invent a new color in a screen — pick one of the eleven palette
tokens.

## 6. Known visual issues / follow-ups

* **No Cairo/Tajawal font** — Arabic body text renders in Roboto fallback.
  Acceptable for internal builds; release should ship the licensed font.
* **No real logo PNG** — every consumer has a calm fallback; the rounded
  sun-icon tile carries the brand visually until the asset is dropped.
* **Energy-flow battery direction** — direction is correctly derived from
  `battery_power_w` sign (v49b), but sensor noise near zero may briefly
  show direction during transitions. Documented in v49 risks. No backend
  fix in scope.
* **Grid connector** — stays in `pulse` mode because the backend doesn't
  expose a `grid_direction` field. Will become directional once it does.
* **No charts** — by design (project rule). The "history" view will
  need a future phase if introduced.

## 7. Read-only badges (v76)

The shared
[`ReadOnlyNotice`](../../lib/core/widgets/read_only_notice.dart) banner
appears on:

* Support thread detail (`هذه المحادثة للقراءة فقط حالياً.`)
* Account / subscription screen (`بيانات الحساب والاشتراك معروضة هنا للعرض فقط حالياً.`)

Loads, Device Details, and Notifications carry their read-only nature
through the absence of edit affordances + their scope banners; an
explicit `ReadOnlyNotice` on those would be redundant.

## 8. QA gates passed at v77

* `flutter analyze` → 0 issues.
* `flutter test` → 75 / 75 pass.
* `git status` between commits → only the expected scope per commit.

## 9. Next visual priorities

1. **Ship the logo PNG + Cairo font.** Both wirings are in place; the
   only blocker is the actual binary asset. The visual jump after these
   two land will be significant.
2. **Animated home-flow board polish** — currently uses sin-wave pulse
   for grid/battery-idle. After Cairo lands, revisit the chip styles
   to verify Arabic glyph baselines.
3. **Adopt the v58 spacing scale** consistently across the older v40–v45
   screens (Home internals, Devices list) to drop the remaining magic
   numbers.
4. **Optional: introduce a small `BrandLogo` widget** so the four
   screens that hard-code `Image.asset(_kBrandLogoPath, errorBuilder:…)`
   share one source of truth.

## 10. What v77 does not do

* No backend touched.
* No package added.
* No screen redesigned.
* No new test failures introduced.
* Documentation only.
