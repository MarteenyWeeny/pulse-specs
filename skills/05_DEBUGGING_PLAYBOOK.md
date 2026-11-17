# 05 — Debugging Playbook

**Purpose:** Fast symptom-to-cause lookup and diagnostic queries for debugging offline sync anomalies, Postgres errors, missing journal notes, and auth/moderation blocks.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. Symptoms and SQL queries verified against `db-design-choices.md` and `db-schema/v1.0.0.sql`. The code wins (see 16).

## Where the Logs and State Live

| Layer | Where to Inspect |
|---|---|
| **Supabase / PostgreSQL** | Supabase Dashboard → Database Logs & SQL Editor (`public.listening_note`, `public.audio_chain`, `public.gear_item`, `public.guideline_hit`) |
| **Backend API (`pulse-api`)** | Structured JSON server stdout/stderr logs (correlate via `request_id` and entity `uuid`) |
| **Android Client (`pulse-android`)** | Logcat (`tag:PulseSync`, `tag:PulseDb`) and App Inspection → Database Inspector (SQLite `synchronized_at` vs `updated_at`) |
| **Web Client (`pulse-web`)** | Browser DevTools → Application → IndexedDB / Local Storage & Network tab (`/api/v1/sync/*`) |

## Symptoms, Causes (by Frequency), and Diagnostic Shortcuts

### 1. `ERROR: 428C9: cannot insert a non-DEFAULT value into column "id"`
- **Cause #1 (95%)**: Client push payload included the local SQLite `id` column, and `pulse-api` passed it into `INSERT INTO public.<table>`. Every server table uses `id bigint GENERATED ALWAYS AS IDENTITY` (see 07).
- **Diagnostic Shortcut**: Check the push serializer in `pulse-android`/`pulse-web` and the column allowlist in `pulse-api`. Strip `id` and `synchronized_at` before building the SQL `INSERT`.

### 2. Local edit on Android/Web never appears on other devices (No error logged)
- **Cause #1 (70%)**: Local `UPDATE` modified `body` or `title` without bumping `updated_at`, so `synchronized_at <> updated_at` evaluated to `false` (see 06 #1).
- **Cause #2 (25%)**: Local code wrote `synchronized_at` directly during a save instead of leaving it for the sync ack handler.
- **Diagnostic Shortcut (SQLite)**:
  ```sql
  SELECT uuid, title, updated_at, synchronized_at
  FROM listening_note
  WHERE synchronized_at IS NULL OR synchronized_at <> updated_at;
  ```

### 3. Client retries pushing the exact same row on every sync cycle forever
- **Cause #1 (60%)**: Server rejected the update via `WHERE table.updated_at < EXCLUDED.updated_at` (because the server already had a newer or equal timestamp) and omitted the row's `uuid` from the `acknowledged_uuids` list.
- **Cause #2 (30%)**: Timestamp string normalization mismatch (`2026-11-18T01:00:00Z` vs `2026-11-18 01:00:00+00`) caused `synchronized_at = updated_at` to mismatch after pull.
- **Diagnostic Shortcut**: Ensure `pulse-api` acknowledges already-up-to-date UUIDs so the client marks them clean (`synchronized_at = COALESCE(updated_at, CURRENT_TIMESTAMP)`).

### 4. `ERROR: 23505: duplicate key value violates unique constraint "idx_listening_note_tag_live"`
- **Cause #1 (80%)**: Two clients linked the same `(listening_note_uuid, synergy_tag_uuid)` offline under different `uuid`s (natural-key collision—see 06 #3).
- **Diagnostic Shortcut (Postgres)**:
  ```sql
  SELECT uuid, listening_note_uuid, synergy_tag_uuid, archived_at
  FROM public.listening_note_tag
  WHERE listening_note_uuid = '<note-uuid>' AND archived_at IS NULL;
  ```
- **Fix**: Apply natural-key adoption on upsert/pull: match active link rows by `(listening_note_uuid, synergy_tag_uuid) WHERE archived_at IS NULL` and adopt the canonical `uuid`.

### 5. Deleted listening note or tag reappears after syncing with another device
- **Cause #1 (85%)**: A developer ran `DELETE FROM listening_note WHERE uuid = ?` instead of setting `archived_at` and bumping `updated_at`. Another client that still had the row pushed it back (see 06 #4).
- **Cause #2 (15%)**: Same-second edit and delete collided, and the upsert `WHERE` clause lacked the delete tie-breaker (`EXCLUDED.archived_at IS NOT NULL AND note.archived_at IS NULL AND note.updated_at <= EXCLUDED.updated_at`).

### 6. Contributor gets `403 Forbidden` when publishing a note (`POSTING_COOLDOWN_ACTIVE`)
- **Cause #1 (90%)**: Account has 2+ active `guideline_hit` records or `posting_cooldown_until > now()`.
- **Diagnostic Shortcut (Postgres)**:
  ```sql
  SELECT a.handle, a.active_hit_count, a.posting_cooldown_until, gh.rule_code, gh.severity, gh.expires_at
  FROM public.account a
  LEFT JOIN public.guideline_hit gh ON gh.target_account_uuid = a.uuid AND gh.archived_at IS NULL
  WHERE a.uuid = '<account-uuid>';
  ```
