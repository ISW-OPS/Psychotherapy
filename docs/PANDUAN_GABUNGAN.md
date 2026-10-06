# Panduan ISW (digabung)

Gabungan semua fail panduan `.md` dalam folder ini. Setiap bahagian kekal seperti asal, dengan laluan fail asal sebagai tajuk. Pautan dalam bahagian asal mungkin tak lagi tepat selepas gabungan.

---


# ===== README.md =====

# Panduan Pengguna (SOP) — Sistem ISW

**Manual operasi langkah-demi-langkah** untuk staf & pesakit.
Berbeza dengan [`docs/sistem/`](../sistem/README.md) (dokumentasi teknikal untuk developer), folder ini menjawab soalan **"macam mana nak buat X?"** — buka page mana, klik butang mana, isi field apa.

> Kemaskini terakhir: 24 Jun 2026

---

## Cara guna dokumen ini

Setiap panduan ikut format yang sama:

1. **Tujuan** — bila guna flow ni
2. **Siapa boleh buat** — peranan yang dibenarkan
3. **Lokasi** — page + jalan navigasi
4. **Langkah** — step bernombor
5. **Field wajib vs pilihan** — apa MESTI isi, apa boleh skip
6. **Apa jadi lepas simpan** — kesan ke sistem (auto-stok, audit, dsb.)
7. **Masalah biasa** — error & penyelesaian

Tanda: **`*`** = field wajib. 🟢 = staf. 🔵 = pesakit.

---

## Indeks Panduan

### 🟢 Staf — Operasi
| Tugas | Panduan | Page |
|-------|---------|------|
| Tambah / edit pakej rawatan | [staff/tambah-pakej.md](staff/tambah-pakej.md) ✅ | `pakej-edit.html` |
| Pesakit baru (lead → KYC → KOB) | [staff/pesakit-kyc-kob.md](staff/pesakit-kyc-kob.md) ✅ | `patients.html`, `kyc-review.html` |
| Pelan mingguan & tanda hadir | [staff/pelan-mingguan.md](staff/pelan-mingguan.md) ✅ | `plan-week.html` |
| Kepatuhan (Catatan Harian) | [staff/kepatuhan.md](staff/kepatuhan.md) ✅ | `kepatuhan.html`, `kepatuhan-fill.html` |
| Inventori & kit prosedur | [staff/inventori.md](staff/inventori.md) ✅ | `inventory.html`, `kit-edit.html` |
| Produk & kedai | [staff/produk.md](staff/produk.md) ✅ | `product-edit.html` |
| Pesanan & tracking | [staff/pesanan.md](staff/pesanan.md) ✅ | `orders.html` |
| Pembayaran | [staff/pembayaran.md](staff/pembayaran.md) ✅ | `payment-admin.html` |
| Pengumuman & acara | [staff/pengumuman-acara.md](staff/pengumuman-acara.md) ✅ | `pengumuman-baru.html`, `events.html` |
| Mesej automatik WhatsApp | [staff/auto-mesej.md](staff/auto-mesej.md) ✅ | `auto-mesej.html` |
| Library & FAQ | [staff/library-faq.md](staff/library-faq.md) ✅ | `library-edit.html`, `library-faq-edit.html` |
| Surat rasmi | [staff/surat-rasmi.md](staff/surat-rasmi.md) ✅ | `surat-issue.html`, `surat.html` |
| Peranan, staf & kebenaran | [staff/peranan.md](staff/peranan.md) ✅ | `peranan.html`, `staff_management.html` |

### 🔵 Pesakit — Self-service
| Tugas | Panduan | Page |
|-------|---------|------|
| Isi borang KYC | [patient/kyc.md](patient/kyc.md) ✅ | `kyc.html` |
| Daftar pakej + KOB + agreement | [patient/daftar-pakej.md](patient/daftar-pakej.md) ✅ | `pakej.html`, `kob.html` |
| Bayar pakej | [patient/bayar.md](patient/bayar.md) ✅ | `payment.html` |
| Catatan Harian (check-in) | [patient/catatan-harian.md](patient/catatan-harian.md) ✅ | `kepatuhan.html`, `checkin.html` |
| Pelan rawatan & jadual harian | [patient/pelan-rawatan.md](patient/pelan-rawatan.md) ✅ | `plan.html`, `routine.html`, `vitals.html` |
| Beli produk, jejak pesanan, pulangan | [patient/kedai-pesanan.md](patient/kedai-pesanan.md) ✅ | `shop.html`, `orders.html`, `pulangan.html` |
| Lapor isu & maklum balas | [patient/lapor-isu.md](patient/lapor-isu.md) ✅ | `issue.html`, `feedback.html` |
| Rekod perubatan, surat, library | [patient/rekod-surat-library.md](patient/rekod-surat-library.md) ✅ | `rekod-perubatan.html`, `surat.html`, `library.html` |

> ✅ = siap · _italic_ = senarai kerja (belum ditulis)

---

## 📸 Manual visual (screenshot, print-ready)

- [Manual_Pengguna_Staf_UTAMA.html](Manual_Pengguna_Staf_UTAMA.html) — versi ringkas, 1 screenshot + 1 perenggan per modul, liputan kumpulan UTAMA penuh (12 modul).
- [Manual_Pengguna_Staf_Detail.html](Manual_Pengguna_Staf_Detail.html) / [Manual_Pengguna_Staf_Detail.docx](Manual_Pengguna_Staf_Detail.docx) — versi **sangat terperinci, LENGKAP SEMUA MODUL STAF**: langkah bernombor, screenshot dianotasi (bulatan merah tunjuk butang), ikut alur sampai destinasi seterusnya. Merangkumi ketujuh-tujuh kumpulan nav (UTAMA, OPERASI, KOMUNIKASI, PENGETAHUAN, LAPORAN, PENTADBIRAN, SISTEM) — 32 bab, ~160 screenshot, semua flow dijalankan betul-betul dalam sistem testing (bukan simulasi). Versi .docx boleh terus diedit dalam Word.

Buka dalam pelayar → Cetak (Ctrl+P) → Save as PDF.

---

## Rujukan silang

- Skema data & jadual: [`docs/sistem/02-pangkalan-data.md`](../sistem/02-pangkalan-data.md)
- Senarai modul & aliran: [`docs/sistem/03-modul.md`](../sistem/03-modul.md)
- Peranan & akses: [`docs/sistem/05-peranan-akses.md`](../sistem/05-peranan-akses.md)
- Rajah aliran ASCII: [`docs/System_Flows.md`](../System_Flows.md)


---


# ===== Readiness_Plan_Patient_Team.md =====

# 📋 Readiness Plan — Patient Team (Phase 2)
> ISW System (Ibnu Sina Wellness) · Disediakan 30 Jun 2026
> Tujuan: sediakan sistem untuk **batch testing oleh pasukan/pesakit sebenar** sebelum go-live penuh.

---

## 1. OBJEKTIF
Membolehkan sekumpulan kecil pesakit sebenar (pilot) menggunakan portal pesakit dari hujung ke hujung — daftar, KYC, KOB, pelan rawatan, catatan harian, vitals, order, surat — sambil pasukan memantau, mengumpul maklum balas, dan membetulkan isu sebelum dibuka kepada semua pesakit.

**Kejayaan = ** pesakit pilot boleh selesaikan satu kitaran penuh (daftar → guna mingguan) tanpa bantuan teknikal, dan pasukan dapat semua data dalam dashboard staff.

---

## 2. SKOP PILOT (cadangan)
| Perkara | Cadangan |
|---|---|
| Bilangan pesakit pilot | 5–10 orang (campuran pakej & keadaan) |
| Tempoh | 2–3 minggu |
| Saluran | Web (desktop + mobile browser / PWA) |
| Persekitaran | **TESTING dahulu**, kemudian PROD bila stabil |
| Sokongan | 1 coach + 1 admin standby untuk bantu pesakit |

---

## 3. APA YANG DAH SEDIA UNTUK PESAKIT ✅
Portal pesakit ini **sudah berfungsi** dan boleh diuji:
- Daftar akaun + **KYC** (isi maklumat, tunggu kelulusan staff)
- **KOB** — lihat sesi, link Google Meet (online), cadangan pakej
- **Pelan rawatan** — lihat progres mingguan, skor
- **Catatan Harian** + **Kepatuhan** (checklist amalan harian)
- **Daily Check-in** (mood, tenaga, tidur, madu)
- **Vitals** — input BP/HbA1c sendiri + graf
- **Routine** — contoh jadual harian ikut pakej
- **Shop / Order** produk + jejak status
- **Surat** — mohon surat, muat turun PDF bila siap
- **Pulangan botol** · **Rekod perubatan** (upload)
- **Library** kandungan · **Pengumuman/Acara** · **FAQ** · **Feedback** · **Lapor isu**
- **Dwibahasa** BM⇄EN · **PWA** boleh install di telefon

## 4. APA YANG BELUM SEDIA (impak ke pesakit) 🟡
| Perkara | Kesan ke pesakit pilot | Penyelesaian sementara |
|---|---|---|
| **Payment gateway sebenar** | Bayar pakej/produk masih simulasi | Bayaran manual (transfer) + staff key-in |
| **WhatsApp automasi** | Tiada peringatan auto via WA | Coach ingatkan manual buat masa ini |
| **Mobile UI/UX polish** | Sesetengah page belum 100% kemas di telefon | Uji & senarai page bermasalah dahulu |
| **Chat pesakit↔coach dalam app** | Belum ada chat terus | Guna "Lapor Isu" (ada thread) atau WhatsApp biasa |

---

## 5. LANGKAH KESEDIAAN (sebelum pilot mula)

### A. Teknikal
- [ ] Sahkan semua page pesakit buka tanpa error (desktop + 1 telefon)
- [ ] Uji aliran penuh dengan **1 akaun pesakit ujian** dahulu
- [ ] Semak mobile: senarai page yang perlu dibaiki responsif
- [ ] Pastikan kelulusan KYC oleh staff berfungsi (notifikasi sampai)
- [ ] Sediakan akaun coach/admin sokongan
- [ ] Backup / tahu cara reset jika data rosak

### B. Proses & manusia
- [ ] Pilih 5–10 pesakit pilot + dapatkan persetujuan mereka
- [ ] Sediakan **panduan ringkas pesakit** (1 muka: cara daftar & guna)
- [ ] Tetapkan 1 orang "talian bantuan" pilot
- [ ] Tetapkan cara kumpul maklum balas (borang / WhatsApp group)
- [ ] Jadual check-in mingguan dengan pasukan

### C. Pemantauan semasa pilot
- [ ] Coach semak dashboard setiap hari (check-in %, kepatuhan, risiko)
- [ ] Log semua isu dilaporkan (page, langkah, screenshot)
- [ ] Mesyuarat mingguan: isu utama + keputusan baiki/teruskan

---

## 6. KRITERIA GO / NO-GO (selepas pilot)
**GO ke PROD penuh bila:**
- Tiada isu kritikal (pesakit tak boleh daftar / data hilang / page crash) berbaki
- ≥80% pesakit pilot boleh guna tanpa bantuan teknikal
- Dashboard staff tunjuk data tepat
- Keputusan dibuat untuk: **payment gateway** & **WhatsApp** (atau sahkan proses manual sementara diterima)

---

## 7. TIMELINE CADANGAN
| Minggu | Aktiviti |
|---|---|
| Minggu 0 (sebelum) | Langkah kesediaan A & B · pilih pesakit · panduan ringkas |
| Minggu 1 | Pesakit daftar + KYC + onboarding · pantau rapat |
| Minggu 2 | Guna harian penuh (check-in, vitals, pelan) · kumpul maklum balas |
| Minggu 3 | Baiki isu · ujian semula · mesyuarat Go/No-Go |
| Selepas | Keputusan go-live + plan rollout penuh |

---

## 8. KEPUTUSAN DITUNGGU DARIPADA MANAGEMENT
- Payment gateway: **Billplz atau ToyyibPay?** (atau terima bayaran manual untuk pilot)
- WhatsApp API: stack mana? (atau coach ingatkan manual untuk pilot)
- Siapa 5–10 pesakit pilot & bila mula?
- TESTING sahaja dulu, atau terus PROD untuk pilot?


---


# ===== patient/bayar.md =====

# Panduan: Bayar Pakej 🔵

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Selesaikan bayaran untuk pakej rawatan yang anda pilih. Selepas bayar, pakej **aktif** pada rekod anda, akses pelan dibuka, **pelan rawatan dijana automatik**, dan anda boleh baca + tandatangan **kontrak** pakej.

> ⚠️ **PENTING — masih simulasi.** Buat masa ini fungsi bayar (`processPayment()`) **belum bersambung ke gateway sebenar**. Tiada FPX/kad betul diproses — sistem cuma tunggu seketika (`setTimeout`) lalu terus tanda "berjaya". Gateway sebenar (**Billplz / ToyyibPay**) masih **pending**. Pilihan kaedah (FPX / Kad) di skrin adalah **paparan sahaja** — tiada wang sebenar ditolak lagi.

## 2. Siapa boleh buat
**Pesakit** yang sudah log masuk. Untuk pesakit kali pertama, pakej biasanya **dipilih oleh doktor semasa KOB** — anda hanya boleh beli sendiri (renewal/sambungan) selepas **KOB selesai** (`kob_status = completed`) dan **tiada** pakej aktif lain. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

## 3. Lokasi
- **Page bayar:** Sidebar pesakit → **Bayaran** (`roles/patient/payment.html`)
- **Datang dari mana:** Anda biasanya sampai sini selepas klik **Beli Pakej →** di `roles/patient/pakej-detail.html`. Butang itu simpan pakej ke `localStorage` (`isw_pending_payment`) dan redirect ke `payment.html`.
- Pakej **PERCUMA** (RM 0) **tidak** melalui page ni — ia terus diaktifkan dari `pakej-detail.html`.

---

## 4. Langkah ringkas

1. Di `pakej-detail.html`, klik **Beli Pakej →** → sahkan → diarah ke **Bayaran**.
2. Semak **Ringkasan bayaran** — senarai invois belum bayar + **Jumlah**.
3. Pilih **Kaedah pembayaran**: 🔘 FPX Online Banking (ToyyibPay) *(default)* atau Credit / Debit Card.
4. Klik **Pay RM … →**.
5. Tunggu "Memproses..." → mesej **"Pembayaran berjaya! Resit: RCP-…"**.
6. Sistem auto-redirect ke **`plan.html`** (kalau pakej baru dibeli & pelan dijana).
7. Resit muncul di bahagian **Resit Terdahulu** — klik **📄 PDF** untuk cetak/simpan.

> Nak batal? Klik **Batal Semua**. Invois pakej yang sedia ada (`package_existing`) akan dipadam; janji temu (`appointment`) ditanda batal. Akan minta pengesahan dulu.

---

## 5. Field — wajib vs pilihan

### Ringkasan bayaran (auto, tak boleh edit)
| Bahagian | Nota |
|----------|------|
| Senarai item | Setiap baris = satu invois belum bayar (pakej, janji temu, minggu tambahan, order kedai, dll.). |
| **Jumlah** | Hasil tambah semua item. **Tiada caj servis & SST** — anda bayar **harga subtotal sahaja** (model bayar sekali). |

> 🔒 **Harga disahkan semula dari DB.** Sebelum papar, harga pakej dibaca balik dari `psy_packages` (`verifyPackagePrice()`) untuk elak gangguan `localStorage`. Kalau pakej tak aktif / harga tak sah, item ditolak dan anda diminta pilih semula.

### Kaedah pembayaran
| Field | Wajib? | Nota |
|-------|--------|------|
| **Kaedah** `*` | ✅ Pilih satu | 🔘 **FPX Online Banking (ToyyibPay)** — default · **Credit / Debit Card** (Visa/Master). Disimpan sebagai `payment_method` pada resit. **Status: paparan sahaja — belum proses wang sebenar.** |

### Butang
| Butang | Kesan |
|--------|-------|
| **Pay RM … →** | Jalankan `processPayment()` (simulasi). Teks butang tunjuk jumlah semasa. |
| **Batal Semua** | Buang semua item tertunggak + padam `isw_pending_payment`. |

---

## 6. Apa jadi lepas Bayar
`processPayment()` jalankan langkah ini (semua **selepas** simulasi `setTimeout` 1.2 saat):

1. **Semak pakej aktif (anti-duplikat).** Baca semula `psy_patients` — kalau anda **sudah ada** pakej aktif yang belum tamat, bayaran **dibatalkan** dan anda diarah ke `plan.html`.
2. **Jana rujukan resit** — `RCP-…` (cth `RCP-LZ8K2M`).
3. **Aktifkan pakej** (untuk item jenis `package`):
   - Insert ke **`psy_package_purchases`** — `status: 'active'`, `expires_at` = **+3 bulan**, simpan `payment_method`.
   - Update **`psy_patients`** — set `active_package_id`, `active_package_name`, `package_purchased_at`, `package_expires_at`. **← inilah yang buka akses pakej.**
   - (Untuk pakej sedia ada `package_existing`: flip purchase → `active` dan aktifkan pada rekod pesakit yang sama.)
4. **Rekod bayaran** — insert ke **`psy_payments`** (`receipt_ref`, `items`, `subtotal`, `service_charge: 0`, `sst: 0`, `total`, `payment_method`, `status: 'completed'`, `paid_at`).
5. **Audit log** — catat `payment.received` (ref, total, kaedah).
6. **Padam** `isw_pending_payment` dari `localStorage`.
7. **Jana Pelan Rawatan automatik** (kalau pakej baru): insert ke **`psy_treatment_plans`** guna template dari `psy_packages` (nama, `duration_weeks`/`duration_unit`, matlamat bio/psiko/sosial/spiritual, `coaching_schedule`), `current_week: 1`, `status: 'active'`. Ada *race guard* — langkau kalau sudah ada pelan aktif.
8. **Redirect** ikut konteks: pelan dijana → **`plan.html`**; bayaran KOB → `kyc.html`; pakej KOB → `kob.html`; selainnya muat semula senarai.

> **Kontrak.** Selepas pakej aktif & pelan dijana, kontrak pakej (tajuk + klausa yang staf set di [Tambah Pakej](../staff/tambah-pakej.md)) tersedia untuk anda **baca + tandatangan**. Pembolehubah seperti `{{patient_name}}`, `{{package_name}}`, `{{price}}`, `{{today}}` diisi automatik.

Item lain pada page yang sama dikendali serupa: `appointment` (tag `[PAID]`), `plan_extension` (minggu tambahan → `extension_paid`), `shop_order` (insert `psy_orders` + kosongkan troli), `kob` / `kob_package` (kemaskini `kob_status`).

Rujukan model & jadual: [03-modul.md](../../sistem/03-modul.md) · [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md).

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Anda sudah ada pakej aktif: … Bayaran dibatalkan." | Rekod anda sudah ada pakej aktif belum tamat. Selesaikan/tunggu tamat dulu sebelum beli baru. Diarah ke `plan.html`. |
| "Harga pakej tidak sah. Sila pilih semula pakej." | Pakej tak aktif (`is_active=false`) atau harga rosak semasa sahkan dari DB. Buka semula `pakej-detail.html` dan pilih semula. |
| "Tiada bayaran tertunggak" / "Tiada invois belum bayar" | Tiada item dalam `isw_pending_payment` & tiada invois pending di DB. Pilih pakej dulu di `pakej-detail.html`. |
| Butang "Beli Pakej" tak muncul (tulis _"Pakej dipilih oleh doktor semasa KOB"_) | KOB belum selesai. Pakej kali pertama dipilih doktor masa KOB. |
| Butang tulis _"Anda sudah ada pakej aktif"_ | Tak boleh beli pakej lain semasa satu pakej masih aktif. |
| Wang tak ditolak walaupun "berjaya" | **Normal — masih simulasi.** Gateway sebenar (Billplz/ToyyibPay) belum disambung. Resit dijana tapi tiada transaksi bank sebenar. |
| "Ralat: …" lepas klik Pay | Insert DB gagal (cth RLS). Butang kembali aktif — cuba semula; kalau berterusan, hubungi staf. |

---

## 8. Rujukan teknikal
- Page: [`roles/patient/payment.html`](../../../roles/patient/payment.html) · `processPayment()` ~ baris 316
- Datang dari: [`roles/patient/pakej-detail.html`](../../../roles/patient/pakej-detail.html) · `tempahPakej()` ~ baris 225 (set `isw_pending_payment`)
- Jadual: `psy_payments`, `psy_package_purchases`, `psy_patients` (`active_package_id`), `psy_treatment_plans` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- **Status gateway:** UI siap, **gateway sebenar masih pending** — lihat catatan di [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md) (`psy_payments`).


---


# ===== patient/catatan-harian.md =====

# Panduan: Catatan Harian — Check-in & Checklist Amalan 🔵

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Rekod keadaan diri anda **setiap hari** semasa program rawatan — perasaan (mood), reaksi pemulihan badan, tidur, aktiviti, dan **checklist amalan** (madu, pernafasan, zikir, terapi bumi, berjemur, pantang makan…). Maklumat ini membantu coach memantau **kepatuhan** dan **perkembangan** anda, dan memberi anda skor amalan harian supaya anda nampak sendiri sejauh mana anda konsisten.

## 2. Siapa boleh buat
**Pesakit** yang aktif berpakej (ada pakej rawatan berjalan). Catatan Harian terbuka secara automatik mengikut **fasa rawatan** anda. Jika coach tertinggal isi bagi pihak anda (cth anda tiada akses telefon hari itu), coach boleh isi melalui modul mereka — tetapi biasanya **anda sendiri** yang isi.

## 3. Lokasi
- **Sidebar pesakit / menu bawah → Check-in** (`roles/patient/checkin.html`) atau **Catatan Harian** (`roles/patient/kepatuhan.html`)
- **Dari Dashboard:** kad "Catatan Harian" → butang **Mula Catatan Harian**
- Telefon mobile: kad biru besar di atas → butang **✨ Mula Catatan Harian**

---

## 4. Langkah ringkas

1. Buka **Catatan Harian**. Pilih **hari ini** pada jalur kalendar minggu (bulatan di atas).
2. Tekan **✨ Mula Catatan Harian** (atau **✏️ Kemaskini Catatan** kalau sudah isi).
3. **Bahagian 1 — Perasaan (mood):** pilih 1 perasaan utama (wajib) → jawab soalan susulan (perincian, tahap ⭐1–5, faktor).
4. **Bahagian 2 — Reaksi pemulihan:** pilih tahap reaksi → kalau bukan "Tiada", pilih bahagian badan + simptom.
5. **Tidur:** masukkan masa tidur & bangun (sistem auto-kira jam tidur).
6. **Aktiviti harian:** pilih satu aras tenaga anda.
7. **Bahagian 3 — Checklist Amalan:** jawab setiap amalan (madu/nafas/zikir/…). Item bertanda **`*`** **wajib**.
8. Tekan **Selesai ✓**. Anda nampak **skor amalan** + **gred** + **🔥 streak** (hari berturut).

> Anda boleh kemaskini catatan **hari yang sama** atau **mana-mana hari dalam minggu semasa** seberapa banyak kali. Tekan butang yang sama untuk buka semula dan ubah.

---

## 5. Field — wajib vs pilihan

### Bahagian 1 — Perasaan / Mood
| Field | Wajib? | Nota |
|-------|--------|------|
| **Perasaan utama** `*` | ✅ **WAJIB** | Pilih 1 dari 6: 😊 Gembira · 😔 Sedih · 😟 Cemas · 😠 Marah · 😩 Burnout · 😐 Biasa. Sistem block kalau kosong. |
| Perincian perasaan | Ikut mood | Cth Gembira → Tenang/Bersyukur/Bersemangat…; Sedih → Kecewa/Murung/Kosong jiwa… (wajib bila bukan "Biasa"). |
| Tahap perasaan ⭐ | Ikut mood | 1–5 bintang (Sangat Rendah → Sangat Baik). Wajib bila bukan "Biasa". |
| Faktor / simptom susulan | Pilihan | Cth Gembira → faktor (Kesihatan/Keluarga…); Cemas → simptom (Berdebar/Sukar tidur…). Pilih satu atau banyak ikut soalan. |

> Pilih **Biasa** = sistem terus ke bahagian seterusnya tanpa soalan susulan.

### Bahagian 2 — Reaksi pemulihan badan
| Field | Wajib? | Nota |
|-------|--------|------|
| **Tahap reaksi** `*` | ✅ untuk teruskan bahagian ini | 😊 Tiada · 😐 Ringan · 😣 Sederhana · 🤒 Teruk. "Reaksi pemulihan" = perubahan badan selepas rawatan (penat, demam ringan, mengantuk) — ini **normal**. |
| Bahagian badan | Bila bukan "Tiada" | Pilih satu atau banyak: Pencernaan · Peredaran Darah · Otot & Saraf · Detoksifikasi · Emosi & Tenaga · Pernafasan. |
| Simptom | Pilihan | Pilih simptom dalam setiap bahagian (cth Kembung, Cirit-birit, Sakit badan, Mengantuk…). |
| Reaksi lain | Pilihan | Medan teks bebas untuk simptom yang tiada dalam senarai. |

### Tidur & Aktiviti
| Field | Wajib? | Nota |
|-------|--------|------|
| Masa tidur & bangun | Pilihan | Sistem auto-kira **≈ jam tidur**. |
| Aktiviti harian | Pilihan | Pilih 1 aras (boleh buat seperti biasa → banyak rehat tak mampu beraktiviti). |

### Bahagian 3 — Checklist Amalan (yang diberi SKOR)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Setiap amalan berskor** `*` | ✅ **WAJIB** | Item bertanda **`*`** mesti dijawab. Tak lengkap → mesej "Sila lengkapkan: \<nama amalan\>". |
| Amalan "tracking" | Pilihan | Bertanda **(tracking)** — direkod tapi **tidak** mempengaruhi skor. |
| "Lain-lain" + teks | Pilihan | Bila pilih "Lain-lain", boleh taip butiran. |

> Senarai amalan **berbeza ikut fasa rawatan** anda. Contoh amalan: 🍯 Madu LTH/IB, 🧄 Madu LTH Pagi/YH Pagi, 🫁 Pernafasan Fitrah, 📿 Zikir Bersanad, 🦶 Terapi Bumi, ☀️ Berjemur, 🥥 Air Kelapa, 🥛 Yogurt, 🥗 Pantang Makan. Kalau checklist fasa anda belum disediakan, mesej "Sila hubungi coach anda" muncul.

---

## Cara baca SKOR & gred (A/B/C)

Selepas **Selesai**, anda nampak peratus **Skor Amalan** + gred:

| Gred | Skor harian | Makna |
|------|-------------|-------|
| **A — Cemerlang** | ≥ 85% | Hampir semua amalan dipatuhi |
| **B — Sederhana** | 50–84% | Sebahagian sahaja |
| **C — Perlu usaha** | < 50% | Banyak amalan tertinggal |

**Macam mana skor dikira:** setiap amalan berskor bernilai sehingga **2 mata**. Skor harian = (mata diperoleh ÷ mata maksimum) × 100. Bahagian Check-in (mood, reaksi, tidur, aktiviti) **tidak diberi skor** — ia rekod keadaan diri sahaja.

> **PENTING — hari tak isi = 0.** Skor **mingguan** yang coach lihat dikira berdasarkan **bilangan hari yang sudah berlalu dalam minggu**, bukan hari yang anda isi sahaja. Maksudnya **setiap hari anda langkau dikira 0 mata**. Jadi cara terbaik naikkan skor ialah **isi setiap hari**, bukan isi banyak amalan dalam satu hari sahaja.

> 🔥 **Streak** = bilangan hari berturut anda isi catatan. Isi setiap hari untuk kekalkan streak.

---

## 6. Kekerapan & apa jadi lepas Simpan

**Kekerapan:** isi **sekali setiap hari**, sebaik-baiknya pada penghujung hari supaya reaksi & aktiviti lebih tepat. Anda hanya boleh isi/kemaskini hari **dalam minggu semasa** sahaja:
- Hari **akan datang** — tak boleh diisi (kelabu).
- Hari **minggu lepas** — boleh **dilihat** sahaja (🔒 "Lihat sahaja"), tak boleh diubah.

