# 15 — Known Limitations

**Purpose:** Honest inventory of architectural tradeoffs, deferred MVP features, and edge cases ordered by how likely they are to surprise an engineer.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. Derived from `pulse-specs/db-design-choices.md` and `pulse-specs/business-logic-v1.1.md`. The code wins (see 16).

## Limitations Ordered by Likelihood of Surprise

### 1. Whole-Row Last-Write-Wins (LWW) Overwrites Concurrent Field Edits
- **What happens**: If the same user edits `title` on `pulse-android` and `body` on `pulse-web` while both are offline, whichever device generated the later `updated_at` timestamp overwrites the entire `listening_note` row on sync (`db-design-choices.md` §6).
- **Why accepted**: Listening notes have a single author and rarely undergo simultaneous multi-device offline editing; row-level LWW avoids per-column timestamp bloat.

### 2. Fast Client Clock Wins LWW Conflicts
- **What happens**: Because `updated_at` is stamped by the client (`db-design-choices.md` §4 & §6), a device with a clock skewed into the future will win LWW conflicts until its clock is corrected.
- **Mitigation**: `pulse-api` returns `meta.server_time` in every response envelope (see 08) so clients can warn users when local clock drift exceeds 5 minutes.

### 3. Server Holds Temporary Orphan Rows When Children Arrive First
- **What happens**: Because server tables omit `REFERENCES` constraints (`db-design-choices.md` §3), a `listening_note_tag` or `chain_component` row can exist on the server before its parent `listening_note` or `audio_chain` arrives.
- **Mitigation**: All read queries must tolerate missing parents (`LEFT JOIN`), and clients run an orphan guard on pull (`db-design-choices.md` §3).

### 4. Sub-Threshold Helpfulness Counts ($k < 5$) Appear as `NULL`
- **What happens**: When 1 to 4 Contributors mark a note as *"Helped Me Decide"*, `v_public_listening_note.visible_helpful_count` returns `NULL` rather than the number (`db-schema/v1.0.0.sql`).
- **Why**: This is **not a bug**—it is a mandatory privacy-by-design aggregation threshold (`business-logic-v1.1.md` Required Solution Layers). UI components should render `"Gathering community impressions"` until `visible_helpful_count >= 5`.

## Deferred Outside MVP Scope (`pulse-specs/business-logic-v1.1.md`)

1. **Frequency-Response (FR) Graph Plotters & Parametric EQ Calculators**: Deliberately excluded to preserve the gatekeep-free, subjective listening journal identity.
2. **Direct User-to-User Messaging & P2P Marketplace Escrow**: Excluded to keep time-to-market fast and avoid financial/escrow liability.
3. **Public Follower Graphs, Karma Scores, & Convertible Rewards**: Permanently banned by the Required Solution Layers.

## Ranked Redesign Candidates (Post-MVP)

1. **Automated 90-Day Tombstone & Expired Pin Purge Job (`pg_cron`)**: Compact soft-deleted rows (`archived_at < now() - interval '90 days'`) and expired `local_spot_pin` rows once table volume grows.
2. **Per-Table Cursor Pagination on `/api/v1/sync/pull`**: Replace timestamp-only watermarks with composite `(updated_at, uuid)` cursors for large catalog pulls.
