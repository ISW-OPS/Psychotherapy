# Audit Checklist Syafa — Status Implementasi

Tarikh: 21 Mei 2026

**Legenda:**
- ✅ Done — siap & berfungsi
- 🟡 Partial — sebahagian siap
- 🟠 Schema ready — DB/backend ada, UI belum
- 🔴 Pending — belum mula
- ⛔ Blocked — tunggu external (Izzah/GHL/API)

---

## A. ✅ DONE (19 item)

| Item | Note |
|---|---|
| Track patient signup pakej or not | `active_package_id` + filter Semua Signup |
| KYC popup pewaris vs patient | `submitted_by_proxy` column + tick box |
| Auto-link patient signup → claim staff record | Match by email dalam `_shared.js initPatient()` |
| Digital agreement + signature PDF | `psy_kob_agreements` + pdf-lib |
| Outcome status (OTW/berhenti/meninggal) | `psy_patients.outcome_status` |
| Cuti umum/Hari Raya auto-lock kalendar | `psy_clinic_closures` (recurring + ad-hoc) |
| Coach & patient view Week 1-12 | plan.html + plan-week.html |
| Coach buka SEMUA pesakit | Lock per-coach dah dibuang |
| Kalendar admin & coach lengkap | appointments.html + weekly-plan.html |
| Auto-tambah minggu reschedule + harga | `autoMarkMissedAndExtend()` |
| Template surat KWSP/PERKESO/RELA/dll | `letterTemplates.js` — 7 template ready |
| Patient submit isu rosak dengan gambar | `psy_issues` + upload |
| Patient return botol madu | `psy_bottle_returns` + criteria |
| Patient + coach scan upload medical report | `psy_medical_reports` (X-Ray, MRI, CT, dll) |
| Patient view BP/HbA1c + update sendiri | Baru siap — patient `vitals.html` |
| Inventory listing detailed (madu, Air Afiyah, IV setup) | `psy_inventory_items` + `psy_procedure_kits` |
| Daily checklist + jadual minum madu ikut pakej | `madu_frequency_per_day` + check-in tracking |
| Jadual harian sample setiap pakej (OB schedule) | `daily_schedule` JSONB seeded |
| Dashboard announcement section | `psy_announcements` |

---

## B. 🟡 PARTIAL (7 item)

| Item | Apa siap | Apa perlu |
|---|---|---|
| Lock waktu rawatan admin pilih offer | Slot config + override per-date | UI staff untuk admin lock-pick waktu |
| Format resit/invoice | Generate receipt ada | Standardize format + branding |
| Coach performance dashboard | `staff-stats.html` umum | Coach-specific view (per-coach metrics) |
| Filter dashboard penyakit/umur/gender/negeri | Status, pakej, outcome filter | Filter lanjutan (medical_condition, age, state) |
| Patient BP/HbA1c trend | Tabular view ada | Graph/chart trend |
| Weekly checklist link coach report | Data ada | Integration penuh ke coach summary |
| Reminder hadir mingguan + reason | Hadir/cancel button | Tangkap alasan kalau cancel |

---

## C. 🟠 SCHEMA READY, UI BELUM (6 item)

| Item | Schema ada | Yang belum |
|---|---|---|
| Lock online dari minggu 3 | `online_lock_from_week`, `allow_online_full_duration` | UI check semasa booking |
| Inventory auto-calc ikut pakej aktif (3 OB × 10 madu = 30) | `weekly_supplies` + `inventory_item_id` | Aggregator + display |
| Auto-PO stok ≤30% → finance | `auto_reorder_enabled`, `last_auto_po_at` | Cron job / trigger |
| Alert coach kalau patient tak patuh | `psy_adherence_alerts` | Trigger logic (madu <5/hari, 4-5 hari/mgg) |
| Content auto lock/unlock ikut pakej | `library_items.package_ids` | Enforcement dalam library.html patient |
| Pakej Package ID + bekalan + bimbingan + WhatsApp | `weekly_message`, `weekly_supplies`, `weekly_content` | UI untuk render weekly message |

---