**Lepas tekan Selesai ✓:**
1. Checklist Amalan + skor ditulis ke **`psy_kepatuhan_log`** (satu rekod per `log_date`; kemaskini menimpa rekod sama).
2. Daily Check-in (mood, reaksi/simptom, tidur, aktiviti) ditulis ke **`psy_daily_checkins`** — hanya bila anda ada pilih mood.
3. Ringkasan mingguan & gred A/B/C dikira semula di **`psy_kepatuhan_weekly`** (paparan coach).
4. Hari itu bertukar hijau ✓ pada jalur kalendar; notis "Sudah diisi" muncul.
5. Coach anda nampak skor & catatan anda dalam laporan kepatuhan mereka.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Sila pilih perasaan anda dahulu" | Mood **wajib**. Pilih 1 perasaan utama sebelum teruskan. |
| "Sila lengkapkan: \<amalan\>" | Ada amalan berskor (`*`) belum dijawab. Lengkapkan semua item bertanda `*`. |
| "Checklist untuk fasa rawatan anda belum disediakan" | Fasa amalan anda belum dikonfigur. **Hubungi coach anda.** |
| Skor nampak rendah walaupun saya rajin isi amalan | Normal — **hari yang tak diisi dikira 0**. Isi **setiap hari** untuk skor naik. |
| Hari tertentu kelabu / tak boleh tekan | Hari **akan datang** tak boleh diisi. Tunggu sampai hari itu tiba. |
| 🔒 "Lihat sahaja" pada hari lepas | Hanya hari dalam **minggu semasa** boleh diisi/diubah. Hari minggu lepas dikunci. |
| Streak hilang | Streak terputus bila ada hari tak isi. Mula semula dengan isi hari ini. |

---

## 8. Rujukan teknikal
- Page: [`roles/patient/kepatuhan.html`](../../../roles/patient/kepatuhan.html) · `computeSkor()` (skor harian), `kfBuildSteps()` (flow adaptif), `saveChecklist()`
- Page mobile: [`roles/patient/checkin.html`](../../../roles/patient/checkin.html)
- Pratonton flow: [`roles/patient/kepatuhan-flow-preview.html`](../../../roles/patient/kepatuhan-flow-preview.html)
- Skor & gred A/B/C (Pilihan B, hari tak isi = 0): lihat panduan coach [../staff/kepatuhan.md](../staff/kepatuhan.md)
- Jadual: `psy_daily_checkins` (check-in) · `psy_kepatuhan_log` (amalan + skor harian) · `psy_kepatuhan_weekly` (ringkasan mingguan) — lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md)


---


# ===== patient/daftar-pakej.md =====

# Panduan: Pilih & Daftar Pakej + Sesi KOB + Tandatangan Agreement 🔵

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Tunjuk pesakit ISW cara lengkap untuk mula rawatan: lihat senarai pakej, hadiri sesi **KOB** (Konsultasi Orang Baru), terima saranan pakej daripada doktor, buat bayaran, baca & tandatangan **Agreement** (Kontrak Pelaburan Kesihatan), dan akhirnya pakej diaktifkan + **Treatment Plan** dijana automatik.

> **Penting:** Pakej rawatan **pertama** TIDAK dipilih sendiri oleh pesakit — ia disarankan oleh **doktor semasa sesi KOB**. Pesakit hanya boleh pilih & beli pakej sendiri **selepas KOB selesai** (untuk sambung/renew).

## 2. Siapa boleh buat
**Pesakit** yang sudah daftar akaun dan **KYC diluluskan**. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).) Akses penuh ke sistem (Treatment Plan, Coaching, Library) hanya terbuka selepas ada pakej aktif.

## 3. Lokasi
- **Senarai pakej:** Sidebar pesakit → **Pakej Rawatan** ([`roles/patient/pakej.html`](../../../roles/patient/pakej.html))
- **Detail pakej:** klik mana-mana kad pakej → [`roles/patient/pakej-detail.html`](../../../roles/patient/pakej-detail.html)
- **Sesi KOB + Agreement:** [`roles/patient/kob.html`](../../../roles/patient/kob.html) — satu page, 6 fasa berturutan (KYC → Tempah → Hadir → Pakej → Agreement → Selesai)
  - `kob-agreement.html` hanya redirect ke `kob.html` (tandatangan dibuat inline dalam fasa **5. Agreement**).

---

## 4. Langkah ringkas

1. Buka **Pakej Rawatan** — lihat senarai pakej tersedia (kad: gambar, harga, bilangan item).
2. Klik kad → **pakej-detail.html** untuk baca kandungan penuh (produk, bimbingan, preview Treatment Plan BPS-S). Buat masa first-time, butang papar *"Pakej dipilih oleh doktor semasa sesi KOB"*.
3. Buka **KOB** → ikut stepper 6 fasa:
   - **1. KYC** — pastikan KYC selesai (kalau belum, isi dulu).
   - **2. Tempah** — pilih **Mod** (🏥 F2F / 💻 Online), **Tarikh**, **Slot Waktu** → **Tempah Slot →**.
   - **3. Hadir KOB** — hadir pada waktu ditetapkan; doktor jalankan konsultasi.
   - **4. Pakej** — doktor saran satu pakej → pesakit semak detail → **💳 Bayar Pakej Sekarang →**.
   - **5. Agreement** — baca klausa, tick kotak persetujuan, turunkan tandatangan → **🖊️ Hantar Tandatangan**.
   - **6. Selesai** — pakej aktif, resit & PDF agreement tersedia, Treatment Plan dijana.

> Selepas KOB **selesai**, pesakit boleh ulang/sambung pakej sendiri terus dari `pakej.html` (butang **Beli →** / **Aktifkan**).

---

## 5. Field & butang — apa yang pesakit nampak

