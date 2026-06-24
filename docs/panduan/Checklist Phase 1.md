# ISW Psikoterapi — Checklist Status + Aliran Kerja Sistem

**Tarikh kemaskini:** 22 Mei 2026
**Sistem:** Platform Psikoterapi Ibnu Sina Wellness (ISW)
**Versi:** v4.0 (gabungan checklist + workflow)

Dokumen ini gabungan **2-dalam-1**: status pembangunan setiap item (untuk PM/management) + aliran kerja ringkas setiap modul (untuk training/SOP). Setiap modul disusun: penerangan → peranan → halaman → aliran ringkas → checklist status.

---

## Legend Status

- ✅ **Done** — Siap & live
- 🟡 **Partial** — Sebahagian siap, sebahagian tertunggak
- 🟠 **Schema Ready** — Database siap, UI/logic belum
- 🔴 **Pending** — Belum dimulakan
- ⛔ **Blocked** — Tertangguh tunggu external

---

## Jenis Pengguna

| Peranan | Penerangan |
|---------|------------|
| **Pesakit** | Individu daftar program terapi 12 minggu |
| **Pewaris** | Proksi keluarga yang isi KYC bagi pesakit tak berkeupayaan |
| **Closer** | Staf jualan (saranan pra-daftar, KYC) |
| **Coach** | Pegawai utama bimbing pesakit mingguan |
| **Hakeema** | Pakar rohani/holistik (sesi 1:1 M6/M11/Q-bulanan) |
| **Hakeem** | Pengamal perubatan Islam tradisional |
| **Kaunselor** | Pakar kesihatan mental |
| **Doktor** | Pengamal perubatan berlesen |
| **Fisioterapis** | Pakar pergerakan/rehab |
| **Admin** | Staf operasi (jadual, inventori, komunikasi) |
| **Staf Kewangan** | Bil & perakaunan |
| **Pengurusan** | Kepimpinan ISW (dashboard governance) |

---

## Aliran Induk (Ringkasan)

Pesakit melalui 24 modul: **M0 Foundation** → **M1 Onboarding** → **M2 KOB** → **M3 Persetujuan** → **M4 Setup Pakej** → **M5 Temujanji + M6 Check-in + M7 Rutin + M8 Vital** berjalan serentak 12 minggu. **M9 Inventori, M10 Coaching, M11 Katalog, M12 Tugasan, M13 Library** menyokong. **M14 Komunikasi, M15 Surat, M16 Kewangan, M17 Kedai, M18 Pengumuman, M19 Penglibatan, M20 Profil** = cross-cutting. **M21 Staf, M22 Audit, M23 Analitik** = pentadbiran platform.

---

## Modul 0 — Platform Foundation (Auth, Navbar, Dashboard)

**Penerangan:** Lapisan asas authentication, navigation, dan dashboard pendaratan. Setiap halaman bergantung modul ini.

**Peranan:** Semua pengguna

**Halaman utama:** [auth/login.html](../auth/login.html), [auth/reset.html](../auth/reset.html), [auth/set-password.html](../auth/set-password.html), [roles/patient/dashboard.html](../roles/patient/dashboard.html), [roles/staff/dashboard.html](../roles/staff/dashboard.html), [shared/navbar.js](../shared/navbar.js), [shared/authGuard.js](../shared/authGuard.js)

**Aliran ringkas:**
1. Pengguna buka URL → `authGuard.js` semak sesi.
2. Tiada sesi → redirect ke `login.html`.
3. Ada sesi → baca peranan daripada `profiles` → muat dashboard sesuai (patient vs staff).
4. `navbar.js` bina menu dinamik ikut peranan.
5. Logout → bersihkan sesi → balik ke login.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Login (Supabase Auth) | `auth/login.html` + `auth/auth.js` |
| ✅ | Reset password (e-mel pautan) | `auth/reset.html` |
| ✅ | Set password baharu | `auth/set-password.html` |
| ✅ | Auth Guard ikut peranan | `shared/authGuard.js` |
| ✅ | Navbar dinamik patient vs staf | `shared/navbar.js` |
| ✅ | Logout & clear sesi | `shared/logout.js` |
| ✅ | Theme switcher | `shared/theme.js` |
| ✅ | Dashboard pesakit & staf | `dashboard.html` (kedua-dua) |
| ✅ | Landing pendaratan awam | `index.html`, `landing-preview.html` |
| 🟡 | Mobile responsive | Sebahagian; belum audit penuh |
| 🔴 | 2FA / OTP login | Belum siap |

---

## Modul 1 — Pengambilan Lead & Onboarding Pesakit

**Penerangan:** Closer tangkap lead, hantar KYC, sahkan signup.

**Peranan:** Closer, Admin, Pesakit, Pewaris

**Halaman:** [roles/patient/kyc.html](../roles/patient/kyc.html), [roles/staff/kyc-list.html](../roles/staff/kyc-list.html), [roles/staff/kyc-review.html](../roles/staff/kyc-review.html)

