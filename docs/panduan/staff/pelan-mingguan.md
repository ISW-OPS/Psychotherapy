# Panduan: Pelan Mingguan & Tanda Hadir / Tidak Hadir Sesi 🟢

[← Kembali ke indeks panduan](../README.md)

---

## 1. Tujuan
Uruskan sesi rawatan pesakit minggu demi minggu — tetapkan tarikh sesi, tanda **Hadir** atau **Tidak Hadir**, rekod nota coach / skor / SOAP / vitals / kepatuhan, dan kendalikan ketidakhadiran (ingatkan pesakit, jadual semula, atau buka minggu tambahan berbayar). Tanda **Hadir** juga yang mencetuskan **auto-tolak stok** bekalan F2F minggu itu.

## 2. Siapa boleh buat
Staf dengan kebenaran modul **`plans`** / **`plan_week`** — biasanya `coach` (untuk pesakit yang ditugaskan kepadanya), `manager`, `admin`, `super_admin`. (Lihat [Peranan & Akses](../../sistem/05-peranan-akses.md).)

> Coach hanya nampak plan pesakit yang ditugaskan kepadanya (`coach_id`). Admin/manager nampak semua. Hanya `super_admin` nampak butang **Reset Sesi** / **Admin Tools**.

## 3. Lokasi
- **Senarai plan:** Sidebar staf → **OPERASI → Treatment Plans** (`roles/staff/plans.html`)
  - Cari pesakit, tapis ikut status (Aktif / Selesai / Tangguh).
- **Detail minggu (editor):** `roles/staff/plan-week.html?plan_id=…&week=…`
  - Klik kad pesakit di `plans.html` → terus buka minggu **semasa**.

> Plan **tidak** dicipta manual di sini — ia dijana automatik melalui aliran pakej (KOB / pembayaran). Lihat [Tambah Pakej](tambah-pakej.md).

---

## 4. Langkah ringkas

1. Buka **Treatment Plans** → klik pesakit untuk buka **Detail Minggu**.
2. Guna **← Minggu Sebelum / Minggu Seterusnya →** untuk ke minggu yang betul. (Kalau 2 sesi seminggu, pilih tab sesi — cth Jum / Sab.)
3. Tetapkan **Tarikh & Masa Sesi** (di kotak *Nota Coach*) — sistem cipta/kemaskini temujanji + notifikasi pesakit.
4. Selepas sesi berlaku, tekan **✅ Hadir** atau **❌ Tidak Hadir** di hero minggu.
5. Isi rekod sesi: **Score**, **Nota Minggu Ini**, **Kepatuhan Rawatan**, **Nota Doktor (SOAP)**, **Bacaan Vitals**, tanda checklist **Coaching Minggu Ini** (bimbingan + bekalan).
6. Kalau **Tidak Hadir**: **🔔 Ingatkan Pesakit** untuk reschedule sendiri, **atau** isi tarikh baru → **📅 Jadual Semula**.
7. Kalau pesakit sah nak sambung rawatan: tekan **➕ Buka Minggu Tambahan** (pesakit bayar — TIADA auto-caj).

> Kebanyakan field **auto-simpan** bila tukar / klik keluar (indikator "✓ Tersimpan" muncul). Nota coach & Kepatuhan perlu klik butang **Simpan**.

---

## 5. Field — wajib vs pilihan

### Hero Minggu (atas)
| Butang / Field | Wajib? | Nota |
|----------------|--------|------|
| Tab sesi (Jum / Sab …) | Auto | Hanya muncul kalau pakej **2 sesi seminggu**. Pilih sesi dulu — semua bahagian bawah ikut sesi aktif. |
| **✅ Hadir** | — | Tanda kehadiran sesi aktif. Cetuskan auto-tolak stok + tetapkan minggu ini sebagai `current_week`. |
| **❌ Tidak Hadir** | — | Rekod absen sesi aktif. **TIDAK** auto-caj. Buka kawalan reschedule + minggu tambahan. |
| **🔔 Ingatkan Pesakit** | — | Muncul bila status = Tidak Hadir. Hantar notifikasi suruh pesakit reschedule sendiri. |
| Tarikh reschedule + **📅 Jadual Semula** | — | Muncul bila Tidak Hadir. Tetapkan tarikh baru → status jadi `booked` + notifikasi pesakit. |
| **➕ Buka Minggu Tambahan** | — | Muncul bila ada sesi Tidak Hadir minggu ini. Buka 1 minggu tambahan **berbayar** (pesakit bayar). |

