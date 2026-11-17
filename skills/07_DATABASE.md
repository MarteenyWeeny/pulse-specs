# 07 — Database

**Purpose:** Reference for the Pulse offline-first database architecture (`pulse-specs/db-design-choices.md`) and the Supabase PostgreSQL schema (`pulse-specs/db-schema/v1.0.0.sql`). Read before writing any SQL query or migration.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. The code wins (see 16).

## Identity & Foreign Key Strategy

1. **Dual Keys on Every Table**:
   - `id bigint GENERATED ALWAYS AS IDENTITY NOT NULL` (Postgres) / `id INTEGER PRIMARY KEY` (SQLite): Server/local surrogate key used strictly for dense B-tree page locality and arrival order (`ORDER BY id`). **Never shared across the network.**
   - `uuid uuid NOT NULL UNIQUE`: Global 128-bit identity minted by the creating client (prefer UUID v7 for append-mostly B-tree inserts, or UUID v4).
2. **UUID-Native Foreign Keys (`*_uuid`)**:
   - All relationships store the parent's `uuid` (e.g., `chain_uuid`, `primary_transducer_uuid`, `paired_dac_amp_uuid`).
   - Server tables **intentionally omit `REFERENCES` constraints** so out-of-order child sync batches never fail (see 06 #2). Every `*_uuid` column used in scoped pulls or joins is indexed with `CREATE INDEX IF NOT EXISTS`.

## Table Map (`pulse-specs/db-schema/v1.0.0.sql`)

| Table / View | Domain Owner | Natural Key (Live Rows `WHERE archived_at IS NULL`) | Key Foreign UUIDs |
|---|---|---|---|
| `public.account` | Auth & Profile | `lower(handle)`, `auth_user_uuid` | `auth_user_uuid` |
| `public.data_consent_log` | RA 10173 Privacy | `(account_uuid, consent_scope)` | `account_uuid` |
| `public.gear_item` | Gear Catalog | `(lower(brand), lower(model_name), category)` | `canonical_gear_uuid`, `approved_by` |
| `public.audio_chain` | Rig Builder | `(uuid)` | `owner_account_uuid`, `source_gear_uuid`, `dac_amp_gear_uuid`, `transducer_gear_uuid`, `accessory_gear_uuid` |
| `public.chain_component` | Rig Slot Link | `(chain_uuid, gear_uuid, slot_type)` | `chain_uuid`, `gear_uuid` |
| `public.listening_note` | Listening Journal | `(uuid)` | `author_account_uuid`, `chain_uuid`, `primary_transducer_uuid`, `paired_dac_amp_uuid` |
| `public.synergy_tag` | Vocabulary | `lower(slug)` | — |
| `public.listening_note_tag` | Note Tag Link | `(listening_note_uuid, synergy_tag_uuid)` | `listening_note_uuid`, `synergy_tag_uuid` |
| `public.helpful_signal` | Feedback ($k \ge 5$) | `(listening_note_uuid, voter_account_uuid)` | `listening_note_uuid`, `voter_account_uuid` |
| `public.local_spot_pin` | Coarse Audition Pins | `(uuid)` | `gear_uuid`, `chain_uuid` |
| `public.guideline_hit` | Moderation Hits | `(uuid)` | `target_account_uuid`, `listening_note_uuid`, `gear_uuid`, `issued_by` |
| `public.app_setting` | System Config | `(feature, name)` | — |
| `public.v_public_listening_note` | Privacy View | Masks `helpful_count < 5` as `NULL` | Filters `archived_at IS NULL AND is_public = true` |
| `public.v_active_local_spot_pin` | Retention View | Enforces `expires_at > now()` | Filters `archived_at IS NULL` |

## Integrity Invariants & Soft Deletes

- **Soft Delete Only (`archived_at`)**: Deleting any row sets `archived_at = now()` and bumps `updated_at`.
  - *Miss →* Physical `DELETE` leaves no tombstone, causing other clients to re-upload the deleted row (see 06 #4).
- **Live-Row Partial Unique Indexes**: Every business uniqueness rule uses `CREATE UNIQUE INDEX ... WHERE archived_at IS NULL` so archived history never blocks recreating a link or handle.
- **Dirty Sync Invariant**:
  - Client dirty predicate: `synchronized_at IS NULL OR synchronized_at <> updated_at`.
  - Server LWW predicate: `WHERE table.updated_at < EXCLUDED.updated_at OR (EXCLUDED.archived_at IS NOT NULL AND table.archived_at IS NULL AND table.updated_at <= EXCLUDED.updated_at)`.

## Schema Migration & Versioning Strategy (`pulse-specs/db-design-choices.md` §9)

- **Forward migrations (`v1.0.0 --> v1.0.1 --> v1.0.2`)**: Bump the **PATCH** number when a developer or AI agent adds or alters tables/columns. Every script must be idempotent (`CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`).
- **Full SQL snapshots (`v1.0.0 --> v1.1.0 --> v1.2.0`)**: Bump the **MINOR** number (and reset PATCH to `0`) when exporting a complete schema snapshot from Supabase to local.
- **Backfilling Change Columns**: When adding a new table or change column, backfill `updated_at` from `created_at` so existing rows do not appear dirty all at once.

## Dangerous Operations

1. **Mass-unarchiving (`UPDATE ... SET archived_at = NULL`)**: Pushing unarchived rows resurrects tombstones across every synced client.
2. **Dropping or renaming a column in place**: Breaks older Android/Web clients that still send or read the column. Always add the new column, backfill, mark the old column legacy, and drop only after all clients upgrade.
3. **Manual SQL edits on Supabase without bumping `updated_at`**: Clients will never pull the manual edit, and the next client push will overwrite it.
