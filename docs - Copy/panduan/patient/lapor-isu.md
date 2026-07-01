# Panduan: Lapor Isu & Maklum Balas (Pesakit) 🔵

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Dua saluran komunikasi pesakit dengan pihak ISW:
- **Lapor Isu (Report Issue)** — adu masalah konkrit (produk rosak, salah produk, kurang jumlah, tidak sampai, masalah appointment, lain-lain). Staf terima, sahkan, dan balas dalam **thread** perbualan dua hala.
- **Maklum Balas (Feedback)** — beri rating ⭐ + komen pengalaman rawatan (mingguan: coach + bekalan; atau keseluruhan selepas tamat program).

## 2. Siapa boleh buat
**Pesakit** yang sudah log masuk. Lapor Isu terbuka kepada semua pesakit. Maklum Balas pula bergantung status pakej (lihat Seksyen 5 — bahagian Feedback). Staf urus jawapan di sebelah mereka (kebenaran modul `issues` / `feedback` — lihat [Peranan & Akses](../../sistem/05-peranan-akses.md)).

## 3. Lokasi
- **Lapor Isu (borang + senarai):** Menu pesakit → **Lapor Isu** ([`roles/patient/issue.html`](../../../roles/patient/issue.html))
  - Tab **📋 Laporan Saya** — senarai isu lalu + status.
  - Tab **✏️ Hantar Isu Baru** — borang laporan.
- **Thread perbualan:** [`roles/patient/issue-thread.html`](../../../roles/patient/issue-thread.html) — buka dari mana-mana isu dalam senarai (butang **👁 Lihat** / **↩ Balas**).
- **Maklum Balas:** Menu pesakit → **Feedback** ([`roles/patient/feedback.html`](../../../roles/patient/feedback.html))
- **Sebelah staf:** [`roles/staff/issue.html`](../../../roles/staff/issue.html), [`roles/staff/issue-detail.html`](../../../roles/staff/issue-detail.html), [`roles/staff/feedback.html`](../../../roles/staff/feedback.html)

---

## 4. Langkah ringkas

### A) Lapor Isu baru
1. Buka **Lapor Isu** → klik tab **✏️ Hantar Isu Baru**.
2. **01 — Jenis Isu:** pilih satu kategori (kad radio).
3. **02 — Details Isu:** taip keterangan masalah.
4. **03 — Foto Bukti (optional):** klik untuk upload satu foto (JPG/PNG, maks 5MB).
5. Klik **Hantar Laporan**.
6. Sistem alih anda ke tab **📋 Laporan Saya** — isu baru muncul dengan status **⏳ Menunggu**.

### B) Balas dalam thread
1. Tab **📋 Laporan Saya** → klik **👁 Lihat** (belum dijawab) atau **↩ Balas** (sudah dijawab).
2. Baca perbualan (gelembung kanan = anda, kiri = staf).
3. Taip di kotak bawah → klik **Hantar ↩** (atau tekan **Ctrl+Enter**).
4. Balasan staf masuk **secara langsung (realtime)** tanpa perlu refresh.

### C) Hantar Maklum Balas
1. Buka **Feedback**. Sistem auto-pilih mod ikut status pakej anda:
   - **Feedback Minggu Ini** (pakej aktif) — pilih minggu → beri ⭐.
   - **Feedback Keseluruhan** (pakej tamat) — rating + tag + komen.
2. Beri rating, isi komen (optional), klik **Hantar Feedback**.

---

## 5. Field — wajib vs pilihan

### Lapor Isu — borang "Hantar Isu Baru" (`issue.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **01 — Jenis Isu** `*` | ✅ **WAJIB** | Pilih satu: 📦 Produk rosak · 🔄 Salah produk · ⚖️ Kurang jumlah · 🚚 Tidak sampai · 📅 Masalah appointment · 💬 Lain-lain. Tak pilih = "Sila pilih jenis isu". |
| **02 — Details Isu** `*` | ✅ **WAJIB** | Keterangan masalah (textarea). Kosong = "Sila isi deskripsi masalah". |
| **03 — Foto Bukti** | Pilihan | Satu foto, JPG/PNG, **maks 5MB**. Lebih 5MB ditolak. Kalau upload gagal, laporan **tetap dihantar** (cuma tanpa foto). |

> Borang hanya block pada **Jenis Isu** dan **Details** — kedua-duanya wajib. Foto sentiasa optional.

### Thread isu (`issue-thread.html`)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Balasan** `*` | ✅ **WAJIB** | Teks balasan. Kosong = "Sila tulis balasan terlebih dahulu." Hantar dengan butang **Hantar ↩** atau **Ctrl+Enter**. |

> Dalam thread, pesakit hanya boleh hantar **teks** (tiada lampiran foto pada balasan susulan).

