-- RBAC granular Sesi 1:1 (audit management #101, 8 Okt 2026) — modul 'rujukan' (dikhaskan
-- utk Sesi 1:1 Hakeema/Hakeem/Dr Session sahaja, disahkan tiada ciri lain kongsi modul ni)
-- kini ada 2 action baharu selain view/create/edit/delete/export/settings sedia ada:
--   • reschedule — tukar/batal tempahan sesi (butang "🚫 Batal" / checkbox "wajib pakej")
--   • complete   — tandakan sesi selesai (butang "✓ Tandakan Selesai")
-- "Edit nota" (soal-jawab/saranan/dokumen) KEKAL guna action 'edit' sedia ada.
-- Rujuk database/schema/03_rbac_security.sql (sumber) — fail ni mengulang perubahan yg
-- sama utk DB yg dah wujud. Idempoten — selamat dijalankan berulang kali.

INSERT INTO psy_actions (code, label, icon, sort_order) VALUES
  ('reschedule', 'Jadual Semula',    '📅', 32),
  ('complete',   'Tandakan Selesai', '✅', 34)
ON CONFLICT (code) DO UPDATE SET label=EXCLUDED.label, icon=EXCLUDED.icon, sort_order=EXCLUDED.sort_order;

-- Daftar cell boleh-toggle utk SEMUA modul (ikut dasar sedia ada "tiada cell — / Tidak
-- Berkenaan" di peranan.html — rujuk 03_rbac_security.sql baris ~399-406).
INSERT INTO psy_module_actions (module_code, action_code)
SELECT m.code, a.code
FROM psy_modules m
CROSS JOIN psy_actions a
WHERE a.code IN ('reschedule', 'complete')
ON CONFLICT DO NOTHING;

-- Grant default: role yg sebelum ni dah ada rujukan.edit/delete penuh (via "Kembangan
-- view" sedia ada) diberi reschedule+complete jugak, supaya kebenaran sedia ada tak jadi
-- lebih ketat drpd sebelum pemisahan granular ni — admin boleh tarik balik ikut keperluan
-- di peranan.html.
INSERT INTO psy_role_module_actions (role_code, module_code, action_code)
SELECT r.role_code, 'rujukan', a.action_code
FROM (VALUES ('super_admin'), ('manager'), ('admin'), ('doctor'), ('coach')) AS r(role_code)
CROSS JOIN (VALUES ('reschedule'), ('complete')) AS a(action_code)
ON CONFLICT DO NOTHING;
