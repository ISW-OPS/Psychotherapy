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
