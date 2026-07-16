-- ============================================================
-- step96: Tetapan Sistem (System Settings) — konfigurasi global
-- ------------------------------------------------------------
-- Simpanan key/value untuk tetapan peringkat sistem: nama app, zon masa,
-- deadline pengesahan sesi, mod gateway pembayaran, dsb.
--
-- Akses:  BACA  → semua staff (nilai bukan rahsia; kunci API rahsia TIDAK
--                 disimpan di sini — ia kekal di env Edge Function).
--         TULIS → super_admin SAHAJA.
--
-- Idempotent: selamat run berulang (IF NOT EXISTS / ON CONFLICT DO NOTHING).
-- Jalankan di Supabase (TESTING dulu → PROD) SQL Editor.
-- ============================================================

CREATE TABLE IF NOT EXISTS psy_settings (
  key        TEXT PRIMARY KEY,
  value      JSONB,
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL
);

-- ── Helpers RLS ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION settings_is_staff() RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff');
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION settings_is_super_admin() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM psy_profiles
    WHERE id = auth.uid() AND role = 'staff' AND staff_role = 'super_admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

ALTER TABLE psy_settings ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  -- Semua staff boleh baca tetapan (untuk pakai nilai global di halaman lain).
  CREATE POLICY "settings_read_staff" ON psy_settings
    FOR SELECT USING (settings_is_staff());
  -- Hanya super_admin boleh cipta / kemaskini / padam.
  CREATE POLICY "settings_write_sa" ON psy_settings
    FOR ALL USING (settings_is_super_admin()) WITH CHECK (settings_is_super_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── Seed nilai default ───────────────────────────────────────
-- Setiap baris = satu tetapan. value disimpan sebagai JSONB (skalar pun boleh).
INSERT INTO psy_settings (key, value) VALUES
  -- Umum
  ('app_name',        to_jsonb('Ibnu Sina Wellness CMS'::text)),
  ('app_version',     to_jsonb('1.0.0'::text)),
  ('language',        to_jsonb('ms'::text)),
  ('date_format',     to_jsonb('DD/MM/YYYY'::text)),
  ('timezone',        to_jsonb('Asia/Kuala_Lumpur'::text)),
  ('currency',        to_jsonb('MYR'::text)),
  -- Klinik
  ('clinic_name',     to_jsonb('Ibnu Sina Wellness'::text)),
  ('clinic_phone',    to_jsonb(''::text)),
  ('clinic_email',    to_jsonb(''::text)),
  ('clinic_address',  to_jsonb(''::text)),
  ('operating_hours', to_jsonb('9:00 pagi - 6:00 petang'::text)),
  ('session_confirm_deadline_hours', to_jsonb(24)),
  ('session_escalation_hours',       to_jsonb(12)),
  ('absence_reschedule_enabled',     to_jsonb(true)),
  -- Notifikasi (togol peringkat sistem)
  ('notif_event_reminder', to_jsonb(true)),
  ('notif_daily_checkin',  to_jsonb(false)),
  ('notif_birthday',       to_jsonb(false)),
  -- Integrasi (config BUKAN rahsia; kunci API kekal di env Edge Function)
  ('payment_provider',  to_jsonb('hitpay'::text)),
  ('payment_mode',      to_jsonb('sandbox'::text)),
  ('whatsapp_provider', to_jsonb('ghl'::text))
ON CONFLICT (key) DO NOTHING;

-- ── touch updated_at ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION settings_touch() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_settings_touch ON psy_settings;
CREATE TRIGGER trg_settings_touch BEFORE UPDATE ON psy_settings
  FOR EACH ROW EXECUTE FUNCTION settings_touch();

SELECT 'OK — step96 settings ready (' ||
  (SELECT COUNT(*) FROM psy_settings) || ' tetapan)' AS status;
