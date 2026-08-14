-- Christian Missionary Fellowship International (CMFI)
-- Foundation Camp 2026 - Trimestral Accountability Form
-- PostgreSQL schema

-- One row per person. A later submission is matched back to an existing
-- row by phone number (normalised to digits only); if that phone has more
-- than one name on record (e.g. siblings sharing a household phone), the
-- submitter is asked to pick which one is them rather than guessing.
-- phone is nullable: someone with no phone at all (not even a shared or
-- borrowed one) is matched by name + locality instead — weaker, but the
-- only option when there is truly no number to use.
CREATE TABLE IF NOT EXISTS people (
    id                          BIGSERIAL PRIMARY KEY,
    full_name                   TEXT NOT NULL,
    phone                       TEXT,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Cleans up the member-code approach from an earlier revision, superseded
-- by phone-based matching above. The old accountability_summary view read
-- this column, so it must be dropped first (recreated further down).
DROP VIEW IF EXISTS accountability_summary;
ALTER TABLE people DROP COLUMN IF EXISTS member_code;

-- A person can have more than one phone number over time (a second SIM, a
-- changed number) or may simply give a second number up front so either
-- one finds their record next time. Every number a person has ever
-- submitted lives here; matching checks all of them, not just one.
CREATE TABLE IF NOT EXISTS person_phones (
    person_id                   BIGINT NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    phone                       TEXT NOT NULL,
    PRIMARY KEY (person_id, phone)
);
CREATE INDEX IF NOT EXISTS idx_person_phones_phone ON person_phones (phone);

-- Backfill: every person created before this table existed only has their
-- one phone recorded on the people row itself.
INSERT INTO person_phones (person_id, phone)
SELECT id, phone FROM people
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS accountability_returns (
    id                          BIGSERIAL PRIMARY KEY,
    submitted_at                TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- A month has two distinct entries: the goal set beforehand and
    -- the actual result reported afterwards. They are a pair, not
    -- duplicates of each other. Never shown or chosen on the form itself —
    -- an internal distinction, set only via a hidden URL flag staff use.
    entry_type                  TEXT NOT NULL DEFAULT 'result' CHECK (entry_type IN ('goal', 'result')),

    -- Identification
    full_name                   TEXT NOT NULL,
    phone                       TEXT,
    phone2                      TEXT,
    -- 0 means "not specified", not unknown/missing — a real, comparable
    -- value so the duplicate-month check still applies to it.
    month_number                SMALLINT NOT NULL DEFAULT 0 CHECK (month_number BETWEEN 0 AND 12),
    locality                    TEXT,
    spiritual_province          TEXT,

    -- Links each return to a person (see people table above) so their
    -- trimestral reports stack up into one history instead of
    -- disconnected rows. Resolved by phone number at submit time.
    person_id                   BIGINT REFERENCES people(id),

    -- 1. Accounts given
    acct_walk_with_god          BOOLEAN NOT NULL DEFAULT FALSE,
    acct_studies                BOOLEAN NOT NULL DEFAULT FALSE,
    acct_finances                BOOLEAN NOT NULL DEFAULT FALSE,
    acct_service_to_god         BOOLEAN NOT NULL DEFAULT FALSE,
    acct_given_to               TEXT,
    acct_frequency              TEXT CHECK (acct_frequency IN ('day', 'week', 'month')),

    -- 2. Daily dynamic encounters with God
    ddeg_number                 INTEGER CHECK (ddeg_number >= 0),
    ddeg_time                   TEXT,

    -- 3. Bible reading
    bible_chapters              INTEGER CHECK (bible_chapters >= 0),
    bible_time                  TEXT,

    -- 4. Bible memorisation
    bible_memorisation          TEXT,

    -- 5. Christian literature: [{ title, pages, author }, ...]
    literature                  JSONB NOT NULL DEFAULT '[]'::jsonb,

    -- 6. Prayer alone
    prayer_alone_time           TEXT,
    retreats_15min              INTEGER CHECK (retreats_15min >= 0),
    thanksgiving_topics         INTEGER CHECK (thanksgiving_topics >= 0),
    prayer_topics               INTEGER CHECK (prayer_topics >= 0),
    prayers_answered            INTEGER CHECK (prayers_answered >= 0),

    -- 7. Prayer with others / house church / local church
    prayer_with_others          TEXT,

    -- 8. Soul winning
    people_reached              INTEGER CHECK (people_reached >= 0),
    conversions                 INTEGER CHECK (conversions >= 0),
    baptised_water              INTEGER CHECK (baptised_water >= 0),
    baptised_holy_spirit        INTEGER CHECK (baptised_holy_spirit >= 0),
    added_to_church             INTEGER CHECK (added_to_church >= 0),
    churches_planted            INTEGER CHECK (churches_planted >= 0),
    members_per_church          TEXT,

    -- 9. Fasts
    fasts_wednesday             INTEGER CHECK (fasts_wednesday >= 0),
    fasts_complete_3days        INTEGER CHECK (fasts_complete_3days >= 0),
    people_encouraged_to_fast   INTEGER CHECK (people_encouraged_to_fast >= 0),

    -- 10. Proclamations of the prophecy
    prophecy_proclamations      INTEGER CHECK (prophecy_proclamations >= 0),

    -- 11. Finances
    giving_percentage           NUMERIC(5,2) CHECK (giving_percentage >= 0 AND giving_percentage <= 100),
    giving_faithful             BOOLEAN,
    has_savings                 BOOLEAN,
    savings_amount              NUMERIC(14,2) CHECK (savings_amount >= 0),
    is_indebted                 BOOLEAN,
    debt_amount                 NUMERIC(14,2) CHECK (debt_amount >= 0),
    debt_reimbursed             NUMERIC(14,2) CHECK (debt_reimbursed >= 0),

    -- 12. Bertoua message
    bertoua_units_completed     INTEGER CHECK (bertoua_units_completed >= 0),
    bertoua_times_done          INTEGER CHECK (bertoua_times_done >= 0),

    -- 13. Uprooting of idols
    idols_uprooted              INTEGER CHECK (idols_uprooted >= 0),

    -- 14. Proclamations
    proclamations               INTEGER CHECK (proclamations >= 0),

    -- 15-17. Narrative sections
    five_year_goal              TEXT,
    distinct_service            TEXT,
    making_disciples            TEXT
);

-- Idempotent safety net for any environment where these were added after
-- the initial release via ALTER TABLE, rather than being present in the
-- CREATE TABLE above from the start (a fresh database already has them).
ALTER TABLE accountability_returns ADD COLUMN IF NOT EXISTS person_id BIGINT REFERENCES people(id);
-- Reversed from an earlier revision: phone was made required, but someone
-- with no phone at all still needs to be able to submit (matched by name +
-- locality instead).
ALTER TABLE people ALTER COLUMN phone DROP NOT NULL;
ALTER TABLE accountability_returns ALTER COLUMN phone DROP NOT NULL;
ALTER TABLE accountability_returns
    ADD COLUMN IF NOT EXISTS entry_type TEXT NOT NULL DEFAULT 'result'
    CHECK (entry_type IN ('goal', 'result'));
ALTER TABLE accountability_returns ADD COLUMN IF NOT EXISTS phone2 TEXT;

-- Renamed from trimester_number: the form moved from a trimestral to a
-- monthly cadence. Guarded by an existence check so a fresh database
-- (whose CREATE TABLE above already creates month_number directly) is a
-- no-op here.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'accountability_returns' AND column_name = 'trimester_number'
  ) THEN
    ALTER TABLE accountability_returns RENAME COLUMN trimester_number TO month_number;
  END IF;
