-- ════════════════════════════════════════════════════════════════
-- step88: Bersih data warisan — sesi 'hadir' tanpa session_date (Jul 2026)
-- ────────────────────────────────────────────────────────────────
-- Konteks: 4 plan prod ada baris psy_plan_weekly_progress bertanda
-- 'hadir' TAPI session_date null/salah. Punca = data lama dimasukkan
-- SEBELUM logik 1→2 sesi dibetulkan; fix kemudian cuma DEDAH rekod
-- tak lengkap ni (bukan bug berterusan — kod semasa tak hasilkan lagi).
--
-- P-009 (2823aa2f…) sudah dibetulkan manual dulu.
-- Tinggal 3 plan: 22020a0d… (P-006?), 0b5889f0…, 4f05963b… → step ni.
--
-- Skop: HANYA isi tarikh untuk baris status='hadir' yg session_date NULL.
--       TAK sentuh: booked / pending / reschedule, atau baris yg dah ada
--       tarikh (termasuk sesi yg sengaja dijadual semula ke tarikh lain).
-- Formula: sama macam unjuran app —
--   session_date = start_date + ((week-1)*7 + (session_day-1)) hari
--   (Sesi 1 = hari anchor minggu itu; Sesi 2 = sehari selepas.)
-- Jalankan di Supabase SQL Editor (PROD xmvqvq — tiada MCP).
-- ════════════════════════════════════════════════════════════════


-- ─── LANGKAH 1 — DIAGNOSTIK (SELECT sahaja, SIFAR risiko) ─────────
-- 1a) Ringkasan: plan mana terjejas + berapa baris rosak.
--     Sepatutnya nampak 3 plan (P-009 dah tiada sebab dah dibetulkan).
select p.plan_id,
       tp.name              as pakej,
       pt.mrn,
       pr.full_name         as pesakit,
       tp.start_date,
       tp.current_week,
       count(*)             as sesi_hadir_tanpa_tarikh
from   psy_plan_weekly_progress p
join   psy_treatment_plans tp on tp.id = p.plan_id
join   psy_patients        pt on pt.id = p.patient_id
left   join psy_profiles   pr on pr.id = pt.user_id
where  p.status = 'hadir' and p.session_date is null
group  by p.plan_id, tp.name, pt.mrn, pr.full_name, tp.start_date, tp.current_week
order  by sesi_hadir_tanpa_tarikh desc;


-- 1b) PRATONTON PENUH: setiap baris rosak + tarikh BARU yg akan ditulis.
--     Semak tarikh_baru menaik & munasabah SEBELUM run Langkah 2.
select pt.mrn,
       tp.name                as pakej,
       p.week_number          as minggu,
       coalesce(p.session_day,1) as sesi,
       p.session_date         as sekarang,
       tp.start_date
         + ((p.week_number - 1) * 7 + (coalesce(p.session_day,1) - 1)) * interval '1 day'
                              as tarikh_baru
from   psy_plan_weekly_progress p
join   psy_treatment_plans tp on tp.id = p.plan_id
join   psy_patients        pt on pt.id = p.patient_id
where  p.status = 'hadir' and p.session_date is null
order  by pt.mrn, p.week_number, coalesce(p.session_day,1);


-- ─── LANGKAH 2 — FIX (UPDATE — auto-commit statement tunggal) ─────
-- Run HANYA selepas Langkah 1b nampak betul. RETURNING = bukti apa yg berubah.
update psy_plan_weekly_progress p
set    session_date = tp.start_date
         + ((p.week_number - 1) * 7 + (coalesce(p.session_day,1) - 1)) * interval '1 day',
       updated_at   = now()
from   psy_treatment_plans tp
where  tp.id = p.plan_id
  and  p.status = 'hadir'
  and  p.session_date is null
returning p.plan_id, p.week_number, p.session_day, p.session_date;


-- ─── LANGKAH 3 — SEMAK SELEPAS FIX (SELECT, patut 0 baris) ───────
select count(*) as baki_hadir_tanpa_tarikh
from   psy_plan_weekly_progress
where  status = 'hadir' and session_date is null;
-- Jangka: 0. Lepas ni hard-refresh patient-hub → semua minggu ada tarikh.
