# Loads Recommendations — Backend Spec

**Status:** spec only — no backend code is being written yet.
**Audience:** the person (or LLM) who implements this on
`C:\Users\Ahmad\Desktop\solardeya\` (Flask + SQLAlchemy +
PostgreSQL on Render).
**Owner constraint:** the Flask backend is the **sole** source of
truth for the load-allowed / load-denied decision. No mobile-side
heuristics. No mock data. No `UserLoad` model change in this pass.
**Source of decision:** the existing `smart_engine` —
`build_smart_energy_advice()` in
`app/blueprints/smart_engine.py:412`. Same function the web
dashboard renders today. Mobile is a thin client over its output.

---

## 0. TL;DR

* Replace the stub body of `mobile_load_recommendations()` (lines
  ~2729 in `app/blueprints/mobile_api.py`) with real per-load
  allow/deny decisions derived from `smart_engine` output.
* No DB columns added. No web-template changes. No Flow Graph
  changes.
* New `app/services/loads_recommendations.py` helper isolates the
  decision logic so the blueprint stays a thin HTTP wrapper.
* Endpoint response gains a `decision` summary (mirroring
  `/insights` for context) + a per-load `items` array with
  `{load_id, name, power_w, priority, allowed, reason}` rows.
* Mobile consumer ships in a follow-up commit once the endpoint
  is live.

---

## 1. Goal

End-to-end story:

1. User opens Notifications → "اقتراحات ذكية" section on mobile.
2. Above the section, the Smart Decision Card already renders
   `/insights.energy_advice` (already shipped — calls out
   `headline` / `detail` / `level` / `generated_at`).
3. Below it, a "اقتراح الأحمال" sub-section shows two cards:
   * "مسموح الآن" — loads the system says are fine to run now.
   * "غير مسموح الآن" — loads the system says to defer.
4. The split is the backend's call, not the mobile's. Mobile only
   renders the names + counts.

Non-goals for this pass:
* Per-load schedule recommendations ("turn on at 14:00").
* User-defined load classes beyond the existing `UserLoad` rows.
* Load remote control / actuation.
* Loads recommendation history / trends.
* Per-load notifications.

---

## 2. Database

### 2.1 No model changes

`UserLoad` (`app/models.py:205`) already has everything the
decision needs:

```python
class UserLoad(db.Model):
    id          = db.Column(db.Integer, primary_key=True)
    user_id     = db.Column(db.Integer, nullable=True, index=True)
    device_id   = db.Column(db.Integer, nullable=True, index=True)
    name        = db.Column(db.String(120), nullable=False)
    power_w     = db.Column(db.Float,   nullable=False, default=0)
    priority    = db.Column(db.Integer, nullable=False, default=1)
    is_enabled  = db.Column(db.Boolean, nullable=False, default=True)
    created_at  = db.Column(db.DateTime, default=datetime.utcnow,
                            index=True)
```

* `is_enabled=False` → the user has hidden this load from
  recommendations entirely. Exclude from the response.
* `priority` → smaller is higher priority (1 = essential).
* `power_w` → instantaneous wattage the load draws when on.

No `is_allowed_now` column. The decision is computed at request
time, the same way `smart_engine` computes its advice — pure
function over current state. Storing it would create a stale-cache
problem.

### 2.2 No migration

`create_all()` at startup already covers the existing
`UserLoad` table. No `_migrate_database()` shim needed.

---

## 3. Decision logic

### 3.1 Inputs

`build_smart_energy_advice(latest, weather, settings, context)`
returns (see `smart_engine.py:412`):

| Key | Used by this spec? |
|---|---|
| `status_label` | Yes — exposed to mobile as `decision.headline` |
| `smart_warning` + `smart_recommendation` | Yes — combined as `decision.summary` |
| `decision_now` | Used to seed per-load `reason` text |
| `confidence_band` (`low` / `medium` / `high`) | Yes — exposed as `decision.confidence` |
| `predicted_next_hour_solar` | Yes — drives surplus calc |
| `predicted_next_hour_surplus` | Yes — drives surplus calc |
| `predicted_risk_code` / `predicted_risk_level` | Yes — informs the level mapping |
| `scenario_title` / `scenario_summary` | No — too verbose for the chip |

The endpoint also pulls the same `level` mapping the `/insights`
handler uses (`device_insights` in
`app/blueprints/mobile_devices_api.py:927`) so the two surfaces
agree on tone — `good` / `caution` / `warning` / `critical` /
`unknown`.

### 3.2 Algorithm

Per device, after fetching the user's enabled loads sorted by
`priority` ASC (highest priority first):

```
level = smart_engine.level (good / caution / warning / critical / unknown)
surplus_w = predicted_next_hour_surplus * 1000 if not None else 0
remaining_w = surplus_w

