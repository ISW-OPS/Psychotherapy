# 🎤 Skrip Pembentangan (Baca-Terus) — ISW System
> Untuk: **2 Julai 2026** · Audience: Management & Manager · Demo di pangkalan **TESTING** · ~15 min + Q&A
>
> **Cara guna:** Ayat dalam *italic* = baca terus / sebut macam tu. Teks dalam **[kurungan tebal]** = arahan klik untuk anda, JANGAN baca. Jeda sekejap di setiap "—" untuk audience cerna.

---

## 🔑 Sebelum Mula (semak 2 minit awal)
- Login semua 6 role sekali untuk "panaskan" — pastikan tiada blank page.
- Buka 6 tab browser ikut urutan babak (Admin → Doctor → Coach → Manager → Super Admin → Pesakit).
- Zoom browser **110–125%**.
- Buka `Flow_Mega_All_Roles.drawio` dalam satu tab sebagai "peta sistem".
- Angka penting di hujung lidah: **120 pesakit · 82 aktif · 117 pelan · 151 sesi · 0 ralat data**.

---

## ▶️ PEMBUKAAN — ~1 min
**[Berdiri, senyum, pandang audience. Belum kongsi skrin lagi.]**

> *"Assalamualaikum dan selamat pagi. Terima kasih kerana luangkan masa. Hari ini saya nak tunjukkan sistem ISW — satu platform yang menguruskan keseluruhan perjalanan pesakit klinik kita, dari saat pesakit mendaftar, sampailah ke laporan untuk pihak pengurusan."*

> *"Sistem ini ada enam jenis pengguna — Super Admin, Admin, Doktor, Coach, Manager, dan Pesakit. Daripada cuba tunjuk setiap skrin satu-satu, saya akan bawa kita ikut SATU perjalanan sebenar seorang pesakit — supaya nampak macam mana semua peranan ini bersambung."*

**[Kongsi skrin → buka tab flowchart `Flow_Mega_All_Roles.drawio`.]**

> *"Ini peta keseluruhan sistem. Setiap kotak ni satu peranan. Apa yang anda nampak ni semuanya data hidup dalam pangkalan ujian kita — seratus dua puluh pesakit, lapan puluh dua sedang dalam rawatan, dan sifar ralat data."*

> *"Jom kita mula dari permulaan — bila pesakit baru masuk."*

---

## 🟦 BABAK 1 — ADMIN: Daftar & KYC pesakit — ~3 min
**[Tukar ke tab Admin → buka `patients.html`.]**

> *"Ini skrin Admin. Di sinilah admin nampak semua pesakit dalam satu senarai. Boleh tapis ikut status — aktif, tunggu kelulusan, tamat rawatan, atau berhenti. Jadi admin tak payah selak fail atau buka banyak excel."*

**[Klik butang + Tambah Pesakit.]**

> *"Bila nak daftar pesakit baru, ada tiga jenis — pesakit betul-betul baru, pesakit yang sedang dalam rawatan, dan pesakit lama. Dan ini bahagian yang penting —"*

> *"— bila admin daftar seorang pesakit sebagai 'sedang rawatan', sistem AUTOMATIK cipta pelan rawatan dia, dan terus jana jadual mingguan. Tak perlu buat manual satu-satu. Ini jimat masa, dan kurangkan silap taip."*

**[Tutup modal → buka KYC: `kyc-list.html` → klik satu → `kyc-review.html`.]**

> *"Setiap pesakit baru pula kena lulus KYC dulu — pengesahan identiti. Staff semak dokumen di sini, kemudian luluskan. Selagi KYC belum lulus, pesakit TAK boleh guna sistem penuh — dia hanya nampak halaman profil dan KYC sahaja. Ini kawalan keselamatan supaya tiada orang yang belum disahkan terus masuk."*

> *"Okay — pesakit dah didaftar dan dah lulus KYC. Langkah seterusnya, dia jumpa doktor."*

---

## 🟩 BABAK 2 — DOCTOR: Sesi KOB — ~2 min
**[Tukar ke tab Doctor → buka `kob-list.html`.]**

> *"Ini sisi Doktor. KOB ialah sesi penilaian awal — Konsultasi, Observasi, dan Bimbingan. Doktor nampak semua sesi di sini, ditapis ikut Hari Ini, Akan Datang, sedang Berlangsung, dan Selesai."*