**Aliran ringkas:**
1. **Closer** tangkap lead di GHL → hantar pautan KYC.
2. **Pesakit / Pewaris** isi KYC (tick `submitted_by_proxy` jika proksi).
3. Sistem auto-link rekod ke staf Closer (email match).
4. **Admin** semak di `kyc-list.html` → lulus/tolak.
5. **Ralat:** medan kosong → form tolak; email mismatch → Admin reconcile manual.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Track patient signup pakej | `active_package_id` + filter Semua Signup |
| ✅ | KYC popup pewaris vs patient | `step29_kyc_proxy.sql` |
| ✅ | Auto-link signup → staff record | Match by email `_shared.js initPatient()` |
| ✅ | KYC review queue | `kyc-list.html`, `kyc-review.html` |
| ✅ | Medan KYC tambahan & sync | `step15`, `step19` |
| ✅ | Track staf cipta pesakit | `step_patients_created_by_staff.sql` |
| 🔴 | Closer key-in saranan rawatan pre-signup | Belum siap |
| ⛔ | GHL integration | Tunggu API key |

---

## Modul 2 — KOB (Konsultasi Online Bermula)

**Penerangan:** Soalselidik pesakit, slot konsultasi, saranan pakej.

**Peranan:** Pesakit/Pewaris, Coach, Doktor, Admin

**Halaman:** [roles/patient/kob.html](../roles/patient/kob.html), [roles/staff/kob-list.html](../roles/staff/kob-list.html), [roles/staff/kob-detail.html](../roles/staff/kob-detail.html), [roles/staff/kob-slots.html](../roles/staff/kob-slots.html)

**Aliran ringkas:**
1. Pesakit isi soalselidik KOB → sistem jana saranan pakej.
2. Pesakit pilih slot konsultasi online.
3. Bayaran KOB (atau skip jika kempen).
4. **Coach/Doktor** kendalikan sesi pada masa slot → sahkan/ubah saranan.
5. **Decision:** Pesakit terima pakej? Ya → M3; Tidak → status `unregistered`.
6. **Ralat:** Tidak hadir slot → laporan DNA dijana automatik.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Soalselidik KOB | `step37_kob_questionnaire.sql` |
| ✅ | Saranan pakej auto | `step38_kob_package_recommendation.sql` |
| ✅ | Slot KOB | `step36_kob_slots.sql` |
| ✅ | Skip bayaran KOB (kempen) | `step35_kob_skip_payment.sql` |
| ✅ | Laporan DNA | `step23_dna_reports.sql` |
| ✅ | Status `unregistered` | `step21_unregistered_status.sql` |
| ✅ | Storage bucket KOB & rujukan | `step42`, `step43` |

---

## Modul 3 — Persetujuan Digital (KOB Agreement)

**Penerangan:** Pesakit semak klausa, tandatangan digital, sistem jana PDF.

**Peranan:** Pesakit/Pewaris, Admin

**Halaman:** [roles/patient/kob-agreement.html](../roles/patient/kob-agreement.html)

**Aliran ringkas:**
1. Sistem papar klausa default daripada `defaultAgreement.js`.
2. Pesakit tick "Saya faham" setiap klausa → tandatangan canvas.
3. Sistem jana PDF via pdf-lib → simpan dalam `psy_kob_agreements`.
4. **Decision:** Bayaran diterima? Ya → M4; Tidak → reminder loop (M16).
5. **Ralat:** signature kosong → jana PDF disekat.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Digital agreement + signature PDF | `psy_kob_agreements` + pdf-lib |
| ✅ | Klausa persetujuan | `step41`, `seed_default_agreement_clauses.sql` |
| ✅ | Storage PDF agreement | `step40_agreement_storage.sql` |
| ✅ | 12 template PDF per pakej | Folder `Agreement/` |
| ✅ | Klausa default loader | `shared/defaultAgreement.js` |

---

## Modul 4 — Setup Pakej & Pelan Rawatan 12 Minggu

**Penerangan:** Admin assign pakej, sistem seed pelan 12 minggu.

**Peranan:** Admin, Coach, Pesakit

**Halaman:** [roles/patient/pakej.html](../roles/patient/pakej.html), [roles/patient/pakej-detail.html](../roles/patient/pakej-detail.html), [roles/patient/plan.html](../roles/patient/plan.html), [roles/patient/plan-week.html](../roles/patient/plan-week.html), [roles/staff/pakej-edit.html](../roles/staff/pakej-edit.html), [roles/staff/plans.html](../roles/staff/plans.html)

