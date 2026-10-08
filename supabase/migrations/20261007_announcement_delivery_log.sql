-- ═══════════════════════════════════════════════════════════════════
-- Audit #133 — Delivery log penghantaran Pengumuman
-- psy_notification_logs (18_notifications_automations.sql) dah wujud &
-- generik cukup (channel/status/event/error ialah TEXT bebas, tiada CHECK
-- constraint) — guna semula jadual ni, TIDAK cipta jadual baharu.
--
-- Satu-satunya perubahan DB yang diperlukan: staff kini boleh INSERT terus
-- dari client (roles/staff/pengumuman-baru.html, bila publish pengumuman
-- in-app) — dulu cuma Edge Function (service_role, bypass RLS) yang tulis.
--
-- Konvensyen rujukan (tiada lajur FK khusus; guna lajur `event` sedia ada):
--   event   = 'announcement:<psy_announcements.id>'
--   channel = 'in_app' (penerbitan manual / broadcast automatik — pengumuman
--             kini IN-APP SAHAJA, tiada laluan WA/email terus dari borang)
--   status  = 'sent' | 'failed'
-- ═══════════════════════════════════════════════════════════════════

drop policy if exists "notif_logs staff insert" on psy_notification_logs;
create policy "notif_logs staff insert" on psy_notification_logs for insert
  with check (auth.uid() in (select id from psy_profiles where role = 'staff'));