allowed = []
denied  = []

for load in loads_sorted_by_priority:

    # Hard kill-switch on critical: nothing runs.
    if level == 'critical':
        denied.append({**load, allowed: false,
                       reason: 'الحالة حرجة — يُفضَّل تأجيل كل الأحمال'})
        continue

    # Unknown level: be conservative — only essentials.
    if level == 'unknown':
        if load.priority <= 1:
            allowed.append({**load, allowed: true,
                            reason: 'حمل أساسي'})
        else:
            denied.append({**load, allowed: false,
                           reason: 'القرار غير محدد — أجِّل غير الضروري'})
        continue

    # Surplus-based decision for good / caution / warning.
    # 'good' allows wider headroom; 'warning' tightens it.
    headroom_factor = {
        'good':    1.0,
        'caution': 1.3,
        'warning': 1.8,
    }[level]
    needed_w = load.power_w * headroom_factor

    if remaining_w >= needed_w:
        allowed.append({**load, allowed: true,
                        reason: f'الفائض المتوقع كافٍ ({int(remaining_w)} و)'})
        remaining_w -= load.power_w
    else:
        # Heuristic-free essentials override: priority=1 always
        # runs unless level is critical (handled above).
        if load.priority <= 1:
            allowed.append({**load, allowed: true,
                            reason: 'حمل أساسي — مسموح رغم محدودية الفائض'})
        else:
            denied.append({**load, allowed: false,
                           reason: f'الفائض المتوقع لا يكفي ({load.power_w:.0f} و)'})
