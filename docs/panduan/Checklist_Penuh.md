# Checklist Status Sistem ISW Psikoterapi — A-Z (Penuh)

**Tarikh kemaskini:** 22 Mei 2026
**Sistem:** Ibnu Sina Wellness Psychotherapy
**Versi:** v5.0 — pure checklist format + item tambahan yang belum dimasukkan dalam audit asal

---

## Legend Status

- ✅ **Done** — Siap & live
- 🟡 **Partial** — Sebahagian siap, sebahagian tertunggak
- 🟠 **Schema Ready** — Database siap, UI/logic belum
- 🔴 **Pending** — Belum dimulakan
- ⛔ **Blocked** — Tertangguh tunggu external
- 🆕 **NEW** — Item tambahan yang tiada dalam audit asal Syafa

---

## Modul 0 — Platform Foundation (Auth, Navbar, Dashboard)

| Status | Item | Note |
|:------:|------|------|
| ✅ | Login (Supabase Auth) | `auth/login.html` + `auth/auth.js` |
| ✅ | Reset password (e-mel pautan) | `auth/reset.html` |
| ✅ | Set password baharu (selepas reset/invite) | `auth/set-password.html` |
| ✅ | Auth Guard ikut peranan | `shared/authGuard.js` |
| ✅ | Navbar dinamik patient vs staf | `shared/navbar.js` |
| ✅ | Logout & clear sesi | `shared/logout.js` |
| ✅ | Theme switcher | `shared/theme.js` |
| ✅ | Dashboard pesakit | `roles/patient/dashboard.html` |
| ✅ | Dashboard staf | `roles/staff/dashboard.html` |
| ✅ | Landing pendaratan awam | `index.html`, `landing-preview.html` |
| 🟡 | Mobile responsive | Sebahagian halaman; belum audit penuh |
| 🔴 | 2FA / OTP login | Belum siap |
| 🆕 🔴 | Session timeout auto-logout | Belum siap |
| 🆕 🔴 | Session aktif berganda (multi-device control) | Belum siap |
| 🆕 🔴 | Social login (Google/Facebook) | Belum siap |
| 🆕 🔴 | Privacy policy & Terms of Service page | Belum siap |
| 🆕 🔴 | Cookie consent banner | Belum siap |
| 🆕 🔴 | PWA support (install as app) | Belum siap |
| 🆕 🔴 | Offline mode (cache critical pages) | Belum siap |
| 🆕 🔴 | Multi-bahasa UI (BM/English toggle) | Belum siap |
| 🆕 🔴 | Notification preferences per user | Belum siap |

---

## Modul 1 — Pengambilan Lead & Onboarding Pesakit

| Status | Item | Note |
|:------:|------|------|
| ✅ | Track patient signup pakej | `active_package_id` + filter Semua Signup |
| ✅ | KYC popup pewaris vs patient | `submitted_by_proxy` (`step29_kyc_proxy.sql`) |
| ✅ | Auto-link patient signup → claim staff record | Match by email `_shared.js initPatient()` |
| ✅ | KYC review queue admin | `kyc-list.html`, `kyc-review.html` |
| ✅ | Medan KYC tambahan | `step15_kyc_extra_fields.sql` |
| ✅ | Sync KYC → patients | `step19_kyc_patients_sync.sql` |
| ✅ | Track staf yang cipta pesakit | `step_patients_created_by_staff.sql` |
| 🔴 | Closer key-in saranan rawatan pre-signup | Belum siap |
| ⛔ | GHL integration (closer flow, WhatsApp, KYC sync) | Tunggu API key |
| 🆕 🔴 | Upload selfie + IC photo dalam KYC | Belum siap |
| 🆕 🔴 | Verifikasi pewaris (proof of relationship) | Belum siap |
| 🆕 🔴 | Lead nurturing/funnel tracking | Belum siap |
| 🆕 🔴 | Welcome email automatic selepas KYC lulus | Belum siap |

---

## Modul 2 — KOB (Konsultasi Online Bermula)