**[Klik satu sesi → `kob-detail.html`.]**

> *"Dalam satu sesi, doktor tanda kehadiran, isi soal selidik, rekod vitals seperti tekanan darah, tulis nota klinikal yang sulit — dan cadangkan pakej rawatan yang sesuai untuk pesakit ni."*

**[Tunjuk butang Tanda Selesai — TAK perlu klik betul-betul.]**

> *"Bila doktor tekan 'Tanda Selesai', sistem automatik bina pelan rawatan untuk dua belas hingga lapan belas minggu. Jadi terus ada struktur — coach tahu apa nak buat setiap minggu, tanpa tunggu arahan berasingan."*

> *"Sekarang pesakit dah ada pelan. Setiap minggu, dia akan berurusan dengan coach. Ini bahagian yang paling banyak digunakan setiap hari."*

---

## ⭐ BABAK 3 — COACH: Bimbingan mingguan — ~3 min (PALING PENTING)
**[Tukar ke tab Coach (Aqilah) → Dashboard.]**

> *"Ini Dashboard Coach. Sebaik login, coach terus nampak caseload dia — semua pesakit di bawah jagaan dia. Dia nampak peratus check-in tujuh hari, dan yang penting — siapa antara pesakit yang kepatuhan rendah, supaya boleh follow-up segera."*

**[Buka `patient-hub.html` — tunjuk 7 tab.]**

> *"Bila klik seorang pesakit, semua maklumat dia ada dalam satu tempat — tujuh tab: gambaran keseluruhan, check-in harian, vitals, sesi, bekalan, laporan, dan profil. Coach tak payah cari merata."*

**[Klik kad minggu → `plan-week.html`.]**

> *"Untuk setiap minggu, coach isi status kehadiran, skor, nota, dan tahap kepatuhan pesakit. Dan bila dia tanda pesakit 'Hadir' —"*

**[Tunjuk medan Status/Skor/Nota.]**

> *"— stok bekalan yang diberi pada pesakit tu automatik tolak dari inventori. Semua tersimpan sendiri, tak payah save berasingan."*

**[Buka Catatan Harian / Kepatuhan — tunjuk heatmap.]**

> *"Dan inilah bahagian kepatuhan. Pesakit isi catatan harian — amalan harian, mood, tenaga, tidur. Sistem auto-kira skor A, B, atau C. Coach nampak dalam bentuk heatmap macam ni — sekali pandang terus tahu siapa konsisten, siapa makin tercicir. Semua boleh export ke Excel atau PDF."*

> *"Itu rutin harian. Sekarang mari kita naik satu tingkat — ke pihak pengurusan operasi."*

---

## ⭐ BABAK 4 — MANAGER: Operasi & Laporan — ~3 min (UNTUK MANAGER)
**[Tukar ke tab Manager → Dashboard.]**

> *"Ini Dashboard Manager. Sebaik buka, manager nampak gambaran keseluruhan operasi — berapa pesakit aktif, sesi yang tertunggak, stok yang dah rendah, dan pesanan yang menunggu tindakan. Tak payah tanya staff satu-satu."*

**[Buka `inventory.html` → tab Requests → tunjuk satu Approve.]**

> *"Contoh kerja harian manager — kelulusan stok. Bila staff mohon bekalan, ia masuk sini. Manager luluskan, dan bila barang dah dibeli, stok automatik naik dalam sistem."*

**[Buka `orders.html` → tunjuk status Packed → Shipped.]**

> *"Untuk pesanan produk pula — manager boleh jejak dari pending, ke dibayar, dibungkus, dihantar, sampai diterima, lengkap dengan nombor tracking."*

**[Buka Closures / tetapan cuti klinik.]**

> *"Manager juga boleh tetapkan cuti klinik. Bila tarikh dikunci, sistem automatik blok tempahan pada hari tu — jadi tiada pesakit boleh book masa klinik tutup."*

**[Buka laporan: governance / staff-stats / pakej-laporan → tunjuk butang Export.]**

> *"Dan ini yang pengurusan paling perlu — laporan. Prestasi staff, governance, bayaran pakej — semua boleh export terus ke Excel atau PDF, sedia untuk dibawa ke mesyuarat. Tak payah susun manual."*

> *"Akhir sekali, di belakang semua ni ada lapisan kawalan."*

---

