-- ════════════════════════════════════════════════════════════════
-- step98: RBAC penuh — SEMUA halaman berdaftar + SEMUA butang boleh on/off
-- 1) Modul baru utk halaman yang tercicir: reaksi, rujukan, kehadiran (staff)
--    + pat_sejarah (patient: sejarah-pembayaran.html & resit.html)
-- 2) Daftar SEMUA action (view/create/edit/delete/export) utk setiap modul
--    staff dalam psy_module_actions → setiap cell dalam matrix peranan.html
--    boleh di-toggle.
-- 3) Grant behaviour-preserving: role yang sudah ada 'view' pada satu modul
--    diberi create/edit/delete/export sekali (sebelum ini butang TIDAK digate,
--    jadi ini mengekalkan tingkah laku semasa — admin boleh untick kemudian).
-- ════════════════════════════════════════════════════════════════

-- ── 1) Modul baru ────────────────────────────────────────────────
INSERT INTO psy_modules (code, label, icon, scope, sort_order) VALUES
  ('reaksi',      'Reaksi & Tindakan',   '🩹', 'staff',    72),
  ('rujukan',     'Rujukan',             '🔀', 'staff',    76),
  ('kehadiran',   'Laporan Kehadiran',   '📋', 'staff',   205),
  ('pat_sejarah', 'Sejarah Pembayaran',  '🧾', 'patient',  95)
ON CONFLICT (code) DO UPDATE SET
  label = EXCLUDED.label,
  icon  = EXCLUDED.icon,
  scope = EXCLUDED.scope,
  sort_order = EXCLUDED.sort_order;

-- ── 2) Daftar SEMUA action untuk SETIAP modul (staff + patient) ──
--      Tiada lagi cell "—" (Tidak Berkenaan) dalam peranan.html —
--      SEMUA kotak boleh di-toggle, dan boleh di-ON bila perlu kelak.
INSERT INTO psy_module_actions (module_code, action_code)
SELECT m.code, a.code
FROM psy_modules m
CROSS JOIN psy_actions a
ON CONFLICT DO NOTHING;

-- ── 3) Default grants modul baru ─────────────────────────────────
-- Halaman ini sebelum step98 TERBUKA kepada semua staff (tiada guard),
-- jadi grant view kepada semua role staff — kekalkan akses semasa.
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT r.code, m.code, 'view'
FROM psy_roles r
CROSS JOIN (VALUES ('reaksi'), ('rujukan'), ('kehadiran')) AS m(code)
WHERE r.code IN ('super_admin','manager','admin','doctor','coach')
ON CONFLICT DO NOTHING;

-- Sejarah pembayaran pesakit: ON secara default
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
VALUES ('patient', 'pat_sejarah', 'view')
ON CONFLICT DO NOTHING;

-- ── 4) Behaviour-preserving: view ⇒ create/edit/delete/export ────
-- Untuk setiap (role, modul staff) yang sudah ada 'view', beri juga
-- action lain supaya butang yang baru digate tidak hilang serta-merta.
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT rma.role_code, rma.module_code, a.code
FROM psy_role_module_actions rma
JOIN psy_modules m ON m.code = rma.module_code AND m.scope = 'staff'
CROSS JOIN psy_actions a
WHERE rma.action_code = 'view'
  AND a.code IN ('create','edit','delete','export')
  AND rma.role_code <> 'patient'
ON CONFLICT DO NOTHING;

-- ── Verifikasi ──
SELECT 'Step 98 OK — semua halaman dalam RBAC + semua butang boleh on/off' AS status;
SELECT m.code, m.label, m.scope,
       COUNT(ma.action_code) AS actions_berdaftar
FROM psy_modules m
LEFT JOIN psy_module_actions ma ON ma.module_code = m.code
WHERE m.is_active
GROUP BY m.code, m.label, m.scope, m.sort_order
ORDER BY m.scope DESC, m.sort_order;
