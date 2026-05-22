# ISW Psychotherapy — System Flows

Flow keseluruhan untuk setiap modul utama. Format ASCII supaya boleh dibaca terus dalam editor / GitHub.

---

## 1. AUTH & ONBOARDING (Patient)

```
                    ┌──────────────────┐
                    │  Patient Sign-up │
                    │   (email + pwd)  │
                    └────────┬─────────┘
                             ▼
                    ┌──────────────────┐
                    │ psy_profiles row │
                    │ role = 'patient' │
                    └────────┬─────────┘
                             ▼
                    ┌──────────────────┐
                    │   Dashboard      │
                    │   (first login)  │
                    └────────┬─────────┘
                             ▼
                ┌────────────┴────────────┐
                ▼                         ▼
        ┌──────────────┐         ┌──────────────────┐
        │  KYC Form    │         │  KOB (Borang     │
        │              │         │  Onboarding)     │
        │ • Biodata    │         │  6 stages:       │
        │ • Health     │         │  1. Welcome      │
        │ • Allergies  │         │  2. Mode (F2F/   │
        │ • Emergency  │         │     Online)      │
        │ • Pewaris    │         │  3. Slot Pilihan │
        │   (proxy)    │         │  4. Pakej        │
        └──────┬───────┘         │  5. Agreement    │
               │                 │     + Sign       │
               │                 │  6. Done         │
               │                 └────────┬─────────┘
               │                          ▼
               │                 ┌──────────────────┐
               │                 │ psy_kob_sessions │
               │                 │ psy_kob_agreemts │
               │                 └──────────────────┘
               ▼
        ┌──────────────┐
        │ psy_kyc_     │
        │ submissions  │
        └──────────────┘
                                  ▼
                    ┌──────────────────────────┐
                    │ Staff Doctor: KYC List   │
                    │ Review → Approve         │
                    └────────┬─────────────────┘
                             ▼
                    ┌──────────────────────────┐
                    │ active_package_id set    │
                    │ → patient.kob_status =   │
                    │   'kyc_done'             │
                    └──────────────────────────┘
```

---

## 2. PAKEJ RAWATAN (Staff)

```
              ┌─────────────────────────┐
              │  Pakej Rawatan (List)   │
              └───────────┬─────────────┘
                          ▼
                  ┌───────────────┐
                  │ + Tambah Pakej│
                  │   atau Edit   │
                  └───────┬───────┘
                          ▼
              ┌─────────────────────────┐
              │   Edit Pakej Form       │
              │  1. Maklumat Asas       │
              │     • Nama, ID, harga   │
              │     • Tempoh (week/day) │
              │  2. Timeline Rawatan    │
              │     • M1, M2, ...       │
              │     • Bimbingan + Akti- │
              │       viti dari Catalog │
              │     • Bekalan (Invtori) │
              │     • Mode (F2F/Online) │
              │  3. Jadual Harian       │
              │  4. Kontrak Pakej       │
              │     • Default 29 klausa │
              │     • Auto-fill from PDF│
              │     • Edit klausa       │
              │  5. Tetapan Lanjutan    │
              │     • Gmeet, Extension  │
              └───────────┬─────────────┘
                          │ Save
                          ▼
              ┌─────────────────────────┐
              │  psy_packages           │
              │  + auto retry strip     │
              │    missing cols         │
              └───────────┬─────────────┘
                          ▼
              ┌─────────────────────────┐
              │  Pakej Detail page      │
              │  • Klausa modal         │
              │  • Coaching schedule    │
              │  • Bekalan summary      │
              │  • Kandungan library    │
              └─────────────────────────┘
```

---

## 3. INVENTORI ↔ PRODUK ↔ SHOP