### Maklum Balas — Mod Mingguan (`feedback.html`, pakej aktif)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Pilih Minggu** `*` | ✅ **WAJIB** | Hanya minggu yang sesinya sudah jalan (status `hadir` / `consultation_done`) muncul. Minggu yang sudah dirating ditanda **✓ (dirated)**. |
| **⭐ Pengalaman minggu ini** `*` | ✅ **WAJIB** | Rating 1–5 bintang. Kosong = "Sila bagi rating overall". |
| 👨‍⚕️ Rate coach | Pilihan | Muncul hanya jika minggu itu ada coach. |
| 📦 Bekalan minggu ini | Pilihan | Rating bintang untuk bekalan (cukup / tepat masa / quality). |
| Komen | Pilihan | Apa yang baik / boleh diperbaiki. |

### Maklum Balas — Mod Keseluruhan (`feedback.html`, pakej tamat)
| Field | Wajib? | Nota |
|-------|--------|------|
| Rating keseluruhan | Default `4` ⭐ | Klik bintang 1–5. |
| Yang paling membantu | Pilihan | Chip pilihan (cth: coach, supplement, library). Boleh pilih banyak. |
| Komen / testimonial | Pilihan | Pengalaman keseluruhan. |

> Selepas hantar dengan rating **≥ 4 ⭐**, sistem papar ajakan **Tulis Review di Google** (popup). Pautan Google Review hanya wujud dalam Mod Keseluruhan.
>
> **Mod Lock** 🔒 — kalau tiada pakej aktif **dan** tiada pakej tamat, Feedback dikunci: "Feedback tersedia selepas anda mula rawatan."

---

## 6. Apa jadi lepas Hantar

### Lapor Isu
1. Laporan ditulis ke jadual **`psy_audit_log`** dengan `action = 'issue.reported'` (foto disimpan dulu ke storage bucket **`issue-photos`**).
2. Isu muncul di tab **📋 Laporan Saya** dengan status **⏳ Menunggu**.
3. Staf nampak di [`roles/staff/issue.html`](../../../roles/staff/issue.html), buka di [`issue-detail.html`](../../../roles/staff/issue-detail.html), dan balas.
4. Bila staf balas (`action = 'issue.responded'`), status pesakit bertukar **✅ Dijawab** dan jawapan muncul dalam senarai + thread.
5. Mesej anda dalam thread direkod sebagai `action = 'issue.followup'`. Perbualan dua hala kekal di bawah `issue_id` yang sama, dipapar **realtime**.
6. Mesej tujuan di panel borang: *"Admin akan response dalam 24 jam."*

### Maklum Balas
1. Rating ditulis ke jadual **`psy_feedback`**:
   - Mingguan: `feedback_type = 'weekly'` + `week_number`, `coach_rating`, `supply_rating`.
   - Keseluruhan: `feedback_type = 'overall'` + `helpful_tags`.
2. Mesej "Feedback dihantar ✅". Minggu yang dirating ditanda **✓ (dirated)**.
3. Staf lihat agregat di [`roles/staff/feedback.html`](../../../roles/staff/feedback.html).
4. Klik pautan Google Review direkod ke `psy_audit_log` (`action = 'google_review.clicked'`).

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Sila pilih jenis isu" | Belum pilih kad **Jenis Isu**. Pilih satu dulu. |
| "Sila isi deskripsi masalah" | Field **Details Isu** kosong. Taip keterangan. |
| "Foto melebihi 5MB" | Foto terlalu besar. Kecilkan / pilih foto lain (maks 5MB). |
| "Laporan dihantar (foto gagal dimuat naik)" | Laporan **berjaya**, cuma upload foto gagal. Boleh sertakan semula foto dalam thread? (tidak — thread teks sahaja); hubungi staf dengan rujukan isu. |
| "Sila tulis balasan terlebih dahulu" | Kotak balasan thread kosong. Taip mesej dahulu. |
| Status kekal **⏳ Menunggu** | Staf belum balas. Jangkaan response dalam 24 jam. |
| Feedback dikunci 🔒 | Tiada pakej aktif/tamat. Feedback dibuka selepas rawatan bermula. |
| "Sila bagi rating overall" | Mod mingguan: belum klik bintang **Pengalaman minggu ini**. |
| Dropdown minggu kosong / "Belum ada minggu siap" | Belum ada sesi yang `hadir`/selesai. Tunggu sesi minggu berkenaan dijalankan. |

---

## 8. Rujukan teknikal
- Page lapor isu: [`roles/patient/issue.html`](../../../roles/patient/issue.html) · `submitIssue()` ~ baris 291
- Page thread: [`roles/patient/issue-thread.html`](../../../roles/patient/issue-thread.html) · `sendReply()` ~ baris 167, realtime ~ baris 217
- Page feedback: [`roles/patient/feedback.html`](../../../roles/patient/feedback.html) · `submitFeedback()` ~ baris 193, `submitWeeklyFeedback()` ~ baris 322
- Jadual: **`psy_audit_log`** (isu — `action` ∈ `issue.reported` / `issue.responded` / `issue.followup`) · **`psy_feedback`** (rating). Storage bucket foto: **`issue-photos`**. Lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md).
- Sebelah staf: [`roles/staff/issue.html`](../../../roles/staff/issue.html) · [`roles/staff/issue-detail.html`](../../../roles/staff/issue-detail.html) · [`roles/staff/feedback.html`](../../../roles/staff/feedback.html)
