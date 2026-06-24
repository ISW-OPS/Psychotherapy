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
