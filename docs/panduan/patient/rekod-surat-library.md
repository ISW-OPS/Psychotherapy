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
