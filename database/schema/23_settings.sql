-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: TETAPAN SISTEM (System Settings — konfigurasi global)
-- Jadual: psy_settings
-- Simpanan key/value (JSONB) untuk tetapan peringkat sistem: nama app,
-- zon masa, deadline pengesahan sesi, mod gateway pembayaran, slot masa
-- jadual, dsb. Kunci API rahsia TIDAK disimpan di sini — ia kekal di
-- env Edge Function.
-- Akses: BACA → semua staff; TULIS → super_admin sahaja.
-- ═══════════════════════════════════════════════════════════════════

-- ──── psy_settings ────
CREATE TABLE IF NOT EXISTS psy_settings (
  key        TEXT PRIMARY KEY,
  value      JSONB,
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL
);

ALTER TABLE psy_settings ENABLE ROW LEVEL SECURITY;

-- Semua staff boleh baca tetapan (untuk pakai nilai global di halaman lain).
DROP POLICY IF EXISTS "settings_read_staff" ON psy_settings;
CREATE POLICY "settings_read_staff" ON psy_settings
  FOR SELECT USING (settings_is_staff());

-- Pesakit turut perlu BACA sebahagian tetapan (cth clinic_phone — fallback no.
-- panggilan di seksyen Protokol Kecemasan bila coach tiada/tiada no. telefon).
-- Selamat dibuka: jadual ni TIDAK simpan kunci API rahsia (lihat nota atas).
DROP POLICY IF EXISTS "settings_read_authenticated" ON psy_settings;
CREATE POLICY "settings_read_authenticated" ON psy_settings
  FOR SELECT USING (auth.role() = 'authenticated');

-- Hanya super_admin boleh cipta / kemaskini / padam.
DROP POLICY IF EXISTS "settings_write_sa" ON psy_settings;
CREATE POLICY "settings_write_sa" ON psy_settings
  FOR ALL USING (settings_is_super_admin()) WITH CHECK (settings_is_super_admin());

-- ──── fungsi + trigger: sentuh updated_at ────
CREATE OR REPLACE FUNCTION settings_touch() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_settings_touch ON psy_settings;
CREATE TRIGGER trg_settings_touch BEFORE UPDATE ON psy_settings
  FOR EACH ROW EXECUTE FUNCTION settings_touch();

-- ──── seed: nilai default ────
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

-- Slot masa global default untuk jadual rawatan (jika belum wujud)
INSERT INTO psy_settings (key, value) VALUES
  ('schedule_time_slots',
   '[{"value":"09:00","label":"9:00 AM"},{"value":"10:00","label":"10:00 AM"},{"value":"14:00","label":"2:00 PM"},{"value":"15:00","label":"3:00 PM"},{"value":"16:00","label":"4:00 PM"}]'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- Ambang Normal/Tidak Normal/Kritikal per-vital — audit management batch 3
-- (29-30 Sept 2026). normal_min/normal_max = nilai sedia ada (dah dipakai client-side
-- di vitals-detail.html/vitals.html/patient/vitals.html sebelum ni, kekal sama supaya
-- tiada perubahan tingkah laku is_abnormal semasa cutover). critical_min/critical_max
-- SENGAJA null (belum disahkan doktor ISW) — automasi kes kecemasan (is_critical,
-- rujuk fn_vitals_compute_critical() di 10_vitals.sql) TAK aktif sehingga super_admin/
-- doktor isi nilai melalui tetapan.html. JANGAN pra-isi nombor di sini.
INSERT INTO psy_settings (key, value) VALUES
  ('vitals_thresholds', '{
    "bp_systolic":      {"normal_min": 90,   "normal_max": 129,  "critical_min": null, "critical_max": null},
    "bp_diastolic":      {"normal_min": 60,   "normal_max": 84,   "critical_min": null, "critical_max": null},
    "heart_rate":        {"normal_min": 60,   "normal_max": 100,  "critical_min": null, "critical_max": null},
    "temperature":       {"normal_min": 36.1, "normal_max": 37.2, "critical_min": null, "critical_max": null},
    "spo2":              {"normal_min": 95,   "normal_max": null, "critical_min": null, "critical_max": null},
    "respiratory_rate":  {"normal_min": 12,   "normal_max": 20,   "critical_min": null, "critical_max": null}
  }'::jsonb)
ON CONFLICT (key) DO NOTHING;
