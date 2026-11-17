# 12 — Performance

**Purpose:** Database indexing strategy, B-tree locality, sync payload bounds, deliberate inefficiencies to leave alone, and expensive operations to avoid.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. Derived from `pulse-specs/db-design-choices.md` and `pulse-specs/db-schema/v1.0.0.sql`. The code wins (see 16).

## Database & Sync Hot Paths

1. **Dense Primary Key B-Tree (`id bigint GENERATED ALWAYS AS IDENTITY`)**:
   - Every table in `pulse-specs/db-schema/v1.0.0.sql` clusters on an 8-byte sequential `bigint` primary key (`id`) so inserts always append at the right edge of the B-tree without random page splits (`db-design-choices.md` §2).
   - **Optimization**: Mint **UUID v7** (time-ordered) on clients so the secondary `UNIQUE (uuid)` index also inserts append-mostly.
2. **Delta Pull Watermark (`idx_<table>_updated_at`)**:
   - Every synced table indexes `updated_at` (`idx_account_updated_at`, `idx_gear_item_updated_at`, `idx_audio_chain_updated_at`, `idx_listening_note_updated_at`, `idx_local_spot_pin_updated_at`, `idx_guideline_hit_updated_at`) so `GET /api/v1/sync/pull?since=<timestamp>` performs an index range scan rather than a sequential table scan.
3. **Denormalized Pairing Shortcuts (`idx_listening_note_pairing_live`)**:
   - `listening_note` carries `primary_transducer_uuid` and `paired_dac_amp_uuid` directly (`db-schema/v1.0.0.sql` lines 253–254) with a partial composite index `WHERE archived_at IS NULL AND is_public = true AND is_hidden_by_moderator = false`.
   - *Why:* Filtering notes for *"How does IEM X sound with Dongle Y?"* hits a single partial index without joining `audio_chain` and `chain_component`.

## Deliberate Inefficiencies to Leave Alone

1. **Dual Unique Indexes (`id` and `uuid`) on Every Server Table**:
   - Maintaining two unique indexes per table costs extra write I/O on Postgres. Do **not** drop `id` (which would fragment the primary key B-tree) or `uuid` (which sync lookups require).
2. **Stored `helpful_count` Aggregate on `listening_note`**:
   - Kept on the row so list queries do not run `COUNT(*) GROUP BY` over `helpful_signal` on every page load (`db-design-choices.md` §8).

## Expensive Operations to Avoid

- **Unbounded Pulls Without a `since` Watermark**: Initial client bootstrap should paginate by `(updated_at, uuid)` in batches of $\le 500$ rows.
- **SQLite Table Rebuilds on Android**: Never run a migration that copies a million-row table on the main UI thread; keep client migrations additive (`ALTER TABLE ... ADD COLUMN`) inside a background coroutine/worker.
