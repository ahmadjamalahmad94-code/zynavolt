# Zynavolt Mobile — Design System (v58)

A pragmatic, **additive** design-system pass. v58 adds a small set of
semantic tokens to the existing `AppTheme` and to `AppCard` without
breaking anything that already shipped. Future polish phases (v59–v80)
pick these up to give the app a coherent premium feel.

This is not a "rip-up-and-rebuild" — every token below is a small
upgrade you can drop into existing screens one at a time.

---

## 1. Color palette (unchanged — for reference)

Defined in [lib/app/app_theme.dart](../../lib/app/app_theme.dart).

| Token | Value | Use |
| --- | --- | --- |
| `ink` | `#0F172A` | primary text |
| `softInk` | `#1E293B` | secondary text |
| `muted` | `#475569` | labels / muted body |
| `faintMuted` | `#64748B` | helper text / disabled |
| `line` | `#CBD5E1` | borders / dividers |
| `softBg` | `#F8FAFC` | page background |
| `surface` | `#FFFFFF` | card surface |
| `indigoPrimary` | `#4338CA` | brand primary |
| `indigoBright` | `#6366F1` | brand accent |
| `indigoSoft` | `#EEF2FF` | brand tint surface |
| `violet` | `#7C3AED` | secondary brand |
| `success` | `#16A34A` | OK / connected |
| `warning` | `#F59E0B` | caution / pending |
| `danger` | `#DC2626` | error / destructive |

Do not invent new colors. Reach for an existing token first.

## 2. Spacing scale (v58)

A 4 dp grid. Replace ad-hoc magic numbers with these where possible:

```
space2  space4  space6  space8  space10  space12
space14 space16 space20 space24 space32
```

Old `SizedBox(height: 12)` keeps working — the scale is a *preference*,
not an enforcement.

## 3. Radius scale (unchanged — for reference)

| Token | Value | Use |
| --- | --- | --- |
| `radiusInput` | `10` | TextField / chip |
| `radiusCard` | `12` | standard card |
| `radiusHero` | `14` | hero card |
| `radiusGlass` | `16` | glass surface |

## 4. Shadows (v58)

Indigo-tinted, so they feel like brand depth rather than generic grey.

| Token | Use |
| --- | --- |
| `softShadow` | subtle lift on featured cards |
| `liftedShadow` | hero / floating elements |

Apply via `AppCard(elevated: true)` or `boxShadow: AppTheme.softShadow`.

## 5. Gradients (v58)

| Token | Use |
| --- | --- |
| `brandGradient` | hero CTAs (indigoPrimary → indigoBright, top-right → bottom-left) |
| `pageBackdropGradient` | pale-indigo screen backdrop (used in Home, Splash, Login) |

## 6. Glass tokens (v58)

For cards layered on the gradient backdrop:

| Token | Value |
| --- | --- |
| `glassSurface` | `Colors.white.withValues(alpha: 0.96)` |
| `glassBorder` | `line` |

## 7. Cards

`AppCard` gains an optional `elevated: true` flag in v58 that applies
`AppTheme.softShadow`. Default is `false`, so every existing screen
remains visually identical.

For hero / featured surfaces, prefer `AppCard(elevated: true, …)` over
hand-rolling Container + BoxShadow.

## 8. Typography

Currently driven by the global `ThemeData.fontFamily = 'Roboto'`. Arabic
font (Cairo / Tajawal) is the long-term plan — see
[`mobile_release_readiness_v56.md`](mobile_release_readiness_v56.md)
§4.2 for the wiring recipe.

Per-screen TextStyle objects stay inline for now (no global token map) to
avoid an invasive rewrite. Phase v75 polishes the Arabic copy itself.

## 9. Arabic-first rule

Every visible string is Arabic. The only Latin tokens allowed are:

* the brand wordmark `Zynavolt`;
* technical units `W`, `kW`, `kWh`, `%`;
* the API base URL when shown in Settings (informational only).

## 10. Never-show-raw-keys rule

Backend slugs (`can_use_telegram`, `auth`, `loads`, …) must never reach
the UI as-is. Map them via a small label helper local to the feature
(see [`account_labels.dart`](../../lib/features/account/data/account_labels.dart)
for the pattern). Future features should drop their own thin helper if
they consume slug-typed payloads.

## 11. What v58 explicitly does not do

* No fonts bundled.
* No new packages.
* No screen redesigned.
* No theme color renamed.
* No widget API broken.
* No backend changes.

Polish phases v59–v80 use these tokens incrementally.
