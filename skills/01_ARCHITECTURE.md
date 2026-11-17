# 01 — Architecture

**Purpose:** High-level mental model of the Pulse (`pulse` / `PLS`) ecosystem, component ownership, end-to-end data flows, hard boundaries, and architectural decision records (ADRs). Read this before touching any repository.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. The code wins (see 16).

## One-Paragraph Model

Pulse is an **offline-first, community-driven audiophile listening journal and gear-pairing platform** spanning four repositories: `pulse-specs` (authoritative specs and SQL schemas), `pulse-android` (Kotlin client with local SQLite storage), `pulse-web` (Next.js web client and RA 10173 regulatory compliance portal), and `pulse-api` (backend sync and moderation gateway fronting Supabase PostgreSQL). Clients write audio chains (`audio_chain`), subjective listening notes (`listening_note`), and gear submissions (`gear_item`) locally using client-minted UUIDs, then synchronize asynchronously with `pulse-api` via last-write-wins (`updated_at` vs `synchronized_at`) dirty sync. Privacy and anti-gatekeeping rules are enforced structurally: coarse city codes replace GPS coordinates, aggregated metrics require $k \ge 5$ contributors, and internal `guideline_hit` records replace public user karma.

## Components and Ownership

| Component | Repository | Prefix | What It Owns | What It Must Never Own |
|---|---|---|---|---|
| **Specifications** | `pulse-specs/` | `SPLS` | Business logic (`business-logic-v1.1.md`), DB schemas (`db-schema/v1.0.0.sql`), git rules, environmental scanning, and `skills/` | Runtime application code or secrets |
| **Backend API** | `pulse-api/` | `BPLS` | Google Sign-In session verification, LWW push/pull sync arbitration, server-stamped attribution (`created_by`, `approved_by`, `issued_by`), $k \ge 5$ privacy gating, and Supabase service-role communication | Unvalidated client `created_by` or raw `id` values |
| **Web Client** | `pulse-web/` | `WPLS` | Next.js web journal/discovery UI, local IndexedDB/SQLite cache, and mandatory RA 10173 regulatory compliance & data-rights pages | Direct service-role database credentials |
| **Android Client** | `pulse-android/` | `APLS` | Offline-first Kotlin mobile app, local SQLite storage (`synchronized_at`), signal-chain rig builder, and journal drafting | Server-only `id` references or precise GPS coordinates |

## End-to-End Data Flows

1. **Offline Creation & Local Edit (`pulse-android` / `pulse-web`)**:
   - Client mints a UUID v4/v7 for a new `audio_chain` or `listening_note`, sets `created_at` and `updated_at` to current ISO-8601 UTC timestamp, and leaves `synchronized_at` as `NULL`.
   - *Miss →* If a local edit fails to bump `updated_at`, the dirty check (`synchronized_at IS NULL OR synchronized_at <> updated_at`) never triggers and the edit is silently stranded on the device (see 06 #1, 07).
2. **Push Phase (Client → `pulse-api` → Supabase Postgres)**:
   - Client queries all rows where `synchronized_at IS NULL OR synchronized_at <> updated_at` and sends them in a batch without `id` or `synchronized_at`.
   - `pulse-api` authenticates the Google Sign-In session, stamps `created_by` from the session account UUID, and executes an `INSERT ... ON CONFLICT (uuid) DO UPDATE WHERE table.updated_at < EXCLUDED.updated_at` (with delete tie-breaker).
   - Client receives accepted UUIDs and sets `synchronized_at = COALESCE(updated_at, CURRENT_TIMESTAMP)`.
3. **Pull Phase (Supabase Postgres → `pulse-api` → Client)**:
   - Client requests rows updated since its last pull watermark, gated by visibility (`archived_at` tombstones included so deletes travel; `helpful_count` masked when `< 5`).
   - Client skips overwriting any local row that is currently dirty (`synchronized_at IS NULL OR synchronized_at <> updated_at`) and applies orphan guards if a parent UUID has not arrived yet.

## Hard Boundaries

- **Server `id` Never Travels**: `id bigint GENERATED ALWAYS AS IDENTITY` is for Postgres B-tree locality only. API payloads use `uuid` and `*_uuid` exclusively (see 07).
- **No Raw GPS Coordinates**: Clients must resolve location to a coarse `coarse_city_code` before storing or syncing `local_spot_pin` rows (see 09).
- **No Public Karma or Financial Rewards**: Never expose `active_hit_count` publicly or build leaderboards, point balances, or affiliate links (see `business-logic-v1.1.md`).

## Decision Records

### Decision: Offline-first UUID-native sync with server-only surrogate `id` (2026-11-18, Pulse Team)
**Status:** accepted
**Context:** Hobbyists log listening notes during commutes or at meetups with spotty connectivity, requiring offline creation without central ID coordination.
**Choice:** Every table pairs a server-only `id bigint GENERATED ALWAYS AS IDENTITY` with a globally unique `uuid` and un-constrained `*_uuid` foreign keys on the server (see `db-design-choices.md`).
**Alternatives:** Auto-increment integer FKs (breaks offline creation) or UUID-only primary key without `id` (causes B-tree page splits and loses arrival order).
**Consequences:** Clients can create and link rows offline and sync in any order, at the cost of maintaining two unique indexes per server table and handling potential orphans on read.

### Decision: Plain-language synergy tags instead of FR measurement graphs (2026-11-18, Pulse Team)
**Status:** accepted
**Context:** Clinical frequency-response graphs intimidate newcomers and fail to capture how DAC/amp pairings feel in everyday listening (`Brand thingy.pdf`).
**Choice:** Model pairing impressions around structured signal chains (`audio_chain`), `synergy_verdict_enum`, and curated plain-language `synergy_tag` descriptors.
**Alternatives:** Full squig.link-style FR graph uploader and parametric EQ analyzer.
**Consequences:** Faster MVP time-to-market and clear gatekeep-free positioning; technical measurement plotting is deferred outside MVP scope.

### Decision: Community-guideline hits and $k \ge 5$ helpfulness gating (2026-11-18, Pulse Team)
**Status:** accepted
**Context:** Visible karma systems breed elitism and astroturfing, while small-sample aggregates risk re-identifying contributors.
**Choice:** Enforce moderation via private `guideline_hit` cooldowns (`hit_1_notice`, `hit_2_cooldown`, `hit_3_restricted`) and mask `helpful_count` in `v_public_listening_note` until `helpful_count >= 5`.
**Alternatives:** Reddit-style upvote/downvote karma and public user reputation badges.
**Consequences:** Eliminates status-farming and protects contributor privacy, requiring server views and API serializers to enforce the threshold consistently.

## Ranked Technical Debt & Tradeoff Register

1. **Row-level LWW overwrites concurrent edits to different fields of the same note** (High likelihood if a user edits the same note on Web and Android before syncing; accepted for MVP simplicity—see 15).
2. **Un-constrained server `*_uuid` columns allow temporary orphan rows** (Medium likelihood when child `listening_note_tag` arrives before `listening_note`; mitigated by client orphan guard and `LEFT JOIN` reads—see 07).
3. **Full/watermark scoped pulls without tombstone compaction** (Low impact at MVP scale; requires 90-day tombstone purge job once soft-deleted rows accumulate—see 12).