```
                    ┌──────────────────────────────────┐
                    │       INVENTORI (Master)         │
                    │  Semua bekalan fizikal           │
                    └─────────────────┬────────────────┘
                                      │
                          ┌───────────┴───────────┐
                          ▼                       ▼
              ┌─────────────────────┐   ┌──────────────────┐
              │   + Tambah Item     │   │   ⚖ Laras Stok   │
              └──────────┬──────────┘   └────────┬─────────┘
                         ▼                       │
              ┌─────────────────────┐            │
              │ Keyin Details +     │            │
              │ Stock + Auto-PO     │            │
              └──────────┬──────────┘            │
                         ▼                       ▼
              ┌─────────────────────────────────────────┐
              │      psy_inventory_items (Save)         │
              └────────────────────┬────────────────────┘
                                   │
                  ┌────────────────┼────────────────┐
                  ▼                ▼                ▼
        ┌──────────────────┐ ┌───────────┐ ┌──────────────────┐
        │ Stok ≤ Min +     │ │ AUTO-SYNC │ │ List All         │
        │ Auto-PI Aktif?   │ │ ke Produk │ │ Inventori        │
        │  → ⚡ Triggered  │ │ (nama)    │ └──────────────────┘
        └──────────────────┘ └─────┬─────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────┐
                    │           PRODUK                 │
                    │  Subset Inventori utk jualan     │
                    └─────────────────┬────────────────┘
                                      ▼
                          ┌─────────────────────┐
                          │  + Tambah Produk    │
                          │  ⛔ Pilih Inventori  │
                          │     dulu (force)    │
                          └──────────┬──────────┘
                                     ▼
                          ┌─────────────────────┐
                          │ Picker Modal        │
                          │ • Sidebar kategori  │
                          │ • Card item         │
                          │ • Stok 0? BLOCK     │
                          │ • Dah jadi? BLOCK   │
                          └──────────┬──────────┘
                                     ▼
                          ┌─────────────────────┐
                          │ Form Prefilled      │
                          │ (Nama/Stok locked)  │
                          │ Set harga, gambar,  │
                          │ visibility          │
                          └──────────┬──────────┘
                                     │ Save
                                     ▼
                          ┌─────────────────────┐
                          │  psy_products       │
                          │  ► sync ke Invtori  │
                          └──────────┬──────────┘
                                     ▼
                          ┌─────────────────────┐
                          │   Patient Shop      │
                          │ • Card produk       │
                          │ • Stok 0? "Habis"   │
                          │ • Add to Cart       │
                          └─────────────────────┘
```

---

## 4. ORDER LIFECYCLE

```
        ┌─────────────────┐
        │ Patient: Cart   │
        │ + Add items     │
        └────────┬────────┘
                 ▼
        ┌─────────────────┐
        │  Checkout       │
        │  • Address      │
        │  • Delivery     │
        │  • Notes        │
        └────────┬────────┘
                 ▼
        ┌─────────────────┐
        │  Payment        │
        │  • FPX / Card   │
        │  • Bank xfer    │
        └────────┬────────┘
                 ▼
        ┌─────────────────┐     ┌──────────────────┐
        │  psy_orders     │ ──► │  Staff: Orders   │
        │  status='paid'  │     │  & Tracking      │
        └────────┬────────┘     └────────┬─────────┘
                                         ▼
                                ┌──────────────────┐
                                │ Mark 'packed'    │
                                └────────┬─────────┘
                                         ▼
                                ┌──────────────────────────┐
                                │ AUTO-DEDUCT:             │
                                │  Produk.stock −qty       │
                                │  + sync Inventori −qty   │
                                └────────┬─────────────────┘
                                         ▼
                                ┌──────────────────┐
                                │ Mark 'shipped'   │
                                │ + tracking no    │
                                └────────┬─────────┘
                                         ▼
                                ┌──────────────────┐
                                │ Patient confirm  │
                                │ 'delivered'      │
                                └──────────────────┘

   Cancel after 'packed' → AUTO-RESTOCK (Produk + Inventori +qty)
```

---

## 5. KOB → TREATMENT PLAN

```
        ┌─────────────────┐
        │ KOB Done        │
        │ kob_status =    │
        │ 'kyc_done'      │
        └────────┬────────┘
                 ▼
        ┌─────────────────────────────┐
        │ Staff: Generate Plan        │
        │ (auto / manual)             │
        │ Berdasarkan:                │
        │ • Pakej.duration_weeks      │
        │ • Pakej.coaching_schedule   │
        │ • Pakej.sessions_per_week   │
        │ • Hari klinik (skip cuti)   │
        └────────┬────────────────────┘
                 ▼
        ┌─────────────────────────────┐
        │  psy_treatment_plans        │
        │  psy_plan_weekly_progress   │
        │  (N rows = N weeks × sesi)  │
        └────────┬────────────────────┘
                 ▼
   ┌────────────────┴───────────────┐
   ▼                                ▼
┌──────────────────┐    ┌──────────────────────┐
│ Patient: plan.   │    │ Coach: weekly-plan,  │
│ html + plan-week │    │ plan-week.html       │
│  • View weeks    │    │  • Mark hadir/cancel │
│  • Reschedule    │    │  • Log notes         │
└────────┬─────────┘    │  • Auto-deduct stok  │
         ▼              └──────────────────────┘
┌──────────────────┐
│ Pick mode/day    │
│ Pilih session_   │
│ days_options     │
│ (variant)        │
└──────────────────┘
```