### Seksyen Nota Coach (kiri)
| Field | Wajib? | Nota |
|-------|--------|------|
| **Tarikh & Masa Sesi** | Disyorkan | `datetime-local`. Auto-simpan + cipta/kemaskini `psy_appointments` + notifikasi pesakit. Status jadi `booked` (kecuali sudah Hadir/Tidak Hadir). |
| Score (0–10) | Pilihan | Skor sesi. Auto-simpan bila tukar. |
| Nota Minggu Ini | Pilihan | Pemerhatian / arahan. Klik **💾 Simpan Nota**. |

### Seksyen Kepatuhan Rawatan (kanan)
Semua **pilihan** — isi yang berkaitan, kemudian klik **🌿 Simpan Kepatuhan**:
🍯 Madu (sudu/hari) · 🌬️ Nafas fitrah (kali/hari) · 🌍 Terapi bumi (min/hari) · 🥥 Air kelapa (kali/mgg) · 💧 Terapi kolon (kali) · ☀️ Berjemur (Ya/Tidak) · 🍽️ Pantang makanan (Ya/Tidak). Disimpan per **sesi** (`session_day`).

### Coaching Minggu Ini (checklist)
| Bahagian | Nota |
|----------|------|
| **Bimbingan / Calling** | Checklist task dari pakej. Tanda bila selesai; kalau belum, isi **alasan**. |
| **Rujukan** (staff sahaja) | Pautan rujukan untuk coach — pesakit tak nampak. |
| **📦 Bekalan** | Checklist bekalan. **Tanda = tolak stok**, buang tanda = kembalikan stok (lihat seksyen 6). |

### Modal lain (pilihan)
- **⚕ Nota Doktor (SOAP)** — Mood sebelum/selepas, S·O·A·P, Tahap Risiko + nota, Homework. Boleh **💾 Simpan Draf** atau **✍️ Sign & Lock** (terkunci selepas ditandatangani).
- **📊 Bacaan Vitals** — BP, nadi, berat, tinggi, suhu, RBS, nota.
- **📎 Dokumen Minggu Ini** — muat naik lampiran (imej / PDF) khusus minggu ini.

---

## 6. Apa jadi lepas Simpan

### Bila tanda **✅ Hadir**
1. `psy_plan_weekly_progress` sesi itu → `status = 'hadir'` (+ `updated_by`, `updated_at`).
2. `psy_treatment_plans.current_week` dikemaskini ke minggu ini.
3. **Auto-tolak stok** ([`shared/inventoryDeduct.js`](../../../shared/inventoryDeduct.js)): bekalan F2F minggu itu (dari `coaching_schedule.supplies`) ditolak dari `psy_inventory_items.qty_in_stock`.
   - **Skip** kalau sesi mode **Online** atau sesi **extension** (minggu tambahan) — tiada bekalan fizikal.
   - Skip item tanpa `item_id`, `qty = 0`, atau `auto_stock = false`.
   - Banner papar bekalan yang ditolak + amaran kalau **stok rendah** (< 5).
   - Dicatat ke audit: `inventory.auto_deducted`.
4. Notifikasi "Kehadiran disahkan ✅" dihantar ke pesakit.
5. Audit log: `plan.week_updated`.

> **Nota stok per item Bekalan:** menanda satu item dalam checklist **Bekalan** juga menolak stok item itu (−1 set); membuang tanda mengembalikannya (+1). Kit prosedur dikembangkan ke item individu.

### Bila tanda **❌ Tidak Hadir**
1. `status = 'cancel'` direkod. **TIADA** auto-caj, **TIADA** auto-buka minggu tambahan.
2. Notifikasi "Sesi ditanda tidak hadir — anda boleh tempah semula" dihantar ke pesakit.
3. Muncul kawalan: **🔔 Ingatkan Pesakit**, **📅 Jadual Semula**, dan **➕ Buka Minggu Tambahan**.