**Aliran ringkas:**
1. Admin assign `active_package_id`.
2. Sistem seed: `weekly_message`, `weekly_supplies`, `weekly_content`, `daily_schedule`, `madu_frequency_per_day`, `online_lock_from_week`.
3. Pesakit & Coach lihat Week 1–12 di `plan.html`.
4. **Decision:** Upgrade/downgrade/add-on kemudian? → re-seed minggu selebihnya + invois pro-rata.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Coach & patient view Week 1–12 | `plan.html`, `plan-week.html` |
| ✅ | Pakej + template + kategori | `step5`, `step50_package_categories.sql` |
| ✅ | Sambungan pakej (extend minggu) | `step32`, `step_package_extension_price.sql` |
| ✅ | Bilangan sesi seminggu per pakej | `step_sessions_per_week.sql` |
| ✅ | Setup jadual pelan + RLS | `step_plan_schedule_setup.sql` |
| ✅ | Edit konfigurasi pakej | `pakej-edit.html` |
| 🟠 | Pakej ID + bekalan + bimbingan + WhatsApp | Schema ada; UI render belum |
| 🟠 | Lock online dari minggu 3 | Schema ada; UI check belum |
| 🔴 | Pakej upgrade/downgrade/add-on/bonus tier | Belum siap |

---

## Modul 5 — Penjadualan & Temujanji

**Penerangan:** Kalendar, slot, cuti klinik, reminder.

**Peranan:** Admin, Coach, Pesakit

**Halaman:** [roles/staff/appointments.html](../roles/staff/appointments.html), [roles/staff/weekly-plan.html](../roles/staff/weekly-plan.html), [roles/staff/closures.html](../roles/staff/closures.html)

**Aliran ringkas:**
1. Admin konfigur slot (template mingguan + override).
2. Auto-kunci cuti klinik daripada `psy_clinic_closures`.
3. Pesakit tempah temujanji.
4. **Decision Week ≥ 3 + online_lock?** → hanya slot online.
5. **Kehadiran:** Hadir → loop minggu berikut; Cancel → tangkap sebab (🟡 belum siap); No-show → `autoMarkMissedAndExtend()` tambah seminggu + invois.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Kalendar admin & coach lengkap | `appointments.html`, `weekly-plan.html` |
| ✅ | Cuti umum / Hari Raya auto-lock | `step28_clinic_closures.sql` |
| ✅ | Sistem slot baharu | `step47_slot_overhaul.sql` |
| ✅ | Auto-tambah minggu reschedule + harga | `autoMarkMissedAndExtend()` |
| ✅ | Auto-jana pautan Google Meet | `step26`, `step_package_meet_link.sql` |
| 🟡 | Lock waktu rawatan, admin pilih offer | UI staff utk lock-pick belum |
| 🟡 | Reminder hadir + reason tak hadir | Tangkap alasan belum |
| 🔴 | Calendar reminder push | Belum siap |
| 🔴 | Reminder sebelum & semasa rawatan | Belum siap |
| 🔴 | Auto WhatsApp reminder (every 5h) | Belum siap |

---

## Modul 6 — Check-in Harian & Kepatuhan

**Penerangan:** Pesakit log madu, vital, emosi setiap hari.

**Peranan:** Pesakit, Coach

**Halaman:** [roles/patient/checkin.html](../roles/patient/checkin.html), [roles/patient/kepatuhan.html](../roles/patient/kepatuhan.html), [roles/staff/kepatuhan.html](../roles/staff/kepatuhan.html)

**Aliran ringkas:**
1. Setiap pagi pesakit buka checklist: madu, vital, emosi.
2. Sistem log ke `psy_patient_checkins`.
3. **Decision:** Madu < 5/hari ATAU 4–5 hari/mgg tercicir → fire `psy_adherence_alerts` → Coach + risk dashboard.
4. **Decision:** Emergency keyword → Protokol Merah (Coach + Admin + Doktor dipanggil — 🔴 belum siap).

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Daily checklist + jadual minum madu | `madu_frequency_per_day` |
| ✅ | Tracking ambilan madu | `step33_madu_tracking.sql` |
| ✅ | Jadual checkins + log selesai | `step7`, `step46` |
| ✅ | Pengiraan skor kepatuhan | `shared/adherence.js` |
| 🟠 | Alert coach tak patuh | `psy_adherence_alerts` ada; trigger logic belum |
| 🔴 | Daily check-in emosi + action | Belum siap |
| 🔴 | Red emergency protokol | Belum siap |
| 🔴 | Reaksi pemulihan modul | Belum siap |
| ⛔ | Kepatuhan definisi (OB A/B/C) | Tunggu Meeting Izzah 26 Mei |

---

## Modul 7 — Rutin Harian

**Penerangan:** Jadual harian terperinci (zikir, berjemur, OB, latihan, muhasabah).

**Peranan:** Pesakit, Coach

**Halaman:** [roles/patient/routine.html](../roles/patient/routine.html)

**Aliran ringkas:**
1. Pesakit buka routine → sistem muat `daily_schedule` JSONB ikut pakej.
2. Render aktiviti hari ini.
3. Pesakit tanda selesai → log ke `daily_completions`.
4. Data suap ke M6 (kepatuhan) & M23 (analitik).

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Jadual harian sample setiap pakej | `step44`, `step45` |
| ✅ | Routine page patient | `routine.html` |
| ✅ | Log selesai aktiviti | `step46_daily_completions.sql` |
| 🔴 | Analitik berjemur/watermelon/batu panas | Belum siap |

---

## Modul 8 — Vital Sign & Rekod Perubatan

**Penerangan:** Pesakit kemaskini BP/HbA1c; upload laporan imbas.

