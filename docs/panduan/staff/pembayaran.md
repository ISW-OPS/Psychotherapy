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
