-- ═══════════════════════════════════════════════════════════════════
-- SKEMA: PAKEJ & TAWARAN PAKEJ
-- Jadual: psy_packages, psy_package_purchases, psy_package_categories,
--         psy_continuity_offers
-- ═══════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- psy_packages — definisi pakej rawatan
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(10,2) DEFAULT 0,
  duration TEXT,
  duration_unit TEXT DEFAULT 'week',
  duration_weeks INT DEFAULT 12,
  icon TEXT DEFAULT '📦',
  bg_color TEXT DEFAULT 'bg-cream',
  tier TEXT,
  is_active BOOLEAN DEFAULT true,
  products JSONB DEFAULT '[]',
  bimbingan JSONB DEFAULT '[]',
  inclusions JSONB DEFAULT '[]',
  coaching_schedule JSONB DEFAULT '[]',
  phases JSONB,
  sort_order INT DEFAULT 0,
  -- jadual madu & kunci sesi online
  madu_frequency_per_day INT,
  madu_schedule_label TEXT,
  allow_online_full_duration BOOLEAN NOT NULL DEFAULT false,
  online_lock_from_week INT NOT NULL DEFAULT 3,
  -- konfigurasi mingguan
  weekly_supplies JSONB DEFAULT '[]',
  weekly_content JSONB DEFAULT '[]',
  weekly_message JSONB DEFAULT '[]',
  -- perjanjian (kontrak) pakej
  agreement_pdf TEXT,
  agreement_clauses JSONB DEFAULT '[]',
  agreement_version TEXT,
  agreement_title TEXT DEFAULT 'Kontrak Pelaburan Kesihatan',
  -- rutin harian & jadual sesi fleksibel
  daily_schedule JSONB DEFAULT '[]'::jsonb,
  sessions_per_week INT DEFAULT 1
    CHECK (sessions_per_week BETWEEN 1 AND 7),
  session_days_options JSONB DEFAULT '[]',
  -- lain-lain
  extension_price_per_week NUMERIC(10,2) DEFAULT 50,
  meet_link TEXT,
  -- bayaran ansuran (Pelan Pelaburan Ansuran)
  installment_allowed BOOLEAN NOT NULL DEFAULT false,
  installment_count INT CHECK (installment_count IS NULL OR installment_count BETWEEN 2 AND 12),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_packages_active ON psy_packages(is_active);
CREATE INDEX IF NOT EXISTS idx_psy_packages_sort ON psy_packages(sort_order);

ALTER TABLE psy_packages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read active packages" ON psy_packages;
CREATE POLICY "Anyone read active packages" ON psy_packages
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage packages" ON psy_packages;
CREATE POLICY "Staff manage packages" ON psy_packages FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

COMMENT ON COLUMN psy_packages.madu_frequency_per_day IS
  'Frekuensi peminuman madu sehari. Examples: 10 (12-minggu), 8 (3-bulan), 4 (3-bulan-sekali). NULL = no madu schedule.';

COMMENT ON COLUMN psy_packages.madu_schedule_label IS
  'Human-readable label for madu schedule, e.g. "10x sehari (12 minggu)"';

COMMENT ON COLUMN psy_packages.allow_online_full_duration IS
  'true = online sessions allowed throughout (OBD1/OBDX1/OBDY1/OBP1/OBPX1/OBPY1). false = lock to f2f after online_lock_from_week.';

COMMENT ON COLUMN psy_packages.online_lock_from_week IS
  'Week number from which online sessions are locked (must use f2f). Default 3.';

COMMENT ON COLUMN psy_packages.weekly_supplies IS
  'Array of {week, items: [{product_id, qty, name}]} — bekalan auto-deduct per week';

COMMENT ON COLUMN psy_packages.weekly_content IS
  'Array of {week, content_ids: []} — library content unlock per week';

COMMENT ON COLUMN psy_packages.weekly_message IS
  'Array of {week, message} — WhatsApp template per week';

COMMENT ON COLUMN psy_packages.agreement_pdf IS
  'Filename of agreement PDF in shared/documents/agreements/ (relative path). NULL = use default agreement.pdf';