**Peranan:** Pesakit, Coach, Doktor

**Halaman:** [roles/patient/vitals.html](../roles/patient/vitals.html), [roles/staff/vitals.html](../roles/staff/vitals.html)

**Aliran ringkas:**
1. Pesakit input BP/HbA1c → sistem simpan + render history tabular.
2. **Decision:** Perlu laporan baru? → upload ke `psy_medical_reports` (X-Ray, MRI, CT).
3. Coach/Doktor semak.
4. **Decision:** Trend membimbangkan? → jadual konsult tambahan + escalate ke Doktor.
5. **Decision:** Pesakit dialisis? → notif 500ml (🔴 belum siap).

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Patient view BP/HbA1c + update sendiri | `vitals.html` (`step31`) |
| ✅ | Upload medical report | `psy_medical_reports` |
| ✅ | Vital pautan ke minggu | `step_vitals_link_to_week.sql` |
| 🟡 | BP/HbA1c trend graph | Tabular ada; graph belum |
| 🔴 | Patient appointment doktor untuk medical report | Belum siap |
| 🔴 | Dialisis 500ml notification | Belum siap |
| 🔴 | Compare progress fasa 1 | Belum siap |

---

## Modul 9 — Inventori, Bekalan & Pulangan Botol

**Penerangan:** Auto-kira keperluan, auto-PO, pulangan botol, isu produk.

**Peranan:** Admin, Staf Kewangan, Pesakit

**Halaman:** [roles/staff/inventory.html](../roles/staff/inventory.html), [roles/staff/inventory-detail.html](../roles/staff/inventory-detail.html), [roles/staff/kit-prosedur.html](../roles/staff/kit-prosedur.html), [roles/patient/pulangan.html](../roles/patient/pulangan.html), [roles/patient/issue.html](../roles/patient/issue.html)

**Aliran ringkas:**
1. Aggregator kira keperluan bekalan ikut pesakit aktif.
2. **Decision:** Stok ≤ 30% + auto_reorder ON? → cron fire auto-PO → Kewangan notified.
3. Pesakit pulangkan botol → sistem validate kriteria → Admin sahkan → kredit/refund.
4. Pesakit submit isu produk dengan gambar → `psy_issues` → Admin handle.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Inventory listing detailed | `psy_inventory_items` + `psy_procedure_kits` |
| ✅ | Asas inventori | `step17`, `step25`, `step27` |
| ✅ | Pembekal & jenis penggunaan | `step_inventory_supplier_info`, `step_inventory_consumption_type` |
| ✅ | Kit prosedur (IV setup dll) | `step_procedure_kits`, `kit-edit.html` |
| ✅ | Pautan produk ↔ inventori | `step_product_inventory_link.sql` |
| ✅ | Tolak stok automatik | `shared/inventoryDeduct.js` |
| ✅ | Patient return botol | `psy_bottle_returns` |
| ✅ | Patient submit isu rosak | `psy_issues` + upload |
| 🟠 | Auto-calc bekalan ikut pakej aktif | Aggregator belum |
| 🟠 | Auto-PO stok ≤ 30% | Cron belum |
| ⛔ | SQL Accounting connect | Tunggu integration spec |

---

## Modul 10 — Coaching, Konsultasi & Sesi Pakar

**Penerangan:** Coach sesi mingguan; rujuk Hakeema/Hakeem/Kaunselor/Fisio/Doktor ikut milestone/risk.

**Peranan:** Coach, Hakeema, Hakeem, Kaunselor, Fisioterapis, Doktor

**Halaman:** [roles/staff/coaching.html](../roles/staff/coaching.html), [roles/staff/consultation.html](../roles/staff/consultation.html), [roles/staff/patient-hub.html](../roles/staff/patient-hub.html)

**Aliran ringkas:**
1. Coach buka senarai pesakit (semua coach nampak semua).
2. Lihat ringkasan check-in + pelan mingguan.
3. Kendalikan sesi (fizikal/online).
4. Lengkapkan checklist mingguan + nota sesi.
5. **Decision milestone:** M6 atau M11 → tempah Hakeema; Q1–Q3 → Hakeema bulanan; mental → Kaunselor; tradisional → Hakeem; rehab → Fisio; akut → Doktor.
6. **Decision:** Ward admission? → notif Management (🔴 belum siap).

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Coach buka SEMUA pesakit | Lock per-coach dibuang |
| ✅ | Penugasan coach ↔ pesakit | `step13`, `fix_coach_assignment.sql` |
| ✅ | Jenis sesi & nota | `step22`, `step24` |
| ✅ | Sesi konsultasi luar program | `consultation.html` |
| ✅ | Peranan Doktor | `step14_doctor_role.sql` |
| 🟡 | Coach performance dashboard | Per-coach metrics belum |
| 🟡 | Weekly checklist link coach report | Integrasi penuh belum |
| 🔴 | Sesi 1:1 Hakeema (M6/M11/Q-bulanan) | Belum siap |
| 🔴 | Hakeem / Kaunselor / Physiotherapist sistem | Belum siap |
| 🔴 | Voice record + transcribe → auto WhatsApp | Belum siap |
| 🔴 | Pesakit masuk ward → notif management | Belum siap |