| Status | Item | Note |
|:------:|------|------|
| ✅ | Soalselidik KOB | `kob.html` + `step37_kob_questionnaire.sql` |
| ✅ | Saranan pakej auto | `step38_kob_package_recommendation.sql` |
| ✅ | Slot KOB | `kob-slots.html` + `step36_kob_slots.sql` |
| ✅ | Skip bayaran KOB (kempen) | `step35_kob_skip_payment.sql` |
| ✅ | Laporan DNA (Did-Not-Attend) | `step23_dna_reports.sql` |
| ✅ | Status `unregistered` | `step21_unregistered_status.sql` |
| ✅ | Storage bucket KOB & rujukan | `step42`, `step43` |
| ✅ | KOB list & detail (staff) | `kob-list.html`, `kob-detail.html` |
| 🆕 🔴 | Rakaman sesi KOB (video/audio) | Belum siap |
| 🆕 🔴 | Reschedule slot KOB oleh pesakit | Belum siap |
| 🆕 🔴 | KOB report PDF auto-jana selepas sesi | Belum siap |
| 🆕 🔴 | Multiple KOB sessions (follow-up) per pesakit | Belum siap |

---

## Modul 3 — Persetujuan Digital (KOB Agreement)

| Status | Item | Note |
|:------:|------|------|
| ✅ | Digital agreement + signature PDF | `psy_kob_agreements` + pdf-lib |
| ✅ | Klausa persetujuan | `step41`, `seed_default_agreement_clauses.sql` |
| ✅ | Storage PDF agreement | `step40_agreement_storage.sql` |
| ✅ | 12 template PDF agreement per pakej | Folder `Agreement/` |
| ✅ | Klausa default loader | `shared/defaultAgreement.js` |
| 🆕 🔴 | Email PDF agreement automatik selepas tandatangan | Belum siap |
| 🆕 🔴 | Pesakit muat turun semula agreement bila-bila | Belum siap |
| 🆕 🔴 | Re-sign agreement (renewal selepas extend) | Belum siap |
| 🆕 🔴 | Version history agreement | Belum siap |
| 🆕 🔴 | Audit trail siapa edit klausa | Belum siap (separa via M22) |

---

## Modul 4 — Setup Pakej & Pelan Rawatan 12 Minggu

| Status | Item | Note |
|:------:|------|------|
| ✅ | Coach & patient view Week 1–12 | `plan.html`, `plan-week.html` |
| ✅ | Pakej + template + kategori | `step5`, `step50_package_categories.sql` |
| ✅ | Sambungan pakej (extend minggu) | `step32`, `step_package_extension_price.sql` |
| ✅ | Bilangan sesi seminggu per pakej | `step_sessions_per_week.sql` |
| ✅ | Setup jadual pelan + RLS | `step_plan_schedule_setup.sql`, `step_patient_plan_setup_rls.sql` |
| ✅ | Edit konfigurasi pakej | `pakej-edit.html` |
| ✅ | Pakej browse & detail (patient + staff) | `pakej.html`, `pakej-detail.html` |
| 🟠 | Pakej Package ID + bekalan + bimbingan + WhatsApp | Schema ada; UI render belum |
| 🟠 | Lock online dari minggu 3 | Schema ada; UI check belum |
| 🔴 | Pakej upgrade / downgrade + add-on + bonus tier | Belum siap |
| 🆕 🔴 | Pakej comparison (banding 2-3 pakej side-by-side) | Belum siap |
| 🆕 🔴 | Pricing tier (early bird, returning customer) | Belum siap |
| 🆕 🔴 | Refund policy paparan jelas | Belum siap |
| 🆕 🔴 | Pakej preview untuk prospek (tanpa login) | Belum siap |

---

## Modul 5 — Penjadualan & Temujanji

| Status | Item | Note |
|:------:|------|------|
| ✅ | Kalendar admin & coach lengkap | `appointments.html` + `weekly-plan.html` |
| ✅ | Cuti umum / Hari Raya auto-lock kalendar | `step28_clinic_closures.sql` |
| ✅ | Penutupan klinik admin | `closures.html` |
| ✅ | Sistem slot baharu (overhaul) | `step47_slot_overhaul.sql` |
| ✅ | Auto-tambah minggu reschedule + harga | `autoMarkMissedAndExtend()` |
| ✅ | Auto-jana pautan Google Meet | `step26`, `step_package_meet_link.sql` |
| ✅ | Sesi hari pelan | `step_plan_session_day.sql` |
| 🟡 | Lock waktu rawatan, admin pilih offer | UI staff utk lock-pick belum |
| 🟡 | Reminder hadir mingguan + reason tak hadir | Tangkap alasan belum |
| 🔴 | Calendar reminder hadir rawatan (push) | Belum siap |
| 🔴 | Reminder sebelum & semasa rawatan | Belum siap |
| 🔴 | Auto WhatsApp reminder (every 5h, admin-set time) | Belum siap |
| 🆕 🔴 | Coach calendar availability (set jam kerja) | Belum siap |
| 🆕 🔴 | Pesakit pilih coach pilihan | Belum siap |
| 🆕 🔴 | Buffer time antara temujanji | Belum siap |
| 🆕 🔴 | Bilik/resource booking (jika fizikal) | Belum siap |
| 🆕 🔴 | Eksport iCal/Google Calendar ke pesakit | Belum siap |
| 🆕 🔴 | Walk-in appointment (tanpa booking) | Belum siap |
| 🆕 🔴 | Group session booking | Belum siap |
| 🆕 🔴 | Multi-location (cawangan) support | Belum siap |

