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
