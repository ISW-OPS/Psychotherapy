# 📋 Checklist Flowchart Sistem ISW

Senarai semua flow `.drawio` dalam `docs/`. Semua tergabung dalam **[Flow_SEMUA_Pages.drawio](Flow_SEMUA_Pages.drawio)** (47 halaman, tab di bawah).

> **Petunjuk status:**
> - `[x]` = fail `.drawio` siap dijana
> - **Semak** = tanda bila anda dah buka & sahkan layout OK
> - Tag: 🟡 SIMULASI / PENDING = ada bahagian belum live dalam sistem sebenar

---

## 🆕 18 Flow Baru

### Onboarding & Akaun
- [x] Pesakit Daftar Akaun (Sign-up) — `Flow_Pesakit_Signup.drawio` — Semak: [ ]
- [x] Admin Cipta Staff — `Flow_Cipta_Staff.drawio` — Semak: [ ]
- [x] Tambah Pesakit (Staff) — `Flow_Tambah_Pesakit.drawio` — Semak: [ ]

### Rawatan & Sesi
- [x] Pakej Rawatan — `Flow_Pakej.drawio` — Semak: [ ]
- [x] Temu Janji — `Flow_Temu_Janji.drawio` — Semak: [ ]
- [x] Kehadiran — `Flow_Kehadiran.drawio` — Semak: [ ]

### Transaksi & Sokongan
- [x] Bayaran 🟡 SIMULASI — `Flow_Bayaran.drawio` — Semak: [ ]
- [x] Acara / Event — `Flow_Acara.drawio` — Semak: [ ]
- [x] Pengumuman — `Flow_Pengumuman.drawio` — Semak: [ ]
- [x] Library & FAQ — `Flow_Library_FAQ.drawio` — Semak: [ ]
- [x] Aduan / Issue — `Flow_Aduan.drawio` — Semak: [ ]
- [x] Maklum Balas — `Flow_Maklum_Balas.drawio` — Semak: [ ]

### Pemantauan & Pentadbiran
- [x] Amaran Risiko 🟡 PENDING — `Flow_Risiko.drawio` — Semak: [ ]
- [x] Mesej Automatik (WhatsApp) — `Flow_Mesej_Automatik.drawio` — Semak: [ ]
- [x] Dashboard — `Flow_Dashboard.drawio` — Semak: [ ]
- [x] Profil — `Flow_Profil.drawio` — Semak: [ ]
- [x] Peranan / RBAC — `Flow_Peranan_RBAC.drawio` — Semak: [ ]
- [x] Audit Log — `Flow_Audit_Log.drawio` — Semak: [ ]

---

## 📁 20 Flow Sedia Ada

- [x] KYC — `Flow_KYC.drawio` — Semak: [ ]
- [x] KOB 6-Stage — `Flow_KOB_6Stage.drawio` — Semak: [ ]
- [x] KOB Stages Detail — `Flow_KOB_Stages_Detail.drawio` — Semak: [ ]
- [x] Rawatan — `Flow_Rawatan.drawio` — Semak: [ ]
- [x] Hari Rawatan — `Flow_Hari_Rawatan.drawio` — Semak: [ ]
- [x] Kepatuhan Rawatan — `Flow_Kepatuhan_Rawatan.drawio` — Semak: [ ]
- [x] Catatan Harian — `Flow_Catatan_Harian.drawio` — Semak: [ ]
- [x] Vitals — `Flow_Vitals.drawio` — Semak: [ ]
- [x] Upload Dokumen — `Flow_Upload_Dokumen.drawio` — Semak: [ ]
- [x] Surat — `Flow_Surat.drawio` — Semak: [ ]
- [x] Surat Detail — `Flow_Surat_Detail.drawio` — Semak: [ ]
- [x] Inventori — `Flow_Inventori.drawio` — Semak: [ ]
- [x] Pulangan Botol — `Flow_Pulangan_Botol.drawio` — Semak: [ ]
- [x] Shop Order — `Flow_Shop_Order.drawio` — Semak: [ ]
- [x] Coach — `Flow_Coach.drawio` — Semak: [ ]
- [x] Staff Portal — `Flow_Staff_Portal.drawio` — Semak: [ ]
- [x] Staff Detail — `Flow_Staff_Detail.drawio` — Semak: [ ]
- [x] Pemantauan & Tindakan — `Flow_Pemantauan_Tindakan.drawio` — Semak: [ ]
- [x] Mega All Roles — `Flow_Mega_All_Roles.drawio` — Semak: [ ]
- [x] Full System Flowchart — `Flow_Full_System_Flowchart.drawio` — Semak: [ ]

---

## 📦 Fail Gabungan
- [x] **Flow_SEMUA_Pages.drawio** — gabungan semua 47 halaman (untuk eksport PDF satu buku)

---

## 📝 Nota
- **Bayaran** masih SIMULASI — `processPayment()` belum sambung gateway sebenar (Billplz/ToyyibPay pending).
- **Amaran Risiko** — UI siap, auto-trigger masih `is_active=false` (tunggu Izzah).
- **Mesej Automatik** — Event Reminder LIVE (testing); Catatan Harian / Birthday / Manzil masih DRAFT; deploy prod pending.
- Fail gabungan adalah **salinan** — jika edit flow individu, jana semula gabungan tu.

_Jumlah: 38 flow individu • 47 halaman • semua dalam BM._