---

## 6. SESI HADIR → AUTO-DEDUCT

```
        ┌─────────────────────┐
        │ Coach: tanda 'hadir'│
        │ untuk sesi minggu N │
        └──────────┬──────────┘
                   ▼
        ┌─────────────────────┐
        │ psy_plan_weekly_    │
        │ progress.status =   │
        │ 'hadir'             │
        └──────────┬──────────┘
                   ▼
        ┌─────────────────────────────┐
        │ deductSessionSupplies()     │
        │ • Skip kalau Online         │
        │ • Skip kalau extension      │
        │ • Loop supplies week N      │
        │   (coaching_schedule[N])    │
        │ • Tolak qty_in_stock        │
        └──────────┬──────────────────┘
                   ▼
        ┌─────────────────────────────┐
        │ psy_audit_log               │
        │ action='inventory.auto_     │
        │         deducted'           │
        └──────────┬──────────────────┘
                   ▼
        ┌─────────────────────────────┐
        │ Banner: "📦 Bekalan ditolak:│
        │ Madu LTH −1botol, ..."      │
        │ + warning kalau stok rendah │
        └─────────────────────────────┘
```

---

## 7. AGREEMENT (KONTRAK PELABURAN KESIHATAN)

```
        ┌─────────────────────┐
        │ Pakej.agreement_    │
        │ clauses (29 default │
        │ + boleh override)   │
        └──────────┬──────────┘
                   ▼
        ┌─────────────────────┐
        │ Patient KOB Stage 5 │
        │ (Agreement)         │
        └──────────┬──────────┘
                   ▼
        ┌─────────────────────┐
        │ loadAgreementData() │
        │ • Default fallback  │
        │ • Override per pkg  │
        └──────────┬──────────┘
                   ▼
        ┌─────────────────────┐
        │ Render klausa list  │
        │ + signature canvas  │
        └──────────┬──────────┘
                   ▼
        ┌─────────────────────┐
        │ Patient sign        │
        │ + checkbox setuju   │
        └──────────┬──────────┘
                   ▼
        ┌─────────────────────────────┐
        │ generateSignedPdf()         │
        │ • pdf-lib draw klausa+sign  │
        │ • Upload to Supabase storage│
        │ • Save signed_pdf_url       │
        └──────────┬──────────────────┘
                   ▼
        ┌─────────────────────┐
        │ psy_kob_agreements  │
        │ + audit log         │
        └─────────────────────┘
```

---

## 8. KALENDAR & APPOINTMENTS

```
        ┌────────────────────┐
        │ Slot Konsultasi    │
        │ (kob-slots.html)   │
        │ Setting:           │
        │ • Slot mingguan    │
        │ • Cuti & override  │
        │ • Hari tutup       │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ psy_clinic_closures│
        │ + slot config      │
        └─────────┬──────────┘
                  ▼
    ┌─────────────┴─────────────┐
    ▼                           ▼
┌──────────────┐        ┌──────────────────┐
│ Patient KOB  │        │ Staff:           │
│ pick slot    │        │ appointments.html│
│ (filter:     │        │ • Daily view     │
│ closures)    │        │ • Weekly view    │
│              │        │ • Reschedule     │
└──────┬───────┘        └────────┬─────────┘
       ▼                         ▼
       ┌──────────────────────────┐
       │ psy_appointments         │
       │ psy_plan_weekly_progress │
       └──────────────────────────┘
```

---

## 9. DAILY CHECK-IN & VITALS

