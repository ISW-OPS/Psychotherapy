-- Jaringan keselamatan: satu pesakit tak boleh ada 2 plan AKTIF utk pakej (template) sama
-- serentak. Punca duplicate disahkan prod 7 Ogos (pesakit 234bb418..., pakej "Overhaul Body
-- Diamond Y1" — 3 baris dicipta dlm 44 saat): race condition dalam trigger
-- fn_auto_inactive_on_session_done (auto-aktif pakej sambungan/continuity bila plan lama
-- selesai) — INSERT guna NOT EXISTS semakan bukan-atom, boleh race bila >1 baris
-- psy_plan_weekly_progress ditanda hadir hampir serentak. Race sama juga wujud (secara
-- berasingan) dalam supabase/functions/payments-webhook (HitPay retry webhook) — dah dibetulkan
-- di kod, relevan utk testing (payments-webhook tak deploy ke prod lagi).
-- Rujuk: database/schema/07_treatment_plans.sql

-- 1) SEMAK DULU sebelum run bahagian 2 — kalau query ni pulangkan baris, ada pesakit LAIN
--    yang juga kena isu sama (>1 plan status='active' utk template sama). CREATE UNIQUE INDEX
--    di bawah akan GAGAL kalau data macam ni masih wujud — kena selesaikan dulu (guna butang
--    "🗑️ Padam" di Pakej & Sejarah utk buang duplicate, atau tukar status yang tak patut aktif).
--
-- SELECT patient_id, template, count(*), array_agg(id) AS plan_ids
-- FROM psy_treatment_plans
-- WHERE status = 'active'
-- GROUP BY patient_id, template
-- HAVING count(*) > 1;

-- 2) Constraint sebenar — run bila (1) di atas dah bersih (tiada baris pulang).
CREATE UNIQUE INDEX IF NOT EXISTS uq_treatment_plans_active_patient_template
  ON psy_treatment_plans(patient_id, template) WHERE status = 'active';

-- 3) Trigger fn_auto_inactive_on_session_done — tangkap unique_violation supaya UPDATE
--    "tandakan hadir" yang mencetuskan trigger ni tak gagal walaupun panggilan/trigger lain
--    (concurrent) menang race dulu (unique index di atas yang jadi jaringan keselamatan sebenar).
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

  -- v_all_done: tiada sesi teras belum selesai + tiada minggu continuity BERBAYAR belum selesai.
  -- Minggu continuity ditanda extension_for_week = 0; absen (extension_for_week >= 1) tak menghalang.
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
      -- NOT EXISTS di bawah cuma "best-effort" — boleh race bila >1 baris psy_plan_weekly_progress
      -- ditanda hadir hampir serentak (setiap satu cetus trigger ni secara berasingan).
      -- uq_treatment_plans_active_patient_template (unique index) ialah jaringan keselamatan
      -- SEBENAR; tangkap unique_violation di sini supaya UPDATE hadir yang mencetuskan trigger
      -- ni tak gagal walaupun panggilan/trigger lain menang race dulu (punca duplicate plan
      -- prod 7 Ogos — 3 baris "Overhaul Body Diamond Y1" dicipta dlm 44 saat utk 1 pesakit).
      BEGIN
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
      EXCEPTION WHEN unique_violation THEN
        NULL; -- plan aktif utk pakej sambungan ni dah dicipta oleh panggilan serentak — abaikan.
      END;
    ELSE
      -- ── Tiada sambungan → pesakit inactive + outcome completed ──
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
-- Trigger trg_auto_inactive sedia ada sudah rujuk fungsi ni — tiada perlu DROP/CREATE semula.
