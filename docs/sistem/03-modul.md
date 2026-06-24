# 03 — Modul Sistem (Feature Overview)

[← Kembali ke indeks](README.md)

Setiap modul: **apa ia buat**, **halaman terlibat**, **jadual**, dan **aliran ringkas**. Untuk rajah aliran ASCII penuh lihat [`docs/System_Flows.md`](../System_Flows.md).

Petunjuk halaman: `P` = pesakit (`roles/patient/`), `S` = staf (`roles/staff/`).

---

## A. Onboarding Pesakit — KYC & KOB

**Fungsi:** Dari sign-up sehingga pesakit aktif dengan pakej. Dua borang: KYC (biodata/kesihatan) dan KOB (konsultasi + pilih pakej + tandatangan kontrak).

| | Halaman / Jadual |
|--|--|
| Pesakit | `P kyc.html`, `P kob.html`, `P kob-agreement.html` |
| Staf | `S kyc-list.html`, `S kyc-review.html`, `S kob-list.html`, `S kob-detail.html`, `S kob-slots.html` |
| Jadual | `psy_kyc_submissions`, `psy_kob_sessions`, `psy_kob_agreements`, `psy_kob_slot_config`, `psy_dna_reports` |

**Aliran:** Sign-up → `psy_profiles` (role=patient) → KYC (sokong isi oleh **pewaris/proxy**) → KOB 6 peringkat (welcome → mod F2F/online → pilih slot → pilih pakej → agreement+tandatangan → siap) → Doktor semak KYC → set `active_package_id`, `kob_status='kyc_done'`.

**Agreement digital:** klausa dari `psy_packages.agreement_clauses` (atau 29 default `shared/defaultAgreement.js`) → pesakit tandatangan (canvas) → `pdf-lib` jana PDF → simpan ke Storage + `psy_kob_agreements`. 12 template PDF rujukan di folder `Agreement/`.

---

## B. Pakej Rawatan & Pelan Mingguan

**Fungsi:** Tetapkan pakej (tempoh, bimbingan, bekalan, jadual, kontrak) dan jana pelan rawatan mingguan per-pesakit.

| | Halaman / Jadual |
|--|--|
| Pesakit | `P pakej.html`, `P pakej-detail.html`, `P plan.html`, `P plan-week.html`, `P routine.html` |
| Staf | `S pakej.html`, `S pakej-edit.html`, `S pakej-detail.html`, `S plans.html`, `S weekly-plan.html`, `S plan-week.html`, `S coaching-catalog.html` |
| Jadual | `psy_packages`, `psy_package_categories`, `psy_treatment_plans`, `psy_plan_weekly_progress`, `psy_coaching_catalog` |

**Aliran:** Edit pakej (maklumat asas → timeline rawatan M1..Mn dengan bimbingan dari katalog + bekalan dari inventori + mod → jadual harian → kontrak 29 klausa → tetapan lanjutan Gmeet/extension) → simpan `psy_packages`. KOB siap → staf jana pelan → `psy_treatment_plans` + N baris `psy_plan_weekly_progress`.

---

## C. Penjadualan & Temujanji

**Fungsi:** Slot konsultasi, kalendar coach/admin, reschedule, auto-lock cuti, auto-jana Google Meet.

| | Halaman / Jadual |
|--|--|
| Staf | `S appointments.html`, `S weekly-plan.html`, `S closures.html`, `S kob-slots.html` |
| Jadual | `psy_appointments`, `psy_clinic_closures`, `psy_slot_date_overrides` |

**Aturan ketidakhadiran (penting, kemaskini 24 Jun 2026):** Coach tanda *Tidak Hadir* = rekod absen + **tawar reschedule sahaja**. Minggu tambahan berbayar kini dibuka **secara MANUAL** (butang "Buka Minggu Tambahan") — **tiada auto-caj**. Dedup per minggu. (Lihat memori `project_absence_extension_rule`.)

---

## D. Catatan Harian & Kepatuhan ⭐

**Fungsi:** Pesakit isi checklist amalan + daily check-in dalam app (ganti Google Form). Auto-skor A/B/C. Coach lihat laporan, heatmap, eksport.

| | Halaman / Jadual |
|--|--|
| Pesakit | `P kepatuhan.html` ("Catatan Harian"), `P checkin.html` (redirect → kepatuhan) |
| Staf | `S kepatuhan.html` ("Kepatuhan Pesakit"), `S kepatuhan-fill.html` |
| Jadual | `psy_kepatuhan_item`, `psy_kepatuhan_log`, `psy_kepatuhan_weekly`, `psy_daily_checkins`, `psy_daily_completions` |