```
        ┌────────────────────┐
        │ Patient: Daily     │
        │ Check-in           │
        │ • Madu intake      │
        │ • Activity (jalan, │
        │   berjemur, dll)   │
        │ • Mood             │
        │ • Notes            │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ psy_daily_checkins │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ Calculate kepatuhan│
        │ • Madu compliance  │
        │ • Activity ratio   │
        │ • Adherence score  │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ Staff Dashboard:   │
        │ kepatuhan.html     │
        │ • Patient list     │
        │ • Risk alerts      │
        └────────────────────┘

        ┌────────────────────┐
        │ Patient: Vitals    │
        │ • BP / HbA1c       │
        │ • Update sendiri   │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ psy_vitals         │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ Staff: vitals.html │
        │ trend view (table) │
        └────────────────────┘
```

---

## 10. ISSUES / RETURNS / PULANGAN

```
        ┌────────────────────┐
        │ Patient: Report    │
        │ Issue              │
        │ • Damaged product  │
        │ • Wrong delivery   │
        │ • Upload gambar    │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ psy_issues         │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ Staff: issue-      │
        │ detail.html        │
        │ • Review           │
        │ • Replace order    │
        │ • Refund           │
        └────────────────────┘

        ┌────────────────────┐
        │ Patient: Pulangan  │
        │ Botol (madu empty) │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ Criteria validation│
        │ • Min bottles?     │
        │ • Pakej active?    │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ psy_bottle_returns │
        │ → Reward / credit  │
        └────────────────────┘
```

---

## 11. PAYMENT & FINANCE

```
        ┌────────────────────┐
        │ Source pembayaran: │
        │ • Pakej (Pelan     │
        │   Pelaburan Ansuran│
        │ • Shop order       │
        │ • Top-up           │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ Patient: payment.  │
        │ html               │
        │ • FPX gateway      │
        │ • Bank transfer +  │
        │   upload receipt   │
        │ • Auto receipt     │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ Staff: payment-    │
        │ admin.html         │
        │ • Verify           │
        │ • Receipt PDF      │
        │ • Refund (kalau    │
        │   perlu)           │
        └────────────────────┘
```

---

## 12. CONTENT (Self-Help Library + Announcements)

```
        ┌────────────────────┐
        │ Staff: Library     │
        │ • Upload video     │
        │ • Article          │
        │ • Worksheet PDF    │
        │ • Tag: pakej ID    │
        │ • Visibility       │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ psy_library        │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ Patient: library   │
        │ • Filter by pakej  │
        │ • Track progress   │
        └────────────────────┘

        ┌────────────────────┐
        │ Staff: Pengumuman  │
        │ • Tulis announce-  │
        │   ment             │
        │ • Sasaran (all /   │
        │   per-pakej)       │
        │ • Tarikh tamat     │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ psy_announcements  │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ Patient/Staff:     │
        │ Dashboard banner   │
        └────────────────────┘
```

---

## 13. SURAT RASMI (Letter Templates)

```
        ┌────────────────────┐
        │ Staff/Patient:     │
        │ surat.html         │
        │ Pilih template:    │
        │ • KWSP             │
        │ • PERKESO          │
        │ • RELA             │
        │ • Doctor's letter  │
        │ • dll (7 types)    │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ Generate PDF:      │
        │ • letterTemplates  │
        │   .js              │
        │ • Patient details  │
        │ • Letterhead       │
        │ • Sign by staff    │
        └─────────┬──────────┘
                  ▼
        ┌────────────────────┐
        │ Audit log + Save   │
        │ to storage         │
        └────────────────────┘
```

---

## 14. GOVERNANCE / AUDIT / REPORT

```
        ┌──────────────────────────┐
        │ Setiap action penting:   │
        │ • Save pakej             │
        │ • Approve KYC            │
        │ • Adjust stok            │
        │ • Order status change    │
        │ • Agreement sign         │
        │  → write psy_audit_log   │
        └────────────┬─────────────┘
                     ▼
        ┌──────────────────────────┐
        │ psy_audit_log            │
        └────────────┬─────────────┘
                     │
        ┌────────────┴───────────┐
        ▼                        ▼
┌──────────────────┐   ┌──────────────────┐
│ Staff: audit.html│   │ Staff:           │
│ • Filter actor   │   │ governance.html  │
│ • Filter action  │   │ • KPI            │
│ • Date range     │   │ • Status pesakit │
│ • Export CSV     │   │ • Compliance     │
└──────────────────┘   └──────────────────┘
                                ▼
                     ┌──────────────────┐
                     │ Staff:           │
                     │ staff-stats.html │
                     │ • Patient growth │
                     │ • Revenue        │
                     │ • Pakej sales    │
                     └──────────────────┘
```

