# 04 — Change Rules & Lockstep Sets

**Purpose:** Inventory of lockstep sets across `pulse-specs`, `pulse-api`, `pulse-web`, and `pulse-android`. Consult this before changing any table, enum, sync payload, privacy threshold, or commit scope.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. The code wins (see 16).

## Lockstep Sets

### Lockstep Set #1: Synced Table Columns & Tombstone Indexes
When adding or altering a column on any offline-synced table (`account`, `data_consent_log`, `gear_item`, `audio_chain`, `chain_component`, `listening_note`, `synergy_tag`, `listening_note_tag`, `helpful_signal`, `local_spot_pin`):

1. `pulse-specs/db-schema/v1.0.x.sql` — Add the column idempotently (`ALTER TABLE ... ADD COLUMN IF NOT EXISTS`), backfill existing rows, and add any index.
2. `pulse-api/` sync allowlist & upsert query — Add the column to the push `INSERT ... ON CONFLICT (uuid) DO UPDATE` statement (preserving `COALESCE` for backfilled columns so old clients sending `NULL` do not erase server data) and the pull `SELECT` projection.
3. `pulse-android/` SQLite migration chain — Guard with `PRAGMA table_info(<table>)` before running `ALTER TABLE ... ADD COLUMN`.
4. `pulse-web/` local cache schema & TypeScript DTOs — Add the field as optional/defaulted to tolerate older cached records.
- *Miss →* If added to client SQLite before `pulse-api` and Postgres, pushed values are silently dropped on the server while the client marks `synchronized_at = updated_at` (clean), permanently losing the user's data on other devices (see 06 #2).

### Lockstep Set #2: Closed-Vocabulary Enums
Six PostgreSQL enums live in `pulse-specs/db-schema/v1.0.0.sql`:
- `user_level_enum` (`system_admin`, `admin`, `moderator`, `contributor`, `guest`)
- `gear_category_enum` (`iem`, `headphone`, `dac_dongle`, `amplifier`, `dap_source`, `cable_tip_accessory`, `speaker`)
- `budget_tier_enum` (`budget`, `entry_mid`, `mid_fi`, `upper_mid`, `summit_fi`)
- `chain_slot_enum` (`source`, `dac_amp`, `transducer`, `accessory`)
- `synergy_verdict_enum` (`aha_synergy`, `noticeable_upgrade`, `subtle_difference`, `neutral_pairing`, `poor_match`)
- `guideline_hit_severity_enum` (`hit_1_notice`, `hit_2_cooldown`, `hit_3_restricted`)

Update in lockstep across:
1. `pulse-specs/db-schema/v1.0.x.sql` (`ALTER TYPE ... ADD VALUE IF NOT EXISTS`)
2. `pulse-api/` validator schemas
3. `pulse-web/` TypeScript union types and filter UI
4. `pulse-android/` Kotlin enum classes and SQLite `CHECK` constraints
- *Miss →* An older client pulling a new enum value crashes during deserialization, or a new client pushing an unmigrated enum value causes the entire push batch to fail with Postgres error `22P02` (`invalid input value for enum`).

### Lockstep Set #3: Denormalized Read Shortcuts on `audio_chain` and `listening_note`
- `audio_chain` stores `source_gear_uuid`, `dac_amp_gear_uuid`, `transducer_gear_uuid`, and `accessory_gear_uuid` alongside `chain_component` link rows.
- `listening_note` stores `primary_transducer_uuid` and `paired_dac_amp_uuid` alongside `chain_uuid`.
- **Rule**: Whenever a user updates the primary transducer or DAC/amp in an `audio_chain`, update both `audio_chain`, `chain_component`, and any draft `listening_note` shortcut columns in **one local transaction** and bump `updated_at` on each touched row.
- *Miss →* Pairing filter queries (`idx_listening_note_pairing_live`) return stale gear pairings that disagree with the chain detail view.

### Lockstep Set #4: Server-Stamped Attribution Allowlist
- Columns `created_by`, `approved_by`, `issued_by`, and `resolved_by` across all tables in `pulse-specs/db-schema/v1.0.0.sql`.
- **Rule**: Exclude these columns from client push payloads and bind them strictly from the verified session account UUID in `pulse-api`.
- *Miss →* Privilege escalation: a client could forge `approved_by` on `gear_item` or `created_by` on another user's `listening_note`.

### Lockstep Set #5: Privacy & Moderation Threshold Constants
- $k \ge 5$ aggregation threshold (`v_public_listening_note.visible_helpful_count` in `v1.0.0.sql`, `business-logic-v1.1.md` Required Solution Layers, and `app_setting` key `k_anonymity_threshold`).
- Guideline hit thresholds (1 = notice, 2 = 7-day cooldown, 3 = restricted; 90-day decay) in `business-logic-v1.1.md` and `pulse-api` moderation service.
- *Miss →* API endpoints and database views disagree on when `helpful_count` becomes visible or when `posting_cooldown_until` is enforced.

## High-Risk Areas & Retest Checklist

| Area Changed | What to Retest Before Merging |
|---|---|
| Sync upsert query (`ON CONFLICT (uuid)`) | 1) Same-second edit vs soft-delete tie-breaker; 2) Out-of-order child-before-parent push; 3) Null-backfill preservation |
| Public note discovery query | Verify archived rows (`archived_at IS NOT NULL`), moderator-hidden notes (`is_hidden_by_moderator = true`), and `helpful_count < 5` are never leaked |
| Local spot pins (`local_spot_pin`) | Verify expired pins (`expires_at <= now()`) disappear and raw GPS lat/lng strings are rejected |
| Schema version bump | Verify `pulse-specs/db-design-choices.md` and `pulse-specs/db-schema/` follow `v1.0.x` (migration) vs `v1.x.0` (snapshot) |
