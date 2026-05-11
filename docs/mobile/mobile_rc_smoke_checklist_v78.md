# Zynavolt Mobile — Release Candidate Smoke Checklist (v78)

Step-by-step manual checklist for verifying a build on a real Android
device after the v57–v77 polish pass. Pass every step before tagging an
RC build for distribution.

---

## Build command

```powershell
F:\flutter\bin\flutter.bat run -d <device-id> --dart-define=SOLARDEYE_API_BASE_URL=https://solardeye.onrender.com
```

For a release APK build:

```powershell
F:\flutter\bin\flutter.bat build apk --dart-define=SOLARDEYE_API_BASE_URL=https://solardeye.onrender.com
```

---

## 1. Auth & session

- [ ] **Cold launch, not signed in**: splash → login.
- [ ] **Cold launch, signed in (valid token)**: splash → home.
- [ ] **Login with wrong password**: clear Arabic error, no crash.
- [ ] **Login with correct credentials**: routes to home, hero greets user by name.
- [ ] **Kill + reopen app**: session restores from secure storage.
- [ ] **More → "تسجيل الخروج"**: returns to login, no cached previous-user data leaks (loads/notifications/account empty until re-login).

## 2. Home (Dashboard)

- [ ] Hero card renders Zynavolt wordmark + greeting + device chip + last-reading chip.
- [ ] Status banner appears above the energy board with the server's `status_text`.
- [ ] Fixed-grid energy board renders without overflow on phones 5"–6.7".
- [ ] Flow direction is honest:
  - [ ] Solar → hub when `solar_power_w > 0`.
  - [ ] Hub → home when `home_load_w > 0`.
  - [ ] Battery: hub → battery when charging (`battery_power_w > 0`).
  - [ ] Battery: battery → hub when discharging (`battery_power_w < 0`).
  - [ ] Battery: pulse when idle but SoC > 0.
  - [ ] Grid: pulse only — never directional (no `grid_direction` field).
- [ ] Connector lines meet the node cards exactly (no drift).
- [ ] Pull-to-refresh updates the dashboard.
- [ ] If no device is selected: calm `_NoDeviceState` card with elevated shadow.

## 3. Devices

- [ ] Devices tab loads real devices from `GET /api/mobile/devices`.
- [ ] Each tile shows: icon, name, type, active pill (if active), status pill.
- [ ] **Tap a device** → opens Device Details (full-screen, not inside bottom-nav).
- [ ] Active-device tile has indigo border + soft indigo background.

## 4. Device Details

- [ ] Body renders content under the AppBar (no blank state — v57 fix).
- [ ] **Loading**: scrollable spinner; can pull-to-refresh.
- [ ] **Error**: full-bleed error card with retry.
- [ ] **Data**: sections in this order — الحالة, آخر قراءة, الإعدادات الآمنة (if present), معلومات الجهاز.
- [ ] Status card (الحالة) has elevated shadow + status pill + "آخر اتصال" chip.
- [ ] Latest-reading card renders 5 stat tiles in a 2×2 + 1 grid (no overflow).
- [ ] Reading values use unit symbols `W` and `%` (never the Arabic letter `و`).
- [ ] "تعيين كجهاز نشط" button works when device is not active.
- [ ] Refresh icon shows the "جارٍ التحديث..." snackbar.

## 5. Loads

- [ ] More → الأحمال opens the list.
- [ ] Loading and error states are scrollable (no blank).
- [ ] Search box filters by load name client-side.
- [ ] When search filters: "عرض X من أصل Y حمل" summary appears.
- [ ] Filter chips: "كل الأحمال" / "الجهاز النشط" — selecting the second triggers a backend refetch with `?device_id=`.
- [ ] Filter chip transitions are smooth (v72 micro-interaction).
- [ ] Each load tile shows: name, enabled/disabled badge, power in `W`, priority, device link (if any).

## 6. Notifications

