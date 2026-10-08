-- Audit management #146 (7 Okt 2026) — Pelan Mingguan: Task Peribadi, 3 gap kecil.
-- 1) priority column SUDAH wujud di psy_coach_tasks (tiada ALTER diperlukan utk itu).
-- 2) linked_appointment_id BAHARU — pautan SEHALA (task → appointment) dari
--    psy_coach_tasks ke psy_appointments supaya task peribadi (sekali sahaja,
--    recur_type='none') muncul dalam Jadual Temujanji (roles/staff/appointments.html)
--    bersama sesi/temujanji lain. Bila task diubah/padam/ditanda selesai di
--    weekly-plan.html, appointment berkaitan turut dikemaskini (UPDATE, bukan INSERT
--    baris baharu). SEHALA sahaja — perubahan di appointments.html TIDAK sync balik
--    ke task.
-- Idempoten — selamat dijalankan berulang kali.

ALTER TABLE psy_coach_tasks
  ADD COLUMN IF NOT EXISTS linked_appointment_id UUID REFERENCES psy_appointments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_coach_tasks_linked_appointment ON psy_coach_tasks (linked_appointment_id);
