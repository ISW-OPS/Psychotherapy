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