### A) Senarai pakej (`pakej.html`)
| Elemen | Nota |
|--------|------|
| **Banner status** | `📦 Pilih Pakej Rawatan Anda` (belum ada) · `✓ AKTIF` hijau (ada pakej, papar progress + countdown) · `⏰ Pakej Sebelumnya Dah Tamat` (boleh sambung) |
| **Kad pakej** | Gambar/ikon, nama, penerangan, `📦 N item dalam pakej`, harga (`RM xx` atau **PERCUMA**), badge **VIP**/**FREE** |
| Butang kad | First-time → **Lihat Details →**. Selepas KOB & tiada pakej aktif → **Beli →** / **Aktifkan** (free). Pakej aktif → label **✓ Aktif** |
| **📋 Sejarah Rawatan Saya** | Timeline gabungan: sesi KOB (🩺) + pembelian pakej (📦) + progress mingguan |

### B) Detail pakej (`pakej-detail.html`)
| Elemen | Nota |
|--------|------|
| Hero + 3 kotak info | **Tempoh**, **Jumlah Item**, **Harga** |
| 🎁 Produk yang anda terima | Senarai produk pakej (kalau ada) |
| 🎯 Bimbingan & Terapi | Senarai bimbingan (kalau ada) |
| 📋 Treatment Plan yang akan dicipta | Preview matlamat **BPS-S**: 🧬 BIO · 🧠 PSYCHO · 👥 SOCIAL · 🕌 SPIRITUAL |
| Butang CTA (bawah) | First-time → italik *"Pakej dipilih oleh doktor semasa KOB"*. Selepas KOB → **Beli Pakej →** / **Aktifkan Pakej**. Pakej ini aktif → **✓ Pakej Anda (Aktif)** |

### C) Fasa Tempah KOB (`kob.html` → fasa 2)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Mod Sesi** | ✅ | 🏥 F2F di Konsultasi · 💻 Online (default F2F) |
| **Tarikh** | ✅ | Konsultasi **tutup Isnin & Selasa** + tarikh closure klinik di-block; tak boleh tarikh lepas |
| **Slot Waktu** | ✅ | Pilih tarikh dahulu, dropdown isi slot tersedia |
| Butang | — | **Tempah Slot →**. Selepas tempah boleh **🔄 Reschedule** (sebelum hadir) |

### D) Fasa Pakej (fasa 4)
Doktor pilih pakej saranan. Pesakit nampak hero pakej + info (Tempoh/Item/Harga) + produk + bimbingan + preview plan, dan butang **💳 Bayar Pakej Sekarang →**. Selepas bayar → badge **✅ Sudah Bayar** + resit.

### E) Fasa Agreement (fasa 5)
| Field / butang | Wajib? | Nota |
|----------------|--------|------|
| Kad info | auto | **Nama**, **No. IC**, **Pakej** (diisi dari KYC/rekod) |
| Klausa kontrak | baca | Pembolehubah auto-isi: `{{patient_name}}`, `{{patient_ic}}`, `{{package_name}}`, `{{price}}`, `{{today}}` |
| ☑️ Kotak persetujuan | ✅ **WAJIB** | *"Saya telah baca, faham, dan bersetuju…"* |
| ✍️ Kanvas tandatangan | ✅ **WAJIB** | Mouse/jari/stylus. **🗑️ Padam & Ulang** untuk reset |
| Nama / No. IC / Tarikh | auto (read-only) | |
| **🖊️ Hantar Tandatangan** | — | Sebelum doktor sahkan, masih boleh **✏️ Sign Semula** / **✕ Batal Tandatangan** |

---

## 6. Apa jadi lepas tiap langkah

1. **Tempah slot** → rekod masuk **`psy_kob_sessions`** (status `booked`); `psy_patients.kob_status = 'booked'`; audit `kob.booked`.
2. **Doktor tanda hadir** → `kob_status = 'hadir'`; doktor saran pakej → `kob_status = 'package_recommended'` (simpan `recommended_package_id/name/price`).
3. **Bayar pakej** → ke `payment.html` (model **bayar sekali**); selepas bayar `kob_status = 'package_paid'`, resit direkod pada sesi KOB.
4. **Hantar tandatangan** → tandatangan + PDF di-upload ke storage `kob-signatures`; rekod masuk **`psy_kob_agreements`** (`signed_pdf_url`, `signature_url`); audit `kob.agreement_signed`.
5. **Doktor sahkan selesai** → `kob_status = 'completed'`; rekod ke **`psy_package_purchases`** (status `active`, ada `expires_at`); `psy_patients` dikemaskini (`active_package_id`, `active_package_name`, `package_expires_at`).
6. **Treatment Plan dijana** → baris masuk **`psy_treatment_plans`** (matlamat BPS-S + `coaching_schedule` dari pakej) → pesakit boleh terus ke **plan.html** & **checkin.html**.

> **Pakej PERCUMA (renewal sendiri):** klik **Aktifkan** → terus insert `psy_package_purchases` (price 0, sah 3 bulan) + cipta Treatment Plan, tanpa bayaran/agreement berasingan.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| Butang pakej kekal *"Pakej dipilih oleh doktor semasa KOB"* | Normal untuk first-time — pakej pertama mesti melalui KOB. Boleh beli sendiri hanya selepas KOB **completed**. |
| "Lengkapkan KYC" di fasa 1 | KYC belum dihantar/diluluskan. Isi [KYC](../../../roles/patient/kyc.html) dahulu. |
| Slot Waktu kosong / "Tiada slot tersedia" | Hari tutup (Isnin/Selasa), tarikh closure klinik, atau belum pilih tarikh. Pilih hari lain. |
| "Sila pilih slot waktu" | Tarikh dah dipilih tapi slot belum — pilih dari dropdown. |
| "Sila tick kotak persetujuan dahulu" | Tick kotak persetujuan sebelum hantar tandatangan. |
| "Sila turunkan tandatangan anda" | Kanvas kosong — lukis tandatangan dahulu. |
| "Anda sudah ada pakej aktif" | Tak boleh tempah pakej baru sehingga pakej semasa selesai/tamat tempoh (kecuali add-on berbayar atas pakej percuma). |
| Nak ubah masa KOB | Guna **🔄 Reschedule** (sebelum hadir). Selepas hadir, butang tiada. |

---

## 8. Rujukan teknikal
- Page: [`roles/patient/pakej.html`](../../../roles/patient/pakej.html) · [`pakej-detail.html`](../../../roles/patient/pakej-detail.html) · [`kob.html`](../../../roles/patient/kob.html) (`bookSlot()`, `submitInlineSignature()`, `payRecommendedPackage()`)
- Jadual: `psy_packages` · `psy_kob_sessions` · `psy_kob_agreements` · `psy_package_purchases` · `psy_treatment_plans` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Modul & aliran: [03-modul.md](../../sistem/03-modul.md)
- Storage tandatangan/PDF: bucket `kob-signatures`


---


# ===== patient/kedai-pesanan.md =====

# Panduan: Beli Produk, Jejak Pesanan & Pulangan Botol 🔵

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Panduan untuk **pesakit** ISW membeli produk individu (top-up) di Kedai, menjejak status pesanan dari bayaran sampai diterima (termasuk tracking courier), dan memohon **pulangan botol madu kosong** untuk diverify staff. Tiga aliran ini digabung kerana saling berkait: Kedai → Pesanan → (kemudian) Pulangan.

> Untuk **pakej rawatan utama** (langganan), bukan di sini — sila ke [Pakej Rawatan](../../../roles/patient/pakej.html). Kedai hanya untuk beli produk individu (à la carte) tanpa pakej.

## 2. Siapa boleh buat
Mana-mana **pesakit** yang sudah log masuk ke akaun ISW. Tiada kebenaran khas — setiap pesakit nampak Kedai, Pesanan, dan Pulangan sendiri sahaja (data dikunci ikut akaun melalui Row Level Security). (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

## 3. Lokasi
- **Kedai (beli produk):** Navigasi pesakit → **🛒 Shop** (`roles/patient/shop.html`)
- **Pesanan & Tracking:** dari Shop → pautan **"📦 Lihat Orders & Tracking →"**, atau terus (`roles/patient/orders.html`)
- **Pulangan Botol:** menu pesakit → **Pulangan Botol** (`roles/patient/pulangan.html`)
- **Pembayaran:** selepas checkout, sistem bawa ke `roles/patient/payment.html`

---

## 4. Langkah ringkas

### A — Beli Produk (Kedai)
1. Buka **🛒 Shop**.
2. (Pilihan) Tapis ikut **kategori** di bar atas (cth: `Madu`, atau `All`).
3. Klik **+ Add** pada produk yang dimahukan.
4. Klik butang troli terapung **🛒 (bilangan · jumlah)** di bawah-kanan.
5. Laras kuantiti dengan **−** / **+** dalam troli.
6. Pilih **Kaedah Penghantaran**: 🏥 **Pickup Konsultasi** (percuma) atau 🚚 **Pos / Courier** (+RM 8.00).
7. Kalau Pos: isi **Alamat Penghantaran**.
8. Klik **Teruskan ke Bayaran →** → buat bayaran di halaman Payment.

### B — Jejak Pesanan
1. Buka **📦 Orders & Tracking**.
2. Pilih tab: **Aktif · Semua · Selesai · Batal**.
3. Klik mana-mana pesanan untuk buka **timeline status**.
4. Untuk Pos: klik **Track →** guna nombor tracking courier.
5. Bila parsel sampai, klik **✅ Saya Dah Terima Parsel**.

### C — Pulangan Botol
1. Buka **Pulangan Botol** → tab **🍯 Hantar Pulangan Baru**.
2. Tick **semua 4 syarat** botol.
3. Isi **kuantiti botol**.
4. Upload **foto bukti** (wajib, boleh banyak).
5. (Pilihan) tulis **nota**.
6. Klik **Hantar Permohonan**.
7. Pantau di tab **📋 Pulangan Saya** + sembang dengan staff.

> Troli disimpan dalam browser sahaja sehingga checkout — ia belum jadi pesanan sebenar dalam database sampai bayaran dibuat.

---

## 5. Field — wajib vs pilihan

### A — Kedai / Troli (`shop.html`)
| Field / Pilihan | Wajib? | Nota |
|-----------------|--------|------|
| Produk (+ Add) | ✅ Sekurangnya 1 | Troli kosong = sistem block checkout ("Cart kosong"). Produk **Habis Stok** tak boleh tambah (butang "Habis"). |
| Kuantiti (− / +) | Default `1` | Laras dalam troli. Tolak sampai 0 = item keluar troli. |
| **Kaedah Penghantaran** | ✅ | 🏥 **Pickup Konsultasi** = percuma · 🚚 **Pos / Courier** = +RM 8.00. Default Pickup. |
| **Alamat Penghantaran** | ✅ kalau **Pos** | Block kalau Pos tapi alamat kosong ("Sila masukkan alamat penghantaran"). Pickup tak perlu alamat. |

> Harga **PROMO** (kalau ada) dipakai automatik dalam troli — harga asal dipalang, harga promo merah jadi harga sebenar. Badge **Tinggal N** muncul bila stok ≤ 5.

### B — Pulangan Botol (`pulangan.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **4 Syarat (checkbox)** `*` | ✅ **SEMUA** | (1) Tidak berkarat · (2) Bersihkan dulu · (3) Getah masih ada · (4) Besi penutup tak longgar. Butang Hantar kekal mati sehingga semua 4 ditick. |
| **Kuantiti Botol** `*` | ✅ | Mesti ≥ 1 (max 100). |
| **Foto Bukti** `*` | ✅ | Sekurangnya 1 foto. JPG/PNG, **maks 5MB setiap satu**, boleh upload banyak. |
| Nota | Pilihan | Cth: bila boleh hantar, kekurangan, dll. |

> Butang **Hantar Permohonan** hanya aktif bila **3 syarat dipenuhi serentak**: semua 4 checkbox ditick, sekurangnya 1 foto, dan kuantiti > 0.

### Status pesanan (timeline) — apa maksudnya
| Status | Papar pesakit | Maksud |
|--------|---------------|--------|
| `pending` | ⏳ Menunggu Pembayaran | Order dibuat, belum dibayar. |
| `paid` | Dibayar | Bayaran diterima. |
| `packed` | Sedang Disediakan | Staf sedang bungkus. Untuk Pickup: **📍 Sedia untuk Diambil**. |
| `shipped` | Dalam Penghantaran | Dah dihantar (ada tracking number) — butang **✅ Saya Dah Terima Parsel** muncul. |
| `delivered` | Selesai | Parsel diterima / diambil. |
| `cancelled` | Dibatalkan | Order dibatalkan. |

> Timeline **berbeza** ikut kaedah: Pos = 🛒 → 💳 → 📦 Dibungkus → 🚚 Dihantar → ✅ Diterima. Pickup = 🛒 → 💳 → 📍 Sedia Pickup → ✅ Diambil.

---

## 6. Apa jadi lepas hantar

### Beli Produk
1. Klik **Teruskan ke Bayaran** simpan butiran order (item, subtotal, fi penghantaran RM 8, alamat) ke browser (`isw_pending_payment`) dan jana **Order Ref** (cth `ORD-XXXX-XXXX`).
2. Diarah ke **`payment.html`** — pesanan **belum** wujud dalam database sampai bayaran selesai.
3. Selepas bayar, rekod ditulis ke jadual **`psy_orders`** dengan status bermula `pending`/`paid`.
4. Order muncul di **Orders & Tracking** (tab Aktif).

### Jejak Pesanan
1. Klik **✅ Saya Dah Terima Parsel** mengemaskini `psy_orders` → `status = delivered` + cap masa `delivered_at`.
2. Order berpindah ke tab **Selesai**. Banner "Terima kasih! Status order dikemaskini." muncul.
3. Status lain (`packed`, `shipped`, nombor tracking) di-set oleh **staf**, bukan pesakit.

### Pulangan Botol
1. Foto di-upload ke storan (`issue-photos`), rekod ditulis ke jadual **`psy_bottle_returns`** dengan `status = pending`.
2. Permohonan muncul di tab **📋 Pulangan Saya** dengan chip **⏳ Menunggu Verify**.
3. Boleh **sembang dengan staf** terus dari kad pulangan (mesej disimpan ke `psy_audit_log`, tag `bottle_return.message`).
4. Staf verify bila botol sampai konsultasi → status jadi **✅ Diterima** (`received`) atau **❌ Ditolak** (`rejected`, dengan alasan tolak).

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Cart kosong" masa checkout | Tiada item dalam troli. Tambah produk dulu (+ Add). |
| "Sila masukkan alamat penghantaran" | Pilih Pos tapi alamat kosong. Isi alamat, atau tukar ke Pickup. |
| Butang produk tertulis "Habis" | Produk Habis Stok — tak boleh beli sehingga staf restock. |
| Butang **Hantar Permohonan** (pulangan) kekal mati | Belum tick **semua 4 syarat**, atau belum upload foto, atau kuantiti 0. Lengkapkan ketiga-tiga. |
| "Beberapa foto > 5MB — sila pilih semula" | Ada foto melebihi 5MB. Kecilkan foto sebelum upload. |
| "Rekod pesakit tidak ditemui" (pulangan) | Sesi/akaun tak link betul. Muat semula halaman; kalau masih, log keluar & masuk semula. |
| Butang **Track →** tak muncul | Order belum status `shipped` atau staf belum isi nombor tracking. Tunggu kemaskini staf. |
| Order tak nampak selepas bayar | Pastikan bayaran benar-benar selesai di `payment.html`. Order hanya wujud selepas pembayaran direkod. |

---

## 8. Rujukan teknikal
- Kedai: [`roles/patient/shop.html`](../../../roles/patient/shop.html) · `checkout()` ~ baris 271
- Pesanan: [`roles/patient/orders.html`](../../../roles/patient/orders.html) · `confirmDelivered()` ~ baris 295
- Pulangan: [`roles/patient/pulangan.html`](../../../roles/patient/pulangan.html) · `submitReturn()` ~ baris 225
- Bayaran: [`roles/patient/payment.html`](../../../roles/patient/payment.html)
- Jadual: `psy_products`, `psy_orders`, `psy_bottle_returns` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Chat pulangan disimpan dalam `psy_audit_log` (action `bottle_return.message`, `meta.return_id`)


---


# ===== patient/kyc.md =====

# Panduan: Isi Borang KYC (Pendaftaran Biodata) 🔵

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Daftarkan maklumat biodata, sejarah kesihatan, maklumat waris dan persetujuan PDPA anda sebagai pesakit ISW. Borang KYC ini adalah langkah pertama selepas sign-up — ia mesti dihantar dan **diluluskan oleh staf** sebelum anda boleh teruskan ke sesi KOB dan langgan pakej rawatan.

## 2. Siapa boleh buat
Pesakit yang sudah ada akaun (role `patient`) — isi untuk **diri sendiri**, atau sebagai **wakil/keluarga (proxy)** bagi pihak pesakit sebenar. (Lihat [Onboarding Pesakit](../../sistem/03-modul.md).)

> Kalau anda isi bagi pihak orang lain, sistem akan minta sahkan ini semasa hantar (pilihan "Saya wakil / keluarga"). Maklumat mesti tepat & boleh disahkan oleh pesakit sebenar.

## 3. Lokasi
- **Borang KYC:** Selepas log masuk sebagai pesakit → `roles/patient/kyc.html`
  - Biasanya muncul automatik sebagai langkah onboarding selepas sign-up.
  - Boleh juga diakses dari dashboard pesakit.

---

## 4. Langkah ringkas

1. Buka **Borang Maklumat Pesakit (KYC)**.
2. (Pilihan) Masukkan **kod rujukan** kawan → klik **Semak** (anda berdua layak ganjaran).
3. Isi **Maklumat Pesakit** (nama, IC, telefon, emel, tarikh lahir, jantina, alamat, pekerjaan, syarikat, status perkahwinan).
4. Isi **Maklumat Waris / Penjaga** (nama, IC, telefon, emel, hubungan).
5. Isi **Sejarah Kesihatan** (pilih kondisi, tempoh dialami; ubat & laporan adalah pilihan).
6. Tanda **Persetujuan PDPA** (2 wajib + 2 pilihan).
7. Klik **Hantar Borang →** → sahkan maklumat dalam popup → pilih **Saya sendiri** atau **Saya wakil / keluarga**.

> Borang **auto-simpan draf** dalam browser semasa anda menaip (indikator "✓ Draf tersimpan secara automatik"). Boleh klik **Simpan Draf** secara manual, atau **🗑 Padam Draf** untuk kosongkan semula. Draf TIDAK masuk database sehingga anda klik Hantar.

---

## 5. Field — wajib vs pilihan

### Kod Rujukan (atas borang)
| Field | Wajib? | Nota |
|-------|--------|------|
| Kod Rujukan | Pilihan | Kod kawan yang rujuk anda (cth: `N7K23H5P`). Klik **Semak** untuk sahkan. Anda berdua layak ganjaran. |

### Maklumat Pesakit
| Field | Wajib? | Nota |
|-------|--------|------|
| **Nama Penuh** `*` | ✅ **WAJIB** | Ikut IC. |
| **No. IC / Pasport** `*` | ✅ **WAJIB** | Format: `900101145555`. IC auto-isi Tarikh Lahir + Jantina. Sistem block kalau IC sudah wujud dalam sistem (hubungi admin kalau itu anda). |
| **No. Telefon (H/P)** `*` | ✅ **WAJIB** | Format: `0123456789` (tanpa dash). |
| **Emel** `*` | ✅ **WAJIB** | Format: `nama@domain.com`. |
| **Tarikh Lahir** `*` | ✅ **WAJIB** | Auto-isi dari IC (boleh ubah). |
| **Jantina** `*` | ✅ **WAJIB** | Lelaki / Perempuan. Auto-isi dari IC (boleh ubah). |
| **Alamat Penuh** `*` | ✅ **WAJIB** | No. rumah, jalan, bandar, poskod, negeri. |
| **Pekerjaan** `*` | ✅ **WAJIB** | Pekerjaan semasa. |
| **Syarikat** `*` | ✅ **WAJIB** | Nama syarikat. |
| **Status Perkahwinan** `*` | ✅ **WAJIB** | Bujang / Berkahwin / Janda / Duda. |

### Maklumat Waris / Penjaga (kontak kecemasan)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Nama Penuh Waris** `*` | ✅ **WAJIB** | |
| **No. IC / Passport Waris** `*` | ✅ **WAJIB** | **Tidak boleh sama** dengan IC pesakit — waris mesti orang lain. |
| **No. Telefon (H/P)** `*` | ✅ **WAJIB** | Format: `0123456789`. |
| **Emel Waris** `*` | ✅ **WAJIB** | |
| **Hubungan** `*` | ✅ **WAJIB** | Ibu/Bapa · Adik-Beradik · Suami/Isteri · Anak · atau **Lain-lain** (nyatakan). |

### Sejarah Kesihatan
| Field | Wajib? | Nota |
|-------|--------|------|
| **Penyakit / Kondisi Semasa** `*` | ✅ **WAJIB** | Tanda **sekurang-kurangnya satu** dari senarai (Diabetes, Darah Tinggi, Anxiety, Depression, dll), atau tanda **Lain-lain** dan nyatakan. |
| **Berapa Lama Dialami** `*` | ✅ **WAJIB** | Kurang 1 bulan → Lebih 5 tahun. |
| Ubat Yang Diambil | Pilihan | Cth: `Sertraline 50mg`. |
| Upload Laporan Perubatan | Pilihan | PDF atau gambar · maksimum **20MB** setiap fail. |

### Persetujuan PDPA
| Field | Wajib? | Nota |
|-------|--------|------|
| **Pemprosesan Data Peribadi** `*` | ✅ **WAJIB** | PDPA Act 709 — wajib tanda untuk teruskan. |
| **Rekod Kesihatan** `*` | ✅ **WAJIB** | Rekod disimpan sulit antara clinicians ISW — wajib tanda. |
| Kajian Penyelidikan | Pilihan | Data anonymized untuk kajian. |
| Komunikasi Promosi | Pilihan | Terima promosi via email/WhatsApp. |

> **Ringkasan field wajib:** Semua field Maklumat Pesakit (10), semua field Waris (5), Kondisi + Tempoh kesihatan (2), dan 2 persetujuan PDPA (Pemprosesan Data + Rekod Kesihatan). Selebihnya pilihan.

---

## 6. Apa jadi lepas Hantar
1. Laporan perubatan (jika ada) dimuat naik ke Storage `medical-reports`.
2. Rekod ditulis ke jadual **`psy_kyc_submissions`** dengan **`status = 'pending'`** (insert kalau baru; update kalau hantar semula selepas ditolak).
3. Jadual hab **`psy_patients`** dikemaskini (IC, tarikh lahir, jantina, alamat, kondisi, dll) dan profil **`psy_profiles`** (nama + telefon).
4. Kalau anda dalam aliran KOB (`kob_status = 'paid'`) → ia maju ke **`kyc_done`**.
5. Tindakan dicatat ke audit log: `kyc.submitted` (dengan tanda self/proxy).
6. **Staf admin/manager/doktor diberi notifikasi** untuk semak borang anda.
7. Draf browser dipadam, dan anda diarah ke **`kob.html`** (kalau dalam aliran KOB) atau **`dashboard.html`**.

**Selepas hantar — status semakan:**
- ⏳ **Pending (Sedang Disemak)** — admin akan semak dalam ~24 jam. Borang jadi baca-sahaja; boleh klik **✏ Edit** untuk ubah semasa masih pending.
- ✅ **Diluluskan** — akaun disahkan, anda dapat akses penuh.
- ❌ **Ditolak** — sebab dipaparkan; kemaskini maklumat dan **hantar semula**.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Sila lengkapkan: …" | Ada field wajib kosong — isi semua field bertanda `*`. |
| "Format No. IC tidak sah" | Guna format `900101145555` (12 digit, dash dibenarkan). |
| "Format emel tidak sah" | Guna format `nama@domain.com`. |
| "IC Waris tidak boleh sama dengan IC Pesakit" | Waris mesti orang lain — masukkan IC waris yang berbeza. |
| "Sila pilih sekurang-kurangnya satu kondisi kesihatan" | Tanda ≥1 kondisi, atau tanda **Lain-lain** dan nyatakan. |
| "Anda perlu bersetuju dengan Pemprosesan Data Peribadi dan Rekod Kesihatan" | Tanda kedua-dua kotak persetujuan wajib. |
| "⚠️ IC ini sudah wujud dalam sistem" | IC sudah didaftarkan. Kalau itu anda, hubungi admin untuk link akaun. |
| "… melebihi 20MB" | Kecilkan fail laporan sebelum upload. |
| Borang baca-sahaja, tak boleh taip | Borang anda **pending** atau **diluluskan**. Kalau pending, klik **✏ Edit**. Kalau diluluskan, hubungi admin untuk ubah. |

---

## 8. Rujukan teknikal
- Page: [`roles/patient/kyc.html`](../../../roles/patient/kyc.html) · `submitKYC()` ~ baris 964, `validateAll()` ~ baris 584
- Jadual: `psy_kyc_submissions` (status: `pending` → `approved`/`rejected`), kemaskini ke `psy_patients` + `psy_profiles` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Modul onboarding & aliran KYC → KOB: [03-modul.md (A. Onboarding)](../../sistem/03-modul.md)
- Storage: bucket `medical-reports` untuk laporan perubatan
- Audit: `psy_audit_log` action `kyc.submitted` · Notifikasi staf: `psy_notifications` (type `kyc`)


---


# ===== patient/lapor-isu.md =====

# Panduan: Lapor Isu & Maklum Balas (Pesakit) 🔵

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Dua saluran komunikasi pesakit dengan pihak ISW:
- **Lapor Isu (Report Issue)** — adu masalah konkrit (produk rosak, salah produk, kurang jumlah, tidak sampai, masalah appointment, lain-lain). Staf terima, sahkan, dan balas dalam **thread** perbualan dua hala.
- **Maklum Balas (Feedback)** — beri rating ⭐ + komen pengalaman rawatan (mingguan: coach + bekalan; atau keseluruhan selepas tamat program).

## 2. Siapa boleh buat
**Pesakit** yang sudah log masuk. Lapor Isu terbuka kepada semua pesakit. Maklum Balas pula bergantung status pakej (lihat Seksyen 5 — bahagian Feedback). Staf urus jawapan di sebelah mereka (kebenaran modul `issues` / `feedback` — lihat [Peranan & Akses](../../sistem/05-peranan-akses.md)).

## 3. Lokasi
- **Lapor Isu (borang + senarai):** Menu pesakit → **Lapor Isu** ([`roles/patient/issue.html`](../../../roles/patient/issue.html))
  - Tab **📋 Laporan Saya** — senarai isu lalu + status.
  - Tab **✏️ Hantar Isu Baru** — borang laporan.
- **Thread perbualan:** [`roles/patient/issue-thread.html`](../../../roles/patient/issue-thread.html) — buka dari mana-mana isu dalam senarai (butang **👁 Lihat** / **↩ Balas**).
- **Maklum Balas:** Menu pesakit → **Feedback** ([`roles/patient/feedback.html`](../../../roles/patient/feedback.html))
- **Sebelah staf:** [`roles/staff/issue.html`](../../../roles/staff/issue.html), [`roles/staff/issue-detail.html`](../../../roles/staff/issue-detail.html), [`roles/staff/feedback.html`](../../../roles/staff/feedback.html)

---

## 4. Langkah ringkas

### A) Lapor Isu baru
1. Buka **Lapor Isu** → klik tab **✏️ Hantar Isu Baru**.
2. **01 — Jenis Isu:** pilih satu kategori (kad radio).
3. **02 — Details Isu:** taip keterangan masalah.
4. **03 — Foto Bukti (optional):** klik untuk upload satu foto (JPG/PNG, maks 5MB).
5. Klik **Hantar Laporan**.
6. Sistem alih anda ke tab **📋 Laporan Saya** — isu baru muncul dengan status **⏳ Menunggu**.

### B) Balas dalam thread
1. Tab **📋 Laporan Saya** → klik **👁 Lihat** (belum dijawab) atau **↩ Balas** (sudah dijawab).
2. Baca perbualan (gelembung kanan = anda, kiri = staf).
3. Taip di kotak bawah → klik **Hantar ↩** (atau tekan **Ctrl+Enter**).
4. Balasan staf masuk **secara langsung (realtime)** tanpa perlu refresh.

### C) Hantar Maklum Balas
1. Buka **Feedback**. Sistem auto-pilih mod ikut status pakej anda:
   - **Feedback Minggu Ini** (pakej aktif) — pilih minggu → beri ⭐.
   - **Feedback Keseluruhan** (pakej tamat) — rating + tag + komen.
2. Beri rating, isi komen (optional), klik **Hantar Feedback**.

---

## 5. Field — wajib vs pilihan

### Lapor Isu — borang "Hantar Isu Baru" (`issue.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **01 — Jenis Isu** `*` | ✅ **WAJIB** | Pilih satu: 📦 Produk rosak · 🔄 Salah produk · ⚖️ Kurang jumlah · 🚚 Tidak sampai · 📅 Masalah appointment · 💬 Lain-lain. Tak pilih = "Sila pilih jenis isu". |
| **02 — Details Isu** `*` | ✅ **WAJIB** | Keterangan masalah (textarea). Kosong = "Sila isi deskripsi masalah". |
| **03 — Foto Bukti** | Pilihan | Satu foto, JPG/PNG, **maks 5MB**. Lebih 5MB ditolak. Kalau upload gagal, laporan **tetap dihantar** (cuma tanpa foto). |

> Borang hanya block pada **Jenis Isu** dan **Details** — kedua-duanya wajib. Foto sentiasa optional.

### Thread isu (`issue-thread.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Balasan** `*` | ✅ **WAJIB** | Teks balasan. Kosong = "Sila tulis balasan terlebih dahulu." Hantar dengan butang **Hantar ↩** atau **Ctrl+Enter**. |

> Dalam thread, pesakit hanya boleh hantar **teks** (tiada lampiran foto pada balasan susulan).

### Maklum Balas — Mod Mingguan (`feedback.html`, pakej aktif)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Pilih Minggu** `*` | ✅ **WAJIB** | Hanya minggu yang sesinya sudah jalan (status `hadir` / `consultation_done`) muncul. Minggu yang sudah dirating ditanda **✓ (dirated)**. |
| **⭐ Pengalaman minggu ini** `*` | ✅ **WAJIB** | Rating 1–5 bintang. Kosong = "Sila bagi rating overall". |
| 👨‍⚕️ Rate coach | Pilihan | Muncul hanya jika minggu itu ada coach. |
| 📦 Bekalan minggu ini | Pilihan | Rating bintang untuk bekalan (cukup / tepat masa / quality). |
| Komen | Pilihan | Apa yang baik / boleh diperbaiki. |

### Maklum Balas — Mod Keseluruhan (`feedback.html`, pakej tamat)
| Field | Wajib? | Nota |
|-------|--------|------|
| Rating keseluruhan | Default `4` ⭐ | Klik bintang 1–5. |
| Yang paling membantu | Pilihan | Chip pilihan (cth: coach, supplement, library). Boleh pilih banyak. |
| Komen / testimonial | Pilihan | Pengalaman keseluruhan. |

> Selepas hantar dengan rating **≥ 4 ⭐**, sistem papar ajakan **Tulis Review di Google** (popup). Pautan Google Review hanya wujud dalam Mod Keseluruhan.
>
> **Mod Lock** 🔒 — kalau tiada pakej aktif **dan** tiada pakej tamat, Feedback dikunci: "Feedback tersedia selepas anda mula rawatan."

---

## 6. Apa jadi lepas Hantar

### Lapor Isu
1. Laporan ditulis ke jadual **`psy_audit_log`** dengan `action = 'issue.reported'` (foto disimpan dulu ke storage bucket **`issue-photos`**).
2. Isu muncul di tab **📋 Laporan Saya** dengan status **⏳ Menunggu**.
3. Staf nampak di [`roles/staff/issue.html`](../../../roles/staff/issue.html), buka di [`issue-detail.html`](../../../roles/staff/issue-detail.html), dan balas.
4. Bila staf balas (`action = 'issue.responded'`), status pesakit bertukar **✅ Dijawab** dan jawapan muncul dalam senarai + thread.
5. Mesej anda dalam thread direkod sebagai `action = 'issue.followup'`. Perbualan dua hala kekal di bawah `issue_id` yang sama, dipapar **realtime**.
6. Mesej tujuan di panel borang: *"Admin akan response dalam 24 jam."*

### Maklum Balas
1. Rating ditulis ke jadual **`psy_feedback`**:
   - Mingguan: `feedback_type = 'weekly'` + `week_number`, `coach_rating`, `supply_rating`.
   - Keseluruhan: `feedback_type = 'overall'` + `helpful_tags`.
2. Mesej "Feedback dihantar ✅". Minggu yang dirating ditanda **✓ (dirated)**.
3. Staf lihat agregat di [`roles/staff/feedback.html`](../../../roles/staff/feedback.html).
4. Klik pautan Google Review direkod ke `psy_audit_log` (`action = 'google_review.clicked'`).

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Sila pilih jenis isu" | Belum pilih kad **Jenis Isu**. Pilih satu dulu. |
| "Sila isi deskripsi masalah" | Field **Details Isu** kosong. Taip keterangan. |
| "Foto melebihi 5MB" | Foto terlalu besar. Kecilkan / pilih foto lain (maks 5MB). |
| "Laporan dihantar (foto gagal dimuat naik)" | Laporan **berjaya**, cuma upload foto gagal. Boleh sertakan semula foto dalam thread? (tidak — thread teks sahaja); hubungi staf dengan rujukan isu. |
| "Sila tulis balasan terlebih dahulu" | Kotak balasan thread kosong. Taip mesej dahulu. |
| Status kekal **⏳ Menunggu** | Staf belum balas. Jangkaan response dalam 24 jam. |
| Feedback dikunci 🔒 | Tiada pakej aktif/tamat. Feedback dibuka selepas rawatan bermula. |
| "Sila bagi rating overall" | Mod mingguan: belum klik bintang **Pengalaman minggu ini**. |
| Dropdown minggu kosong / "Belum ada minggu siap" | Belum ada sesi yang `hadir`/selesai. Tunggu sesi minggu berkenaan dijalankan. |

---

## 8. Rujukan teknikal
- Page lapor isu: [`roles/patient/issue.html`](../../../roles/patient/issue.html) · `submitIssue()` ~ baris 291
- Page thread: [`roles/patient/issue-thread.html`](../../../roles/patient/issue-thread.html) · `sendReply()` ~ baris 167, realtime ~ baris 217
- Page feedback: [`roles/patient/feedback.html`](../../../roles/patient/feedback.html) · `submitFeedback()` ~ baris 193, `submitWeeklyFeedback()` ~ baris 322
- Jadual: **`psy_audit_log`** (isu — `action` ∈ `issue.reported` / `issue.responded` / `issue.followup`) · **`psy_feedback`** (rating). Storage bucket foto: **`issue-photos`**. Lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md).
- Sebelah staf: [`roles/staff/issue.html`](../../../roles/staff/issue.html) · [`roles/staff/issue-detail.html`](../../../roles/staff/issue-detail.html) · [`roles/staff/feedback.html`](../../../roles/staff/feedback.html)


---


# ===== patient/pelan-rawatan.md =====

# Panduan: Pelan Rawatan & Jadual Harian 🔵

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Lihat pelan rawatan mingguan anda (sesi coaching, bimbingan, bekalan, mode F2F/online + link Gmeet), tetapkan & uruskan jadual sesi mingguan, jejak aktiviti harian (Jadual Harian), dan rekod bacaan kesihatan (vitals). Kebanyakan halaman ini **untuk dilihat sahaja** — coach yang merekod nota, vitals sesi, dan kepatuhan. Yang **anda** boleh ubah ialah jadual sesi, Jadual Harian, checklist matlamat, feedback, dan bacaan sendiri.

## 2. Siapa boleh buat
**Pesakit** yang sudah ada **pakej rawatan aktif**. Treatment Plan muncul automatik selepas anda beli pakej dan buat bayaran (lihat [pakej](pakej.html) & [payment](payment.html)). Tanpa pakej aktif, halaman tunjuk skrin "Belum Ada Pelan Rawatan".

## 3. Lokasi
- **Pelan Rawatan (utama):** Menu bawah → **Plan** (`roles/patient/plan.html`)
- **Butiran Mingguan:** dari kad minggu → **📋 Lihat butiran & bekalan minggu ini** (`roles/patient/plan-week.html?plan_id=…&week=N`)
- **Jadual Harian:** menu pesakit → **Jadual Harian** (`roles/patient/routine.html`)
- **Bacaan Saya (vitals):** menu pesakit → **Bacaan Saya** (`roles/patient/vitals.html`)

---

## 4. Langkah ringkas

1. Buka **Plan**. Kali pertama, sistem tunjuk **wizard setup jadual** — pilih pasangan hari & jam.
2. Sistem **auto-jadual** semua sesi untuk seluruh tempoh (cth 14 minggu × 2 sesi).
3. Skrol **Progress Mingguan** — setiap minggu tunjuk status sesi (Hadir, Ditempah, Tidak Hadir, dll.).
4. Klik satu minggu untuk buka butiran sesi; klik **📋 Lihat butiran & bekalan minggu ini** untuk nota coach, vitals, kepatuhan, bimbingan & bekalan.
5. Untuk sesi online, klik **🎥 Sertai Sesi Dalam Talian** (link Gmeet) pada minggu berkenaan.
6. Perlu tukar tarikh? Klik **Reschedule** / **Tempah** pada sesi tersebut.
7. Buka **Jadual Harian** untuk tick aktiviti harian; buka **Bacaan Saya** untuk catat vitals sendiri.

> Treatment Plan dijana **automatik** dari data pakej anda. Jika pakej aktif tapi pelan belum siap, halaman akan cuba siapkan sendiri — kalau gagal, hubungi coach/staff.

---

## 5. Apa yang anda boleh / tidak boleh ubah

Halaman ini banyak **VIEW** (lihat sahaja). Jadual di bawah jelaskan mana satu anda kawal sendiri.

### A. Pelan Rawatan — `plan.html`
| Item | Anda boleh ubah? | Nota |
|------|------------------|------|
| Setup jadual (pasangan hari + jam) | ✅ **Ya** (sekali, kali pertama) | Pilih **Jumaat + Sabtu** atau **Sabtu + Ahad**, dan jam setiap hari. Sistem auto-jadual sesi seluruh tempoh. |
| Tempah / Reschedule sesi | ✅ **Ya** | Klik **Tempah** (sesi belum dijadual) atau **Reschedule** (sesi ditempah). Hanya hari rawatan dibenarkan (lazimnya Jumaat/Sabtu/Ahad). |
| Skop reschedule | ✅ **Ya** | Pilih **"Tukar semua sesi seterusnya"** (auto-shift minggu lain) atau **"Tukar minggu ini sahaja"**. |
| Statistik (Total/Selesai/Progres/Aktif minggu) | ❌ Auto | Dikira sistem dari status sesi. |
| Status sesi (Hadir/Tidak Hadir/Selesai) | ❌ Coach | Coach tanda hadir semasa sesi. Sesi yang terlepas tarikh auto-jadi **Tidak Hadir**. |

### B. Butiran Mingguan — `plan-week.html`
| Item | Anda boleh ubah? | Nota |
|------|------------------|------|
| Checklist **Matlamat BPS-S** (Bio/Psycho/Social/Spiritual) | ✅ **Ya** | Tick matlamat yang anda dah laksanakan minggu ini. |
| Checklist **Goals & Homework** dari coach | ✅ **Ya** | Tick bila siap (disimpan dalam browser anda). |
| **Feedback Minggu Ini** (rating Coach & Bekalan + komen) | ✅ **Ya** | Beri bintang + komen; boleh tukar semula. |
| **Nota Coach / Nota Doktor** | ❌ Lihat sahaja | Direkod coach/doktor. Klik kad untuk baca penuh. |
| **Bacaan Vitals** minggu ini | ❌ Lihat sahaja | Direkod semasa sesi (untuk tambah sendiri → guna **Bacaan Saya**). |
| **Kepatuhan Rawatan** (madu, nafas, terapi bumi, dll.) | ❌ Lihat sahaja | Direkod coach semasa sesi. |
| **Bimbingan & Bekalan Minggu Ini** | ❌ Lihat sahaja | Tunjuk status tugasan & bekalan yang coach tanda semasa sesi. |
| **🎥 Sertai Sesi Dalam Talian** (Gmeet) | — | Butang muncul untuk sesi online yang **belum berlangsung**. |

> Jika sesi minggu itu **belum berlaku**, butiran (nota, vitals, rekod) belum tersedia dan kad akan dipudarkan — maklumat muncul selepas sesi berlangsung.

### C. Jadual Harian — `routine.html`
| Item | Anda boleh ubah? | Nota |
|------|------------------|------|
| Tick aktiviti harian (selesai/belum) | ✅ **Ya** | Tab **Hari Ini**. Reminder muncul automatik bila tiba masa aktiviti. |
| **✏️ Edit Jadual** (masa + aktiviti) | ✅ **Ya** | Ubah suai jadual peribadi anda. |
| **↺ Reset Default** | ✅ **Ya** | Kembali ke jadual default dari pakej (perubahan anda hilang). |
| Jadual default (template) | ❌ Datang dari pakej | Asalnya dari pakej; muncul kalau anda belum ubah suai. |
| Tab **Sejarah** (7/14/30/90 hari) | ❌ Lihat sahaja | Peratus kepatuhan harian dijejak automatik. |

### D. Bacaan Saya (vitals) — `vitals.html`
| Item | Anda boleh ubah? | Nota |
|------|------------------|------|
| **+ Catat Bacaan Sendiri** | ✅ **Ya** | BP, nadi, berat, tinggi, gula darah (RBS), HbA1c + nota. BMI auto dikira. |
| **✏️ Edit** bacaan | ✅ **Ya** (terhad) | Hanya bacaan **sendiri** bertarikh **hari ini** boleh diedit. |
| Bacaan oleh **Staf Konsultasi** | ❌ Lihat sahaja | Direkod staf semasa sesi. |
| Kad ringkasan terkini & jadual sejarah | ❌ Auto | Tapis ikut sumber: Semua / Staf / Rekod Sendiri. |

---

## 6. Apa jadi lepas anda buat tindakan
1. **Setup jadual:** sistem tulis pilihan (`preferred_pair`, jam) ke **`psy_treatment_plans`** dan jana semua sesi ke **`psy_plan_weekly_progress`** (status `booked`, atau `reschedule` kalau jatuh pada cuti konsultasi). Audit: `plan.schedule_setup`.
2. **Tempah / Reschedule:** cipta/kemaskini janji temu (`psy_appointments`) + kemaskini sesi (`psy_plan_weekly_progress`). Pilih "tukar semua" akan **cascade shift** sesi seterusnya. Audit: `plan.session_booked` / `plan.session_rescheduled` / `plan.cascade_shift`.
3. **Sesi terlepas:** sesi yang lepas tarikh tanpa hadir auto-tanda **Tidak Hadir** (`cancel`); sistem cadang tarikh ganti. Coach boleh buka **minggu tambahan berbayar** — banner kuning muncul dengan butang **Bayar** (lihat [peraturan absence](../../sistem/03-modul.md)).
4. **Checklist matlamat BPS-S:** tick ditulis ke **`psy_plan_check_ins`**; progress bar dikemaskini.
5. **Feedback minggu:** ditulis ke **`psy_feedback`** (`feedback_type='weekly'`) — sama sumber yang staf lihat.
6. **Jadual Harian (edit):** jadual peribadi disimpan ke **`psy_patients.daily_schedule`**; tick harian ke **`psy_daily_completions`**.
7. **Bacaan sendiri:** ditulis ke **`psy_vitals`** (`source='patient_self'`), auto-tag plan & minggu semasa; tinggi dikemaskini pada rekod pesakit.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Belum Ada Pelan Rawatan" | Belum ada pakej aktif (atau dah luput). Pilih pakej di [pakej](pakej.html) & bayar. |
| "Pelan Rawatan Akan Disiapkan" | Pakej aktif tapi pelan belum dijana. Refresh; kalau berterusan, hubungi coach/staff. |
| Wizard setup muncul lagi | Anda belum sahkan jadual. Pilih pasangan hari + jam, semak preview, tekan **Sahkan & Auto-Jadual**. |
| "Hanya Jumaat, Sabtu, Ahad dibenarkan" | Sesi rawatan hanya pada hari yang dibenarkan. Pilih hari yang sah. |
| "Konsultasi tutup pada tarikh ini" | Tarikh jatuh pada cuti konsultasi. Pilih hari lain. |
| Banner kuning "Sesi terlepas — bayar untuk lanjutkan" | Anda terlepas sesi; minggu tambahan dibuka. Tekan **Bayar Sekarang** atau hubungi coach. |
| Nota/vitals minggu kosong & kad pudar | Sesi belum berlangsung. Maklumat muncul selepas sesi. |
| Tak nampak butang **🎥 Sertai Sesi** | Butang hanya untuk sesi **online** yang **akan datang** dan ada link Gmeet. Sesi lepas/F2F tiada butang. |
| Tak boleh edit bacaan lama | Hanya bacaan **sendiri** bertarikh **hari ini** boleh diedit. Bacaan staf & bacaan lama dikunci. |
| Jadual Harian kosong / "perlu pakej aktif" | Perlu pakej aktif + jadual harian dari pakej. Tekan **✏️ Edit Jadual** untuk tambah sendiri. |

---

## 8. Rujukan teknikal
- Page: [`roles/patient/plan.html`](../../../roles/patient/plan.html) · setup wizard `confirmScheduleSetup()`, tempah `confirmBooking()`, auto-miss `autoMarkMissedAndExtend()`
- Page: [`roles/patient/plan-week.html`](../../../roles/patient/plan-week.html) · `loadWeekDetail()`, checklist `toggleCheckIn()`, feedback `submitWeekFeedback()`
- Page: [`roles/patient/routine.html`](../../../roles/patient/routine.html) · `saveDailyEdit()`, `toggleDailyDone()`
- Page: [`roles/patient/vitals.html`](../../../roles/patient/vitals.html) · `saveSelfVitals()`
- Jadual: `psy_treatment_plans`, `psy_plan_weekly_progress`, `psy_plan_check_ins`, `psy_feedback`, `psy_daily_completions`, `psy_vitals`, `psy_appointments`, `psy_plan_compliance` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))


---


# ===== patient/rekod-surat-library.md =====

# Panduan: Rekod Perubatan, Mohon Surat Rasmi & Self-Help Library/FAQ 🔵

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Tiga perkhidmatan layan-diri (self-service) untuk pesakit ISW dalam satu panduan:

- **(A) Rekod Perubatan** — simpan & muat naik dokumen kesihatan anda sendiri (laporan perubatan, hasil ujian, imbasan X-Ray/MRI/CT, surat rujukan) supaya tersimpan selamat dan boleh dirujuk oleh doktor yang merawat.
- **(B) Mohon Surat Rasmi** — minta surat rasmi ISW (cth: KWSP, PERKESO, pengesahan rawatan) — pilih jenis surat + nyatakan sebab, kemudian staf yang **lulus & tandatangan**. Surat siap masuk terus ke akaun anda untuk dibuka/dicetak.
- **(C) Self-Help Library & FAQ** — tonton video, baca artikel dan cari jawapan Soalan Lazim tentang kesihatan mental/fizikal dan program ISW.

## 2. Siapa boleh buat
Mana-mana **pesakit** yang sudah ada akaun aktif (role `patient`) dan rekod pesakit (`patientRecord`).

- **Rekod Perubatan & Surat Rasmi** memerlukan anda mempunyai rekod pesakit yang sah.
- **Library/FAQ** boleh dibaca oleh semua pesakit; sesetengah kandungan **dikunci ikut pakej** — anda hanya nampak/buka kalau pakej langganan anda padan. (Lihat sisi staf: [Surat Rasmi](../staff/surat-rasmi.md), [Library & FAQ](../staff/library-faq.md).)

## 3. Lokasi
- **Rekod Perubatan (senarai):** `roles/patient/rekod-perubatan.html`
  - Tambah baru: butang **Muat Naik** → `roles/patient/rekod-tambah.html`
  - Lihat satu rekod: klik baris/kad → `roles/patient/rekod-detail.html?id=...`
- **Surat Rasmi:** `roles/patient/surat.html` (mohon surat + buka surat siap)
- **Library:** `roles/patient/library.html` → buka satu kandungan `roles/patient/library-detail.html?id=...`
- **FAQ:** `roles/patient/faq.html` (juga boleh dibuka dari pil **❓ FAQ** dalam Library)

---

## 4. Langkah ringkas

### (A) Muat naik rekod perubatan
1. Buka **Rekod Perubatan** → klik **Muat Naik** (banner biru atau butang atas).
2. Di borang **Tambah Rekod Perubatan**, isi **Nama Dokumen** (wajib) dan pilih **Jenis Dokumen**.
3. (Pilihan) isi **Sumber / Klinik**, **Tarikh Dokumen**, **Catatan**.
4. **Muat Naik Dokumen:** seret-lepas atau **Pilih Fail** (PDF/JPG/PNG/DOC/DOCX, maks 10MB/fail, sehingga 5 fail).
5. Klik **Simpan Rekod**. Anda diarah balik ke senarai; rekod baru bermula status **⏳ Menunggu** semakan staf.

### (B) Mohon surat rasmi
1. Buka **Surat Rasmi** (`surat.html`).
2. Di kad **Mohon Surat Baru**, pilih **Jenis Surat** dari senarai (atau **Lain-lain (taip sendiri)**).
3. Kalau pilih **Lain-lain**, isi **Nama Surat**.
4. Isi **Sebab / Tujuan Permohonan** (wajib).
5. Klik **Hantar Permohonan**. Permohonan muncul di **Permohonan Saya** dengan status **Menunggu**.
6. Bila staf lulus & tandatangan, surat muncul di **Surat Saya** → klik **Buka / Cetak** untuk cetak atau simpan PDF.

### (C) Guna library (tonton video / baca artikel / FAQ)
1. Buka **Library** (`library.html`).
2. Tukar tab **Video** ↔ **Artikel**; pilih pil kategori; atau **Cari kandungan…**.
3. Klik kad → halaman **library-detail** (video main terus / artikel boleh dibaca). Boleh **🔖 Simpan** dan beri maklum balas **👍/👎**.
4. Untuk soalan lazim, klik pil **❓ FAQ** (atau buka `faq.html`) → cari/pilih topik → klik soalan untuk buka jawapan.

---

## 5. Field — wajib vs pilihan

### (A) Tambah Rekod Perubatan (`rekod-tambah.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Nama Dokumen** `*` | ✅ **WAJIB** | Block kalau kosong. Cth: `Laporan Konsultasi`, `Keputusan Ujian Darah`. |
| **Jenis Dokumen** `*` | ✅ (ada default) | 📄 Laporan Perubatan · 🧪 Hasil Ujian · 🩻 Imbasan (Imaging) · ✉️ Surat Rujukan · 📁 Lain-lain. |
| Sumber / Klinik | Pilihan | Cth: `Klinik Ibnu Sina`, `Pathlab Malaysia`. |
| Tarikh Dokumen | Pilihan | Tarikh pada dokumen (bukan tarikh muat naik). |
| Catatan | Pilihan | Maks 500 aksara. |
| **Fail** `*` | ✅ **WAJIB** | Sekurang-kurangnya 1 fail. PDF/JPG/JPEG/PNG/DOC/DOCX. Maks **10MB/fail**, maks **5 fail** sekali muat naik. |

> Kalau anda muat naik >1 fail, setiap fail jadi satu rekod berasingan dengan tajuk `Nama Dokumen — namafail`.

### (B) Borang Mohon Surat (`surat.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Jenis Surat** `*` | ✅ **WAJIB** | Dari senarai templat aktif kategori pesakit, **atau** **Lain-lain (taip sendiri)**. Pilih templat akan papar penerangan + **👤 Perlu kelulusan: [nama]** kalau ada penyelaras ditetapkan. |
| **Nama Surat** | Wajib bila pilih **Lain-lain** | Cth: `Surat Permohonan KWSP`. Hanya muncul bila pilih custom. |
| **Sebab / Tujuan Permohonan** `*` | ✅ **WAJIB** | Cth: `untuk failkan claim KWSP bulan depan`. Butang **Hantar Permohonan** kekal mati sehingga sebab + jenis surat diisi. |

### (C) Library & FAQ — kawalan pada page (bukan borang)
| Kawalan | Di mana | Nota |
|---------|---------|------|
| Tab **Video / Artikel** | Library | Tukar jenis kandungan dipapar. |
| Pil **Kategori** | Library | Cth: Kesihatan Mental, Minda & Emosi, Hubungan & Sosial, Kebiasaan Sihat, Panduan Praktikal — + pil **❓ FAQ** ke `faq.html`. |
| **Cari kandungan…** / **Filter** | Library | Filter: Susun Ikut (Terbaru / Paling Ditonton / Terlama) + Status (Semua / Disimpan Sahaja). |
| **🔖 Simpan** | Library / detail | Tambah/buang bookmark. Boleh tapis "Disimpan Sahaja". |
| **👍 / 👎** | library-detail / FAQ | Maklum balas "Adakah kandungan ini membantu?". |
| **Cari soalan** + pil **Topik** | FAQ | Klik soalan untuk buka/tutup jawapan (accordion). |
| 🔒 ikon | Library | Kandungan terkunci — perlu pakej lain. Klik = mesej "perlukan pakej lain". |

---

## 6. Apa jadi lepas hantar

### (A) Rekod Perubatan
1. Fail dimuat naik ke storage bucket **`medical-reports`** (folder `patient/<id>`).
2. Satu/lebih rekod ditulis ke jadual **`psy_medical_reports`** — `report_type`, `title`, `source`, `sample_date`, `notes`, `status='ready'`, `review_status='pending'`, `uploaded_by`.
3. Status mula sebagai **⏳ Menunggu**; bila staf/doktor semak ia jadi **✅ Disemak** (`review_status='diluluskan'`) dan boleh ada **Komen Doktor** di `rekod-detail.html`.
4. Di **rekod-detail**, anda boleh **⬇️ Muat Turun** (signed URL 1 jam). **🗑️ Padam** hanya untuk rekod yang **anda** muat naik **dan belum disemak**.

### (B) Surat Rasmi
1. Permohonan ditulis ke **`psy_letter_requests`** (`template_code`, `template_name`, `reason`, `assigned_signer_id`, `status='pending'`).
2. Kalau templat ada penyelaras, staf itu dapat **notifikasi** permohonan baru.
3. Staf lulus → surat dijana ke **`psy_letter_issued`** (ada `ref_number`, `signed_by_name`, tandatangan) → muncul di **Surat Saya**. Klik **Buka / Cetak** render surat penuh (letterhead) dalam tab baru untuk cetak/PDF.
4. Kalau **Ditolak** → status `rejected` + **alasan** dipapar merah di **Permohonan Saya**.

### (C) Library / FAQ
1. **Buka kandungan** menambah kiraan tontonan (`view_count` / RPC `psy_library_bump_view`).
2. **🔖 Simpan** ditulis/dipadam dari **`psy_library_bookmarks`**.
3. **👍/👎** disimpan ke **`psy_library_feedback`** (satu undi per kandungan, boleh tukar).
4. Library hanya papar kandungan **aktif** (`is_active`) dan yang **padan pakej** anda. FAQ hanya item `media_type='faq'` yang aktif.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Nama dokumen wajib diisi" | Isi **Nama Dokumen** dulu. |
| "Sila muat naik sekurang-kurangnya 1 fail" | Pilih/seret sekurang-kurangnya 1 fail sebelum Simpan. |
| "[nama] melebihi 10MB" | Fail terlalu besar — kecilkan/mampatkan dulu (had 10MB/fail). |
| "Maksimum 5 fail" | Had 5 fail sekali muat naik. Hantar berbaki dalam muat naik berasingan. |
| Butang 🗑️ Padam Rekod tak nampak | Hanya boleh padam rekod yang **anda** muat naik **dan belum disemak**. Selepas disemak ia dikunci. |
| "Gagal padam (mungkin dah disemak)" | Rekod sudah disemak staf — tak boleh dipadam. |
| Butang **Hantar Permohonan** kekal kelabu | **Jenis Surat** dan **Sebab** mesti diisi (Nama Surat juga kalau pilih Lain-lain). |
| Jenis surat yang dicari tiada dalam senarai | Pilih **Lain-lain (taip sendiri)** dan terangkan dalam Nama Surat + Sebab. |
| "Belum ada surat dikeluarkan" / status **Menunggu** lama | Permohonan masih menunggu staf lulus & tandatangan (anggaran 1–2 hari bekerja). |
| Permohonan **Ditolak** | Baca alasan merah di **Permohonan Saya**, baiki & mohon semula. |
| 🔒 "Kandungan ini memerlukan pakej lain" | Kandungan dikunci ikut pakej — perlu naik taraf pakej untuk akses. |
| "Tiada kandungan dijumpai" / "Tiada soalan dijumpai" | Tiada padanan untuk carian/filter/tab semasa — kosongkan carian, tukar tab/topik, atau **Papar Semua**. |

---

## 8. Rujukan teknikal
- Rekod Perubatan: [`roles/patient/rekod-perubatan.html`](../../../roles/patient/rekod-perubatan.html) · [`rekod-tambah.html`](../../../roles/patient/rekod-tambah.html) (`saveRec()`) · [`rekod-detail.html`](../../../roles/patient/rekod-detail.html) (`downloadDoc()`, `delDoc()`)
- Surat Rasmi (pesakit): [`roles/patient/surat.html`](../../../roles/patient/surat.html) — `submitRequest()`, `viewLetter()` · sisi staf: [Surat Rasmi](../staff/surat-rasmi.md)
- Library/FAQ (pesakit): [`roles/patient/library.html`](../../../roles/patient/library.html) · [`library-detail.html`](../../../roles/patient/library-detail.html) · [`faq.html`](../../../roles/patient/faq.html) · sisi staf: [Library & FAQ](../staff/library-faq.md)
- Jadual DB: `psy_medical_reports`, `psy_medical_report_comments`, `psy_letter_requests`, `psy_letter_issued`, `psy_letter_templates`, `psy_library_items`, `psy_library_bookmarks`, `psy_library_feedback` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Storage bucket: `medical-reports` (rekod perubatan), `library-media` (kandungan library)
- Modul berkaitan: [03-modul.md](../../sistem/03-modul.md) · Peranan & akses: [05-peranan-akses.md](../../sistem/05-peranan-akses.md)


---


# ===== staff/auto-mesej.md =====

# Panduan: Mesej Automatik WhatsApp 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Urus semua **mesej WhatsApp automatik** yang sistem hantar sendiri — peringatan acara, broadcast sesi berulang (cth Manzil Live), peringatan Catatan Harian, dan alert kepatuhan kepada coach. Dari satu skrin, staf boleh **edit teks (template)**, **set masa**, dan **hidup/matikan** setiap mesej. Ubah di sini terus berkesan — tiada perlu pasang semula (re-deploy) Edge Function.

> Penting: skrin ini **tidak** menghantar mesej satu-satu secara manual. Ia mengkonfigurasi mesej yang dicetus automatik oleh cron (setiap 15 minit). Hantaran sebenar melalui **GoHighLevel (GHL)**.

## 2. Siapa boleh buat
- **Edit (template, masa, on/off):** Staf dengan kebenaran modul **`auto_messages`** — biasanya **`super_admin`**.
- **Lihat sahaja:** `manager` (view, tak boleh ubah).
- (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

## 3. Lokasi
- **Senarai mesej automatik:** Sidebar staf → kumpulan **KOMUNIKASI → Mesej Automatik** (`roles/staff/auto-mesej.html`)
- **Borang edit:** klik butang **Edit** pada mana-mana mesej dalam senarai → modal edit terbuka.

> Tiada butang "Tambah" — set mesej automatik telah disemai (seed) oleh migrasi. Staf hanya **edit** mesej sedia ada.

---

## 4. Langkah ringkas

1. Buka **Mesej Automatik**. Setiap kad papar: nama, jenis pencetus (label warna), status (● Aktif / ○ Tidak aktif), saluran, dan ringkasan masa.
2. Klik **Edit** pada mesej yang nak diubah.
3. Set **masa** ikut jenis mesej (lihat Seksyen 5):
   - Sebelum acara/sesi → pilih **berapa minit sebelum** (15/30/60 atau taip sendiri).
   - Broadcast berulang → pilih **hari**, **masa sesi**, **minit awal**, **pautan**, **saluran**, **sasaran**.
   - Harian → set **masa hantar setiap hari** (cth 20:00).
   - Serta-merta → tiada tetapan masa.
4. Edit **Teks Mesej**. Guna chip **Sisip** untuk masukkan placeholder (cth `{nama}`).
5. Semak **Pratonton** (gaya gelembung WhatsApp dengan nilai sampel).
6. Tanda / buang tanda **"Aktifkan mesej automatik ini"** untuk hidup/matikan.
7. Klik **💾 Simpan**.

> Pratonton guna nilai sampel (cth `Encik Ali`, `Kelas Mindfulness`) — bukan data sebenar. Ia hanya untuk lihat rupa mesej.

---

## 5. Field — wajib vs pilihan

### Header kad (senarai)
Bukan field input — hanya paparan ringkas setiap mesej:
| Item | Nota |
|------|------|
| Nama + label jenis | Label warna ikut `trigger_type` (Sebelum acara · Harian · Broadcast berulang · Serta-merta). |
| Status | **● Aktif** (hijau) atau **○ Tidak aktif** (kelabu). |
| Saluran + masa | Cth `📲 whatsapp · ⏱️ 30 minit sebelum`. |

### Modal edit — field bersama (semua jenis)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Teks Mesej** `*` | ✅ **WAJIB** | Tak boleh kosong — sistem block. Sokong placeholder `{...}`. |
| Aktifkan mesej automatik ini | Pilihan | Checkbox = `is_active`. Tak tanda = mesej tak akan dihantar walaupun masa kena. |
| Sisip (chip placeholder) | — | Klik untuk masukkan placeholder sah pada kursor. Senarai chip ikut mesej. |

### Field masa — bergantung jenis pencetus
| Jenis (`trigger_type`) | Field masa | Wajib? | Nota |
|------------------------|-----------|--------|------|
| `before_event` / `before_session` | **Berapa lama sebelum** (minit) | ✅ ≥ 1 | Butang cepat 15/30/60 minit atau taip sendiri. |
| `recurring_broadcast` | **Hari hantar** `*` + **Masa sesi** `*` + **minit awal** `*` + **Saluran** `*` | ✅ | Lihat jadual broadcast bawah. |
| `daily_reminder` | **Hantar setiap hari pukul** (masa) | ✅ | Cth `20:00`. |
| `on_action` | (tiada) | — | "⚡ Dihantar serta-merta bila tindakan berlaku." |

### Field tambahan — Broadcast Berulang (`recurring_broadcast`) sahaja
| Field | Wajib? | Nota |
|-------|--------|------|
| **Hari hantar (setiap minggu)** `*` | ✅ sekurang-kurangnya 1 | Pilih Isn–Ahd (0=Ahad..6=Sabtu). |
| **Masa sesi bermula** `*` | ✅ | Masa sesi sebenar (cth 08:45). Mesej dihantar *minit awal* sebelum ini. |
| **Minit awal** `*` | ✅ ≥ 1 | Set di bahagian "berapa lama sebelum". |
| **Pautan (Google Meet)** | Pilihan | Mengisi placeholder `{pautan}`. |
| **Saluran hantar** `*` | ✅ sekurang-kurangnya 1 | 📲 WhatsApp · 🔔 Notifikasi app · 📢 Pengumuman. |
| **Sasaran** | Default semua | 👥 Semua pesakit **atau** 🎯 Pakej tertentu (pilih pakej). |

### Placeholder yang disokong
Diisi automatik oleh runner masa hantar:
| Placeholder | Maksud |
|-------------|--------|
| `{nama}` | Nama pesakit (atau coach untuk alert kepatuhan). |
| `{acara}` | Tajuk acara (peringatan acara). |
| `{masa}` | Masa acara/sesi. |
| `{lead}` | Berapa lama lagi (cth `30 minit`). |
| `{pautan}` | Link Google Meet / lokasi. |
| `{senarai}` | Senarai isu kepatuhan (alert coach sahaja). |

> Editor untuk medan **`rule`** (ambang alert kepatuhan — cth `min_score`, `min_days_missing`) **belum ada di UI**. Ubah ambang ini buat masa ini melalui SQL.

---

## 6. Apa jadi lepas Simpan
1. Rekod dikemaskini ke jadual **`psy_auto_messages`** (update — bukan insert; satu baris setiap mesej, kunci `key`).
2. `updated_at` + `updated_by` direkod.
3. Banner **"Mesej automatik dikemaskini ✅"** muncul; senarai dimuat semula.
4. **Berkesan serta-merta** — runner (Edge Function `event-reminders`) baca konfig terkini pada cetusan cron seterusnya (setiap 15 minit). Tiada re-deploy perlu.
5. Jika **Aktif** + masa kena (dalam window ±10 minit) → runner berkenaan hantar mesej via GHL.

### Runner mana aktif? (status semasa)
Cron `event-reminders` jalankan **4 runner** setiap 15 minit. Setiap satu dipacu satu baris `psy_auto_messages` dan di-gate oleh `is_active`:

| # | Runner | Mesej (`key`) | Jenis | Status |
|---|--------|---------------|-------|--------|
| 1 | `runEventReminders` | `event_reminder` — Peringatan Acara & Kelas | `before_event` | 🟢 **LIVE** (testing). Hantar WA kpd pendaftar sebelum acara. |
| 2 | `runBroadcasts` | `manzil_live` — Live Bacaan Manzil | `recurring_broadcast` | ⚪ **Draf (off)**. Lengkapkan link + aktifkan. WA+loceng+Pengumuman. |
| 3 | `runCatatanHarianReminder` | `catatan_harian` — Peringatan Catatan Harian | `daily_reminder` | ⚪ **Draf (off)**. WA kpd pesakit aktif yang belum isi Catatan Harian. |
| 4 | `runKepatuhanAlerts` | `kepatuhan_alert` — Alert Coach Kepatuhan | `daily_reminder` | ⚪ **Draf (off)**. Alert gabungan kpd COACH (loceng + `risk.html`). |
| — | (tiada runner) | `birthday` — Ucapan Hari Jadi | `daily_reminder` | ⚪ **Draf (off)** — pencetus belum disambung. |

> **Deploy production masih pending.** Runner 3 & 4 sengaja `is_active=false` — staf hidupkan di UI bila GHL sedia & sudah diuji. Aliran **dua-hala reschedule** (tanya boleh hadir → auto-reschedule) = **Fasa 2**, belum dibina.

> ⚠️ Broadcast (#2) hantar ke **semua pesakit** sasaran = volume WA besar. Uji guna pakej ujian / diri sendiri dahulu sebelum hidupkan untuk semua.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Teks mesej tak boleh kosong." | Isi field **Teks Mesej** dulu. |
| "Pilih sekurang-kurangnya satu hari." | Broadcast berulang: pilih ≥ 1 hari hantar. |
| "Sila set masa sesi bermula." | Broadcast berulang: isi masa sesi (cth 08:45). |
| "Sila set berapa minit sebelum." | Set minit awal (≥ 1). |
| "Pilih sekurang-kurangnya satu saluran." | Broadcast berulang: tanda ≥ 1 (WhatsApp / Notifikasi / Pengumuman). |
| "Sila set masa hantar harian." | Jenis harian: isi masa (cth 20:00). |
| Mesej Aktif tapi pesakit tak terima | Semak: (a) masih dalam window ±10 min vs masa set; (b) GHL secret/cron berfungsi; (c) pesakit ada **no. telefon** sah; (d) untuk broadcast — sasaran pakej betul; (e) untuk Catatan Harian — pesakit belum isi log hari itu. |
| Broadcast hantar 2 kali / tak hantar lagi hari ini | Normal — dedup harian guna `last_broadcast_at` (1×/hari/mesej). |
| Nak ubah ambang alert (min skor, hari miss) | Belum ada di UI — ubah medan `rule` (jsonb) via SQL. |
| Modul tak nampak di sidebar | Tiada kebenaran `auto_messages`. Hanya `super_admin` (edit) / `manager` (view). |

---

## 8. Rujukan teknikal
- Page: [`roles/staff/auto-mesej.html`](../../../roles/staff/auto-mesej.html) · `saveMsg()` ~ baris 294, `load()` ~ baris 336
- Runner: [`supabase/functions/event-reminders/index.ts`](../../../supabase/functions/event-reminders/index.ts) — 4 runner (`runEventReminders`, `runBroadcasts`, `runCatatanHarianReminder`, `runKepatuhanAlerts`)
- Jadual: `psy_auto_messages` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Migrasi:
  - [`supabase/migrations/20260623_auto_messages.sql`](../../../supabase/migrations/20260623_auto_messages.sql) — rangka + seed `event_reminder`/`catatan_harian`/`birthday`
  - [`supabase/migrations/20260624_auto_messages_broadcast.sql`](../../../supabase/migrations/20260624_auto_messages_broadcast.sql) — `recurring_broadcast` + seed `manzil_live`
  - [`supabase/migrations/20260625_catatan_harian_reminder.sql`](../../../supabase/migrations/20260625_catatan_harian_reminder.sql) — sambung pencetus Catatan Harian
  - [`supabase/migrations/20260626_kepatuhan_alerts.sql`](../../../supabase/migrations/20260626_kepatuhan_alerts.sql) — lajur `rule` + seed `kepatuhan_alert`
- Automasi & status deploy: [04-automasi-edge.md](../../sistem/04-automasi-edge.md)


---


# ===== staff/inventori.md =====

# Panduan: Inventori & Kit Prosedur 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Urus semua bekalan fizikal yang sistem guna — tambah item inventori (madu, supplement, sarung tangan, DNA kit, dll.), laras stok bila terima/guna/buang, dan bina **Kit Prosedur** (himpunan beberapa item jadi satu set). Stok ini akan **auto-tolak** bila coach tanda sesi *Hadir* dan **auto-sync** dengan stok produk kedai (ikut nama yang sama).

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`inventory`**:
- **Lihat** senarai & detail — semua staf yang ada akses modul (`view`).
- **Tambah / Edit / Laras stok** — perlu kebenaran `create` / `edit` (biasanya `admin`, `manager`).
- **Lulus / Tolak permohonan beli** — perlu kebenaran `approve` (manager).
- **Tandakan Dibeli** (terima stok PO) — `admin`.
- **Bina / Edit Kit Prosedur** — `admin` atau `manager`.

(Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

## 3. Lokasi
- **Senarai inventori:** Sidebar staf → **OPERASI → Inventori** (`roles/staff/inventory.html`)
  - 3 tab: **📦 Inventori** · **🧰 Kit Prosedur** · **📋 Permohonan**
- **Detail item:** klik mana-mana baris item → `roles/staff/inventory-detail.html?id=…`
- **Bina / edit kit:** tab **Kit Prosedur** → **+ Tambah Kit**, atau page khas Kit Prosedur (`roles/staff/kit-prosedur.html`) → borang `roles/staff/kit-edit.html`

---

## 4. Langkah ringkas

### A. Tambah item inventori
1. Buka **Inventori** → tab **📦 Inventori** → klik **+ Tambah Item**.
2. Isi **Nama Item** + pilih **Jenis Penggunaan** (Bekalan Coaching / Bekalan Perubatan).
3. Pilih **Kategori** + **Unit**, isi **Stok Semasa** + **Stok Minimum**.
4. (Pilihan) Set **Auto-PO** + toggle **Perlu Kelulusan Manager**.
5. Klik **💾 Simpan Item**.

### B. Laras stok
1. Buka **detail item** (klik baris) → **⚖️ Laras Stok**.
2. Pilih **Jenis Pergerakan**: `+ Masuk` (terima), `− Guna / Buang`, atau `= Set semula` (stock count).
3. Isi **Kuantiti** + (pilihan) **Nota** → **Simpan**.

> Modal ringkas di senarai (tab Inventori) hanya `Laras Stok = set stok baru`. Modal di **detail item** ada pilihan +/−/set yang lebih lengkap.

### C. Bina Kit Prosedur
1. Tab **🧰 Kit Prosedur** → **+ Tambah Kit**.
2. Isi **Nama Kit** (+ Kategori, Deskripsi pilihan).
3. Klik **+ Tambah Item** → taip **nama item** + **Qty** + **Unit** untuk setiap baris.
4. Klik **Simpan Kit**.

> Kit ialah cara pintas untuk masukkan satu set bekalan ke dalam minggu pakej sekali gus — bukannya pilih item satu-satu.

---

## 5. Field — wajib vs pilihan

### A. Modal Tambah/Edit Item (`inventory.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Nama Item** `*` | ✅ **WAJIB** | Sistem block kalau kosong. Nama ini juga kunci **auto-sync** dengan produk (mesti sama betul-betul). Cth: `Madu Tualang`, `DNA Test Kit`. |
| **Jenis Penggunaan** `*` | ✅ **WAJIB** | `Bekalan Coaching` (umum/`general`) atau `Bekalan Perubatan` (pakej). Tentukan cara kira keperluan stok — lihat nota di bawah jadual. |
| **Kategori** `*` | Disyorkan | Senarai tetap: Bekalan Coaching · Bekalan Rawatan · Madu & Produk · Starter Kit · Suplemen & Resepi · Buku & Bahan Cetak · Brosur & Marketing · Peralatan Konsultasi. |
| **Unit** `*` | Disyorkan | Unit · Botol · Kotak · Paket · Liter · Gram · Kilogram. |
| **Stok Semasa** `*` | Disyorkan | Jumlah stok ada sekarang. Default `0`. |
| **Stok Minimum (Reorder)** `*` | Disyorkan | Tahap reorder. Untuk jenis *Pakej* ia hanya **fallback** bila tiada patient aktif; untuk *Umum* ia angka trigger Auto-PO sebenar. |
| Kuantiti Auto-PO | Pilihan | Kuantiti tetap untuk top-up. Kosong = sistem auto-kira (pulih ke keperluan penuh, atau min × 3). |
| Auto-Trigger Purchase Invoice | Default OFF | Toggle. ON = sistem jana PI/permohonan beli automatik bila stok rendah. |
| Perlu Kelulusan Manager | Default OFF | ON = permohonan beli item ini perlu lulus manager dulu sebelum dibeli. |

> **Jenis Penggunaan menentukan logik stok:**
> - **Bekalan Perubatan / Pakej (`package`)** — sistem **auto-kira keperluan sebenar** dari sesi pesakit yang betul-betul dijadualkan (belum hadir) dalam **14 hari akan datang** (`shared/inventoryForecast.js` — `computeForecastForRange()`), bukan anggaran pukal sepanjang tempoh pakej. Auto-PO trigger bila stok **≤ keperluan 14 hari** tu. "Stok Minimum" jadi fallback sahaja (dipakai bila tiada sesi dijadualkan lagi dlm julat tu).
> - **Bekalan Coaching / Umum (`general`)** — barang guna merentas semua aktiviti (sarung tangan, swab, tissue). Tiada auto-kira; Auto-PO trigger bila stok **≤ Stok Minimum**.
>
> Auto-PO dikendalikan **client-side sepenuhnya** (`checkAutoPO()` di `inventory.html`, jalan setiap kali page dibuka + turut dipanggil dari `dashboard.html`). Trigger DB lama (`psy_inventory_auto_request`) dibuang 29 Ogos 2026 — ia guna medan `max_qty` yang tak pernah diisi di mana-mana borang, jadi sentiasa fallback ke `min_qty` untuk semua item & tak selaras dgn logik ni.

### B. Modal Edit Item (di `inventory-detail.html`)
Edit lanjut + maklumat supplier. Hanya **Nama** wajib. Field tambahan: Penerangan Produk, **Nama Supplier**, **Kos seunit (RM)**, **Lead time (hari)**, **Cadangan PO Min/Max**, checkbox **Perlu kelulusan**. (Disimpan dalam `supplier_info` JSON.)

### C. Modal Laras Stok
| Field | Wajib? | Nota |
|-------|--------|------|
| **Jenis Pergerakan** | (di detail) | `+ Masuk` · `− Guna / Buang` · `= Set semula`. |
| **Kuantiti / Stok Baru** `*` | ✅ **WAJIB** | Mesti > 0. |
| Catatan / Nota | Pilihan | Sebab pelarasan (cth: "Pembelian bulanan", "stok rosak"). |

### D. Borang Kit Prosedur (`kit-edit.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Nama Kit** `*` | ✅ **WAJIB** | Cth: `IV Drip Setup`. |
| Kategori | Pilihan | Default `Umum`. Cth: `IV Therapy`. |
| Deskripsi | Pilihan | Huraian ringkas bila kit ini digunakan. |
| **Senarai Item** `*` | ✅ **WAJIB** | Mesti ada **sekurang-kurangnya 1 item**. Setiap baris: **Nama Item** + **Qty** (>0) + **Unit**. |

> Item kit dipadan ke inventori **ikut nama** (taip nama sama macam item inventori) supaya auto-deduct berfungsi bila kit digunakan dalam pakej.

---

## 6. Apa jadi lepas Simpan

### Tambah/Edit item
1. Rekod ditulis ke **`psy_inventory_items`** (insert kalau baru, update kalau edit).
2. Item muncul dalam senarai, keperluan (`forecast_required`) dikira semula ikut sesi pesakit sebenar dijadualkan dlm 14 hari akan datang.
3. Kalau stok di bawah threshold, **Auto-PO** boleh jana permohonan ke `psy_inventory_requests` (notifikasi ke admin/manager).

### Laras stok
1. `qty_in_stock` dikemaskini.
2. **Auto-sync ke produk:** sistem cari produk di `psy_products` dengan **nama sama** (case-insensitive) dan set stoknya sama → banner papar "Produk juga di-sync". (Lihat [`shared/stockSync.js`](../../../shared/stockSync.js).)

### Bina/edit kit
1. Rekod ditulis ke **`psy_procedure_kits`** (field `items` = JSON array `{item_name, qty, unit}`).
2. Kit boleh dipilih sebagai bekalan minggu dalam [borang pakej](tambah-pakej.md) (rujukan `{kit_id, qty}` — sistem kembang jadi sub-item).

### Auto-tolak stok (bila coach tanda *Hadir*)
1. Di `plan-week.html`, bila coach tanda sesi **✅ Hadir**, sistem panggil `deductSessionSupplies()`.
2. Sistem baca `coaching_schedule[minggu].supplies` dari pelan rawatan pesakit.
3. **Skip** kalau: sesi `is_extension`, mode `online`, item tiada `item_id`, qty 0, atau `auto_stock = false`.
4. Untuk setiap bekalan sah → `qty_in_stock` ditolak (tak boleh bawah 0).
5. **Auto-sync ke produk:** kalau item sama juga dijual di Shop (nama sama, `psy_products`), stoknya turut dikemaskini (`syncStockToProducts()`) — elak stok Shop lapuk selepas sesi coaching guna bekalan.
6. Dicatat ke **`psy_audit_log`** (`action: inventory.auto_deducted`) + banner ringkasan; amaran kalau ada item jadi stok rendah.

(Lihat [`shared/inventoryDeduct.js`](../../../shared/inventoryDeduct.js).)

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Nama wajib diisi" | Isi **Nama Item** / **Nama Kit** dulu. |
| "Kit mesti ada sekurang-kurangnya 1 item" | Tambah minimum 1 baris item dengan nama + qty. |
| "Masukkan kuantiti yang sah" | Kuantiti laras stok mesti > 0. |
| Stok tak auto-tolak bila tanda Hadir | Bekalan minggu mesti dipilih dari **picker Inventory** (ada `item_id`), bukan teks bebas. Sesi **online** & **extension** memang tak tolak stok. Pastikan `auto_stock` tak dimatikan. |
| Banner "Produk juga di-sync" tak muncul | Tiada produk dengan nama **sama betul-betul** di `psy_products`. Sync padan ikut nama — eja mesti sama (tak kira besar/kecil huruf). |
| Item "Pakej" tunjuk keperluan `0` / `—` | Tiada patient aktif pada pakej yang guna item ini, **atau** nama item tak padan dengan entri supplies pakej. Semak jadual pakej. |
| Auto-PO tak jana walaupun stok rendah | Threshold = 0 (item pakej tiada patient + min_qty 0), atau dah ada permohonan `pending/approved`, atau dalam cooldown 24 jam (`last_auto_po_at`). |
| Item dalam kit tak tolak stok | Nama item dalam kit mesti padan nama di Inventori. Item kit disimpan sebagai nama (`item_id: null`) — padanan ikut nama. |

---

## 8. Rujukan teknikal
- Pages:
  - [`roles/staff/inventory.html`](../../../roles/staff/inventory.html) — senarai, stat, Auto-PO (`checkAutoPO()`), threshold (`getReorderThreshold()`)
  - [`roles/staff/inventory-detail.html`](../../../roles/staff/inventory-detail.html) — detail, edit+supplier, laras stok (`saveAdjust()`), pergerakan
  - [`roles/staff/kit-edit.html`](../../../roles/staff/kit-edit.html) · [`roles/staff/kit-prosedur.html`](../../../roles/staff/kit-prosedur.html) — bina/senarai kit
- Auto-sync inventori ↔ produk (ikut nama): [`shared/stockSync.js`](../../../shared/stockSync.js) — `syncStockToProducts()`, `syncStockToInventory()`, `ensureInventoryCounterpart()`
- Auto-tolak stok bila tanda Hadir: [`shared/inventoryDeduct.js`](../../../shared/inventoryDeduct.js) — `deductSessionSupplies()`; dipanggil dari `plan-week.html` (`markStatus('hadir')` / `upsertProgress`); turut sync ke produk Shop selepas tolak
- Forecast keperluan (14 hari akan datang, ikut sesi sebenar): [`shared/inventoryForecast.js`](../../../shared/inventoryForecast.js) — `attachInventoryForecast()`, `getInventoryReorderThreshold()`, `computeForecastForRange()`; dipakai `inventory.html`, `inventory-detail.html`, `dashboard.html`, `governance.html`, `item-form.html` (panel rujukan staff)
- Jadual: `psy_inventory_items`, `psy_inventory_requests`, `psy_procedure_kits`, `psy_products` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Berkaitan: [Tambah / Edit Pakej](tambah-pakej.md) (di mana bekalan & kit dipilih per minggu)


---


# ===== staff/kepatuhan.md =====

# Panduan: Modul Kepatuhan — Catatan Harian (Pemantauan Coach) 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Pantau sejauh mana pesakit **patuh** kepada amalan rawatan harian (Catatan Harian / Checklist Amalan). Coach guna modul ini untuk:
- Baca **skor kepatuhan** setiap pesakit (mingguan & bulanan) dan tahap A/B/C.
- Lihat **heatmap** amalan mana yang kerap tertinggal merentas semua pesakit.
- **Eksport** laporan (Excel / PDF) untuk fail pesakit atau rujukan pasukan.
- **Isi Catatan Harian bagi pihak pesakit** bila pesakit tertinggal (cth tiada akses telefon hari itu).

> Catatan Harian itu sendiri diisi pesakit di aplikasi mereka (`roles/patient/kepatuhan.html`) — 2 bahagian: **Daily Check-In** (mood, simptom, tidur, aktiviti — *tiada skor*) + **Checklist Amalan** (*ada skor kepatuhan*).

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`kepatuhan`** — biasanya **coach** yang di-assign, `admin`, `manager`, `super_admin`. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

> Untuk **isi bagi pihak pesakit**, akaun staf mesti `role = 'staff'` di `psy_profiles` (dikuatkuasa oleh RLS — lihat §8). Tindakan ditag `jawapan.__by = 'staff:<id>'` untuk audit.

## 3. Lokasi
- **Laporan / pemantauan coach:** Sidebar staf → **OPERASI → Kepatuhan** (`roles/staff/kepatuhan.html`)
- **Detail seorang pesakit:** klik ikon 👁 pada baris pesakit (atau buka terus `kepatuhan.html?patient_id=<id>`)
- **Isi bagi pihak pesakit (borang penuh):** dalam detail pesakit → baris hari yang belum isi → butang **"Isi Sekarang"**
  - Ini buka flow pesakit dalam mod staff: `roles/patient/kepatuhan.html?staff=1&patient_id=<id>&date=<YYYY-MM-DD>`
  - Borang ringkas alternatif: `roles/staff/kepatuhan-fill.html?patient_id=<id>&date=<YYYY-MM-DD>`

---

## 4. Langkah ringkas

**A. Baca kepatuhan pesakit**
1. Buka **Kepatuhan**. Senarai pesakit aktif terpapar, **disusun skor rendah dahulu** (perlu perhatian).
2. Guna anak panah **‹ ›** untuk tukar minggu, atau **📅 Laporan Bulanan** untuk paparan A/B/C 4-5 minggu.
3. Tapis dengan dropdown **Tahap Kepatuhan** atau cari nama/ID.
4. Klik **👁** untuk buka detail pesakit (pecahan harian + peratus setiap amalan).
5. (Pilihan) Buka **🔥 Heatmap** untuk lihat amalan paling banyak tertinggal.

**B. Override kelas (coach)**
6. Dalam detail pesakit → kotak **Override kelas (coach)** → klik **A / B / C** untuk timpa kelas auto; **✕** untuk buang.

**C. Isi Catatan Harian bagi pihak pesakit**
7. Dalam detail pesakit → cari hari berstatus **Belum isi** → klik **"Isi Sekarang"**.
8. Step 1 **Daily Check-In** (mood/simptom/tidur/aktiviti) → **Seterusnya**.
9. Step 2 **Checklist Amalan** → lengkapkan semua item berskor → **Simpan Catatan Harian ✓**.

**D. Eksport**
10. **⬇ Excel** / **🖨 PDF** di header (mingguan), dalam heatmap, dalam detail pesakit, atau dalam modal bulanan.

---

## 5. Field — wajib vs pilihan

### Borang isi bagi pihak pesakit — Step 1: Daily Check-In (TIADA skor)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Mood** `*` | ✅ **WAJIB** untuk teruskan | Pilih 1 dari 6 (Gembira/Sedih/Cemas/Marah/Burnout/Biasa). Setiap mood buka sub-soalan (perincian, tahap ★1–5, faktor). Sistem block ke Step 2 kalau mood kosong. |
| Simptom / Keadaan Badan | Pilihan | Pilih tahap (Tiada/Ringan/Sederhana/Teruk) → kalau bukan "Tiada", pilih bahagian + simptom. |
| Tidur (masa tidur & bangun) | Pilihan | Sistem auto-kira jumlah jam tidur. |
| Aktiviti Harian | Pilihan | Pilih 1 aras (memetakan ke skor tenaga). |
| Perasaan & Nota Harian | Pilihan | Bebas, maks 500 aksara. |

> Check-In **tidak memberi skor kepatuhan** — ia rekod keadaan diri sahaja. Disimpan ke `psy_daily_checkins`.

### Borang isi bagi pihak pesakit — Step 2: Checklist Amalan (ADA skor)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Setiap amalan berskor** `*` | ✅ **WAJIB** | Item bertanda berskor MESTI dijawab. Tak lengkap → "Sila lengkapkan: \<nama amalan\>". |
| Amalan "tracking" (tidak berskor) | Pilihan | Direkod tapi tak mempengaruhi skor. |
| "Lain-lain" + medan teks | Pilihan | Bila pilih "Lain-lain", boleh taip butiran. |

> Senarai amalan berbeza ikut **fasa rawatan** pesakit (cth Madu LTH, Pernafasan Fitrah, Zikir Bersanad, Terapi Bumi, Berjemur, Pantang Makan…). Item ditarik dari konfigurasi fasa pesakit; kalau fasa belum dikonfigur, sistem guna fasa terdahulu yang ada item.

### Detail pesakit (laporan) — Override kelas
| Field | Wajib? | Nota |
|-------|--------|------|
| Override kelas A/B/C | Pilihan | Timpa kelas auto secara manual. Disimpan dgn `override_by` + `override_at`. Baris tertanda **(ubah)** dalam jadual. |
| Nota coach | Pilihan | Disimpan di `psy_kepatuhan_weekly.nota_coach`, muncul dalam eksport Excel. |

---

## Cara baca skor & kelas A/B/C (Pilihan B)

**Skor harian** = mata yang diperoleh ÷ mata maksimum (item berskor sahaja) × 100, untuk hari itu (`skor_harian`, 0–100).

**Skor mingguan (Pilihan B)** = jumlah `skor_harian` semua hari ÷ **bilangan hari yang sudah BERLALU dalam minggu** (bukan bilangan hari diisi). Maksudnya **hari tak isi dikira 0** — ini menghukum pesakit yang tinggalkan hari, supaya skor jujur.

**Peratus setiap amalan (Pilihan B)** = mata amalan itu ÷ (hari berlalu × 2) × 100. ≤50% = **merah** (tidak cukup).

**Kelas auto** (dari skor mingguan):
| Kelas | Skor | Makna |
|-------|------|-------|
| **A — Patuh** | ≥ 85% | Konsisten ikut amalan |
| **B — Separuh** | 50–84% | Sebahagian sahaja |
| **C — Tidak** | < 50% | Perlu intervensi |

**Tahap Kepatuhan (5-aras)** dipaparkan di jadual: Sangat Tinggi (≥85) · Tinggi (≥70) · Sederhana (≥50) · Rendah (≥30) · Sangat Rendah (<30) · Belum isi (tiada data).

> Override coach mengatasi kelas auto untuk paparan & eksport, tetapi **skor mentah kekal** seperti dikira.

---

## 6. Apa jadi lepas Simpan

**Lepas isi Catatan Harian bagi pihak pesakit (butang Simpan):**
1. Checklist Amalan + skor ditulis ke **`psy_kepatuhan_log`** (upsert `onConflict: patient_id,log_date`) — termasuk `jawapan`, `skor_harian`, `fasa`.
2. Tag audit `jawapan.__by = 'staff:<id>'` direkod (sumber data: staf, bukan pesakit).
3. Daily Check-In (mood/tidur/aktiviti/simptom) ditulis ke **`psy_daily_checkins`** (upsert `patient_id,checkin_date`).
4. Diarah balik ke `kepatuhan.html?patient_id=<id>` — skor & kelas dikira semula dalam laporan.

**Lepas set Override kelas:**
1. Rekod ditulis ke **`psy_kepatuhan_weekly`** (upsert `patient_id,minggu_mula`) dgn `override_kelas`, `override_by`, `override_at`, juga `skor`, `bil_hari_isi`, `kelas` (auto).
2. Jadual & KPI di-refresh; baris papar tanda **(ubah)**.

**Alert kepatuhan kepada coach (automatik, malam):**
- Setiap malam sistem nilai setiap pesakit aktif (amalan bawah sasaran, hari tak isi, skor rendah, tiada bacaan kesihatan) dan **gabung jadi SATU alert** ke coach yang di-assign (loceng dalam app; email boleh dihidupkan). Dedup 1×/minggu/pesakit. Konfig/ambang di `psy_auto_messages` (key `kepatuhan_alert`) — **default `is_active = false`**, staf aktifkan dari UI [Mesej Automatik](auto-mesej.md) bila sedia.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Sila pilih mood pesakit terlebih dahulu" | Mood wajib sebelum ke Step 2 Checklist Amalan. |
| "Sila lengkapkan: \<amalan\>" | Ada item berskor belum dijawab. Lengkapkan semua item bertanda `*`. |
| "Tiada amalan untuk fasa ini" | Fasa rawatan pesakit belum dikonfigur item amalan. Setup checklist fasa dahulu. |
| Pesakit tak muncul dalam senarai | Senarai hanya pesakit **aktif berpakej** (ada `active_package_id` dan belum tamat `package_expires_at`). Pesakit deleted/rejected ditapis. |
| Skor nampak rendah walaupun pesakit rajin | Normal — **Pilihan B** kira hari tak isi sebagai 0. Skor naik bila semua hari berlalu diisi. |
| Gagal simpan (mesej "Gagal menyimpan: …") bila isi bagi pihak pesakit | Akaun anda mungkin bukan `role = 'staff'` di `psy_profiles` (RLS halang). Pastikan migrasi staff-fill telah dijalankan (§8). |
| Butang "Isi Sekarang" tiada pada hari tertentu | Hari itu sudah **Lengkap** — gunakan "Lihat Butiran" untuk semak/edit. |
| "Pesakit tidak ditemui" / "patient_id diperlukan" | URL kena ada `patient_id` sah. Buka melalui butang dalam laporan, jangan taip manual. |
| Butang Excel tak berfungsi | Pustaka XLSX belum dimuat — muat semula halaman. |

---

## 8. Rujukan teknikal
- Page laporan coach: [`roles/staff/kepatuhan.html`](../../../roles/staff/kepatuhan.html) — skor `loadData()`, kelas `classify()`/`tier5()`, Pilihan B `elapsedDays()`/`weekDenom()`, heatmap `heatmapData()`, eksport `exportWeeklyExcel()`/`printWeekly()`/`exportPatientExcel()`/`exportMonthlyExcel()`
- Page isi ringkas (staff): [`roles/staff/kepatuhan-fill.html`](../../../roles/staff/kepatuhan-fill.html) — `sfSave()`
- Flow pesakit (mod staff): [`roles/patient/kepatuhan.html`](../../../roles/patient/kepatuhan.html) — `computeSkor()` (skor harian), `weekToFasa()`
- Jadual:
  - `psy_kepatuhan_log` — log harian (`jawapan` jsonb, `skor_harian`, `fasa`, `log_date`)
  - `psy_daily_checkins` — Daily Check-In (mood/tidur/aktiviti/simptom)
  - `psy_kepatuhan_weekly` — ringkasan mingguan + override coach
  - `psy_kepatuhan_item` — definisi amalan per-fasa (`berskor`, `options[].mata`)
  - (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Migrasi:
  - [`supabase/migrations/20260627_staff_fill_kepatuhan.sql`](../../../supabase/migrations/20260627_staff_fill_kepatuhan.sql) — RLS benarkan staff tulis log + check-in bagi pihak pesakit
  - [`supabase/migrations/20260626_kepatuhan_alerts.sql`](../../../supabase/migrations/20260626_kepatuhan_alerts.sql) — alert kepatuhan gabungan kepada coach (`psy_auto_messages.rule`, key `kepatuhan_alert`)


---


# ===== staff/library-faq.md =====

# Panduan: Library (Self-Help) & FAQ 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Urus kandungan **Self-Help Library** (video, artikel, audio) dan **FAQ (Soalan Lazim)** yang pesakit baca dalam app — termasuk tajuk, kategori, pakej sasaran, fail/URL kandungan, serta urus senarai kategori. Inilah kandungan yang muncul di `roles/patient/library.html` dan `roles/patient/faq.html`.

## 2. Siapa boleh buat
- **Tambah / edit / padam kandungan & FAQ:** Staf dengan kebenaran modul **`library`** (`create` / `edit` / `delete`). Biasanya `super_admin`, `admin`, `manager`. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)
- **Urus Kategori:** **Super Admin sahaja** — butang 🗂️ Kategori dan halaman `library-categories.html` hanya nampak untuk `super_admin`.

## 3. Lokasi
- **Senarai kandungan:** Sidebar staf → **Library Content** (`roles/staff/library.html`)
- **Borang tambah/edit kandungan (video/artikel/audio):** `roles/staff/library-edit.html`
  - Tambah baru: butang **"+ Tambah Kandungan"** di `library.html`
  - Edit: klik ✏️ pada baris kandungan
- **Borang FAQ:** `roles/staff/library-faq-edit.html` (klik ✏️ pada baris jenis FAQ membuka borang ini secara automatik)
- **Urus Kategori:** butang **🗂️ Kategori** → `roles/staff/library-categories.html`
- **Lihat / pratonton:** `library-view.html`, `library-detail.html`

---

## 4. Langkah ringkas

### A. Tambah video / artikel / audio
1. Buka **Library Content** → klik **+ Tambah Kandungan**.
2. **Langkah 1 — Jenis:** pilih **Video**, **Artikel** atau **Audio**.
3. **Langkah 2 — Maklumat:** isi **Tajuk**, **Kategori**, **Description** (+ **Kandungan Penuh** untuk Artikel).
4. **Langkah 3 — Muat Naik:** muat naik fail **atau** tampal URL (YouTube/pautan). Tambah thumbnail (auto-jana dari video) + dokumen sokongan (pilihan).
5. **Langkah 4 — Tetapan & Penerbitan:** pilih status, akses (Semua Pesakit / ikut Pakej), jadual terbit.
6. Klik **📤 Terbitkan Sekarang** atau **Simpan Sebagai Draf**.

### B. Tambah FAQ
1. **Library Content** → **+ Tambah Kandungan** → pilih jenis **FAQ** (atau edit FAQ sedia ada → buka `library-faq-edit.html`).
2. Isi **Soalan** + **Kategori**, tulis **Jawapan** (rich-text), tambah **Pautan Video** (pilihan).
3. Tetapkan **Status** + **Akses**, klik **Simpan**.

### C. Urus kategori (Super Admin)
1. **Library Content** → **🗂️ Kategori**.
2. Pilih skop: **📚 Kategori Kandungan** atau **❓ Kategori FAQ**.
3. **+ Tambah**, **Edit** (rename), **Sembunyi**/**Aktifkan**, **Padam**, atau guna ▲▼ untuk susun.

