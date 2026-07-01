# 🎤 Pakej Pembentangan — Management & Manager
> ISW System (Ibnu Sina Wellness) · Disediakan 30 Jun 2026 · Demo di pangkalan TESTING (ISW Data Centre)

---

## 1. CHECKLIST SEBELUM DEMO (buat malam ini / pagi sebelum)

- [ ] **Laptop + charger + internet stabil** (sistem perlu sambung ke Supabase online)
- [ ] **Buka app sekali untuk "panaskan"** — login setiap role sekali, pastikan tiada blank page
- [ ] **Sediakan kertas senarai login** (Bahagian 2) — jangan menaip cari-cari depan audience
- [ ] **Tutup tab/tetingkap lain** — fokus, tiada notifikasi peribadi timbul
- [ ] **Zoom browser 110–125%** supaya audience nampak skrin
- [ ] **Buka flowchart** (Flow_Staff_Detail.drawio / Flow_Mega_All_Roles.drawio) dalam draw.io sebagai "peta sistem"
- [ ] **Cas telefon** — kalau nak tunjuk versi mobile (PWA)
- [ ] Data sudah disahkan: **120 pesakit · 82 aktif · 0 ralat integriti** ✅

---

## 2. AKAUN LOGIN DEMO (TESTING)

> URL: buka `index.html` → auto ke `auth/login.html`. Password = yang anda set semasa cipta akaun.
> **Isi password di sini sebelum present** supaya tak tercari-cari.

| Role | Email | Password | Tunjuk apa |
|---|---|---|---|
| **Super Admin** | `adminiswcustomer@ibnusinawellness.com` | __________ | Urus staff, RBAC, audit |
| **Admin** | `admin@ibnusinawellness.com` | __________ | Daftar & urus pesakit, KYC |
| **Manager** | `manager@gmail.com` | __________ | Kelulusan, order, laporan |
| **Doctor** | `nornajihah@ibnusinawellness.com` | __________ | KOB, laporan perubatan |
| **Coach** | `aqilah@ibnusinawellness.com` | __________ | Caseload, nota mingguan |
| **Pesakit** | (akaun ujian anda sendiri) | __________ | Pengalaman pesakit |

> ⚠️ **Nota penting:** 120 pesakit demo **tiada login sendiri** (data sahaja, untuk isi skrin staff). Untuk tunjuk sisi pesakit, guna **1 akaun pesakit ujian** yang anda dah daftar. Kalau belum ada, daftar satu malam ini melalui `auth/login.html` → Sign Up.

---

## 3. ANGKA UNTUK SLIDE / RINGKASAN 1-PAGE

**Apa itu ISW System?**
> Sistem pengurusan klinik psikoterapi hujung-ke-hujung — dari pesakit daftar (KYC), sesi KOB doktor, bimbingan coach mingguan, sehingga inventori, bayaran, order produk & laporan pengurusan. Satu platform, 6 jenis pengguna.

**Angka demo hidup (TESTING):**

| Metrik | Nilai |
|---|---|
| Jumlah pesakit dalam sistem | **120** |
| Pesakit aktif (dalam rawatan) | **82** |
| Pelan rawatan dijana | **117** |
| Sesi mingguan direkod | **151** |
| Bayaran pakej | **99** |
| Coach aktif (ada caseload) | **5** |
| Menunggu kelulusan KYC | **3** |
| Permohonan inventori menunggu | **4** |
| Permohonan surat menunggu | **5** |
| Amaran risiko terbuka | **3** |
| Ralat data | **0** ✅ |

**6 peranan pengguna:** Super Admin · Admin · Doctor · Coach · Manager · Pesakit
**Modul utama:** Pesakit/KYC · KOB 6-peringkat · Pelan Rawatan · Catatan Harian & Kepatuhan · Inventori · Order/Shop · Bayaran · Surat · Library · Pengumuman/Acara · Laporan/Governance

---

## 4. DEMO SCRIPT — URUTAN & AYAT (≈15 min)

> Prinsip: cerita **satu perjalanan pesakit**, bukan klik rawak. Ayat dalam *italic* = boleh baca terus.

