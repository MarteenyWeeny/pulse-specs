# 10 — Deployment & Release Versioning

**Purpose:** Maturity-based branching workflow (`main` → `beta` → `release`), cross-repository release order, and weekly tag derivation rules for `WPLS`, `BPLS`, `APLS`, and `SPLS`.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. Directly mirrors `pulse-specs/git-guidelines.md` Part 2. The code wins (see 16).

## Release Order Across Repositories

Always promote and deploy changes in this exact order so schema and API contracts exist before clients depend on them:

1. **`pulse-specs` (`SPLS`)** — Merge updated business logic and idempotent SQL migration (`pulse-specs/db-schema/v1.0.x.sql`).
2. **Supabase PostgreSQL Database** — Apply the idempotent forward migration (`v1.0.x.sql`) in a transaction (`BEGIN; ... COMMIT;`).
3. **`pulse-api` (`BPLS`)** — Deploy backend API supporting both the new columns and older client payloads.
4. **`pulse-web` (`WPLS`) & `pulse-android` (`APLS`)** — Publish web and Android client builds.
- *Miss →* Deploying `pulse-android` or `pulse-web` before `v1.0.x.sql` and `pulse-api` causes client pushes of new columns to be dropped or fail on the server (see 04 #1).

## Maturity-Based Branching Model (`pulse-specs/git-guidelines.md`)

`main` → `beta` → `release` → production

| Branch | Owner / Gate | Permitted Work |
|---|---|---|
| `main` | Developers (Unit testing) | Active feature development, bug fixes, and developer unit tests. Not eligible for independent release testing. |
| `beta` | QA (System testing) | Promoted from `main`. QA validates major product claims and stabilizes the build. |
| `release` | Independent Testers (Integration testing) | Promoted from `beta` only after QA acceptance. Bundles published to release site for `a` → `b` → `rc` candidate testing. |

## Tag Format & Weekly Cut Rules

Format: `<prefix>.0X.Y.00Z` (never normalize zero-padding: `WPLS.01.0.001`, never `WPLS.1.0.1`).

| Repository | Prefix | Initial Tag |
|---|---|---|
| `pulse-web` | `WPLS` | `WPLS.01.0.001` |
| `pulse-api` | `BPLS` | `BPLS.01.0.001` |
| `pulse-android` | `APLS` | `APLS.01.0.001` |
| `pulse-specs` | `SPLS` | `SPLS.01.0.001` |

### Six Weekly Tagging Rules (`pulse-specs/git-guidelines.md` §Release Tags)

1. **Start at the first commit's ISO week**: `001` anchors to the ISO week (Monday–Sunday) of the repository's very first commit.
2. **No commits, no tag**: Skip any ISO week with zero commits; do not consume a `00Z` build number for empty weeks.
3. **Never tag an ongoing week early**: Do not tag the current ISO week until **Friday 5:00 PM or later on the local clock**.
4. **Bundle by ISO week**: Each tag points to the last commit of its ISO week.
5. **Never move or retag**: Tags are immutable once pushed.
6. **Pre-release candidate suffixes (`a`, `b`, `rc`)**: Used on `release` only after planned development is 100% complete (`WPLS.01.0.017a` → `a2` → `b` → `rc` → production).

## Release Checklist

- [ ] No AI agent appears as commit/tag/PR author (`git log` check).
- [ ] Every commit message on the branch matches `scope: Imperative summary` ($\le 50$ chars).
- [ ] Forward SQL migrations in `pulse-specs/db-schema/` run idempotently twice in a row with zero errors.
- [ ] Release tag table at the bottom of `pulse-specs/git-guidelines.md` is updated once the weekly tag is cut.