---

## Modul 6 — Check-in Harian & Kepatuhan

| Status | Item | Note |
|:------:|------|------|
| ✅ | Daily checklist + jadual minum madu ikut pakej | `madu_frequency_per_day` |
| ✅ | Tracking ambilan madu | `step33_madu_tracking.sql` |
| ✅ | Jadual `psy_patient_checkins` | `step7_checkins.sql` |
| ✅ | Log selesai aktiviti harian | `step46_daily_completions.sql` |
| ✅ | Pengiraan skor kepatuhan | `shared/adherence.js` |
| 🟠 | Alert coach kalau patient tak patuh | Trigger logic belum |
| 🔴 | Daily check-in link emosi + action | Belum siap |
| 🔴 | Red emergency protokol dashboard | Belum siap |
| 🔴 | Reaksi pemulihan modul + saranan + call coach | Belum siap |
| ⛔ | Kepatuhan definisi (OB A/B/C) | Tunggu Meeting Izzah 26 Mei |
| 🆕 🔴 | Voice check-in (rakam audio harian) | Belum siap |
| 🆕 🔴 | Photo check-in (gambar botol madu) | Belum siap |
| 🆕 🔴 | Streak tracking + gamification | Belum siap |
| 🆕 🔴 | Opsyen skip hujung minggu | Belum siap |

---

## Modul 7 — Rutin Harian (Daily Routine)

| Status | Item | Note |
|:------:|------|------|
| ✅ | Jadual harian sample setiap pakej (OB schedule) | `step44`, `step45` |
| ✅ | Routine page patient | `routine.html` |
| ✅ | Log selesai aktiviti rutin | `step46_daily_completions.sql` |
| 🔴 | Analitik berjemur / watermelon / pijak batu panas | Belum siap |
| 🆕 🔴 | Custom routine per pesakit (override default) | Belum siap |
| 🆕 🔴 | Push notification reminder rutin | Belum siap |
| 🆕 🔴 | Routine completion badge | Belum siap |

---

## Modul 8 — Vital Sign & Rekod Perubatan

| Status | Item | Note |
|:------:|------|------|
| ✅ | Patient view BP / HbA1c + update sendiri | `vitals.html` (`step31_patient_self_vitals.sql`) |
| ✅ | Patient + coach scan upload medical report | `psy_medical_reports` (X-Ray, MRI, CT, dll) |
| ✅ | Vital pautan ke minggu | `step_vitals_link_to_week.sql` |
| ✅ | Staff vital view | `roles/staff/vitals.html` |
| 🟡 | Patient BP / HbA1c trend | Tabular view ada; graf trend belum |
| 🔴 | Patient setup appointment doctor untuk medical report | Belum siap |
| 🔴 | Buah pinggang / dialisis 500ml notification | Belum siap |
| 🔴 | Compare progress fasa 1 (BP, HbA1c) | Belum siap |
| 🆕 🔴 | Integrasi BP monitor Bluetooth | Belum siap |
| 🆕 🔴 | Glukometer integration | Belum siap |
| 🆕 🔴 | Body weight tracking | Belum siap |
| 🆕 🔴 | Waist measurement / BMI tracking | Belum siap |
| 🆕 🔴 | Upload keputusan lab (blood test) | Belum siap |

---

## Modul 9 — Inventori, Bekalan & Pulangan Botol

