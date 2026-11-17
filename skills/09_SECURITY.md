# 09 — Security & Privacy Compliance

**Purpose:** Threat model, authentication, authorization layers, RA 10173 Data Privacy Act solution layers, and security review checklist for the Pulse ecosystem.

**Confidence note:** verified against `SPLS.01.0.001` (`v1.0.0`) on 2026-11-18. Directly implements the Required Solution Layers in `pulse-specs/business-logic-v1.1.md`. The code wins (see 16).

## Threat Model & Primary Assets

| Asset / Surface | Threat | Mitigation in Pulse |
|---|---|---|
| **Contributor Location (`local_spot_pin`)** | Stalking or home-address inference from geotagged audio gear posts | Client strips GPS coordinates; database stores only `coarse_city_code` and auto-expires rows via `expires_at` (`v_active_local_spot_pin`) |
| **Small-Sample Community Aggregates** | Re-identifying a niche gear owner via linkage attacks (Sweeney, 2002) | Enforce $k \ge 5$ aggregation threshold (`v_public_listening_note` masks `helpful_count < 5` as `NULL`) |
| **Ownership & Moderation Attribution** | Spoofing `created_by` to overwrite another user's listening note or `approved_by` on gear | `pulse-api` ignores client-supplied actor columns and stamps them from the verified session |
| **Astroturfing & Shilling** | Paid affiliate manipulation or elitist downvote brigading | Zero financial/convertible rewards; no public user karma; enforcement via internal `guideline_hit` cooldowns |
| **User Behavioral Privacy** | Cross-session reading trails and non-consensual data resale | No clickstream/view-history logging; explicit opt-in `data_consent_log` required under RA 10173 |

## Authentication & Authorization Layers

1. **Authentication (Google Sign-In via Supabase Auth)**:
   - Clients authenticate via Google Sign-In OAuth2/PKCE flow and send a short-lived bearer JWT to `pulse-api`.
   - `pulse-api` verifies the token signature and maps `sub` (`auth_user_uuid`) to `public.account.uuid` and `user_level`.
2. **Role-Based Access Control (`user_level_enum`)**:
   - `system_admin` (`A`) > `admin` (`B`) > `moderator` (`C`) > `contributor` (`D`) > `guest` (`E`).
   - Ownership check: Contributors (`D`) may only update or archive rows where `created_by = session.account_uuid` (or `owner_account_uuid` / `author_account_uuid` matches).
   - Cooldown check: Before accepting a public write from a Contributor, verify `posting_cooldown_until IS NULL OR posting_cooldown_until <= now()` and `active_hit_count < 3`.

## Required Solution Layers (RA 10173 Compliance Checklist)

Every feature PR must preserve these six guarantees from `pulse-specs/business-logic-v1.1.md`:

- [ ] **Location Protection**: No table, log, or API payload accepts or stores latitude/longitude coordinates. Only `coarse_city_code` is persisted.
- [ ] **Retention Limits**: `local_spot_pin` requires `expires_at` ($\le 14$ days from creation). Soft-deleted tombstones (`archived_at IS NOT NULL`) are eligible for hard purge after 90 days.
- [ ] **No Per-User Trails**: Do not create `page_view`, `search_history`, or per-user clickstream tables.
- [ ] **Aggregation Thresholds ($k \ge 5$)**: Any query returning community counts (`helpful_count`, regional pairing counts, analytics) suppresses values where the contributing cohort is $< 5$.
- [ ] **Explicit Consent (`data_consent_log`)**: Users can view regulatory disclosures (hosted in `pulse-web`), toggle consent scopes, export their data, and trigger account erasure at any time.
- [ ] **Guideline Hits Instead of Visible Reputation**: `active_hit_count` and `guideline_hit` rows are visible only to the account owner and Moderators/Admins (`A,B,C`), never on public profiles.

## Secrets Handling

- Never commit `.env` files, Supabase service-role keys, or Google OAuth client secrets to any repository.
- Reference only environment variable names in documentation and configs:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY` (safe for client initialization where applicable)
  - `SUPABASE_SERVICE_ROLE_KEY` (**server-only** in `pulse-api`, never in `pulse-web` `NEXT_PUBLIC_*` or `pulse-android`)
  - `GOOGLE_OAUTH_CLIENT_ID`
