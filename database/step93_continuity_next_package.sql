-- step93_continuity_next_package.sql
-- KERJA B (pakej sambungan / continuity package): pesakit terima tawaran pakej BARU & bayar,
-- tetapi pelan baru TIDAK aktif serta-merta — ia BERATUR (queued) sehingga pakej lama SELESAI,
-- kemudian AUTO-AKTIF. Pelan lama kekal sebagai 'completed' (History — data sesi tak dipadam).
--
-- 1) Lajur pada psy_patients untuk simpan pakej yang beratur.
-- 2) Naik taraf fn_auto_inactive_on_session_done (step80/step92): bila pelan selesai —
--    - jika ada next_package_id → tukar jadi pakej aktif, cipta pelan baru, pesakit KEKAL aktif.
--    - jika tiada → kelakuan lama (pesakit inactive + outcome completed).
--
-- psy_package_purchases.status guna nilai 'queued' untuk purchase yang dibayar tapi belum aktif
-- (lajur TEXT, tiada enum — tak perlu ubah skema).
--
-- Jalankan di TESTING dahulu, kemudian PRODUCTION (xmvqvq).

-- ── 1) Lajur pakej beratur ──────────────────────────────────────────────
ALTER TABLE psy_patients
  ADD COLUMN IF NOT EXISTS next_package_id   TEXT,
  ADD COLUMN IF NOT EXISTS next_package_name TEXT;

COMMENT ON COLUMN psy_patients.next_package_id IS
  'Pakej sambungan (continuity) yang sudah dibayar & beratur; auto-aktif bila pakej semasa selesai (step93).';

-- ── 2) Trigger: selesai pelan → auto-aktif pakej sambungan (jika ada) ────
CREATE OR REPLACE FUNCTION fn_auto_inactive_on_session_done()
RETURNS TRIGGER AS $$
DECLARE
  v_patient_id    UUID;
  v_pstatus       TEXT;
  v_pkg_expired   BOOLEAN;
  v_all_done      BOOLEAN;
  v_has_core      BOOLEAN;
  v_next_pkg      TEXT;
  v_next_name     TEXT;
BEGIN
  IF NEW.status NOT IN ('hadir','consultation_done') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT patient_id INTO v_patient_id FROM psy_treatment_plans WHERE id = NEW.plan_id;
  IF v_patient_id IS NULL THEN RETURN NEW; END IF;

  -- v_all_done: tiada sesi teras belum selesai + tiada minggu continuity BERBAYAR belum selesai (step92).
  SELECT
    EXISTS (SELECT 1 FROM psy_plan_weekly_progress
            WHERE plan_id = NEW.plan_id AND COALESCE(is_extension,false) = false),
    NOT EXISTS (
      SELECT 1 FROM psy_plan_weekly_progress
      WHERE plan_id = NEW.plan_id
        AND status NOT IN ('hadir','consultation_done')
        AND (
          COALESCE(is_extension,false) = false
          OR (COALESCE(extension_for_week, -1) = 0 AND status <> 'extension_pending_payment')
        )
    )
    INTO v_has_core, v_all_done;

  SELECT status, (package_expires_at IS NOT NULL AND package_expires_at < now()),
         next_package_id, next_package_name
    INTO v_pstatus, v_pkg_expired, v_next_pkg, v_next_name
    FROM psy_patients WHERE id = v_patient_id;

  IF v_pstatus IN ('inactive','archived','deceased','deleted') THEN
    RETURN NEW;
  END IF;

  IF (v_has_core AND v_all_done) OR v_pkg_expired THEN
    -- Pelan lama SELESAI (kekal di History — tiada data dipadam).
    UPDATE psy_treatment_plans SET status = 'completed'
      WHERE id = NEW.plan_id AND status <> 'completed';

    IF v_next_pkg IS NOT NULL AND v_next_pkg <> '' THEN
      -- ── Ada pakej sambungan beratur → AUTO-AKTIF, pesakit KEKAL aktif ──
      UPDATE psy_patients
        SET active_package_id    = v_next_pkg,
            active_package_name  = COALESCE(v_next_name, active_package_name),
            package_purchased_at = now(),
            package_expires_at   = now() + interval '3 months',
            next_package_id      = NULL,
            next_package_name    = NULL,
            status               = 'active'
        WHERE id = v_patient_id;

      -- Purchase beratur → aktif (tempoh 3 bulan bermula dari pengaktifan).
      UPDATE psy_package_purchases
        SET status = 'active', expires_at = now() + interval '3 months'
        WHERE patient_id = v_patient_id AND package_id = v_next_pkg AND status = 'queued';

      -- Cipta pelan baru dari pakej sambungan (jika belum wujud). Baris mingguan dijana
      -- kemudian bila pesakit set jadual (sama seperti pakej baru biasa).
      INSERT INTO psy_treatment_plans
        (patient_id, name, template, duration_unit, duration_weeks, current_week, coaching_schedule, status)
      SELECT v_patient_id, COALESCE(pk.name,'Pakej') || ' Treatment Plan', pk.package_id,
             COALESCE(pk.duration_unit,'week'), COALESCE(pk.duration_weeks,12), 1,
             COALESCE(pk.coaching_schedule, '[]'::jsonb), 'active'
      FROM psy_packages pk
      WHERE pk.package_id = v_next_pkg
        AND NOT EXISTS (
          SELECT 1 FROM psy_treatment_plans
          WHERE patient_id = v_patient_id AND template = v_next_pkg AND status = 'active'
        );
    ELSE
      -- ── Tiada sambungan → kelakuan lama: pesakit inactive + outcome completed ──
      UPDATE psy_patients
        SET status = 'inactive',
            outcome_status = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                  THEN 'completed' ELSE outcome_status END,
            outcome_status_at = CASE WHEN outcome_status IS NULL OR outcome_status = ''
                                     THEN now() ELSE outcome_status_at END
        WHERE id = v_patient_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT 'OK — continuity next-package auto-activation dipasang (step93)' AS status;
