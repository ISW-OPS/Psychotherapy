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
