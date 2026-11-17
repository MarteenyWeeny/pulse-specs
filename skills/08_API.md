# 08 — API

**Purpose:** Contract conventions, response envelope, route inventory with role gating, sync payload rules, and common pitfalls for `pulse-api`.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. Route contracts derived from `pulse-specs/business-logic-v1.1.md` and `pulse-specs/db-design-choices.md`. The code wins (see 16).

## Standard Response Envelope

All `pulse-api` endpoints return JSON with a deterministic envelope so `pulse-web` and `pulse-android` share error and pagination handling:

```json
{
  "ok": true,
  "data": {},
  "meta": {
    "server_time": "2026-11-18T01:30:00Z",
    "next_cursor": null
  },
  "error": null
}
```

On error (`ok: false`):
```json
{
  "ok": false,
  "data": null,
  "meta": { "server_time": "2026-11-18T01:30:00Z" },
  "error": {
    "code": "POSTING_COOLDOWN_ACTIVE",
    "message": "Your account is in a temporary posting cooldown until 2026-11-25T00:00:00Z.",
    "details": { "cooldown_until": "2026-11-25T00:00:00Z" }
  }
}
```

## MVP Route Inventory & Access Levels

Access letters map to `pulse-specs/business-logic-v1.1.md` (`A` = System Admin, `B` = Admin, `C` = Moderator, `D` = Contributor, `E` = Guest):

| Method & Route | Access | Purpose |
|---|---|---|
| `GET /api/v1/catalog/gear` | `A,B,C,D,E` | Search/filter verified & crowd-submitted `gear_item` records |
| `GET /api/v1/notes` | `A,B,C,D,E` | Browse public listening notes via `v_public_listening_note` ($k \ge 5$ gated) |
| `GET /api/v1/spots` | `A,B,C,D,E` | List active, non-expired coarse-location pins via `v_active_local_spot_pin` |
| `POST /api/v1/auth/google` | `A,B,C,D` | Exchange Google Sign-In / Supabase token and upsert `account` |
| `POST /api/v1/sync/push` | `A,B,C,D` | Batch LWW push of dirty client rows (`audio_chain`, `listening_note`, etc.) |
| `GET /api/v1/sync/pull` | `A,B,C,D` | Delta pull (`?since=<ISO-8601>`) of user's rows + public catalog/notes |
| `POST /api/v1/privacy/consent` | `A,B,C,D` | Record or revoke granular RA 10173 consent in `data_consent_log` |
| `GET /api/v1/privacy/export` | `A,B,C,D` | Export authenticated user's personal journal & consent log (JSON/CSV) |
| `POST /api/v1/privacy/erase` | `A,B,C,D` | Soft-delete (`archived_at`) user's account and personal content |
| `POST /api/v1/moderation/gear-merge` | `A,B,C` | Set `canonical_gear_uuid` and `approved_by` on duplicate gear items |
| `POST /api/v1/moderation/hits` | `A,B,C` | Issue or resolve a `guideline_hit` and recalculate `posting_cooldown_until` |
| `GET /api/v1/admin/analytics` | `A,B` | Aggregated synergy metrics (strictly gated at $k \ge 5$ contributors) |
| `PUT /api/v1/admin/settings` | `A,B` | Upsert row-based platform configuration in `app_setting` |
| `POST /api/v1/system/backup` | `A` | Trigger database snapshot / maintenance operations |

## How to Add or Modify an Endpoint

1. Verify the required user level (`A`–`E`) in `pulse-specs/business-logic-v1.1.md`.
2. Validate request payloads with strict schema validators:
   - Reject any payload containing `id` or `synchronized_at` (or strip them before DB binding).
   - Reject any `local_spot_pin` payload containing raw decimal coordinates (`lat`/`lng`); accept only validated `coarse_city_code` strings.
3. Stamp actor columns (`created_by`, `approved_by`, `issued_by`) from `req.session.account_uuid`—never from `req.body` (see 04 #4).
4. Ensure public reads query `v_public_listening_note` and `v_active_local_spot_pin` so soft-deleted rows, moderator-hidden rows, expired pins, and sub-threshold `helpful_count` (`< 5`) are never serialized.

## Common API Mistakes

- **Forgetting to return unchanged UUIDs in `/api/v1/sync/push`**: If the server already has a row with `updated_at >= EXCLUDED.updated_at`, still include its `uuid` in `acknowledged_uuids` so the client marks its local row clean (`synchronized_at = updated_at`).
  - *Miss →* Infinite push retry loop on the client (see 05 #3).
- **Allowing `NULL` from an older client to wipe out a backfilled server column**: Use `COALESCE(EXCLUDED.<new_col>, table.<new_col>)` on newly added columns during transitional periods.