**Detail:**
- **Borang pesakit** gabung: Daily Check-in (emosi 5 domain, reaksi pemulihan berkumpulan, tidur, tahap aktiviti) + Checklist Amalan (9 item ikut fasa). Satu submit → tulis `psy_kepatuhan_log` + `psy_daily_checkins`.
- **Skor = "Pilihan B"**: skor mingguan = Σ skor harian ÷ hari berlalu (hari tak isi = 0). Kelas **A ≥85 / B 50–84 / C <50**. Coach boleh override.
- **Fasa**: dikesan dari `psy_treatment_plans.current_week` (week1 / week2-4 / week5-12 / fasa2 / fasa3). Setakat ini hanya **Week 1** ada item seeded.
- **Laporan coach**: jadual A/B/C 5-aras, donut taburan, **heatmap pesakit×amalan**, modal per-pesakit, laporan bulanan, **eksport Excel (SheetJS) + PDF (cetak)**.
- **Staff-fill**: staf boleh isi bagi pihak pesakit (`kepatuhan-fill.html` → borang pesakit dalam mod staf). Perlu RLS migration `20260627_staff_fill_kepatuhan.sql`.
- **Anti-ketidakpatuhan**: disclaimer wizard (Gred B/C), nudge dashboard pesakit (belum isi hari ini), + alert coach automatik (lihat [04 — Automasi](04-automasi-edge.md)).

(Detail penuh: memori `project_kepatuhan_module`.)

---

## E. Vital Sign & Rekod Perubatan

**Fungsi:** Pesakit rekod BP/HbA1c sendiri; muat naik laporan imbasan (X-Ray/MRI/CT) untuk coach semak.

| | Halaman / Jadual |
|--|--|
| Pesakit | `P vitals.html` ("Bacaan Saya"), `P rekod-perubatan.html`, `P rekod-tambah.html`, `P rekod-detail.html` |
| Staf | `S vitals.html`, `S patient-hub.html` |
| Jadual | `psy_vitals`, `psy_medical_reports`, `psy_medical_report_comments` |

---

## F. Inventori, Bekalan & Pulangan Botol

**Fungsi:** Master inventori, kit prosedur, auto-sync ke produk, auto-tolak stok bila sesi hadir, pulangan botol madu.

| | Halaman / Jadual |
|--|--|
| Staf | `S inventory.html`, `S inventory-detail.html`, `S kit-prosedur.html`, `S kit-edit.html`, `S pulangan.html` |
| Pesakit | `P pulangan.html` |
| Jadual | `psy_inventory_items`, `psy_inventory_requests`, `psy_procedure_kits`, `psy_supply_disbursements`, `psy_bottle_returns` |

**Auto-mekanisme:**
- **Auto-sync** (`shared/stockSync.js`): Inventori ↔ Produk padan ikut nama (case-insensitive).
- **Auto-deduct** (`shared/inventoryDeduct.js`): sesi tanda hadir → tolak stok dari `coaching_schedule.supplies` minggu itu (skip jika Online/extension) → tulis `psy_audit_log` action `inventory.auto_deducted` → banner bekalan ditolak.

---

## G. Kedai & Pesanan (E-dagang)

**Fungsi:** Pesakit beli produk; staf urus stok & penghantaran. Auto-tolak/restock inventori.

| | Halaman / Jadual |
|--|--|
| Pesakit | `P shop.html`, `P orders.html`, `P payment.html` |
| Staf | `S products.html`, `S product-edit.html`, `S product-detail.html`, `S services.html`, `S service-detail.html`, `S orders.html` |
| Jadual | `psy_products`, `psy_services`, `psy_orders` |

**Order lifecycle:** Cart → Checkout (alamat/penghantaran) → Payment → `psy_orders` (paid) → staf *packed* (**auto-deduct** produk+inventori) → *shipped* (+tracking) → pesakit sahkan *delivered*. Batal selepas packed → **auto-restock**.

> Produk baru **wajib** pilih item inventori dahulu (picker modal; block jika stok 0).

---

## H. Pembayaran & Kewangan

**Fungsi:** Pesakit bayar pakej/order; staf sahkan + resit.

| | Halaman / Jadual |
|--|--|
| Pesakit | `P payment.html` |
| Staf | `S payment-admin.html` |
| Jadual | `psy_payments` |

> **Status:** UI + DB lengkap tetapi `processPayment()` masih **SIMULASI** — tiada gateway sebenar lagi. Model bayar sekali. Pilihan gateway (Billplz vs ToyyibPay) + SST masih pending. (Lihat memori `project_payment_gateway_pending`.)

---

## I. Kandungan — Self-Help Library

**Fungsi:** Staf muat video/artikel/worksheet; pesakit tonton (filter ikut pakej).