---

## 5. Field — wajib vs pilihan

### A. Kandungan — Video / Artikel / Audio (`library-edit.html`)

**Langkah 1 — Jenis Kandungan**
| Field | Wajib? | Nota |
|-------|--------|------|
| **Jenis** `*` | ✅ **WAJIB** | Video · Artikel · Audio · FAQ. Pilih FAQ = dialih ke borang FAQ. Boleh tukar kemudian. |

**Langkah 2 — Maklumat Kandungan**
| Field | Wajib? | Nota |
|-------|--------|------|
| **Tajuk Kandungan** `*` | ✅ **WAJIB** | Maks 150 aksara. Cth: `Teknik Pernafasan Untuk Tenangkan Minda` |
| **Kategori** `*` | ✅ **WAJIB** | Dari senarai kategori (skop `content`). Block kalau kosong. |
| **Description** `*` | ✅ **WAJIB** | Maks 300 aksara. Dipapar sebagai pratonton pada kad library. |
| Kandungan Penuh | Pilihan | **Artikel sahaja** (rich-text: bold/italic/list/link). Maks 5000 aksara. Tersembunyi untuk Video/Audio. |

**Langkah 3 — Muat Naik Kandungan**
| Field | Wajib? | Nota |
|-------|--------|------|
| **Fail Video / Audio** `*` | Video/Audio: **salah satu** | Muat naik fail **ATAU** isi URL. Video: MP4/MOV/WebM maks 500MB. Audio: MP3/WAV/OGG maks 200MB. |
| **Pautan Video / Audio (URL)** `*` | Video/Audio: **salah satu** | Cth YouTube `https://www.youtube.com/watch?v=...`. Kalau ada URL, fail tak perlu. |
| Pautan Artikel (URL) | Pilihan | **Artikel sahaja** — pautan luaran (opsyenal). |
| Thumbnail | Pilihan | JPG/PNG, 1280×720 (16:9). Untuk video, sistem cuba auto-tangkap frame jadi thumbnail. |
| Dokumen Sokongan | Pilihan | PDF/DOC/PPT. |