| Status | Item | Note |
|:------:|------|------|
| ✅ | Inventory listing detailed | `psy_inventory_items` + `psy_procedure_kits` |
| ✅ | Asas inventori | `step17`, `step25`, `step27` |
| ✅ | Jenis penggunaan inventori | `step_inventory_consumption_type.sql` |
| ✅ | Maklumat pembekal | `step_inventory_supplier_info.sql` |
| ✅ | Kit prosedur (IV setup dll) | `step_procedure_kits`, `kit-prosedur.html`, `kit-edit.html` |
| ✅ | Pautan produk ↔ inventori | `step_product_inventory_link.sql` |
| ✅ | Tolak stok automatik | `shared/inventoryDeduct.js` |
| ✅ | Patient return botol madu | `psy_bottle_returns` (`step_bottle_returns.sql`) |
| ✅ | Patient submit isu rosak dengan gambar | `psy_issues` + upload |
| ✅ | Staff inventory & detail | `inventory.html`, `inventory-detail.html` |
| 🟠 | Inventory auto-calc ikut pakej aktif | Aggregator belum |
| 🟠 | Auto-PO stok ≤ 30% → finance | Cron belum |
| ⛔ | SQL Accounting connect | Tunggu integration spec |
| 🆕 🔴 | Stock take / audit count berkala | Belum siap |
| 🆕 🔴 | Expiry date tracking | Belum siap |
| 🆕 🔴 | Lot/batch tracking | Belum siap |
| 🆕 🔴 | Multi-warehouse / lokasi stok | Belum siap |
| 🆕 🔴 | Transfer stok antara lokasi | Belum siap |
| 🆕 🔴 | Writeoff stok rosak | Belum siap |
| 🆕 🔴 | PR (Purchase Requisition) approval flow | Belum siap |
| 🆕 🔴 | Receiving stock against PO | Belum siap |
| 🆕 🔴 | Barcode/QR code labelling | Belum siap |

---

## Modul 10 — Coaching, Konsultasi & Sesi Pakar

| Status | Item | Note |
|:------:|------|------|
| ✅ | Coach buka SEMUA pesakit | Lock per-coach dibuang |
| ✅ | Penugasan coach ↔ pesakit | `step13`, `fix_coach_assignment.sql` |
| ✅ | Jenis sesi | `step22_session_type.sql` |
| ✅ | Nota sesi coaching | `step24_session_notes.sql` |
| ✅ | Sesi konsultasi luar program | `consultation.html` |
| ✅ | Halaman coaching | `coaching.html` |
| ✅ | Peranan Doktor | `step14_doctor_role.sql` |
| ✅ | Cleanup nombor sesi lama | `step_cleanup_session_no.sql` |
| 🟡 | Coach performance dashboard | Per-coach metrics belum |
| 🟡 | Weekly checklist link coach report | Integrasi penuh belum |
| 🔴 | Sesi 1:1 Hakeema (M6, M11, bulanan, Q1–Q3) | Belum siap |
| 🔴 | Hakeem sistem | Belum siap |
| 🔴 | Kaunselor sistem | Belum siap |
| 🔴 | Physiotherapist saranan + monitor | Belum siap |
| 🔴 | Voice record + transcribe → masuk record + auto WhatsApp | Belum siap |
| 🔴 | ChatGPT record coaching → transcribe | Belum siap |
| 🔴 | Pesakit masuk ward → notif management | Belum siap |
| 🆕 🔴 | Coach handover (bila coach berhenti) | Belum siap |
| 🆕 🔴 | Pesakit minta tukar coach | Belum siap |
| 🆕 🔴 | Group coaching session | Belum siap |
| 🆕 🔴 | Coach availability calendar (set jam kerja) | Belum siap |
| 🆕 🔴 | Coach leave/cuti management | Belum siap |

---

## Modul 11 — Katalog Bimbingan

| Status | Item | Note |
|:------:|------|------|
| ✅ | Katalog bimbingan | `step_coaching_catalog.sql`, `seed_coaching_catalog_bimbingan.sql` |
| ✅ | UI katalog | `coaching-catalog.html` |
| 🆕 🔴 | Promotional pricing per bimbingan | Belum siap |
| 🆕 🔴 | Soft-delete item katalog | Belum siap |

---

## Modul 12 — Tugasan Pesakit (Assignments)

| Status | Item | Note |
|:------:|------|------|
| ✅ | Cipta & senarai tugasan | `assignments.html` |
| ✅ | Semak submission | `assignment-review.html` |
| 🔴 | Reminder lewat hantar | Belum siap |
| 🔴 | Auto-bintang ganjaran selepas tugasan lulus | Belum siap |
| 🆕 🔴 | Quiz/MCQ type tugasan | Belum siap |
| 🆕 🔴 | Template tugasan library (re-use) | Belum siap |
| 🆕 🔴 | Bulk assign tugasan ke beberapa pesakit | Belum siap |

---

## Modul 13 — Perpustakaan Kandungan & Pendidikan

