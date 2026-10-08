-- Audit #146 (sub-3, 7 Okt 2026) — lanjutkan trg_patient_warded_auto_event()
-- (dicipta oleh migration 20261007_patient_status_warded.sql) supaya turut
-- auto-cipta SATU task peribadi utk coach pesakit, dipautkan terus kpd
-- pesakit tu (psy_coach_tasks.patient_id) — muncul di widget "Task Peribadi"
-- dashboard coach tanpa staf perlu taip manual.
-- Idempoten (CREATE OR REPLACE FUNCTION) — selamat dijalankan berulang kali.
-- WAJIB migration 20261007_patient_status_warded.sql DAN
-- 20261007_coach_tasks_priority_appointment_sync.sql dijalankan DULU
-- (psy_patients.status='warded' + psy_coach_tasks mesti dah wujud).

CREATE OR REPLACE FUNCTION trg_patient_warded_auto_event()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status <> 'warded' OR OLD.status IS NOT DISTINCT FROM 'warded' THEN
    RETURN NEW;
  END IF;

  -- Elak rekod berganda kalau dah ada rekod 'warded' TERBUKA utk pesakit ni
  -- (cth staf toggle status warded→aktif→warded semula tanpa tutup rekod lama).
  IF EXISTS (
    SELECT 1 FROM psy_patient_events
    WHERE patient_id = NEW.id AND event_type = 'warded' AND status = 'open'
  ) THEN
    RETURN NEW;
  END IF;

  INSERT INTO psy_patient_events (
    patient_id, event_type, priority, status, event_date,
    need_visit, visit_priority, assigned_to, notify_roles, notes, reported_by
  ) VALUES (
    NEW.id, 'warded', 'high', 'open', CURRENT_DATE,
    true, 'high', NEW.coach_id, '["manager","coach"]'::jsonb,
    'Rekod dicipta automatik — status pesakit ditukar ke Warded (Masuk Wad/Hospital).',
    NULL
  );

  -- Audit #146 (sub-3, 7 Okt 2026) — task peribadi auto-cipta & dipautkan kpd
  -- coach pesakit ni (psy_coach_tasks.patient_id), supaya terus muncul di
  -- widget "Task Peribadi" dashboard coach tanpa staf perlu taip manual.
  -- Marker '[auto:warded]' dlm notes elak duplikasi kalau status toggle
  -- warded→aktif→warded berulang kali sebelum task lama ditutup.
  IF NEW.coach_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM psy_coach_tasks
    WHERE patient_id = NEW.id AND coach_id = NEW.coach_id
      AND status <> 'selesai' AND notes LIKE '%[auto:warded]%'
  ) THEN
    INSERT INTO psy_coach_tasks (
      coach_id, title, notes, task_date, priority, status, patient_id
    ) VALUES (
      NEW.coach_id,
      '🏥 Pesakit ' || COALESCE(NEW.full_name, 'Tanpa Nama') || ' masuk Wad/Hospital — rancang lawatan',
      'Dicipta automatik — status pesakit ditukar ke Warded. [auto:warded]',
      CURRENT_DATE, 'tinggi', 'belum_mula', NEW.id
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'trg_patient_warded_auto_event: %', SQLERRM;
  RETURN NEW;
END;
$$;