---

## Modul 11 — Katalog Bimbingan

**Penerangan:** Admin urus senarai perkhidmatan bimbingan (durasi, harga, prasyarat).

**Peranan:** Admin, Coach

**Halaman:** [roles/staff/coaching-catalog.html](../roles/staff/coaching-catalog.html)

**Aliran ringkas:**
1. Admin tambah item katalog (tajuk, durasi, harga, peranan).
2. Coach pilih dari katalog bila jadual sesi → medan auto-isi.
3. Override jika perlu.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Katalog bimbingan | `step_coaching_catalog.sql` + seed |
| ✅ | UI katalog | `coaching-catalog.html` |

---

## Modul 12 — Tugasan Pesakit (Assignments)

**Penerangan:** Coach beri tugasan; pesakit submit; coach review.

**Peranan:** Coach, Pesakit

**Halaman:** [roles/staff/assignments.html](../roles/staff/assignments.html), [roles/staff/assignment-review.html](../roles/staff/assignment-review.html)

**Aliran ringkas:**
1. Coach cipta tugasan (refleksi/latihan/upload) + tarikh akhir.
2. Pesakit submit (teks/fail/gambar).
3. Coach review → lulus/minta hantar semula.
4. **Lewat:** flag kepatuhan + reminder.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Cipta & senarai tugasan | `assignments.html` |
| ✅ | Semak submission | `assignment-review.html` |
| 🔴 | Reminder lewat hantar | Belum siap |
| 🔴 | Auto-bintang lepas lulus | Belum siap |

---

## Modul 13 — Perpustakaan Kandungan

**Penerangan:** Video, SOP, FAQ dibuka secara dinamik ikut pakej + minggu.

**Peranan:** Pesakit, Admin

**Halaman:** [roles/patient/library.html](../roles/patient/library.html), [roles/patient/library-detail.html](../roles/patient/library-detail.html), [roles/staff/library-edit.html](../roles/staff/library-edit.html)

**Aliran ringkas:**
1. Admin upload + tag `package_ids`.
2. Pesakit buka → sistem baca pakej + minggu semasa.
3. Kandungan unlocked = paparkan; locked = ikon kunci.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Asas perpustakaan + media | `step8`, `step12` |
| ✅ | Filter ikut pakej | `step49_library_package_filter.sql` |
| ✅ | Library browse patient + staff | `library.html`, `library-edit.html` |
| 🟠 | Auto lock/unlock ikut pakej | Schema ada; enforcement belum |
| 🔴 | Video testimoni LTH + 3 minggu | Content upload |
| 🔴 | Diet umrah/haji, Madu Ramadhan SOP | Content upload |
| 🔴 | Video OB (10 video — berjemur, zikir, dll) | Content upload |
| 🔴 | Welcome video / lokasi | Belum siap |
| 🔴 | AI chatbot FAQ | Belum siap |

---

## Modul 14 — Komunikasi & Notifikasi

**Penerangan:** Enjin notifikasi cross-cutting (invois, reminder, FAQ, alert agama, kecemasan).

**Peranan:** Admin, Pesakit, Coach, Sistem Luar

**Halaman:** [roles/staff/announcements.html](../roles/staff/announcements.html) (in-app side)

**Aliran ringkas:**
1. Sistem pantau peristiwa M1–M13.
2. Hala mesej via in-app / email / WhatsApp ikut jenis peristiwa.
3. **Decision delivery:** Gagal → retry 3x → fallback ke saluran alternatif.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | In-app announcement | `psy_announcements` |
| 🔴 | Auto-send invoice email + WhatsApp | Belum siap |
| 🔴 | Notification reaksi pemulihan | Belum siap |
| 🔴 | FAQ + emergency mesej | Belum siap |
| 🔴 | Notif daging korban (3 hari sebelum 1 Dzulhijjah) | Belum siap |
| 🔴 | Live bacaan Manzil (Rab/Kham/Jum 8.45am) | Belum siap |
| ⛔ | WhatsApp Business API | Tunggu integrasi |

---

## Modul 15 — Surat & Isu Produk

**Penerangan:** Admin jana surat sokongan; pesakit hantar isu produk.

**Peranan:** Pesakit, Admin, Coach

**Halaman:** [roles/patient/surat.html](../roles/patient/surat.html), [roles/patient/issue.html](../roles/patient/issue.html), [roles/patient/issue-thread.html](../roles/patient/issue-thread.html), [roles/staff/surat.html](../roles/staff/surat.html), [roles/staff/surat-edit.html](../roles/staff/surat-edit.html), [roles/staff/issue-detail.html](../roles/staff/issue-detail.html)

