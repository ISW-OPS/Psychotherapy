-- =====================================================================
-- SEED: Pakej Rawatan Demo Lengkap (OBP-DEMO)
-- 12 minggu · Timeline penuh · Jadual harian · Kontrak · Bekalan
-- Demo data untuk uji semua section dalam pakej-detail.html
-- =====================================================================

-- Ensure all required columns exist (idempotent)
ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS madu_frequency_per_day INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS supplies JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS addons JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS automation_flags JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS access_flags JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS internal_notes TEXT;

INSERT INTO psy_packages (
  package_id, name, description, price, duration, duration_weeks,
  icon, bg_color, tier, is_active, status, sort_order,
  madu_frequency_per_day, extension_price_per_week, meet_link,
  products, bimbingan, inclusions, supplies, addons,
  bio_goals, psycho_goals, social_goals, spiritual_goals,
  coaching_schedule, daily_schedule,
  agreement_title, agreement_version, agreement_clauses,
  automation_flags, access_flags, internal_notes
) VALUES (
  'pkg-demo-lengkap',
  'OBP DEMO',
  '12 minggu program holistik · contoh pakej lengkap untuk demo',
  2999,
  '12 Minggu',
  12,
  '💎',
  'bg-navy-light',
  'standard',
  true,
  'active',
  99,
  2,                                              -- 2 botol madu / hari
  50,                                             -- RM 50 / minggu extension
  'https://meet.google.com/abc-defg-hij',

  -- products (legacy)
  '["6 KG IB","6 KG YHPG","Starter Kit","12 Botol Air Afiyah","1 Set Herba Kolon","1 Set Enema Kit"]'::jsonb,

  -- bimbingan (legacy)
  '["20 Sesi Herba Thoharah","Bimbingan Terapi Peminuman IB","Bimbingan Terapi Zikir Bersanad","Konsultasi Hakeema","Perubatan Rohani Coach Fares"]'::jsonb,

  -- inclusions (legacy)
  '["6 KG IB","6 KG YHPG","Starter Kit","12 Botol Air Afiyah","20 Sesi Herba Thoharah","Bimbingan Terapi Peminuman","Bimbingan Terapi Zikir","Konsultasi Hakeema"]'::jsonb,

  -- supplies (new — aggregated bekalan)
  '[
    {"name":"IB","qty":6,"unit":"kg","auto_stock":true},
    {"name":"YHPG","qty":6,"unit":"kg","auto_stock":true},
    {"name":"Air Afiyah","qty":12,"unit":"botol","auto_stock":true},
    {"name":"Air Zaafaran","qty":7,"unit":"botol","auto_stock":true},
    {"name":"Herba Kolon","qty":1,"unit":"set","auto_stock":true},
    {"name":"Madu YHPG","qty":24,"unit":"botol","auto_stock":true}
  ]'::jsonb,

  -- addons (new)
  '[]'::jsonb,

  -- bio/psycho/social/spiritual goals (legacy)
  '["Peminuman IB ikut jadual","Air Afiyah 1 botol/hari","Madu YHPG 2x/hari","Pantau vitals mingguan"]'::jsonb,
  '["Mood tracker harian","Journaling syukur","Breathing exercise 4-7-8","Bimbingan Terapi Reaksi"]'::jsonb,
  '["Aktif Whatsapp Group","Konsultasi Hakeema bulanan","Sesi 1:1 Coach"]'::jsonb,
  '["Zikir pagi petang","Solat penuh 5 waktu","Tadarus Al-Quran","Perubatan Rohani Coach Fares"]'::jsonb,

  -- coaching_schedule (Timeline Rawatan — 12 minggu lengkap)
  '[
    {
      "week": 1,
      "mode": "f2f",
      "guidance": [{"item_name":"Onboarding & KOB"},{"item_name":"Bimbingan Terapi Peminuman IB"}],
      "aktiviti": [{"item_name":"Konsultasi awal Hakeema"},{"item_name":"DNA Test sampling"}],
      "supplies": [{"item_name":"IB","qty":1,"item_unit":"kg"},{"item_name":"Air Afiyah","qty":2,"item_unit":"botol"}]
    },
    {
      "week": 2,
      "mode": "both",
      "guidance": [{"item_name":"Bimbingan Terapi Zikir Bersanad"}],
      "aktiviti": [{"item_name":"Sesi Herba Thoharah #1"},{"item_name":"Pemantauan Coach"}],
      "supplies": [{"item_name":"IB","qty":1,"item_unit":"kg"},{"item_name":"Madu YHPG","qty":2,"item_unit":"botol"}]
    },
    {
      "week": 3,
      "mode": "online",
      "guidance": [{"item_name":"Bimbingan Diet & Nutrisi"}],
      "aktiviti": [{"item_name":"Sesi Herba Thoharah #2"},{"item_name":"Kelas Online New Life Challenge #1"}],
      "supplies": [{"item_name":"YHPG","qty":1,"item_unit":"kg"},{"item_name":"Madu YHPG","qty":2,"item_unit":"botol"}]
    },
    {
      "week": 4,
      "mode": "f2f",
      "guidance": [{"item_name":"Bimbingan Gaya Hidup Fitrah"}],
      "aktiviti": [{"item_name":"Sesi Herba Thoharah #3"},{"item_name":"IV Saline Drip #1"}],
      "supplies": [{"item_name":"IB","qty":1,"item_unit":"kg"},{"item_name":"Air Zaafaran","qty":1,"item_unit":"botol"}]
    },
    {
      "week": 5,
      "mode": "both",
      "guidance": [{"item_name":"Bimbingan Terapi Reaksi Pemulihan"}],
      "aktiviti": [{"item_name":"Sesi Herba Thoharah #4"},{"item_name":"Konsultasi Hakeema #1"}],
      "supplies": [{"item_name":"YHPG","qty":1,"item_unit":"kg"},{"item_name":"Madu YHPG","qty":2,"item_unit":"botol"}]
    },
    {
      "week": 6,
      "mode": "online",
      "guidance": [{"item_name":"Perubatan Rohani — Coach Fares"}],
      "aktiviti": [{"item_name":"Sesi Herba Thoharah #5"},{"item_name":"Kelas Online NLC #2"}],
      "supplies": [{"item_name":"IB","qty":1,"item_unit":"kg"},{"item_name":"Madu YHPG","qty":2,"item_unit":"botol"}]
    },
    {
      "week": 7,
      "mode": "f2f",
      "guidance": [{"item_name":"Bimbingan Detox Lanjutan"}],
      "aktiviti": [{"item_name":"Sesi Herba Thoharah #6"},{"item_name":"Enema Kit terapi"}],
      "supplies": [{"item_name":"YHPG","qty":1,"item_unit":"kg"},{"item_name":"Herba Kolon","qty":1,"item_unit":"set"}]
    },
    {
      "week": 8,
      "mode": "both",
      "guidance": [{"item_name":"Bimbingan Penyucian Aura"}],
      "aktiviti": [{"item_name":"Sesi Herba Thoharah #7"},{"item_name":"IV Saline Drip #2"}],
      "supplies": [{"item_name":"IB","qty":1,"item_unit":"kg"},{"item_name":"Madu YHPG","qty":2,"item_unit":"botol"}]
    },
    {
      "week": 9,
      "mode": "online",
      "guidance": [{"item_name":"Bimbingan Mental Resilience"}],
      "aktiviti": [{"item_name":"Sesi Herba Thoharah #8"},{"item_name":"Kelas Online NLC #3"}],
      "supplies": [{"item_name":"YHPG","qty":1,"item_unit":"kg"},{"item_name":"Air Afiyah","qty":2,"item_unit":"botol"}]
    },
    {
      "week": 10,
      "mode": "f2f",
      "guidance": [{"item_name":"Konsultasi Hakeema #2"}],
      "aktiviti": [{"item_name":"Sesi Herba Thoharah #9"},{"item_name":"DNA Test review"}],
      "supplies": [{"item_name":"IB","qty":1,"item_unit":"kg"},{"item_name":"Madu YHPG","qty":2,"item_unit":"botol"}]
    },
    {
      "week": 11,
      "mode": "both",
      "guidance": [{"item_name":"Bimbingan Maintenance Plan"}],
      "aktiviti": [{"item_name":"Sesi Herba Thoharah #10"},{"item_name":"IV Saline Drip #3"}],
      "supplies": [{"item_name":"Air Zaafaran","qty":2,"item_unit":"botol"},{"item_name":"Madu YHPG","qty":2,"item_unit":"botol"}]
    },
    {
      "week": 12,
      "mode": "f2f",
      "guidance": [{"item_name":"Penilaian Akhir & Sijil"}],
      "aktiviti": [{"item_name":"Konsultasi Hakeema #3"},{"item_name":"IV Saline Drip #4"},{"item_name":"Graduation"}],
      "supplies": [{"item_name":"Air Afiyah","qty":2,"item_unit":"botol"},{"item_name":"Air Zaafaran","qty":4,"item_unit":"botol"}]
    }
  ]'::jsonb,

  -- daily_schedule (Jadual Harian default)
  '[
    {"time":"05:30","activity":"Bangun · Solat Subuh · Zikir pagi","duration":30},
    {"time":"06:00","activity":"Senaman ringan 15 minit","duration":15},
    {"time":"06:30","activity":"Madu YHPG 1 sudu besar","duration":5},
    {"time":"07:00","activity":"Sarapan + IB drink","duration":30},
    {"time":"10:00","activity":"Air Afiyah 1 botol","duration":5},
    {"time":"12:30","activity":"Solat Zohor · Bacaan Al-Quran","duration":30},
    {"time":"13:00","activity":"Makan tengah hari","duration":45},
    {"time":"15:30","activity":"Madu YHPG 1 sudu besar","duration":5},
    {"time":"16:00","activity":"Solat Asar · Zikir petang","duration":30},
    {"time":"18:30","activity":"Solat Maghrib","duration":15},
    {"time":"19:00","activity":"Makan malam (ringan)","duration":30},
    {"time":"20:30","activity":"Solat Isyak · Mood tracker · Journaling","duration":30},
    {"time":"22:00","activity":"Tidur (sebelum tengah malam)","duration":0}
  ]'::jsonb,

  -- agreement
  'Kontrak Pelaburan Kesihatan — OBP DEMO',
  'ISW.SOP OB KOB FORM 03 CONTRACT 250711',
  '[
    {"title":"1. Pengenalan","text":"Saya {{patient_name}} (IC: {{patient_ic}}) dengan ini bersetuju untuk mendaftar dalam program {{package_name}} dengan kos pelaburan RM{{price}} bermula {{today}}."},
    {"title":"2. Komitmen Patient","text":"Saya komited untuk menghadiri semua sesi yang dijadualkan, mengikut bimbingan dengan teliti, dan melaporkan apa-apa reaksi pemulihan kepada coach saya."},
    {"title":"3. Konfidensial","text":"Semua maklumat peribadi dan kesihatan saya akan dijaga rahsia oleh pihak klinik dan tidak akan dikongsi kepada pihak ketiga tanpa kebenaran bertulis."},
    {"title":"4. Reaksi Pemulihan","text":"Saya faham bahawa program ini boleh menghasilkan reaksi pemulihan seperti penat, sakit kepala ringan, atau perubahan emosi. Saya akan rujuk coach jika reaksi ini berterusan lebih 48 jam."},
    {"title":"5. Bayaran","text":"Bayaran RM{{price}} adalah satu kali untuk tempoh 12 minggu. Sebarang sesi tambahan akan dikenakan caj RM50 per minggu. Tiada refund selepas sesi minggu pertama bermula."},
    {"title":"6. Ketidakhadiran","text":"Jika saya gagal hadir sesi tanpa pemberitahuan 24 jam awal, sesi akan ditandai sebagai miss dan minggu tambahan akan dijadualkan untuk gantikan, dengan caj RM50."},
    {"title":"7. Pengakhiran","text":"Saya boleh menamatkan program pada bila-bila masa, tetapi tiada refund akan dikeluarkan untuk minggu yang telah berlalu. Akses ke kandungan digital akan ditarik selepas penamatan."},
    {"title":"8. Pengesahan","text":"Saya, {{patient_name}}, mengaku telah membaca, memahami, dan bersetuju dengan semua terma dan syarat di atas pada {{today}}."}
  ]'::jsonb,

  -- automation_flags
  '{"whatsapp_weekly":true,"reminder_checkin":true,"attendance_reminder":true,"auto_lock_content":false}'::jsonb,

  -- access_flags
  '{"self_help_library":true,"video_panduan":true,"checklist_harian":true,"geng_alive":false}'::jsonb,

  -- internal_notes
  'PAKEJ DEMO untuk testing UI. Boleh padam selepas siap demo.