> Untuk **Video/Audio**: borang block kalau **tiada fail DAN tiada URL**. Salah satu mesti ada.

**Langkah 4 — Tetapan & Penerbitan**
| Field | Wajib? | Nota |
|-------|--------|------|
| **Status Penerbitan** `*` | Default **Terbitkan** | `Terbitkan` (pesakit nampak) atau `Simpan Sebagai Draf`. |
| **Akses Kandungan** `*` | Default **Semua Pesakit** | `Semua Pesakit` (public) **atau** `Mengikut Pakej` → tick pakej tertentu (`package_ids`). |
| Jadual Terbit | Pilihan | `Terbit Sekarang` atau `Jadualkan Tarikh & Masa` (set `created_at` ke masa depan). |
| Benarkan Komen / Tunjuk Tontonan / Premium | Pilihan | Toggle tetapan lanjutan. |
| Notifikasi | Pilihan | Hantar notifikasi pesakit tentang kandungan baru. |

### B. FAQ (`library-faq-edit.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Soalan** `*` | ✅ **WAJIB** | Maks 255 aksara. Disimpan sebagai `title`. |
| **Kategori** `*` | ✅ **WAJIB** | Dari senarai kategori skop `faq`. |
| **Jawapan** `*` | ✅ **WAJIB** | Rich-text (tajuk/bold/list/link). Maks 5000 aksara. Disimpan ke `content_body`. |
| Pautan Video | Pilihan | Pautan YouTube untuk bantu jelaskan jawapan. Disimpan ke `content_url`. |
| **Status** `*` | Default **Diterbitkan** | `Diterbitkan` · `Draf` · `Tidak Aktif`. |
| **Akses** `*` | Default **Semua Pesakit** | `Semua Pesakit` atau `Mengikut Pakej`. |

### C. Kategori (`library-categories.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Nama kategori** `*` | ✅ **WAJIB** | Tak boleh duplikat (case-insensitive). |
| Skop | Pilih | **📚 Kandungan** (`content`) atau **❓ FAQ** (`faq`) — dua senarai berasingan. |
| Susunan | Auto | Guna ▲▼ untuk ubah `sort_order`. |

---

## 6. Apa jadi lepas Simpan
1. Rekod ditulis ke jadual **`psy_library_items`** (insert kalau baru, update kalau edit) — termasuk `media_type` (`video`/`article`/`audio`/`faq`), `topic`, `package_ids`, `content_url`/`content_body`, `thumbnail_url`, `status`, `is_active`.
2. `item_id` auto-dijana dari tajuk (FAQ guna prefix `faq-`).
3. Fail (video/audio/thumbnail/dokumen) dimuat naik ke storage bucket **`library-media`**; URL awam disimpan.
4. Tindakan dicatat ke audit log: `library.created` / `library.updated` (juga `library.deleted` / `library.activated` / `library.deactivated`).
5. Diarah balik ke **`library.html`**; KPI (jumlah Video/Artikel/Audio/FAQ + tontonan) dikira semula.
6. Kandungan muncul untuk pesakit di `roles/patient/library.html` & `library-detail.html` (FAQ di `faq.html`) **jika status = Terbitkan/Diterbitkan** dan pakej padan dengan akses.

> **Kategori:** rename akan kemas kini semua item yang guna nama lama (`topic` diset semula); padam akan jadikan item tersebut **tanpa kategori** (`topic = null`). Tukar di sini = semua dropdown & filter ikut automatik.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Tajuk wajib diisi." | Isi field **Tajuk** (Langkah 2). |
| "Sila pilih kategori." | Pilih **Kategori**. Kalau dropdown kosong, tambah dulu di **🗂️ Kategori**. |
| "Ringkasan pendek wajib diisi." | Isi **Description** (Langkah 2). |
| "Sila muat naik fail atau masukkan pautan…" | Video/Audio mesti ada **fail ATAU URL** — salah satu. |
| "Soalan wajib diisi" / "Sila isi jawapan" (FAQ) | Isi **Soalan** dan **Jawapan**. |
| Dropdown kategori kosong | Belum ada kategori untuk skop berkenaan, **atau** migrasi `library_categories` belum dijalankan. Tambah di **🗂️ Kategori** (Super Admin). |
| Butang 🗂️ Kategori / + Tambah Kandungan tak nampak | Tiada kebenaran. Kategori = Super Admin sahaja; tambah kandungan perlu `library.create`. |
| "Akses Terhad — Hanya Super Admin" (halaman kategori) | Memang betul; minta Super Admin urus kategori. |
| Thumbnail video tak auto-jana | Sumber video CORS-blocked (cth pautan luaran tertentu) — muat naik thumbnail manual. |
| "Kategori dah wujud" | Nama kategori duplikat. Guna nama lain. |
| Kandungan tak muncul untuk pesakit | Pastikan status = Terbitkan **dan** akses/pakej padan langganan pesakit. |
| Senarai/dropdown kategori atau item kosong sama sekali | Skema belum siap — jalankan migrasi `step49 → step50 → step51`. |

---

## 8. Rujukan teknikal
- Page (kandungan): [`roles/staff/library-edit.html`](../../../roles/staff/library-edit.html) · `saveItem()` ~ baris 740
- Page (FAQ): [`roles/staff/library-faq-edit.html`](../../../roles/staff/library-faq-edit.html) · `saveItem()` ~ baris 178
- Page (senarai): [`roles/staff/library.html`](../../../roles/staff/library.html) · `loadLibrary()` ~ baris 443
- Page (kategori): [`roles/staff/library-categories.html`](../../../roles/staff/library-categories.html)
- Pesakit lihat: [`roles/patient/library.html`](../../../roles/patient/library.html) · [`roles/patient/faq.html`](../../../roles/patient/faq.html)
- Jadual: `psy_library_items` (`media_type` / `topic` / `tags` / `package_ids` / `content_url` / `content_body` / `status`), `psy_library_categories` (`name` / `scope` / `sort_order` / `is_active`) — lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md)
- Storage bucket: `library-media` (folder `videos` / `audio` / `thumbnails` / `docs`)
- Migrasi prasyarat: `step49 → step50 → step51` mesti dijalankan.


---


# ===== staff/pelan-mingguan.md =====

# Panduan: Pelan Mingguan & Tanda Hadir / Tidak Hadir Sesi 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Uruskan sesi rawatan pesakit minggu demi minggu — tetapkan tarikh sesi, tanda **Hadir** atau **Tidak Hadir**, rekod nota coach / skor / SOAP / vitals / kepatuhan, dan kendalikan ketidakhadiran (ingatkan pesakit, jadual semula, atau buka minggu tambahan berbayar). Tanda **Hadir** juga yang mencetuskan **auto-tolak stok** bekalan F2F minggu itu.

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`plans`** / **`plan_week`** — biasanya `coach` (untuk pesakit yang ditugaskan kepadanya), `manager`, `admin`, `super_admin`. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

> Coach hanya nampak plan pesakit yang ditugaskan kepadanya (`coach_id`). Admin/manager nampak semua. Hanya `super_admin` nampak butang **Reset Sesi** / **Admin Tools**.

## 3. Lokasi
- **Senarai plan:** Sidebar staf → **OPERASI → Treatment Plans** (`roles/staff/plans.html`)
  - Cari pesakit, tapis ikut status (Aktif / Selesai / Tangguh).
- **Detail minggu (editor):** `roles/staff/plan-week.html?plan_id=…&week=…`
  - Klik kad pesakit di `plans.html` → terus buka minggu **semasa**.

> Plan **tidak** dicipta manual di sini — ia dijana automatik melalui aliran pakej (KOB / pembayaran). Lihat [Tambah Pakej](tambah-pakej.md).

---

## 4. Langkah ringkas

1. Buka **Treatment Plans** → klik pesakit untuk buka **Detail Minggu**.
2. Guna **← Minggu Sebelum / Minggu Seterusnya →** untuk ke minggu yang betul. (Kalau 2 sesi seminggu, pilih tab sesi — cth Jum / Sab.)
3. Tetapkan **Tarikh & Masa Sesi** (di kotak *Nota Coach*) — sistem cipta/kemaskini temujanji + notifikasi pesakit.
4. Selepas sesi berlaku, tekan **✅ Hadir** atau **❌ Tidak Hadir** di hero minggu.
5. Isi rekod sesi: **Score**, **Nota Minggu Ini**, **Kepatuhan Rawatan**, **Nota Doktor (SOAP)**, **Bacaan Vitals**, tanda checklist **Coaching Minggu Ini** (bimbingan + bekalan).
6. Kalau **Tidak Hadir**: **🔔 Ingatkan Pesakit** untuk reschedule sendiri, **atau** isi tarikh baru → **📅 Jadual Semula**.
7. Kalau pesakit sah nak sambung rawatan: tekan **➕ Buka Minggu Tambahan** (pesakit bayar — TIADA auto-caj).

> Kebanyakan field **auto-simpan** bila tukar / klik keluar (indikator "✓ Tersimpan" muncul). Nota coach & Kepatuhan perlu klik butang **Simpan**.

---

## 5. Field — wajib vs pilihan

### Hero Minggu (atas)
| Butang / Field | Wajib? | Nota |
|----------------|--------|------|
| Tab sesi (Jum / Sab …) | Auto | Hanya muncul kalau pakej **2 sesi seminggu**. Pilih sesi dulu — semua bahagian bawah ikut sesi aktif. |
| **✅ Hadir** | — | Tanda kehadiran sesi aktif. Cetuskan auto-tolak stok + tetapkan minggu ini sebagai `current_week`. |
| **❌ Tidak Hadir** | — | Rekod absen sesi aktif. **TIDAK** auto-caj. Buka kawalan reschedule + minggu tambahan. |
| **🔔 Ingatkan Pesakit** | — | Muncul bila status = Tidak Hadir. Hantar notifikasi suruh pesakit reschedule sendiri. |
| Tarikh reschedule + **📅 Jadual Semula** | — | Muncul bila Tidak Hadir. Tetapkan tarikh baru → status jadi `booked` + notifikasi pesakit. |
| **➕ Buka Minggu Tambahan** | — | Muncul bila ada sesi Tidak Hadir minggu ini. Buka 1 minggu tambahan **berbayar** (pesakit bayar). |

### Seksyen Nota Coach (kiri)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Tarikh & Masa Sesi** | Disyorkan | `datetime-local`. Auto-simpan + cipta/kemaskini `psy_appointments` + notifikasi pesakit. Status jadi `booked` (kecuali sudah Hadir/Tidak Hadir). |
| Score (0–10) | Pilihan | Skor sesi. Auto-simpan bila tukar. |
| Nota Minggu Ini | Pilihan | Pemerhatian / arahan. Klik **💾 Simpan Nota**. |

### Seksyen Kepatuhan Rawatan (kanan)
Semua **pilihan** — isi yang berkaitan, kemudian klik **🌿 Simpan Kepatuhan**:
🍯 Madu (sudu/hari) · 🌬️ Nafas fitrah (kali/hari) · 🌍 Terapi bumi (min/hari) · 🥥 Air kelapa (kali/mgg) · 💧 Terapi kolon (kali) · ☀️ Berjemur (Ya/Tidak) · 🍽️ Pantang makanan (Ya/Tidak). Disimpan per **sesi** (`session_day`).

