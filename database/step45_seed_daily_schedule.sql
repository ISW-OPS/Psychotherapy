-- ============================================================
-- step45_seed_daily_schedule.sql
-- Seed sample daily_schedule for demo. Single UPDATE with CASE
-- to avoid deadlock between multiple UPDATE statements.
-- ============================================================

UPDATE psy_packages
SET daily_schedule = CASE
  WHEN LOWER(package_id) IN (
    'obd1','obdx1','obdy1','obp1','obpx1','obpy1',
    'pkg-obd1','pkg-obdx1','pkg-obdy1','pkg-obp1','pkg-obpx1','pkg-obpy1'
  ) THEN '[
    {"time":"06:15","activity":"Zikir bersanad"},
    {"time":"06:30","activity":"Minum madu LTHPG"},
    {"time":"07:30","activity":"Minum madu LTH"},
    {"time":"07:45","activity":"Berjemur cahaya matahari pagi & terapi bumi & pernafasan fitrah (10 minit)"},
    {"time":"08:15","activity":"Makan breakfast (Yogurt dan buah)"},
    {"time":"09:15","activity":"Minum madu LTHPG"},
    {"time":"10:15","activity":"Minum madu LTH"},
    {"time":"11:15","activity":"Minum madu LTHPG"},
    {"time":"12:15","activity":"Minum madu LTH"},
    {"time":"12:30","activity":"Lunch & minum air kelapa"},
    {"time":"13:15","activity":"Solat Zohor & pernafasan fitrah (5 minit)"},
    {"time":"14:15","activity":"Minum madu LTHPG"},
    {"time":"15:15","activity":"Minum madu LTH"},
    {"time":"16:15","activity":"Minum madu LTHPG"},
    {"time":"16:40","activity":"Solat Asar & pernafasan fitrah (5 minit)"},
    {"time":"17:00","activity":"Berkebun @ Terapi bumi"},
    {"time":"18:30","activity":"Makan malam"},
    {"time":"19:30","activity":"Solat Maghrib & Zikir bersanad"},
    {"time":"20:30","activity":"Solat Isyak & Pernafasan Fitrah (5 minit)"},
    {"time":"21:00","activity":"Minum madu LTH"},
    {"time":"21:30","activity":"Pernafasan fitrah (5 minit) & Tidur"}
  ]'::jsonb
  WHEN LOWER(package_id) IN (
    'eol','pkg-eol','eol-plus','eol+','pkg-eol-plus','pkg-eolplus',
    'js','jumpstart','js+','jumpstart+','pkg-js','pkg-jumpstart','pkg-jumpstart-plus','pkg-jsplus'
  ) THEN '[
    {"time":"06:30","activity":"Zikir pagi & pernafasan fitrah"},
    {"time":"07:00","activity":"Minum air Afiyah"},
    {"time":"08:00","activity":"Sarapan ringan"},
    {"time":"10:00","activity":"Sesi bimbingan terapi (online/F2F)"},
    {"time":"13:00","activity":"Solat Zohor & rehat"},
    {"time":"14:00","activity":"Makan tengahari"},
    {"time":"17:00","activity":"Berkebun atau aktiviti luar"},
    {"time":"19:30","activity":"Solat Maghrib & Zikir bersanad"},
    {"time":"21:30","activity":"Tidur awal"}
  ]'::jsonb
  ELSE daily_schedule
END
WHERE LOWER(package_id) IN (
  'obd1','obdx1','obdy1','obp1','obpx1','obpy1',
  'pkg-obd1','pkg-obdx1','pkg-obdy1','pkg-obp1','pkg-obpx1','pkg-obpy1',
  'eol','pkg-eol','eol-plus','eol+','pkg-eol-plus','pkg-eolplus',
  'js','jumpstart','js+','jumpstart+','pkg-js','pkg-jumpstart','pkg-jumpstart-plus','pkg-jsplus'
)
AND (daily_schedule IS NULL OR daily_schedule = '[]'::jsonb);

SELECT
  package_id,
  name,
  jsonb_array_length(COALESCE(daily_schedule,'[]'::jsonb)) AS items
FROM psy_packages
WHERE jsonb_array_length(COALESCE(daily_schedule,'[]'::jsonb)) > 0
ORDER BY package_id;
