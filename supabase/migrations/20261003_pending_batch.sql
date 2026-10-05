-- ═══════════════════════════════════════════════════════════════════
-- BATCH MIGRATION — gabungan semua migration yang belum dijalankan
-- (menggantikan 20261003, 20261005, 20261006, 20261007).
-- Susunan asal dikekalkan. Setiap bahagian boleh dijalankan semula dengan selamat
-- (IF NOT EXISTS / DROP IF EXISTS / CREATE OR REPLACE / backfill hanya bila item_id kosong).
--
--   A. Pengesahan Pesakit: clear patient_confirmed bila status cancel/reschedule (trigger)
--   B. Tugas Coach berulang + log + aktiviti
--   C. Kit Prosedur: item_id pada setiap entri kit (backfill ikut nama tepat)
--   D. Pautan Waze (psy_suppliers.location_url) & Shopee (psy_inventory_items.shopee_url)
-- ═══════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────
-- A. Audit Pelan Mingguan — elak sesi bercanggah (Tidak Hadir/dijadual semula tapi masih "Disahkan")
-- Rujuk: database/schema/07_treatment_plans.sql
-- ───────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION fn_clear_confirm_on_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('cancel','reschedule') AND NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.patient_confirmed := NULL;
    NEW.patient_confirmed_at := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_clear_confirm_on_status_change ON psy_plan_weekly_progress;

CREATE TRIGGER trg_clear_confirm_on_status_change
  BEFORE UPDATE ON psy_plan_weekly_progress
  FOR EACH ROW
  EXECUTE FUNCTION fn_clear_confirm_on_status_change();


-- ───────────────────────────────────────────────────────────────────
-- B. Tugas Coach berulang (setiap hari / hari tertentu) — dipaparkan dalam Jadual Mingguan
-- Task berulang simpan status setiap kejadian dalam psy_coach_task_logs (satu task = satu rekod).
-- Rujuk: database/schema/18_notifications_automations.sql
-- ───────────────────────────────────────────────────────────────────

ALTER TABLE psy_coach_tasks
  ADD COLUMN IF NOT EXISTS recur_type  TEXT NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS recur_days  INT[],
  ADD COLUMN IF NOT EXISTS recur_until DATE,
  ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::jsonb;

ALTER TABLE psy_coach_tasks DROP CONSTRAINT IF EXISTS psy_coach_tasks_recur_type_check;
ALTER TABLE psy_coach_tasks ADD CONSTRAINT psy_coach_tasks_recur_type_check
  CHECK (recur_type IN ('none','daily','weekly'));

CREATE TABLE IF NOT EXISTS psy_coach_task_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id     UUID NOT NULL REFERENCES psy_coach_tasks(id) ON DELETE CASCADE,
  log_date    DATE NOT NULL,
  status      TEXT NOT NULL DEFAULT 'belum_mula' CHECK (status IN ('belum_mula','dalam_proses','selesai')),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT psy_coach_task_logs_task_date_key UNIQUE (task_id, log_date)
);

ALTER TABLE psy_coach_task_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coach_task_logs_own" ON psy_coach_task_logs;
CREATE POLICY "coach_task_logs_own" ON psy_coach_task_logs
  USING (EXISTS (SELECT 1 FROM psy_coach_tasks t WHERE t.id = task_id AND t.coach_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_coach_tasks t WHERE t.id = task_id AND t.coach_id = auth.uid()));

DROP POLICY IF EXISTS "coach_task_logs_manager_read" ON psy_coach_task_logs;
CREATE POLICY "coach_task_logs_manager_read" ON psy_coach_task_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('manager','admin'))
  );

-- Log aktiviti task (siapa buat apa, bila) — dipaparkan di halaman detail task
CREATE TABLE IF NOT EXISTS psy_coach_task_activity (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id     UUID NOT NULL REFERENCES psy_coach_tasks(id) ON DELETE CASCADE,
  actor_id    UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  actor_name  TEXT,
  action      TEXT NOT NULL,
  detail      JSONB DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_coach_task_activity_task ON psy_coach_task_activity (task_id, created_at DESC);

ALTER TABLE psy_coach_task_activity ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coach_task_activity_own" ON psy_coach_task_activity;
CREATE POLICY "coach_task_activity_own" ON psy_coach_task_activity
  USING (EXISTS (SELECT 1 FROM psy_coach_tasks t WHERE t.id = task_id AND t.coach_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_coach_tasks t WHERE t.id = task_id AND t.coach_id = auth.uid()));

DROP POLICY IF EXISTS "coach_task_activity_manager_read" ON psy_coach_task_activity;
CREATE POLICY "coach_task_activity_manager_read" ON psy_coach_task_activity
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff' AND staff_role IN ('manager','admin'))
  );


-- ───────────────────────────────────────────────────────────────────
-- C. Kit Prosedur: simpan item_id (ID Inventori) pada setiap entri kit
-- Backfill HANYA bila nama padan tepat dengan SATU item inventori (case-insensitive).
-- Entri yang dah ada item_id tak diubah. Struktur jadual kekal (JSONB).
-- ───────────────────────────────────────────────────────────────────

WITH unique_items AS (
  SELECT lower(trim(name)) AS match_key, (array_agg(id))[1] AS item_id
  FROM psy_inventory_items
  GROUP BY lower(trim(name))
  HAVING count(*) = 1
)
UPDATE psy_procedure_kits k
SET items = (
  SELECT coalesce(jsonb_agg(
    CASE
      WHEN u.item_id IS NULL OR (e->>'item_id') IS NOT NULL THEN e
      ELSE jsonb_set(e, '{item_id}', to_jsonb(u.item_id::text))
    END
    ORDER BY ord
  ), '[]'::jsonb)
  FROM jsonb_array_elements(k.items) WITH ORDINALITY AS t(e, ord)
  LEFT JOIN unique_items u ON u.match_key = lower(trim(e->>'item_name'))
)
WHERE jsonb_typeof(k.items) = 'array'
  AND jsonb_array_length(k.items) > 0;


-- ───────────────────────────────────────────────────────────────────
-- D. Pautan Waze pada supplier & pautan Shopee pada produk inventori
-- Kedua-dua optional. Data sedia ada tak terjejas.
-- ───────────────────────────────────────────────────────────────────

ALTER TABLE psy_suppliers ADD COLUMN IF NOT EXISTS location_url TEXT;      -- pautan Waze lokasi supplier
ALTER TABLE psy_inventory_items ADD COLUMN IF NOT EXISTS shopee_url TEXT;  -- pautan Shopee untuk beli produk ini
