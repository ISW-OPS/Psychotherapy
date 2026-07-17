-- ============================================================
-- 20260716_reaksi_multi_msg.sql
-- Reaksi Pemulihan — mesej berperingkat (jarak 5-10 minit):
--   Mesej 1: Tindakan / Cadangan Pemulihan   (terus)
--   Mesej 2: Saranan Gaya Hidup Fitrah       (+5 minit)
--   Mesej 3: Saranan Diet & Nutrisi          (+10 minit)
--
-- Sumber kandungan: psy_reaksi_actions.jenis
--   'pemakanan'  -> mesej Diet & Nutrisi (title = tajuk, panduan = senarai makanan)
--   'gaya_hidup' -> mesej Gaya Hidup Fitrah
--   lain-lain    -> mesej Tindakan (macam sedia ada)
--
-- Penghantaran tertangguh: baris psy_reaksi_advice_log status='draft'
-- dengan send_after akan datang; cron panggil reaksi-advice-send
-- (x-cron-secret) tiap 5 minit untuk proses yang sudah cukup masa.
-- Selamat di-run berulang kali (idempotent).
-- ============================================================

-- ── 1. psy_reaksi_advice_log — satu baris SATU MESEJ ─────────
ALTER TABLE psy_reaksi_advice_log
  ADD COLUMN IF NOT EXISTS msg_jenis     TEXT        NOT NULL DEFAULT 'tindakan',
  ADD COLUMN IF NOT EXISTS send_after    TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS send_attempts INT         NOT NULL DEFAULT 0;

DO $$ BEGIN
  ALTER TABLE psy_reaksi_advice_log
    ADD CONSTRAINT chk_reaksi_advice_msg_jenis CHECK (msg_jenis IN ('tindakan','diet','gaya_hidup'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON COLUMN psy_reaksi_advice_log.msg_jenis     IS 'tindakan / diet / gaya_hidup — satu submission Poll Harian boleh jana hingga 3 mesej';
COMMENT ON COLUMN psy_reaksi_advice_log.send_after    IS 'Mesej hanya dihantar selepas waktu ini (queue; cron proses tiap 5 minit)';
COMMENT ON COLUMN psy_reaksi_advice_log.send_attempts IS 'Bilangan percubaan hantar gagal; cron berhenti cuba selepas 5';

CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_queue ON psy_reaksi_advice_log(status, send_after);

-- ── 2. Template mesej baharu dalam psy_auto_messages ─────────
-- Urus di Staff Portal > Mesej Automatik (auto-mesej.html), sama
-- seperti reaksi_harian / reaksi_kritikal. Pesakit boleh baca
-- (policy "auto_msg patient read reaksi": key LIKE 'reaksi_%').
INSERT INTO psy_auto_messages (key, name, description, trigger_type, message_template, placeholders, is_active) VALUES
  ('reaksi_diet',
   'Saranan Diet & Nutrisi',
   'Mesej ke-3 selepas Poll Harian (+10 minit) — saranan pemakanan berdasarkan reaksi dikesan (tindakan jenis "pemakanan").',
   'on_action',
   E'Assalamualaikum {{patient_name}},\n\n🍽️ *Saranan Diet & Nutrisi* untuk membantu pemulihan anda hari ini:\n\n{{diet_list}}\n\nAmalkan mengikut kemampuan dan secara konsisten, insyaAllah.\n\nSalam kasih,\nPasukan Ibnu Sina Wellness 💚',
   '["{{patient_name}}","{{diet_list}}"]'::jsonb,
   true),
  ('reaksi_gaya_hidup',
   'Saranan Gaya Hidup Fitrah',
   'Mesej ke-2 selepas Poll Harian (+5 minit) — saranan gaya hidup fitrah berdasarkan reaksi dikesan (tindakan jenis "gaya_hidup").',
   'on_action',
   E'Assalamualaikum {{patient_name}},\n\n🌿 *Saranan Gaya Hidup Fitrah* untuk hari ini:\n\n{{lifestyle_list}}\n\nSedikit demi sedikit, secara istiqamah — insyaAllah membantu pemulihan anda.\n\nSalam kasih,\nPasukan Ibnu Sina Wellness 💚',
   '["{{patient_name}}","{{lifestyle_list}}"]'::jsonb,
   true)
ON CONFLICT (key) DO NOTHING;

-- ── 2b. Template mesej 1 (reaksi_harian) — format BERKUMPULAN ikut kategori ──
-- {{sections}} = blok per kategori: "Reaksi yang dikesan: <kategori> + senarai
-- simptom" diikuti "Cadangan Pemulihan:" bernombor. Tindakan yang sama disebut
-- SEKALI sahaja untuk seluruh mesej (dedup global oleh klien).
-- UPDATE (bukan insert) supaya DB yang sudah seed versi lama turut dikemaskini.
UPDATE psy_auto_messages SET
  name = 'Cadangan Reaksi Harian',
  description = 'Mesej 1 (terus) selepas Poll Harian — reaksi & Cadangan Pemulihan dikumpulkan ikut kategori; tindakan sama disebut sekali sahaja.',
  message_template = E'Assalamualaikum {{patient_name}},\n\nTerima kasih kerana melengkapkan Poll Harian hari ini.\n\nBerdasarkan jawapan anda, kami mengesan beberapa reaksi pemulihan.\n\n{{sections}}\n\nJika simptom menjadi semakin teruk atau berpanjangan, sila hubungi coach anda.\n\nSemoga Allah mempermudahkan urusan pemulihan anda.\n\nSalam kasih,\nPasukan Ibnu Sina Wellness 💚',
  placeholders = '["{{patient_name}}","{{sections}}"]'::jsonb
WHERE key = 'reaksi_harian';

-- ── 3. (WAJIB SEKALI) Jadualkan cron penghantar queue ─────────
-- reaksi-advice-send perlu di-deploy dengan --no-verify-jwt
-- (mod cron guna x-cron-secret, bukan JWT — sama corak event-reminders):
--   supabase functions deploy reaksi-advice-send --no-verify-jwt
-- Kemudian run SQL ini (ganti <PROJECT_REF> & <CRON_SECRET>):
-- select cron.schedule('reaksi-advice-send', '*/5 * * * *', $$
--   select net.http_post(
--     url := 'https://<PROJECT_REF>.supabase.co/functions/v1/reaksi-advice-send',
--     headers := jsonb_build_object('Content-Type','application/json','x-cron-secret','<CRON_SECRET>'),
--     body := '{}'::jsonb
--   );
-- $$);

SELECT 'OK — reaksi multi-mesej (tindakan +0m, diet +5m, gaya hidup +10m) ready' AS status;