END $$;

-- 0 now means "not specified" instead of leaving month_number null, so
-- the duplicate check still applies to blank-month submissions. The old
-- constraint (0-4, from the trimester era) must go first, or the UPDATE
-- below that sets 0 would violate it. Dropped by scanning for it rather
-- than by a fixed expected name — an earlier table rebuild left this one
-- under an auto-suffixed name (a naming collision at the time), not the
-- plain one.
DO $$
DECLARE con record;
BEGIN
  FOR con IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'accountability_returns'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%month_number%'
  LOOP
    EXECUTE 'ALTER TABLE accountability_returns DROP CONSTRAINT ' || quote_ident(con.conname);
  END LOOP;
END $$;
UPDATE accountability_returns SET month_number = 0 WHERE month_number IS NULL;
ALTER TABLE accountability_returns ALTER COLUMN month_number SET DEFAULT 0;
ALTER TABLE accountability_returns ALTER COLUMN month_number SET NOT NULL;
ALTER TABLE accountability_returns ADD CONSTRAINT accountability_returns_month_number_check
    CHECK (month_number BETWEEN 0 AND 12);

-- Not useful data for tracking anyone's progress — dropped, the EN/FR
-- toggle on the form itself is untouched, this only stops recording it.
ALTER TABLE accountability_returns DROP COLUMN IF EXISTS form_language;

