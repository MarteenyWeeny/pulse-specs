# Business Logic v1.1 (Proposed)

> Development of a Web and Android-based Community-Driven Audiophile Listening Journal and Gear Pairing Platform using Next.js, Kotlin, and Supabase for Personal Audio Enthusiasts

- Allowed Platforms: Web, Android

## Summary of Identified MVP Gaps in v1.0 & Proposed Revisions

To achieve a fast time-to-market without over-engineering "nice-to-have" features (such as frequency-response graph plotters, direct messaging, marketplace escrow, or complex social feeds), the following essential MVP gaps in `business-logic-v1.0.md` were identified and addressed:

1. **Structured Signal-Chain Pairing Model**: `v1.0` mentioned pairing gear generally, but lacked a concrete, minimal structure for a signal chain. `v1.1` defines a lightweight 3-slot core chain (**Source** → **DAC/Dongle/Amp** → **Transducer [IEM/Headphone/Speaker]**, plus optional **Tip/Cable/Mod** notes) so users can compare how the exact same IEM sounds with versus without a specific DAC.
2. **Newcomer-Friendly Subjective Vocabulary Tags**: To deliver on the *gatekeep-free, anti-jargon* brand positioning, `v1.1` replaces free-for-all audiophile jargon with curated, plain-language subjective tags (e.g., `"Opened up soundstage"`, `"Tighter bass"`, `"Clean background / no hiss"`, `"Warm & relaxed"`, `"Great for commute/pocket-fi"`, `"Noticeable upgrade"`, `"Subtle difference"`).
3. **Non-Gamified Community Feedback ("Helpful Pairing")**: Since visible user karma and monetary rewards are prohibited by the Required Solution Layers, `v1.1` introduces a simple per-note **"Helped Me Decide"** signal that aggregates only after reaching a privacy threshold ($k \ge 5$) and never accumulates into a public user reputation score.
4. **Explicit Community-Guideline Hit Escalation**: `v1.0` stated that Moderators use community-guideline hits, but did not define the operational thresholds. `v1.1` defines a clear, deterministic hit lifecycle (Hit 1: private notice & note hidden for revision; Hit 2: 7-day posting cooldown; Hit 3+: read-only mode pending Admin review) with automatic expiration of minor hits after 90 days.
5. **Time-Limited & Coarse-Location Rules for Local Audition/Availability Pins**: `v1.1` specifies that location-pinned community notes (e.g., local audio café demo units, hobbyist meetup listening tables, or regional stock sightings) accept only coarse city/district codes, automatically expire after a user-selected TTL (24 hours to 14 days), and are purged after the retention window.
6. **Regulatory Compliance & Self-Service Data Rights on Web/Android**: `v1.1` explicitly connects `pulse-web` (which hosts the regulatory compliance pages and web client) and `pulse-android` to self-service Data Privacy Act (RA 10173) controls: granular consent toggles, one-click personal journal export (JSON/CSV), and account/data soft-delete + retention purge.

---

## Project Details

- Company/Startup/Team Name: Pulse Audio Collective
- Project Code Name: `pulse`
- Project Short Code: `PLS`
- Short Description: A gatekeep-free, community-driven listening journal where everyday hobbyists log and share honest, subjective real-world experiences with IEMs, DACs, headphones, and personal audio chains.
- Long Description: Getting into personal audio usually starts the same way: you buy a solid pair of In-Ear Monitors (IEMs), plug them in, and think, *"These sound pretty good."* Then you pair them with a proper DAC—and suddenly the soundstage opens up, the details click into place, and you finally hear what the hype is about. Pulse exists to capture that exact discovery. Instead of overwhelming beginners with clinical measurements, sterile frequency graphs, and elitist terminology, Pulse is an unpretentious space for real people to log their personal audio setups, document what genres and reference tracks they played, and share honest, subjective listening notes on whether a pairing or upgrade actually made a difference in everyday life.

## Positioning & Brand Pillars

- **Core Positioning**: A community-driven listening journal built to demystify personal audio—trading intimidating frequency graphs for honest, everyday impressions of how IEMs, DACs, headphones, and sources actually sound together.
- **Hero Tagline**: *"Real ears, honest pairings. Discover how IEMs, DACs, and audio setups actually sound before you buy."*
- **Voice & Tone**: Unpretentious, warm, candid, tactile, grounded, conversational, curious.
- **Core Experience**: Synergy, pairing, chain, clarity, "aha" moment, unfiltered, real-world, listening notes.
- **Community & Culture**: Gatekeep-free, peer-led, hobbyist, subjective, crowdsourced, newcomer-friendly, pocket-fi.
- **Aesthetic & Feel**: Analog warmth, clean signal, studio desk, minimalist, journal, curated, crisp.

## User Levels

| User Level              | Description |
| ----------------------- | ----------- |
| A. System Administrator | Maintains/overrides system and server configurations, manages Supabase PostgreSQL schema migrations, and performs regular database backups and restores. |
| B. Administrator        | Manages general platform settings, curates newcomer-friendly subjective tags and gear categories, oversees RA 10173 regulatory compliance, and reviews k-anonymized system analytics. |
| C. Moderator            | Reviews crowdsourced gear submissions (approving or merging duplicates), handles flagged content, and issues internal community-guideline hits without public shaming. |
| D. Contributor          | Authenticated hobbyists and newcomers who log offline/online listening journals, create audio chains (Source + DAC/Amp + IEM/Headphone), publish pairing notes, mark notes as helpful, and share time-limited, coarse-location demo/availability sightings. |
| E. Guest                | Unauthenticated users who browse the gear catalog, filter real-world pairing notes by gear or music genre, view aggregated synergy summaries, and access regulatory compliance disclosures. |