## D. 🔴 PENDING (30+ item)

### Komunikasi & Notifikasi
- Auto-send invoice email + WhatsApp
- Notification reaksi pemulihan
- Calendar reminder hadir rawatan
- Reminder sebelum & semasa rawatan
- Auto WhatsApp reminder (every 5 hours, admin-set time)
- Mesej soal-jawab patient + FAQ + emergency
- Notification daging korban (3 hari sebelum 1 Dzulhijjah)
- Live bacaan Manzil (Rabu/Khamis/Jumaat 8.45am)

### Modul Tambahan (Belum Mula)
- Sesi 1:1 Hakeema (M6, M11, bulanan, Q1-Q3)
- Voice record + transcribe → masuk record + auto WhatsApp
- ChatGPT record coaching → transcribe
- Reaksi pemulihan modul + saranan + call coach
- Daily check-in link emosi + action
- Red emergency protokol dashboard
- Physiotherapist saranan + monitor
- Patient setup appointment doctor untuk medical report
- Kaunselor sistem
- Hakeem sistem
- Kelas NLC attendance + folder
- Pesakit masuk ward → notif management

### Patient Engagement
- Welcome video/lokasi selepas register
- Closer key-in saranan rawatan pre-signup
- Auto reward star + cabutan bertuah
- Referral program + gift voucher
- Geng ALIVE design + features khas
- Disclaimer motivasi kalau tak patuh
- AI chatbot FAQ

### Content Upload (Self-Help)
- Video testimoni LTH + 3 minggu
- Saranan diet umrah/haji
- Madu Ramadhan + diet Raya SOP
- Video OB (10 video CS — berjemur, zikir, terapi bumi, dll)

### Analytics & Comparison
- Analytics berjemur/watermelon/pijak batu panas
- Compare progress fasa 1 (BP, HBA1c)
- Auto-summary check-in (graf/pie chart)

### Clinical Rules
- Buah pinggang/dialisis 500ml notification
- Pakej upgrade/downgrade + add-on + bonus tier

### Integration ke Social
- Feedback Google Review + FB/IG/YT/TikTok comment

---

## E. ⛔ BLOCKED (4 item)

| Item | Tunggu |
|---|---|
| GHL integration (closer, WhatsApp, KYC sync) | API key + access |
| SQL Accounting connect (inventory + payment) | Integration spec |
| Kepatuhan definisi (kategori OB A/B/C) | Meeting Izzah 26 Mei |
| Risk alert kriteria + threshold | Meeting Izzah 26 Mei |

---

## RINGKASAN

| Status | Bilangan |
|---|---|
| ✅ Done | 19 |
| 🟡 Partial | 7 |
| 🟠 Schema ready, UI belum | 6 |
| 🔴 Pending | 30+ |
| ⛔ Blocked (external) | 4 |

---

## PRIORITI GO-LIVE (per Syafa)

| Priority | Item | Status |
|---|---|---|
| 1 | KYC | ✅ Done |
| 2 | GHL integration | ⛔ Blocked |
| 3 | Product description | 🟡 Partial |
| 4 | Notification system | 🟡 In-app done, external pending |
| 5 | Adherence checklist | ⛔ Tunggu Izzah |
| 6 | Schedule locking | ✅ Done |
| 7 | Governance dashboard | 🟡 Partial |

**Boleh proceed sekarang tanpa blockers:**
- Self-help content upload (video, FAQ, SOP)
- Daily check-in extension (emosi, reaksi pemulihan)
- Counsellor/Physiotherapist module foundation
- Reward/star system
- Module Hakeema basic (booking + notes, voice/AI later)
- Disclaimer motivasi
- Welcome video/lokasi page

**Boleh start kalau ada AI/integration partner:**
- WhatsApp Business API (auto reminder, invoice, mesej)
- ChatGPT/Whisper API (voice transcribe coaching/Hakeema)
- GHL webhook (closer flow + KYC sync)
- SQL Accounting integration

---

**Cara guna untuk Word:**
Open file ini, select all → copy → paste ke Word document. Markdown akan auto-convert ke heading + bullet + table.
