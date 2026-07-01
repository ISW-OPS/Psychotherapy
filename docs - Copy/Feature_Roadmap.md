# ISW System — Feature Roadmap
> Kemaskini: 30 Jun 2026 · Berdasarkan meeting Izzah 26 Mei 2026

---

## 🎯 PHASE 3 — Skop Rasmi (ditetapkan 30 Jun 2026)
> 10 item disahkan untuk Phase 3. Status: 🆕 baharu · ♻️ naik taraf modul sedia ada · 📋 dari roadmap asal (#).

| # | Feature | Jenis | Keterangan & nota pembinaan |
|---|---|---|---|
| 1 | **Payment gateway** | 📋 #29 | Tukar `processPayment()` dari simulasi → gateway sebenar (Billplz / ToyyibPay). **Blocker:** keputusan Zahin (gateway/kad/SST). Bayaran sekali, bukan recurring. |
| 2 | **OH MY GENE (DNA Flow)** | 📋 #34 | Test → consultation → report email pesakit. Perlu schema baru + langkah workflow + storan laporan DNA. Boleh guna `psy_medical_reports` sebagai asas. |
| 3 | **Continuity Package** | 🆕 | Bila pesakit ada **baki ≤4 minggu** dalam pelan, sistem cadang pakej sambungan. Trigger ikut `current_week` vs `duration_weeks`; papar cadangan di portal pesakit + alert coach. |
| 4 | **Red Emergency Protocol** | 📋 #19 | Butang SOS / alert kecemasan pesakit → notifikasi segera ke coach/doktor + log risiko. Sambung ke `psy_risk_alerts`. |
| 5 | **Reward System** | 📋 #21 | Star/kategori ikut progress + hadiah bila capai sasaran. Perlu schema mata/lencana + peraturan + paparan pesakit. |
| 6 | **Geng ALIVE features** | 📋 #22 | Santapan fitrah, ziarah, family day, graduasi, hi-tea — modul komuniti/acara lanjutan (extend `psy_events`). |
| 7 | **Hakeema 1:1** | 📋 #10 | Jadual 1:1 Hakeema (Minggu 6 & 11, bulanan M1–M3, suku-tahun Q1–Q3) + nota. Perlu schema sesi Hakeema + dashboard ringkasan (#36). |
| 8 | **Referral dalam sistem** | 📋 #11 | Rujuk pesakit ke doktor / Hakeema / coach / manager dalam app + jejak status rujukan. Schema `psy_referrals` (sudah wujud — bina UI + alur). |
| 9 | **Daily Check-in: mood → emosi → saranan tindakan** | ♻️ | Naik taraf `checkin.html`: petakan skor mood → emosi → **saranan tindakan automatik** (cadangan amalan/aktiviti ikut emosi). Logik pemetaan + paparan saranan. |
| 10 | **Reaksi Pemulihan: saranan → tindakan** | ♻️ | Naik taraf modul Reaksi Pemulihan (`psy_reaksi_item`): dari simptom direkod → jana **saranan tindakan** untuk pesakit/coach. |

**Kebergantungan luar (perlu keputusan/akses):** Payment gateway (Zahin) · OH MY GENE (proses & format report) · WhatsApp untuk notifikasi SOS/continuity (jika mahu auto-WA).
**Boleh mula tanpa blocker:** Continuity Package, Reward, Referral, Daily Check-in saranan, Reaksi Pemulihan saranan, Hakeema 1:1, Geng ALIVE, Red Emergency (in-app).

---

## ✅ SELESAI

| Feature | Nota |
|---|---|
| Semua audit bugs HIGH/MEDIUM/LOW | 30+ fixes — commit `b0ce7e3`, `08b00b6` |
| RLS hardening (security) | psy_notifications, psy_kepatuhan_log, psy_vitals |
| Kepatuhan module | Catatan Harian, heatmap, auto scoring A/B/C |
| Medical records upload | X-Ray/MRI/CT → psy_medical_reports |
| Library content module | Staff editor + patient view |
| Bilingual i18n engine | BM⇄EN toggle, shared/i18n.js |
| Absence → extension rule | Butang manual, tiada auto-caj |
| Patient duplicate prevention | IC block + autoLink fix |
| KYC flow | Self-register + staff approve + psy_patients INSERT |
| Auto-mesej framework | psy_auto_messages, staff UI auto-mesej.html |
| Pengumuman / Acara system | Staff buat, patient view |
| Assignment → merged into Pesakit | patients.html tabs |
| Pulangan botol | Patient submit, staff verify |
| Rekod perubatan | Patient upload, staff view |
| **Outcome status** (#9) | OTW / Berhenti / Meninggal — field + filter dalam patients.html |
| **Disclaimer motivasi** (#3) | Muncul dalam kepatuhan.html bila skor < 85% |
| **Welcome video** (#4) | Lokasi & video panduan perjalanan dalam kob.html |
| **Patient input BP / HbA1c** (#16) | patient/vitals.html — input + graf weekly |
| **Contoh jadual harian** (#23) | patient/routine.html — daily_schedule ikut pakej + customize |
| **Coach performance dashboard** (#40) | staff-stats.html — tab Prestasi Staff + Analitik Pesakit |
| **Highlight patient low compliance** (#41) | dashboard.html — card Alert Kepatuhan + intervensi awal |
| **Ruangan kontrak** (#37) | kob-detail.html + kob-agreement.html — upload + sign + PDF |
| **Notes selepas coaching** (#38) | session-notes.html — SOAP notes + risk flag |
| **Filter dashboard coach** (#39) | staff-stats.html — filter period + staff cards |

---

## 🔴 KRITIKAL — Go-Live Blocker

| # | Feature | Keterangan | Blocker |
|---|---|---|---|
| 1 | **GHL integration** | Sync KYC + appointment + phone ke GoHighLevel | Tunggu GHL API credentials dari Closer |
| 2 | **WhatsApp automation** | Catatan harian reminder + birthday + event | Framework ada, catatan_harian/birthday masih draft |
| 5 | **Governance dashboard** | Tambah filter penyakit / umur / lokasi (governance.html ada tapi belum ada filter) | — |

---

## 🟠 CLINICAL WORKFLOW

| # | Feature | Keterangan |
|---|---|---|
| 6 | **Package ID structure formal** | DB schema: tempoh, bekalan, bimbingan, weekly content, WA msg |
| 7 | **Lock butang online minggu ≥3** | Kecuali pakej OBD1/OBDX1/OBDY1/OBP1/OBPX1/OBPY1 |
| 8 | **Auto-shift jadual bila reschedule** | Sesi berikutnya auto-gerak ikut tarikh baru |
| 9 | **Outcome status** | Berhenti / OTW / Meninggal — field + filter dashboard |
| 10 | **Hakeema 1:1 schema** | Minggu 6 & 11, M1-M3 (bulanan), Q1-Q3 (3-bulan-sekali) + nota |
| 11 | **Referral dalam sistem** | Coach refer patient ke Hakeema / doktor |
| 12 | **Closer key-in recommendation** | Walaupun patient belum signup pakej |
| 13 | **Coach-only RLS tighten** | Record pesakit hanya coach berkenaan boleh access |

---

## 🟢 PATIENT EXPERIENCE

| # | Feature | Keterangan |
|---|---|---|
| 14 | **Jadual madu ikut pakej** | 12-minggu: 10x/hari · 3-bulan: 8x/hari · 3-bulan-sekali: 4x/hari |
| 15 | **Reminder harian adjustable** | Madu, yogurt, terapi bumi, jemur pagi, pernafasan fitrah, zikir bersanad |
| 17 | **Notification kehadiran mingguan** | + ruangan tulis sebab tak hadir |
| 18 | **Live Manzil + Google Meet auto-notif** | Rabu/Khamis/Jumaat 8.45–9.15am |
| 19 | **Red emergency protocol** | Butang SOS / alert kecemasan |
| 20 | **Self-help desk** | FAQ, AI chatbot, video pakej OB, DNA kit content, testimoni |
| 21 | **Reward system** | Star kategori ikut progress + hadiah bila capai result |
| 22 | **Geng ALIVE features** | Santapan fitrah, ziarah, family day, graduasi, hi-tea |
| 24 | **KYC popup** | "Patient sebenar atau pewaris?" sebelum daftar |

---

## 🟡 INVENTORY / COMMERCE

| # | Feature | Keterangan | Blocker |
|---|---|---|---|
| 25 | **Auto-generate PO** | Bila stok ≤20%, hantar untuk kelulusan management | — |
| 26 | **Auto-send invoice** | Email + WhatsApp lepas bayar | Tunggu WhatsApp API |
| 27 | **SQL Accounting integration** | Inventory + payment + recurring — elak duplicate key-in | Tunggu SQL API/CSV spec |
| 28 | **Upgrade / downgrade pakej** | Add-on, family/friend cross-sell, festive offer | — |
| 29 | **Payment gateway** | Billplz vs ToyyibPay | Pending bincang Zahin |
| 30 | **Order tracking notif staff** | Blinking alert bila order baru | — |
| 31 | **Format resit/invois final** | Standard format untuk semua pembayaran | — |

---

## 🔵 MEDICAL / CLINICAL DATA

| # | Feature | Keterangan |
|---|---|---|
| 32 | **Scan medical report → auto-extract** | Blood test, hormone — OCR + parse |
| 33 | **Analyse outcome** | "Most successful reducing HbA1c/cholesterol" — aggregate analytics |
| 34 | **OH MY GENE DNA workflow** | Test → consultation → report email patient |
| 35 | **DNA Test Kit content** | Dalam self-help desk |

---

## 🟣 COACH SIDE

| # | Feature | Keterangan |
|---|---|---|
| 36 | **Dashboard summary Hakeema** | Berapa patient perlu 1:1 Hakeema dalam bilik |
| 42 | **Star nama patient** | Ikut kategori progress |

---

## Sprint Plan (Cadangan)

### Sprint 1 — Quick Wins (1 minggu)
- [x] Outcome status: Berhenti / OTW / Meninggal + filter (#9) — patients.html
- [x] Disclaimer motivasi bila adherence rendah (#3) — kepatuhan.html skor < 85%
- [x] Patient input BP/HbA1c + graf (#16) — patient/vitals.html
- [ ] KYC popup "patient atau pewaris?" (#24)
- [ ] Jadual madu ikut pakej (#14)
- [ ] Pengumuman: extend access ke Hakeema + doctor

### Sprint 2 — Workflow Lock (2 minggu)
- [ ] Package ID structure formal DB schema (#6)
- [ ] Auto-shift jadual bila reschedule (#8)
- [ ] Lock butang online minggu ≥3 (#7)
- [ ] Coach-only RLS tighten (#13)
- [ ] Hakeema 1:1 schema (#10)

### Sprint 3 — Integration (3–4 minggu)
- [ ] GHL bridge (#1) — *perlukan GHL credentials*
- [ ] WhatsApp automation (#2) — *perlukan WA API stack*
- [ ] Auto-send invoice email + WA (#26)
- [ ] SQL Accounting (#27) — *perlukan spec*

### Sprint 4+ — Advanced
- [ ] Medical OCR/scan (#32)
- [ ] DNA workflow (#34)
- [ ] AI chatbot (#20)
- [ ] Reward + gamification (#21)
- [ ] Geng ALIVE (#22)

---

## Soalan Tergantung

| Soalan | Kepada |
|---|---|
| GHL API credentials | Closer / Zahin |
| WhatsApp API stack (Business API / Twilio / 3rd party?) | Zahin |
| SQL Accounting API atau CSV export-import? | Zahin |
| Payment gateway: Billplz atau ToyyibPay? | Zahin |
| Timeline go-live? | Izzah |
| Paling urgent untuk demo stakeholder? | Izzah |