COMMENT ON COLUMN psy_packages.agreement_clauses IS
  'Array of {title, body} clauses for the patient agreement. Supports variables like {{patient_name}}.';

COMMENT ON COLUMN psy_packages.agreement_version IS
  'Version label, e.g. ISW.SOP OB KOB FORM 03 CONTRACT 250711';

COMMENT ON COLUMN psy_packages.agreement_title IS
  'Title shown at top of agreement (default: Kontrak Pelaburan Kesihatan)';

COMMENT ON COLUMN psy_packages.daily_schedule IS
  'Array of {time:"HH:MM", activity:"text"} — default daily routine for patients on this package.';

COMMENT ON COLUMN psy_packages.sessions_per_week IS
  'Bilangan sesi seminggu untuk pakej ini. 1 = sekali (OBG), 2 = dua kali (OB/NLC). Pakej per-hari (777) guna duration_unit=day, biarkan field ini = 1.';

COMMENT ON COLUMN psy_packages.session_days_options IS
  'Pilihan variant hari sesi yang patient boleh pilih. Format: array of array of int (1=Mon, 7=Sun). Cth OB: [[5,6],[6,7]] = pilihan Jum+Sab ATAU Sab+Ahd. OBG: [[6]] = Sabtu sahaja.';

COMMENT ON COLUMN psy_packages.extension_price_per_week IS
  'Harga (RM) untuk tambah satu minggu rawatan bila patient miss sesi. Default RM 50.';

COMMENT ON COLUMN psy_packages.meet_link IS
  'Pautan Gmeet recurring untuk pakej. Dipaparkan kepada patient bila minggu semasa adalah online/both.';

-- ──────────────────────────────────────────────────────────────
-- psy_package_purchases — pembelian pakej oleh pesakit
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_package_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES psy_patients(id) ON DELETE CASCADE NOT NULL,
  package_id TEXT NOT NULL,
  package_name TEXT NOT NULL,
  price NUMERIC(10,2) NOT NULL,
  purchased_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  status TEXT DEFAULT 'pending_payment' CHECK (status IN ('pending_payment','paid','active','expired','cancelled')),
  payment_method TEXT,
  ghl_order_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_psy_purchases_patient ON psy_package_purchases(patient_id);

ALTER TABLE psy_package_purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients manage own purchases" ON psy_package_purchases;
CREATE POLICY "Patients manage own purchases" ON psy_package_purchases FOR ALL
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()))
  WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Staff read all purchases" ON psy_package_purchases;
CREATE POLICY "Staff read all purchases" ON psy_package_purchases FOR SELECT
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Staff update purchases" ON psy_package_purchases;
CREATE POLICY "Staff update purchases" ON psy_package_purchases FOR UPDATE
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

-- ──────────────────────────────────────────────────────────────
-- psy_package_categories — kategori pakej dinamik (CRUD dari UI)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_package_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        TEXT NOT NULL UNIQUE,
  label       TEXT NOT NULL,
  badge_color TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 100,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE psy_package_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read categories" ON psy_package_categories;
CREATE POLICY "Anyone read categories" ON psy_package_categories
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Staff manage categories" ON psy_package_categories;
CREATE POLICY "Staff manage categories" ON psy_package_categories
  FOR ALL USING (
    EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')
  );

COMMENT ON TABLE psy_package_categories IS 'Senarai kategori pakej (dahulu hardcoded: standard/free/vip). Slug disimpan dalam psy_packages.tier.';
COMMENT ON COLUMN psy_package_categories.slug IS 'Stored value in psy_packages.tier (e.g. standard, free, vip, detox)';
COMMENT ON COLUMN psy_package_categories.badge_color IS 'Tailwind color suffix for badge (e.g. gold, green, navy) — null = no badge';

