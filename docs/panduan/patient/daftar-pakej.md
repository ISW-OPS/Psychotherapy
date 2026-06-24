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
