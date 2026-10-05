-- Task peribadi coach boleh berulang (setiap hari / hari tertentu) — dipaparkan
-- dalam Jadual Mingguan. Task berulang simpan status setiap kejadian dalam
-- psy_coach_task_logs (satu task = satu rekod sahaja).
-- Rujuk: database/schema/18_notifications_automations.sql

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
