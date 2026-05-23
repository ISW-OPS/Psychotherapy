# ISW — Flow Lengkap Semua Role

Dokumentasi flow lengkap setiap modul untuk setiap role dalam sistem.

## 📋 Senarai Kandungan

1. **[PATIENT](#1-patient-flows)** — signup, KYC, KOB, plan, check-in, shop, dll (18 flow)
2. **[ADMIN](#2-admin-flows)** — pesakit, pakej, produk, inventori, surat, staff (17 flow)
3. **[COACH](#3-coach-flows)** — assignments, weekly plan, plan-week, nota, vitals (8 flow)
4. **[DOCTOR](#4-doctor-flows)** — KOB session, questionnaire, prescribe pakej, SOAP (7 flow)
5. **[MANAGER](#5-manager-flows)** — approvals, reports, governance, closures (6 flow)

**Status legend:** `DONE` ✅ • `PARTIAL` 🟡 • `PENDING` 🔴

---

## 1. PATIENT FLOWS

### A. Signup & Onboarding

#### 1.1 Signup Akaun `DONE`
```
Patient buka login.html → tab Daftar
  • Nama Penuh
  • Email
  • Password (min 6 aksara)
  ↓
auth.users created
  ↓
TRIGGER handle_new_user() fires:
  → INSERT psy_profiles (role='patient')
  ↓
Email verification sent (kalau Supabase auth setup verify)
  ↓
Patient login → cek auto-link by email:
  • Match staff-created record → claim + skip KYC
  • Tiada match → mula KYC flow
```

#### 1.2 KYC (Stage 1 KOB) `DONE`
```
Patient buka kob.html (kob_status='paid', stage='kyc')
  ↓
Isi borang lengkap:
  • IC, nama, tarikh lahir, jantina
  • Telefon, email, alamat
  • Marital status, occupation, company
  • Waris (nama, IC, phone, email, hubungan)
  • Masalah kesihatan (checkbox + Lain-lain)
  • Insurance info (optional)
  • Upload IC + dokumen sokongan
  • Consent: data, health records, research, marketing
  • Tick "saya bukan wakil" (atau submitted_by_proxy=true)
  ↓
Submit:
  → INSERT psy_kyc_submissions (status='approved' kalau staff-created)
  → INSERT/UPDATE psy_patients
  → UPDATE kob_status='kyc_done'
```

#### 1.3 Tempah Slot KOB (Stage 2) `DONE`
```
Patient buka kob.html stage='book'
  ↓
Pilih mod: F2F di Klinik / Online
  ↓
Pilih tarikh (block Isnin & Selasa + cuti klinik)
  ↓
Pilih slot waktu dari psy_kob_slot_config
  (4 slot: 8.30-10am, 10.30-12pm, 2-3.30pm, 3.30-5pm)
  ↓
Klik Tempah:
  → INSERT psy_kob_sessions (status='booked')
  → UPDATE patient kob_status='booked'
  ↓
Stage 'booked' tunjuk:
  • Tarikh, masa, mod
  • Butang Reschedule
  • Sertai Online (kalau mode='online')
```

#### 1.4 Hadir KOB (Stage 3) `DONE`
```
Doktor di kob-detail.html tekan "Hadir":
  → UPDATE psy_kob_sessions status='hadir'
  → UPDATE patient kob_status='hadir'
  ↓
Patient page tunjuk:
  "Sesi KOB Sedang Berlangsung"
  "Sila tunggu doktor selesai menilai..."
  ↓
[Background] Doktor isi:
  • Questionnaire (anak, tidur, gaya hidup, masalah kesihatan)
  • Vitals (BP, HR, BMI, dll)
  • SOAP notes (private — patient tak nampak)
```

#### 1.5 Pakej Disyorkan + Bayar (Stage 4) `DONE`
```
Doktor pilih pakej:
  → UPDATE psy_kob_sessions:
    • recommended_package_id, name, price
    • recommended_by, recommended_at
  → UPDATE patient kob_status='package_recommended'
  ↓
Patient nampak "Pakej Disyorkan":
  • Detail pakej
  • Harga
  • Butang "Bayar Sekarang"
  ↓
Patient bayar (FPX/card/transfer/manual):
  → INSERT psy_payments
  → UPDATE psy_kob_sessions:
    • package_payment_status='paid'
    • package_paid_at, package_receipt_ref
  → UPDATE patient kob_status='package_paid'
```

#### 1.6 Sign Agreement (Stage 5) `DONE`
```
Patient baca agreement clauses dari pakej
  (psy_packages.agreement_clauses JSONB)
  ↓
Lukis signature dalam canvas:
  • Tick "Saya bersetuju"
  • Draw signature
  ↓
Submit:
  → Upload PNG ke storage 'kob-signatures'
  → Generate signed PDF (pdf-lib)
  → Upload PDF ke storage
  → INSERT psy_kob_agreements:
    • signature_url, signed_pdf_url
    • patient_name, patient_ic
    • agreement_version
  ⛔ STATUS BERHENTI — tunggu doktor
```

#### 1.7 Selesai (Stage 6) — Doctor Confirm `DONE`
```
Doktor tekan "Tandakan Selesai":
  → UPDATE psy_kob_sessions status='completed'
  → UPDATE psy_patients:
    • kob_status='completed'
    • active_package_id, active_package_name
    • package_purchased_at, package_expires_at
  → INSERT psy_package_purchases
  → 🔥 AUTO-CIPTA psy_treatment_plans:
    • name, duration_weeks, current_week=1
    • bio/psycho/social/spiritual_goals dari pakej
    • coaching_schedule dari pakej
    • status='active'
  ↓
Patient page: "Tahniah! KOB selesai 🎉"
Auto-redirect ke plan.html
```

### B. Treatment Plan

#### 1.8 Setup Jadual Rawatan (Wizard) `DONE`
```
Patient buka plan.html pertama kali
  ↓
Detect: schedule_setup_at IS NULL → tunjuk WIZARD
  ↓
Wizard:
  1. Pilih pasangan hari: Jumaat+Sabtu / Sabtu+Ahad
  2. Pilih jam hari pertama (cth 10:00 AM)
  3. Pilih jam hari kedua (cth 10:00 AM)
  ↓
Preview 3 minggu pertama
  ↓
Klik "Sahkan & Auto-Jadual 24 Sesi":
  → UPDATE plan dengan preferred_pair + masa
  → generateScheduleDates(): 12 minggu × 2 sesi
  → INSERT 24 rows psy_plan_weekly_progress
    (status='booked' atau 'reschedule' kalau cuti)
```

#### 1.9 View Progress + Reschedule Sesi `DONE`
```
plan.html tunjuk 12 minggu × 2 sesi
  ↓
Setiap kad sesi ada:
  • Tarikh + masa
  • Status pill (Ditempah/Hadir/Selesai)
  • Butang Reschedule (kalau status=booked)
  ↓
Klik Reschedule:
  • Modal pilih tarikh + masa baru
  • Validate: bukan cuti, dalam tempoh plan
  ↓
Sahkan:
  → UPDATE psy_plan_weekly_progress
    (session_date baru, status='booked')
```

#### 1.10 Miss Sesi → Bayar Extension Week `DONE`
```
Tarikh sesi dah lepas, status masih 'booked'
  ↓
loadWeeklyProgress() fires autoMarkMissedAndExtend():
  → Tanda semua missed sesi 'cancel'
  → Group ikut minggu asal
  → Cipta 1 extension week baru (2 sesi, day1+day2)
    • status='extension_pending_payment'
    • extension_price = pakej.extension_price_per_week (RM 50)
  → Notifikasi: "Bayar RM 50 untuk lanjut"
  ↓
Patient klik notifikasi → payment.html
  ↓
Bayar:
  → UPDATE status='extension_paid'
  → Patient boleh tempah tarikh baru untuk extension week
```

### C. Daily Activities

#### 1.11 Daily Check-in `DONE`
```
Patient buka checkin.html (sekali sehari)
  ↓
Isi:
  • Mood (1-10), Energy (1-10), Sleep quality (1-10)
  • Jam tidur
  • Madu count (target = pakej.madu_frequency_per_day)
  • Simptom (multi-select)
  • Aktiviti (multi-select)
  • Nota
  ↓
Save:
  → UPSERT psy_daily_checkins (UNIQUE patient_id + checkin_date)
```

#### 1.12 Jadual Harian (Routine) `DONE`
```
Patient buka routine.html
  ↓
Render psy_packages.daily_schedule (atau patient-customized)
Cth OB schedule:
  06:15 Zikir bersanad
  06:30 Minum madu LTHPG
  07:30 Minum madu LTH
  07:45 Berjemur + terapi bumi + pernafasan
  ... (20+ items sehari)
  ↓
Tick checkbox bila siap setiap item:
  → INSERT psy_daily_completions
    (UNIQUE patient_id + log_date + item_time)
```

#### 1.13 Update Vitals Sendiri (Bacaan Saya) `DONE`
```
Patient buka vitals.html
  ↓
4 stat cards: BP, Berat, BMI, HbA1c (terkini)
Sejarah table (sumber: Staf / Sendiri)
  ↓
Klik "+ Catat Bacaan Sendiri":
  • Tarikh
  • BP sistolik/diastolik, Nadi
  • Berat, RBS, HbA1c
  • Nota
  ↓
Save:
  → INSERT psy_vitals
    (source='patient_self', auto-tag plan_id + week_number)
```

### D. Shop & Orders

#### 1.14 Beli Produk → Order → Tracking `PARTIAL`
```
Patient buka shop.html
  ↓
SELECT psy_products + JOIN inv:inventory_item_id
  • Tunjuk visible_in_shop=true + status='active'
  • Live stock dari psy_inventory_items.qty_in_stock
  • Promo price kalau promo_until belum tamat
  ↓
Add to cart → Checkout (payment.html)
  ↓
INSERT psy_orders (status='pending')
  ↓
Bayar:
  → INSERT psy_payments
  → UPDATE psy_orders status='paid'
  → 🔥 TRIGGER auto-deduct psy_inventory_items.qty_in_stock
  ↓
Admin di orders.html:
  • UPDATE status='packed' → 'shipped' (tambah tracking)
  ↓
Patient di orders.html:
  • Track delivery
  • Klik "Telah Diterima" → status='delivered'
─── Belum: auto-email invoice ───
```

### E. Patient Tools

#### 1.15 Pulangan Botol Madu `DONE`
```
Patient buka pulangan.html
  ↓
Tick criteria (semua mesti true):
  ☐ Tidak berkarat
  ☐ Bersih
  ☐ Getah ada
  ☐ Besi kemas
  ↓
Upload gambar bukti (multiple)
  ↓
Isi qty + nota
  ↓
Submit:
  → INSERT psy_bottle_returns (status='pending')
  ↓
Admin verify → UPDATE status='received' atau 'rejected'
```

#### 1.16 Submit Issue (Barang Rosak/Salah) `DONE`
```
Patient buka issue.html → New Issue
  • Title, description, category
  • Upload gambar bukti
  ↓
Submit → INSERT psy_issues + audit log
  ↓
Admin di issue.html → reply, resolve, close
```

#### 1.17 Request Surat Rasmi `DONE`
```
Patient buka surat.html
  ↓
Pilih template (KWSP/PERKESO/RELA/dll)
  ↓
Isi reason + field tambahan
  ↓
Submit:
  → INSERT psy_letter_requests (status='pending')
  ↓
Admin terima → fill template → sign → generate PDF
  → INSERT psy_letter_issued
  ↓
Patient terima notifikasi → download PDF
```

#### 1.18 Upload Medical Report `DONE`
```
Patient buka medical-reports section
  ↓
Upload (PDF / image): X-Ray, MRI, blood test, dll
  → Upload ke storage 'medical-reports'
  → INSERT psy_medical_reports
    (report_type, title, status='pending')
  ↓
Doktor review → UPDATE doctor_review, review_status
```

---

## 2. ADMIN FLOWS

### A. Pengurusan Pesakit

#### 2.1 Tambah Pesakit (3 Jenis) `DONE`
```
Admin buka patients.html → "+ Tambah Pesakit"
  ↓
Pilih jenis:
  • Pesakit Baru — full KYC + KOB flow
  • Sedang Dalam Rawatan — sudah ada pakej, migrate
  • Pesakit Lama — rekod sejarah sahaja
  ↓
Isi maklumat:
  • Nama, IC, email, telefon
  • Alamat, status perkahwinan, occupation
  • Waris (nama, IC, phone, email, hubungan)
  • Masalah kesihatan
  • Pakej (kalau ada) + tarikh mula
  • Minggu Semasa (kalau "Sedang Dalam Rawatan")
  ↓
Simpan:
  → INSERT psy_patients (created_by_staff=true)
  → INSERT psy_package_purchases (kalau ada pakej)
  → AUTO-CIPTA psy_treatment_plans + 12 row weekly progress
    (kalau jenis "Sedang Dalam Rawatan")
  → INSERT psy_kyc_submissions (kalau jenis "Baru")
  → INSERT psy_kob_sessions (kalau check Tempah KOB sekali)
  ↓
Auto-link bila patient signup pakai email sama
```

#### 2.2 Edit Pesakit / Tambah Pakej `DONE`
```
Admin buka patients.html → klik Edit ATAU
patient-hub.html → klik "Edit Pesakit"
  ↓
Modal pre-fill dengan data sedia ada
  ↓
Ubah pakej + minggu semasa
  ↓
Simpan:
  → UPDATE psy_patients
  → INSERT psy_package_purchases (kalau pakej baru)
  → AUTO-CIPTA psy_treatment_plans (kalau belum ada)
  → Seed 12 row weekly progress
  → Audit log 'plan.staff_seeded_on_edit'
```

#### 2.3 Review KYC Submissions `DONE`
```
Admin buka kyc-list.html
  ↓
Senarai psy_kyc_submissions (status='pending')
  ↓
Klik review → kyc-review.html
  • Tengok semua jawapan
  • Tengok dokumen upload
  ↓
Aksi:
  • Approved → UPDATE status='approved', INSERT/UPDATE psy_patients
  • Rejected → UPDATE status='rejected' + review_notes
  • Needs Docs → UPDATE status='needs_docs'
```

### B. Pakej Rawatan

#### 2.4 Tambah / Edit Pakej Rawatan `DONE`
```
Admin buka pakej.html → "+ Tambah Pakej"
  ↓
Buka pakej-edit.html:
  • Maklumat Asas: Nama, Pakej ID, Harga, Tempoh (Minggu/Hari)
  • Sessions per week (1/2/3) + pilihan hari variant
  • Bilangan sesi seminggu (OB=2, OBG=1, 777=daily)
  • Tier (kategori)
  • Gambar pakej
  • Madu frequency per day
  • Online lock from week
  • Extension price per week
  • Coaching schedule (per minggu/hari):
    - Guidance / Bimbingan (link catalog)
    - Aktiviti
    - Supplies (link inventory items + kits)
    - Mode (F2F / Online / Both)
    - Rujukan files (upload PDF)
  • BPS-S goals (Bio, Psycho, Social, Spiritual)
  • Daily schedule template
  • Agreement clauses + version
  • Automation flags (whatsapp_weekly, reminder, dll)
  ↓
Simpan:
  → INSERT/UPDATE psy_packages
  → Audit log 'package.created' / 'package.updated'
```

### C. Produk Shop

#### 2.5 Tambah / Edit Produk `DONE`
```
Admin buka products.html → "+ Tambah Produk"
  ↓
Buka product-edit.html:
  • Maklumat Asas:
    - Nama, SKU, Kategori, Jenama
    - Status (active/inactive/draft)
    - Penerangan ringkas + penuh
  • Harga & Jualan:
    - Harga jualan (RM)
    - Harga promo + tarikh tamat
  • Stok & Inventori:
    - Stok semasa, Min stock, Unit
    - Track inventory toggle
    - Low stock alert toggle
    - Link inventory_item_id (auto-deduct on order paid)
  • Media:
    - image_url (single primary image)
  • Butiran:
    - Weight/size, Supplier, Tags, Notes
  • Visibility:
    - visible_in_shop, featured, online_purchase
  ↓
Simpan:
  → INSERT/UPDATE psy_products
  → Audit log 'product.created' / 'product.updated'
```

### D. Inventori

#### 2.6 Tambah Item Inventori `DONE`
```
Admin buka inventory.html → "+ Tambah Item"
  ↓
Modal:
  • Nama item
  • Kategori (Madu/Starter Kit/Suplemen/Buku/dll)
  • Unit (kg, botol, naskhah, unit, set, biji)
  • Qty in stock (initial)
  • Min qty (alert threshold)
  • Max qty (untuk auto-PO calculation)
  • Auto reorder enabled (toggle)
  • Auto reorder qty (cadangan PO)
  • Requires approval (toggle)
  • Consumption type (package/service/general)
  • Supplier info (JSONB: name, cost, lead_days, po_min/max)
  • Notes
  ↓
Simpan → INSERT psy_inventory_items
```

#### 2.7 Adjust Stok Inventori `DONE`
```
Admin buka inventory.html → klik item
  ↓
Modal "Laras Stok":
  • Qty masuk / keluar / set
  • Reason / catatan
  ↓
Save:
  → UPDATE psy_inventory_items.qty_in_stock
  → Audit log 'inventory.adjust'
```

#### 2.8 Inventory Request (Manual / Auto) `DONE`
```
Staff mohon item baru:
  → INSERT psy_inventory_requests
    (status='pending_approval')
  ↓
Admin/Manager review:
  • Approve → UPDATE status='approved'
  • Reject → UPDATE status='rejected' + reason
  ↓
Bila beli & sampai:
  → UPDATE status='purchased'
  → Adjust stok auto
```

#### 2.9 Tambah Kit Prosedur `DONE`
```
Admin buka kit-prosedur.html → "+ Tambah Kit"
  ↓
kit-edit.html:
  • Nama kit (cth: "IV Drip Setup")
  • Description, category
  • Items (multi-select dari psy_inventory_items):
    - Per item: item_name, qty, unit
  ↓
Simpan → INSERT psy_procedure_kits
  ↓
Bila pakej guna kit dalam supplies → auto-expand
ke semua sub-items dalam kit
```

### E. Kalendar & Slot

#### 2.10 Setup Slot Klinik `DONE`
```
Admin buka kob-slots.html
  ↓
Setup slot template per hari (Rab-Ahd):
  • Slot type: kob / rawatan
  • Time slots: 7-9am, 9.30-11.30am, 2-4pm, 4.30-6.30pm, dll
  • Toggle is_active
  ↓
UPDATE psy_kob_slot_config
  ↓
Override per-date:
  • Lock / unlock specific slot for specific date
  → INSERT psy_slot_date_overrides
```

#### 2.11 Tambah Cuti Klinik `DONE`
```
Admin buka closures.html → "+ Tambah Cuti"
  ↓
Modal:
  • Tarikh cuti
  • Label (cth: "Hari Raya Aidilfitri")
  • Category (public_holiday/hari_raya/clinic_closed/training)
  • Recurring (annual) toggle
  • Notes
  ↓
Simpan → INSERT psy_clinic_closures
  ↓
Booking auto-block tarikh ni
```

### F. Komunikasi & Kandungan

#### 2.12 Tambah Pengumuman `DONE`
```
Admin buka announcements.html → "+ Tambah"
  ↓
Modal:
  • Title, body
  • Tag (Promosi/Kelas/Challenge/dll)
  • Background gradient
  • CTA label + URL
  • Tempoh aktif (starts_at / ends_at)
  ↓
INSERT psy_announcements
  ↓
Patient dashboard tunjuk announcement aktif
```

#### 2.13 Tambah Library Item (Self-Help) `DONE`
```
Admin buka library.html → "+ Tambah"
  ↓
library-edit.html:
  • Title, description, content body
  • Content type (Video/Article/Audio/Worksheet)
  • Content URL (link) atau upload
  • Thumbnail
  • Category, icon, gradient
  • Package filter (psy_packages.package_id array)
    - Empty = public, ada = restricted
  ↓
INSERT psy_library_items
  ↓
Patient library.html paparkan yang accessible
```

#### 2.14 Manage Templates Surat `DONE`
```
Admin buka surat.html → "Templates"
  ↓
List 7 template hardcoded (KWSP, PERKESO, RELA, dll)
  ↓
Boleh override template:
  • Edit body HTML
  • Edit fields (key, label, type, autofill)
  → INSERT/UPDATE psy_letter_template_overrides
  ↓
Manage Auto-Fields:
  • Key (cth [BMI])
  • Label, Source (patient/staff/system)
  • Data path (column name)
  → INSERT psy_letter_auto_fields
```

#### 2.15 Generate Surat untuk Pesakit `DONE`
```
Admin buka patient-hub → klik "Generate Surat"
ATAU buka surat-issue.html
  ↓
Pilih template + patient
  ↓
Field auto-fill dari psy_letter_auto_fields:
  • [NAMA], [IC], [ALAMAT], [PAKEJ], dll
  ↓
Isi field manual (kalau ada)
  ↓
Preview HTML → klik Sign
  ↓
Generate PDF (pdf-lib):
  → INSERT psy_letter_issued
    (signed_by, ref_number, file_url)
  ↓
Patient terima notifikasi → download PDF
```

### G. Staff & Sistem

#### 2.16 Manage Staff (Add/Edit/Delete) `DONE`
```
Admin buka staff_management.html
  ↓
List psy_profiles (role='staff')
  ↓
"+ Tambah Staff":
  • Staff ID (registration_no)
  • Nama, Email
  • Pilihan: Email invite ATAU Set password
  • Staff role (admin/doctor/coach/manager)
  ↓
Edge function 'invite-staff' fires:
  → Cipta auth.users
  → INSERT psy_profiles (role='staff', staff_role)
  ↓
Edit staff → staff-detail.html
Delete → edge function 'invite-staff' delete action
```

#### 2.17 View Reports & Audit `DONE`
```
Pages tersedia:
  • governance.html — overall KPI
  • staff-stats.html — staff performance
  • pakej-laporan.html — pakej analytics
  • audit.html — semua activity log
    (dengan UUID → nama resolver)
  ↓
Filter ikut tempoh, jenis tindakan, modul, pengguna
Export CSV / Excel / Print
```

---

## 3. COACH FLOWS

#### 3.1 Login → Dashboard Coach `DONE`
```
Coach login → dashboard.html
  ↓
View:
  • Pesakit Di Bawah Coach (caseload count)
  • Check-in 7 Hari (% caseload)
  • Low Compliance count
  • Sesi Hari Ini
  • Reaksi Pemulihan (greyed — modul belum)
  ↓
Sections:
  • Pesakit Saya (table dengan link patient hub)
  • Jadual Mingguan (sesi minggu ni)
  • Pesakit Perlu Tindakan Segera (greyed — tunggu Izzah)
  • Trend Kepatuhan (greyed — tunggu Izzah)
  • Sesi 1:1 Hakeema (greyed — modul belum)
  • Quick Actions (greyed — no messaging yet)
```

#### 3.2 Senarai Patients (Assignments) `DONE`
```
Coach buka assignments.html ("Patients")
  ↓
3 tab:
  • Belum Ditugaskan — pesakit tanpa coach
  • Semua Pesakit — semua dalam sistem
  • Pesakit Saya — coach_id = me
  ↓
Filter: status, pakej, outcome, signup
  ↓
Aksi per row:
  • "Assign to me" — UPDATE coach_id=me
  • "Lihat" → patient-hub.html
  • "Unassign" — coach sendiri / admin
  ↓
KYC pending → package & risk columns "Menunggu KYC"
```

#### 3.3 Open Patient Hub `DONE`
```
Coach klik "Lihat" / Details
  ↓
patient-hub.html buka — 7 tab:
  • Overview — stats, Progress Mingguan, Pakej Aktif
  • Check-in — daily check-in history
  • Vitals — BP/HR/BMI history + record new
  • Sesi — coaching sessions
  • Bekalan — supplies status
  • Laporan — medical reports
  • Profil & Dokumen — KYC, IC, dll
  ↓
Edit nota per minggu:
  • Klik kad minggu di Progress Mingguan
  → buka plan-week.html?plan_id=X&week=N
```

#### 3.4 Edit Plan Week (Nota Coach) `DONE`
```
plan-week.html buka untuk minggu N
  ↓
Edit:
  • Status kehadiran (Hadir / Reschedule / Tidak Hadir)
  • Tarikh & masa sesi
  • Score (0-10)
  • Nota minggu ini
  • Kepatuhan Rawatan (madu, nafas, terapi bumi, dll)
  • Coaching checklist (guidance + supplies)
  ↓
Auto-save:
  → UPDATE psy_plan_weekly_progress
  → UPDATE psy_plan_compliance
  ↓
Hadir → 🔥 Auto-deduct supplies dari inventory
```

#### 3.5 Record Vitals (Patient Hub) `DONE`
```
Patient hub → tab Vitals → "+ Rekod Vitals Baru"
  ↓
Modal:
  • BP sistolik/diastolik, HR
  • Berat, tinggi, suhu
  • RBS, HbA1c
  • PHQ2 score (optional)
  • Nota
  ↓
Save:
  → INSERT psy_vitals
    (source='staff', auto-tag plan_id + week_number)
```

#### 3.6 Weekly Plan Calendar (Coach View) `DONE`
```
Coach buka weekly-plan.html
  ↓
Hero: profil coach + caseload count
  ↓
Stats: Sesi Dirancang / Disahkan / Menunggu / Dibatalkan
  ↓
Grid 7-hari (Isn-Ahd):
  • Card sesi per hari dengan:
    - Time + nama pesakit + Minggu N
    - Status pill
    - Source icon (📋 plan / 📅 appt / 🎯 coaching)
  ↓
Toggle Minggu/Hari view
Toggle Saya / Semua scope
Filter Status
```

#### 3.7 Manage Bottle Returns `DONE`
```
Coach/Admin buka pulangan.html
  ↓
List psy_bottle_returns (status='pending')
  ↓
Review:
  • Tengok gambar bukti
  • Tengok criteria_confirmed
  ↓
Aksi:
  • Received → UPDATE status='received'
  • Rejected → UPDATE status='rejected' + reason
```

#### 3.8 Manage Inventory (Read + Request) `DONE`
```
Coach buka inventory.html
  ↓
Read-only view:
  • Senarai item + stok semasa
  • Stok rendah highlighted
  ↓
"+ Request Item":
  → INSERT psy_inventory_requests (status='pending_approval')
  ↓
Tunggu Admin/Manager approve
```

---

## 4. DOCTOR FLOWS

#### 4.1 KOB List → Pick Session `DONE`
```
Doctor buka kob-list.html
  ↓
List psy_kob_sessions:
  • Sort by scheduled_at
  • Filter by status (booked/hadir/completed/dll)
  ↓
Klik session → kob-detail.html?id=X
```

#### 4.2 KOB Detail — Mark Hadir `DONE`
```
kob-detail.html buka untuk sesi
  ↓
Tunjuk:
  • Patient info (nama, IC, contact)
  • Scheduled at, mode
  • Status semasa
  ↓
Klik "Hadir":
  → UPDATE status='hadir'
  → doctor_hadir_id, hadir_at
  → UPDATE patient kob_status='hadir'
```

#### 4.3 Fill Questionnaire `DONE`
```
Questionnaire JSONB structure:
  • Anak (bilangan, umur)
  • Tidur (jam, kualiti)
  • Gaya hidup (senaman, makan, dll)
  • Masalah kesihatan detail
  ↓
Save → UPDATE psy_kob_sessions.questionnaire
  → Audit log 'kob.questionnaire_saved'
```

#### 4.4 Record Vitals (KOB) `DONE`
```
Dalam kob-detail.html, section Vitals
  ↓
Isi BP, HR, BMI, weight, height, dll
  ↓
Save → INSERT psy_vitals (source='staff')
```

#### 4.5 Add SOAP Notes (Private) `DONE`
```
consultation.html — doctor isi SOAP:
  • Subjective (apa patient cakap)
  • Objective (apa doctor nampak)
  • Assessment (diagnosis)
  • Plan (action plan)
  ↓
Save → INSERT psy_soap_notes
  • Patient TAK NAMPAK (RLS staff only)
```

#### 4.6 Recommend Pakej + Mark Selesai `DONE`
```
kob-detail.html → "Cadang Pakej":
  ↓
Pilih dari psy_packages
  → UPDATE psy_kob_sessions:
    • recommended_package_id, name, price
    • recommended_by, recommended_at
  → UPDATE patient kob_status='package_recommended'
  ↓
Patient bayar (via payment.html)
  → UPDATE package_payment_status='paid'
  ↓
Patient sign agreement
  → INSERT psy_kob_agreements
  ↓
Doctor klik "Tandakan Selesai":
  → UPDATE status='completed'
  → 🔥 Activate patient pakej (lihat 1.7)
```

#### 4.7 Upload Medical Report `DONE`
```
patient-hub → Laporan tab → "+ Upload"
  ↓
File picker (PDF/image)
  • Pilih report_type (dna/xray/ct/mri/blood/dll)
  • Title, summary, sample_date
  • Categories (JSONB key-value)
  ↓
Upload ke storage 'medical-reports'
  → INSERT psy_medical_reports
  ↓
Toggle "Share with patient" → patient nampak
```

---

## 5. MANAGER FLOWS

#### 5.1 Dashboard Manager `DONE`
```
Manager dashboard tunjuk:
  • Pesakit Aktif (count)
  • Sesi Tertunggak
  • Stok Rendah (count)
  • Pesanan Menunggu
  • Trend mingguan
  ↓
Quick links ke staff-stats, governance
```

#### 5.2 Approve Inventory Requests `DONE`
```
Manager buka inventory.html → tab "Requests"
  ↓
List psy_inventory_requests (status='pending_approval')
  ↓
Aksi:
  • Approve → UPDATE status='approved', approved_by, approved_at
  • Reject → UPDATE status='rejected', rejected_reason
  ↓
Bila purchasing siap beli:
  • UPDATE status='purchased', purchased_at
```

#### 5.3 Manage Closures Klinik `DONE`
```
Manager buka closures.html
  ↓
Same as Admin 2.11
  ↓
Lock tarikh-tarikh tertentu — booking auto-block
```

#### 5.4 View Staff Stats `DONE`
```
Manager buka staff-stats.html
  ↓
Tunjuk per-staff:
  • Sesi handle (count)
  • Patient assigned
  • Compliance rate
  ↓
Filter by tempoh, role
```

#### 5.5 Payment Admin `DONE`
```
Manager buka payment-admin.html
  ↓
List psy_payments + psy_orders
  ↓
Filter by status, tempoh
  ↓
Export reconciliation report
```

#### 5.6 Process Orders `DONE`
```
Manager buka orders.html
  ↓
List psy_orders by status:
  • Pending → Paid → Packed → Shipped → Delivered
  ↓
Aksi:
  • Mark packed → status='packed', packed_at
  • Add tracking → status='shipped', tracking_number, photo
  ↓
Patient confirm delivery → status='delivered'
```

---

**End of Flow Documentation**
ISW System — 22 Mei 2026
