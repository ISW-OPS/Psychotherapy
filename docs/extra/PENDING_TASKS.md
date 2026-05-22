# ISW — Senarai Pending Tasks

Status setakat: 24 Mei 2026

---

## 🔴 Pending — Menunggu Keputusan Domain (Meeting Izzah 26 Mei)

### 1. Risk Alert
- **Status**: Panel "Pesakit Perlu Tindakan Segera" di Dashboard Coach **greyed-out**
- **Issue**: Schema `psy_risk_alerts` wujud tapi **tiada logik INSERT** dari mana-mana tempat. Severity (low/medium/high/critical) tiada makna sebenar.
- **Tunggu**: Definisi "risk" + threshold severity + auto-trigger rules dari Izzah
- **Ref**: [Meeting_Izzah_Soalan_Risk_Kepatuhan.md](Meeting_Izzah_Soalan_Risk_Kepatuhan.md) Bahagian A–F

### 2. Kepatuhan
- **Status**: [kepatuhan.html](../roles/staff/kepatuhan.html) **keseluruhan page greyed-out**. Kad Dashboard Coach tukar dari "Kepatuhan 7 Hari" → "Check-in 7 Hari" (lebih jelas)
- **Issue**: 3 definisi konflik: session-based vs check-in based vs kategori OB (A/B/C)
- **Tunggu**: Pilihan definisi + threshold + siapa assign kategori
- **Ref**: [Meeting_Izzah_Soalan_Risk_Kepatuhan.md](Meeting_Izzah_Soalan_Risk_Kepatuhan.md) Bahagian G

---

## 🟡 Pending — Feature Belum Implement (Tiada Backend)

### 3. Quick Actions Dashboard Coach
- **Greyed-out**: 4 butang (💬 Mesej, 📞 Call, 📋 Checklist, 📁 Rekod)
- **Issue**: Sistem tiada messaging/VOIP. Mesej & Call tak boleh connect ke mana-mana.
- **Cadangan**: Implement WhatsApp link (`https://wa.me/...`) + tel link, atau buang sahaja

### 4. Sesi 1:1 Hakeema
- **Greyed-out**: Panel dalam Dashboard Coach
- **Issue**: Modul Hakeema belum ada langsung (tiada schema, tiada flow)

### 5. Reaksi Pemulihan
- **Greyed-out**: KPI card dalam Dashboard Coach
- **Issue**: Tiada table untuk track recovery reactions

### 6. Auto-Generate Inventory Request (stok ≤ 30%)
- **Schema ready**: `auto_reorder_enabled`, `last_auto_po_at`, `is_auto_generated` columns
- **Belum implement**: Logik auto-create `psy_inventory_request` bila stok rendah
- **Effort**: Sederhana — trigger PG atau cron job

### 7. Email/WhatsApp Notifikasi
- Bila order shipped, payment received, sesi reminder
- Tiada integration ke email service atau WhatsApp API

### 8. Refund Flow UI
- Schema: `psy_payments.status='refunded'` wujud
- UI: Tiada button refund di mana-mana

---

## 🟠 Pending — Schema Ada, UI Belum Lengkap

### 9. Sessions Per Week (Stage 2 & 3)
- **Stage 1 SIAP**: `psy_packages.sessions_per_week` + `session_days_options` ditambah, UI pakej-edit boleh set variants
- **Stage 2 BELUM**: Patient signup flow tarik dari `session_days_options` (sekarang hardcoded fri_sat/sat_sun dalam plan.html)
- **Stage 3 BELUM**: `plan-week.html` tunjuk sub-tabs Sesi 1 / Sesi 2 dengan nota berasingan per sesi
- **Reason tangguh**: Tunggu test pakej OB/NLC/OBG sebenar dengan data baru

### 10. Audit Log
- **Schema + UI siap**: Boleh paparkan dengan resolver UUID → nama
- **Issue**: IP Address column buang dari UI (tak pernah dirakam)
- **Soalan**: Page audit ni penting ke tak? Jawapan user: "kalau tak ada SOP review, buang dari menu tapi keep insert" — belum implement

### 11. Stage 2 Pesakit (Patient Flow)
- ⏭ **Next task** — bina flow lengkap dari signup → KYC → KOB → Pakej → Rawatan

---

## ✅ Recently Fixed (Untuk Reference)

- `created_by_staff` column ditambah ke `psy_patients`
- `full_name`, `phone`, `emergency_contact_email`, `emergency_contact_relationship` ditambah ke `psy_patients`
- `image_url` ditambah ke `psy_products`
- RLS update plan untuk patient (`Patients update own plan setup`)
- Bug 286% check-in Dashboard Coach (filter caseload + cap 7/pesakit + clamp 100%)
- Bug Reschedule KOB tak buka modal (element id salah)
- Bug Lihat butiran tak akses (pageId mismatch)
- 3 jenis Pesakit dalam modal — labels diperbaiki (Baru / Sedang Dalam Rawatan / Pesakit Lama)
- Checkbox column dalam patients table dibuang (dead UI)
- Logic auto-extension bila miss sesi (Pilihan B: 1 minggu tambahan per missed week)
- Backfill 24 sesi kalau setup terganggu separa

---

**File ini akan diupdate setiap kali ada feature ditangguh / disiapkan. Rujuk sebelum tambah scope baru.**
