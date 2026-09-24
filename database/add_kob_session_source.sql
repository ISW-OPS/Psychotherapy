-- Migration: psy_kob_sessions.source
-- Additive only — new NOT NULL column with DEFAULT, no changes to existing data
-- (rekod sedia ada auto jadi 'system' — betul, sbb sebelum lajur ni wujud
-- hanya sesi dicipta dalam ISW system je yang ada).
-- Safe to re-run.
-- Run on testing (ipmemyiz) first, verify di kob-list.html (lajur Sumber),
-- lepas tu run pada prod (xmvqvq).

ALTER TABLE psy_kob_sessions
  ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'system'
    CHECK (source IN ('system','ghl'));

COMMENT ON COLUMN psy_kob_sessions.source IS
  'Asal tempahan: ''system'' = dicipta dalam ISW system (staff/pesakit sendiri),
   ''ghl'' = disync automatik dari GHL Calendar (lihat _shared/ghl-sync.ts).';
