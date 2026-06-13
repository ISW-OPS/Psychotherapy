-- FAQ Rawatan Overhaul Body 2023
-- Two-table structure: faq_sections + faq_items
-- Accessible by both staff and patients (RLS handled at app level)

CREATE TABLE IF NOT EXISTS psy_faq_sections (
  id          SERIAL PRIMARY KEY,
  code        VARCHAR(2) NOT NULL UNIQUE,  -- A, B, C ... M
  title       TEXT NOT NULL,
  sort_order  INT NOT NULL
);

CREATE TABLE IF NOT EXISTS psy_faq_items (
  id          SERIAL PRIMARY KEY,
  section_id  INT NOT NULL REFERENCES psy_faq_sections(id) ON DELETE CASCADE,
  soalan      TEXT NOT NULL,
  jawapan     TEXT NOT NULL,
  sort_order  INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_faq_items_section ON psy_faq_items(section_id);

-- ─── SECTIONS ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_sections (code, title, sort_order) VALUES
  ('A', 'Pendahuluan Rawatan Overhaul Body', 1),
  ('B', 'Buku PET', 2),
  ('C', 'Buku Sains Di Sebalik Overhaul Body', 3),
  ('D', 'Sistem Perubatan Overhaul Body (Perubatan Herba)', 4),
  ('E', 'Sistem Perubatan Overhaul Body (Perubatan Alami)', 5),
  ('F', 'Sistem Perubatan Overhaul Body (Perubatan Minda)', 6),
  ('G', 'Sistem Perubatan Overhaul Body (Perubatan Rohani)', 7),
  ('H', 'Formula Rawatan Overhaul Body (5 Formula)', 8),
  ('I', 'Fasa Rawatan Overhaul Body (Fasa 1) — Rawatan Mingguan', 9),
  ('J', 'Fasa Rawatan Overhaul Body (Fasa 2)', 10),
  ('K', 'Fasa Rawatan Overhaul Body (Fasa 3)', 11),
  ('L', 'Diet dan Nutrisi', 12),
  ('M', 'Laporan Progres Report', 13);

-- ─── SECTION A ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_items (section_id, soalan, jawapan, sort_order)
SELECT s.id, q.soalan, q.jawapan, q.sort_order
FROM psy_faq_sections s,
(VALUES
  (1, 'Kenapa saya boleh jatuh sakit?',
   'Penyakit berlaku disebabkan dua faktor utama: (1) Ketidakseimbangan mikrobiota perut dan sistem gastrousus — setiap manusia mempunyai lebih daripada 100 trilion mikrobiota dan ketidakseimbangannya menyebabkan rintangan insulin yang mendorong penyakit kronik. (2) Peningkatan tekanan oksidatif dalam sistem enjin jasad — gaya hidup, tabiat pemakanan dan gaya pemikiran yang FIGHT FITRAH mendorong peningkatan radikal bebas yang menyerang sel-sel sihat, merosakkannya dan boleh mendorong percambahan sel kanser.'),
  (2, 'Bagaimana Overhaul Body dapat merawat penyakit saya?',
   'Overhaul Body melembutkan saraf, injap, tisu, organ, sendi dan otot; mengembangkan lapisan toksin; mengepam keluar racun-racun yang tersumbat; mematikan parasit dan candida; kemudian membekalkan tenaga secukupnya agar sistem enjin jasad dapat menggalakkan percambahan berjuta-juta sel sihat baharu, yang akhirnya merawat penyakit hingga ke akar umbi.'),
  (3, 'Adakah saya boleh kembali sihat seperti dahulu setelah menjalani Overhaul Body?',
   'Overhaul Body hanya akan berjaya jika anda berniat untuk sembuh dan berdisiplin dalam mengikuti program yang telah disusun khas serta yakin terhadap Hukum Alam (Sunnatullah) dan Teknologi Fitrah yang telah ditetapkan oleh Allah. Hasilnya anda akan kembali sihat-aktif-panjang umur.'),
  (4, 'Adakah pemulangan wang akan diberikan sekiranya berhenti rawatan?',
   'Tiada pemulangan dalam bentuk wang. Sekiranya berhenti rawatan, pemulangan jumlah yang telah dibayar akan dipulangkan dengan madu.'),
  (5, 'Perlukah saya tukar tampalan gigi amalgam ke komposit dalam menjalani Overhaul Body?',
   'Perlu. Tampalan gigi amalgam akan menyebabkan sistem enjin jasad dipenuhi heavy metal berbahaya kerana ia terhakis sedikit demi sedikit hari demi hari, menyebabkan penyakit kronik berlaku.'),
  (6, 'Boleh ke pesakit Overhaul Body mencabut gigi semasa dalam rawatan?',
   'Boleh, kerana ia tidak menganggu proses lembut-kembang-cerna longgokan toksin. Cuma elakkan cabut gigi di hari rawatan atau sehari sebelum hari rawatan anda.'),
  (7, 'Boleh ke pesakit Overhaul Body melakukan rawatan laser semasa dalam tempoh rawatan?',
   'Tidak digalakkan kerana laser merupakan rawatan yang membunuh sel manakala fokus rawatan Overhaul Body ialah untuk menghidupkan sel-sel yang sihat.'),
  (8, 'Selain dari ubat yang diberi oleh doktor, adakah ubatan/rawatan lain yang boleh saya ambil semasa Overhaul Body?',
   'Selain daripada ubat yang diberikan oleh doktor perubatan anda, kami tidak menggalakkan anda untuk mengambil ubat atau rawatan daripada tempat lain. Fokus sahaja melakukan rawatan Overhaul Body yang anda sedang laksanakan ini dan nantikan kesan positifnya dengan penuh keyakinan.'),
  (9, 'Adakah dibenarkan untuk pengambilan ubat kemoterapi, ubat tahan sakit dan ubat steroid?',
   'Ubat-ubatan sebegini adalah tidak digalakkan kerana ubat kemoterapi fokusnya untuk membunuh sel manakala rawatan Overhaul Body ialah untuk menggalakkan percambahan sel. Begitu juga ubat tahan sakit dan ubat steroid yang mengganggu proses penyembuhan jasad. Ubat-ubatan ini boleh diambil selepas habis rawatan Overhaul Body jika masih memerlukan — namun kebanyakan pesakit sudah tidak memerlukannya selepas tempoh rawatan kerana sistem enjin JASAD-JIWA-AKAL-ROH sudah kembali berfungsi mengikut Teknologi Fitrah.'),
  (10, 'Boleh ke ambil vaksin/booster jika buat Overhaul Body?',
   'Tidak digalakkan kerana ditakuti boleh menganggu fungsi fitrah sistem enjin jasad anda.'),
  (11, 'Bolehkah saya menggunakan deodorant sekiranya saya ada kanser payudara?',
   'Tidak digalakkan menggunakan deodorant yang spray atau roll kerana ia menyumbat pori-pori pada ketiak tempat di mana toksin dikeluarkan. Alternatif terbaik ialah bertukar kepada tawas atau deodorant semula jadi iaitu garam kristal (smells no more) yang tidak bersifat menyumbat pori-pori kulit.'),
  (12, 'Adakah saya boleh mengambil urutan tradisional semasa dalam tempoh rawatan?',
   'Ya, anda boleh melakukan urutan tradisional semasa rawatan Overhaul Body. Ia bagus untuk melancarkan pengaliran dan peredaran darah dan tidak menganggu proses lembut-kembang-cerna longgokan toksin. Yang tidak digalakkan ialah berbekam, fashdu dan sewaktu dengannya.'),
  (13, 'Adakah ada kemungkinan sel kanser merebak semasa melakukan rawatan Overhaul Body?',
   'Fokus rawatan Overhaul Body ialah untuk menghapuskan punca penyakit dari akar umbinya — ia membantu membunuh sel kanser dan mengepam keluar sel-sel mati secara alami. Maka sel kanser tidak akan merebak jika anda mengikut segala panduan. NAMUN, terdapat situasi di mana sel kanser pesakit menjadi aktif semula — itu merupakan reaksi pemulihan UNTUK SEMENTARA WAKTU kerana jasad sedang mengepam keluar longgokan toksin.')
) AS q(sort_order, soalan, jawapan)
WHERE s.code = 'A';

-- ─── SECTION B ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_items (section_id, soalan, jawapan, sort_order)
SELECT s.id, q.soalan, q.jawapan, q.sort_order
FROM psy_faq_sections s,
(VALUES
  (1, 'Adakah saya perlu mengikuti segala panduan dan amalan yang telah disarankan?',
   'Komitmen anda yang tinggi dalam mengikuti setiap panduan dan amalan yang disarankan secara istiqamah ketika menjalani rawatan adalah penting untuk kejayaan Overhaul Body. Pihak Ibnu Sina Wellness sangat menggalakkan anda mengikuti setiap saranan dan panduan yang telah diberikan untuk mendapatkan hasil rawatan yang memberangsangkan.'),
  (2, 'Kenapa saya perlu meminum Jus Thoharah 2 kali seminggu?',
   'Jus Thoharah perlu diminum 2 kali seminggu pada hari yang berturutan atau paling tidak hanya selang sehari. Jika pengambilan tidak mengikuti cadangan yang disarankan, proses penyucian sel akan terganggu. Jus Thoharah bertujuan untuk lembut-kembang-cerna longgokan toksin beracun dalam sistem enjin jasad yang menjadi punca penyakit kronik berlaku.'),
  (3, 'Bolehkah saya mencampur rawatan dari Ibnu Sina Wellness dengan rawatan luar seperti ruqyah?',
   'Kebiasaannya, Perawat akan menyuruh anda melakukan rawatan seperti ruqyah SEBELUM anda melakukan rawatan Overhaul Body — untuk menyelesaikan masalah berkenaan saka, sihir dan sebagainya dahulu. Kesimpulannya anda tidak boleh mencampurkan rawatan Overhaul Body dengan rawatan-rawatan lain.'),
  (4, 'Mengapakah buku ini dinamakan Panduan SISTEM PET?',
   'Sejak 2015 hingga awal 2019, rawatan dipanggil Sistem PET iaitu (P)urification, (E)rase dan (T)une. Sejak 2019 rawatan dinamakan semula kepada Overhaul Body kerana ia lebih dekat dengan apa yang dilakukan sekarang dan mudah difahami. Buku PET akan digantikan dengan buku Sains Di Sebalik Overhaul Body apabila habis diedarkan.'),
  (5, 'Mengapakah cetakan buku PET ini menggunakan nama 7 Heaven Wellness?',
   'Dari 2015 sehingga awal 2019, syarikat kami dahulunya dikenali sebagai 7 Heaven Wellness. Bermula 2019 hingga sekarang, syarikat dan rawatan kami telah dijenamakan semula sebagai Ibnu Sina Wellness untuk memberikan gambaran jelas bahawa rawatan berasaskan Kanun Perubatan Ibnu Sina.'),
  (6, 'Apa bezanya Buku PET dengan Buku Sains Di Sebalik Overhaul Body?',
   'Buku Sains di Sebalik Overhaul Body merupakan pengganti Buku PET yang digunakan sejak 2015. Buku PET menerangkan rawatan secara ringkas manakala Buku Sains Di Sebalik Overhaul Body lebih kompleks dan disertakan dengan beratus kajian saintifik moden untuk membantu pesakit lebih memahami rawatan Overhaul Body.')
) AS q(sort_order, soalan, jawapan)
WHERE s.code = 'B';

-- ─── SECTION C ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_items (section_id, soalan, jawapan, sort_order)
SELECT s.id, q.soalan, q.jawapan, q.sort_order
FROM psy_faq_sections s,
(VALUES
  (1, 'Apakah kepentingan Buku Sains Di Sebalik Overhaul Body?',
   'Buku Sains di sebalik Overhaul Body merupakan kompilasi kesemua kaedah-kaedah rawatan dalam Overhaul Body, mengaitkan kepentingan kaedah-kaedah rawatan dalam menjamin kesihatan yang baik dan disokong dengan bukti-bukti kajian saintifik. Ia juga menunjukkan bagaimana rawatan Overhaul Body boleh membantu transformasi sistem enjin JASAD-JIWA-AKAL-ROH agar kembali berfungsi mengikut Teknologi Fitrah. Buku ini penting untuk dijadikan rujukan pesakit yang melakukan rawatan Overhaul Body.')
) AS q(sort_order, soalan, jawapan)
WHERE s.code = 'C';

-- ─── SECTION D ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_items (section_id, soalan, jawapan, sort_order)
SELECT s.id, q.soalan, q.jawapan, q.sort_order
FROM psy_faq_sections s,
(VALUES
  (1,  'Kenapa baik pulih sel menggunakan madu?',
   'Tiga sebab utama: (1) Kajian saintifik menunjukkan madu berupaya baik pulih rantaian DNA sel-sel dalam jasad, membolehkan percambahan sel sihat baharu. (2) Madu membekalkan tenaga untuk sel melakukan baik pulih dan merawat rintangan insulin dengan merangsang penghasilan insulin oleh pankreas serta meningkatkan sensitivity insulin reseptor sel. (3) Madu tinggi antioksidan yang meneutralkan radikal bebas punca kerosakan sel. Kajian terkini juga membuktikan madu lebah asli dapat meneutralkan toksin dan menghalang kerosakan DNA yang disebabkan toksin.'),
  (2,  'Kenapa Lote Tree Honey digunakan?',
   'Lote Tree Honey dianggap sebagai raja segala madu oleh masyarakat Arab di Timur Tengah, berdasarkan ayat 13-18 surah An-Najm yang menyatakan pohon Lote berasal dari syurga yang ke-7. Raja-raja Arab memonopoli pasaran Lote Tree Honey gred Royal dan mengamalkan pengambilannya lebih 10 sudu besar setiap hari sehingga hidup berumur 80 tahun ke atas tanpa penyakit kronik.'),
  (3,  'Betul ke madu Lote Tree Honey sama sahaja dengan gula biasa?',
   'Tidak. Komposisi utama madu terdiri daripada gula ringkas monosakarida (fruktosa dan glukosa) ditambah enzim hidup diastase, invertase dan glukosa oksidase. Gula biasa terdiri daripada gula disakarida tanpa nutrisi lain. Nilai tambah madu sangat bagus untuk merawat penyakit kronik seperti kencing manis dan kanser.'),
  (4,  'Dari manakah sumber Lote Tree Honey yang digunakan di Ibnu Sina Wellness?',
   'Lote Tree Honey diimport dan dibawa khas dari ladang-ladang yang diusahakan oleh kaum keluarga Hakeema sendiri. Madu ini tidak diproses dengan sebarang bahan kimia dan tidak diproses menggunakan haba yang tinggi bagi menjaga keasliannya. Lebah yang membawa nectar dari pohon Lote tidak diberi makan air gula ataupun antibiotik — hanya lebah liar berupaya membawa nectar dari pohon Lote.'),
  (5,  'Walaupun harga Lote Tree Honey 1/3 lebih murah dari harga pasaran, bukankah RM2000 masih terlalu mahal?',
   'Harga jualan Lote Tree Honey di Ibnu Sina Wellness masih dikira murah pada RM2000. Ada pesakit yang melaporkan mereka pernah membeli Lote Tree Honey gred yang sama di Dubai dengan harga mencecah RM3,000 sekilogram.'),
  (6,  'Kenapa selepas makan madu perut akan kembung dan mengalami cirit-birit?',
   'Kebiasaannya anda akan mengalami simptom kembung dan cirit-birit apabila mengambil madu LTHPG/YHPG sahaja kerana kandungan pearl garlic. Simptom ini biasanya berlaku di awal rawatan sahaja dan akan hilang apabila perut sudah boleh beradaptasi. Rasa kembung tersebut adalah salah satu cara untuk mengepam keluar longgokan toksin dan menyediakan jasad untuk minum Jus Thoharah.'),
  (7,  'Adakah madu akan meningkatkan lagi gula dalam darah saya?',
   'Semestinya tidak kerana madu akan membantu menstabilkan paras gula dalam darah. Madu membantu mengaktifkan semula sel pankreas untuk merembeskan insulin secukupnya dan meningkatkan sensitiviti insulin reseptor sel. MUNGKIN anda akan mengalami peningkatan paras gula UNTUK SEMENTARA WAKTU kerana ia merupakan reaksi pemulihan. Jangan panik dan teruskan konsisten dengan pengambilan madu seperti biasa.'),
  (8,  'Sekiranya tidak berkesempatan untuk membuat campuran, bolehkah saya makan madu sahaja?',
   'TIDAK DIGALAKKAN! Anda perlu berdisiplin dalam pengambilan madu dengan campuran seperti yang ditetapkan. Kegagalan mengambil madu bersama campuran akan mengganggu keberkesanan rawatan. Sekiranya tertinggal, anda dibolehkan makan madu LTHPG/YHPG begitu sahaja — campurkan dengan air suam sedikit jika sukar diminum. Pastikan perkara yang sama tidak berulang.'),
  (9,  'Mengapakah tidak menggunakan madu tempatan yang harga jauh lebih murah?',
   'Menurut kajian oleh Professor Dr. Kamaruddin (ahli mikrobiologi, Universiti Malaya), lebih 80% madu yang dijual di pasaran Malaysia adalah madu tiruan. Bagi mengurangkan risiko penggunaan madu tiruan yang boleh memburukkan penyakit, pesakit disarankan menggunakan Lote Tree Honey yang dibekalkan. Sifat antioksidan Lote Tree Honey juga lebih tinggi berbanding madu tempatan.'),
  (10, 'Adakah masih minum pati kunyit dengan madu ketika haid?',
   'Ya, teruskan minum kunyit bercampur asam jawa supaya darah kotor dari haid dapat dipecahkan dan keluar lebih lancar.'),
  (11, 'Bolehkah makan madu pada waktu tengah hari?',
   'Boleh. Anda digalakkan untuk minum madu 10 kali sehari — susunlah waktu untuk minum madu agar sistem enjin jasad mendapat madu secukupnya sepanjang hari dari pagi, tengahari, petang sehingga malam.'),
  (12, 'Adakah saya boleh berhenti minum Lote Tree Honey kerana tidak mampu membelinya pada bulan ini?',
   'Anda dinasihatkan supaya tidak berhenti mengambil Lote Tree Honey. Pengambilannya akan membantu mempercepatkan proses baik pulih DNA dan sel. Sekarang, toksin dalam jasad sekurang-kurangnya 50–80% sudah dipam keluar dan Lote Tree Honey dapat memudahkan sel-sel baharu bercambah banyak bagi membolehkan anda kembali sihat.'),
  (13, 'Adakah saya perlu makan madu juga pada hari minum Jus Thoharah?',
   'Sewaktu hari rawatan Overhaul Body, minum LTH/LTHPG sejam sekali sehingga 2 jam sebelum rawatan. Hanya selepas 3 jam rawatan berakhir anda dibenarkan minum semula LTH/LTHPG setiap sejam hingga sebelum tidur. Tidak mengapa jika tidak dapat minum sebanyak 10 kali ketika hari rawatan.'),
  (14, 'Kalau saya tersilap aturan makan madu, adakah saya perlu tambah dos madu?',
   'Tidak mengapa jika tersalah minum madu. Yang penting anda sedar di mana yang tersilap dan teruskan minum madu seperti biasa. Tambah dos minum madu jika perlu.'),
  (15, 'Pesakit gagal komitmen madu 10 kali sehari. Apakah cadangan lain?',
   'Walau apapun yang berlaku anda perlu pastikan cukup pengambilan madu 10 kali sehari. Jika terlalu sibuk anda boleh minum 2 sudu madu (sama jenis) pada satu masa ataupun pendekkan jarak antara pengambilan madu kepada 15–30 minit.'),
  (16, 'Adakah boleh saya kurangkan pengambilan minum Lote Tree Honey dari 10 kali sehari ke 5 kali sehari?',
   'Untuk bulan pertama dan kedua selepas habis Overhaul Body, anda perlu minum 10 kali sehari dahulu. Selepas anda datang rawatan susulan bulanan yang kedua, Hakeema akan benarkan jika pembaikpulihan sel dalam progress yang baik.'),
  (17, 'Ahli keluarga saya positif COVID. Saya nak berikan mereka LTH. Berapa dos yang diperlukan?',
   'Untuk ahli keluarga yang tidak mempunyai penyakit kronik tetapi dijangkiti covid19, dos yang digalakkan ialah 4–6 sudu sehari, selang sejam pengambilannya. Jika kronik boleh ambil 10 sudu sehari. Jika sudah sihat tetapi ingin meneruskan minum madu, dos yang digalakkan ialah 1–2 sudu sehari.'),
  (18, 'Kenapa madu ini bersemut?',
   'Madu asli memang semut akan datang. Madu mengandungi gula semulajadi (fruktosa) — bahan natural — jadi semut akan datang. Jika semut tidak datang ke madu tersebut, itu bermakna madu itu mengandungi bahan kimia, pengawet, pewarna, belerang atau bahan tambahan lain.'),
  (19, 'Adakah madu asli tidak mengalami pengkristalan gula?',
   'Tidak timbul isu madu tersebut asli atau bukan apabila madu itu mengkristal. Glukosa kurang larut berbanding fruktosa dan mudah terpisah dari molekul air, membentuk kristal gula yang halus. Apabila nisbah kandungan glukosa melebihi fruktosa, madu itu akan lebih mudah menjadi kristal.'),
  (20, 'Kenapa sangat penting pemakanan campuran madu dalam menjalani rawatan ini?',
   'Campuran kunyit dan air asam jawa menggandakan manfaat madu. Kunyit untuk mengaktifkan fungsi hati agar boleh menapis toksin dengan optimum. Asam jawa pula fokusnya untuk mencairkan darah yang pekat dan berasid agar darah boleh dialirkan ke seluruh sistem enjin jasad secara optimum.'),
  (21, 'Adakah pengambilan kunyit setiap hari akan memberi kesan buruk kepada hati saya?',
   'TIDAK. Kajian saintifik menunjukkan pengambilan kunyit bagus untuk kesihatan hati. Kunyit mengandungi curcumin yang bagus untuk kesihatan hati agar kembali aktif menapis longgokan toksin beracun. Isipadu air kunyit yang perlu diambil sehari hanyalah 100 mL.'),
  (22, 'Apa itu Za''faran?',
   'Za''faran ialah sejenis rempah-ratus daripada stigma bunga Za''faran, digelar Raja Segala Rempah dan herba termahal di dunia. Sekuntum bunga Za''faran hanya mampu menghasilkan 3 helai bebenang Za''faran. Za''faran akan mengeluarkan warna kuning pekat dan kebiasaannya digunakan sebagai pewarna dalam penyediaan nasi Arab apabila direndam dalam air.'),
  (23, 'Apa tujuan dan kebaikan Aktivasi Neuron?',
   'Berdasarkan penemuan bioperubatan tradisional dan moden, Za''faran berpotensi tinggi dalam merawat gangguan neurodegeneratif, penyakit koronari arteri, penyakit pernafasan, ulser perut, masalah sistem pencernaan, kerosakan buah pinggang, kanser, katarak, dan jangkitan mikrob. Aktivasi Neuron terbukti secara saintifik dapat melindungi sel neuron, buah pinggang dan jantung; menangani masalah kesuburan, merawat kanser, mencegah keradangan, mengawal tekanan darah tinggi, memberikan rasa tenang, dan mengepam toksin keluar daripada jasad.'),
  (24, 'Apakah kaitan Za''faran dengan neuron?',
   'Za''faran sangat baik untuk kecerdasan minda kerana ia mengaktifkan semula saraf dan neuron dalam otak yang selama ini tidak menjalankan fungsinya dengan optimum, menyebabkan masalah seperti pelupa di usia muda, Parkinson dan sebagainya.'),
  (25, 'Jika tidak sempat minum air Za''faran pada waktu pagi, bolehkah diminum pada waktu lain?',
   'Air Za''faran perlu diminum pada waktu pagi sebelum melakukan aktiviti harian yang lain. Pastikan anda minum air za''faran dulu sebelum minum madu LTHPG/YHPG (sudu-1). Minum satu botol air za''faran sehingga habis.'),
  (26, 'Kenapa air Za''faran saya menjadi putih?',
   'Air za''faran bertukar putih kerana terlalu lama disimpan dari tarikh pembuatannya. Jika air za''faran sudah bertukar warna putih dan ada keladak di bahagian bawah botol, anda boleh minta untuk tukar air za''faran tersebut dengan botol yang baru pada hari di mana stok diberi.'),
  (27, 'Betul ke ada otak kedua di perut?',
   'Sebenarnya terdapat otak pada perut — bukanlah perumpamaan. Otak di perut terdiri daripada saraf enterik dan mikrobiota yang dapat melaksanakan fungsi sama seperti otak sebenar.'),
  (28, 'Adakah Penyucian Kolon itu menyakitkan?',
   'Proses penyucian kolon tidak menyakitkan kerana hanya air yang banyak dimasukkan ke usus besar melalui dubur untuk memberi tekanan sehingga kotoran pada usus besar dapat ditarik keluar sehingga usus besar menjadi bersih.'),
  (29, 'Kenapa saya perlu melakukan Penyucian Kolon walaupun saya bukan penghidap kanser kolon?',
   'Usus besar mempunyai 3 fungsi utama: meresap semula air dan elektrolit, menghasilkan dan meresap vitamin, serta menyingkirkan sisa-sisa dari sistem enjin jasad. Jika dinding-dinding usus besar kotor ia akan menyebabkan fungsi-fungsi ini terganggu dan lama kelamaan menyebabkan penyakit kronik berlaku. Sesiapa yang sudah mempunyai penyakit kronik pasti menghidapi masalah usus ini.'),
  (30, 'Kenapa perlu menggunakan air suling untuk Penyucian Kolon?',
   'Hanya air suling yang digunakan kerana ia hanya mengandungi molekul Hidrogen dan Oksigen (pH 7), tiada bahan mineral, hidupan mikro mahupun bahan-bahan lain. Maka, air suling tersebut tidak berbahaya untuk dimasukkan ke dalam usus besar anda. Air suling boleh didapati di farmasi, kedai runcit atau pasar raya — kami menggalakkan anda pergi ke Pasaraya Aeon.'),
  (31, 'Adakah terdapat waktu tertentu untuk lakukan Penyucian Kolon?',
   'Anda boleh melakukan penyucian kolon pada waktu siang (pagi atau petang). Jangan lakukan pada waktu malam. Waktu disarankan adalah sebelum pukul 7 petang kerana dikhuatiri akan menyebabkan anda kembung perut atau sakit perut.'),
  (32, 'Bolehkah Penyucian Kolon dibuat lebih dari 2 kali?',
   'Semasa tempoh Overhaul Body, anda hanya perlu melakukan Penyucian Kolon sebanyak 2 kali seminggu, selang satu hari antara rawatan jus thoharah atau penyucian kolon. Namun selepas tamat Overhaul Body, anda dikehendaki melakukannya sebanyak 3 kali seminggu.'),
  (33, 'Kalau saya period atau pendarahan di dubur, apa saya perlu lakukan penyucian kolon?',
   'Sudah tentu! Penyucian kolon sebenarnya sangat baik pada masa ini kerana ia boleh membantu mengurangkan kekejangan dan kembung perut yang sering dikaitkan dengan haid.'),
  (34, 'Perlukah saya melakukan penyucian kolon semasa bulan Ramadhan?',
   'Tidak perlu melakukan penyucian kolon semasa bulan Ramadhan. Selepas Ramadhan dan terutamanya selepas menyambut Syawal, segera lakukan penyucian kolon.'),
  (35, 'Betul ke Penyucian Kolon ini selamat untuk dilakukan?',
   'Penyucian Kolon selamat untuk anda. Prosedur melibatkan bahan-bahan yang telah disterilkan dengan bahan antikuman dan prosedurnya tidak menggunakan bancuhan panas yang boleh menyebabkan lecur atau kesan terbakar kepada usus.'),
  (36, 'Mengapakah saya mesti menggunakan mesin air ozon?',
   'Selain mudah untuk digunakan, mesin air ozon dapat membekalkan oksigen yang mencukupi kepada anda. Jasad memerlukan oksigen yang banyak dan kerap untuk proses pemulihan. Air ozon ni sangat membantu dalam penyembuhan diri anda.'),
  (37, 'Berapa lama air ozon boleh diminum selepas diozonkan?',
   'Air ozon perlu diminum secepat mungkin sebaik sahaja air tersebut diozonkan. Semakin lama dibiarkan akan menyebabkan oksigen dalam air tersebut akan hilang atau berkurang. Anda boleh menggunakan air masak dan tidak semestinya air mineral sahaja.'),
  (38, 'Betul ke Terapi Ozon ini tidak berkesan?',
   'Oksigen merupakan keperluan utama sel hidup. Kekurangan oksigen boleh menyebabkan penyakit kronik dan membuatkan sel kanser lebih agresif. Menurut laporan Kementerian Kesihatan Malaysia bertajuk Ozone Therapy, penggunaan air ozon dalam rawatan moden adalah pelbagai dan berpotensi tinggi untuk rawatan tambahan.'),
  (39, 'Adakah madu tidak boleh bercampur dengan air panas?',
   'Madu mengandungi enzim hidup yang boleh musnah disebabkan suhu tinggi air panas — ini mengurangkan keberkesanannya. Jika perlu, gunakan air suam sahaja dan biarkan madu larut secara perlahan-lahan.'),
  (40, 'Adakah honey stick sama manfaatnya dengan madu asli?',
   'Tidak. Kaedah pembungkusan madu dalam tiub plastik membuatkan madu terdedah kepada haba semasa proses pembungkusan dan potensi reaksi plastik dengan madu. Ini boleh meningkatkan risiko bahaya kepada kesihatan.'),
  (41, 'Betul ke madu tidak boleh diambil menggunakan sudu besi?',
   'Pengambilan madu menggunakan sudu besi sebenarnya tidak membahayakan anda. Namun perlu diingat bahawa logam seperti besi dapat meneutralkan cas yang ada pada madu dan ini dikhuatiri akan mengurangkan keberkesanan madu. Selain itu, madu bersifat sedikit asidik (pH 4.7) yang bersifat menghakis — penggunaan sudu besi boleh mengakibatkan pencampuran bahan kimia dari permukaan sudu besi.'),
  (42, 'Sekiranya jus thoharah tumpah, berapakah harga tambahan yang perlu dibayar?',
   'Jus Thoharah Kembang: RM30. Jus Thoharah Pecah: RM65.'),
  (43, 'Adakah saya masih minum jus thoharah jika demam?',
   'Jangan skip minum jus thoharah. Bila demam, lebih baik minum jus thoharah. Namun, pastikan anda buat test covid-19 dahulu.'),
  (44, 'Mengapakah cara pengambilan Jus Thoharah perlu berselang-seli dengan campuran minyak zaitun?',
   'Terdapat dua jenis jus thoharah: jus hitam (bertujuan untuk lembut-kembang toksin lapisan demi lapisan hingga ke akar umbi) dan jus minyak (untuk pecahkan longgokan toksin agar dapat dipam keluar). Gabungan keduanya ialah 11 gelas Jus Thoharah. Tujuan diminum selang-seli ialah untuk mengurangkan rasa loya jika diambil secara berterusan.'),
  (45, 'Kenapa perlu berhenti minum Jus Thoharah pada waktu tengah hari?',
   'Pada waktu tengah hari iaitu ketika matahari tegak di atas kepala, proses metabolisme jasad akan menjadi perlahan. Pesakit perlu menghabiskan Jus Thoharah sebelum pukul 11.30 pagi dan jika masih ada baki, perlulah disambung minum semula selepas waktu Zohor.'),
  (46, 'Mengapakah Jus Thoharah tidak boleh dibawa pulang?',
   'Jus Thoharah dihasilkan secara segar setiap hari bagi mengekalkan manfaat dan khasiatnya. Oleh itu, ia tidak boleh dibawa pulang bagi mengelakkan berlakunya pengurangan kualiti yang boleh memudaratkan kesihatan pesakit.'),
  (47, 'Saya tidak larat untuk datang ke ISW untuk minum jus thoharah.',
   'Jus thoharah dan bekalan rawatan lain boleh dihantar dengan rider (pada hari rawatan) dan tuan/puan perlu minum sambil on video call/Google Meet sambil dipantau oleh staff (customer service).'),
  (48, 'Jika saya muntah semasa minum jus thoharah adakah jus thoharah belum dapat diproses dalam jasad?',
   'Anda termuntah kerana longgokan toksin yang tersumbat di bahagian atas jasad seperti di leher atau kawasan paru-paru atau perut sudah lembut-kembang-cerna. Teruskan sahaja muntah tanpa perlu risau. Muntah yang keluar merupakan salah satu cara untuk mengepam keluar longgokan toksin beracun dalam jasad. Ia menunjukkan bahawa Jus Thoharah yang diminum sudah diproses oleh jasad anda.'),
  (49, 'Kalau saya ada gastrik boleh ke minum jus thoharah?',
   'Ya boleh! Jus Thoharah tidak akan menipiskan lagi lapisan perut anda tetapi ia hanya mengepam keluar longgokan toksin yang menyebabkan anda gastrik.'),
  (50, 'Berapa lamakah tempoh pengambilan ubat darah tinggi dengan pengambilan jus thoharah?',
   'Anda digalakkan untuk menjarakkan pengambilan ubat seperti ubat darah tinggi dengan pengambilan Jus Thoharah sekurang-kurangnya anggaran 1 jam ke atas.'),
  (51, 'Apakah yang perlu saya lakukan apabila saya susah nak membuang walaupun minum jus thoharah?',
   'Masalah susah membuang ini hanya dialami pesakit yang berada di hujung rawatan kerana lapisan toksin di bahagian luar sudah berjaya dilembut-kembang-cerna. Sekarang Jus Thoharah fokus untuk lembut-kembang-cerna bahagian lapisan dalam yang lebih keras. Jangan panik — anda boleh percepatkan proses ini dengan minum air kelapa sehari sebiji.'),
  (52, 'Betul ke minyak zaitun merupakan makanan sunnah yang penuh barakah?',
   'Minyak zaitun mempunyai kedudukan istimewa dalam Islam sebagaimana firman Allah SWT dalam surah an-Nur, ayat 35. Nabi SAW bersabda: "Gunakanlah minyak zaitun sebagai makanan, berminyaklah dengannya untuk rambut, badan dan seumpamanya kerana sesungguhnya ia adalah daripada pokok yang berkat." (Hadis Riwayat Tirmidzi, No. 185)'),
  (53, 'Betul ke minyak zaitun tidak boleh digunakan dalam masakan?',
   'Kebaikan polifenol dalam minyak zaitun dapat dimanfaatkan sepenuhnya jika diambil secara mentah. Pemanasan minyak zaitun pada suhu 188°C selama 5 minit sahaja sudah boleh menghapuskan kebaikan luteolin sehingga 69%. Jika ingin memasak, gunakan api kecil atau sederhana. Boleh juga sekadar merenjiskan minyak zaitun ke atas hidangan yang telah masak atau salad segar.'),
  (54, 'Betul ke ada minyak zaitun yang boleh dimasak dan yang tidak boleh dimasak?',
   'Minyak zaitun extra virgin tidak sesuai untuk masakan kerana takat asap yang rendah. Minyak zaitun gred biasa lebih stabil dan mempunyai takat asap yang lebih tinggi dan sesuai untuk masakan.')
) AS q(sort_order, soalan, jawapan)
WHERE s.code = 'D';

-- ─── SECTION E ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_items (section_id, soalan, jawapan, sort_order)
SELECT s.id, q.soalan, q.jawapan, q.sort_order
FROM psy_faq_sections s,
(VALUES
  (1,  'Adakah saya boleh memilih untuk tidak melakukan IV Saline Drip jika saya seorang yang takut pada jarum?',
   'Kehilangan elektrolit adalah kebiasaan bagi pesakit kronik dan dapat mengurangkan kadar prognosis. Elektrolit penting kerana ia mengandungi cas yang membenarkan isyarat elektrik proses biologi mengalir ke seluruh jasad. Jika anda tidak melakukan IV Saline Drip, langkah penyembuhan akan terbantut.'),
  (2,  'Kenapa IV Saline Drip hanya boleh dilakukan pada Sabtu pagi sahaja?',
   'Rawatan IV Saline Drip akan dilakukan oleh Medical Assistant (MA) yang berdaftar. Bagi pesakit yang melakukan rawatan selama 12 minggu anda hanya perlu melakukan IV Saline Drip pada 4 minggu pertama sahaja. Waktu kehadiran MA bergantung kepada keberadaan MA pada minggu tersebut.'),
  (3,  'Adakah saya boleh menunda IV Saline Drip yang dijadualkan pada minggu ke-4 kepada minggu ke-5?',
   'IV Saline Drip perlu dilakukan pada 4 minggu pertama meminum jus thoharah, kerana pada masa inilah banyak toksin yang keluar dan tubuh kehilangan banyak elektrolit. Anda dibenarkan menunda ke minggu ke-5 atas sebab yang kukuh sahaja. Jika tidak, satu sesi drip itu tidak akan dikira.'),
  (4,  'Apakah kaitan antara IV Saline Drip dengan Aktivasi Neuron?',
   'IV Saline Drip ialah untuk seimbangkan elektrolit dalam sistem enjin jasad bagi mengepam keluar longgokan toksin secara optimum. Terapi Aktivasi Neuron pula ialah untuk mengaktifkan semula saraf-saraf dalam sistem enjin jasad. IV Saline Drip membekalkan elektrolit bercas yang menyokong kesan pengaktifan sel neuron dengan dibantu air Za''faran.'),
  (5,  'Adakah pernafasan secara biasa tidak cukup menandingi Pernafasan Fitrah?',
   'Pernafasan biasa tidak boleh menandingi pernafasan fitrah. Kajian saintifik membuktikan pernafasan fitrah (belly breathing/diaphragmatic breathing) terbukti bagus untuk kesihatan berbanding pernafasan dada. Melalui Pernafasan Fitrah, paru-paru akan mengembang sepenuhnya, sel menyerap oksigen yang mencukupi untuk mengepam keluar longgokan toksin dan menjalankan proses biokimia mengikut Teknologi Fitrah.'),
  (6,  'Mengapakah saya berasa mengantuk apabila melakukan Pernafasan Fitrah?',
   'Jasad kita sudah terbiasa dengan kaedah pernafasan yang kurang tepat. Apabila anda cuba bernafas dengan betul, gabungan rasa tenang daripada Pernafasan Fitrah dan rasa kepenatan kerana perubahan kaedah bernafas akan membuatkan anda sedikit mengantuk. Rasa mengantuk ini akan hilang apabila anda sudah membiasakan diri. Jika susah tidur, lakukan pernafasan fitrah.'),
  (7,  'Apakah yang perlu saya lakukan jika gagal melakukan Pernafasan Fitrah?',
   'Pernafasan Fitrah perlu dilatih dan diamalkan setiap hari. Luangkan masa 5-6 minit setiap kali selepas solat untuk melakukan pernafasan fitrah. Pastikan anda lakukan 30 minit pernafasan fitrah setiap hari. Jika lebih daripada 30 minit sehari, lebih bagus.'),
  (8,  'Kenapa saya selalu menjadi semput apabila melakukan pernafasan fitrah?',
   'Berkemungkinan anda tersalah cara melakukan pernafasan fitrah. Coach perlu periksa semula cara pesakit melakukan pernafasan fitrah. Jika sudah betul, ini bermaksud pesakit perlu melakukan pernafasan fitrah dalam keadaan yang lebih tenang atau berbaring kerana perutnya masih keras. Masalah ini biasanya dialami di awal rawatan sahaja.'),
  (9,  'Kenapa setiap kali datang ke Ibnu Sina Wellness perlu melakukan Pernafasan Fitrah sambil terapi bumi selama 30 minit?',
   'Anda perlu melakukan pernafasan fitrah dan terapi bumi setiap kali sebelum minum Jus Thoharah untuk membuka rongga-rongga dalam sistem enjin jasad anda. Semakin banyak rongga terbuka semakin mudah Jus Thoharah meresap masuk ke dalam sel untuk lembut-kembang-cerna longgokan toksin. Pernafasan fitrah dan terapi bumi juga bertujuan untuk menstabilkan tekanan darah, degupan jantung dan memberikan ketenangan sebelum minum Jus Thoharah.'),
  (10, 'Saya tidak lakukan terapi bumi sebab matahari tak keluar.',
   'Terapi bumi, pernafasan fitrah dan berjemur cahaya matahari tidak semestinya perlu dilakukan pada waktu yang sama. Anda perlu berjemur cahaya matahari di waktu pagi tetapi terapi bumi dan pernafasan fitrah boleh dilakukan bila-bila masa sahaja. Cuma, terapi bumi perlu dilakukan di kawasan yang ada tanah yang bersih dan tanah yang kena cahaya matahari dan hujan.'),
  (11, 'Bolehkah kami berjemur cahaya matahari selama sejam?',
   'Boleh. Cuma anda perlu pastikan yang anda tidak terhidrasi dan tidak terdedah kepada cahaya matahari berbahaya iaitu cahaya matahari selepas pukul 9 pagi. Disarankan 30 minit sahaja sudah mencukupi.'),
  (12, 'Hari tu saya dapat tahu mandi hujan bagus? Boleh saya tahu kenapa?',
   'Antara kelebihan air hujan: boleh menstabilkan hormon, merawat masalah jangkitan telinga, meningkatkan rembesan hormon endorphin dan serotonin, menyihatkan rambut dan menggalakkan penghasilan vitamin B12. Panduan: di kampung, biarkan hujan turun 10 minit barulah boleh mandi hujan; di bandar, biarkan 15-20 minit. Mandi secara direct dari langit (bukan di bawah bumbung/pokok) dan semasa hujan lebat bukan hujan gerimis.'),
  (13, 'Hakeema minta untuk saya mandi ais, boleh saya tahu frequency untuk mandi ais?',
   'Mandi ais pada suhu 10-15 darjah selsius. Anda boleh berendam selama 10 saat ke atas dan dilakukan minimum seminggu sekali. Jika tidak dapat mandi ais, mandi pada ketika 4-5 pagi di waktu air sangat sejuk sehingga menggigil dan lakukan setiap hari. Lagi banyak anda menggigil lebih bagus untuk memecahkan longgokan toksin dan meningkatkan body frequency.')
) AS q(sort_order, soalan, jawapan)
WHERE s.code = 'E';

-- ─── SECTION F ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_items (section_id, soalan, jawapan, sort_order)
SELECT s.id, q.soalan, q.jawapan, q.sort_order
FROM psy_faq_sections s,
(VALUES
  (1, 'Adakah dengan menghadiri seminar Trillionaire boleh membuatkan saya menjadi jutawan Trillionaire?',
   'Anda dilahirkan sebagai jutawan Trillionaire. DNA dalam setiap sel jasad anda adalah magnet untuk menarik rezeki. Jasad yang sihat dianggarkan mempunyai 100 trillion DNA yang berfungsi sebagai magnet rezeki. Namun, setiap hari anda mengalami susut nilai akibat dari kerosakan DNA, menyebabkan kehidupan anda dilanda pelbagai penyakit, kesukaran dan masalah.'),
  (2, 'Apa yang saya dapat apabila menghadiri Formula Trillionaire?',
   'Program 3 hari ini membuka rahsia fitrah diri anda yang sebenar. Anda akan menyedari betapa pentingnya hidup mengikut Teknologi Fitrah serta hubungannya dengan hukum alam. Anda akan mempelajari cara asas menyembuhkan 100 trillion DNA agar ia kembali berfungsi sebagai magnet menarik rezeki.'),
  (3, 'Bagaimana ingin menjadikan jiwa lapang?',
   'Anda perlu melalui proses memadam memori terpendam yang meracuni jiwa, memadam kepercayaan yang membentuk stres, dan bina kepercayaan baru yang selari dengan Teknologi Fitrah. Fokus kepada membesarkan satelit jiwa bagi pengaliran tenaga hayat. DNA semakin sembuh, sel semakin bercambah sehingga daya tarikan magnet rezeki menjadi semakin kuat.'),
  (4, 'Apa akan jadi kepada diri saya apabila jiwa saya lapang?',
   'Hasilnya, anda dapat menikmati kehidupan dengan jiwa tenang dan bahagia, fikiran luas dan kreatif, jasad menjadi sihat dan aktif serta rezeki melimpah ruah.'),
  (5, 'Bolehkah ia meningkatkan potensi diri?',
   'Ya, boleh! Aliran tenaga hayat berkuasa tinggi dapat membina potensi diri tanpa batasan. Jasad dewasa yang sihat dianggarkan mempunyai 100 trillion sel, terbentuk dari cantuman 100 trillion atom. Setiap atom bersamaan dengan kuasa tenaga nuklear. Tenaga hayat berkuasa tinggi mampu menghidupkan 100 kuasa dua trillion atom di dalam diri anda sehingga membina potensi diri tanpa batasan.')
) AS q(sort_order, soalan, jawapan)
WHERE s.code = 'F';

-- ─── SECTION G ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_items (section_id, soalan, jawapan, sort_order)
SELECT s.id, q.soalan, q.jawapan, q.sort_order
FROM psy_faq_sections s,
(VALUES
  (1, 'Apakah yang akan terjadi jika saya mengalami masalah tenaga hayat dalam jasad?',
   'Roh yang lemah kerana masalah pengaliran tenaga hayat akan mengakibatkan tekanan pada jiwa dan merosakkan rantaian DNA. Kelemahan tenaga hayat akan menyebabkan getaran tenaga kuasa atom sistem enjin jasad melemah sehingga mendorong kepada penyakit kronik. Tenaga hayat ini bersifat dinamik, menembusi, memberi nyawa kepada organ dan jasad. Ia boleh diaktifkan dan dipindahkan daripada seorang individu kepada individu lain oleh perawat yang terlatih.'),
  (2, 'Bagaimanakah Rawatan Tenaga Hayat dapat menyembuhkan penyakit saya?',
   'Tenaga hayat akan meningkatkan getaran tenaga kuasa atom dalam sistem enjin jasad anda. Cantuman atom-atom inilah yang membentuk sel. Apabila getaran tenaga kuasa atom meningkat, gelombang frekuensi sistem enjin jasad meningkat. Individu yang sihat mempunyai gelombang frekuensi yang tinggi — menyebabkan sistem enjin JASAD-JIWA-AKAL-ROH dapat berfungsi mengikut Teknologi Fitrah.'),
  (3, 'Apakah kebaikan air ''Afiah kepada saya?',
   'Air ''Afiah ialah air minuman yang telah dibacakan dengan potongan ayat-ayat suci Al-Quran seperti yang telah diijazahkan oleh Sheikh-Sheikh yang bersanad kepada perawat. Molekul air berubah apabila dibacakan ayat-ayat suci al-Quran. Molekul air yang terbentuk hasil bacaan ayat-ayat suci ini akan meresap ke dalam sel dengan getaran yang bersesuaian untuk pemulihan sel.'),
  (4, 'Bolehkah air ''Afiah diminum oleh seisi keluarga saya?',
   'Ya, air ''Afiah boleh diminum seisi keluarga. Apabila air sudah tinggal sesuku di dalam bekas, tambahkan lagi dengan air mineral (bukan air masak) sehingga penuh dan mencukupi untuk seminggu, kemudian baru ditambahkan dari botol yang baru.'),
  (5, 'Adakah air ''Afiah hanya dibekalkan pada tiga minggu pertama sahaja?',
   'Air afiah akan diberikan setiap 3 minggu sekali iaitu pada minggu ke-3, 6, 9 dan 12.'),
  (6, 'Apakah itu aura negatif?',
   'Aura adalah gelombang elektromagnetik pada frekuensi tertentu yang berlegar di sekitar jasad manusia. Getaran tenaga kuasa atom yang kuat akan meningkatkan frekuensi sistem enjin jasad dan membebaskan gelombang positif — individu yang sihat akan memancarkan aura positif (wajah berseri, bertenaga, nampak sihat). Apabila aura negatif banyak dalam jasad, kita akan menjadi lemah semangat, mudah terkejut, tidak cukup rehat, berasa tertekan dan sering susah hati.'),
  (7, 'Adakah saya boleh membuat Penyucian Aura kepada ahli keluarga yang lain?',
   'Ya, boleh. Tetapi anda dinasihatkan supaya menggunakan dulang tin bakar yang lain.'),
  (8, 'Selepas selesai 40 hari penyucian aura, adakah masih perlu dilakukan lagi?',
   'Selepas selesai 40 hari, anda digalakkan untuk meneruskan lagi melakukan penyucian aura. Tetapi, dengan menggunakan bekalan air a''fiah baru yang akan diberikan setiap 3 minggu sekali di Ibnu Sina Wellness sepanjang rawatan yang anda lakukan.'),
  (9, 'Mengapakah saya perlu mengamalkan zikir-zikir bersanad?',
   'Amalan zikir yang disarankan adalah diijazahkan daripada Sheikh-Sheikh yang bersanad kepada Rasulullah SAW. Zikir merupakan sejenis penyucian yang berasaskan unsur cahaya dan menyumbang kepada tenaga hayat yang diperlukan oleh sel pada jasad. Para pesakit digalakkan mengamalkan amalan-amalan zikir bersanad ini bagi menerima keberkatan dan insyaAllah kesembuhan JASAD-JIWA-AKAL-ROH.'),
  (10, 'Apakah yang perlu saya lakukan jika terlalu sibuk untuk melakukan Zikir Bersanad selepas solat subuh?',
   'Sebaiknya, kita perlu lakukan Zikir Bersanad ini dengan khusyuk sejurus selepas solat subuh di atas tikar sejadah. Tetapi, jika sangat tidak berkesempatan kerana mencari rezeki, boleh sambung untuk menghabiskannya ketika memandu ke tempat kerja ataupun apabila berada di tempat kerja (tidak digalakkan tetapi jika perlu sahaja).'),
  (11, 'Bagaimana amalan sedekah dapat membantu menyembuhkan saya?',
   'Bersedekah tidak akan menyebabkan harta berkurangan — ia dapat memperkayakan hati, membersihkan harta, memanjangkan usia serta melancarkan rezeki. Apabila berada dalam keadaan bersedih, carilah peluang untuk bersedekah. Mudah-mudahan Allah akan mengurniakan kegembiraan pada hati kita yang berdukacita.')
) AS q(sort_order, soalan, jawapan)
WHERE s.code = 'G';

-- ─── SECTION H ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_items (section_id, soalan, jawapan, sort_order)
SELECT s.id, q.soalan, q.jawapan, q.sort_order
FROM psy_faq_sections s,
(VALUES
  (1, 'Apakah kaitan ilmu perubatan Ibnu Sina dengan baik pulih DNA?',
   'Ilmu perubatan Ibnu Sina menerangkan kepentingan keseimbangan dalam jasad bagi membantu merawat penyakit dan menyembuhkan jasad. Kerosakan DNA telah menyebabkan lebih banyak sel mati daripada jumlah sel baharu yang dihasilkan lalu menyebabkan ketidakseimbangan yang merupakan punca kepada penyakit anda.'),
  (2, 'Apakah kaitan kerosakan DNA dengan penyakit saya?',
   'DNA adalah otak kepada sel yang mengawal seluruh aktiviti sel termasuk arahan untuk menghasilkan berjuta-juta sel baharu dan menyingkirkan toksin berbahaya daripada jasad. Gangguan isyarat penghasilan sel baharu oleh DNA akan mengganggu keseimbangan jasad dan menyebabkan penyakit. DNA yang rosak juga boleh menyebabkan terhasilnya sel yang tidak normal seperti sel kanser.'),
  (3, 'Apakah maksud sebenar Terapi Aktivasi Neuron?',
   'Sistem Saraf Enterik di dalam perut mengawal perasaan di dalam jiwa, manakala perasaan di dalam jiwa mempengaruhi isyarat percambahan sel otak. Sel-sel otak memberi signal kepada saraf untuk melaksanakan proses pemulihan daripada penyakit. Dengan kata lain, Aktivasi Neuron dapat merangsang isyarat neuron yang membolehkan sel baru dihasilkan bagi menggantikan sel yang tidak sihat, seterusnya merangsang semula fungsi sistem imun untuk berfungsi secara normal.'),
  (4, 'Apakah kaitan penyakit saya dengan Penyucian Jiwa?',
   'Longgokan memori beracun dan sistem kepercayaan FIGHT FITRAH menyebabkan anda mengamalkan tabiat pemakanan dan gaya hidup yang FIGHT FITRAH sehingga menjemput penyakit kronik. Penyucian jiwa penting agar boleh memecahkan longgokan memori beracun dan mengalignkan semula sistem kepercayaan anda agar FOLLOW FITRAH.'),
  (5, 'Bagaimana Penyucian Jiwa dapat membantu merawat penyakit saya?',
   'Penyucian Jiwa merupakan proses di mana memori beracun yang terpendam dan sistem kepercayaan FIGHT FITRAH yang meracuni jiwa akan dihapuskan hingga ke akar umbi melalui amalan-amalan yang telah disarankan. Rawatan Overhaul Body dapat menyelaraskan semula kepercayaan FOLLOW FITRAH dan membantu merawat penyakit anda daripada jiwa yang sihat.'),
  (6, 'Kenapa penting untuk mengamalkan 5 formula Overhaul Body kepada sistem jasad?',
   '5 formula Overhaul Body hanya dapat dicapai melalui 4 sistem perubatan dalam Rawatan Overhaul Body. Barulah dapat mengaktifkan semula sistem enjin JASAD-JIWA-AKAL-ROH anda agar kembali berfungsi secara optimum mengikut Teknologi Fitrah.')
) AS q(sort_order, soalan, jawapan)
WHERE s.code = 'H';

-- ─── SECTION I ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_items (section_id, soalan, jawapan, sort_order)
SELECT s.id, q.soalan, q.jawapan, q.sort_order
FROM psy_faq_sections s,
(VALUES
  (1,  'Adakah gejala muntah-muntah dan cirit-birit yang saya alami ketika menjalani Overhaul Body merupakan perkara yang normal?',
   'Pembebasan toksin beracun ke dalam darah sebelum ia keluar melalui sistem perkumuhan mungkin menyebabkan reaksi pemulihan seperti muntah-muntah, cirit-birit, pening dan keletihan. Reaksi-reaksi pemulihan ini adalah tindak balas positif yang menunjukkan sistem semulajadi dalaman sedang berfungsi semula untuk mengepam keluar racun dari sistem enjin jasad.'),
  (2,  'Apakah bentuk toksin yang keluar apabila saya meminum Jus Thoharah?',
   'Longgokan toksin berbahaya yang dipam keluar adalah seperti: karbon dioksida, asid, kalsifikasi (calcification), cacing, candida, kolestrol, batu karang, darah beku, ketulan darah, kahak atau lendir yang berwarna putih/kuning/hijau/coklat, darah beku yang dicairkan, sista (cyst) dan fibroid. Bergantung kepada penyakit yang anda alami.'),
  (3,  'Jika reaksi pemulihan ini menyakitkan, adakah dibenarkan untuk makan ubat tahan sakit?',
   'Tidak digalakkan kerana ubat tahan sakit akan menghalang fungsi penghapusan semulajadi berlaku dengan sempurna, menyebabkan sel-tisu-organ-tulang-otot tidak dapat dibersihkan dengan betul. Anda boleh kurangkan rasa sakit dengan melakukan pernafasan fitrah, terapi bumi dan minum madu. Tetapi, sekiranya betul-betul tidak tahan, boleh ambil ubat tahan sakit.'),
  (4,  'Kenapa tekanan darah saya semakin tinggi?',
   'Tekanan darah yang tidak stabil semasa proses pemulihan terjadi kerana sistem enjin jasad sedang lembut-kembang-pecah longgokan toksin dengan intensif. Longgokan toksin yang lembut dan kembang ini menyebabkan salur darah menjadi sempit atau darah menjadi pekat dan berasid sehingga jantung terpaksa bekerja keras. Anda tidak perlu risau kerana reaksi pemulihan ini hanya bersifat sementara.'),
  (5,  'Kenapa bacaan kencing manis meningkat?',
   'Bacaan kencing manis meningkat disebabkan dua perkara: (1) Pengambilan madu menyebabkan pengumpulan glukosa dalam salur darah — sel pankreas masih "tidur" di awal rawatan dan tidak berupaya menghasilkan insulin secukupnya. (2) Insulin reseptor sel jasad tidak sensitif terhadap kehadiran insulin. Tabiat pemakanan FOLLOW FITRAH sepanjang rawatan akan membantu meningkatkan sensitivity insulin reseptor sel jasad. Jangan berhenti minum madu kerana madu yang anda minum inilah yang akan membantu mengaktifkan semula pankreas.'),
  (6,  'Adakah normal sekiranya saya kerap membuang angin?',
   'Ya, itu adalah reaksi pemulihan iaitu jasad akan kerap membuang angin dalam bentuk kentut dan sendawa. Angin merupakan salah satu bentuk toksin yang ada dalam sistem enjin jasad anda.'),
  (7,  'Adakah normal sekiranya haid saya terlalu banyak pendarahan?',
   'Ya, itu adalah reaksi pemulihan. Mereka yang mengalami masalah berkaitan Rahim, payudara dan hormon sahaja yang selalunya akan mengalami reaksi pemulihan ini. Darah haid yang keluar merupakan darah yang terkumpul lama dalam Rahim. Tetapi, jika pendarahan terlalu banyak anda digalakkan untuk mendapatkan khidmat nasihat dari doktor.'),
  (8,  'Adakah normal sekiranya haid saya terlewat?',
   'Ya, itu adalah reaksi pemulihan. Kelewatan haid berlaku apabila hormon anda sudah "reset" kembali pada normal dan menyebabkan kitaran haid mula berubah pada normal. Anda tidak perlu panik dan hanya perlu memantau kitaran haid anda.'),
  (9,  'Kenapa saya kerap cirit-birit?',
   'Cirit-birit ialah reaksi jasad untuk mengikis racun secara semulajadi. Usus besar menjadi aktif melakukan aktiviti peristalsis untuk mengepam keluar toksin dalam bentuk najis. Juga boleh berlaku akibat daripada perubahan tabiat pemakanan kepada banyak sayur-sayuran dan buah-buahan. Jika cirit-birit terlalu kronik tingkatkan pengambilan air kelapa lebih dari sebiji sehari ataupun ke klinik berdekatan untuk drip.'),
  (10, 'Adakah normal sekiranya jasad saya keluar banyak bisul?',
   'Ya, itu adalah reaksi pemulihan iaitu toksin akan cuba dipam keluar menerusi kulit. Anda perlu minum air kelapa sebiji sehari untuk mengelakkan longgokan toksin "parking" terlalu lama dalam darah anda. Selain itu, anda juga boleh melakukan sauna untuk membantu peluh yang mengandungi toksin dipam keluar.'),
  (11, 'Adakah normal sekiranya jasad saya gatal-gatal?',
   'Ya, itu adalah reaksi pemulihan. Gatal-gatal berlaku kerana darah sedang kotor dan dipenuhi longgokan toksin yang sudah berjaya dilembut-kembang dan "parking" dalam salur darah terlalu lama. Minum air kelapa sebiji sehari dan boleh lakukan sauna untuk membantu peluh yang mengandungi toksin dipam keluar.'),
  (12, 'Adakah normal sekiranya kulit saya mengelupas?',
   'Ya, itu adalah reaksi pemulihan. Rawatan Overhaul Body fokus menggugurkan kesemua sel-sel lama yang rosak dan mati. Kulit menggelupas untuk menyingkirkan sel-sel mati yang ada dalam sistem enjin jasad. Kemudian, sel-sel mati ini akan digantikan dengan berjuta-juta sel baru yang sihat. Untuk mempercepatkan proses ini, anda boleh gunakan pelembap atau losyen dan sapukan pada kawasan mengelupas.'),
  (13, 'Kenapa saya selalu demam?',
   'Demam menambahkan kadar metabolik, pengaliran darah dan pembesaran limfa — ini mempercepatkan pembuangan toksin. Demam juga mewujudkan satu alam sekitar dalaman yang bertindak mematikan kuman dan virus. Jika setelah sekian lama anda tidak demam tetapi anda demam semasa rawatan Overhaul Body, itu ialah demam yang bagus — ia akan melebarkan salur darah yang menyempit, meningkatkan pengaliran darah dan meningkatkan sistem imun.'),
  (14, 'Adakah normal sekiranya jasad saya menjadi bengkak-bengkak?',
   'Ya, itu adalah reaksi pemulihan iaitu bengkak dan edema (pengumpulan cecair) akibat daripada tindakan jasad yang melawan masalah di sesuatu tempat. Cara untuk mengurangkan bengkak-bengkak ini ialah dengan perbanyakkan berjalan kaki, berjemur cahaya matahari, memijak batu sungai yang dipanaskan dan bersauna.'),
  (15, 'Adakah normal sekiranya hidung saya asyik berhingus?',
   'Ya, itu adalah reaksi pemulihan kerana mukus ialah satu jenis toksin yang dibuang dari jasad. Rawatan Overhaul Body membuka rongga-rongga dalam sistem enjin jasad dan menyebabkan air/mucus yang selama ini tersumbat berjaya dipam keluar.'),
  (16, 'Adakah normal sekiranya saya kerap batuk?',
   'Ya, itu adalah reaksi pemulihan. Batuk ialah cara untuk paru-paru membersihkan saluran pernafasan daripada bahan longgokan toksin yang sudah lembut dan kembang. Jika batuk semakin berterusan anda digalakkan untuk minum air asam jawa yang dicampurkan dengan madu manis EOL/LTH.'),
  (17, 'Apakah yang perlu saya buat jika mengalami muntah yang berterusan?',
   'Selepas muntah, anda harus meminum air yang bercampur garam disusuli dengan 1 sudu besar Lote Tree Honey dan teruskan meminum LTH bercampur dengan 20ml pati kunyit dan 20ml air asam jawa sejam sekali. Jika keadaan semakin melarat, sila dapatkan rawatan kecemasan atau lakukan IV Saline Drip.'),
  (18, 'Apakah yang perlu saya buat jika jasad menjadi sangat lemah?',
   'Anda harus meminum air yang bercampur garam dan 1 sudu besar Lote Tree Honey sejam sekali. Sekiranya jasad berasa semakin lemah selepas 24 jam, segera mendapatkan rawatan di hospital. Anda boleh juga melakukan pernafasan fitrah selama 15-30 minit dalam keadaaan tenang dan tanpa gangguan.'),
  (19, 'Apakah yang perlu saya buat jika hilang selera makan?',
   'Jika anda tidak makan, tekanan darah akan menjadi rendah dan jasad akan kurang tenaga untuk menghadapi proses pemulihan. Ini dapat diatasi dengan meminum air bercampur garam bukit dan 1 sudu besar Lote Tree Honey 10 kali sehari.'),
  (20, 'Apakah yang perlu saya lakukan jika kepekatan haemoglobin (HB) rendah?',
   'Sekiranya HB rendah, minum 1 sudu besar Lote Tree Honey yang bercampur 20ml pati kunyit dan 20ml air asam jawa dan segera ke hospital untuk tindakan selanjutnya. Tingkatkan pengambilan Jus Beetroot kerana terbukti boleh meningkatkan kepekatan sel darah merah. Amalkan satu gelas sehari untuk kesan yang optimum.'),
  (21, 'Apakah yang perlu saya lakukan jika keluar gatal-gatal pada kulit?',
   'Sapu mendakan kunyit bercampur madu pada bahagian tersebut dan biarkan selama 30 minit. Kemudian cuci sehingga bersih. Anda boleh melakukan pernafasan fitrah untuk mengurangkan rasa gatal-gatal.'),
  (22, 'Apakah yang perlu saya lakukan jika kulit saya jadi kering dan mengelupas?',
   'Sapu santan, minyak kelapa atau aloe vera pada bahagian tersebut.'),
  (23, 'Apakah yang perlu saya lakukan jika perut saya sakit dan berasa ketat?',
   'Makan yogurt atau pil probiotik. Elakkan makan makanan sejuk atau pedas. Perbanyakkan makan makanan suam, tidak pedas dan senang dihadam. Lakukan pernafasan fitrah selama 30 minit sehari.'),
  (24, 'Apakah yang perlu saya lakukan jika mengalami lelah dan kesukaran bernafas?',
   'Minum 1 sudu besar Lote Tree Honey yang bercampur 20ml pati kunyit dan 20ml air asam jawa dan segera ke hospital untuk mendapatkan gas nebulizer. Juga bawa bersama anda LTH dan sambung pengambilan sejam sekali. Anda boleh juga menghilangkan lelah dengan melakukan pernafasan fitrah.'),
  (25, 'Jika saya mengalami pening kepala yang teruk, adakah saya dibolehkan untuk makan panadol?',
   'Anda tidak digalakkan untuk makan Panadol bagi mengurangkan sakit kepala kerana ia akan mengganggu reaksi pemulihan. Saranan terbaik ialah dengan melakukan pernafasan fitrah 15-30 minit tanpa sebarang gangguan, minum air masak secukupnya, dapat tidur dan rehat yang secukupnya serta minum air afiah yang diberikan.'),
  (26, 'Kenapa bacaan sel kanser dalam darah saya tidak menurun sedangkan saya telah menjalani rawatan Overhaul Body?',
   'Bacaan sel kanser tidak menurun dalam tempoh sekelip mata kerana rawatan Overhaul Body ini TANPA KIMIA-TANPA BEDAH-TANPA RADIASI yang memerlukan anda untuk konsisten sepanjang perjalanan untuk Sihat. Ia akan memakan masa beberapa bulan atau tahun tetapi ia akan menghapuskan akar umbi punca kanser. Ramai pesakit dah berjaya bebas kanser melalui Rawatan Overhaul Body ini.'),
  (27, 'Kenapa berat badan saya makin susut?',
   'Ini menunjukkan jasad anda sudah dapat berfungsi secara optimum mengikut Teknologi Fitrah. Berat badan susut kepada berat ideal kerana metabolisma jasad sudah meningkat dan longgokan toksin terkumpul dalam jasad sudah/sedang dipam keluar. Ini juga mengurangkan risiko pengumpulan lemak dalam jasad dan mengatasi masalah rintangan insulin.'),
  (28, 'Saya mengalami kesukaran untuk tidur. Apa perlu saya buat?',
   'Makan makanan yang tinggi dengan tryptophan seperti yogurt, kekacang dan sebagainya yang boleh menghasilkan hormon serotonin untuk merangsang rasa mengantuk. Juga, anda boleh melakukan pernafasan fitrah bagi menimbulkan rasa tenang dan menyebabkan rasa mengantuk muncul.')
) AS q(sort_order, soalan, jawapan)
WHERE s.code = 'I';

-- ─── SECTION J ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_items (section_id, soalan, jawapan, sort_order)
SELECT s.id, q.soalan, q.jawapan, q.sort_order
FROM psy_faq_sections s,
(VALUES
  (1, 'Apakah yang akan terjadi jika saya tidak dapat menghadiri rawatan susulan?',
   'Jika tidak menghadiri rawatan susulan, baki toksin sebanyak 20% hingga 50% yang tertinggal di dalam jasad kita tidak akan dapat dipam keluar. Mengikut ilmu Ibnu Sina, punca penyakit adalah toksin (racun) yang terkumpul di dalam jasad. Jika ia tidak dikeluarkan sepenuhnya, dikhuatiri penyakit boleh datang semula.'),
  (2, 'Saya rasa jasad dah sihat tetapi bimbang jika penyakit saya masih belum hilang sepenuhnya.',
   'Pada masa sekarang, toksin yang sudah keluar adalah dalam 50 hingga 80%. Jadi, sel baru sudah mula boleh bercambah. Semasa datang semula untuk rawatan susulan bulanan nanti, lebihan toksin yang tinggal akan mula keluar dan lebih banyak sel baharu dapat bercambah. Apabila sel sihat yang baharu semakin banyak, insyaAllah sel yang rosak akan berkurangan dan penyakit akan hilang dari jasad.'),
  (3, 'Adakah penyakit saya telah sembuh sepenuhnya kerana berasa lebih sihat dan bertenaga?',
   'Pada masa sekarang, toksin yang sudah keluar adalah dalam 50 hingga 80%. Jadi, sel baru sudah mula boleh bercambah. Semasa datang semula untuk rawatan susulan bulanan nanti, lebihan toksin yang tinggal akan mula keluar. Apabila sel sihat yang baharu semakin banyak, insyaAllah sel yang rosak akan berkurangan dan penyakit akan hilang dari jasad.')
) AS q(sort_order, soalan, jawapan)
WHERE s.code = 'J';

-- ─── SECTION K ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_items (section_id, soalan, jawapan, sort_order)
SELECT s.id, q.soalan, q.jawapan, q.sort_order
FROM psy_faq_sections s,
(VALUES
  (1, 'Apa beza rawatan Overhaul Body Fasa 2 dan Fasa 3?',
   'Fasa 2 fokusnya ialah untuk mengepam keluar longgokan toksin dari lapisan dalam sel jasad — melibatkan tempoh rawatan 3 bulan (minum Jus Thoharah sebulan sekali selama 3 bulan). Fasa 3 fokusnya ialah untuk meningkatkan resapan nutrisi dalam jasad dan menggalakkan percambahan berjuta-juta sel baru yang sihat — melibatkan tempoh rawatan 9 bulan (minum Jus Thoharah 3 bulan sekali selama 9 bulan). Namun, fokus rawatan Fasa 2 dan Fasa 3 ini ialah untuk mengepam keluar anggaran 70% longgokan toksin di dalam jasad.')
) AS q(sort_order, soalan, jawapan)
WHERE s.code = 'K';

-- ─── SECTION L ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_items (section_id, soalan, jawapan, sort_order)
SELECT s.id, q.soalan, q.jawapan, q.sort_order
FROM psy_faq_sections s,
(VALUES
  (1,  'Kenapa saya perlu berpantang?',
   'Perlu pantang supaya perut tidak berat menggunakan tenaga untuk menghadam makanan yang kompleks seperti makanan berproses, protein haiwan dsb. Apabila berpantang, tenaga yang ada digunakan untuk proses pam keluar toksin dan proses pemulihan jasad. Pengambilan makanan yang bertoksin pada ketika ini boleh menggagalkan proses tersebut.'),
  (2,  'Kenapa perlu pemakanan yang sihat?',
   'Manusia makan untuk mendapatkan nutrisi yang diperlukan oleh 100 trillion sel di dalam jasad. Jasad yang bersih hanya akan berasa lapar apabila sel meminta nutrisi. Setiap sel menghantar isyarat keperluan nutrisi dalam bentuk "rasa lapar" untuk meminta makanan yang diperlukan untuk proses baik pulih dan percambahan.'),
  (3,  'Berapa lama saya perlu berpantang dari memakan ikan, ayam dan daging?',
   'Pesakit kronik harus berpantang dari memakan protein haiwan selama 1 hingga 3 tahun. Ini penting bagi mengelakkan proses baik pulih jasad anda daripada penyakit yang sedang anda hidapi sekarang ini.'),
  (4,  'Kenapa perlu berpantang dari memakan protein haiwan selama 1 hingga 3 tahun?',
   'Tiga sebab: (1) Protein haiwan merupakan makanan yang tidak bersifat prebiotic dan probiotic — tidak menyumbang kepada keseimbangan mikrobiota perut. (2) Protein haiwan ialah protein kompleks yang susah dihadamkan — menyebabkan peningkatan penghasilan radikal bebas yang menyerang sel-sel sihat. (3) Protein haiwan akan menyebabkan pengumpulan intramuscular fat pada reseptor insulin sel jasad dan mendorong kepada rintangan insulin. Selain itu, sumber protein haiwan hari ini banyak tercemar dengan toksin seperti bahan kimia, hormon tumbesaran dan logam berat.'),
  (5,  'Bagaimanakah keperluan protein jasad selama 1-3 tahun dapat dipenuhi tanpa pengambilan ikan, ayam dan daging?',
   'Protein juga boleh diperolehi dengan memakan tumbuh-tumbuhan, sayur-sayuran, kekacang dan buah-buahan tempatan yang segar. Kajian menunjukkan protein daripada sumber bukan haiwan lebih sihat untuk dimakan. Contoh: Greek Yogurt 6 auns = 20g protein, kacang kuda secawan = 15g protein, beras perang = 5g protein.'),
  (6,  'Kenapa hanya dibenarkan pengambilan sayur-sayuran dan buah-buahan tempatan?',
   'Buah-buahan import adalah tidak segar, ditanam menggunakan hormon tumbesaran, racun kimia, dan bahan pelindung. Pesakit digalakkan mengambil makanan segar yang mengandungi tenaga hayat bagi menyokong proses baik pulih sel.'),
  (7,  'Mengapa perlu minum air kelapa setiap hari?',
   'Air kelapa membantu mempercepat proses rawatan Overhaul Body. Air kelapa mengandungi elektrolit, vitamin dan mineral serta membantu hidrat semula jasad. Air kelapa perlu diambil sebiji sehari untuk mengurangkan reaksi pemulihan yang dialami selepas minum Jus Thoharah. Jika reaksi pemulihan terlalu ekstrem, anda boleh minum 2 biji kelapa pada hari itu sahaja.'),
  (8,  'Ada tak pesakit yang tak digalakkan minum air kelapa?',
   'Bagi pesakit yang menghidapi masalah kegagalan buah pinggang tahap 4 dan tahap 5, anda tidak digalakkan minum air kelapa terlalu banyak (dikhuatiri "water retention" meningkat) — boleh minum 1 cawan sahaja sehari. Bagi pesakit masalah jantung, tidak digalakkan minum jus beetroot kerana ia akan meningkatkan bilangan sel darah merah, menjadikan darah semakin pekat. Dalam apa jua keadaan, anda tetap perlu minum madu 10 sudu sehari dan minum jus thoharah sepanjang tempoh rawatan.'),
  (9,  'Adakah boleh jika saya makan ikan dengan kadar yang sedikit?',
   'Untuk memastikan jasad anda betul-betul sihat, anda perlu berpantang dari memakan protein haiwan dan juga makanan proses sekurang-kurangnya setahun agar jasad anda mudah untuk mencambahkan sel-sel baharu serta tiada penambahan toksin yang banyak.'),
  (10, 'Adakah pengambilan air alkali dibolehkan dalam rawatan ini?',
   'Tidak boleh kerana air alkali akan mengganggu pH darah dalam jasad anda. Jasad yang sihat akan mempunyai pH yang normal. Anda perlu bertukar kepada pengambilan air afiah atau air ozon untuk jasad yang sihat.'),
  (11, 'Apakah kesan makan protein haiwan semasa dalam tempoh berpantang?',
   'Mengganggu proses pemulihan anda kerana pengambilan protein haiwan semasa tempoh rawatan akan menyebabkan keseimbangan mikrobiota perut terganggu, peningkatan tekanan oksidatif dalam jasad dan pengumpulan intramuscular fat pada reseptor insulin sel — menyebabkan masalah rintangan insulin tidak dapat diatasi. Masalah rintangan insulin inilah yang merupakan punca penyakit kronik berlaku.'),
  (12, 'Adakah pengambilan susu dan oat pada waktu pagi dibenarkan?',
   'Susu daripada sumber haiwan yang dijual di pasaran kebiasaannya mengandungi pengawet dan bahan kimia lain. Jika anda teringin untuk minum susu, anda boleh minum susu badam atau soya yang dihasilkan sendiri. Susu daripada sumber haiwan sesetengahnya mengandungi hormon yang boleh mengganggu keseimbangan hormon dalam jasad.'),
  (13, 'Adakah kacang tanah boleh dimakan?',
   'Kacang yang boleh dimakan adalah kacang yang apabila diletakkan di atas tisu basah ia tidak bercambah dengan cepat seperti kacang kuda dan kacang dal. Kacang tanah dan kacang hijau adalah jenis yang cepat bercambah dan bersifat sejuk — perlu dipantang oleh pesakit.'),
  (14, 'Adakah kuah ayam dibenarkan bagi menaikkan selera makan?',
   'Kuah ayam telah meresap zat dan lemak dari ayam tersebut. Untuk menaikkan selera, gunakan rencah dan penyedap rasa dari bahan-bahan asli seperti herba dan rempah.'),
  (15, 'Adakah buah-buahan tempatan boleh dimakan pada musim buah tersebut?',
   'Bergantung kepada kondisi kesihatan pesakit. Buah durian bagus untuk mereka yang mengalami masalah buah pinggang tapi tidak bagus untuk orang yang ada darah tinggi. Manggis, langsat dan rambutan boleh dimakan untuk semua penyakit tetapi dalam kuantiti yang bersesuaian. Jangan terlalu banyak sehingga memudaratkan.'),
  (16, 'Saya kena makan yoghurt juga ke? Saya risau nak makan masam sebab saya ada gastrik.',
   'Mereka yang menghidapi gastrik lebih sesuai makan yogurt. Yogurt penting kerana ia boleh seimbangkan mikrobiota perut dan sistem gastrousus yang merupakan faktor yang menyebabkan gastrik berlaku. Tanpa yogurt yang bersifat probiotik, serat yang anda makan dari sayur-sayuran tidak dapat diproses dengan baik oleh jasad.'),
  (17, 'Kalau pesakit minum air kelapa selepas minum jus thoharah tapi ada rasa kejang?',
   'Minum air kelapa sejam atau dua jam selepas minum Jus Thoharah. Pastikan minum dalam isipadu yang sedikit, jangan habiskan satu biji kelapa dalam waktu yang singkat. Air kelapa perlu dibiarkan pada suhu bilik sekurang-kurangnya 30 minit sebelum minum. Juga, air kelapa perlu diminum sebelum malam kerana ketika malam hari suhu jasad sudah menurun.')
) AS q(sort_order, soalan, jawapan)
WHERE s.code = 'L';

-- ─── SECTION M ────────────────────────────────────────────────────────────────

INSERT INTO psy_faq_items (section_id, soalan, jawapan, sort_order)
SELECT s.id, q.soalan, q.jawapan, q.sort_order
FROM psy_faq_sections s,
(VALUES
  (1, 'Kenapa progress penyakit saya perlu dilakukan dalam bentuk video? Saya tidak mahu ia direkod dalam bentuk video.',
   'Kami merekod progress pesakit dengan menggunakan video bertujuan untuk melihat progress awal, pertengahan dan di hujung rawatan. Jika laporan hanya bertulis tanpa video, perkembangan tidak dapat dilihat dengan baik. Jangan risau — pihak Ibnu Sina Wellness merekod progress anda untuk diberikan kepada anda di penghujung rawatan agar anda nampak apakah transformasi yang anda sudah berjaya lalui.'),
  (2, 'Mengapa video saya disiarkan ke media sosial? Saya tidak mahu video saya disiarkan ke media sosial.',
   'Tujuan kami siarkan video anda ke media sosial adalah untuk membantu memberikan inspirasi kepada lebih ramai orang yang menderita penyakit kronik agar mereka tahu bahawa sentiasa ada peluang untuk sembuh. Melalui video anda, anda juga dapat menyumbang dan membantu masyarakat di mana ia merupakan sedekah yang sangat besar. Pihak Ibnu Sina Wellness menghormati keputusan anda jika tidak mahu — tetapi anda perlu tetap melakukan rakaman progress sepanjang rawatan untuk tontonan peribadi anda.'),
  (3, 'Mengapa harus direkod jika saya tidak mempunyai sebarang progress sepanjang menjalani rawatan?',
   'Tidak mengapa. Walaupun tiada progress di awal rawatan, ia masih perlu direkod supaya perbandingan dapat dilakukan di hujung rawatan nanti. Mungkin pesakit tidak menyedari progress yang terjadi secara berperingkat — kerana itulah pentingnya untuk merekod progress dalam bentuk video agar perbandingan dapat dilakukan dengan jelas.')
) AS q(sort_order, soalan, jawapan)
WHERE s.code = 'M';