### Peraturan ketidakhadiran (penting — kemaskini 24 Jun 2026)
- Tidak Hadir = **rekod absen + tawar reschedule SAHAJA**.
- Minggu tambahan berbayar dibuka **secara MANUAL** sahaja, melalui butang **➕ Buka Minggu Tambahan** — **tiada auto-caj**. Tekan hanya bila pesakit sah nak sambung rawatan.
- Buka minggu tambahan = cipta 2 sesi baru (`is_extension = true`, `status = 'extension_pending_payment'`) selepas minggu terbesar, pada harga `extension_price_per_week` pakej (default **RM 50**) + notifikasi pesakit bayar. Audit: `plan.extension_created`.
- **Dedup per minggu:** satu minggu hanya boleh ada satu minggu tambahan (`extension_for_week`).
- Kalau coach kemudian betulkan kehadiran (tanda Hadir / Jadual Semula) **sebelum** pesakit bayar, minggu tambahan yang belum dibayar **dibatalkan automatik** (audit: `plan.extension_voided`). Yang sudah dibayar dikekalkan.

(Rujukan penuh: [03-modul.md — Aturan ketidakhadiran](../../sistem/03-modul.md).)

---

## 7. Masalah biasa
| Mesej / gejala | Sebab & penyelesaian |
|----------------|----------------------|
| "Tiada sesi untuk minggu ini" bila tekan Hadir | Belum ada baris sesi. Tetapkan **Tarikh & Masa Sesi** dulu (cipta baris `booked`), kemudian tanda kehadiran. |
| Butang Hadir / Tidak Hadir tak muncul | Minggu itu belum ada sesi (`weekEntry`). Set tarikh sesi dahulu. |
| Stok tak ditolak walaupun tanda Hadir | Sesi mode **Online** / **extension**, atau bekalan tiada `item_id` / `qty = 0` / `auto_stock = off`. Semak timeline pakej di [Tambah Pakej](tambah-pakej.md). |
| "⚠️ Ralat inventori …" | Item bekalan tak wujud dalam inventori atau ralat kemaskini. Semak item di **Inventory**. |
| Butang **Buka Minggu Tambahan** tak muncul | Hanya muncul bila ada sesi **Tidak Hadir** minggu ini & ia bukan minggu extension sendiri. |
| "Tiada sesi tidak hadir untuk minggu ini" bila buka minggu tambahan | Tiada sesi berstatus `cancel`. Tanda Tidak Hadir dulu. |
| "Sila pilih tarikh & masa baru" bila Jadual Semula | Isi medan tarikh reschedule dahulu. |
| "Tiada akaun pesakit untuk dihubungi" | Pesakit belum ada akaun (`user_id`). Notifikasi tak dapat dihantar; gunakan saluran lain. |
| Tarikh sesi rosak / silap | `super_admin` boleh guna **Admin Tools → Reset Tarikh Sesi Minggu Ini** atau **Reset Sesi** di senarai (rows hadir dikekalkan; tarikh dijana semula). |

---

## 8. Rujukan teknikal
- Page senarai: [`roles/staff/plans.html`](../../../roles/staff/plans.html)
- Page editor: [`roles/staff/plan-week.html`](../../../roles/staff/plan-week.html) · `markStatus()`, `openExtensionManually()` / `createExtensionForWeek()`, `coachReschedule()`, `applySupplyStock()`
- Auto-tolak stok: [`shared/inventoryDeduct.js`](../../../shared/inventoryDeduct.js) · `deductSessionSupplies()`
- Jadual: `psy_treatment_plans`, `psy_plan_weekly_progress` (kehadiran + nota + SOAP + extension), `psy_plan_compliance`, `psy_appointments`, `psy_inventory_items`, `psy_procedure_kits` (lihat [02-pangkalan-data.md](../../sistem/02-pangkalan-data.md))
- Modul + peraturan ketidakhadiran: [03-modul.md](../../sistem/03-modul.md)
- Audit actions: `plan.week_updated`, `inventory.auto_deducted`, `plan.extension_created`, `plan.extension_voided`, `plan.reschedule_reminder`
