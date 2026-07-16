-- ============================================================
-- 20260715_reaksi_engine_v2.sql
-- Reaksi & Tindakan v2 — sokongan UI penuh Staff Portal:
--   1. psy_reaksi_item  : tahap risiko, markah, penerangan, contoh,
--                         flag tindakan-jika-dipilih (pemantauan/notifikasi/kecemasan)
--   2. psy_reaksi_actions: kategori, jenis tindakan, panduan penyediaan
--   3. Template mesej WA reaksi = 2 baris psy_auto_messages (Mesej Automatik)
--      -> generateReaksiAdvice (patient) baca reaksi_harian / reaksi_kritikal
-- Selamat di-run berulang kali (idempotent).
-- ============================================================

-- ── 1. psy_reaksi_item — tetapan risiko per simptom ──────────
ALTER TABLE psy_reaksi_item
  ADD COLUMN IF NOT EXISTS tahap_risiko     TEXT    NOT NULL DEFAULT 'rendah',
  ADD COLUMN IF NOT EXISTS markah_risiko    INT     NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS penerangan       TEXT,
  ADD COLUMN IF NOT EXISTS contoh           JSONB   NOT NULL DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS perlu_pemantauan BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS tunjuk_ringkasan BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notifikasi_coach BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_emergency     BOOLEAN NOT NULL DEFAULT false;

