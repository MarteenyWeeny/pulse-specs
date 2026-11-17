# 00 — Index

**Purpose:** Entry point for the Pulse (`pulse` / `PLS`) engineering skills base. Read this first to find which document applies to your current task, check verification freshness, and learn how to contribute lessons back.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. The code wins (see 16).

## Reading Order by Task

| Task | Read in order |
|---|---|
| First day on the Pulse ecosystem | `01` → `02` → `07` → `16` |
| Adding or modifying a database table/column | `07` → `04` → `14` → `06` |
| Building or changing a sync or API endpoint | `08` → `07` → `09` → `04` |
| Implementing a Web or Android UI feature | `01` → `03` → `04` → `11` |
| Debugging a broken sync, missing row, or auth failure | `05` → `06` → `07` |
| Preparing a weekly build tag or release promotion | `10` → `14` → `pulse-specs/git-guidelines.md` |
| Reviewing privacy, RA 10173, or moderation rules | `09` → `01` → `pulse-specs/business-logic-v1.1.md` |

## Document Inventory

| File | Topic | Status / Confidence | Last Verified |
|---|---|---|---|
| `00_INDEX.md` | Reading order, inventory, and changelog | Verified | 2026-11-18 |
| `INBOX.md` | Unprocessed field notes and contributor queue | Verified | 2026-11-18 |
| `01_ARCHITECTURE.md` | Ecosystem topology, boundaries, and ADRs | Verified (`pulse-specs`) | 2026-11-18 |
| `02_PROJECT_STRUCTURE.md` | Multi-repo layout and file placement rules | Verified (`pulse-ecosystem`) | 2026-11-18 |
| `03_CODE_STYLE.md` | Naming, error handling, comments, and commit rules | Verified (`git-guidelines.md`) | 2026-11-18 |
| `04_CHANGE_RULES.md` | Lockstep sets across SQLite, API, and Postgres | Verified (`db-schema/v1.0.0.sql`) | 2026-11-18 |
| `05_DEBUGGING_PLAYBOOK.md` | Symptoms, causes, and diagnostic queries | Verified / Inferred | 2026-11-18 |
| `06_FAILURE_STORIES.md` | Reconstructed offline-sync and privacy failure modes | Inferred from design scars | 2026-11-18 |
| `07_DATABASE.md` | UUID-native schema, LWW sync, and soft deletes | Verified (`db-design-choices.md`) | 2026-11-18 |
| `08_API.md` | Envelope, sync contracts, and auth gating | Verified / Inferred | 2026-11-18 |
| `09_SECURITY.md` | RA 10173 privacy layers, k-anonymity, and auth | Verified (`business-logic-v1.1.md`) | 2026-11-18 |
| `10_DEPLOYMENT.md` | Maturity branching (`main` → `beta` → `release`) & tags | Verified (`git-guidelines.md`) | 2026-11-18 |
| `11_TESTING.md` | Sync invariants, privacy threshold tests, and drills | Verified / Inferred | 2026-11-18 |
| `12_PERFORMANCE.md` | B-tree locality, scoped pulls, and hot paths | Verified (`db-design-choices.md`) | 2026-11-18 |
| `13_DEPENDENCIES.md` | Approved stack, upgrade traps, and banned packages | Verified (`business-logic-v1.1.md`) | 2026-11-18 |
| `14_DEVELOPER_WORKFLOWS.md` | Step-by-step recipes for schema, sync, and git | Verified | 2026-11-18 |
| `15_KNOWN_LIMITATIONS.md` | Accepted LWW tradeoffs, deferred scope, and risks | Verified | 2026-11-18 |
| `16_ENGINEERING_PRINCIPLES.md` | Quotable rules governing the Pulse ecosystem | Verified | 2026-11-18 |

## How to Contribute

Drop rough notes into `INBOX.md` immediately when you hit a surprise, or edit the target document directly:

| Contribution Type | Home Document |
|---|---|
| Best practice | `03_CODE_STYLE.md` (code) or `14_DEVELOPER_WORKFLOWS.md` (workflow) |
| Methodology | `10_DEPLOYMENT.md`, `11_TESTING.md`, or `14_DEVELOPER_WORKFLOWS.md` |
| Design choice | `01_ARCHITECTURE.md` (as a Decision Record) |
| Change rule / Lockstep set | `04_CHANGE_RULES.md` |
| Failure story | `06_FAILURE_STORIES.md` (linked from `04`, `05`, and `16`) |
| Debugging tip | `05_DEBUGGING_PLAYBOOK.md` |
| Known limitation | `15_KNOWN_LIMITATIONS.md` |
| Dependency note | `13_DEPENDENCIES.md` |
| Proven principle | `16_ENGINEERING_PRINCIPLES.md` |

## Changelog (Newest First)

- **2026-11-18 (`SPLS.01.0.001`)**: Initial generation of the 18 skills documents from `handoff.md`, `pulse-specs/business-logic-v1.1.md`, `pulse-specs/db-design-choices.md`, `pulse-specs/db-schema/v1.0.0.sql`, and `pulse-specs/git-guidelines.md`.
