-- STEP 88 — Status automasi bertiga: draft | active | paused
-- ─────────────────────────────────────────────────────────────────────────
-- Sebelum ni cuma is_active (true/false) → Draf & Tidak Aktif tak dapat
-- diasingkan. Tambah kolum `status`:
--   draft  = dicipta, belum diaktifkan
--   active = sedang jalan (enjin hantar)
--   paused = dulu aktif, kini dimatikan (Tidak Aktif)
-- is_active dikekalkan & disegerakkan (is_active = status='active') supaya
-- enjin sedia ada (filter is_active) tak pecah.
-- Idempotent. WAJIB run TESTING & PROD.

alter table psy_automations add column if not exists status text default 'draft';

-- Backfill dari is_active (rekod lama: aktif→active, else→draft)
update psy_automations set status = case when is_active then 'active' else 'draft' end
where status is null or status not in ('draft','active','paused');

select 'Step 88 OK — psy_automations.status sedia' as status;