## 🟪 BABAK 5 — SUPER ADMIN: Kawalan & Keselamatan — ~1 min
**[Tukar ke tab Super Admin → `staff_management.html`.]**

> *"Super Admin uruskan staff — tambah staff baru, hantar jemputan melalui email, dan tetapkan peranan masing-masing."*

**[Buka `peranan.html` (RBAC).]**

> *"Dan di sini — kawalan capaian ikut peranan. Kita boleh tentukan dengan tepat siapa boleh buat apa, ikut setiap modul. Setiap tindakan penting pula direkod dalam audit log — jadi ada jejak penuh, sesuai untuk pematuhan dan keselamatan data pesakit."*

---

## ⏹️ PENUTUP — ~2 min
**[Berhenti kongsi skrin ATAU kekal di flowchart. Pandang audience.]**

> *"Itulah aliran penuh sistem ISW — satu platform, enam peranan, semuanya bersambung. Dari pesakit daftar, doktor nilai, coach bimbing setiap minggu, manager urus operasi dan laporan, sampai Super Admin kawal keselamatan."*

> *"Izinkan saya ringkaskan kedudukan sekarang —"*

> *"Yang DAH SIAP dan boleh guna hari ini: pendaftaran dan KYC, sesi KOB, pelan rawatan dan caseload coach, catatan harian dan kepatuhan, vitals, inventori, order produk, surat, library, laporan dengan export, serta RBAC dan audit log."*

> *"Yang SEDANG dibuat: payment gateway sebenar — antara muka dan rekod dah siap, cuma proses bayaran masih simulasi sementara kita pilih penyedia. Dan automasi WhatsApp — rangka dah siap, peringatan acara dah hidup dalam ujian."*

> *"Untuk fasa seterusnya, ada beberapa keputusan yang kami perlukan daripada pihak pengurusan —"*
> - *"Satu — payment gateway: kita pilih yang mana?"*
> - *"Dua — WhatsApp API: stack mana yang nak digunakan?"*
> - *"Tiga — dan yang paling penting, timeline go-live yang pengurusan mahukan."*

> *"Jadi soalan saya kepada pihak pengurusan — apa keutamaan utama yang anda mahu kami fokuskan dahulu untuk go-live?"*

**[Diam. Beri ruang mereka jawab. Ini pembuka Q&A.]**

---

## 🛟 JAWAPAN PANTAS (Q&A) — baca bila ditanya

**Q: Bila Phase 3 siap?**
> *"Bergantung pada keutamaan yang pengurusan tetapkan. Payment gateway boleh kami siapkan dulu sebagai 'quick win' kerana ia berkaitan terus dengan hasil."*

**Q: Ada modul checkup pesakit?**
> *"Ya — gabungan tiga: Daily Check-in untuk mood dan tenaga, Vitals untuk tekanan darah dan HbA1c dengan graf, dan Catatan Harian dengan skor kepatuhan. Semua ada data demo sekarang."*

**Q: Sistem ni dah test dengan user?**
> *"Phase 1 dan 2 dah selesai. UAT penuh akan dijalankan selepas Phase 3 siap, sebelum go-live rasmi."*

**Q: Payment gateway pilih apa? Berapa kos?**
> *"Pilihan dalam pertimbangan — Billplz atau ToyyibPay untuk FPX (sekitar RM1 satu transaksi). Kami cadang pengurusan tetapkan pilihan supaya kami boleh sambungkan."*

**Q: Kalau ada page lambat / error masa demo?**
> **[Jangan minta maaf. Teruskan bercerita.]** *"Ini pangkalan ujian, kadang server online ambil masa sikit — tapi konsepnya macam yang saya terangkan."*

---

## 💡 5 PERINGATAN MASA PRESENT
1. **Jangan minta maaf** untuk benda belum siap — sebut *"itu dalam fasa seterusnya"*. Lebih yakin.
2. **Page lambat load** → terus bercerita, jangan diam menunggu skrin.
3. **Fokus NILAI bukan teknikal** — *"jimat masa staff", "kurang silap manual", "semua dalam satu tempat", "laporan sedia untuk mesyuarat"*.
4. **JANGAN buka WhatsApp Inbox staff** (kosong — belum sambung WA API).
5. **Manager paling minat Babak 4** (kelulusan, stok, order, laporan) — bagi masa lebih di situ.