**Aliran ringkas:**
1. **Surat:** Pesakit minta → Admin pilih dari 7 template (KWSP, PERKESO, RELA, Insurans, MC, Wad, Custom) → isi medan → jana PDF.
2. **Isu:** Pesakit upload gambar produk rosak → Admin review → refund/ganti.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Template surat 7 jenis | `letterTemplates.js` |
| ✅ | Asas surat + auto-fields + files | `step_letter_base`, `step_letter_auto_fields`, `step_letter_files` |
| ✅ | Override template surat | `step_letter_template_overrides.sql` |
| ✅ | Patient submit isu + thread | `psy_issues` + upload |
| ✅ | Surat tindakan isu | `surat-issue.html` |
| ✅ | Template RELA fizikal | `surat/Surat permohonan RELA.docx/pdf` |
| 🔴 | Kelas NLC attendance + folder | Belum siap |

---

## Modul 16 — Kewangan, Bil & Pembayaran

**Penerangan:** Invois, resit, recurring, sync SQL Accounting.

**Peranan:** Staf Kewangan, Admin, Pesakit

**Halaman:** [roles/patient/payment.html](../roles/patient/payment.html), [roles/staff/payment-admin.html](../roles/staff/payment-admin.html)

**Aliran ringkas:**
1. Peristiwa boleh-bil (signup/reschedule/upgrade/auto-PO/pesanan) → jana invois.
2. Kewangan sahkan → hantar via M14.
3. Pesakit bayar via gateway.
4. **Decision:** Bayar? Ya → resit + sync SQL Accounting (⛔); Tidak → reminder setiap 3 hari.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Asas payments | `step6_payments.sql` |
| ✅ | Payment patient + admin page | `payment.html`, `payment-admin.html` |
| 🟡 | Format resit/invoice standardize | Generate ada; branding belum |
| 🔴 | Auto-send invoice email + WhatsApp | Belum siap |
| ⛔ | Recurring + SQL Accounting sync | Tunggu integration spec |

---

## Modul 17 — Kedai & E-Dagang

**Penerangan:** Pesakit beli produk/perkhidmatan add-on; auto-tolak inventori.

**Peranan:** Pesakit, Admin, Staf Kewangan

**Halaman:** [roles/patient/shop.html](../roles/patient/shop.html), [roles/patient/orders.html](../roles/patient/orders.html), [roles/staff/products.html](../roles/staff/products.html), [roles/staff/services.html](../roles/staff/services.html), [roles/staff/product-edit.html](../roles/staff/product-edit.html), [roles/staff/orders.html](../roles/staff/orders.html)

**Aliran ringkas:**
1. Admin urus katalog produk + perkhidmatan.
2. Pesakit checkout → cipta order → invois (M16) → bayar.
3. Berjaya → stok ditolak automatik via `inventoryDeduct.js`.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Asas produk + enhanced | `step9`, `step_products_enhanced.sql` |
| ✅ | URL gambar produk | `step_products_image_url.sql` |
| ✅ | Pautan produk ↔ inventori | `step_product_inventory_link.sql` |
| ✅ | Shop, orders patient & staff | `shop.html`, `orders.html` (kedua-dua) |
| ✅ | Products, services staff | `products.html`, `services.html` |
| ✅ | Auto-tolak inventori | `shared/inventoryDeduct.js` |
| 🟡 | Product description perkaya | Partial |

---

## Modul 18 — Pengumuman

**Penerangan:** Admin terbit pengumuman global/per-pakej/per-peranan.

**Peranan:** Admin, Pesakit, Coach

**Halaman:** [roles/staff/announcements.html](../roles/staff/announcements.html), [roles/staff/announcement-detail.html](../roles/staff/announcement-detail.html)

**Aliran ringkas:**
1. Admin cipta pengumuman (tajuk, badan, sasaran, urgent level).
2. Urgent → cetus push (M14); selain itu → muncul di dashboard.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Asas + senarai + detail | `step10`, `announcements.html` |
| 🔴 | Push urgent ke WhatsApp | Belum siap |

---

## Modul 19 — Penglibatan & Pengekalan

**Penerangan:** Bintang ganjaran, rujukan, ALIVE, testimoni.

**Peranan:** Pesakit, Admin, Coach

**Halaman:** [roles/patient/feedback.html](../roles/patient/feedback.html), [roles/staff/feedback.html](../roles/staff/feedback.html)

**Aliran ringkas:**
1. Sistem pantau milestone M5/M6/M7/M10/M12.
2. Bintang/cabutan bertuah (🔴) atau disclaimer motivasi (🔴).
3. Rujukan berjaya → baucar hadiah.
4. Tamat program → testimoni + Google Review prompt.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Status tamat rawatan | `step51_treatment_completion.sql` |
| ✅ | Feedback mingguan | `step48`, `feedback.html` |
| 🔴 | Auto reward star + cabutan bertuah | Belum siap |
| 🔴 | Referral program + gift voucher | Belum siap |
| 🔴 | Geng ALIVE | Belum siap |
| 🔴 | Disclaimer motivasi | Belum siap |
| 🔴 | Feedback Google Review + sosial | Belum siap |

---

## Modul 20 — Pengurusan Profil

**Penerangan:** Pesakit + staf kemaskini maklumat peribadi.

**Peranan:** Semua