Pesakit yang ambil pakej ni akan dimasukkan dalam batch coaching B-2026.
Sila pastikan slot Hakeema setiap minggu 5, 10 telah ditempah awal.
Untuk patient dengan keperluan khas (vegetarian/halal-only), tambah note dalam profile mereka.'
)
ON CONFLICT (package_id) DO UPDATE SET
  name                     = EXCLUDED.name,
  description              = EXCLUDED.description,
  price                    = EXCLUDED.price,
  duration                 = EXCLUDED.duration,
  duration_weeks           = EXCLUDED.duration_weeks,
  icon                     = EXCLUDED.icon,
  bg_color                 = EXCLUDED.bg_color,
  tier                     = EXCLUDED.tier,
  is_active                = EXCLUDED.is_active,
  status                   = EXCLUDED.status,
  sort_order               = EXCLUDED.sort_order,
  madu_frequency_per_day   = EXCLUDED.madu_frequency_per_day,
  extension_price_per_week = EXCLUDED.extension_price_per_week,
  meet_link                = EXCLUDED.meet_link,
  products                 = EXCLUDED.products,
  bimbingan                = EXCLUDED.bimbingan,
  inclusions               = EXCLUDED.inclusions,
  supplies                 = EXCLUDED.supplies,
  addons                   = EXCLUDED.addons,
  bio_goals                = EXCLUDED.bio_goals,
  psycho_goals             = EXCLUDED.psycho_goals,
  social_goals             = EXCLUDED.social_goals,
  spiritual_goals          = EXCLUDED.spiritual_goals,
  coaching_schedule        = EXCLUDED.coaching_schedule,
  daily_schedule           = EXCLUDED.daily_schedule,
  agreement_title          = EXCLUDED.agreement_title,
  agreement_version        = EXCLUDED.agreement_version,
  agreement_clauses        = EXCLUDED.agreement_clauses,
  automation_flags         = EXCLUDED.automation_flags,
  access_flags             = EXCLUDED.access_flags,
  internal_notes           = EXCLUDED.internal_notes,
  updated_at               = now();

SELECT 'Seed Pakej Lengkap OK — pkg-demo-lengkap dicipta/dikemaskini' AS status;
