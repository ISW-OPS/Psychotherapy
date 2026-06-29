-- ============================================================
-- 20260628_vitals_rbac.sql
-- Tambah modul 'vitals' sebagai modul RBAC bebas (bukan tumpang 'patient')
-- Nav: 💓 Bacaan Vitals → vitals.html
-- ============================================================

-- ── 1. Tambah modul vitals ───────────────────────────────────
INSERT INTO psy_modules (code, label, icon, scope, sort_order)
VALUES ('vitals', 'Bacaan Vitals', '💓', 'staff', 75)
ON CONFLICT (code) DO UPDATE
  SET label=EXCLUDED.label, icon=EXCLUDED.icon, scope=EXCLUDED.scope, sort_order=EXCLUDED.sort_order;

-- ── 2. Tambah module actions ─────────────────────────────────
INSERT INTO psy_module_actions (module_code, action_code) VALUES
  ('vitals','view'),
  ('vitals','create'),
  ('vitals','edit'),
  ('vitals','delete')
ON CONFLICT DO NOTHING;

-- ── 3. Role permissions ──────────────────────────────────────

-- Super Admin & Manager: semua (diliputi oleh SELECT * FROM psy_module_actions)
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT role_code, module_code, action_code FROM (VALUES
  ('super_admin','vitals','view'),('super_admin','vitals','create'),('super_admin','vitals','edit'),('super_admin','vitals','delete'),
  ('manager',    'vitals','view'),('manager',    'vitals','create'),('manager',    'vitals','edit'),('manager',    'vitals','delete'),
  ('admin',      'vitals','view'),('admin',      'vitals','create'),('admin',      'vitals','edit'),('admin',      'vitals','delete'),
  ('doctor',     'vitals','view'),('doctor',     'vitals','create'),('doctor',     'vitals','edit'),('doctor',     'vitals','delete'),
  ('coach',      'vitals','view'),('coach',      'vitals','create'),('coach',      'vitals','edit'),('coach',      'vitals','delete')
) AS t(role_code, module_code, action_code)
ON CONFLICT DO NOTHING;

SELECT 'OK — vitals RBAC module ready' AS status;