| Status | Item | Note |
|:------:|------|------|
| ✅ | Asas perpustakaan | `step8_library.sql`, `step12_library_media.sql` |
| ✅ | Filter ikut pakej | `step49_library_package_filter.sql` |
| ✅ | Library browse patient & staff | `library.html`, `library-detail.html`, `library-edit.html` |
| 🟠 | Content auto lock / unlock ikut pakej | Enforcement belum |
| 🔴 | Video testimoni LTH + 3 minggu | Content upload belum |
| 🔴 | Saranan diet umrah / haji | Content upload belum |
| 🔴 | Madu Ramadhan + diet Raya SOP | Content upload belum |
| 🔴 | Video OB (10 video CS — berjemur, zikir, terapi bumi, dll) | Content upload belum |
| 🔴 | Welcome video / lokasi selepas register | Belum siap |
| 🔴 | AI chatbot FAQ | Belum siap |
| 🆕 🔴 | Search dalam library | Belum siap |
| 🆕 🔴 | Bookmark/favorite kandungan | Belum siap |
| 🆕 🔴 | Tracking completion (siapa dah tonton) | Belum siap |
| 🆕 🔴 | Quiz kefahaman selepas video | Belum siap |
| 🆕 🔴 | Multi-language content | Belum siap |
| 🆕 🔴 | Transkrip video (sari kata BM) | Belum siap |

---

## Modul 14 — Komunikasi & Notifikasi

| Status | Item | Note |
|:------:|------|------|
| ✅ | In-app announcement section | `psy_announcements` |
| 🔴 | Auto-send invoice email + WhatsApp | Belum siap |
| 🔴 | Notification reaksi pemulihan | Belum siap |
| 🔴 | Mesej soal-jawab patient + FAQ + emergency | Belum siap |
| 🔴 | Notification daging korban | Belum siap |
| 🔴 | Live bacaan Manzil | Belum siap |
| ⛔ | WhatsApp Business API | Tunggu integrasi |
| 🆕 🔴 | Direct chat pesakit ↔ coach | Belum siap |
| 🆕 🔴 | Internal chat staff ↔ staff | Belum siap |
| 🆕 🔴 | Group chat (per pakej / per kohort) | Belum siap |
| 🆕 🔴 | Read receipts | Belum siap |
| 🆕 🔴 | Quiet/silent hours (jangan ganggu) | Belum siap |
| 🆕 🔴 | Inbox notifikasi in-app | Belum siap |
| 🆕 🔴 | Push notifikasi (browser/PWA) | Belum siap |

---

## Modul 15 — Pengurusan Surat & Isu Produk

| Status | Item | Note |
|:------:|------|------|
| ✅ | Template surat KWSP / PERKESO / RELA / dll (7 template) | `letterTemplates.js` |
| ✅ | Asas surat | `step_letter_base`, `step_letter_simple` |
| ✅ | Medan auto-isi surat | `step_letter_auto_fields.sql` |
| ✅ | Fail PDF surat | `step_letter_files.sql` |
| ✅ | Override template surat | `step_letter_template_overrides.sql` |
| ✅ | Patient submit isu | `psy_issues` + upload gambar |
| ✅ | Patient & staff issue UI | `issue.html`, `issue-thread.html`, `issue-detail.html` |
| ✅ | Akses read isu patient | `fix_issue_patient_read.sql` |
| ✅ | Surat tindakan isu | `surat-issue.html` |
| ✅ | Surat patient + staff | `surat.html`, `surat-edit.html` |
| ✅ | Template RELA fizikal | `surat/Surat permohonan RELA.docx/pdf` |
| 🔴 | Kelas NLC attendance + folder | Belum siap |
| 🆕 🔴 | Bulk surat generation (banyak pesakit sekali) | Belum siap |
| 🆕 🔴 | Surat approval workflow (Admin → Pengurusan) | Belum siap |
| 🆕 🔴 | Tracking surat (sent/received/printed) | Belum siap |
| 🆕 🔴 | Admin cipta template surat custom | Belum siap |
| 🆕 🔴 | Isu kategorisasi (rosak/lewat/salah/dll) | Belum siap |
| 🆕 🔴 | SLA tracking untuk isu pesakit | Belum siap |

---

## Modul 16 — Kewangan, Bil & Pembayaran

