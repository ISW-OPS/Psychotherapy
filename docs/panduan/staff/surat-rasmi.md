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
