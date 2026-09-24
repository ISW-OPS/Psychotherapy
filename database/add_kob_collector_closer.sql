-- Migration: psy_kob_sessions.collector_id/collector_name/closer_id/closer_name
-- Additive only — new nullable columns, no changes to existing data.
-- Menggantikan peranan "Doktor" (doctor_hadir_id/doctor_selesai_id KEKAL di DB
-- sbg LEGACY utk rekod lama, tapi tak diisi lagi utk rekod baharu).
-- Safe to re-run.
-- Run on testing (ipmemyiz) first, verify di kob-detail.html (assign Collector/Closer)
-- + kob-list.html (lajur baharu), lepas tu run pada prod (xmvqvq).

ALTER TABLE psy_kob_sessions
  ADD COLUMN IF NOT EXISTS collector_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_kob_sessions
  ADD COLUMN IF NOT EXISTS collector_name TEXT;

ALTER TABLE psy_kob_sessions
  ADD COLUMN IF NOT EXISTS closer_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;

ALTER TABLE psy_kob_sessions
  ADD COLUMN IF NOT EXISTS closer_name TEXT;

COMMENT ON COLUMN psy_kob_sessions.collector_id IS
  'Staff "owner" pesakit sepanjang proses KOB. Ditugaskan/ditukar bila-bila (macam coach_id
   pesakit), TIDAK auto-terikat dgn butang Hadir/Selesai. Assign/tukar di kob-detail.html
   (openChangeKobRole). Staff yg layak dipilih = staff_role ''kob''.';

COMMENT ON COLUMN psy_kob_sessions.closer_id IS
  'Staff yang handle sesi presentation KOB. Berasingan drpd Collector, ditugaskan/ditukar
   bila-bila sama cara. Staff yg layak dipilih = staff_role ''kob''.';
