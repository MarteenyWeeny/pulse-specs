# 16 — Engineering Principles

**Purpose:** Numbered, quotable engineering rules that govern every decision in the Pulse (`pulse` / `PLS`) ecosystem, each backed by its reasoning and source story.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18.

## Principles

### Principle #1: Server `id` is for the B-tree; `uuid` is for the world.
- **Reasoning**: Sequential `bigint` primary keys (`id GENERATED ALWAYS AS IDENTITY`) keep PostgreSQL B-tree pages dense and record arrival order, while client-minted `uuid`s allow offline creation without central coordination. Mixing them causes cross-device collisions and enumeration vulnerabilities.
- **Evidence / Source**: `pulse-specs/db-design-choices.md` §2 & §3; `pulse-specs/db-schema/v1.0.0.sql`.

### Principle #2: Every local mutation bumps `updated_at`, and only sync writes `synchronized_at`.
- **Reasoning**: Dirty synchronization (`synchronized_at IS NULL OR synchronized_at <> updated_at`) has no separate outbox queue to drift out of step—the row itself is the queue. Breaking either half silently strands edits on the client forever.
- **Evidence / Source**: `pulse-specs/db-design-choices.md` §6; Incident 06 #1.

### Principle #3: Deletes are tombstones (`archived_at`), never physical `DELETE`s.
- **Reasoning**: In an offline-first system, a physical `DELETE` leaves nothing to sync; the next offline client that comes online will push the deleted row straight back to life. Setting `archived_at` and using partial unique indexes (`WHERE archived_at IS NULL`) lets deletions travel cleanly without blocking future rows.
- **Evidence / Source**: `pulse-specs/db-design-choices.md` §5; Incident 06 #4.

### Principle #4: The server stamps the actor (`created_by`, `approved_by`, `issued_by`), never the client.
- **Reasoning**: Attribution columns determine who can edit a listening note, who approved a gear item, and who issued a moderation hit. Accepting actor UUIDs from client payloads lets any client spoof ownership or moderator authority.
- **Evidence / Source**: `pulse-specs/db-design-choices.md` §4; Lockstep Set 04 #4.

### Principle #5: Protect privacy and community health structurally, not by policy promises.
- **Reasoning**: Raw GPS coordinates cannot leak if the schema only stores `coarse_city_code`; small cohorts cannot be re-identified if `v_public_listening_note` masks counts where `helpful_count < 5`; karma farming and affiliate shilling cannot take root when public reputation scores and financial rewards do not exist in the data model.
- **Evidence / Source**: `pulse-specs/business-logic-v1.1.md` Required Solution Layers; `pulse-specs/db-schema/v1.0.0.sql` §9.

### Principle #6: Schema changes are additive, idempotent, and deployed before the code that reads them.
- **Reasoning**: Offline mobile and web clients upgrade on their own schedule. Additive migrations (`ADD COLUMN IF NOT EXISTS`), null-preserving server upserts, and strict `v1.0.x` (migration) vs `v1.x.0` (snapshot) versioning ensure old and new clients coexist safely.
- **Evidence / Source**: `pulse-specs/db-design-choices.md` §9; Lockstep Set 04 #1.

### Principle #7: Trust the code over any document, including this one.
- **Reasoning**: Specifications and skills documents capture intent and design scars, but running code and applied SQL schemas are the ground truth. Whenever a document disagrees with the code or schema, verify the behavior and fix the stale document in the same change.
- **Evidence / Source**: `handoff.md` §Standards.
