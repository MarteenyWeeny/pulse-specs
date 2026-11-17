# 14 — Developer Workflows

**Purpose:** Step-by-step recipes for common engineering tasks in the Pulse ecosystem, linking the lockstep sets and failure stories each step guards against.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. The code wins (see 16).

## Recipe 1: Adding a New Table or Column (Guards against 04 #1, 06 #1, 06 #2)

1. **Create Forward Migration in `pulse-specs/db-schema/`**:
   - Bump PATCH version (`v1.0.0.sql` → `v1.0.1.sql`; see `db-design-choices.md` §9).
   - Include `id bigint GENERATED ALWAYS AS IDENTITY`, `uuid uuid NOT NULL UNIQUE`, `created_by`, `created_at`, `updated_at`, and `archived_at`.
   - Use `ADD COLUMN IF NOT EXISTS` and `CREATE INDEX IF NOT EXISTS`.
   - Backfill `updated_at` from `created_at` on existing rows so they do not re-sync unnecessarily.
2. **Update `pulse-api` Sync Layer**:
   - Add new columns to the push allowlist (excluding `id`, `synchronized_at`, and server-stamped `*_by` columns—see 04 #4).
   - Include the same-second delete tie-breaker in `ON CONFLICT (uuid) DO UPDATE`.
3. **Update `pulse-android` & `pulse-web` Local Schemas**:
   - Guard SQLite `ALTER TABLE` with `PRAGMA table_info(<table>)`.
   - Ensure local DAO mutations always bump `updated_at` and never write `synchronized_at`.
4. *Add what surprised you to `INBOX.md`.*

## Recipe 2: Exporting a Full SQL Snapshot from Supabase (Guards against `db-design-choices.md` §9)

1. Export the current schema from Supabase to `pulse-specs/db-schema/`.
2. Bump the **MINOR** version and reset PATCH to `0` (`v1.0.x.sql` → `v1.1.0.sql`).
3. Verify all `CREATE TABLE`, `CREATE INDEX`, and `DO $$ ... $$` enum blocks remain idempotent.
4. *Add what surprised you to `INBOX.md`.*

## Recipe 3: Committing and Atomically Pushing Across All 4 Repos (Guards against `git-guidelines.md`)

1. Check status across `pulse-specs`, `pulse-api`, `pulse-web`, and `pulse-android`.
2. Verify no AI agent is set as Git author or co-author (`git-guidelines.md` §Exclusion of AI Agent).
3. Format the commit message as `scope: Imperative summary` ($\le 50$ characters, sentence case, no trailing period):
   - Examples:
     - `pulse-specs: Add initial agent instructions and MVP specs`
     - `pulse-api: Add repository agent instructions`
     - `pulse-web: Add repository agent instructions`
     - `pulse-android: Add repository agent instructions`
4. Commit and push atomically across each repository with changes.
5. *Add what surprised you to `INBOX.md`.*

## Recipe 4: Cutting a Weekly Release Tag (Guards against `git-guidelines.md` §Release Tags)

1. Confirm local time is **Friday 5:00 PM or later** (never tag an ongoing ISO week early).
2. Identify the last commit of each ISO week that had at least one commit (skip weeks with zero commits).
3. Create an annotated tag on `release` (or per spec rules for `pulse-specs`) using `<prefix>.0X.Y.00Z` (`WPLS.01.0.001`, `BPLS.01.0.001`, `APLS.01.0.001`, `SPLS.01.0.001`).
4. Record the tag, ISO week, release date, and commit hash in `pulse-specs/git-guidelines.md`.
5. *Add what surprised you to `INBOX.md`.*
