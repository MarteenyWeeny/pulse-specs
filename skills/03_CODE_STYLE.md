# 03 — Code Style

**Purpose:** Coding conventions, comment philosophy, naming, error handling, logging, banned anti-patterns, and Git commit standards across the Pulse ecosystem.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. The code wins (see 16).

## Comment Philosophy: Write the *Why* at the Line

- Explain **why** a guard, tie-breaker, or filter exists and **what breaks** if someone removes it. Never restate what the syntax already says.
- Good example (from `pulse-specs/db-design-choices.md` §6):
  ```sql
  -- SQLite timestamps have one-second precision, so an edit and a delete in the
  -- same second share a stamp; let the delete win a same-second tie.
  OR (EXCLUDED.archived_at IS NOT NULL AND note.archived_at IS NULL AND note.updated_at <= EXCLUDED.updated_at)
  ```
- Tag temporary compromises with `TODO(<owner>, <issue>): <why and when to remove>` so `grep` finds them during skills refreshes.

## Naming & Schema Mirroring Rules

1. **Exact Table and Column Parity**:
   - SQLite tables in `pulse-android`, client models in `pulse-web`, and PostgreSQL tables in `pulse-specs/db-schema/v1.0.0.sql` must use the **exact same `snake_case` table and column names** (`listening_note`, `primary_transducer_uuid`, `updated_at`, `archived_at`).
   - *Reason:* Generic sync mappers map fields by column name. Renaming `archived_at` to `isDeleted` on a client breaks tombstone propagation (see 04 #1).
2. **Closed Vocabularies**:
   - Mirror PostgreSQL `ENUM` values (`user_level_enum`, `gear_category_enum`, `budget_tier_enum`, `chain_slot_enum`, `synergy_verdict_enum`, `guideline_hit_severity_enum`) identically in TypeScript (`pulse-web`/`pulse-api`) and Kotlin (`pulse-android`).

## Error Handling & Logging

- **Explicit Sync Outcomes**: Every batch push response must return per-row or batch-level accepted UUIDs so the client knows which rows can have `synchronized_at` updated. Never silently swallow a rejected row.
- **Orphan Tolerance on Read**: Because server tables omit `REFERENCES` constraints to allow out-of-order syncs, queries joining parent tables (`gear_item`, `audio_chain`) must handle missing parents gracefully (`LEFT JOIN` or fallback labels) rather than throwing a null-pointer crash.
- **Privacy-Safe Logging**:
  - Never log OAuth tokens, Google Sign-In ID tokens, database connection strings, or raw client IP/location coordinates.
  - Log `uuid` and `rule_code` when debugging sync or moderation actions, never personal user trails (see 09).

## Banned Anti-Patterns

| Anti-Pattern | Cost / What Breaks | Preferred Pattern |
|---|---|---|
| Sending `id` in API/sync payloads | Collides across SQLite and Postgres counters or triggers `GENERATED ALWAYS` errors | Send `uuid` and `*_uuid` only; strip `id` at the serialization boundary |
| Trusting client-supplied `created_by`, `approved_by`, or `issued_by` | Any client can spoof authorship or moderator approval | Stamp actor UUIDs on the server from the verified session token |
| Executing physical `DELETE FROM` on synced tables | Deleted row vanishes without a tombstone; other clients re-push it back to life | Set `archived_at = now()` and bump `updated_at` |
| Using `synchronized_at < updated_at` for dirty checks | Breaks on ISO-8601 string formatting differences (`Z` vs `+00:00`) | Use `synchronized_at IS NULL OR synchronized_at <> updated_at` |
| Exposing `helpful_count` directly from `listening_note` | Violates the $k \ge 5$ aggregation threshold in Required Solution Layers | Query `v_public_listening_note` (`visible_helpful_count`) or gate in API serializer |

## Commit Conventions (`pulse-specs/git-guidelines.md`)

1. **Format**: `scope: Imperative summary` (Line 1 **must be $\le 50$ characters**, sentence case, no trailing period).
   - *Miss →* Commit hooks and release changelog parsers reject messages over 50 chars or written in past tense (`Added` instead of `Add`).
2. **Scopes**:
   - Product + feature: `pulse-api/<feature>:`, `pulse-web/<feature>:`, `pulse-android/<feature>:`, `pulse-specs/<feature>:`.
   - Approved features: `auth`, `sync`, `security`, `backup`, `restore`, `gear`, `chains`, `journal`, `discover`, `spots`, `moderation`, `compliance`, `analytics`.
   - Spec-kind scopes (in `pulse-specs`): `requirements`, `design`, `schema`, `contracts`.
3. **Exclusion of AI Agent**:
   - Never add any AI agent as author or `Co-authored-by` of any commits, tags, releases, or PRs (`pulse-specs/git-guidelines.md` §Part 1).