### Coaching Minggu Ini (checklist)
| Bahagian | Nota |
|----------|------|
| **Bimbingan / Calling** | Checklist task dari pakej. Tanda bila selesai; kalau belum, isi **alasan**. |
| **Rujukan** (staff sahaja) | Pautan rujukan untuk coach — pesakit tak nampak. |
| **📦 Bekalan** | Checklist bekalan. **Tanda = tolak stok**, buang tanda = kembalikan stok (lihat seksyen 6). |

### Modal lain (pilihan)
- **⚕ Nota Doktor (SOAP)** — Mood sebelum/selepas, S·O·A·P, Tahap Risiko + nota, Homework. Boleh **💾 Simpan Draf** atau **✍️ Sign & Lock** (terkunci selepas ditandatangani).
- **📊 Bacaan Vitals** — BP, nadi, berat, tinggi, suhu, RBS, nota.
- **📎 Dokumen Minggu Ini** — muat naik lampiran (imej / PDF) khusus minggu ini.

---

## 6. Apa jadi lepas Simpan

### Bila tanda **✅ Hadir**
1. `psy_plan_weekly_progress` sesi itu → `status = 'hadir'` (+ `updated_by`, `updated_at`).
2. `psy_treatment_plans.current_week` dikemaskini ke minggu ini.
3. **Auto-tolak stok** ([`shared/inventoryDeduct.js`](../../../shared/inventoryDeduct.js)): bekalan F2F minggu itu (dari `coaching_schedule.supplies`) ditolak dari `psy_inventory_items.qty_in_stock`.
   - **Skip** kalau sesi mode **Online** atau sesi **extension** (minggu tambahan) — tiada bekalan fizikal.
   - Skip item tanpa `item_id`, `qty = 0`, atau `auto_stock = false`.
   - Banner papar bekalan yang ditolak + amaran kalau **stok rendah** (< 5).
   - Dicatat ke audit: `inventory.auto_deducted`.
4. Notifikasi "Kehadiran disahkan ✅" dihantar ke pesakit.
5. Audit log: `plan.week_updated`.

> **Nota stok per item Bekalan:** menanda satu item dalam checklist **Bekalan** juga menolak stok item itu (−1 set); membuang tanda mengembalikannya (+1). Kit prosedur dikembangkan ke item individu.

### Bila tanda **❌ Tidak Hadir**
1. `status = 'cancel'` direkod. **TIADA** auto-caj, **TIADA** auto-buka minggu tambahan.
2. Notifikasi "Sesi ditanda tidak hadir — anda boleh tempah semula" dihantar ke pesakit.
3. Muncul kawalan: **🔔 Ingatkan Pesakit**, **📅 Jadual Semula**, dan **➕ Buka Minggu Tambahan**.

### Peraturan ketidakhadiran (penting — kemaskini 24 Jun 2026)
- Tidak Hadir = **rekod absen + tawar reschedule SAHAJA**.
- Minggu tambahan berbayar dibuka **secara MANUAL** sahaja, melalui butang **➕ Buka Minggu Tambahan** — **tiada auto-caj**. Tekan hanya bila pesakit sah nak sambung rawatan.
- Buka minggu tambahan = cipta 2 sesi baru (`is_extension = true`, `status = 'extension_pending_payment'`) selepas minggu terbesar, pada harga `extension_price_per_week` pakej (default **RM 50**) + notifikasi pesakit bayar. Audit: `plan.extension_created`.
- **Dedup per minggu:** satu minggu hanya boleh ada satu minggu tambahan (`extension_for_week`).
- Kalau coach kemudian betulkan kehadiran (tanda Hadir / Jadual Semula) **sebelum** pesakit bayar, minggu tambahan yang belum dibayar **dibatalkan automatik** (audit: `plan.extension_voided`). Yang sudah dibayar dikekalkan.

(Rujukan penuh: [03-modul.md — Aturan ketidakhadiran](../../sistem/03-modul.md).)

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Tiada sesi untuk minggu ini" bila tekan Hadir | Belum ada baris sesi. Tetapkan **Tarikh & Masa Sesi** dulu (cipta baris `booked`), kemudian tanda kehadiran. |
| Butang Hadir / Tidak Hadir tak muncul | Minggu itu belum ada sesi (`weekEntry`). Set tarikh sesi dahulu. |
| Stok tak ditolak walaupun tanda Hadir | Sesi mode **Online** / **extension**, atau bekalan tiada `item_id` / `qty = 0` / `auto_stock = off`. Semak timeline pakej di [Tambah Pakej](tambah-pakej.md). |
| "⚠️ Ralat inventori …" | Item bekalan tak wujud dalam inventori atau ralat kemaskini. Semak item di **Inventory**. |
| Butang **Buka Minggu Tambahan** tak muncul | Hanya muncul bila ada sesi **Tidak Hadir** minggu ini & ia bukan minggu extension sendiri. |
| "Tiada sesi tidak hadir untuk minggu ini" bila buka minggu tambahan | Tiada sesi berstatus `cancel`. Tanda Tidak Hadir dulu. |
| "Sila pilih tarikh & masa baru" bila Jadual Semula | Isi medan tarikh reschedule dahulu. |
| "Tiada akaun pesakit untuk dihubungi" | Pesakit belum ada akaun (`user_id`). Notifikasi tak dapat dihantar; gunakan saluran lain. |
| Tarikh sesi rosak / silap | `super_admin` boleh guna **Admin Tools → Reset Tarikh Sesi Minggu Ini** atau **Reset Sesi** di senarai (rows hadir dikekalkan; tarikh dijana semula). |

---

## 8. Rujukan teknikal
- Page senarai: [`roles/staff/plans.html`](../../../roles/staff/plans.html)
- Page editor: [`roles/staff/plan-week.html`](../../../roles/staff/plan-week.html) · `markStatus()`, `openExtensionManually()` / `createExtensionForWeek()`, `coachReschedule()`, `applySupplyStock()`
- Auto-tolak stok: [`shared/inventoryDeduct.js`](../../../shared/inventoryDeduct.js) · `deductSessionSupplies()`
- Jadual: `psy_treatment_plans`, `psy_plan_weekly_progress` (kehadiran + nota + SOAP + extension), `psy_plan_compliance`, `psy_appointments`, `psy_inventory_items`, `psy_procedure_kits` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Modul + peraturan ketidakhadiran: [03-modul.md](../../sistem/03-modul.md)
- Audit actions: `plan.week_updated`, `inventory.auto_deducted`, `plan.extension_created`, `plan.extension_voided`, `plan.reschedule_reminder`


---


# ===== staff/pembayaran.md =====

# Panduan: Pembayaran (Admin) 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Pantau, sahkan dan rekod semua pembayaran pesakit (pakej rawatan, order produk, minggu tambahan, KOB) di satu tempat — termasuk **sahkan bayaran yang masih *pending***, **rekod bayaran manual** (transfer/tunai), jana **invois/resit**, dan **export CSV** untuk akaun.

> ⚠️ **PENTING — bayaran pesakit masih SIMULASI.** Halaman pesakit (`payment.html`) belum sambung ke gateway sebenar (Billplz / ToyyibPay masih pending). Fungsi `processPayment()` cuma *simulate* bayaran lepas 1.2 saat, jadi rekod `psy_payments` terus jadi `completed`. Sebab itu, untuk bayaran sebenar (transfer/FPX di luar sistem), **staf perlu sahkan/rekod secara manual** di halaman ini. Model bayar **sekali** (bukan langganan berulang).

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`payment_admin`** — biasanya `super_admin`, `admin`, `manager`. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).) Jika tiada akses, sidebar tak papar item **Pembayaran** dan `authGuard` akan halang masuk.

## 3. Lokasi
- **Sidebar staf → OPERASI → Pembayaran** (`roles/staff/payment-admin.html`)
- Pesakit pula bayar di `roles/patient/payment.html` (rekod masuk ke jadual yang sama, `psy_payments`).

---

## 4. Langkah ringkas

**A. Semak status bayaran**
1. Buka **Pembayaran**. Lihat **KPI** atas: Kutipan Hari Ini · Kutipan Bulan Ini · **Pending** (perlu disahkan) · Jumlah Transaksi.
2. Guna penapis **Status / Kaedah / Tempoh** atau kotak **Cari** (receipt atau nama pesakit) untuk tapis senarai.
3. Klik **Lihat** pada mana-mana baris untuk butiran penuh.

**B. Sahkan bayaran pending**
4. Tapis **Status = Pending** → klik **Lihat** pada transaksi.
5. Sah betul (sudah terima duit transfer/FPX) → klik **Sahkan Selesai**. Status bertukar ke `completed` dan `paid_at` diisi sekarang.

**C. Rekod bayaran manual** (pesakit bayar luar sistem — tunai/transfer)
6. Klik **+ Bayaran Manual** → pilih **Pesakit**, isi **Jumlah** + **Kaedah** → **Simpan Bayaran**. Rekod terus jadi `completed`.

**D. Jana invois / resit**
7. Dalam butiran transaksi → **🧾 Jana Invois** → **🖨️ Cetak / PDF**.

**E. Export**
8. Klik **📥 Export CSV** untuk muat turun senarai (mengikut penapis semasa).