-- Rubrique 1 ("I gave the accounts of") was removed from the form, and
-- with it the "from the month of" / "to the month of" fields — only the
-- single Month field (month_number) remains, on the first form only.
ALTER TABLE accountability_returns DROP COLUMN IF EXISTS month_from;
ALTER TABLE accountability_returns DROP COLUMN IF EXISTS month_to;

CREATE INDEX IF NOT EXISTS idx_returns_name
    ON accountability_returns (lower(full_name));
CREATE INDEX IF NOT EXISTS idx_returns_period
    ON accountability_returns (month_number, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_returns_province
    ON accountability_returns (spiritual_province);
CREATE INDEX IF NOT EXISTS idx_returns_person
    ON accountability_returns (person_id, submitted_at DESC);
-- Superseded by idx_returns_person_month_type below (renamed along with
-- the column); dropped by old name so an upgraded database doesn't keep
-- both.
DROP INDEX IF EXISTS idx_returns_person_trimester_type;
CREATE INDEX IF NOT EXISTS idx_returns_person_month_type
    ON accountability_returns (person_id, month_number, entry_type);
CREATE INDEX IF NOT EXISTS idx_people_phone
    ON people (phone);

-- ---------------------------------------------------------------------------
-- Nation and province are two different questions.
--
-- The sheet asked "Spiritual province or nation" in one box, and 64% of the
-- first 105 submissions answered it with a country. Only Cameroon is divided
-- into spiritual provinces, so the province is a subdivision of one nation
-- rather than a peer of it.
--
-- spiritual_province keeps its name and now holds one of the Cameroon
-- provinces, or nothing. The original free text is preserved in
-- spiritual_province_legacy so no answer is destroyed by the split and a
-- misfiled one can still be recovered later.
--
-- No CHECK constraint on the province on purpose: four spellings on the
-- official map are still unconfirmed, and a constraint would have to be
-- migrated every time one is corrected. The list is enforced by the dropdown
-- and by validateRow, both of which are one edit away.
-- ---------------------------------------------------------------------------
ALTER TABLE accountability_returns ADD COLUMN IF NOT EXISTS spiritual_nation TEXT;
ALTER TABLE accountability_returns ADD COLUMN IF NOT EXISTS spiritual_province_legacy TEXT;

-- Amounts were recorded with no unit at all. The form labels said FCFA, the
-- schema said nothing, and a Togo member is already on file. XAF and XOF are
-- both "franc CFA" but they are not the same currency.
ALTER TABLE accountability_returns ADD COLUMN IF NOT EXISTS currency TEXT;

CREATE INDEX IF NOT EXISTS idx_returns_nation ON accountability_returns (spiritual_nation);

-- Keep the original answer before anything normalises the column. Runs once:
-- the WHERE clause makes a second migration a no-op.
UPDATE accountability_returns
   SET spiritual_province_legacy = spiritual_province
 WHERE spiritual_province_legacy IS NULL
   AND spiritual_province IS NOT NULL;

-- Monthly "Imitators of ZTF" commitments form. Deliberately independent of
-- people/accountability_returns — not matched or linked to any existing
-- record, each submission just stands on its own.
CREATE TABLE IF NOT EXISTS finance_returns (
    id                          BIGSERIAL PRIMARY KEY,
    submitted_at                TIMESTAMPTZ NOT NULL DEFAULT now(),

    full_name                   TEXT NOT NULL,
    locality                    TEXT,
    phone                       TEXT,
    email                       TEXT,
    nation                      TEXT,
    conversion_date             TEXT,

    -- 1. Daily dynamic encounter with God
    commit_daily_encounter      BOOLEAN,

    -- 2. Complete the Bible: a preset count (1/2/3) or a custom one
    bible_completions_choice    SMALLINT CHECK (bible_completions_choice IN (1, 2, 3)),
    bible_completions_other     INTEGER CHECK (bible_completions_other >= 0),

    -- 6. Memorisation: the whole Bible, the New Testament, or named portions
    bible_memorization_choice   TEXT CHECK (bible_memorization_choice IN ('entire_bible', 'new_testament', 'some_portions')),
    bible_memorization_portions TEXT,

    -- 3. Uprooting idols ("Be Filled with the Holy Spirit"): a preset
    -- frequency or a custom one
    idol_uprooting_frequency    TEXT CHECK (idol_uprooting_frequency IN ('twice_monthly', 'monthly', 'bimonthly')),
    idol_uprooting_other        TEXT,

    -- 7. Bertoua message teaching units: a preset count (7/12/25) or a custom one
    bertoua_units_target        SMALLINT CHECK (bertoua_units_target IN (7, 12, 25)),
    bertoua_units_other         INTEGER CHECK (bertoua_units_other >= 0)
);

-- Superseded content: the form moved from financial commitments (tithe,
-- offering, savings, debts, fasting) to the paper form's spiritual
-- commitments above. Dropped rather than kept alongside, since the page no
-- longer asks any of these questions.
ALTER TABLE finance_returns DROP COLUMN IF EXISTS disciple_maker;
ALTER TABLE finance_returns DROP COLUMN IF EXISTS budget_commitment;
ALTER TABLE finance_returns DROP COLUMN IF EXISTS tithe_commitment;
ALTER TABLE finance_returns DROP COLUMN IF EXISTS offering_commitment;
ALTER TABLE finance_returns DROP COLUMN IF EXISTS has_savings;
ALTER TABLE finance_returns DROP COLUMN IF EXISTS planned_savings_percentage;
ALTER TABLE finance_returns DROP COLUMN IF EXISTS is_indebted;
ALTER TABLE finance_returns DROP COLUMN IF EXISTS fasting_commitment;
ALTER TABLE finance_returns DROP COLUMN IF EXISTS fasting_encourage_count;
-- Month lives only on the first (accountability) form — dropped earlier,
-- restated here so an environment that never ran that migration still ends
-- up in the same place.
ALTER TABLE finance_returns DROP COLUMN IF EXISTS month;

-- Idempotent for any environment where finance_returns was already created
-- before these columns existed (a fresh database already has them via the
-- CREATE TABLE above). The CHECK is inline: when the column already exists,
-- Postgres skips the whole ADD COLUMN clause — constraint included — so a
-- second run can never try to add it twice.
ALTER TABLE finance_returns ADD COLUMN IF NOT EXISTS conversion_date TEXT;
ALTER TABLE finance_returns ADD COLUMN IF NOT EXISTS commit_daily_encounter BOOLEAN;
ALTER TABLE finance_returns ADD COLUMN IF NOT EXISTS bible_completions_choice SMALLINT CHECK (bible_completions_choice IN (1, 2, 3));
ALTER TABLE finance_returns ADD COLUMN IF NOT EXISTS bible_completions_other INTEGER CHECK (bible_completions_other >= 0);
ALTER TABLE finance_returns ADD COLUMN IF NOT EXISTS bible_memorization_choice TEXT CHECK (bible_memorization_choice IN ('entire_bible', 'new_testament', 'some_portions'));
ALTER TABLE finance_returns ADD COLUMN IF NOT EXISTS bible_memorization_portions TEXT;
ALTER TABLE finance_returns ADD COLUMN IF NOT EXISTS idol_uprooting_frequency TEXT CHECK (idol_uprooting_frequency IN ('twice_monthly', 'monthly', 'bimonthly'));
ALTER TABLE finance_returns ADD COLUMN IF NOT EXISTS idol_uprooting_other TEXT;
ALTER TABLE finance_returns ADD COLUMN IF NOT EXISTS bertoua_units_target SMALLINT CHECK (bertoua_units_target IN (7, 12, 25));
ALTER TABLE finance_returns ADD COLUMN IF NOT EXISTS bertoua_units_other INTEGER CHECK (bertoua_units_other >= 0);

CREATE INDEX IF NOT EXISTS idx_finance_returns_name
    ON finance_returns (lower(full_name));
CREATE INDEX IF NOT EXISTS idx_finance_returns_period
    ON finance_returns (submitted_at DESC);

-- Convenience view for the province secretaries.
-- Dropped and recreated (rather than CREATE OR REPLACE) because the column
-- list has changed shape since the view was first created, which CREATE OR
-- REPLACE VIEW does not allow.
DROP VIEW IF EXISTS accountability_summary;
CREATE VIEW accountability_summary AS
SELECT
    r.id,
    r.submitted_at,
    r.person_id,
    r.entry_type,
    r.full_name,
    r.phone,
    r.month_number,
    r.locality,
    r.spiritual_nation,
    r.spiritual_province,
    r.spiritual_province_legacy,
    r.currency,
    r.ddeg_number,
    r.bible_chapters,
    r.people_reached,
    r.conversions,
    r.added_to_church,
    r.fasts_wednesday + r.fasts_complete_3days AS total_fasts,
    r.proclamations,
    r.idols_uprooted
FROM accountability_returns r;
