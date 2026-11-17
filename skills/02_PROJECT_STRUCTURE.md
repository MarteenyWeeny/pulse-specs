# 02 — Project Structure

**Purpose:** Annotated directory tree of the `pulse-ecosystem` workspace, repository responsibilities, where new files belong, and naming conventions that carry operational meaning.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. The code wins (see 16).

## Workspace Annotated Tree

```text
pulse-ecosystem/                        # Parent local workspace (not a git repo itself)
├── AGENTS.md                           # Root agent instructions (points to *-*/AGENTS.md & skills)
├── handoff.md                          # Senior engineer skills generator specification
├── pulse-specs/                        # [Git Repo: SPLS] Authoritative ecosystem specifications
│   ├── AGENTS.md                       # Repo role: product ecosystem specifications for Pulse
│   ├── business-logic-v1.0.md          # Initial MVP requirements draft
│   ├── business-logic-v1.1-proposed.md # Gap analysis and proposed MVP refinements
│   ├── business-logic-v1.1.md          # Agreed authoritative MVP business logic
│   ├── db-design-choices.md            # Offline-first SQLite <-> Postgres design rationale
│   ├── git-guidelines.md               # Commit scopes, maturity branches, and WPLS/BPLS/APLS/SPLS tags
│   ├── sense-making.md                 # Environmental scanning prompt instructions
│   ├── db-schema/
│   │   └── v1.0.0.sql                  # Idempotent Supabase PostgreSQL MVP baseline schema
│   ├── planning/
│   │   ├── sense-making.csv            # Verified STEEPLE environmental scan (CSV)
│   │   └── sense-making.md             # Verified STEEPLE environmental scan (Markdown block)
│   └── skills/
│       ├── 00_INDEX.md .. 16_ENGINEERING_PRINCIPLES.md
│       └── INBOX.md
├── pulse-api/                          # [Git Repo: BPLS] Backend API bridging Supabase & clients
│   └── AGENTS.md                       # Repo role: backend web application for Pulse
├── pulse-web/                          # [Git Repo: WPLS] Next.js web app & regulatory compliance
│   └── AGENTS.md                       # Repo role: front-end web app with regulatory compliance
└── pulse-android/                      # [Git Repo: APLS] Offline-first Kotlin Android client
    └── AGENTS.md                       # Repo role: Android application for Pulse
```

## Where New Work Goes (and Must Not Go)

| Artifact Type | Where It Must Go | Where It Must Never Go |
|---|---|---|
| SQL schema baselines, forward migrations (`v1.0.x.sql`), and snapshots (`v1.x.0.sql`) | `pulse-specs/db-schema/` | Hardcoded only inside `pulse-api/` or `pulse-android/` without a spec migration |
| Cross-repo requirements, STEEPLE analysis, and engineering skills | `pulse-specs/` (`planning/`, `skills/`) | Duplicated across `pulse-web/` or `pulse-android/` |
| Supabase service-role queries, LWW conflict resolution SQL, and auth token validation | `pulse-api/` | Client bundles in `pulse-web/` or `pulse-android/` (*Miss →* leaks service-role keys to end users) |
| RA 10173 privacy disclosures, consent management UI, and web journal pages | `pulse-web/` | Omitted or hidden behind login walls (Guests `E` must be able to view regulatory compliance) |
| Mobile SQLite helper, `synchronized_at` dirty tracker, and native rig builder | `pulse-android/` | Unsynced shared preferences for domain entities |

## Naming Conventions That Carry Meaning

1. **Repository & Scope Names (`pulse-<product>`)**:
   - Always lowercase `kebab-case`: `pulse-specs`, `pulse-api`, `pulse-web`, `pulse-android`.
   - Commit scopes must match `<repo>/<feature>:` (e.g., `pulse-api/sync:`, `pulse-web/compliance:`, `pulse-android/journal:`).
2. **Release Tag Prefixes (`<Prefix>.0X.Y.00Z`)**:
   - `WPLS` (`pulse-web`), `BPLS` (`pulse-api`), `APLS` (`pulse-android`), `SPLS` (`pulse-specs`).
   - Never normalize zero-padding (`WPLS.01.0.001` is valid; `WPLS.1.0.1` breaks release tooling—see `git-guidelines.md`).
3. **Database Column Suffixes**:
   - `id`: Server-only surrogate `bigint` or client-only SQLite `INTEGER PRIMARY KEY`. Never crosses the wire.
   - `uuid`: The row's global 128-bit identity (`uuid NOT NULL UNIQUE`).
   - `*_uuid`: Foreign key referencing another table's `uuid` (e.g., `chain_uuid`, `primary_transducer_uuid`).
   - `*_at`: UTC timestamp (`timestamptz` on Postgres, ISO-8601 UTC `TEXT` on SQLite).
   - `*_by`: Server-stamped actor `uuid` (`created_by`, `approved_by`, `issued_by`). Never accepted from client payloads.
4. **Schema Version Files (`vMAJOR.MINOR.PATCH.sql`)**:
   - Bump `PATCH` (`v1.0.0` → `v1.0.1`) for forward additive migrations.
   - Bump `MINOR` (`v1.0.0` → `v1.1.0`) for full SQL snapshots exported from Supabase.
