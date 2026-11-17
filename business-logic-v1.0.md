# Business Logic

> Development of a Web and Android-based Community-Driven Audiophile Listening Journal and Gear Pairing Platform using Next.js, Kotlin, and Supabase for Personal Audio Enthusiasts

- Allowed Platforms: Web, Android

## Project Details

- Company/Startup/Team Name: Pulse Audio Collective
- Project Code Name: `pulse`
- Project Short Code: `PLS`
- Short Description: A gatekeep-free, community-driven listening journal where everyday hobbyists log and share honest, subjective real-world experiences with IEMs, DACs, headphones, and personal audio chains.
- Long Description: Getting into personal audio usually starts the same way: you buy a solid pair of In-Ear Monitors (IEMs), plug them in, and think they sound good—until you pair them with a proper DAC or dongle and suddenly the soundstage opens up, details click into place, and you experience the "aha" moment of gear synergy. Pulse is a subjective audio discovery platform and listening journal built to capture that exact discovery for newcomers and hobbyists alike. Instead of overwhelming beginners with clinical frequency-response graphs, sterile measurements, and elitist terminology, Pulse provides an unpretentious, warm, and candid space for real listeners to log their audio chains (IEMs, headphones, DACs, amps, dongles, DAPs, eartips, and sources), record what tracks and genres they played, and share whether a pairing or upgrade actually made a real-world difference.

## User Levels

> Note: Modify/rename the list of users based on the actual users that you expect to use the system.

| User Level              | Description |
| ----------------------- | ----------- |
| A. System Administrator | Maintains/overrides system/server configurations, manages Supabase database migrations, and performs regular backups and restores. |
| B. Administrator        | Manages general platform settings, curates canonical audio gear categories, oversees regulatory/privacy compliance, and generates periodic aggregated system analytics and reports. |
| C. Moderator            | Reviews user-submitted audio gear entries for duplicates, handles flagged listening notes, and enforces community rules via internal community-guideline hits without public shaming. |
| D. Contributor          | Authenticated everyday hobbyists and newcomers who log personal audio gear setups, publish subjective listening notes and pairing impressions, bookmark chains, and share coarse location-pinned local audition/demo sightings. |
| E. Guest                | Unauthenticated visitors who browse public gear pairings, read subjective listening notes, search by genre or setup synergy, and view regulatory compliance information on Web or Android. |

## System Requirements

1. The app shall allow the users to authenticate using Google Sign-In integration.
2. The app shall allow Contributors to build and manage personal audio chains (pairing transducers such as IEMs/headphones with DACs, dongles, amplifiers, and sources) both offline and online.
3. The app shall allow Contributors to write, edit, and soft-delete subjective listening notes detailing gear synergy, reference tracks/genres, real-world comfort, and "aha" pairing impressions without requiring technical measurement graphs.
4. The app shall allow all users (including Guests) to discover and filter audio gear pairings and listening notes by gear model, pairing chain, music genre, budget tier, and subjective sound descriptors.
5. The app shall allow Contributors to submit new audio gear items to the crowdsourced catalog and post time-limited, coarse location-pinned community availability or local demo/audition notes.
6. The app shall allow Moderators to merge duplicate gear submissions and enforce anti-gatekeeping, anti-shilling standards using internal community-guideline hits rather than visible user karma or reputation scores.
7. The app shall synchronize local SQLite journaling data on Android and Web clients with the central Supabase PostgreSQL database via the backend API using UUID-native identities and last-write-wins (LWW) dirty synchronization.

## Required Solution Layers

1. Security and privacy by design. Data Privacy Act of 2012 (RA 10173) compliance, location protection (city/municipality-level fuzzy pinning only; no raw GPS coordinates stored), retention limits on time-limited availability pins and logs, no per-user behavioral tracking trails, aggregation thresholds (minimum k-anonymity threshold before showing community pairing trends), and explicit opt-in consent before any data sharing or resale (with data resale treated as the absolute last revenue option).
2. Community enforcement through internal community-guideline hits instead of visible reputation, karma, or leaderboards, ensuring a gatekeep-free, newcomer-friendly culture without financial, credit, or convertible rewards.

## MVP Features and Access

> See the User Levels table for reference.

| Feature                                                                                      | Access      |
| -------------------------------------------------------------------------------------------- | ----------- |
| 1. Browse & Search Crowdsourced Gear Catalog, Audio Chains, and Subjective Listening Notes   | A,B,C,D,E   |
| 2. Google Sign-In Authentication & Privacy/Consent Management                                | A,B,C,D     |
| 3. Personal Audio Rig/Chain Builder (IEM/Headphone + DAC/Amp + Source Pairing)               | A,B,C,D     |
| 4. Offline-First Subjective Listening Journal & Real-World Synergy Note Logging              | A,B,C,D     |
| 5. Time-Limited, Coarse Location-Pinned Local Demo/Audition & Availability Notes             | A,B,C,D     |
| 6. Crowdsourced Gear Catalog Moderation & Community-Guideline Hit Enforcement                | A,B,C       |
| 7. Platform Settings, Aggregated Community Synergy Analytics, and Compliance Reporting       | A,B         |
| 8. System Configuration Override, Schema Migration Management, and Database Backup/Restore   | A           |

## Notes
- **Brand Voice & Tone**: Unpretentious, warm, candid, tactile, grounded, conversational, curious.
- **Core Experience Pillars**: Synergy, pairing, chain, clarity, "aha" moment, unfiltered, real-world, listening notes.
- **Community & Culture**: Gatekeep-free, peer-led, hobbyist, subjective, crowdsourced, newcomer-friendly, pocket-fi.
- **Aesthetic & Feel**: Analog warmth, clean signal, studio desk, minimalist, journal, curated, crisp.
- **No Financial Bait**: The platform strictly prohibits monetary, credit, or convertible rewards for posting reviews to prevent affiliate shilling and preserve authentic hobbyist impressions.