| Status | Item | Note |
|:------:|------|------|
| ✅ | Asas payments | `step6_payments.sql` |
| ✅ | Payment patient page | `payment.html` |
| ✅ | Payment admin | `payment-admin.html` |
| 🟡 | Format resit / invoice | Standardize format + branding belum |
| 🔴 | Auto-send invoice email + WhatsApp | Belum siap |
| ⛔ | Recurring payment & SQL Accounting sync | Tunggu integration spec |
| 🆕 🔴 | Pelbagai kaedah bayar (FPX, kad, e-wallet, transfer bank) | Belum siap |
| 🆕 🔴 | Installment plan (ansuran) | Belum siap |
| 🆕 🔴 | Kod diskaun / voucher | Belum siap |
| 🆕 🔴 | Pengiraan cukai (SST) | Belum siap |
| 🆕 🔴 | Proses bayaran balik (refund flow) | Belum siap |
| 🆕 🔴 | Dashboard tunggakan pesakit | Belum siap |
| 🆕 🔴 | Skim nombor invois (sequence) | Belum siap |
| 🆕 🔴 | Laporan kewangan (P&L, cashflow) | Belum siap |
| 🆕 🔴 | Eksport CSV/Excel invois & bayaran | Belum siap |

---

## Modul 17 — Kedai & E-Dagang

| Status | Item | Note |
|:------:|------|------|
| ✅ | Asas produk | `step9_products.sql`, `step_products_enhanced.sql` |
| ✅ | URL gambar produk | `step_products_image_url.sql` |
| ✅ | Pautan produk ↔ inventori | `step_product_inventory_link.sql` |
| ✅ | Shop, orders patient | `shop.html`, `orders.html` |
| ✅ | Products, services staff | `products.html`, `product-edit.html`, `services.html` |
| ✅ | Staff orders | `roles/staff/orders.html` |
| ✅ | Auto-tolak inventori | `shared/inventoryDeduct.js` |
| 🟡 | Product description | Perlu diperkaya |
| 🆕 🔴 | Cart save for later | Belum siap |
| 🆕 🔴 | Wishlist pesakit | Belum siap |
| 🆕 🔴 | Product reviews & rating | Belum siap |
| 🆕 🔴 | Product variants (saiz, jenis) | Belum siap |
| 🆕 🔴 | Promotion / diskaun produk | Belum siap |
| 🆕 🔴 | Bundle produk (combo) | Belum siap |
| 🆕 🔴 | Notify-when-available (stok habis) | Belum siap |
| 🆕 🔴 | Tracking penghantaran order | Belum siap |
| 🆕 🔴 | Integrasi kurier (poslaju, j&t, dll) | Belum siap |

---

## Modul 18 — Pengumuman (Announcements)

| Status | Item | Note |
|:------:|------|------|
| ✅ | Asas pengumuman | `step10_announcements.sql` |
| ✅ | Senarai & detail | `announcements.html`, `announcement-detail.html` |
| 🔴 | Push pengumuman urgent ke WhatsApp | Belum siap |
| 🆕 🔴 | Schedule pengumuman (terbit kemudian) | Belum siap |
| 🆕 🔴 | Pin pengumuman (sentiasa di atas) | Belum siap |
| 🆕 🔴 | Tracking siapa dah baca | Belum siap |
| 🆕 🔴 | Arkib pengumuman lama | Belum siap |
| 🆕 🔴 | Lampiran (gambar/PDF) dalam pengumuman | Belum siap |

---

## Modul 19 — Penglibatan & Pengekalan Pesakit

| Status | Item | Note |
|:------:|------|------|
| ✅ | Status tamat rawatan (graduate) | `step51_treatment_completion.sql` |
| ✅ | Feedback mingguan | `step48_feedback_weekly.sql`, `feedback.html` |
| 🔴 | Auto reward star + cabutan bertuah | Belum siap |
| 🔴 | Referral program + gift voucher | Belum siap |
| 🔴 | Geng ALIVE design + features khas | Belum siap |
| 🔴 | Disclaimer motivasi kalau tak patuh | Belum siap |
| 🔴 | Feedback Google Review + FB / IG / YT / TikTok comment | Belum siap |
| 🆕 🔴 | Leaderboard kepatuhan | Belum siap |
| 🆕 🔴 | Badges/pencapaian (milestone achievement) | Belum siap |
| 🆕 🔴 | Pengiktirafan hari jadi / ulang tahun rawatan | Belum siap |
| 🆕 🔴 | Forum komuniti pesakit | Belum siap |
| 🆕 🔴 | Galeri kisah kejayaan pesakit | Belum siap |

---

## Modul 20 — Pengurusan Profil