### Pembukaan (1 min)
> *"Hari ini saya tunjukkan sistem ISW — satu platform yang uruskan keseluruhan perjalanan pesakit klinik kita, dari pendaftaran sampai laporan pengurusan. Ada 6 jenis pengguna. Saya akan tunjuk ikut aliran sebenar kerja kita."*
> Buka flowchart sekejap → *"Ini peta keseluruhan sistem."*

### Babak 1 — ADMIN: Onboarding pesakit (3 min)
1. Login **Admin** → Dashboard → **patients.html**
2. *"Di sini admin nampak semua pesakit — boleh tapis ikut status: aktif, tunggu KYC, tamat, berhenti."*
3. Klik **+ Tambah Pesakit** → tunjuk 3 jenis: Baru / Sedang Rawatan / Lama
4. *"Bila admin daftar pesakit 'sedang rawatan', sistem AUTO-cipta pelan rawatan dan jadual mingguan — tak perlu buat manual."*
5. Tunjuk **KYC** (kyc-list → kyc-review) → *"Setiap pesakit baru perlu lulus KYC dulu sebelum boleh guna sistem."*

### Babak 2 — DOCTOR: KOB (2 min)
1. Login **Doctor** → **kob-list.html** → pilih satu sesi → **kob-detail.html**
2. *"Doktor jalankan sesi KOB — tanda hadir, isi soal selidik, vitals, nota SOAP yang sulit, dan cadang pakej."*
3. Tunjuk butang **Tanda Selesai** → *"Bila selesai, sistem auto-cipta pelan rawatan 12–18 minggu."*
> ✅ Data KOB sudah di-seed (4 ditempah · 2 sedang berlangsung · 3 selesai + cadangan pakej). Filter "Hari Ini / Akan Datang / Hadir / Selesai" semua ada isi.

### Babak 3 — COACH: Bimbingan mingguan (3 min) ⭐ paling penting
1. Login **Coach (Aqilah)** → Dashboard → *"Coach nampak caseload dia, % check-in 7 hari, dan siapa kepatuhan rendah."*
2. Buka **patient-hub.html** (7 tab) → *"Semua tentang seorang pesakit dalam satu tempat — overview, check-in, vitals, sesi, bekalan, laporan, profil."*
3. Klik kad minggu → **plan-week.html** → tunjuk isi **Status / Skor / Nota / Kepatuhan**
4. *"Bila tanda Hadir, stok bekalan auto-tolak. Semua tersimpan automatik."*
5. Tunjuk **Catatan Harian / Kepatuhan** → heatmap & skor A/B/C

### Babak 4 — MANAGER: Operasi & laporan (3 min) ⭐ untuk manager
1. Login **Manager** → Dashboard → *"Manager nampak gambaran operasi: pesakit aktif, sesi tertunggak, stok rendah, pesanan menunggu."*
2. **Lulus Inventori** (inventory.html → Requests) → Approve → *"Bila diluluskan & dibeli, stok auto-naik."*
3. **Proses Order** (orders.html) → Packed → Shipped + tracking
4. **Closures** → *"Tetapkan cuti klinik, booking auto-blok tarikh itu."*
5. **Laporan** (governance / staff-stats / payment-admin / pakej-laporan) → **Export Excel/PDF**
6. *"Semua laporan boleh export untuk mesyuarat."*

### Babak 5 — SUPER ADMIN: Kawalan (1 min)
1. Login **Super Admin** → **staff_management.html** → *"Tambah staff, hantar jemputan email, set peranan."*
2. **peranan.html (RBAC)** → *"Kawal siapa boleh buat apa, ikut modul. Semua ada audit log."*

### Penutup (2 min)
> *"Itu aliran penuh — satu sistem, semua peranan bersambung. Sekarang saya kongsi apa yang dah siap, apa yang sedang dibuat, dan apa fasa seterusnya."*
> → Tunjuk Bahagian 5.

---

## 5. STATUS: DAH SIAP · SEDANG DIBUAT · FASA SETERUSNYA

