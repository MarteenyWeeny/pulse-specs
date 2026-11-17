# 06 — Failure Stories

**Purpose:** Concrete failure modes and design scars behind our database, sync, and privacy rules. Read these before simplifying a guard in `db-design-choices.md` or `db-schema/v1.0.0.sql`.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. Reconstructed from the architectural scars documented in `pulse-specs/db-design-choices.md` and `pulse-specs/business-logic-v1.1.md`. The code wins (see 16).

## Incident #1: The Silent Unbumped Edit (Confidence: Verified pattern from `db-design-choices.md` §6)

- **What happened**: A user edited the `body` of a saved `listening_note` offline on Android, then synced online. The note never updated on the web app, and no error was thrown.
- **Why**: The DAO update statement ran `UPDATE listening_note SET body = ? WHERE uuid = ?` without updating `updated_at`. Because `synchronized_at` still equaled `updated_at` from the initial sync, the dirty gate (`synchronized_at IS NULL OR synchronized_at <> updated_at`) saw the row as clean and skipped it forever.
- **How it was found**: Comparing local SQLite rows against Postgres showed identical `updated_at` and `synchronized_at` timestamps despite differing `body` text.
- **Fix & Lesson**: Every local mutation (insert, edit, or soft-delete) **must** bump `updated_at`, and **only** the sync engine may write `synchronized_at` (see 07, 16 #2).

## Incident #2: Out-of-Order Child Sync Batch Failure (Confidence: Verified pattern from `db-design-choices.md` §3)

- **What happened**: A user created a new `audio_chain`, a `listening_note`, and three `listening_note_tag` rows offline. During sync, the `listening_note_tag` batch arrived at the API before the `listening_note` batch. With a strict PostgreSQL `REFERENCES listening_note(uuid)` foreign key, the entire batch failed with `23503 foreign_key_violation`.
- **Why**: Offline sync queues do not guarantee strict parent-first delivery across network retries and partial permission scopes.
- **How it was found**: Server error logs showed `insert or update on table "listening_note_tag" violates foreign key constraint`.
- **Fix & Lesson**: Omit server-side `REFERENCES` constraints on offline-synced `*_uuid` columns (`pulse-specs/db-schema/v1.0.0.sql`). Enforce foreign keys in local SQLite and use an orphan guard on client pull so out-of-order rows land safely on the server and converge once the parent arrives (see 07).

## Incident #3: Dual-Client Natural Key Split on Link Tables (Confidence: Verified pattern from `db-design-choices.md` §3 & §5)

- **What happened**: A user tagged the same `listening_note` with `"opened-up-soundstage"` on both their phone and laptop while offline. Each device minted a different `uuid` for the `listening_note_tag` row. When both synced, the second push hit `idx_listening_note_tag_live` (`UNIQUE (listening_note_uuid, synergy_tag_uuid) WHERE archived_at IS NULL`).
- **Why**: Link tables have both a surrogate global identity (`uuid`) and a natural composite key (`listening_note_uuid`, `synergy_tag_uuid`).
- **How it was found**: Unique index violation `23505` on `idx_listening_note_tag_live` during push.
- **Fix & Lesson**: On push/pull of link tables (`chain_component`, `listening_note_tag`, `helpful_signal`, `gear_item`), adopt the existing live row's `uuid` when the natural key matches (`WHERE archived_at IS NULL`) instead of inserting a duplicate.

## Incident #4: Zombie Rows Resurrected After Physical `DELETE` (Confidence: Verified pattern from `db-design-choices.md` §5)

- **What happened**: A user deleted a draft `audio_chain` on Device A. Device B synced later and pushed the deleted `audio_chain` right back to the server, resurrecting it on Device A.
- **Why**: Device A ran a physical SQL `DELETE`. With no row left in the table, Device A had nothing to push, and Device B treated its copy as valid live data.
- **How it was found**: Deleted records kept reappearing whenever a secondary client came online.
- **Fix & Lesson**: Never run physical `DELETE` on synced tables. Set `archived_at = now()` and bump `updated_at` so the deletion travels as a tombstone to every client (see 07, 16 #3).

## Incident #5: Same-Second Edit vs. Delete Race in SQLite (Confidence: Verified pattern from `db-design-choices.md` §6)

- **What happened**: An automated cleanup or fast user action edited a note and immediately soft-deleted it within the same second on a client with 1-second timestamp precision. The server rejected the soft-delete because `note.updated_at < EXCLUDED.updated_at` was false (`updated_at == EXCLUDED.updated_at`).
- **Why**: Strict `<` comparison drops same-second updates.
- **Fix & Lesson**: In every server LWW upsert, include the delete tie-breaker: `OR (EXCLUDED.archived_at IS NOT NULL AND table.archived_at IS NULL AND table.updated_at <= EXCLUDED.updated_at)` (see 07).
