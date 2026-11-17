# 11 — Testing

**Purpose:** Honest current coverage, what must be tested before promoting `main` → `beta` → `release`, manual offline-sync drills, and dimensions that break.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. At this planning stage, runtime application tests are not yet implemented; invariants below define required test coverage for `pulse-api`, `pulse-web`, and `pulse-android`. The code wins (see 16).

## Current Coverage Reality

- **`pulse-specs`**: Schema (`db-schema/v1.0.0.sql`), business logic (`business-logic-v1.1.md`), and environmental scan (`planning/sense-making.md`) are specified.
- **`pulse-api`, `pulse-web`, `pulse-android`**: Repositories currently contain `AGENTS.md` baselines awaiting MVP implementation. Zero automated unit/integration tests run yet.

## What Must Be Automated When Code Lands

1. **Schema Idempotency Test (`pulse-specs/db-schema/v1.0.0.sql`)**:
   - Execute `v1.0.0.sql` twice consecutively against a clean Postgres instance. Both runs must exit with `0` errors.
2. **LWW Sync & Conflict Matrix (`pulse-api`)**:
   - Newer `updated_at` overwrites older server row.
   - Older `updated_at` is ignored by the server, **and** its `uuid` is still returned in `acknowledged_uuids`.
   - Same-second edit vs soft-delete (`archived_at IS NOT NULL`) resolves in favor of the soft-delete (see 06 #5).
   - Client-supplied `id`, `created_by`, `approved_by`, and `issued_by` are stripped/ignored.
3. **Privacy & Solution Layer Guards (`pulse-api` & DB Views)**:
   - `v_public_listening_note` returns `NULL` for `visible_helpful_count` when `helpful_count` is `0`, `1`, `2`, `3`, or `4`, and returns `5` when `helpful_count = 5`.
   - `v_active_local_spot_pin` excludes rows where `expires_at <= now()` or `archived_at IS NOT NULL`.
   - `local_spot_pin` validator rejects strings resembling raw GPS coordinates (`lat,lng`).

## Manual Drills Before Promoting `main` → `beta`

1. **Airplane-Mode Commute Drill**:
   - Turn on Airplane Mode on `pulse-android`. Create a new `audio_chain`, draft a `listening_note`, attach two `synergy_tag` items, then soft-delete one tag. Disable Airplane Mode and verify `synchronized_at` matches `updated_at` across all rows and `pulse-web` renders the exact state.
2. **Child-Before-Parent Sync Drill**:
   - Push a `listening_note_tag` row before its parent `listening_note` row. Verify `pulse-api` accepts both without a `23503` FK failure and that a subsequent pull converges cleanly.
3. **Guideline Hit Cooldown Drill**:
   - Issue two `guideline_hit` records against a test Contributor account. Verify `pulse-api` rejects new public note pushes with `403 POSTING_COOLDOWN_ACTIVE` while still allowing local offline journaling.