### 🩺 Modul Checkup Pesakit (sudah siap — gabungan)
Bila ditanya "ada modul checkup pesakit?" — **Ya**, gabungan 3 ini:
- **Daily Check-in** (mood/tenaga/tidur/madu) · **Vitals** self-input BP/HbA1c + graf · **Catatan Harian + Kepatuhan**. Semua ada data demo.

### 💬 Modul Conversation (separa)
- **Berfungsi:** Lapor Isu dengan **thread balas-balas** (pesakit ↔ staff) dalam app.
- **UI ada, tunggu WA API:** WhatsApp Inbox staff (kosong — JANGAN buka masa demo).

### ✅ DAH SIAP (boleh demo hari ini)
- Pendaftaran pesakit + **KYC** (self-register + kelulusan staff)
- **KOB** 6-peringkat (doktor) + auto-cipta pelan rawatan
- **Pelan rawatan** mingguan + caseload coach + nota & skor
- **Catatan Harian & Kepatuhan** (checklist + auto-scoring A/B/C + heatmap + export)
- **Vitals** (BP/HbA1c) input pesakit + graf
- **Inventori** (request → kelulusan → auto-adjust stok)
- **Order/Shop** produk (pending→paid→packed→shipped→delivered)
- **Bayaran pakej** (rekod + resit) *(gateway sebenar belum — lihat bawah)*
- **Surat** (permohonan + kelulusan + jana PDF)
- **Library** kandungan + **Pengumuman/Acara**
- **Pulangan botol** · **Rekod perubatan** (upload X-ray/MRI)
- **Laporan & Governance** + export Excel/PDF
- **RBAC + audit log** + urus staff (Super Admin)
- **Outcome status** (OTW/Berhenti/Meninggal) · **Dwibahasa BM⇄EN**
- **Coach performance dashboard** + alert kepatuhan rendah

### 🟡 SEDANG DIBUAT / SIAP SEPARA
- **Payment gateway sebenar** — UI & rekod siap, proses bayaran masih **simulasi** (pending pilih Billplz vs ToyyibPay)
- **WhatsApp automasi** — rangka siap, peringatan acara LIVE (testing); catatan harian & birthday masih draf (tunggu WA API)
- **GHL integration** (sync ke GoHighLevel) — Fasa 1 dibina, belum deploy (tunggu kredensial GHL)
- **KYC→KOB access gating** — dibina, dalam ujian
- **Governance filter** (penyakit/umur/lokasi) — dashboard ada, filter belum

### 🔜 FASA SETERUSNYA (roadmap)
- **Sprint 2 — Workflow lock:** struktur Package ID formal · auto-shift jadual bila reschedule · lock butang online minggu ≥3 · RLS coach-only · jadual Hakeema 1:1
- **Sprint 3 — Integrasi:** GHL bridge · WhatsApp penuh · auto-invoice email+WA · SQL Accounting
- **Sprint 4 — Advanced:** OCR scan laporan perubatan · workflow DNA · AI chatbot · sistem reward/gamifikasi · Geng ALIVE
- **Mobile:** PWA responsif penuh untuk pesakit (Phase 2–3)

### ❓ Keputusan ditunggu daripada management (sebut masa Q&A)
- Payment gateway: **Billplz atau ToyyibPay?**
- WhatsApp API: stack mana (Business API / Twilio / 3rd party)?
- SQL Accounting: API atau CSV?
- **Timeline go-live?**

---

## 6. TIPS MASA PRESENT
- **Jangan minta maaf** untuk benda belum siap — kata *"itu dalam fasa seterusnya"*. Lebih yakin.
- Kalau satu page lambat load → teruskan bercerita, jangan diam menunggu.
- Fokus **nilai**, bukan teknikal: *"jimat masa staff"*, *"kurang silap manual"*, *"semua dalam satu tempat"*, *"laporan sedia untuk mesyuarat"*.
- Manager paling minat: **kelulusan, stok, order, laporan export**. Beri masa lebih di Babak 4.
- Akhir sekali tanya: *"Apa keutamaan pihak pengurusan untuk go-live?"* — tunjuk anda dengar.