```

**Key properties:**

* Deterministic given the same `smart_engine` output + same
  `UserLoad` rows. Same call twice = same answer.
* Conservative on `unknown` and `critical` — never optimistic.
* Greedy on `good` / `caution` / `warning` — higher-priority
  loads consume surplus first, lower-priority get what's left.
* Surplus accounting in Watts (multiplied by 1000 because
  `predicted_next_hour_surplus` is in kW from `smart_engine`).
* Essentials (priority ≤ 1) get an override on non-critical
  levels so the user's must-run loads aren't denied for the wrong
  reason. Critical still wins because that's the entire point of
  the critical level.

**Edge cases:**

| Case | Behaviour |
|---|---|
| User has zero `is_enabled` loads | `items: []`, both summary buckets empty, `available: true` |
| `latest` reading is missing | `available: false`, `reason: 'reading_unavailable'` (same code `/insights` uses) |
| `predicted_next_hour_surplus` is `None` | Treat surplus as 0 W. Most loads will land in "denied" with `'unknown_surplus'` reason |
| Device unknown / not owned | `404` via existing `_device_allowed` guard |

---

## 4. Endpoint

**Path:** `GET /api/mobile/loads/recommendations`
**Handler:** `mobile_load_recommendations()` (existing — replace
the stub body)
**Auth:** Bearer token (existing `_require_bearer_user()` guard
unchanged)
**Query:** `device_id` (optional — when missing, default to the
user's preferred device, same as `/dashboard`)

### 4.1 Request

```
GET /api/mobile/loads/recommendations?device_id=12 HTTP/1.1
Authorization: Bearer <access_token>
```

### 4.2 Response — `available: true`

```json
{
  "available": true,
  "scope": {
    "mode": "device",
    "device_id": 12
  },
  "decision": {
    "headline": "🟡 احذر",
    "summary": "البطارية منخفضة — الفائض الشمسي المتوقع محدود.",
    "level": "warning",
    "confidence": "medium"
  },
  "items": [
    {
      "load_id": 21,
      "name": "ثلاجة",
      "power_w": 200,
      "priority": 1,
      "allowed": true,
      "reason": "حمل أساسي"
    },
    {
      "load_id": 24,
      "name": "غسالة",
      "power_w": 1200,
      "priority": 2,
      "allowed": true,
      "reason": "الفائض المتوقع كافٍ (1500 و)"
    },
    {
      "load_id": 27,
      "name": "فرن كهربائي",
      "power_w": 2500,
      "priority": 3,
      "allowed": false,
      "reason": "الفائض المتوقع لا يكفي (2500 و)"
    }
  ],
  "totals": {
    "enabled_load_count": 3,
    "allowed_count": 2,
    "denied_count": 1,
    "allowed_power_w": 1400,
    "denied_power_w": 2500
  },
  "generated_at": "2026-05-14T15:30:00Z"
}
```

### 4.3 Response — `available: false`

Same `reason` vocabulary the `/insights` handler uses, so the
mobile screen can share its copy table:

```json
{
  "available": false,
  "reason": "reading_unavailable",
  "message": "Latest reading is missing; cannot compute load recommendations.",
  "scope": { "mode": "device", "device_id": 12 },
  "totals": {
    "enabled_load_count": 3,
    "allowed_count": 0,
    "denied_count": 0,
    "allowed_power_w": 0,
    "denied_power_w": 0
  },
  "items": [],
  "generated_at": "2026-05-14T15:30:00Z"
}
```

### 4.4 Status codes

| Code | When |
|---|---|
| `200` | Always for the happy + non-fatal-unavailable paths |
| `401` | Bearer missing / invalid |
| `404` | Device id not owned by the user |
| `400` | `device_id` is non-numeric / malformed |
| `500` | Unexpected exception — should be unreachable; logs via the app logger |

---

## 5. Files to modify

| File | Change |
|---|---|
| `app/blueprints/mobile_api.py` | Replace the stub body of `mobile_load_recommendations()` (the function exists from line ~2729). Keep the existing auth guard + `device_id` resolution; delete the `mobile_recommendations_deferred` short-circuit; call into the new helper. |
| `app/services/loads_recommendations.py` | **New** — `build_loads_recommendations(user, device, latest, weather, settings) -> dict`. Contains the algorithm in §3.2. Pure function, no Flask context. |
| `tests/test_v102_loads_recommendations.py` | **New** — see §6. |
| `HEAVY_V10_5_X_LOADS_RECOMMENDATIONS_RELEASE_NOTES.md` | **New** at repo root, following the v10.5.X naming. Replace `X` with the next available suffix on `main` at implementation time. |

**Files NOT touched:**

* `app/models.py` — no schema change.
* `app/blueprints/notifications.py` — no rules / dispatcher change.
* `app/blueprints/smart_engine.py` — consumed read-only.
* `app/templates/**` — no web UI change. Flow Graph untouched.
* `app/static/css/**` — no styling change.

---

## 6. Test plan

Mirror `tests/test_v100_battery_lab_mobile.py` — module-level
imports, `_make_flask_app()` fixture, mock helpers where needed.

### 6.1 Pure-function tests (no DB)

For `build_loads_recommendations`:

1. **No loads** → `items: []`, all totals zero, `available: true`.
2. **Critical level** → every load denied with reason "الحالة حرجة".
3. **Unknown level + 2 loads (priority 1 and 3)** → priority-1
   allowed (essential), priority-3 denied.
4. **Good level, surplus 3000 W, three loads {500W p1, 1200W p2,
   2500W p3}** → all three allowed (surplus eats them in priority
   order). `remaining_w` calc verified.
5. **Warning level, surplus 1000 W, same three loads** → priority-1
   allowed (essential override), priority-2 allowed (surplus
   covers 1000 ≥ 1200 × headroom 1.8 = 2160? — let's compute:
   1.8 × 1200 = 2160; 1000 < 2160 → denied). Priority-3 denied.
   Adjust example numbers in the test until the headroom math is
   exercised; document the headroom factor as a known constant.
6. **Reading unavailable** → returns `available: false` envelope
   with `reason: 'reading_unavailable'`.

### 6.2 Endpoint registration + smoke

7. The path `/loads/recommendations` is in the mobile blueprint's
   allowed-methods registry (catch-all 404 guard) — mirror the
   `test_battery_lab_endpoint_registered_in_allowed_methods`
   pattern.

8. Calling the endpoint without a bearer token returns 401.

### 6.3 Manual test (Render shell)

After deploy:

```python
python3 -c "
from app import create_app
app = create_app()
with app.app_context():
    from app.services.scope import set_system_scope, reset_system_scope
    from app.services.loads_recommendations import build_loads_recommendations
    tokens = set_system_scope(user_id=1, device_id=1)
    try:
        from app.models import UserLoad, AppDevice
        # Fetch latest reading + weather + settings exactly the
        # same way mobile_api.py does for /dashboard.
        # ... (or invoke the endpoint via curl with a real bearer)
        ...
    finally:
        reset_system_scope(tokens)
"
```

Then curl with a real bearer:

```bash
curl -sS -H 'Authorization: Bearer <real-token>' \
  https://solardeye.onrender.com/api/mobile/loads/recommendations \
  | python -m json.tool
```

Expect `available: true` + non-empty `items` if the user has
loads + a recent reading.

---

## 7. Render rollout

1. Push to `main` → auto-deploy.
2. No new env vars. No new Secret File. No new dependencies.
3. From the Render shell, run the manual test in §6.3 to verify
   the endpoint returns real data for a known user/device.
4. On the mobile, the existing `LOADS_BACKEND_SPEC.md` consumer
   commit (separate, follow-up) replaces the
   `_LoadsRecommendationsPlaceholder` widget on
   `notifications_screen.dart` with a real
   `LoadsRecommendationsStrip` wired to a new
   `loadsRecommendationsProvider`.

**Roll-back:** revert the commit. The endpoint reverts to the
existing stub; the mobile placeholder continues to show "قيد
التطوير" until the next deploy. No data loss.

---

## 8. Hard constraints (owner-set)

| Constraint | How this spec honours it |
|---|---|
| Mobile-only? No — explicit backend phase | This whole document IS the backend phase |
| Flask backend is the sole decision source | Algorithm runs server-side in `loads_recommendations.py`, called by the existing mobile endpoint. Mobile has zero decision code. |
| No mobile heuristic | Confirmed — mobile only renders names + counts from the response |
| No mock data | All values come from `UserLoad` rows and `smart_engine` output. Empty states ship as `available: false` envelopes, not fake items. |
| No Flow Graph touch | This work doesn't touch `app/templates/**`, the web dashboard, or any flow-graph component. The only web-side file touched is `mobile_api.py` (which is a JSON API, not UI). |
| No web UI / web theme change | Confirmed. |
| Phase D / push wiring untouched | Confirmed — different code path entirely. |

---

## 9. Open questions for the implementer

1. The headroom factors in §3.2 (`1.0` / `1.3` / `1.8`) are
   defaults — the owner may want to tune them after the first
   real-device test. Make them module-level constants for easy
   tuning.

2. `priority <= 1` as the "essentials" cutoff is the simplest
   read. If the owner uses a different scale (e.g. some users put
   ALL loads at priority 1), expose `essential_priority_threshold`
   as a `Setting` row that defaults to 1 and let it be edited
   later — out of scope for this commit.

3. `predicted_next_hour_surplus` is documented in `smart_engine`
   as kilowatts. Verify the unit in a quick REPL before shipping
   so the `* 1000` conversion in the algorithm is correct.

4. Should the response cap `items` at some maximum (e.g. 50) to
   protect against pathological user accounts? Probably not
   needed today (no user has more than ~10 loads) — flag as a
   future-proofing question only.

5. Caching: should the endpoint cache the decision for 30 s per
   `(user_id, device_id)` to absorb tight-loop polling? Defer
   until we see real-world latency.

---

## 10. Done definition

* [ ] `app/services/loads_recommendations.py` exists with
      `build_loads_recommendations(...)`.
* [ ] `tests/test_v102_loads_recommendations.py` exists; all
      ~8 cases pass under pytest.
* [ ] `app/blueprints/mobile_api.py:mobile_load_recommendations`
      no longer returns the `mobile_recommendations_deferred`
      stub.
* [ ] Manual `curl` from §6.3 returns `available: true` for the
      owner's account + the device with active loads.
* [ ] `HEAVY_V10_5_X_LOADS_RECOMMENDATIONS_RELEASE_NOTES.md`
      committed on `main`.
* [ ] Mobile follow-up commit replaces
      `_LoadsRecommendationsPlaceholder` with the real
      `LoadsRecommendationsStrip` consumer.