| Status | Item | Note |
|:------:|------|------|
| ✅ | Asas patient | `step2_patients.sql` |
| ✅ | Medan KYC tambahan | `step15_kyc_extra_fields.sql` |
| ✅ | KYC proxy (pewaris) | `step29_kyc_proxy.sql` |
| ✅ | Alamat menetap | `step_patient_address_residence.sql` |
| ✅ | Medan profil peribadi | `step_profile_personal_fields.sql` |
| ✅ | Lajur hilang ditambah | `step_patients_missing_columns.sql` |
| ✅ | Sync KYC → patients | `step19_kyc_patients_sync.sql` |
| ✅ | Patient & staff profile page | `roles/patient/profile.html`, `roles/staff/profile.html` |
| ✅ | Patients list & search | `patients.html`, `patient-hub.html` (`step_patient_hub_v2.sql`) |
| 🆕 🔴 | Upload gambar profil | Belum siap |
| 🆕 🔴 | Privacy settings (visibility kawalan) | Belum siap |
| 🆕 🔴 | Eksport data peribadi (PDPA compliance) | Belum siap |
| 🆕 🔴 | Permintaan hapus akaun (right to erasure) | Belum siap |

---

## Modul 21 — Pengurusan Staf & Peranan

| Status | Item | Note |
|:------:|------|------|
| ✅ | Profiles (asas peranan) | `step1_profiles.sql` |
| ✅ | Peranan staf | `step11_staff_roles.sql` |
| ✅ | Peranan Doktor | `step14_doctor_role.sql` |
| ✅ | Soft-delete | `step20_soft_delete.sql` |
| ✅ | RLS staf | `fix_staff_rls.sql`, `fix_staff_delete_fk.sql` |
| ✅ | Assign peranan (24 Mei 2026) | `assign_staff_roles_240526.sql` |
| ✅ | Staff management UI | `staff_management.html`, `staff-detail.html`, `staff-stats.html` |
| 🆕 🔴 | Senarai semak onboarding staf baru | Belum siap |
| 🆕 🔴 | Rekod latihan staf | Belum siap |
| 🆕 🔴 | Pengurusan cuti staf | Belum siap |
| 🆕 🔴 | Timesheet staf | Belum siap |
| 🆕 🔴 | Matriks kebenaran granular (per modul) | Belum siap |
| 🆕 🔴 | Staf KPI per role | Belum siap |

---

## Modul 22 — Log Audit

| Status | Item | Note |
|:------:|------|------|
| ✅ | Audit log + trigger | `step3_audit.sql` |
| ✅ | RLS policy audit | `fix_audit_policy.sql` |
| ✅ | Audit UI | `audit.html` |
| ✅ | Kod rujukan unik | `step18_reference_code.sql` |
| 🆕 🔴 | Eksport log audit ke CSV | Belum siap |
| 🆕 🔴 | Alert corak mencurigakan (anomaly detection) | Belum siap |
| 🆕 🔴 | Tamper-evident logging (signed log) | Belum siap |
| 🆕 🔴 | Log retention policy (auto-arkib lama) | Belum siap |

---

## Modul 23 — Analitik, Hasil Rawatan & Tadbir Urus

| Status | Item | Note |
|:------:|------|------|
| ✅ | Outcome status (OTW / berhenti / meninggal) | `step30_outcome_status.sql` |
| ✅ | Kategori pakej | `step50_package_categories.sql` |
| ✅ | Governance dashboard | `governance.html` |
| ✅ | Risk dashboard | `risk.html` |
| ✅ | Pakej laporan & report | `pakej-laporan.html`, `pakej-report.html` |
| 🟡 | Filter dashboard penyakit / umur / gender / negeri | Lanjutan belum |
| 🟡 | Coach performance dashboard | Per-coach belum |
| 🟡 | Governance dashboard penuh | Sebahagian |
| 🔴 | Compare progress fasa 1 (BP, HbA1c) | Belum siap |
| 🔴 | Auto-summary check-in (graf / pie chart) | Belum siap |
| 🔴 | Analitik berjemur / watermelon / pijak batu panas | Belum siap |
| ⛔ | Kepatuhan definisi (kategori OB A / B / C) | Tunggu Meeting Izzah 26 Mei |
| ⛔ | Risk alert kriteria + threshold | Tunggu Meeting Izzah 26 Mei |
| 🆕 🔴 | Custom report builder | Belum siap |
| 🆕 🔴 | Schedule laporan auto-email | Belum siap |
| 🆕 🔴 | Cohort analysis | Belum siap |
| 🆕 🔴 | Funnel analysis (lead → signup → complete) | Belum siap |
| 🆕 🔴 | KPI alert (auto-notif jika KPI menurun) | Belum siap |
| 🆕 🔴 | Eksport PDF laporan dengan branding | Belum siap |
| 🆕 🔴 | Dashboard widget customization | Belum siap |