## System Requirements

1. **Authentication & Account Privacy**: The app shall allow users to authenticate via Google Sign-In integration and manage explicit privacy/consent preferences, data export, and account deletion under the Philippine Data Privacy Act of 2012 (RA 10173).
2. **Crowdsourced Gear Catalog**: The app shall allow Contributors to browse existing audio gear (IEMs, headphones, DACs/dongles, amplifiers, DAPs, sources, eartips/cables) and submit missing gear entries offline or online for Moderator deduplication.
3. **Signal-Chain Rig Builder**: The app shall allow Contributors to assemble reusable audio chains linking a Source, DAC/Amp, and Transducer (plus optional accessories) to evaluate and compare setup synergy.
4. **Offline-First Listening Journal & Pairing Notes**: The app shall allow Contributors to draft, edit, and soft-delete subjective listening notes offline (in local SQLite) and sync them to Supabase PostgreSQL using UUID-native keys and last-write-wins (`updated_at` vs `synchronized_at`) conflict resolution.
5. **Anti-Jargon Discovery & Filtering**: The app shall allow all users (including Guests) to search and filter listening notes by gear pairing, music genre, reference track, budget tier, and plain-language subjective synergy tags without requiring technical graphs.
6. **Time-Limited, Coarse-Location Audition/Availability Pins**: The app shall allow Contributors to post optional, time-limited (24h–14d TTL) local availability or audition spot notes pinned only to a coarse city/municipality code (never exact GPS coordinates).
7. **Non-Gamified Community Feedback**: The app shall allow Contributors to flag a listening note as *"Helped Me Decide"*, displaying counts only when the aggregation threshold ($k \ge 5$) is met and never displaying cumulative user karma or leaderboards.
8. **Guideline-Hit Moderation**: The app shall allow Moderators to enforce community standards (anti-elitism, anti-affiliate/shilling, respectful tone) through private community-guideline hits that automatically apply posting cooldowns or restrictions based on hit thresholds.

## Required Solution Layers

1. **Privacy & Security by Design**:
   - **Location Protection**: Strip high-precision GPS coordinates on the client before storage or sync; persist only coarse administrative region/city identifiers for local audition/availability pins.
   - **Retention Limits**: Automatically archive expired time-limited availability pins upon TTL expiry and purge soft-deleted tombstones (`archived_at`) and raw operational logs after a 90-day sync retention window.
   - **No Per-User Trails**: Do not log per-user clickstreams, reading history trails, or cross-session behavioral profiles.
   - **Aggregation Thresholds**: Suppress aggregated community synergy stats and *"Helped Me Decide"* counts until at least $k = 5$ distinct Contributors have contributed to the metric.
   - **Explicit Consent & No Data Resale**: Require granular opt-in consent for any optional analytics; prohibit credit, monetary, or convertible rewards; treat data resale as the last revenue option requiring explicit, revocable user consent.
2. **Community-Guideline Hit Enforcement**:
   - Replace public reputation scores, downvote brigades, and user karma with internal **community-guideline hits** (`guideline_hit`).
   - Threshold rules: 1 active hit triggers a constructive revision prompt; 2 active hits apply a temporary 7-day publishing cooldown; 3 active hits restrict the account to private local journaling until Moderator/Admin review. Minor hits expire after 90 days of clean participation.

## MVP Features and Access

> See the User Levels table for reference (`A` = System Admin, `B` = Admin, `C` = Moderator, `D` = Contributor, `E` = Guest).

| Feature                                                                                              | Access      |
| ---------------------------------------------------------------------------------------------------- | ----------- |
| 1. Browse & Filter Gear Catalog, Audio Chains, Listening Notes, and Regulatory Compliance Pages       | A,B,C,D,E   |
| 2. Google Sign-In Authentication, Consent Management, and Personal Data Export/Deletion              | A,B,C,D     |
| 3. Personal Audio Signal-Chain Builder (Source → DAC/Amp → IEM/Headphone) & Crowd Gear Submission    | A,B,C,D     |
| 4. Offline-First Subjective Listening Journal, Plain-Language Synergy Tagging, & LWW Cloud Sync      | A,B,C,D     |
| 5. Time-Limited, Coarse-Location Local Audition/Availability Pins & "Helped Me Decide" Signal        | A,B,C,D     |
| 6. Gear Catalog Deduplication, Content Review, and Community-Guideline Hit Enforcement               | A,B,C       |
| 7. Curated Tag/Category Management, Aggregated ($k \ge 5$) Analytics, and Compliance Reporting       | A,B         |
| 8. System Configuration Overrides, Database Schema Migrations, and Backup/Restore Operations         | A           |

## Notes

- **Scope Discipline (Excluded from MVP)**: Frequency response (FR) graph rendering tools, direct user-to-user messaging, P2P used-gear payment processing, affiliate link injection, and public user follower/reputation graphs are deliberately excluded to keep the MVP lightweight, fast to ship, and faithful to the gatekeep-free listening journal vision.
- **Offline-First Parity**: Both `pulse-android` (local SQLite) and `pulse-web` interact with `pulse-api` using identical table and column names, UUID v4/v7 global identities, server-stamped `created_by`, and `archived_at` soft-delete tombstones.