-- ──────────────────────────────────────────────────────────────
-- psy_continuity_offers — cadangan pakej sambungan oleh coach
-- package_uuid = psy_packages.id (UUID yg app guna sbg active_package_id)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS psy_continuity_offers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id       UUID,  -- FK → psy_treatment_plans (dipasang di hujung 07_treatment_plans.sql)
  patient_id    UUID NOT NULL REFERENCES psy_patients(id) ON DELETE CASCADE,
  suggested_by  UUID REFERENCES psy_profiles(id) ON DELETE SET NULL,
  package_uuid  UUID,
  package_name  TEXT,
  price         NUMERIC(10,2),
  note          TEXT,
  status        TEXT DEFAULT 'sent' CHECK (status IN ('sent','viewed','accepted','declined','cancelled')),
  created_at    TIMESTAMPTZ DEFAULT now(),
  responded_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_psy_continuity_offers_patient
  ON psy_continuity_offers(patient_id, status, created_at DESC);

ALTER TABLE psy_continuity_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff manage continuity offers" ON psy_continuity_offers;
CREATE POLICY "Staff manage continuity offers" ON psy_continuity_offers FOR ALL
  USING (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff'));

DROP POLICY IF EXISTS "Patients read own continuity offers" ON psy_continuity_offers;
CREATE POLICY "Patients read own continuity offers" ON psy_continuity_offers FOR SELECT
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Patients respond own continuity offers" ON psy_continuity_offers;
CREATE POLICY "Patients respond own continuity offers" ON psy_continuity_offers FOR UPDATE
  USING (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()));

COMMENT ON TABLE psy_continuity_offers IS
  'Cadangan pakej sambungan oleh coach utk pesakit baki ≤4 minggu. Terima → pembayaran.';

-- ══════════════════════════════════════════════════════════════
-- DATA RUJUKAN (SEED)
-- ══════════════════════════════════════════════════════════════

-- ──── kategori pakej ────
INSERT INTO psy_package_categories (slug, label, badge_color, sort_order)
VALUES
  ('standard', 'Program Intensif', NULL,    10),
  ('free',     'Pakej Percuma',    'green', 20),
  ('vip',      'VIP / Premium',    'gold',  30)
ON CONFLICT (slug) DO NOTHING;

-- ──── konfigurasi pakej OB-direct: online dibenarkan sepanjang tempoh ────
UPDATE psy_packages
  SET allow_online_full_duration = true
  WHERE LOWER(package_id) IN ('obd1','obdx1','obdy1','obp1','obpx1','obpy1');

-- ──── pemetaan PDF perjanjian per pakej (hanya jika belum ditetapkan) ────
UPDATE psy_packages SET agreement_pdf = 'ELIXIR_EOL_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-eol','eol') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR_EOL+_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-eol-plus','pkg-eolplus','eol+','eol-plus') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR__JUMPSTART_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-jumpstart','pkg-js','js','jumpstart') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR__JUMPSTART+_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-jumpstart-plus','pkg-jsplus','js+','jumpstart+') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBD1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obd1','obd1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBDX1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obdx1','obdx1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBDY1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obdy1','obdy1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBG_(NLC)_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obg-nlc','pkg-obg','obg','obg-nlc') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBP1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obp1','obp1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBPX1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obpx1','obpx1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBPY1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obpy1','obpy1') AND agreement_pdf IS NULL;

