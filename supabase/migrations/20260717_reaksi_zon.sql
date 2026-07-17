-- ============================================================
-- 20260717_reaksi_zon.sql
-- Red Emergency Protocol — ZON per submission Poll Harian.
--
-- Zon dikira klien dari Tahap Risiko TERTINGGI simptom dipilih:
--   hijau  (semua rendah)      → pesakit ikut saranan sahaja
--   kuning (ada sederhana)     → + notifikasi coach "perlu perhatian"
--   merah  (ada tinggi / kecemasan) → SATU mesej kritikal (pergi hospital
--            + hubungi coach) + notifikasi coach 🚨
--
-- Selamat di-run berulang kali (idempotent).
-- Prasyarat: 20260715 (tahap_risiko) + 20260716 (msg_jenis/send_after).
-- ============================================================

-- ── 1. Kolum zon pada log saranan ────────────────────────────
ALTER TABLE psy_reaksi_advice_log
  ADD COLUMN IF NOT EXISTS zon TEXT;

DO $$ BEGIN
  ALTER TABLE psy_reaksi_advice_log
    ADD CONSTRAINT chk_reaksi_advice_zon CHECK (zon IN ('hijau','kuning','merah'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON COLUMN psy_reaksi_advice_log.zon IS 'hijau/kuning/merah — zon protokol dikira dari tahap_risiko tertinggi simptom submission ini';

-- ── 2. Trigger notifikasi coach — merah (🚨) & kuning (🟡) ────
-- Satu submission boleh insert hingga 3 baris mesej serentak; notifikasi
-- hanya utk BARIS PERTAMA (send_after ≈ created_at; baris 2/3 = +5/+10 min).
CREATE OR REPLACE FUNCTION trg_reaksi_advice_notify_emergency()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_coach_id     UUID;
  v_patient_name TEXT;
  v_first_row    BOOLEAN;
BEGIN
  -- Baris pertama submission sahaja (elak notifikasi berganda 3x)
  v_first_row := (NEW.send_after IS NULL OR NEW.send_after <= NEW.created_at + interval '2 minutes');
  IF NOT v_first_row THEN RETURN NEW; END IF;

  IF NOT (NEW.is_emergency OR NEW.zon IN ('merah','kuning')) THEN RETURN NEW; END IF;

  SELECT pt.coach_id, COALESCE(pr.full_name, pt.full_name, 'Pesakit')
    INTO v_coach_id, v_patient_name
  FROM psy_patients pt
  LEFT JOIN psy_profiles pr ON pr.id = pt.user_id
  WHERE pt.id = NEW.patient_id;
  IF v_coach_id IS NULL THEN RETURN NEW; END IF;

  IF NEW.is_emergency OR NEW.zon = 'merah' THEN
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🔴 ZON MERAH: ' || v_patient_name,
      v_patient_name || ' melaporkan simptom tahap tinggi/kecemasan dalam Poll Harian. Pesakit dinasihatkan ke hospital & telah dihantar mesej kritikal — sila susul SEGERA.',
      'kepatuhan.html'
    );
  ELSE
    INSERT INTO psy_notifications (user_id, type, title, body, link)
    VALUES (
      v_coach_id, 'reaksi',
      '🟡 Zon Kuning: ' || v_patient_name,
      v_patient_name || ' melaporkan simptom tahap sederhana dalam Poll Harian — perlukan perhatian coach. Sila semak dan susul pesakit.',
      'kepatuhan.html'
    );
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_reaksi_advice_notify_emergency: %', SQLERRM;
  RETURN NEW;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_reaksi_advice_log_zon ON psy_reaksi_advice_log(zon, log_date);

SELECT 'OK — zon protokol (hijau/kuning/merah) + notifikasi coach ready' AS status;