DO $$ BEGIN
  ALTER TABLE psy_reaksi_item
    ADD CONSTRAINT chk_reaksi_item_tahap CHECK (tahap_risiko IN ('rendah','sederhana','tinggi'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON COLUMN psy_reaksi_item.tahap_risiko  IS 'rendah (Green) / sederhana (Yellow) / tinggi (Red)';
COMMENT ON COLUMN psy_reaksi_item.markah_risiko IS 'Julat 1-100, semakin tinggi semakin berisiko';
COMMENT ON COLUMN psy_reaksi_item.contoh        IS 'Array string — contoh bagaimana simptom dirasai pesakit';
COMMENT ON COLUMN psy_reaksi_item.is_emergency  IS 'Simptom kecemasan: advice log ditanda emergency (tidak auto-hantar WA)';

-- ── 2. psy_reaksi_actions — kategori / jenis / panduan ───────
ALTER TABLE psy_reaksi_actions
  ADD COLUMN IF NOT EXISTS kategori TEXT,
  ADD COLUMN IF NOT EXISTS jenis    TEXT NOT NULL DEFAULT 'am',
  ADD COLUMN IF NOT EXISTS panduan  TEXT;

DO $$ BEGIN
  ALTER TABLE psy_reaksi_actions
    ADD CONSTRAINT chk_reaksi_actions_jenis CHECK (jenis IN ('am','pemakanan','gaya_hidup','terapi','pemerhatian','tindakan','kecemasan'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON COLUMN psy_reaksi_actions.kategori IS 'Kategori bebas (biasanya kumpulan simptom, cth Pencernaan)';
COMMENT ON COLUMN psy_reaksi_actions.jenis    IS 'am/pemakanan/gaya_hidup/terapi/pemerhatian/tindakan/kecemasan';
COMMENT ON COLUMN psy_reaksi_actions.panduan  IS 'Panduan / cara penyediaan terperinci (teks; baris baharu dikekalkan)';

-- ── 2b. Kategori reaksi — jadual sendiri (penerangan / status / susunan) ──
-- psy_reaksi_item.kumpulan kekal TEXT dan dipadankan dengan nama kategori.
CREATE TABLE IF NOT EXISTS psy_reaksi_kategori (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama       TEXT NOT NULL UNIQUE,
  ikon       TEXT,
  penerangan TEXT,
  aktif      BOOLEAN NOT NULL DEFAULT true,
  urutan     INT NOT NULL DEFAULT 100,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE psy_reaksi_kategori ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Staff manage reaksi kategori" ON psy_reaksi_kategori FOR ALL
    USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Authenticated read reaksi kategori" ON psy_reaksi_kategori FOR SELECT
    USING (auth.uid() IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Seed dari kumpulan sedia ada dalam psy_reaksi_item
INSERT INTO psy_reaksi_kategori (nama, ikon, urutan)
SELECT kumpulan, MAX(COALESCE(ikon, '')), MIN(COALESCE(urutan, 100))
FROM psy_reaksi_item GROUP BY kumpulan
ON CONFLICT (nama) DO NOTHING;

-- ── 3. Template mesej WhatsApp — GUNA psy_auto_messages (Mesej Automatik) ──
-- Tiada jadual baharu: template saranan reaksi ialah 2 baris dalam
-- psy_auto_messages (urus di Staff Portal > Mesej Automatik, auto-mesej.html).
-- Pemboleh ubah: {{patient_name}} {{symptom_list}} {{action_list}} {{emergency_message}}
INSERT INTO psy_auto_messages (key, name, description, trigger_type, message_template, placeholders, is_active) VALUES
  ('reaksi_harian',
   'Cadangan Reaksi Harian',
   'Dihantar automatik ke WhatsApp pesakit selepas Poll Harian jika ada reaksi dikesan (bukan kecemasan).',
   'on_action',
   E'Assalamualaikum {{patient_name}},\n\nTerima kasih kerana melengkapkan Poll Harian hari ini.\n\nBerdasarkan jawapan anda, sistem mengesan beberapa reaksi pemulihan.\n\nReaksi yang dikesan:\n{{symptom_list}}\n\nCadangan Pemulihan:\n{{action_list}}\n\n{{emergency_message}}Jika simptom menjadi semakin teruk atau berpanjangan, sila hubungi coach anda.\n\nSemoga Allah mempermudahkan urusan pemulihan anda.\n\nSalam kasih,\nPasukan Ibnu Sina Wellness 💚',
   '["{{patient_name}}","{{symptom_list}}","{{action_list}}","{{emergency_message}}"]'::jsonb,
   true),
  ('reaksi_kritikal',
   'Cadangan Reaksi Kritikal',
   'Draf mesej untuk reaksi berisiko tinggi / kecemasan — TIDAK auto-hantar, staff semak & hantar dari halaman Semak & Hantar Mesej.',
   'on_action',
   E'Assalamualaikum {{patient_name}},\n\n🚨 PENTING: Berdasarkan Poll Harian anda, terdapat simptom yang memerlukan perhatian segera.\n\nReaksi yang dikesan:\n{{symptom_list}}\n\nTindakan disyorkan:\n{{action_list}}\n\nSila hubungi coach anda DENGAN SEGERA atau dapatkan rawatan di hospital berdekatan jika keadaan serius.\n\nPasukan Ibnu Sina Wellness',
   '["{{patient_name}}","{{symptom_list}}","{{action_list}}"]'::jsonb,
   true)
ON CONFLICT (key) DO NOTHING;

-- Pesakit perlu BACA template reaksi sahaja (client jana mesej semasa submit
-- Poll Harian). Template auto-mesej lain kekal staff-only.
DO $$ BEGIN
  CREATE POLICY "auto_msg patient read reaksi" ON psy_auto_messages FOR SELECT
    USING (auth.uid() IS NOT NULL AND key LIKE 'reaksi_%' AND is_active = true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── 4. Trigger notifikasi kecemasan — kemaskini mesej & pautan ──
-- Halaman reaksi-advice.html DIBUANG: semua saranan (termasuk kecemasan)
-- kini auto-hantar ke WhatsApp. Notifikasi coach jadi amaran susulan,
-- pautan ke halaman Kepatuhan (lihat log pesakit).
CREATE OR REPLACE FUNCTION trg_reaksi_advice_notify_emergency()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
BEGIN
  IF NOT NEW.is_emergency THEN RETURN NEW; END IF;

  SELECT pt.coach_id, COALESCE(pr.full_name, pt.full_name, 'Pesakit')
    INTO v_coach_id, v_patient_name
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;

  IF v_coach_id IS NOT NULL THEN
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🚨 Reaksi Kecemasan: ' || v_patient_name,
      v_patient_name || ' melaporkan simptom kecemasan. Saranan telah dihantar automatik ke WhatsApp — sila susul pesakit dengan segera.',
      'kepatuhan.html'
    );
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_reaksi_advice_notify_emergency: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Indeks
CREATE INDEX IF NOT EXISTS idx_reaksi_item_tahap ON psy_reaksi_item(tahap_risiko);

SELECT 'OK — reaksi engine v2 (risiko + jenis tindakan + templates) ready' AS status;