> ❗ **Tiada butang "Tolak/Gagal" automatik dalam UI.** Untuk tandakan bayaran sebagai **Gagal** (failed) atau **Refund**, ubah status terus di Supabase (lihat [§7 Masalah biasa](#7-masalah-biasa)).

---

## 5. Field — wajib vs pilihan

### Penapis & carian (atas senarai)
| Field | Wajib? | Nota |
|-------|--------|------|
| Cari | Pilihan | Padan **receipt** atau **nama pesakit**. |
| Status | Pilihan | `Selesai` (completed) · `Pending` · `Gagal` (failed). |
| Kaedah | Pilihan | FPX · Kad · Transfer · GHL · Manual. |
| Tempoh | Default `30 Hari` | 7 / 30 / 90 / 365 hari / Semua. **Tukar tempoh muat semula data dari DB** (bukan sekadar tapis paparan). |

### Modal "Rekod Bayaran Manual"
| Field | Wajib? | Nota |
|-------|--------|------|
| **Pesakit** `*` | ✅ **WAJIB** | Dropdown **pesakit aktif sahaja** (status `active`). Block kalau kosong. |
| **Jumlah (RM)** `*` | ✅ **WAJIB** | Mesti > 0, kalau tidak ditolak ("Masukkan jumlah yang sah"). Jadi `subtotal` **dan** `total`. |
| Kaedah | Default `Transfer` | Transfer · Kad · FPX · Manual. |
| Penerangan | Pilihan | Cth: `Pakej Asas (1x)`. Jadi satu baris item pada resit (`qty 1`). Kosong = resit tanpa baris item. |
| Nota | Pilihan | Simpan ke kolum `notes`, papar pada butiran & invois. |

> Bayaran manual **tidak** auto-aktifkan pakej. Ia cuma rekod kewangan. Untuk buka akses pakej, lihat §6.

---

## 6. Apa jadi lepas Simpan / Sahkan

### Bila **Sahkan Selesai** (pending → completed)
1. `psy_payments` dikemas kini: `status = 'completed'`, `paid_at = sekarang`.
2. Senarai dimuat semula; KPI Pending berkurang, Kutipan bertambah.

### Bila **Rekod Bayaran Manual**
1. Baris baru di-`insert` ke **`psy_payments`** dengan `receipt_ref` auto (`RCP-…`), `status = 'completed'`, `paid_at = sekarang`.
2. Muncul serta-merta dalam senarai & boleh jana invois.

### ⚠️ Kesan ke akses pakej (penting)
- Bila **pesakit** bayar pakej melalui `payment.html` (simulasi), barulah sistem **buka akses**: insert `psy_package_purchases` (`status='active'`), kemas kini `psy_patients` (`active_package_id`, `active_package_name`, `package_expires_at` +3 bulan), dan **auto-cipta** `psy_treatment_plans`.
- **Halaman admin ini TIDAK buat semua itu.** "Sahkan Selesai" dan "Bayaran Manual" cuma sentuh `psy_payments`. Jadi kalau pesakit bayar di luar sistem dan staf rekod manual, **akses pakej + treatment plan belum terbuka** — staf masih perlu aktifkan pakej secara berasingan (cth: minta pesakit teruskan flow pakej, atau aktifkan pada rekod pesakit). Jangan andai resit completed = pakej sudah aktif.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Pilih pesakit dahulu" | Pilih pesakit dalam dropdown modal manual sebelum simpan. |
| "Masukkan jumlah yang sah" | Jumlah mesti nombor > 0. |
| Pesakit tak muncul dalam dropdown manual | Dropdown hanya papar pesakit **aktif** (`status='active'`). Pastikan rekod pesakit aktif dulu. |
| Bayar manual tapi pakej masih terkunci | Normal — manual cuma rekod kewangan. Aktifkan pakej berasingan (lihat §6). |
| Nak tandakan bayaran **Gagal** / **Refund** | Tiada butang dalam UI. Ubah `status` ke `failed`/`refunded` terus di Supabase (`psy_payments`). |
| Transaksi pending tak hilang lepas sahkan | Muat semula halaman / tukar penapis Tempoh untuk paksa `loadData()`. |
| Nama pesakit papar "Pesakit" / kosong pada resit | Profil (`psy_profiles.full_name`) atau MRN belum diisi — lengkapkan rekod pesakit. |
| Bimbang bayaran sebenar tak masuk | Ingat: gateway belum live. Semua bayaran pesakit di `payment.html` adalah **simulasi** — sahkan secara manual ikut bukti transfer sebenar. |

---

## 8. Rujukan teknikal
- Page admin: [`roles/staff/payment-admin.html`](../../../roles/staff/payment-admin.html) · fungsi utama: `markComplete()` ~ baris 454, `saveManual()` ~ baris 467, `openInvoice()` ~ baris 392, `exportCsv()` ~ baris 499.
- Page pesakit: [`roles/patient/payment.html`](../../../roles/patient/payment.html) · `processPayment()` ~ baris 316 (**masih simulasi** — `setTimeout(...1200)`, tiada panggilan gateway).
- Jadual: **`psy_payments`** — kolum utama: `receipt_ref`, `patient_id`, `user_id`, `items` (JSON), `subtotal`, `total`, `payment_method`, `status` (`completed`/`pending`/`failed`/`refunded`), `paid_at`, `notes`, `ghl_transaction_id`. (Lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md).)
- Modul & status simulasi: [03-modul.md](../../sistem/03-modul.md) (seksyen Pembayaran).
- Modul `payment_admin` → akses `payment` (`shared/authGuard.js`); item sidebar `roles/staff/navbar.js` (label "Pembayaran", group OPERASI).
- Audit: bayaran pesakit catat `payment.received` / `payment.cancelled` ke `psy_audit_log`.


---


# ===== staff/pengumuman-acara.md =====

# Panduan: Pengumuman & Acara / Kelas 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Maklumkan pesakit (dan staf) tentang berita, promosi, notis sistem, **atau** acara/kelas/webinar — termasuk reminder WhatsApp automatik sebelum acara bermula.

Dua jenis rekod dibuat dari **satu borang yang sama** (`pengumuman-baru.html`), bergantung pada **Jenis Pengumuman** yang dipilih:

| Jenis | Disimpan ke jadual | Pesakit nampak di |
|-------|--------------------|-------------------|
| **Pengumuman biasa** (Makluman, Survey, Kemaskini Sistem…) | `psy_announcements` | `roles/patient/announcements.html` |
| **Acara / Kelas** (Event F2F, Webinar, Manzil…) | `psy_events` | `roles/patient/events.html` → `event-detail.html` |

> Bezanya: jenis **event** ada Tarikh + Masa + Lokasi/Online + Kapasiti + reminder automatik. Pengumuman biasa hanya tajuk + kandungan + butang tindakan (CTA) pilihan.

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`announcements`** (cipta/edit pengumuman) dan **`events_admin`** (urus acara) — biasanya `super_admin`, `admin`, `manager`. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

> **`super_admin` sahaja** boleh **Urus Jenis Pengumuman** dan **Urus Kategori** (tambah/edit/padam) melalui pilihan **⚙️** dalam dropdown.

## 3. Lokasi
- **Senarai pengumuman:** Sidebar staf → **OPERASI → Pengumuman** (`roles/staff/announcements.html`)
- **Senarai acara/kelas:** Sidebar staf → **Acara & Kelas** (`roles/staff/events.html`)
- **Borang cipta (pengumuman & acara):** `roles/staff/pengumuman-baru.html`
  - Dari `announcements.html`: butang **"+ Tambah Pengumuman"**
  - Dari `events.html`: butang **"+ Cipta di Pengumuman"**
- **Edit pengumuman:** `roles/staff/pengumuman-edit.html` (klik pengumuman → Edit)
- **Edit acara cepat:** modal **✏️ Edit Acara** terus dalam `events.html` (klik kad acara), atau halaman penuh `acara-detail.html`

---

## 4. Langkah ringkas

### A) Cipta Pengumuman biasa
1. Buka **Pengumuman** → **+ Tambah Pengumuman**.
2. **Jenis Pengumuman** → pilih jenis biasa (cth `Makluman`, `Survey / Tindakan`, `Kemaskini Sistem`).
3. **Sasaran Pengguna** → pilih **Semua Pesakit** / **Pakej Tertentu** / **Staff**.
4. Isi **Tajuk**, **Kategori**, **Ringkasan Pendek**. (Pilihan: Banner, Tarikh Tamat Papar, Butang Tindakan/CTA.)
5. Klik **🚀 Publish Pengumuman** (atau **📄 Simpan Draft** untuk sembunyi dulu).

### B) Cipta Acara / Kelas
1. Buka **Pengumuman** → **+ Tambah Pengumuman** (atau dari `events.html` → **+ Cipta di Pengumuman**).
2. **Jenis Pengumuman** → pilih jenis **event** (cth `Event Fizikal (F2F)`, `Webinar / Online`, `Bacaan Manzil`). Kad **Maklumat Event** akan muncul.
3. **Sasaran Pengguna** + isi **Tajuk**, **Kategori**, **Ringkasan**.
4. Isi **Maklumat Event**: **Tarikh**, **Masa Mula** (wajib), Masa Tamat, Lokasi/Pautan, Pengendali, Kapasiti.
5. Klik **🚀 Publish** → diarah ke `events.html`.

> **Edit acara cepat** (tukar masa, mod, harga, pautan rakaman, batalkan): buka `events.html`, klik kad → modal **Edit Acara**. Tukar status ke **Cancelled** akan auto-maklum pesakit berdaftar (loceng dalam app).

---

## 5. Field — wajib vs pilihan

### Bersama (semua jenis) — `pengumuman-baru.html`
| Field | Wajib? | Nota |
|-------|--------|------|
| **Jenis Pengumuman** `*` | ✅ Pilih | Menentukan sama ada rekod jadi **pengumuman** atau **event**. Default `Event Fizikal (F2F)`. |
| **Sasaran Pengguna** `*` | ✅ **WAJIB** | Pilih ≥1: 👥 Semua Pesakit · 🎯 Pakej Tertentu (mesti pilih ≥1 pakej) · 🧑‍⚕️ Staff. "Semua Pesakit" & "Pakej Tertentu" saling eksklusif. |
| **Tajuk** `*` | ✅ **WAJIB** | Maks 150 aksara. |
| **Kategori** `*` | Disyorkan | Dari `psy_announcement_categories`. Kalau kosong, sistem guna nama jenis sebagai kategori. |
| **Ringkasan Pendek** `*` | ✅ **WAJIB** | Maks 200 aksara. Ini jadi `body` (pengumuman) / `description` (event). |
| Banner / Gambar | Pilihan | JPG/PNG, **maks 5MB**. Auto-crop nisbah **2:1** (1200×600px). |

### Khusus PENGUMUMAN biasa
| Field | Wajib? | Nota |
|-------|--------|------|
| Tarikh Tamat Papar | Pilihan | `datetime-local`. Auto-sembunyi dari pesakit selepas tarikh. Kosong = kekal. |
| Butang Tindakan (CTA) — Label + URL | Pilihan (berpasangan) | Kalau isi satu, **wajib** isi kedua-dua. Untuk jenis **Survey/Tindakan**, tukar jadi **Pautan Borang** (cth Google Form). |

### Khusus EVENT (kad "Maklumat Event")
| Field | Wajib? | Nota |
|-------|--------|------|
| **📅 Tarikh Event** `*` | ✅ **WAJIB** | |
| **🕒 Masa Mula** `*` | ✅ **WAJIB** | |
| 🕒 Masa Tamat | Pilihan | Kosong = tiada masa tamat. |
| **📍 Nama Lokasi** `*` | ✅ **WAJIB untuk F2F** | Untuk event **online**, lokasi jadi opsyenal. |
| 📍 Alamat Lokasi | Pilihan | F2F sahaja. |
| 🗺 Google Maps URL **/** 📹 Pautan Sertai | Pilihan | F2F = Maps URL (`maps_url`). Online = pautan Meet/Zoom (`meet_link`). Bertukar ikut mod jenis. |
| 👤 Pengendali Program (peranan + nama) | Pilihan | Peranan: Penceramah / Coach / Moderator. |
| 👥 Kapasiti Peserta | Pilihan | Kosong = tiada had. |

> **Field tambahan dalam modal `events.html`** (tak ada di borang cipta): **Tag** (label kad), **Mod** (online/F2F), **Harga (RM, 0 = percuma)**, **Pautan rakaman** (selepas acara), dan **Status** (Published/Draft/Completed/Cancelled).

---

## 6. Apa jadi lepas Simpan

### Pengumuman biasa
1. Insert ke **`psy_announcements`** (`title`, `body`, `category`, `tag`, `image_url`, `audience`, `package_ids`, `cta_label`, `cta_url`, `expires_at`).
2. `is_active = true` kalau **Publish**, `false` kalau **Draft**.
3. Diarah ke `announcements.html`. Pesakit yang padan **sasaran** nampak di `roles/patient/announcements.html` (kalau aktif & belum tamat).

### Event
1. Insert ke **`psy_events`** (`title`, `description`, `type`, `mode`, `start_at`, `end_at`, `location`, `address`, `maps_url`/`meet_link`, `capacity`, `host`, `host_role`, `cover_image`, `audience`, `package_ids`).
2. `status = 'published'` (papar) atau `'draft'` (sembunyi).
3. Diarah ke `events.html`. Pesakit nampak di `roles/patient/events.html` → boleh **daftar** (rekod ke `psy_event_registrations`).
4. **Reminder automatik** dijadualkan (lihat bawah). Pendaftar boleh ditanda **Hadir** & dieksport CSV dari modal **Pendaftar** di `events.html`.

### Reminder acara automatik (`supabase/functions/event-reminders/`)
- Cron (**tiap 15 minit**) panggil Edge Function `event-reminders`.
- Untuk acara **`status='published'`** yang akan mula dalam tetingkap reminder (default **30 minit** sebelum, ikut tetapan `psy_auto_messages` key `event_reminder`), hantar **WhatsApp** (via GoHighLevel) kepada setiap pendaftar yang ada no. telefon sah.
- **Idempotent**: setiap pendaftaran diperingat **sekali sahaja** (`psy_event_registrations.reminder_sent_at`).
- Tetapan template + masa reminder boleh diubah di UI **Mesej Automatik** (`auto-mesej.html`). Fungsi yang sama juga jalankan broadcast berulang (cth Manzil), peringatan Catatan Harian & alert kepatuhan coach.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Tajuk Pengumuman wajib diisi" | Isi field **Tajuk**. |
| "Ringkasan Pendek wajib diisi" | Isi **Ringkasan Pendek**. |
| "Pilih sekurang-kurangnya satu sasaran pengguna" | Tanda ≥1 dalam **Sasaran Pengguna**. |
| "Sila pilih sekurang-kurangnya satu pakej…" | Anda pilih **Pakej Tertentu** tapi tiada pakej ditanda. Pilih pakej atau tukar ke Semua Pesakit. |
| "Tarikh & Masa Mula event wajib diisi" | Isi **Tarikh** + **Masa Mula** untuk event. |
| "Nama Lokasi wajib diisi untuk event fizikal" | Event F2F mesti ada **Nama Lokasi** (atau tukar jenis ke Online). |
| "Sila isi URL/label untuk butang tindakan" | CTA berpasangan — isi **kedua-dua** Label & URL, atau kosongkan kedua-duanya. |
| "Gambar melebihi 5MB" | Kecilkan gambar sebelum upload (banner maks 5MB). |
| Pilihan **⚙️ Urus jenis / kategori** tak nampak | Hanya `super_admin` nampak. |
| Pesakit tak terima reminder WhatsApp | Pesakit tiada no. telefon sah (di-skip), acara bukan `published`, atau key `event_reminder` **off** di `auto-mesej.html`. Saluran hantar = `type:'SMS'` (di-route ke WhatsApp) — bukan WhatsApp rasmi. |
| Acara dibatalkan tapi pendaftar tak dimaklum | Auto-maklum hanya berlaku bila status ditukar **ke** `Cancelled` (loceng dalam app, bukan WhatsApp). |

---

## 8. Rujukan teknikal
- Borang cipta: [`roles/staff/pengumuman-baru.html`](../../../roles/staff/pengumuman-baru.html) · `submitForm()` ~ baris 446
- Edit pengumuman: [`roles/staff/pengumuman-edit.html`](../../../roles/staff/pengumuman-edit.html)
- Senarai/edit acara: [`roles/staff/events.html`](../../../roles/staff/events.html) · `saveEvent()` ~ baris 312 · [`acara-detail.html`](../../../roles/staff/acara-detail.html)
- Senarai pengumuman: [`roles/staff/announcements.html`](../../../roles/staff/announcements.html) · [`announcement-detail.html`](../../../roles/staff/announcement-detail.html)
- Paparan pesakit: [`roles/patient/announcements.html`](../../../roles/patient/announcements.html) · [`events.html`](../../../roles/patient/events.html) · [`event-detail.html`](../../../roles/patient/event-detail.html)
- Reminder automatik: [`supabase/functions/event-reminders/index.ts`](../../../supabase/functions/event-reminders/index.ts) · [README](../../../supabase/functions/event-reminders/README.md)
- Jadual: `psy_announcements`, `psy_events`, `psy_event_registrations`, `psy_announcement_types`, `psy_announcement_categories`, `psy_auto_messages` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
</content>
</invoke>


---


# ===== staff/peranan.md =====

# Panduan: Peranan & Kebenaran (RBAC), Urus Staf & Audit 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Kawal **siapa boleh buat apa** dalam sistem ISW. Tiga tugas berkaitan:
- **Peranan & Kebenaran (RBAC)** — tetapkan kebenaran modul (lihat/cipta/edit/padam) untuk setiap peranan, dan buat *override* khas untuk individu tertentu.
- **Manage Staff** — daftar akaun staf baru, tetapkan peranan mereka, edit/nyahaktif/padam.
- **Audit** — baca log siapa ubah apa (kebenaran, peranan, dan tindakan operasi).

> Sistem guna **5 peranan staf**: `super_admin` (bypass semua), `admin`, `manager`, `doctor`, `coach`. authGuard guna peta `PAGE_MODULE` → `can(module, action)` untuk benarkan/sekat setiap halaman. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

## 2. Siapa boleh buat
| Tugas | Peranan dibenarkan |
|-------|--------------------|
| **Peranan & Kebenaran** (`peranan.html`) | **`super_admin` SAHAJA** — page block semua peranan lain dan halau ke dashboard |
| **Audit Kebenaran** (`audit-kebenaran.html`) | **`super_admin` SAHAJA** |
| **Manage Staff** (`staff_management.html`) | Staf dengan kebenaran modul **`staff`** — biasanya `super_admin`, `admin`. Butang "Tambah/Edit/Padam" muncul ikut `can('staff','create'/'edit'/'delete')` |
| **Audit Log** (`audit.html`) | Staf dengan kebenaran modul **`audit`** |

## 3. Lokasi
Semua di sidebar staf bawah kategori **PENTADBIRAN** dan **SISTEM**:
- **Peranan & Kebenaran:** Sidebar → **SISTEM → Peranan & Kebenaran** (`roles/staff/peranan.html`)
- **Audit Kebenaran:** Sidebar → **SISTEM → Audit Kebenaran** (`roles/staff/audit-kebenaran.html`)
- **Audit Log:** Sidebar → **SISTEM → Audit Log** (`roles/staff/audit.html`)
- **Manage Staff:** Sidebar → **PENTADBIRAN → Manage Staff** (`roles/staff/staff_management.html`)
  - Edit satu staf: klik baris staf → buka `roles/staff/staff-detail.html?id=...`

---

## 4. Langkah ringkas

### A. Set kebenaran modul untuk satu peranan
1. Buka **Peranan & Kebenaran**. Senarai peranan di kiri.
2. Klik peranan (cth **Coach**) → matriks **Modul × Aksi** muncul di kanan.
3. **Klik kotak** dalam matriks untuk toggle (hijau ✓ = dibenarkan, kosong = tidak).
4. Klik **💾 Simpan Perubahan**. (Butang aktif hanya bila ada perubahan; tunjuk bilangan, cth "💾 Simpan (3 perubahan)".)

> Matriks **Super Admin terkunci** (sentiasa semua ✓) — ia bypass semua semakan, tak boleh diubah.

### B. Override kebenaran per-pengguna
1. Dalam page yang sama, pilih peranan pengguna itu dahulu (supaya default role dimuat).
2. Skrol ke **"Pengguna dalam peranan ini"** → klik nama pengguna.
3. Modal override buka — **klik kotak** untuk *kitar*: dari default → grant tambahan **atau** sekat (revoke) → kembali default.
4. Override **disimpan serta-merta** (tiada butang simpan berasingan). Klik **Selesai**.

> Hijau biasa = ikut default role · hijau berkilau = **grant tambahan** · merah ✕ = **disekat**. Butang **Buang Semua Override** kosongkan semua override individu.

### C. Tambah & urus staf, tetapkan peranan
1. Buka **Manage Staff** → **+ Tambah Staff**.
2. Isi **Staff ID, Name, Email**, pilih **Option** (Email Invite atau Set password), pilih **Staff Role**.
3. Klik **Daftar**. Untuk edit: klik baris staf → ubah di `staff-detail.html` → **Simpan**.

### D. Baca audit log
1. **Audit Kebenaran** untuk perubahan RBAC; **Audit Log** untuk tindakan operasi.
2. Tetapkan **Dari/Hingga**, pilih **Jenis Aktiviti** / **Modul** / **Aktor**, klik **🔍 Tapis**.

---

## 5. Field — wajib vs pilihan

### Borang "Daftar Staff Baru" (Manage Staff)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Staff ID** `*` | ✅ **WAJIB** | Disimpan sebagai `registration_no`. Mesti unik — sistem block kalau dah wujud. Cth: `STF-001` |
| **Name** `*` | ✅ **WAJIB** | Nama penuh staf |
| **Email** `*` | ✅ **WAJIB** | Emel log masuk (jadi pengguna auth) |
| **Option** | Default `Email Invite` | `Email Invite (auto)` = sistem hantar jemputan set kata laluan · `Set password` = anda set terus |
| Password | Wajib bila Option = Set password | Min **6 aksara**. Staf boleh tukar dari Profil kemudian |
| **Staff Role** `*` | ✅ **WAJIB** | Senarai dari `psy_roles` aktif. **`super_admin` SENGAJA tak disenaraikan** — assign via SQL sahaja untuk keselamatan |

### Borang Edit Staf (`staff-detail.html`)
| Field | Nota |
|-------|------|
| Staff ID / Name / Email | Kemaskini maklumat asas |
| **Staff Role** | Tukar peranan staf (dropdown) |
| **Status** (Aktif/Tidak Aktif) | `is_active` — Tidak Aktif = staf tak boleh akses sistem |
| Jabatan / Specialization | Pilihan; dipapar dalam jadual |

### Modal "Peranan Baru / Edit Peranan" (RBAC)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Kod** `*` | ✅ **WAJIB** | Huruf kecil + underscore sahaja (`^[a-z_]+$`). **Tak boleh diubah** selepas dicipta. Cth: `receptionist` |
| **Nama Paparan** `*` | ✅ **WAJIB** | Cth: `Receptionist` |
| Penerangan | Pilihan | Penerangan ringkas peranan |
| Ikon / Warna | Pilihan | Ikon emoji + warna chip (navy/purple/teal/green/gold/terracotta) |

### Matriks Kebenaran
- **Lajur = Aksi** (cth Lihat / Cipta / Edit / Padam — dari `psy_actions`).
- **Baris = Modul** (cth `patient`, `package`, `inventory`, `staff`, `audit` — dari `psy_modules`).
- Kotak **"—"** = aksi itu **Tidak Berkenaan** untuk modul tersebut (tak boleh diklik).
- Peranan `patient` papar modul scope pesakit sahaja (`pat_*`); peranan staf papar modul bukan-pesakit.

### Filter Audit Kebenaran
| Field | Nota |
|-------|------|
| Dari / Hingga | Julat tarikh (default 30 hari terakhir) |
| Jenis Aktiviti | grant/revoke (role), user grant/revoke, clear override, tukar peranan, cipta/edit/padam/aktif/nyahaktif peranan |
| Modul | Tapis ikut modul tertentu |
| Carian Aktor | Email/nama staf yang buat tindakan |

---

## 6. Apa jadi lepas Simpan

### Set kebenaran peranan (matriks)
1. Kebenaran ditulis ke **`psy_role_module_actions`** (insert untuk grant, delete untuk revoke).
2. Setiap perubahan dicatat ke **`psy_permission_audit`** (action `grant`/`revoke`, target = peranan).
3. **Berkuat kuasa serta-merta** untuk semua pengguna dalam peranan itu (pada log masuk seterusnya / muat semula kebenaran).

### Override per-pengguna
1. Ditulis ke **`psy_user_overrides`** (`grant_type` = `grant` atau `revoke`), atau dipadam bila kembali ke default.
2. Dicatat ke `psy_permission_audit` (action `user_grant`/`user_revoke`/`user_clear_override`).
3. Kebenaran berkesan dikira gabungan role default + override (lihat view `psy_user_effective_permissions`).

### Daftar staf
1. Akaun dicipta melalui **Edge Function `invite-staff`** (action `create`) — buat pengguna auth + rekod di `psy_profiles` (role = `staff`, `staff_role`, `registration_no`).
2. Jika "Email Invite" → emel jemputan dihantar; jika "Set password" → kata laluan ditetapkan terus.
3. Tindakan dicatat ke `psy_audit_log` (cth `staff.invited`, `staff.updated`, `staff.deleted`).
4. Senarai staf dimuat semula.

### Tukar peranan / status staf
- `staff_role` / `is_active` dikemaskini dalam `psy_profiles`; dicatat ke audit. Staf "Tidak Aktif" tak boleh log masuk guna sistem.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Halaman ini hanya untuk Super Admin." (lalu dihalau ke dashboard) | `peranan.html` & `audit-kebenaran.html` **super_admin sahaja**. Guna akaun super_admin. |
| Butang "+ Tambah Staff" / Edit / Padam tak muncul di Manage Staff | Tiada kebenaran modul `staff` (create/edit/delete). Minta super_admin grant di RBAC. |
| Matriks Super Admin tak boleh diklik | **Normal** — super_admin sentiasa ada semua kebenaran (terkunci). |
| "Staff ID sudah didaftarkan" | `registration_no` mesti unik. Guna ID lain. |
| "Nama dan email wajib diisi" / "Sila pilih Staff Role" | Lengkapkan field wajib `*` sebelum Daftar. |
| "Kata laluan mestilah min 6 aksara" | Option = Set password perlu kata laluan ≥ 6 aksara. |
| Tak nampak `super_admin` dalam dropdown daftar staf | **Sengaja** — assign super_admin via SQL sahaja untuk keselamatan. |
| "Tidak boleh padam — N pengguna masih guna peranan ini" | Ubah peranan pengguna tersebut dahulu sebelum padam peranan. |
| Peranan sistem tak boleh dipadam/nyahaktif | Peranan `is_system` (cth super_admin) dilindungi. Hanya peranan tambahan boleh dipadam. |
| Butang "Simpan Perubahan" (matriks) disabled | Tiada perubahan belum-simpan. Klik kotak dahulu. |
| Override tak nampak walau dah set | Pastikan peranan betul dipilih dahulu (default role mesti dimuat untuk kira override). |

---

## 8. Rujukan teknikal
- Page: [`roles/staff/peranan.html`](../../../roles/staff/peranan.html) — `saveMatrix()`, `cycleOverride()`, `saveRole()`
- Page: [`roles/staff/staff_management.html`](../../../roles/staff/staff_management.html) (senarai + daftar) · [`roles/staff/staff-detail.html`](../../../roles/staff/staff-detail.html) (edit) — guna Edge Function `invite-staff`
- Page: [`roles/staff/audit-kebenaran.html`](../../../roles/staff/audit-kebenaran.html) (RBAC) · [`roles/staff/audit.html`](../../../roles/staff/audit.html) (operasi)
- Guard: [`shared/authGuard.js`](../../../shared/authGuard.js) — `PAGE_MODULE`, `can(module, action)`, `loadPermissions()`
- Jadual: `psy_roles`, `psy_modules`, `psy_actions`, `psy_module_actions`, `psy_role_module_actions`, `psy_user_overrides`, view `psy_user_effective_permissions`; audit RBAC `psy_permission_audit`; audit operasi `psy_audit_log` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Konsep RBAC penuh: [05-peranan-akses.md](../../sistem/05-peranan-akses.md)


---


# ===== staff/pesakit-kyc-kob.md =====

# Panduan: Pengurusan Pesakit Baru — Lead → KYC → KOB 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Uruskan pesakit dari mula daftar (lead) sehingga sah dan sedia dirawat. Tiga peringkat utama: **(a)** tambah/assign pesakit baru, **(b)** semak & **lulus KYC** (sahkan identiti + biodata + kesihatan), dan **(c)** uruskan **sesi KOB** (Konsultasi Orang Baru / Konsultasi Overhaul Body) + slotnya. Bila KYC lulus, akaun pesakit jadi aktif; bila KOB selesai, pesakit boleh signup pakej.

> Lihat juga aliran modul A: [03-modul.md](../../sistem/03-modul.md) — *Onboarding Pesakit — KYC & KOB*.

## 2. Siapa boleh buat
- **Tambah / edit pesakit & assign coach:** staf dengan modul **`psy_patients`** — `super_admin`, `admin`, `manager`. **Coach** boleh "Assign to me" + edit pesakit yang ditugaskan kepadanya sahaja.
- **Semak & lulus KYC:** staf dengan modul **`kyc_forms`** (biasanya doktor/admin/manager). Padam KYC perlu kebenaran `kyc.delete`.
- **Senarai & detail KOB / tetapan slot:** staf dengan modul **`kob_list`** / akses jadual konsultasi. Padam KOB perlu kebenaran `kob.delete`.

(Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

## 3. Lokasi
- **Senarai pesakit + assign coach + pre-KYC:** Sidebar staf → **Pesakit** ([`roles/staff/patients.html`](../../../roles/staff/patients.html))
  - Tambah baru: butang **"+ Tambah Pesakit"** (admin/manager/coach sahaja nampak)
- **Semak KYC:** [`roles/staff/kyc-list.html`](../../../roles/staff/kyc-list.html) → klik **Semak** → [`roles/staff/kyc-review.html`](../../../roles/staff/kyc-review.html)
- **Sesi KOB:** [`roles/staff/kob-list.html`](../../../roles/staff/kob-list.html) → **Detail →** ([`kob-detail.html`](../../../roles/staff/kob-detail.html))
- **Tetapan slot KOB / cuti / override:** [`roles/staff/kob-slots.html`](../../../roles/staff/kob-slots.html)

---

## 4. Langkah ringkas

**A. Tambah / dapatkan lead (pesakit baru)**
1. Buka **Pesakit** → **+ Tambah Pesakit**.
2. Pilih **Jenis Pesakit**: `Pesakit Baru` (flow KOB penuh) · `Sedang Dalam Rawatan` (migrate, dah ada pakej) · `Pesakit Lama` (rekod sejarah).
3. Isi **Maklumat Peribadi**, **Waris/Kecemasan**, **Maklumat Perubatan**.
4. (Pilihan, **Pesakit Baru** sahaja) Tick **Tempah Slot KOB Sekali** → pilih mod, tarikh & slot.
5. Klik **Simpan**.

> Pesakit boleh juga daftar sendiri (signup) → isi KYC di app. Kes itu masuk terus ke senarai KYC tanpa staf tambah manual.

**B. Assign coach**
6. Dalam jadual, kolum **Coach / Terapi** → **Assign to me** (coach) atau urus dari tab **Belum Ditugaskan**. Klik **✕** untuk tarik balik.

**C. Semak & lulus KYC**
7. Buka **Semakan KYC** → tapis `Pending` → **Semak**.
8. Semak biodata, waris, sejarah kesihatan, **penanda risiko**, dokumen & **status persetujuan**.
9. (Jika tolak) Isi **Nota Semakan** wajib → **Tolak**. Jika OK → **Lulus KYC**.

**D. Uruskan KOB**
10. Buka **Senarai KOB** → tapis Hari Ini / Akan Datang → **Detail →** untuk tanda **Hadir** & **Selesai** + cadangan pakej.
11. (Tetapan) Di **Tetapan Jadual Konsultasi**, urus slot mingguan, cuti & override per-tarikh.

---

## 5. Field — wajib vs pilihan

### 5A. Tambah Pesakit (`patients.html` → modal "Tambah Pesakit Baru")

**Jenis Pesakit** menentukan field mana wajib. Untuk **Pesakit Baru**, hampir semua wajib; untuk **Sedang Dalam Rawatan** / **Pesakit Lama**, hanya Nama + IC + Telefon yang wajib (field lain jadi *(optional)* automatik).

| Field | Wajib? | Nota |
|-------|--------|------|
| **Nama Penuh** `*` | ✅ **WAJIB** (semua jenis) | — |
| **No. KP / Passport** `*` | ✅ **WAJIB** (semua jenis) | **Sistem block jika sudah wujud** — amaran masa taip + halangan keras masa Simpan. Mesti guna rekod sedia ada. |
| **Telefon** `*` | ✅ Wajib semua jenis | Untuk Pesakit Baru ia sebahagian set wajib. |
| **Jantina** `*` | Wajib (Pesakit Baru) | Butang Lelaki/Perempuan. |
| **Tarikh Lahir** `*` | Wajib (Pesakit Baru) | — |
| **E-mel** `*` | Wajib (Pesakit Baru) | — |
| **Pekerjaan** `*` | Wajib (Pesakit Baru) | — |
| **Alamat** `*` | Wajib (Pesakit Baru) | — |
| **Status Perkahwinan** `*` | Wajib (Pesakit Baru) | Bujang/Berkahwin/Janda/Duda. |
| **Masalah Kesihatan** `*` | Wajib (Pesakit Baru) | Checklist (≥1) + pilihan **Lain-lain**. |
| **Waris: Nama, No. KP, Telefon, Hubungan, E-mel** `*` | Wajib (Pesakit Baru) | Hubungan: Ibu/Bapa, Adik-Beradik, Suami/Isteri, Anak, atau Lain-lain. |
| Syarikat | Pilihan | — |
| Kod Rujukan | Pilihan | Kod kempen/promosi. |
| **Dirujuk Oleh — Kod Rujukan** | Pilihan | Kod pesakit yang merujuk (referral). Diproses jadi lejar bila KYC lulus. |
| Pakej Rawatan + Tarikh Mula | Pilihan | Pilih dari `psy_packages`. Jika dipilih → cipta rekod pembelian. |
| **Minggu Semasa Rawatan** | Pilihan (hanya "Sedang Dalam Rawatan") | Default `1`. Cth `3` = sistem cipta plan + buka minggu 1..durasi untuk backfill nota. |
| Berapa Lama Dialami | Pilihan | — |
| Ubat Yang Diambil | Pilihan | — |
| Status Outcome Rawatan + Nota | Pilihan (reporting) | OTW / Selesai / Berhenti / Meninggal. |
| Laporan Perubatan (fail) | Pilihan | PDF/imej, maks **20MB/fail**. |

**Tempah Slot KOB Sekali** (hanya **Pesakit Baru**, jika ticked):
| Field | Wajib bila tick? | Nota |
|-------|------------------|------|
| Mod Sesi | — | 🏥 F2F di Konsultasi · 💻 Online (online auto-jana meet link). |
| Tarikh `*` | ✅ | **Block jika Isnin/Selasa** (konsultasi tutup) atau tarikh cuti (`psy_clinic_closures`). |
| Slot Waktu `*` | ✅ | Hanya slot aktif dari `psy_kob_slot_config` untuk hari itu. |

### 5B. Semak KYC (`kyc-review.html`)
Borang ini **papar sahaja** (data dari `psy_kyc_submissions`). Satu-satunya input staf:
| Field | Wajib? | Nota |
|-------|--------|------|
| Nota Semakan | **Wajib jika Tolak** | Jika **Tolak** tanpa nota → sistem block. Jika Lulus, nota pilihan. |

### 5C. Tetapan Slot & Cuti (`kob-slots.html`)
**Tambah Slot Mingguan:**
| Field | Wajib? | Nota |
|-------|--------|------|
| Jenis Slot | Default `KOB` | KOB atau Rawatan. |
| **Masa Mula / Tamat** `*` | ✅ | Block jika kosong. Label auto-jana dari masa; tempoh auto-kira. |
| **Hari** `*` | ✅ (≥1) | Default Rabu–Ahad. Isnin/Selasa biasanya tutup. Hari yang sudah ada slot masa sama ditanda *conflict* + dimatikan. |
| Status Default | Default `ON` | ON/OFF. |
| Nota | Pilihan | Maks 150 aksara. |

**Tambah Tarikh Cuti:** **Tarikh** `*` + **Label** `*` wajib; Kategori (default Cuti Umum) + Nota pilihan. Cuti auto-lock kalendar tempahan.

---

## 6. Apa jadi lepas Simpan

### Tambah Pesakit (`savePatient()`)
1. Insert ke **`psy_patients`** — auto-jana MRN `P-001`, `P-002`… (`created_by_staff: true`, `user_id: null` sehingga pesakit claim ikut IC bila signup).
2. Status & `kob_status` ikut jenis: **Pesakit Baru** → `status='unregistered'`, `kob_status='booked'` (jika tempah slot) atau `'kyc_done'`; **Sedang Dalam Rawatan** → `unregistered` + `kob_status='na'`; **Pesakit Lama** → `inactive` + `kob_status='na'`.
3. Jika pilih pakej → insert **`psy_package_purchases`** (`status='active'`, `payment_method='staff_assigned'`).
4. Jika **Sedang Dalam Rawatan** + pakej → cipta **`psy_treatment_plans`** + seed N baris **`psy_plan_weekly_progress`** (audit `plan.staff_seeded`).
5. Jika **Pesakit Baru** → cipta **`psy_kyc_submissions`** terus berstatus **`approved`** (`reviewed_by` = staf). Jika tempah slot → insert **`psy_kob_sessions`** (`status='booked'`; audit `kob.staff_booked`).
6. Jika ada "Dirujuk Oleh" → cipta baris referral. Laporan perubatan dimuat naik ke Storage + simpan ke `psy_patients.documents`.
7. Audit log: **`patient.created_by_staff`** (atau `patient.updated_by_staff` jika edit) ke **`psy_audit_log`**.

### Assign / Unassign coach
- `quickAssign` → update `psy_patients.coach_id` + `assigned_at`; audit **`patient.assigned`**.
- `doUnassign` → set `coach_id`/`assigned_at` = null; audit **`patient.unassigned`**.

### Lulus / Tolak KYC (`doReview()`)
1. Update `psy_kyc_submissions` → `status` + `reviewed_by` + `review_notes`.
2. **Auto-link**: jika ada rekod staf dengan IC sama & `user_id` null → pautkan **hanya jika nama + tarikh lahir padan** (cegah account takeover). Jika tak padan → audit **`kyc.autolink_blocked`** (tiada pautan dibuat).
3. Jika **Lulus** & pesakit ada `user_id`:
   - Update `psy_patients` → **`status='active'`** + salin semua biodata/kesihatan dari KYC.
   - Proses **referral** (jika ada `referred_by_code`) → update perujuk + insert `psy_referrals` (`status='pending'`).
   - Update `psy_profiles` (nama, telefon) + hantar **`psy_notifications`** "KYC Diluluskan ✅".
4. Jika **Tolak**: jika sebelum ini `approved`, pesakit di-revert ke `status='pending_kyc'`; hantar notifikasi minta semakan.
5. Audit log: **`kyc.approved`** / **`kyc.rejected`** ke `psy_audit_log`.

### KOB & Slot
- Tanda hadir/selesai + cadangan pakej diuruskan di `kob-detail.html` (kemaskini `psy_kob_sessions`). Senarai papar "Signup Pakej" ikut `kob_status='completed'` + `active_package_id` pesakit.
- Slot: insert/update/delete **`psy_kob_slot_config`**; cuti → **`psy_clinic_closures`**; override → **`psy_slot_date_overrides`**. Setiap perubahan tulis audit (`clinic_slot.*`). **Keutamaan booking:** Cuti mengatasi slot mingguan → Override per-tarikh mengatasi kedua-duanya.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "🚫 No. KP … sudah wujud — …" | IC sudah ada. Guna rekod sedia ada (cari di senarai), jangan cipta baru. |
| "Semua field bertanda * wajib diisi untuk Pesakit Baru." | Lengkapkan semua field `*`. Atau tukar jenis ke "Sedang Dalam Rawatan"/"Pesakit Lama" jika sesuai (hanya Nama+IC+Telefon wajib). |
| "🚫 Konsultasi tutup Isnin & Selasa." | Pilih hari Rabu–Ahad untuk slot KOB. |
| Slot KOB kosong / "Tiada slot tersedia" | Tiada slot aktif untuk hari itu, atau tarikh adalah cuti. Tambah/aktifkan slot di **Tetapan Jadual Konsultasi**. |
| Butang "+ Tambah Pesakit" tak nampak | Hanya admin/manager/coach. Coach lain tak nampak. |
| "Anda tidak dibenarkan edit pesakit ini" | Coach hanya boleh edit pesakit yang ditugaskan kepadanya; admin/manager boleh semua. |
| Tak boleh Tolak KYC | Nota Semakan wajib diisi sebelum tekan **Tolak**. |
| KYC lulus tapi rekod staf tak terpaut | Nama / tarikh lahir tak padan dengan rekod staf → auto-link diblok (`kyc.autolink_blocked`). Semak & paut manual (modal "Link Akaun"). |
| Pesakit baru tak nampak akaun selepas signup | `user_id` null sehingga pesakit claim ikut IC. Pautkan manual jika perlu. |

---

## 8. Rujukan teknikal
- Pages: [`roles/staff/patients.html`](../../../roles/staff/patients.html) (`savePatient()` ~baris 1110, `quickAssign`/`doUnassign` ~baris 1812) · [`kyc-list.html`](../../../roles/staff/kyc-list.html) · [`kyc-review.html`](../../../roles/staff/kyc-review.html) (`doReview()` ~baris 377) · [`kob-list.html`](../../../roles/staff/kob-list.html) · [`kob-slots.html`](../../../roles/staff/kob-slots.html) (`submitSlotModal()` ~baris 748)
- Jadual: `psy_patients`, `psy_kyc_submissions`, `psy_kob_sessions`, `psy_kob_slot_config`, `psy_clinic_closures`, `psy_slot_date_overrides`, `psy_package_purchases`, `psy_treatment_plans`, `psy_referrals`, `psy_audit_log` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Aliran modul: [03-modul.md](../../sistem/03-modul.md) — bahagian A (Onboarding) & C (Penjadualan)


---


# ===== staff/pesanan.md =====

# Panduan: Pesanan & Tracking (Orders) 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Urus pesanan kedai yang masuk dari pesakit — sahkan bayaran, bungkus, hantar parsel + isi nombor tracking, dan tandakan selesai. Setiap perubahan status menghantar notifikasi automatik ke pesakit, mengemaskini timeline pesakit, dan dicatat dalam audit log.

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`orders`**. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)
- **`orders` edit** — boleh tukar status, hantar parsel + isi tracking (butang "Hantar + Tracking" hanya muncul kalau ada kebenaran ini).
- **`orders` export** — boleh nampak baris statistik (Stat Cards) di atas.

## 3. Lokasi
- **Senarai pesanan (staf):** Sidebar staf → **OPERASI → Orders & Tracking** (`roles/staff/orders.html`)
- **Paparan pesakit:** `roles/patient/orders.html` (pesakit nampak status + timeline + tracking sendiri sahaja)

---

## 4. Langkah ringkas

Setiap pesanan bergerak ikut aliran status: **Pending → Dibayar (paid) → Dibungkus (packed) → Dihantar (shipped) → Diterima (delivered)**.

1. Buka **Orders & Tracking**. Pesanan baru default ditapis ke chip **"Perlu Dihantar"** (paid + packed).
2. Cari pesanan guna kotak carian (nama pesakit atau no. order) atau klik chip status.
3. **Pending** → klik **✓ Sahkan Bayaran** (jadi `paid`). Atau **Batalkan** kalau perlu.
4. **Dibayar (paid)** → klik **📦 Tandakan Dibungkus** (pos) / **✅ Tandakan Sedia Pickup** (pickup). Stok ditolak di sini.
5. **Dibungkus (packed), pos** → klik **🚚 Hantar + Tracking** → modal terbuka:
   - Pilih **Kurier**, isi **Tracking Number** (wajib), (pilihan) upload gambar parsel/resit.
   - Klik **Tandakan Dihantar** (jadi `shipped`).
6. **Dibungkus (packed), pickup** → klik **✅ Sedia Pickup** (terus jadi `delivered`).
7. **Dihantar (shipped)** → tunggu pesakit klik "Saya Dah Terima Parsel". Boleh **Force Diterima** kalau perlu tandakan manual.

> Klik **Detail** pada mana-mana pesanan untuk lihat penuh: item, alamat, cap masa setiap status, dan maklumat tracking.

---

## 5. Field — wajib vs pilihan

### Carian & penapis (atas senarai)
| Kawalan | Nota |
|---------|------|
| Kotak carian | Cari ikut **nama pesakit** atau **no. order** (`order_ref`). |
| Susun | `Terbaru dulu` (default) · `Terlama dulu` · `Jumlah ↓` |
| Kad / Jadual | Tukar paparan senarai (kad atau jadual). |
| Chip status | `Perlu Dihantar` (default) · Semua · Pending · Dibayar · Dibungkus · Dihantar · Diterima · Batal. Setiap chip ada kiraan. |

### Modal "🚚 Hantar Parsel"
| Field | Wajib? | Nota |
|-------|--------|------|
| **Tracking Number** `*` | ✅ **WAJIB** | Satu-satunya field yang sistem block kalau kosong ("Masukkan tracking number dahulu"). Cth: `JT1234567890` |
| Kurier | Default `J&T Express` | Pilihan: J&T Express · Pos Laju · DHL · Ninja Van · Grab Express · Lain-lain |
| Gambar Parsel / Resit | Pilihan | JPG/PNG. Disimpan ke storage `order-photos`; pesakit nampak dalam tracking mereka. Kalau upload gagal, status tetap dikemaskini (gambar di-skip). |

> **Pickup vs Pos** ditetapkan masa pesakit buat order (`delivery_method`), bukan di sini. Order pickup **tidak** ada modal tracking — terus dari packed ke diterima.

---

## 6. Apa jadi lepas tukar status
Setiap kali status ditukar (fungsi `markStatus`):
1. Rekod dikemaskini di jadual **`psy_orders`** — `status`, `updated_at`, dan cap masa berkaitan (`paid_at` / `packed_at` / `shipped_at` / `delivered_at`).
2. **Stok ditolak** kali pertama masuk `packed` — `psy_products` dikurangkan ikut item, dan disync ke Inventori ikut nama (`shared/stockSync.js`).
3. **Stok dipulangkan** kalau order dibatalkan selepas `packed`/`shipped`.
4. Tindakan dicatat ke audit log: `order.paid` / `order.packed` / `order.shipped` / `order.delivered` / `order.cancelled` (`psy_audit_log`), termasuk `order_ref` dan status sebelum.
5. **Notifikasi** dihantar ke pesakit (`psy_notifications`) dengan mesej ikut status (cth dihantar: sertakan no. tracking). Pesakit nampak di `roles/patient/orders.html`.
6. Pada `shipped`: `tracking_number`, `courier`, dan `tracking_photo_url` (jika ada) disimpan ke pesanan.
7. Timeline pesakit bergerak ke step seterusnya. Untuk pos: Order Dibuat → Bayaran → Dibungkus → Dihantar → Diterima. Untuk pickup: Order Dibuat → Bayaran → Sedia Pickup → Diambil. Order pos yang `shipped` ada butang **Track →** (link semakan J&T) di pihak pesakit.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Masukkan tracking number dahulu" | Field **Tracking Number** dalam modal hantar kosong. Isi dahulu. |
| Butang "Hantar + Tracking" tak muncul | Tiada kebenaran **`orders` edit**. Minta admin tambah peranan. |
| Stat Cards tak nampak | Tiada kebenaran **`orders` export** — normal untuk sesetengah peranan. |
| Stok tak berkurang | Stok hanya ditolak masa **kali pertama** masuk `packed`. Item perlu ada `id` + `qty` dan wujud di `psy_products`. |
| Gambar parsel tak naik | Upload gagal (di-skip secara senyap) — status tetap jadi `shipped`. Cuba upload semula dari Detail, atau abaikan (pilihan sahaja). |
| Order pickup tiada butang tracking | Memang betul — order pickup terus dari "Sedia Pickup" (`packed`) ke "Diambil" (`delivered`), tiada tracking. |
| Pesakit kata tak terima notifikasi | Notifikasi ditulis ke `psy_notifications` (link `orders.html`). Pastikan `patient_id` order betul. |
| Tersilap batalkan order yang dah dibungkus | Stok dipulangkan automatik (restock), tapi notifikasi "dibatalkan" sudah dihantar — maklum pesakit secara manual. |

---

## 8. Rujukan teknikal
- Page staf: [`roles/staff/orders.html`](../../../roles/staff/orders.html) · `markStatus()` ~ baris 469, `confirmShip()` ~ baris 558
- Page pesakit: [`roles/patient/orders.html`](../../../roles/patient/orders.html) · `confirmDelivered()` ~ baris 295
- Jadual: `psy_orders` (lifecycle paid→packed→shipped→delivered), `psy_products`, `psy_notifications`, `psy_audit_log` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Sync stok: [`shared/stockSync.js`](../../../shared/stockSync.js)
- Storage gambar parsel: bucket `order-photos`


---


# ===== staff/produk.md =====

# Panduan: Produk & Kedai (E-Dagang) 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Tambah (atau kemaskini) produk untuk **Kedai pesakit** (shop à la carte) — termasuk nama, harga, gambar, stok, kategori dan tetapan paparan. Produk yang **Aktif** akan muncul untuk pesakit beli secara individu tanpa pakej.

> **Penting:** Setiap produk WAJIB datang dari **Inventori** sebagai *source of truth*. Stok produk auto-sync dengan item inventori dengan **nama yang sama**. Sebab itu, untuk produk baru anda **mesti pilih item dari Inventori dulu** — bukan taip nama bebas.

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`products`** — biasanya `super_admin`, `admin`, `manager`. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)
- Butang **+ Tambah Produk** hanya muncul kalau ada kebenaran `products.create`.
- Butang **🗑️ Padam** hanya muncul kalau ada kebenaran `products.delete`.

## 3. Lokasi
- **Senarai produk:** Sidebar staf → **OPERASI → Produk** (`roles/staff/products.html`)
- **Borang tambah/edit:** `roles/staff/product-edit.html`
  - Tambah baru: butang **"+ Tambah Produk"** di `products.html`
  - Edit: klik ikon **✏️** pada baris produk, atau buka detail → **✏️ Edit Produk**
- **Detail produk:** `roles/staff/product-detail.html` (lihat ringkasan, log aktiviti)
- **Pesakit nampak di:** `roles/patient/shop.html` (Kedai)

---

## 4. Langkah ringkas

1. Buka **Produk** → klik **+ Tambah Produk**.
2. Skrin paparkan banner **"Pilih item dari Inventori dulu"** → klik **📦 Pilih dari Inventori**.
3. Dalam modal picker, cari & pilih item → **✓ Pilih Item**.
   - Nama, SKU, unit, stok & min-stok auto-isi dari item inventori dan **dikunci** (read-only) supaya nama kekal padan.
4. Lengkapkan **Maklumat Asas** (kategori, status, penerangan).
5. Isi **Harga & Jualan** (harga jualan wajib; harga promosi pilihan).
6. (Pilihan) Semak **Stok & Inventori**, tetapan jejak inventori & amaran stok rendah.
7. (Pilihan) **Muat naik imej** produk, isi **Butiran Tambahan** (berat, supplier, tag, notes).
8. Semak **Visibility / Publication** (tunjuk di shop, featured, benarkan beli online).
9. Klik **💾 Simpan Produk**.

> **Edit produk sedia ada** tidak melalui picker — semua field boleh diubah terus.
> Boleh klik **💾 Simpan Draft** — ia set status ke `Draft` dan simpan (produk tak muncul di shop sampai diaktifkan).

---

## 5. Field — wajib vs pilihan

### Seksyen 1 — Maklumat Asas
| Field | Wajib? | Nota |
|-------|--------|------|
| **Nama Produk** `*` | ✅ **WAJIB** | Sistem block kalau kosong. Untuk produk baru, auto-isi dari Inventori & **dikunci**. Cth: `Young & Healthy Honey 500g` |
| **SKU / Product ID** `*` | ✅ **WAJIB** | Sistem block kalau kosong. Untuk produk baru, auto-jana dari nama (slug) & dikunci. Cth: `madu-yhh-500` |
| **Kategori** `*` | ✅ **WAJIB** | Sistem block kalau kosong. `Madu` · `Herba` · `Air Terapi` · `Supplements` · `Lain-lain` |
| Jenama | Pilihan | Cth: `Ibnu Sina Wellness` |
| **Status** `*` | Default `Aktif` | `Aktif` (muncul di shop) · `Draft` · `Tidak Aktif` |
| Penerangan ringkas | Pilihan | Maks 200 aksara. Dipapar di kad shop pesakit. |

### Seksyen 2 — Harga & Jualan
| Field | Wajib? | Nota |
|-------|--------|------|
| **Harga jualan (RM)** `*` | ✅ **WAJIB** | Sistem block kalau kosong / negatif. `0` = dipapar **"Percuma"**. |
| Harga promosi (RM) | Pilihan | Kosongkan jika tiada promo. Promo aktif bila harga promo `> 0` dan `< harga jualan`. |
| Tarikh tamat promosi | Pilihan | Selepas tarikh ini, harga jualan asal digunakan semula. Kosong = promo tiada had tamat. |

### Seksyen 3 — Stok & Inventori
| Field | Wajib? | Nota |
|-------|--------|------|
| **Stok semasa** `*` | Disyorkan | Jumlah unit. Untuk produk baru, auto-isi dari Inventori & dikunci. Kosong = `0`. |
| **Minimum stok** `*` | Default `5` | Ambang amaran "stok rendah". |
| **Unit** `*` | Default `unit` | `unit` · `botol` · `kg` · `gram` · `sachet` · `pak` · `set` · `kotak`. Auto dari Inventori & dikunci untuk produk baru. |
| Jejak inventori (toggle) | Default **ON** | Kemas kini stok automatik bila jualan berlaku. |
| Amaran stok rendah (toggle) | Default **ON** | Notifikasi bila stok ≤ minimum. |

### Seksyen 4 — Media Produk
| Field | Wajib? | Nota |
|-------|--------|------|
| Imej produk | Pilihan | PNG / JPG, **maks 2MB**. Imej utama dipapar di shop & senarai produk. Tiada imej = ikon default (📦). |

### Seksyen 5 — Butiran Tambahan
| Field | Wajib? | Nota |
|-------|--------|------|
| Berat / Saiz | Pilihan | Cth: `500g` / `1kg` / `30ml` |
| Supplier | Pilihan | Cth: `Ibnu Sina Supplier` |
| Tag / Label | Pilihan | Tekan **Enter** untuk tambah satu-satu. |
| Notes | Pilihan | Catatan dalaman. Maks 500 aksara. |

### Seksyen 6 — Visibility / Publication
| Field | Wajib? | Nota |
|-------|--------|------|
| Produk kelihatan di shop (toggle) | Default **ON** | Papar di senarai shop pesakit. |
| Produk pilihan / featured (toggle) | Default **OFF** | Tanda sebagai produk pilihan. |
| Benarkan pembelian online (toggle) | Default **ON** | Pelanggan boleh beli produk ini secara online. |

---

## 6. Apa jadi lepas Simpan
1. Rekod ditulis ke jadual **`psy_products`** (insert kalau baru, update kalau edit).
2. `is_active` diset ikut status (`active` = `true`).
3. Gambar baharu (kalau ada) dimuat naik ke storage bucket `product-images`, dan `image_url` / `image_urls` dikemaskini.
4. Tindakan dicatat ke audit log: `product.created` / `product.updated` (`psy_audit_log`) — muncul di **Log Aktiviti** pada detail produk.
5. Diarah ke **`product-detail.html`** untuk produk tersebut.
6. Produk kini muncul untuk pesakit di `roles/patient/shop.html` (kalau status **Aktif**).

> **Arah sync SATU HALA sahaja (Inventori → Produk):** stok & unit di borang Produk sentiasa read-only — nilai ikut Inventori (dikemaskini oleh `syncStockToProducts()` bila item Inventori disimpan). Borang Produk **tidak** menulis balik ke Inventori lagi (bug lama dibetulkan). Nak ubah stok sebenar, pergi ke **Inventori**. (Kekecualian: pesanan/order yang benar-benar consume stok — `orders.html` — turut kemas kini Inventori via `syncStockToInventory()`, sebab itu pergerakan stok sebenar.)

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Nama produk diperlukan" | Pilih item dari Inventori dulu (produk baru) atau isi nama. |
| "SKU diperlukan" | SKU kosong — auto-jana dari nama, atau isi manual (edit). |
| "Sila pilih kategori" | Pilih satu kategori dalam dropdown. |
| "Harga tidak sah" | Harga kosong / negatif. Isi nombor ≥ 0. |
| "Imej terlalu besar (max 2MB)" | Kecilkan imej sebelum muat naik. |
| Picker Inventori kosong / item tak boleh dipilih | Item bertanda **✓ Dah jadi produk** (sudah ada produk nama sama) atau **⛔ Stok kosong** tidak boleh dipilih. Tiada item sesuai? **Tambah di Inventori dulu** (`inventory.html`). |
| Nama / SKU tak boleh diubah | Normal untuk produk baru — field dikunci supaya nama padan dengan Inventori. |
| Stok / Unit tak boleh diubah | Normal, sentiasa dikunci — Inventori adalah source of truth. Untuk ubah stok, kemas kini di **Inventori**; `syncStockToProducts()` akan cerminkan balik ke produk. |
| Produk tak muncul di shop pesakit | Pastikan status **Aktif** (`is_active`) DAN toggle **kelihatan di shop** ON. |
| Stok di shop tunjuk 0 walau ada stok | Nama produk tak padan mana-mana item Inventori. Samakan nama, atau pastikan ada `inventory_item_id`. |

---

## 8. Rujukan teknikal
- Senarai: [`roles/staff/products.html`](../../../roles/staff/products.html)
- Borang: [`roles/staff/product-edit.html`](../../../roles/staff/product-edit.html) · `saveProduct()` ~ baris 420
- Detail: [`roles/staff/product-detail.html`](../../../roles/staff/product-detail.html)
- Auto-sync stok Inventori → Produk: [`shared/stockSync.js`](../../../shared/stockSync.js) (`syncStockToProducts`, `ensureInventoryCounterpart`); `syncStockToInventory` kini dipanggil hanya bila stok betul-betul consume (`orders.html`), bukan dari borang Produk.
- Paparan pesakit: [`roles/patient/shop.html`](../../../roles/patient/shop.html) · `loadProductsFromDB()`
- Jadual: `psy_products`, `psy_inventory_items` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))


---


# ===== staff/surat-rasmi.md =====

# Panduan: Surat Rasmi (Keluarkan Surat untuk Pesakit) 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Keluarkan surat rasmi ISW untuk pesakit (cth: surat KWSP, PERKESO, RELA, pengesahan rawatan, sokongan) — pilih templat, isi maklumat khas, tandatangan secara digital, dan jana surat siap-letterhead. Pesakit boleh terus buka, cetak, atau simpan PDF surat tersebut dari akaun mereka.

Aliran lengkap ada 2 sebelah:
- **Pesakit mohon** → staf **lulus & tandatangan** → surat masuk akaun pesakit.
- Staf juga boleh **terus keluarkan** surat tanpa permohonan (cth surat dalaman, atau bila pesakit minta secara walk-in).

---

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`surat`**:
- **`create`** — boleh keluarkan surat baharu & ada butang "+ Surat / Pesakit Baru".
- **`approve`** — boleh lulus & tandatangan permohonan pesakit.
- **`edit`** — admin: boleh cipta/edit templat surat & auto-field.
- **`delete`** — boleh padam permohonan / surat dikeluarkan / templat.

Sesetengah templat **kunci approver tertentu** (`requires_specific_approver`) — hanya staf yang ditetapkan (atau `super_admin`) boleh tandatangan. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

---

## 3. Lokasi
- **Senarai surat & permohonan:** Sidebar staf → **OPERASI → Surat** (`roles/staff/surat.html`)
  - Tab **📋 Senarai Surat** — semua permohonan + surat dikeluarkan, dengan stat (Semua / Draf / Menunggu Kelulusan / Selesai / Dibatalkan).
  - Tab **🗂️ Templat** — senarai templat (Untuk Pesakit / Kegunaan Dalaman).
- **Keluarkan surat (wizard 3-langkah):** `roles/staff/surat-issue.html`
  - Surat baharu: butang **"+ Surat / Pesakit Baru"** di `surat.html`, atau **📝 Guna** pada baris templat.
  - Lulus permohonan: menu **✍️ Lulus & Sign** pada baris status *Menunggu Kelulusan*.
- **Cipta/edit templat (wizard 4-langkah, admin):** `roles/staff/surat-edit.html`
- **Sisi pesakit:** `roles/patient/surat.html` — pesakit mohon surat & buka/cetak surat siap.

> **Nota:** Surat **tidak** dijana dari `patient-hub.html`. `patient-hub` hanya papar/simpan dokumen sedia ada (kategori `surat_rasmi` antara lain). Penjanaan surat sebenar hanya berlaku di `surat-issue.html`.

---

## 4. Langkah ringkas

**A. Keluarkan surat (staf):**
1. Buka **Surat** → klik **+ Surat / Pesakit Baru** (atau **📝 Guna** pada templat).
2. **Langkah 1 — Pilih Templat:** pilih templat surat → pilih **pesakit** (cari ikut nama atau No. K/P). *(Templat kategori dalaman tak perlu pesakit.)*
3. **Langkah 2 — Maklumat Surat:** sahkan **Tarikh Surat** + **No. Rujukan** (auto-jana), isi mana-mana **Maklumat Khas Templat** (field manual).
4. **Langkah 3 — Semak & Tandatangan:** semak pratonton di kanan → **lukis tandatangan** dalam kotak signature → klik **✍️ Lulus & Tandatangan**.
5. Surat tersimpan; pesakit dapat notifikasi. Buka semula untuk **cetak / simpan PDF**.

**B. Lulus permohonan pesakit:**
1. Di **Senarai Surat**, cari baris status **Menunggu Kelulusan** → menu ⋮ → **✍️ Lulus & Sign**.
2. Borang dibuka pra-isi dengan pesakit & templat → ikut Langkah 2–4 di atas.
3. Atau **✕ Tolak** → isi alasan (alasan dihantar sebagai notifikasi kepada pesakit).

> Pratonton di sebelah kanan update **secara langsung** setiap kali awak ubah field. Auto-field auto-isi dari rekod pesakit yang dipilih.

---

## 5. Field — wajib vs pilihan

### Wizard Keluarkan Surat (`surat-issue.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Templat Surat** `*` | ✅ **WAJIB** | Pilih dari senarai aktif (dikumpul: Untuk Pesakit / Kegunaan Dalaman). |
| **Pesakit** `*` | ✅ **WAJIB** (kecuali templat dalaman) | Cari ikut **Nama** atau **No. K/P**. Hanya pesakit `status = active`. |
| **Tarikh Surat** `*` | ✅ **WAJIB** | Default = hari ini. Tarikh ini jadi tarikh pada surat & `signed_at`. |
| No. Rujukan | Pilihan | Auto-jana format `ISW/<tahun>/0001` (urutan ikut jumlah surat dikeluarkan). Boleh edit untuk format khas. |
| Maklumat Khas Templat (field manual) | Ikut templat | Muncul kalau templat ada `fields`. Jenis: Text / Number / Date / Long. Auto-field (Nama, IC, Alamat dll) **tak perlu diisi** — auto-isi. |
| **Tandatangan** `*` | ✅ **WAJIB** | Lukis guna tetikus/jari. Kena ada coretan sebelum boleh "Lulus & Tandatangan". |

### Wizard Cipta/Edit Templat (`surat-edit.html`, admin)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Nama Template** `*` | ✅ **WAJIB** | Cth: `Surat untuk KWSP`. |
| **Kategori Surat** `*` | ✅ | `Untuk Pesakit` (pesakit boleh mohon) atau `Kegunaan Dalaman`. |
| Jenis Surat | Pilihan | Label bebas: `KWSP`, `RELA`, `PERKESO`, `MC`, `Sokongan`, dll — digunakan untuk filter & chip kategori. |
| **Isi Surat (body)** `*` | ✅ **WAJIB** | Taip teks; sisip pemboleh ubah `[KEY]` dari palette. |
| Kepada (recipient) / Tajuk Surat | Pilihan | Sokong `[KEY]` juga. |
| Field Manual | Pilihan | Medan yang staf isi semasa keluarkan surat (KEY mesti unik & ada nilai). |
| Auto Field | Global | Auto-isi dari DB (Patient/Staff/System). Default: `NAMA`, `IC`, `ALAMAT`, `TARIKH`, `RUJUKAN`, `STAFF_NAMA` dll. Boleh tambah custom (column DB + format date/currency). |
| Approver / Penyelaras | Pilihan | Staf yang bertanggungjawab lulus. Tanda **"Wajib hanya approver ini"** untuk kunci. |
| Status Template | Default Aktif | Tidak aktif = draft, tak muncul untuk patient request. |

### Borang permohonan pesakit (`roles/patient/surat.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Jenis Surat** `*` | ✅ | Dari templat kategori `patient` aktif, atau **"Lain-lain (taip sendiri)"**. |
| Nama Surat | Wajib bila "Lain-lain" | Muncul hanya bila pilih custom. |
| **Sebab / Tujuan** `*` | ✅ | Cth: `untuk failkan claim KWSP bulan depan`. |

---

## 6. Apa jadi lepas Simpan

**Bila staf klik "✍️ Lulus & Tandatangan":**
1. Rekod ditulis ke jadual **`psy_letter_issued`** — termasuk `field_values` (snapshot data), `ref_number`, `signature_url` (imej PNG tandatangan), `signed_by`, `signed_at`.
2. Kalau datang dari permohonan, **`psy_letter_requests`** untuk permohonan itu di-set `status = 'issued'`.
3. Pesakit dapat **notifikasi**: *"Surat Anda Sedia"* (kalau bukan templat dalaman).
4. Tindakan dicatat ke audit log: **`letter.issued`** (`psy_audit_log`).
5. Diarah balik ke **`surat.html`**; surat kini muncul di tab Senarai (status **Selesai**) dan di akaun pesakit (`roles/patient/surat.html` → "Surat Saya").

**Buka / Cetak / PDF:** Klik **📄 Buka / Cetak** (staf) atau **Buka / Cetak** (pesakit) → surat dirender penuh (letterhead + body + tandatangan + footer) dalam tab baru. Butang **"Cetak / Simpan PDF"** guna `window.print()` (saiz A4) — pengguna pilih *Save as PDF* dalam dialog cetak browser.

> **Nota teknikal:** PDF dijana melalui **print-to-PDF browser** (`openLetterTab` → `window.print()`), bukan pustaka pdf-lib. Tiada fail PDF disimpan ke Storage secara automatik — surat dirender semula on-demand dari `field_values` setiap kali dibuka.

**Bila permohonan ditolak:** `psy_letter_requests.status = 'rejected'` + `reject_reason`; pesakit dapat notifikasi dengan alasan. Audit: `letter.request_rejected`.

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Sila pilih templat" / "Sila pilih pesakit" | Langkah 1 belum lengkap. Templat pesakit **mesti** ada pesakit dipilih. |
| "Sila isi tarikh surat" | Tarikh Surat kosong di Langkah 2. |
| "Sila lukis signature dulu" | Kotak tandatangan kosong — lukis dulu sebelum klik Lulus & Tandatangan. |
| "Permohonan ini perlu kelulusan [nama] sahaja." | Templat kunci approver tertentu. Hanya approver itu (atau `super_admin`) boleh sign. |
| Pesakit tak nampak surat selepas dikeluarkan | Pastikan templat **bukan** kategori dalaman, dan pesakit ada `user_id` (akaun aktif) untuk terima notifikasi. |
| Templat tak muncul untuk pesakit mohon | Templat mesti kategori **Untuk Pesakit** + status **Aktif**. |
| Auto-field keluar kosong dalam surat | `data_path` (nama column DB) salah, atau rekod pesakit/staff tiada nilai itu. Semak di Auto Field (`surat-edit.html`). |
| No. Rujukan berlanggar / nak format khas | Edit medan **No. Rujukan** secara manual di Langkah 2. |
| Surat dah dikeluarkan tapi data salah | Tiada "edit" pada surat dikeluarkan — **padam** (jika ada kebenaran `delete`) dan keluarkan semula. Rekod hilang dari akaun pesakit juga. |

---

## 8. Rujukan teknikal
- Page senarai: [`roles/staff/surat.html`](../../../roles/staff/surat.html) — `loadData()`, `viewIssued()`, `confirmRejectReq()`
- Page keluarkan surat: [`roles/staff/surat-issue.html`](../../../roles/staff/surat-issue.html) — `confirmSign()` ~ baris 549, `buildIssueData()` ~ baris 445
- Page cipta/edit templat: [`roles/staff/surat-edit.html`](../../../roles/staff/surat-edit.html) — `saveTpl()`, default auto-fields `DEFAULT_AUTO_FIELDS_SEED` ~ baris 691
- Page pesakit: [`roles/patient/surat.html`](../../../roles/patient/surat.html) — `submitRequest()`, `viewLetter()`
- Renderer surat (letterhead + print PDF): [`shared/letterTemplates.js`](../../../shared/letterTemplates.js) — `renderLetterFull()`, `buildLetterValues()`, `openLetterTab()`
- Jadual DB: `psy_letter_templates`, `psy_letter_requests`, `psy_letter_issued`, `psy_letter_auto_fields` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Templat fizikal rujukan: folder [`surat/`](../../../surat/) (cth `Surat permohonan RELA.docx` / `.pdf`)
- Modul: [03-modul.md → K. Surat Rasmi & Isu Produk](../../sistem/03-modul.md)


---


# ===== staff/tambah-pakej.md =====

# Panduan: Tambah / Edit Pakej Rawatan 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Buat pakej rawatan baru (atau kemaskini yang sedia ada) yang pesakit akan langgan — termasuk harga, tempoh, jadual sesi mingguan, bekalan, jadual harian, dan kontrak yang pesakit tandatangan.

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`packages`** — biasanya `super_admin`, `admin`, `manager`. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

## 3. Lokasi
- **Senarai pakej:** Sidebar staf → **OPERASI → Pakej Rawatan** (`roles/staff/pakej.html`)
- **Borang tambah/edit:** `roles/staff/pakej-edit.html`
  - Tambah baru: butang **"+ Tambah Pakej"** di `pakej.html`
  - Edit: klik pakej sedia ada → **Edit**

---

## 4. Langkah ringkas

1. Buka **Pakej Rawatan** → klik **+ Tambah Pakej**.
2. Isi **Maklumat Asas** (nama, kategori, harga, tempoh, sesi seminggu).
3. Susun **Timeline Rawatan** setiap minggu (mode, bimbingan/aktiviti, bekalan).
4. (Pilihan) Tetapkan **Jadual Harian** default.
5. Isi **Kontrak Pakej** (tajuk + klausa, atau auto-fill dari PDF).
6. (Pilihan) **Nota Dalaman** + **Tetapan Lanjutan** (Gmeet, harga tambah minggu).
7. Klik **💾 Simpan Perubahan**.

> Boleh klik **💾 Simpan Draft** bila-bila masa — draf disimpan di browser (auto-save), tak masuk database lagi. Indikator "✓ Draf disimpan" akan muncul.

---

## 5. Field — wajib vs pilihan

### Header (atas borang)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Nama Pakej** `*` | ✅ **WAJIB** | Satu-satunya field yang sistem block kalau kosong. Cth: `OBP 1` |
| Package ID | Pilihan | ID unik. Kosongkan = sistem auto-jana (`M 001`, `M 002`…). Kalau isi, mesti unik. |
| Penerangan Ringkas | Pilihan | Cth: `12 minggu program intensif` |
| Status | Default `Aktif` | `Tidak Aktif` = pesakit tak nampak pakej dalam senarai langganan |
| Gambar Pakej (16:9) | Pilihan | JPG/PNG, maks 10MB. Ada tool zoom & posisi (crop). |

### Seksyen 1 — Maklumat Asas
| Field | Wajib? | Nota |
|-------|--------|------|
| **Kategori** `*` | Disyorkan | `Program Intensif` (standard) · `Pakej Percuma` (free) · `VIP / Premium` |
| **Harga (RM)** `*` | Disyorkan | Kosong = `0`. Model bayar sekali. |
| **Tempoh** `*` | Disyorkan | Nombor + unit **Minggu** atau **Hari**. Cth: `12` Minggu. |
| Bilangan sesi seminggu | Bila unit = Minggu | `1` atau `2` sesi. Cth: OB/NLC = 2 sesi, OBG = 1 sesi. |
| Pilihan hari sesi (variant) | Pilihan | Pilih hari (Isn–Ahd). Boleh tambah >1 variant — pesakit pilih satu masa daftar. Setiap variant mesti ada bilangan hari = bilangan sesi. |

> **Tempoh menentukan bilangan baris dalam Timeline.** Tukar tempoh = jadual mingguan dibina semula (`12 Minggu` → M1…M12).

### Seksyen 2 — Timeline Rawatan (setiap minggu / hari)
Untuk setiap baris **M1, M2, …**:
| Bahagian | Nota |
|----------|------|
| **Mode** | 🏥 F2F · 💻 Online · 🔀 Both (default Both) |
| **💡 Bimbingan & Aktiviti** | Pilih dari **Coaching Catalog** (`coaching-catalog.html`). Kalau tiada item, tambah dulu di catalog. |
| **📦 Bekalan** | Pilih dari **Inventory** (item individu) atau **Kit Prosedur** + isi kuantiti. Inilah yang **auto-tolak stok** bila coach tanda hadir. |
| **📎 Rujukan** (staff only) | Upload fail rujukan untuk coach (maks 20MB/fail). Pesakit tak nampak. |

### Seksyen 3 — Jadual Harian (default)
Template aktiviti harian (cth: ambil supplement pagi). Pesakit boleh ubah selepas langgan. Pilihan.

### Seksyen 4 — Kontrak Pakej
Pesakit baca + tandatangan selepas bayar.
| Field | Nota |
|-------|------|
| Tajuk Kontrak | Default `Kontrak Pelaburan Kesihatan` |
| Version | Cth: `ISW.SOP OB KOB FORM 03` |
| Klausa | Tambah satu-satu, **atau** klik **📄 Auto-fill dari PDF** (sistem extract klausa dari PDF kontrak). |

Pembolehubah dalam klausa: `{{patient_name}}`, `{{patient_ic}}`, `{{package_name}}`, `{{price}}`, `{{today}}`.

### Seksyen 5 — Nota Dalaman
Pentadbir sahaja nampak (tak dipapar ke pesakit). Maks 1000 aksara. Pilihan.

### Tetapan Lanjutan (collapsible)
| Field | Nota |
|-------|------|
| 🔗 Pautan Gmeet (default) | Satu link untuk semua minggu mode Online/Both |
| ➕ Harga Tambah Minggu (RM) | Caj 1 minggu tambahan bila pesakit miss sesi. Default `RM 50`. Lihat [peraturan absence](../../sistem/03-modul.md). |

---

## 6. Apa jadi lepas Simpan
1. Rekod ditulis ke jadual **`psy_packages`** (insert kalau baru, update kalau edit).
2. Package ID auto-dijana kalau kosong (`M 001`…).
3. Tindakan dicatat ke audit log: `package.created` / `package.updated` (`psy_audit_log`).
4. Draf browser dipadam.
5. Diarah ke **`pakej-detail.html`** untuk pakej tersebut.
6. Pakej kini muncul untuk pesakit di `roles/patient/pakej.html` (kalau status **Aktif**).

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Nama pakej wajib diisi" | Isi field **Nama Pakej** dulu. |
| "Package ID … dah digunakan" | ID tak unik. Tukar, atau kosongkan untuk auto-jana. |
| "Gambar melebihi 10MB" | Kecilkan gambar sebelum upload. |
| Bekalan kosong dalam picker | Tambah item dulu di **Inventory** / buat **Kit Prosedur**. |
| Bimbingan/Aktiviti kosong dalam picker | Tambah dulu di **Coaching Catalog** (`coaching-catalog.html`). |
| Variant hari ada amaran "Perlu N hari" | Bilangan hari dipilih mesti sama dengan bilangan sesi seminggu. |
| Sesetengah field tak tersimpan | Normal — kolum yang belum wujud dalam skema DB di-strip automatik. Jalankan migrasi skema terkini kalau perlu kolum tersebut. |

---

## 8. Rujukan teknikal
- Page: [`roles/staff/pakej-edit.html`](../../../roles/staff/pakej-edit.html) · `savePackage()` ~ baris 1614
- Jadual: `psy_packages` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Auto-tolak stok: [`shared/inventoryDeduct.js`](../../../shared/inventoryDeduct.js)


---
