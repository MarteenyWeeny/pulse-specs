-- =============================================================================
-- Pulse Ecosystem (PLS) — Idempotent MVP Database Schema
-- File: pulse-specs/db-schema/v1.0.0.sql
-- Target: Supabase PostgreSQL DB Service (offline-first SQLite sync compatible)
--
-- Design conventions (see pulse-specs/db-design-choices.md):
--   1. Every table uses `id bigint GENERATED ALWAYS AS IDENTITY` as a server-only
--      surrogate primary key for dense B-tree indexing and arrival order.
--      `id` NEVER leaves the server and is stripped from sync payloads.
--   2. Every table uses `uuid uuid NOT NULL UNIQUE` as its global identity,
--      minted offline or online by the creating client/service.
--   3. Relationships use `*_uuid` columns without server-side `REFERENCES`
--      constraints on synced tables so out-of-order child sync batches succeed.
--   4. Attribution uses server-stamped `created_by` (and action-specific actor
--      UUIDs) plus client-supplied `created_at`, `updated_at`, and `archived_at`.
--   5. Soft deletes set `archived_at` (tombstone) and bump `updated_at`.
--      Uniqueness on live rows is enforced via partial unique indexes
--      (`WHERE archived_at IS NULL`).
--   6. Required Solution Layers (RA 10173 Privacy by Design & Guideline Hits):
--      - Coarse city/region codes only (no raw GPS coordinates).
--      - Time-limited availability pins (`expires_at`).
--      - Aggregation threshold (k >= 5) before surfacing helpfulness counts.
--      - Internal `guideline_hit` records instead of public user karma.
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -----------------------------------------------------------------------------
-- 1. Idempotent Enum Types
-- -----------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_level_enum') THEN
    CREATE TYPE public.user_level_enum AS ENUM (
      'system_admin',
      'admin',
      'moderator',
      'contributor',
      'guest'
    );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'gear_category_enum') THEN
    CREATE TYPE public.gear_category_enum AS ENUM (
      'iem',
      'headphone',
      'dac_dongle',
      'amplifier',
      'dap_source',
      'cable_tip_accessory',
      'speaker'
    );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'budget_tier_enum') THEN
    CREATE TYPE public.budget_tier_enum AS ENUM (
      'budget',
      'entry_mid',
      'mid_fi',
      'upper_mid',
      'summit_fi'
    );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'chain_slot_enum') THEN
    CREATE TYPE public.chain_slot_enum AS ENUM (
      'source',
      'dac_amp',
      'transducer',
      'accessory'
    );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'synergy_verdict_enum') THEN
    CREATE TYPE public.synergy_verdict_enum AS ENUM (
      'aha_synergy',
      'noticeable_upgrade',
      'subtle_difference',
      'neutral_pairing',
      'poor_match'
    );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'guideline_hit_severity_enum') THEN
    CREATE TYPE public.guideline_hit_severity_enum AS ENUM (
      'hit_1_notice',
      'hit_2_cooldown',
      'hit_3_restricted'
    );
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 2. Account & Privacy/Consent Tables
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.account (
  id                     bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid                   uuid NOT NULL UNIQUE,
  auth_user_uuid         uuid,                                   -- Supabase Auth / Google Sign-In subject UUID
  handle                 text NOT NULL,
  display_name           text,
  bio                    text,
  preferred_genres       text,
  user_level             public.user_level_enum NOT NULL DEFAULT 'contributor',
  coarse_region_code     text,                                   -- City/municipality code only; never GPS
  active_hit_count       integer NOT NULL DEFAULT 0,             -- Internal moderation counter (never public karma)
  posting_cooldown_until timestamptz,                            -- Set when guideline hits reach threshold
  created_by             uuid,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  archived_at            timestamptz,
  CONSTRAINT account_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_account_handle_live
  ON public.account (lower(handle)) WHERE archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_account_auth_user_live
  ON public.account (auth_user_uuid) WHERE archived_at IS NULL AND auth_user_uuid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_account_updated_at
  ON public.account (updated_at);

-- Explicit RA 10173 Data Privacy Act consent records (no silent data resale).
CREATE TABLE IF NOT EXISTS public.data_consent_log (
  id             bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid           uuid NOT NULL UNIQUE,
  account_uuid   uuid NOT NULL,
  consent_scope  text NOT NULL,                                  -- e.g., 'terms_and_privacy', 'aggregated_analytics', 'data_resale_opt_in'
  policy_version text NOT NULL,
  is_granted     boolean NOT NULL DEFAULT false,
  consented_at   timestamptz NOT NULL DEFAULT now(),
  revoked_at     timestamptz,
  created_by     uuid,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  archived_at    timestamptz,
  CONSTRAINT data_consent_log_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_data_consent_log_account
  ON public.data_consent_log (account_uuid);
CREATE UNIQUE INDEX IF NOT EXISTS idx_data_consent_log_live
  ON public.data_consent_log (account_uuid, consent_scope) WHERE archived_at IS NULL;

-- -----------------------------------------------------------------------------
-- 3. Crowdsourced Audio Gear Catalog
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.gear_item (
  id                  bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid                uuid NOT NULL UNIQUE,
  brand               text NOT NULL,
  model_name          text NOT NULL,
  category            public.gear_category_enum NOT NULL,
  budget_tier         public.budget_tier_enum NOT NULL DEFAULT 'budget',
  form_factor         text,                                      -- e.g., 'Dynamic Driver IEM', 'USB-C Dongle DAC', 'Open-Back Headphone'
  summary             text,
  canonical_gear_uuid uuid,                                      -- Set by Moderator if this entry is merged into a canonical item
  is_verified         boolean NOT NULL DEFAULT false,
  approved_by         uuid,                                      -- Server-stamped Moderator/Admin UUID
  approved_at         timestamptz,
  created_by          uuid,                                      -- Server-stamped Contributor UUID
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  archived_at         timestamptz,
  CONSTRAINT gear_item_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_gear_item_category
  ON public.gear_item (category) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_gear_item_canonical
  ON public.gear_item (canonical_gear_uuid);
CREATE INDEX IF NOT EXISTS idx_gear_item_updated_at
  ON public.gear_item (updated_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_gear_item_natural_live
  ON public.gear_item (lower(brand), lower(model_name), category)
  WHERE archived_at IS NULL AND canonical_gear_uuid IS NULL;

-- -----------------------------------------------------------------------------
-- 4. Signal-Chain Rig Builder (Source -> DAC/Amp -> Transducer)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.audio_chain (
  id                   bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid                 uuid NOT NULL UNIQUE,
  owner_account_uuid   uuid NOT NULL,
  name                 text NOT NULL,                            -- e.g., 'Daily Pocket-Fi Commute Rig', 'Desk Warmth Setup'
  description          text,
  source_gear_uuid     uuid,                                     -- Read shortcut: Source/DAP/Phone
  dac_amp_gear_uuid    uuid,                                     -- Read shortcut: DAC / Dongle / Amplifier
  transducer_gear_uuid uuid NOT NULL,                            -- Read shortcut: Primary IEM / Headphone / Speaker
  accessory_gear_uuid  uuid,                                     -- Read shortcut: Eartips / Cable / Mod
  is_public            boolean NOT NULL DEFAULT true,
  rank                 integer NOT NULL DEFAULT 0,
  created_by           uuid,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  archived_at          timestamptz,
  CONSTRAINT audio_chain_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_audio_chain_owner
  ON public.audio_chain (owner_account_uuid);
CREATE INDEX IF NOT EXISTS idx_audio_chain_transducer
  ON public.audio_chain (transducer_gear_uuid);
CREATE INDEX IF NOT EXISTS idx_audio_chain_dac_amp
  ON public.audio_chain (dac_amp_gear_uuid);
CREATE INDEX IF NOT EXISTS idx_audio_chain_pairing
  ON public.audio_chain (transducer_gear_uuid, dac_amp_gear_uuid) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_audio_chain_updated_at
  ON public.audio_chain (updated_at);

-- Placement / link table allowing multi-component signal chains with per-slot notes & rank.
CREATE TABLE IF NOT EXISTS public.chain_component (
  id          bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid        uuid NOT NULL UNIQUE,
  chain_uuid  uuid NOT NULL,
  gear_uuid   uuid NOT NULL,
  slot_type   public.chain_slot_enum NOT NULL,
  slot_notes  text,                                              -- e.g., 'High gain, slow roll-off filter', 'SpinFit W1 Medium tips'
  rank        integer NOT NULL DEFAULT 0,
  created_by  uuid,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  CONSTRAINT chain_component_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_chain_component_chain
  ON public.chain_component (chain_uuid);
CREATE INDEX IF NOT EXISTS idx_chain_component_gear
  ON public.chain_component (gear_uuid);
CREATE UNIQUE INDEX IF NOT EXISTS idx_chain_component_live
  ON public.chain_component (chain_uuid, gear_uuid, slot_type) WHERE archived_at IS NULL;

-- -----------------------------------------------------------------------------
-- 5. Offline-First Subjective Listening Journal & Synergy Notes
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.listening_note (
  id                      bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid                    uuid NOT NULL UNIQUE,
  author_account_uuid     uuid NOT NULL,
  chain_uuid              uuid,                                  -- Associated signal chain
  primary_transducer_uuid uuid NOT NULL,                         -- Denormalized read shortcut for fast IEM/headphone lookup
  paired_dac_amp_uuid     uuid,                                  -- Denormalized read shortcut for fast DAC/amp pairing lookup
  title                   text NOT NULL,
  body                    text NOT NULL,                         -- Candid, subjective real-world listening impression
  reference_track         text,                                  -- Song / album used during the session
  music_genre             text,                                  -- e.g., 'Acoustic, Jazz, J-Pop, Indie Rock'
  synergy_verdict         public.synergy_verdict_enum NOT NULL DEFAULT 'aha_synergy',
  soundstage_impression   text,                                  -- Plain-language spatial/staging note
  comfort_impression      text,                                  -- Fit, seal, heat, microphonics, pocketability
  helpful_count           integer NOT NULL DEFAULT 0,            -- Stored aggregate; surfaced publicly only when >= 5 (k-anonymity)
  is_public               boolean NOT NULL DEFAULT true,
  is_hidden_by_moderator  boolean NOT NULL DEFAULT false,
  published_at            timestamptz,
  created_by              uuid,                                  -- Server-stamped from authenticated session
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  archived_at             timestamptz,
  CONSTRAINT listening_note_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_listening_note_author
  ON public.listening_note (author_account_uuid);
CREATE INDEX IF NOT EXISTS idx_listening_note_chain
  ON public.listening_note (chain_uuid);
CREATE INDEX IF NOT EXISTS idx_listening_note_transducer
  ON public.listening_note (primary_transducer_uuid);
CREATE INDEX IF NOT EXISTS idx_listening_note_dac_amp
  ON public.listening_note (paired_dac_amp_uuid);
CREATE INDEX IF NOT EXISTS idx_listening_note_pairing_live
  ON public.listening_note (primary_transducer_uuid, paired_dac_amp_uuid)
  WHERE archived_at IS NULL AND is_public = true AND is_hidden_by_moderator = false;
CREATE INDEX IF NOT EXISTS idx_listening_note_updated_at
  ON public.listening_note (updated_at);

-- Curated, newcomer-friendly subjective descriptors (no intimidating FR graph jargon).
CREATE TABLE IF NOT EXISTS public.synergy_tag (
  id          bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid        uuid NOT NULL UNIQUE,
  slug        text NOT NULL,                                     -- e.g., 'opened-up-soundstage', 'zero-hiss-clean-floor', 'warm-analog'
  label       text NOT NULL,                                     -- e.g., 'Opened up soundstage', 'Zero hiss / clean background'
  category    text NOT NULL,                                     -- e.g., 'synergy', 'tonality', 'comfort', 'use_case'
  description text,
  rank        integer NOT NULL DEFAULT 0,
  created_by  uuid,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  CONSTRAINT synergy_tag_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_synergy_tag_slug_live
  ON public.synergy_tag (lower(slug)) WHERE archived_at IS NULL;

-- Link / placement table attaching curated synergy tags to a listening note.
CREATE TABLE IF NOT EXISTS public.listening_note_tag (
  id                  bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid                uuid NOT NULL UNIQUE,
  listening_note_uuid uuid NOT NULL,
  synergy_tag_uuid    uuid NOT NULL,
  rank                integer NOT NULL DEFAULT 0,
  created_by          uuid,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  archived_at         timestamptz,
  CONSTRAINT listening_note_tag_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_listening_note_tag_note
  ON public.listening_note_tag (listening_note_uuid);
CREATE INDEX IF NOT EXISTS idx_listening_note_tag_tag
  ON public.listening_note_tag (synergy_tag_uuid);
CREATE UNIQUE INDEX IF NOT EXISTS idx_listening_note_tag_live
  ON public.listening_note_tag (listening_note_uuid, synergy_tag_uuid) WHERE archived_at IS NULL;

-- Non-gamified "Helped Me Decide" feedback (no convertible rewards, no user karma).
CREATE TABLE IF NOT EXISTS public.helpful_signal (
  id                  bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid                uuid NOT NULL UNIQUE,
  listening_note_uuid uuid NOT NULL,
  voter_account_uuid  uuid NOT NULL,
  created_by          uuid,                                      -- Server-stamped from authenticated session
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  archived_at         timestamptz,
  CONSTRAINT helpful_signal_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_helpful_signal_note
  ON public.helpful_signal (listening_note_uuid);
CREATE INDEX IF NOT EXISTS idx_helpful_signal_voter
  ON public.helpful_signal (voter_account_uuid);
CREATE UNIQUE INDEX IF NOT EXISTS idx_helpful_signal_live
  ON public.helpful_signal (listening_note_uuid, voter_account_uuid) WHERE archived_at IS NULL;

-- -----------------------------------------------------------------------------
-- 6. Time-Limited, Coarse-Location Local Audition & Availability Pins
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.local_spot_pin (
  id                 bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid               uuid NOT NULL UNIQUE,
  gear_uuid          uuid NOT NULL,
  chain_uuid         uuid,
  coarse_city_code   text NOT NULL,                              -- City/municipality code ONLY; precise lat/lng forbidden
  spot_label         text NOT NULL,                              -- e.g., 'Cebu City Audio Meetup Table', 'Manila Demo Kiosk'
  availability_note  text NOT NULL,                              -- e.g., 'Demo unit available to audition with 4.4mm balanced cable'
  expires_at         timestamptz NOT NULL,                       -- Time-limited pin (24h to 14d TTL)
  created_by         uuid,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  archived_at        timestamptz,
  CONSTRAINT local_spot_pin_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_local_spot_pin_gear
  ON public.local_spot_pin (gear_uuid);
CREATE INDEX IF NOT EXISTS idx_local_spot_pin_city_active
  ON public.local_spot_pin (coarse_city_code, expires_at) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_local_spot_pin_updated_at
  ON public.local_spot_pin (updated_at);

-- -----------------------------------------------------------------------------
-- 7. Community-Guideline Hit Enforcement (Replaces Public Reputation/Karma)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.guideline_hit (
  id                  bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid                uuid NOT NULL UNIQUE,
  target_account_uuid uuid NOT NULL,
  listening_note_uuid uuid,
  gear_uuid           uuid,
  local_spot_pin_uuid uuid,
  rule_code           text NOT NULL,                             -- e.g., 'NO_GATEKEEPING', 'NO_SHILLING_OR_AFFILIATE', 'NO_DOXXING_GPS'
  severity            public.guideline_hit_severity_enum NOT NULL DEFAULT 'hit_1_notice',
  reason_note         text NOT NULL,
  issued_by           uuid NOT NULL,                             -- Server-stamped Moderator/Admin UUID
  issued_at           timestamptz NOT NULL DEFAULT now(),
  expires_at          timestamptz,                               -- Minor hits decay after 90 days
  resolved_by         uuid,
  resolved_at         timestamptz,
  created_by          uuid,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  archived_at         timestamptz,
  CONSTRAINT guideline_hit_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_guideline_hit_target_account
  ON public.guideline_hit (target_account_uuid) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_guideline_hit_note
  ON public.guideline_hit (listening_note_uuid);
CREATE INDEX IF NOT EXISTS idx_guideline_hit_updated_at
  ON public.guideline_hit (updated_at);

-- -----------------------------------------------------------------------------
-- 8. Platform Configuration Settings (Row-Based Settings)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.app_setting (
  id          bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid        uuid NOT NULL UNIQUE,
  feature     text NOT NULL,                                     -- e.g., 'privacy', 'moderation', 'sync'
  name        text NOT NULL,                                     -- e.g., 'k_anonymity_threshold', 'spot_pin_max_ttl_days'
  value       text NOT NULL,                                     -- e.g., '5', '14'
  description text,
  created_by  uuid,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  CONSTRAINT app_setting_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_app_setting_feature_name_live
  ON public.app_setting (feature, name) WHERE archived_at IS NULL;

-- -----------------------------------------------------------------------------
-- 9. Privacy & Aggregation-Threshold Gated Views
-- -----------------------------------------------------------------------------

-- Enforces k >= 5 aggregation threshold on helpful_count and hides archived/moderated notes.
CREATE OR REPLACE VIEW public.v_public_listening_note AS
SELECT
  ln.uuid,
  ln.author_account_uuid,
  ln.chain_uuid,
  ln.primary_transducer_uuid,
  ln.paired_dac_amp_uuid,
  ln.title,
  ln.body,
  ln.reference_track,
  ln.music_genre,
  ln.synergy_verdict,
  ln.soundstage_impression,
  ln.comfort_impression,
  CASE
    WHEN ln.helpful_count >= 5 THEN ln.helpful_count
    ELSE NULL
  END AS visible_helpful_count,
  ln.published_at,
  ln.created_at,
  ln.updated_at
FROM public.listening_note ln
WHERE ln.archived_at IS NULL
  AND ln.is_public = true
  AND ln.is_hidden_by_moderator = false;

-- Enforces time-limited retention on coarse-location local audition/availability pins.
CREATE OR REPLACE VIEW public.v_active_local_spot_pin AS
SELECT
  sp.uuid,
  sp.gear_uuid,
  sp.chain_uuid,
  sp.coarse_city_code,
  sp.spot_label,
  sp.availability_note,
  sp.expires_at,
  sp.created_at,
  sp.updated_at
FROM public.local_spot_pin sp
WHERE sp.archived_at IS NULL
  AND sp.expires_at > now();

COMMIT;
