-- FIX: psy_orders.patient_id sepatutnya simpan AUTH/profile id (user_id), BUKAN
-- psy_patients.id — sebab tu nama pesakit tak keluar (fallback "Pesakit"/"Patient")
-- di dashboard & orders.html (kedua-dua cari nama guna psy_profiles.id).
-- Punca: seed demo (seeds_demo_full.sql) insert guna psy_patients.id (dah dibetulkan
-- kat sumber), tapi data yg DAH ADA dalam DB masih guna nilai lama. Run sekali sahaja.
-- Selamat run berkali-kali (kalau dah betul, WHERE tak match apa-apa).

UPDATE psy_orders o
SET patient_id = p.user_id
FROM psy_patients p
WHERE o.patient_id = p.id AND p.user_id IS NOT NULL;

-- Semak hasil:
-- SELECT o.order_ref, pr.full_name FROM psy_orders o LEFT JOIN psy_profiles pr ON pr.id = o.patient_id;