**Halaman:** [roles/patient/profile.html](../roles/patient/profile.html), [roles/staff/profile.html](../roles/staff/profile.html), [roles/staff/patients.html](../roles/staff/patients.html), [roles/staff/patient-hub.html](../roles/staff/patient-hub.html)

**Aliran ringkas:**
1. Pengguna kemaskini peribadi/alamat/kenalan kecemasan.
2. **Decision:** Maklumat sensitif (IC/alamat)? → barisan semakan Admin.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Asas patient + KYC extra + proxy | `step2`, `step15`, `step29` |
| ✅ | Alamat menetap + medan peribadi | `step_patient_address_residence`, `step_profile_personal_fields` |
| ✅ | Lajur hilang ditambah | `step_patients_missing_columns.sql` |
| ✅ | Sync KYC → patients | `step19_kyc_patients_sync.sql` |
| ✅ | Profile page patient + staff | `profile.html` (kedua-dua) |
| ✅ | Patients list + search + hub | `patients.html`, `patient-hub.html` (`step_patient_hub_v2`) |

---

## Modul 21 — Pengurusan Staf & Peranan

**Penerangan:** Admin/Pengurusan cipta akaun staf + assign peranan + RLS.

**Peranan:** Admin, Pengurusan

**Halaman:** [roles/staff/staff_management.html](../roles/staff/staff_management.html), [roles/staff/staff-detail.html](../roles/staff/staff-detail.html), [roles/staff/staff-stats.html](../roles/staff/staff-stats.html)

**Aliran ringkas:**
1. Admin cipta akaun → assign peranan (Coach/Doktor/Hakeema/dll).
2. RLS policy auto-apply.
3. Berhenti → soft-delete (FK pesakit tak terjejas).

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Profiles asas + peranan staf + Doktor | `step1`, `step11`, `step14` |
| ✅ | Soft-delete | `step20_soft_delete.sql` |
| ✅ | RLS staf | `fix_staff_rls.sql`, `fix_staff_delete_fk.sql` |
| ✅ | Assign peranan (24 Mei 2026) | `assign_staff_roles_240526.sql` |
| ✅ | Staff management UI | `staff_management.html`, `staff-detail.html`, `staff-stats.html` |

---

## Modul 22 — Log Audit

**Penerangan:** Setiap tindakan kritikal direkod kekal.

**Peranan:** Admin, Pengurusan

**Halaman:** [roles/staff/audit.html](../roles/staff/audit.html)

**Aliran ringkas:**
1. Trigger auto-catat setiap edit/padam/ubah peranan ke `audit_log`.
2. Admin/Pengurusan tapis log ikut tarikh/staf/tindakan untuk siasatan.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Audit log + trigger | `step3_audit.sql` |
| ✅ | RLS policy audit | `fix_audit_policy.sql` |
| ✅ | Audit UI | `audit.html` |
| ✅ | Kod rujukan unik | `step18_reference_code.sql` |

---

## Modul 23 — Analitik, Hasil Rawatan & Tadbir Urus

**Penerangan:** Dashboard Pengurusan untuk outcome, kepatuhan, risk, coach performance.

**Peranan:** Pengurusan, Admin, Coach

**Halaman:** [roles/staff/governance.html](../roles/staff/governance.html), [roles/staff/risk.html](../roles/staff/risk.html), [roles/staff/kepatuhan.html](../roles/staff/kepatuhan.html), [roles/staff/pakej-laporan.html](../roles/staff/pakej-laporan.html), [roles/staff/pakej-report.html](../roles/staff/pakej-report.html)

**Aliran ringkas:**
1. Sistem agregat data M1–M22 ke dashboard.
2. Pengurusan tapis (outcome/pakej/penyakit/umur/jantina/negeri/minggu).
3. Risk alert → notif Coach untuk follow-up.
4. Eksport laporan berkala.

**Checklist:**
| Status | Item | Note |
|:------:|------|------|
| ✅ | Outcome status (OTW/berhenti/meninggal) | `step30_outcome_status.sql` |
| ✅ | Kategori pakej | `step50_package_categories.sql` |
| ✅ | Governance + Risk dashboard | `governance.html`, `risk.html` |
| ✅ | Pakej laporan + report | `pakej-laporan.html`, `pakej-report.html` |
| 🟡 | Filter dashboard lanjutan (penyakit/umur/jantina/negeri) | Partial |
| 🟡 | Coach performance per-coach | `staff-stats.html` umum sahaja |
| 🔴 | Compare progress fasa 1 (BP, HbA1c) | Belum siap |
| 🔴 | Auto-summary check-in (graf/pie chart) | Belum siap |
| 🔴 | Analitik berjemur/watermelon/batu panas | Belum siap |
| ⛔ | Kepatuhan kategori OB A/B/C | Tunggu Meeting Izzah 26 Mei |
| ⛔ | Risk alert kriteria + threshold | Tunggu Meeting Izzah 26 Mei |

---

## Matriks Modul-ke-Peranan