---

## Modul 24 — Platform & Infrastruktur (🆕 NEW)

Modul tambahan yang menangani isu platform menyeluruh.

| Status | Item | Note |
|:------:|------|------|
| 🆕 ✅ | Deploy Vercel | `vercel.json` |
| 🆕 ✅ | Deploy Railway | `railway.json` |
| 🆕 ✅ | Static server (Node.js Express) | `server.js`, `serve.json` |
| 🆕 ✅ | Skrip jana PowerPoint | `generate_ppt.py` |
| 🆕 ✅ | Konfigurasi Supabase | folder `supabase/` |
| 🆕 🔴 | Automated backup database | Belum siap |
| 🆕 🔴 | Disaster recovery plan | Belum siap |
| 🆕 🔴 | Pelan kapasiti / scaling | Belum siap |
| 🆕 🔴 | Health check endpoint | Belum siap |
| 🆕 🔴 | Uptime monitoring (StatusCake/UptimeRobot) | Belum siap |
| 🆕 🔴 | Error tracking (Sentry/Rollbar) | Belum siap |
| 🆕 🔴 | CI/CD pipeline (GitHub Actions) | Belum siap |
| 🆕 🔴 | Environment variables management | Belum siap |
| 🆕 🔴 | API public/private (untuk mobile app future) | Belum siap |
| 🆕 🔴 | Webhook outbound (ke sistem luar) | Belum siap |
| 🆕 🔴 | Rate limiting | Belum siap |
| 🆕 🔴 | CDN untuk asset static | Belum siap |
| 🆕 🔴 | Multi-tenancy (sokong banyak klinik) | Belum siap |
| 🆕 🔴 | Mobile app iOS/Android native | Belum siap |

---

## Ringkasan Status (A-Z)

| Status | Bilangan (anggaran) |
|--------|:--------:|
| ✅ Done | **~115** |
| 🟡 Partial | **~10** |
| 🟠 Schema ready, UI belum | **~6** |
| 🔴 Pending (asal) | **~35** |
| 🆕 🔴 Pending (item baharu ditambah) | **~120** |
| ⛔ Blocked (external) | **~6** |
| **Jumlah keseluruhan** | **~290 item** |

---

## Prioriti Go-Live (per Syafa)

| Priority | Item | Status |
|:--------:|------|--------|
| 1 | KYC | ✅ Done |
| 2 | GHL integration | ⛔ Blocked |
| 3 | Product description | 🟡 Partial |
| 4 | Notification system | 🟡 In-app done, external pending |
| 5 | Adherence checklist | ⛔ Tunggu Izzah |
| 6 | Schedule locking | ✅ Done |
| 7 | Governance dashboard | 🟡 Partial |

---

## Item Tersekat (Blocked) — Ringkasan

| Item | Tunggu |
|------|--------|
| GHL integration (closer, WhatsApp, KYC sync) | API key + access |
| WhatsApp Business API integration | API key + business verification |
| SQL Accounting connect (inventory + payment) | Integration spec |
| Kepatuhan definisi (kategori OB A / B / C) | Meeting Izzah 26 Mei 2026 |
| Risk alert kriteria + threshold | Meeting Izzah 26 Mei 2026 |
| ChatGPT / Whisper API (voice transcribe) | Akaun & key |

---

## Bilangan Halaman & Fail Siap (Codebase Audit)

| Komponen | Bilangan |
|----------|:--------:|
| Halaman patient siap | **24** (`roles/patient/*.html`) |
| Halaman staff siap | **56** (`roles/staff/*.html`) |
| Halaman auth siap | **3** (`auth/login.html`, `reset.html`, `set-password.html`) |
| Fail shared JS | **10** (`shared/*.js`) |
| Migrasi DB siap | **80+** (step1–step51, step_*, fix_*, seed_*) |
| Template PDF agreement | **12** (`Agreement/`) |
| Template surat | **7** (+ RELA DOCX/PDF) |

---

**Nota:** Item 🆕 adalah cadangan tambahan yang belum dalam audit asal Syafa — bukan permintaan rasmi klien tetapi *gap analysis* berdasarkan amalan biasa platform serupa.