---

## 15. ROLE & ACCESS MAP

```
                        ┌─────────────┐
                        │  AUTH.UID   │
                        └──────┬──────┘
                               ▼
                  ┌────────────────────────┐
                  │ psy_profiles           │
                  │ role: patient/staff    │
                  │ staff_role (jika staff)│
                  └────────────────────────┘
                               │
   ┌──────────────────┬────────┴────────┬──────────────────┐
   ▼                  ▼                 ▼                  ▼
┌──────────┐    ┌──────────┐     ┌──────────┐      ┌──────────┐
│ patient  │    │ admin    │     │ manager  │      │ doctor   │
└────┬─────┘    └────┬─────┘     └────┬─────┘      └────┬─────┘
     │ Dashboard      │ Semua page     │ Pesakit         │ KYC,
     │ KOB, KYC       │ + Manage Staff │ Inventori       │ KOB,
     │ Plan, Vitals   │ Audit          │ Pesanan         │ Slot
     │ Shop, Library  │ Governance     │ Pengumuman      │ Patient
     │ Payment, Surat │                │                 │
     ▼                ▼                ▼                 ▼
                                  ┌──────────┐
                                  │ coach    │
                                  └────┬─────┘
                                       │ Weekly Plan,
                                       │ Patients,
                                       │ Inventori,
                                       │ Pulangan
```

---

## RINGKASAN INTEGRASI ANTARA MODUL

```
                 ┌─────────────────────────────────┐
                 │       psy_profiles (auth)       │
                 └──────────────┬──────────────────┘
                                ▼
        ┌─────────────────────────────────────────────┐
        │              psy_patients                   │
        │  + active_package_id  + kob_status          │
        │  + outcome_status     + assigned_coach_id   │
        └─┬──────────┬──────────┬──────────┬──────────┘
          │          │          │          │
          ▼          ▼          ▼          ▼
    ┌─────────┐ ┌────────┐ ┌─────────┐ ┌──────────┐
    │  KYC    │ │  KOB   │ │  Plan   │ │ Vitals,  │
    │ Submi-  │ │ Sessions│ │Treatment│ │ Daily    │
    │ ssion   │ │+ Agreemts│ │+Progress│ │ Checkin  │
    └────┬────┘ └────┬───┘ └────┬────┘ └────┬─────┘
         │           │          │           │
         ▼           ▼          ▼           ▼
                ┌──────────────────────────┐
                │   psy_packages           │
                │ + agreement_clauses      │
                │ + coaching_schedule      │
                │ + daily_schedule         │
                │ + supplies (link inv)    │
                └─────────┬────────────────┘
                          ▼
            ┌─────────────────────────┐
            │  psy_inventory_items    │ ◄────── sync (name) ──────┐
            └─────────┬───────────────┘                            │
                      ▼                                            │
            ┌─────────────────────────┐                  ┌─────────┴───────┐
            │   psy_products          │ ──── stock ────► │ psy_orders      │
            └─────────────────────────┘                  └─────────────────┘

                ┌──────────────────────────┐
                │ psy_audit_log (all ops)  │ ◄──── setiap action
                └──────────────────────────┘
```

---

## NOTA PENGGUNAAN

- **Auto-sync**: Inventori ↔ Produk match by `name` (case-insensitive trim) via `shared/stockSync.js`
- **Auto-deduct**: Sesi tanda hadir → `shared/inventoryDeduct.js` tolak stok dari `coaching_schedule.supplies`
- **Default agreement**: 29 klausa dari `shared/defaultAgreement.js` (fallback) atau seed SQL untuk DB
- **RLS**: Setiap jadual ada policy untuk patient (own row) vs staff (semua, ikut staff_role)

Untuk drawing tool yang lebih visual, paste flow ni dalam:
- **Mermaid**: `https://mermaid.live` — guna syntax `graph TD`
- **Excalidraw**: `https://excalidraw.com` — sketch style
- **draw.io / diagrams.net**: import / drag-drop