| Modul | Pesakit | Closer | Coach | Pakar | Admin | Kewangan | Pengurusan |
|-------|:------:|:------:|:-----:|:-----:|:-----:|:-------:|:----------:|
| 0. Foundation | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 1. Onboarding | ✓ | ✓ |  |  | ✓ |  |  |
| 2. KOB | ✓ |  | ✓ | ✓ | ✓ |  |  |
| 3. Persetujuan | ✓ |  |  |  | ✓ |  |  |
| 4. Setup Pakej | ✓ |  | ✓ |  | ✓ |  |  |
| 5. Temujanji | ✓ |  | ✓ |  | ✓ |  |  |
| 6. Check-in | ✓ |  | ✓ |  |  |  |  |
| 7. Rutin | ✓ |  | ✓ |  |  |  |  |
| 8. Vital | ✓ |  | ✓ | ✓ |  |  |  |
| 9. Inventori | ✓ |  |  |  | ✓ | ✓ |  |
| 10. Coaching |  |  | ✓ | ✓ |  |  |  |
| 11. Katalog |  |  | ✓ |  | ✓ |  |  |
| 12. Tugasan | ✓ |  | ✓ |  |  |  |  |
| 13. Library | ✓ |  |  |  | ✓ |  |  |
| 14. Komunikasi | ✓ |  | ✓ |  | ✓ |  |  |
| 15. Surat & Isu | ✓ |  | ✓ |  | ✓ |  |  |
| 16. Kewangan | ✓ |  |  |  | ✓ | ✓ |  |
| 17. Kedai | ✓ |  |  |  | ✓ | ✓ |  |
| 18. Pengumuman | ✓ |  | ✓ |  | ✓ |  |  |
| 19. Penglibatan | ✓ |  | ✓ |  | ✓ |  |  |
| 20. Profil | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 21. Staf |  |  |  |  | ✓ |  | ✓ |
| 22. Audit |  |  |  |  | ✓ |  | ✓ |
| 23. Analitik |  |  | ✓ |  | ✓ |  | ✓ |

---

## Ringkasan Status Keseluruhan

| Status | Bilangan (anggaran) |
|--------|:--------:|
| ✅ Done | **~110** |
| 🟡 Partial | **~10** |
| 🟠 Schema ready, UI belum | **~6** |
| 🔴 Pending | **~35** |
| ⛔ Blocked (external) | **~6** |

---

## Prioriti Go-Live (per Syafa)

| Pri | Item | Status |
|:---:|------|--------|
| 1 | KYC | ✅ Done |
| 2 | GHL integration | ⛔ Blocked |
| 3 | Product description | 🟡 Partial |
| 4 | Notification system | 🟡 In-app done, external pending |
| 5 | Adherence checklist | ⛔ Tunggu Izzah |
| 6 | Schedule locking | ✅ Done |
| 7 | Governance dashboard | 🟡 Partial |

---

## Item Tersekat (Blocked)

| Item | Tunggu |
|------|--------|
| GHL integration (closer, WhatsApp, KYC sync) | API key + access |
| WhatsApp Business API | API key + business verification |
| SQL Accounting connect | Integration spec |
| Kepatuhan kategori OB A/B/C | Meeting Izzah 26 Mei 2026 |
| Risk alert kriteria + threshold | Meeting Izzah 26 Mei 2026 |
| ChatGPT/Whisper API (voice transcribe) | Akaun & key |

---

## Boleh Proceed Sekarang (Tanpa Blocker)

- Content upload library (video testimoni, diet umrah/haji, SOP Madu Ramadhan, video OB)
- Daily check-in extension (emosi + reaksi pemulihan)
- Kaunselor / Hakeem / Physiotherapist module foundation
- Reward / star system + cabutan bertuah
- Module Hakeema basic (booking + notes, voice/AI later)
- Disclaimer motivasi
- Welcome video / lokasi page
- Aggregator inventori auto-calc + cron auto-PO
- Enforcement library lock ikut pakej
- Pakej upgrade/downgrade/add-on flow
- Reminder system (jadual cron, tanpa WhatsApp pun boleh)
- Graf trend BP/HbA1c
- AI chatbot FAQ basic

---

## Perlu AI / Integration Partner

- **WhatsApp Business API** — auto reminder, invoice, mesej
- **ChatGPT/Whisper API** — voice transcribe, AI chatbot FAQ
- **GHL webhook** — closer flow + KYC sync
- **SQL Accounting** — recurring payment + reconciliation

---

## Bilangan Halaman & Fail Siap (Codebase Audit)

| Komponen | Bilangan |
|----------|:--------:|
| Halaman patient | **24** (`roles/patient/*.html`) |
| Halaman staff | **56** (`roles/staff/*.html`) |
| Halaman auth | **3** (`auth/login.html`, `reset.html`, `set-password.html`) |
| Fail shared JS | **10** (`shared/*.js`) |
| Migrasi DB | **80+** (step1–step51, step_*, fix_*, seed_*) |
| Template PDF agreement | **12** (`Agreement/`) |
| Template surat | **7** (`letterTemplates.js`) + RELA DOCX/PDF |

---


**Tamat dokumen.**
