# 13 — Dependencies

**Purpose:** Dependency policy, approved technology stack reasons, upgrade traps, and deliberately rejected libraries across the Pulse ecosystem.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. Derived from `pulse-specs/business-logic-v1.1.md` and `pulse-specs/db-design-choices.md`. The code wins (see 16).

## Dependency Policy

1. **Prefer Standard Platform Primitives**: If SQLite, PostgreSQL (`pgcrypto`), or the standard library handles it in 20 lines of clear code, do not add a third-party package.
2. **Pin Major/Minor Versions & Commit Lockfiles**: Every dependency addition must use the `deps:` or `pulse-<app>:` commit scope and explain why it is needed.
3. **Zero Telemetry / Ad-Tech SDKs**: Never install third-party analytics, session-replay, or ad-network SDKs that track per-user trails or device fingerprints (violates `pulse-specs/business-logic-v1.1.md` Required Solution Layers).

## Core Stack Inventory & Rationale

| Component | Technology | Why Chosen | Upgrade / Usage Traps |
|---|---|---|---|
| **Server DB & Auth** | Supabase PostgreSQL + `pgcrypto` | Native `uuid` type, `timestamptz`, partial unique indexes (`WHERE archived_at IS NULL`), and Google Sign-In OAuth integration | Never expose `SUPABASE_SERVICE_ROLE_KEY` to client apps; keep RLS / API gating aligned |
| **Web Client (`pulse-web`)** | Next.js (React / TypeScript) | Fast SSR for public gear/note discovery and regulatory compliance pages, plus client-side offline storage | Do not import server-only DB modules inside client components |
| **Backend API (`pulse-api`)** | Node.js / TypeScript (or Next.js API / Fastify) | Shares TypeScript DTOs and enum definitions with `pulse-web` while isolating Supabase service-role upserts | Always parameterize SQL queries; never interpolate client strings |
| **Android Client (`pulse-android`)** | Kotlin + Jetpack Compose + SQLite (Room / SQLDelight) | First-class offline SQLite support with foreign-key enforcement and reactive UI updates | SQLite lacks `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`; always check `PRAGMA table_info` before migrating |

## Deliberate Rejections

| Rejected Dependency / Feature | Why Rejected |
|---|---|
| Heavyweight CRDT engines (Automerge / Yjs) | Overkill for personal listening notes that have a single natural author; row-level LWW (`updated_at` vs `synchronized_at`) requires only one timestamp column (`db-design-choices.md` §6) |
| Client-side FR Graph / FFT Audio Analyzers | Contradicts Pulse's core anti-jargon positioning (`Brand thingy.pdf`) and bloats MVP scope |
| Third-party location / map SDKs (Google Maps SDK / Mapbox) | Unnecessary and dangerous for privacy; Pulse uses coarse city/municipality codes (`coarse_city_code`) only, never map pins with GPS coordinates |
| Behavioral analytics SDKs (Mixpanel, Amplitude, GA4 user-ID tracking) | Violates the strict **no per-user trails** requirement in `business-logic-v1.1.md` |
