-- ════════════════════════════════════════════════════════════════
-- step77: Override BIMBINGAN & AKTIVITI per-pesakit per-minggu (Jul 2026)
-- Melengkapkan step75+76. Sebelum ni hanya BEKALAN (supplies_override) &
-- sesi (session_days_override) boleh diubah per-minggu; bimbingan/aktiviti
-- sentiasa dibaca LIVE dari pakej. Kini coach boleh override juga.
--
-- Konsep sama: templat pakej = DEFAULT. Kolum di bawah simpan PENGECUALIAN
-- untuk satu pesakit, satu minggu. Logik baca di UI: override ?? default_pakej.
--
-- Bentuk data (mirror supplies_override): objek per-sesi
--   guidance_override / aktiviti_override = { "1": ["item", ...], "2": [...] }
--   NULL / tiada key = ikut pakej; [] = sesi ni TIADA item.
--
-- Idempotent & selamat jalan semula.
-- ════════════════════════════════════════════════════════════════

ALTER TABLE psy_plan_week_overrides
  ADD COLUMN IF NOT EXISTS guidance_override JSONB,
  ADD COLUMN IF NOT EXISTS aktiviti_override JSONB;

COMMENT ON COLUMN psy_plan_week_overrides.guidance_override IS
  'Bimbingan/Calling khas pesakit ini per-sesi. {"1":[...],"2":[...]}. NULL=ikut pakej; []=tiada.';
COMMENT ON COLUMN psy_plan_week_overrides.aktiviti_override IS
  'Aktiviti khas pesakit ini per-sesi. {"1":[...],"2":[...]}. NULL=ikut pakej; []=tiada.';

SELECT 'step77 OK -- guidance_override + aktiviti_override added' AS status;
