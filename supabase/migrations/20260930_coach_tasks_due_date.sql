-- Audit Tier 9 #8 — Tugasan Peribadi Coach: tambah medan Due Date berasingan
-- drpd task_date (dulu satu medan double sbg "bila nak buat" DAN "bila deadline").
-- Rujuk: database/schema/18_notifications_automations.sql, roles/staff/weekly-plan.html

ALTER TABLE psy_coach_tasks
  ADD COLUMN IF NOT EXISTS due_date DATE;