| | Halaman / Jadual |
|--|--|
| Pesakit | `P library.html`, `P library-detail.html`, `P faq.html`, `P faq-overhaul.html` |
| Staf | `S library.html`, `S library-edit.html`, `S library-detail.html`, `S library-view.html`, `S library-categories.html`, `S library-faq-edit.html`, `S faq-overhaul.html` |
| Jadual | `psy_library_items`, `psy_library_categories`, `psy_library_bookmarks`, `psy_library_feedback`, `psy_library_views` |

Model: `media_type` / `topic` / `tags` / `package_ids`. (Migrasi step49→51.)

---

## J. Pengumuman, Acara & Kelas

**Fungsi:** Pengumuman bersasar + acara/kelas dengan pendaftaran & kehadiran.

| | Halaman / Jadual |
|--|--|
| Pesakit | `P announcements.html`, `P event-detail.html` |
| Staf | `S announcements.html`, `S announcement-detail.html`, `S pengumuman-baru.html`, `S pengumuman-edit.html`, `S events.html`, `S acara-detail.html` |
| Jadual | `psy_announcements`, `psy_announcement_categories`, `psy_announcement_types`, `psy_events`, `psy_event_registrations`, `psy_event_materials` |

**Ciri:** sasaran (Semua Pesakit / Pakej Tertentu / Staff), banner cropper 2:1, tarikh tamat papar (auto-sembunyi expired), urus kategori dalam app, bahan acara (nota/video/slaid/pautan), kehadiran + eksport CSV. Penciptaan acara mengalir dari Pengumuman.

---

## K. Surat Rasmi & Isu Produk

**Fungsi:** Jana surat rasmi (KWSP/PERKESO/RELA/dll) auto-isi; pesakit lapor isu produk.

| | Halaman / Jadual |
|--|--|
| Pesakit | `P surat.html`, `P issue.html`, `P issue-thread.html` |
| Staf | `S surat.html`, `S surat-edit.html`, `S surat-issue.html`, `S issue.html`, `S issue-detail.html` |
| Jadual | `psy_letter_requests`, `psy_letter_issued`, `psy_letter_templates`, `psy_letter_template_overrides`, `psy_letter_template_files`, `psy_letter_auto_fields` |

7 template surat dalam `shared/letterTemplates.js` (+ RELA DOCX/PDF di folder `surat/`). Jana PDF dengan medan pesakit + letterhead + tandatangan staf → audit log + Storage.

---

## L. Pengurusan Pesakit & Staf

**Fungsi:** Senarai/hab pesakit; assign coach; pre-KYC; urus staf & peranan.

| | Halaman / Jadual |
|--|--|
| Staf | `S patients.html`, `S patient-hub.html`, `S staff_management.html`, `S staff-detail.html`, `S staff-stats.html`, `S peranan.html`, `S audit-kebenaran.html`, `S profile.html` |
| Pesakit | `P profile.html` |
| Jadual | `psy_profiles`, `psy_patients`, `psy_permissions`, `psy_role_permissions`, `psy_user_permissions` |

> **Nota:** `assignments.html` (penugasan) telah **dibersarakan** → redirect. Tab penugasan kini dalam `patients.html`. Edit `patients.html`, bukan `assignments.html`. (Memori `project_assignments_merged`.)
> **Pencegahan duplikat pesakit**: autoLink + sekatan IC keras; migrasi cleanup step66. (Memori `project_patient_dedup`.)

Detail RBAC: [05 — Peranan & Akses](05-peranan-akses.md).

---

## M. Tadbir Urus, Risiko, Audit & Laporan

**Fungsi:** Dashboard KPI, amaran risiko, log audit, laporan pakej, statistik.

| | Halaman / Jadual |
|--|--|
| Staf | `S governance.html`, `S risk.html`, `S audit.html`, `S audit-kebenaran.html`, `S staff-stats.html`, `S pakej-laporan.html`, `S pakej-report.html` |
| Jadual | `psy_audit_log`, `psy_risk_alerts`, `psy_adherence_alerts` |

Risk dashboard (`risk.html`) himpun amaran termasuk kategori `kepatuhan` yang dijana automatik oleh runner (lihat [04 — Automasi](04-automasi-edge.md)).

---

## N. Komunikasi — Inbox WhatsApp & Notifikasi

**Fungsi:** Inbox WhatsApp (via GHL), notifikasi dalam app, maklum balas.

| | Halaman / Jadual |
|--|--|
| Staf | `S inbox.html`, `S auto-mesej.html`, `S feedback.html` |
| Pesakit | `P feedback.html` |
| Jadual | `psy_wa_conversations`, `psy_wa_messages`, `psy_notifications`, `psy_feedback`, `psy_weekly_feedback`, `psy_auto_messages` |

Mesej automatik & GHL: lihat [04 — Automasi & Edge Functions](04-automasi-edge.md).

---

Seterusnya: [04 — Automasi & Edge Functions →](04-automasi-edge.md)
