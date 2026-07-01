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