- [ ] Feed loads from `GET /api/mobile/notifications`.
- [ ] **Unread items**: left accent bar (violet) + violet dot + bolder title.
- [ ] **Read items**: calm white card with "مقروء" footer.
- [ ] Filter pills "الكل / غير المقروء" — selecting either is animated.
- [ ] Category chip (event_type / source_type) renders **Arabic** label, never the raw slug.
- [ ] Timestamps humanize: `HH:mm` today, `أمس HH:mm` yesterday, `YYYY-MM-DD HH:mm` older.
- [ ] Tap an unread item → marks read on the server, badge count decrements.
- [ ] "اقرأ الكل" marks all and shows a confirmation snackbar.
- [ ] "تحميل المزيد" appears when there are more pages.

## 7. Support

- [ ] Support tab loads cases from `GET /api/v1/support/cases`.
- [ ] Cases show subject + type chip (تذكرة / رسالة) + status chip.
- [ ] **Tap a case** → opens read-only thread.
- [ ] Thread shows the `ReadOnlyNotice` banner up top.
- [ ] Admin replies render with indigo "الدعم" header on indigoSoft bg.
- [ ] User replies render with muted "أنت" header on white bg.

## 8. Account & subscription

- [ ] More → الحساب والاشتراك loads.
- [ ] Top of screen shows the `ReadOnlyNotice` banner.
- [ ] Identity card: name, username, البريد الإلكتروني, الدور, معرّف.
- [ ] **Role** label is Arabic — never `admin` / `manager` / `owner` / `user` raw.
- [ ] Subscription card has elevated shadow.
- [ ] Plan features chips are **Arabic** — never `can_manage_devices` etc. raw.
- [ ] Mobile API sections chips are **Arabic** — never `auth` / `devices` etc. raw.
- [ ] Capabilities list shows green check / muted dash per capability.

## 9. Profile

- [ ] More → الملف الشخصي loads.
- [ ] Back button in AppBar points RTL-correctly (v68 default BackButton).
- [ ] Form fields: full name, email, phone, country, city, timezone, language, phone prefix.
- [ ] Save shows success / clear error.

## 10. Settings

- [ ] More → إعدادات التطبيق loads.
- [ ] Brand card has elevated shadow (Zynavolt + tagline).
- [ ] App-info card shows: version, platform (Arabic label), default locale, base URL.
- [ ] "تحقّق من الاتصال" button hits `/api/mobile/health` — green success banner.
- [ ] Active-device card shows current device or "لم يتم اختيار" state.
- [ ] Language card has the v70 polished iconified layout.

## 11. More tab IA

- [ ] Three section headers visible: **الحساب**, **التطبيق**, **التشخيص**.
- [ ] Account group: identity card → profile tile → loads tile → account/subscription tile.
- [ ] التطبيق group: settings tile → about card.
- [ ] التشخيص group: health-check card → collapsible developer info.
- [ ] Logout button at the bottom, red tone.

## 12. Visual gates

- [ ] **No English UI text** anywhere except: `Zynavolt` wordmark, `W` / `kW` / `kWh` / `%` units, and the API base URL in Settings.
- [ ] **No raw backend slugs**: `can_manage_*`, `can_use_*`, `auth`, `devices`, `dashboard`, `onboarding`, etc. — every chip / row in the app shows their Arabic label.
- [ ] **No layout overflow** on phones 5"–6.7" in either orientation portrait.
- [ ] **RTL alignment**: back arrows flip correctly, chevrons point inward correctly.
- [ ] **No silent blank screens** in any state (loading / error / empty / data) on any route.

## 13. Network & resilience

- [ ] Airplane-mode after sign-in → screens show calm "تعذّر الاتصال" error states with retry, no crash.
- [ ] Backend 5xx → screens show server-error state with retry, no crash.
- [ ] Token refresh on 401 → seamless retry; no surprise login redirect mid-session.

## 14. After-deploy gates

- [ ] `flutter analyze` passes locally with 0 issues.
- [ ] `flutter test` passes 75/75.
- [ ] `git status` clean before tagging.
- [ ] No `git add .` in the build branch history.
- [ ] No backend repo touched in the build branch.

---

## What this doc deliberately does not cover

* **Tablet / foldable layouts** — out of scope for v57–v80.
* **iOS** — Android-only target today.
* **Charts** — by project rule, no charts.
* **Push notifications** — not wired (no FCM by project rule).
* **Offline behaviour** — no offline DB.

When ready, paste a passing screenshot from each section into the
release tracker and tag the build.