-- ──── klausa perjanjian lalai (hanya jika masih kosong) ────
UPDATE psy_packages
SET
  agreement_clauses = '[
    {"title": "1. Tanggungjawab Maklumat", "body": "Saya mengambil tanggungjawab sepenuhnya terhadap kesihatan saya dan telah mengisi borang ini dengan sukarela dengan memberikan maklumat kesihatan saya kepada Ibnu Sina Wellness."},
    {"title": "2. Khidmat Nasihat", "body": "Saya berpuas hati dengan khidmat nasihat kesihatan yang diberikan oleh perawat Ibnu Sina Wellness."},
    {"title": "3. Bukan Rawatan Medikal", "body": "Saya faham dengan sepenuhnya bahawa ia bukan diagnosis medikal atau rawatan medikal atau substitut untuk diagnosis medikal atau rawatan medikal."},
    {"title": "4. Penyakit Mental & Sihir", "body": "Saya faham bahawa sekiranya saya mempunyai masalah mental atau sihir dan saka, saya harus dirawat terlebih dahulu sebelum memulakan program {{package_name}} di Ibnu Sina Wellness."},
    {"title": "5. Rawatan Alternatif", "body": "Saya faham bahawa program {{package_name}} di Ibnu Sina Wellness adalah rawatan alternatif dan ia tidak menggantikan perubatan hospital maka saya akan meneruskan pengambilan ubat, perubatan dan pemeriksaan hospital."},
    {"title": "6. Komitmen Harian", "body": "Saya faham bagi mencapai hasil yang baik, saya perlu amalkan secara komited setiap hari segala tatacara yang disusun dan diajarkan oleh Ibnu Sina Wellness secara sepenuhnya."},
    {"title": "7. Gaya Pemikiran Fitrah", "body": "Saya komited untuk mengikuti program {{package_name}} bagi menukar kepada Gaya Pemikiran Follow Fitrah sebagai tahap asas untuk mencapai kesihatan yang sihat."},
    {"title": "8. Penyembuhan Di Tangan Allah", "body": "Saya faham penyembuhan penyakit adalah di tangan Allah SWT dan jangkamasa penyembuhan bergantung kepada keizinan Allah."},
    {"title": "9. Penerangan Pakej", "body": "Saya telah diberi penerangan penuh pakej program {{package_name}} dengan jelas oleh Ibnu Sina Wellness."},
    {"title": "10. Reaksi Pemulihan", "body": "Ibnu Sina Wellness telah memaklumkan tentang reaksi pemulihan dan gejala prosedur, yang boleh termasuk, tetapi tidak terhad kepada: pening atau loya, sakit-sakit badan, flu, lebam, perubahan warna kulit, dan kemungkinan risiko lain yang tidak dijangka. Dalam sesetengah kes, simptom saya mungkin bertambah buat sementara waktu sebelum ia mula beransur baik. Saya akan menanggung segala risiko yang terlibat dengan prosedur saya."},
    {"title": "11. Kecemasan Hospital", "body": "Saya faham saya perlu ke hospital untuk kecemasan. Saya juga akan segera ke hospital sekiranya saya sakit atau mengalami reaksi pemulihan yang teruk seperti yang tertera di buku Sains di Sebalik {{package_name}} atau seperti yang dinasihatkan oleh perawat dan coach Ibnu Sina Wellness."},
    {"title": "12. Tiada Jaminan Keputusan", "body": "Saya faham bahawa tiada jaminan keputusan untuk sebarang prosedur yang sedang dijalani. Prosedur kesihatan alternatif dan holistik selalunya tidak akan menunjukkan hasil rawatan dengan serta merta."},
    {"title": "13. Tempoh Hasil", "body": "Tempoh untuk mencapai hasil serta keputusan bergantung pada tahap kesihatan saya, disiplin serta komitmen saya mengamalkan kaedah program {{package_name}} di Ibnu Sina Wellness."},
    {"title": "14. Tiada Paksa Tanggungjawab", "body": "Saya tidak akan memaksa Ibnu Sina Wellness untuk bertanggungjawab ke atas sebarang kekurangan hasil program {{package_name}}."},
    {"title": "15. Kerosakan Peralatan", "body": "Saya faham bahawa sekiranya terdapat sebarang kerosakan terhadap peralatan rawatan Ibnu Sina Wellness disebabkan oleh kecuaian atau kegagalan untuk bertindak sewajarnya dari diri saya sendiri, saya akan membayar pampasan kepada pihak Ibnu Sina Wellness kos yang munasabah untuk membaiki kerosakan peralatan rawatan tersebut berdasarkan permintaan Ibnu Sina Wellness."},
    {"title": "16. Pilihan Sendiri", "body": "Dengan rela hati saya sendiri membuat keputusan untuk mengikuti program {{package_name}} Ibnu Sina Wellness dan telah dimaklumkan tentang risiko serta manfaatnya."},
    {"title": "17. Pembebasan Tanggungjawab", "body": "Saya membebaskan pihak Ibnu Sina Wellness, herba-herba yang digunakan, peralatan yang digunakan, fasiliti, perawat, strategist, pekerja Ibnu Sina Wellness, pesakit yang memberi testimoni serta kesemua produksi media Ibnu Sina Wellness dari sebarang tindakan dan kerugian selamanya."},
    {"title": "18. Barang Peribadi", "body": "Saya faham bahawa semua barang peribadi di dalam fasiliti Ibnu Sina Wellness adalah di bawah tanggungjawab saya sendiri dan pihak Ibnu Sina Wellness tidak akan bertanggungjawab pada sebarang kerosakan atau kecurian atau penyelewengan barang peribadi saya."},
    {"title": "19. Rakaman Laporan Progres", "body": "19.1 Saya dengan ini mengesahkan persetujuan yang diberikan kepada Ibnu Sina Wellness berkenaan dengan fotografi, rakaman video, penggambaran, atau rakaman audio bagi tujuan penyimpanan rekod pesakit, informasi, pembelajaran atau promosi.\n\n19.2 Saya sedia maklum bahawa maklumat yang diberikan kepada Ibnu Sina Wellness akan digunakan, diedarkan atau dikongsikan kepada mana-mana pihak ketiga berkenaan dengan fotografi, rakaman video, penggambaran, atau rakaman audio untuk siaran - langsung atau pre-rakaman."},
    {"title": "20. Pembatalan Program", "body": "Saya akan memberi notis bertulis tempoh 7 hari sekiranya saya ingin membatalkan program {{package_name}}."},
    {"title": "21. Pemulangan Wang", "body": "Saya faham tiada pemulangan wang secara tunai ke atas pembayaran yang dilakukan. Lebihan wang yang telah dibayar akan digantikan dengan mana-mana perkhidmatan dan/atau produk Ibnu Sina Wellness yang lain."},
    {"title": "22. Hari Rawatan", "body": "22.1 Hari rawatan ialah pada hari Jumaat, Sabtu dan Ahad.\n\n22.2 Saya faham bahawa jika rawatan di luar waktu dan hari yang dinyatakan, akan ada cas \"on-call\" RM50/sejam.\n\n22.3 Saya faham bahawa ISW berhak untuk menukar waktu dan hari rawatan atas apa-apa sebab dan tiada cas \"on-call\" akan dikenakan."},
    {"title": "23. Pembayaran Ansuran", "body": "Saya bertanggungjawab untuk melunaskan bayaran mengikut tarikh dan jumlah yang telah ditetapkan mengikut Pelan Pelaburan Ansuran."},
    {"title": "24. Kegagalan Ansuran", "body": "Saya faham jika saya gagal menunaikan pembayaran mengikut Pelan Pelaburan Ansuran, yuran pakej saya akan berbalik ke yuran asal."},
    {"title": "25. Tindakan Undang-undang", "body": "Saya juga sedar kegagalan mematuhi bayaran mengikut tarikh dan jumlah yang telah ditetapkan akan menyebabkan kes saya dirujuk untuk tindakan undang-undang."},
    {"title": "26. Persetujuan Hutang", "body": "Saya bersetuju untuk menjalani program {{package_name}} sepenuhnya di Ibnu Sina Wellness secara berhutang."},
    {"title": "27. Janji Pembayaran", "body": "Saya berjanji untuk melangsaikan semua bayaran mengikut Pelan Pelaburan Ansuran."},
    {"title": "28. Tiada Refund", "body": "Saya faham tiada pemulangan wang akan diberikan atas bayaran yang telah dibuat. Lebihan wang yang telah dibayar boleh digantikan dengan mana-mana perkhidmatan dan/atau produk Ibnu Sina Wellness yang lain, tertakluk pada pengurusan Ibnu Sina Wellness."},
    {"title": "29. Bayaran Online Transfer", "body": "Untuk bayaran online transfer, saya hanya akan buat bayaran ke akaun di bawah:\n\nIBNU SINA WELLNESS SDN BHD - CIMB BANK - 8605794539\nWA SCREENSHOT BAYARAN KE COACH DI 0389663702"}
  ]'::jsonb,
  agreement_version = 'ISW.SOP OB KOB FORM 03 CONTRACT 250711',
  agreement_title = 'Kontrak Pelaburan Kesihatan'
WHERE agreement_clauses = '[]' OR agreement_clauses IS NULL;

-- ──── jadual harian lalai per pakej (hanya jika masih kosong) ────
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
