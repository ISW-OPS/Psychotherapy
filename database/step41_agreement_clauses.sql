-- ============================================================
-- step41_agreement_clauses.sql
-- Migrate from PDF upload to HTML text clauses approach.
-- Admin edit clauses → patient render as HTML → sign → auto-generate PDF.
--
-- agreement_clauses structure:
--   [{ "title": "1. Tanggungjawab", "body": "Saya bersetuju..." }, ...]
--
-- Supports variables: {{patient_name}}, {{patient_ic}}, {{package_name}}, {{today}}, {{price}}
-- ============================================================

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS agreement_clauses JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS agreement_version TEXT,
  ADD COLUMN IF NOT EXISTS agreement_title TEXT DEFAULT 'Kontrak Pelaburan Kesihatan';

COMMENT ON COLUMN psy_packages.agreement_clauses IS
  'Array of {title, body} clauses for the patient agreement. Supports variables like {{patient_name}}.';
COMMENT ON COLUMN psy_packages.agreement_version IS
  'Version label, e.g. ISW.SOP OB KOB FORM 03 CONTRACT 250711';
COMMENT ON COLUMN psy_packages.agreement_title IS
  'Title shown at top of agreement (default: Kontrak Pelaburan Kesihatan)';

-- Seed default clauses (matching the original PDF content) for all packages with empty clauses
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

SELECT 'Step 41 OK — agreement clauses seeded for all packages' AS status;
