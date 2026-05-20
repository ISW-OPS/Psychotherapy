# Ibnu Sina Wellness (ISW) — Workflow Documentation
**System:** Psychotherapy & Integrated Treatment Platform
**Version:** 1.0 · For Friday Alignment
**Date:** 20 Mei 2026
**Target Launch:** 25 Mei 2026 (Isnin)

---

## User Types

The ISW system supports the following user roles. Access permissions and visibility of modules are controlled by role.

| Role | Description | Primary Modules |
|---|---|---|
| **Patient (Pesakit)** | End-user receiving treatment | Dashboard, Daily Check-in, Plan, Vitals, Library, Payment, Orders, Pulangan, Issue, Surat, Profile |
| **Coach** | Treatment guide & adherence monitor | Coach Dashboard, Assigned Patients, Plan-Week Entry, Coaching Catalog, Sessions, Inventory, Pulangan, Surat |
| **Doctor** | Clinical oversight & KOB sessions | Doctor Dashboard, KYC Review, KOB Sessions, Plan-Week, Patient Hub, Library, Inventory |
| **Manager** | Operations oversight | Manager Dashboard, Patients, Sessions, Orders, Closures, Inventory, Reports, Announcements |
| **Admin (Pentadbir)** | Full system control | All modules + Staff Management, System Settings, Audit Log, Payments, Invoices, Reports, Surat, Library |
| **Hakeema / Kaunselor / Fisioterapi / Hakeem** *(Phase 2)* | Specialist consultations | Specialist-specific dashboards (M6/M11 Hakeema 1:1, monthly/quarterly sessions) |

**Summary:** Six distinct role types with cascading access. Patient has the most restricted view (own data only). Admin has full system access. Specialist roles are scoped to their booking/notes only.

---

## Master Workflow

The ISW platform consists of **17 interconnected modules** organised around the patient treatment journey. The master flow follows a patient from first contact (lead) through onboarding, active treatment, and graduation to the **Geng ALIVE** community.

### High-Level Module Map

```
LEAD INTAKE
   │
   ▼
[1] KYC & Pendaftaran ──────────────► [2] KOB (Konsultasi Overhaul Body)
   │                                      │
   │                                      ▼
   │                                   [3] Pakej Rawatan Selection & Payment
   │                                      │
   │                                      ▼
   │                                   [4] Digital Agreement Signing
   │                                      │
   ▼                                      ▼
[5] Patient Dashboard ◄──────────────► [6] Treatment Timeline (auto-generated)
   │      ▲                                  │
   │      │                                  ▼
   ▼      │                              [7] Slot Klinik (booking)
[8] Daily Check-in ──────► [9] Kepatuhan Dashboard ◄──── [10] Coach Dashboard
   │                              ▲                              │
   ▼                              │                              ▼
[11] Vitals (BP, HbA1c)          [12] Adherence Alerts ──► [13] Plan-Week Entry
   │                                                              │
   │                                                              ▼
[14] Library Access ◄─── (package_ids filter)              [15] Mark Hadir
   │                                                              │
   ▼                                                              ▼
[16] Pulangan Botol                                       [17] Auto-Deduct Inventory
   │                                                              │
   │                                                              ▼
   │                                                       [Audit Log]
   ▼                                                              ▲
[Other patient services: Orders, Issue, Surat, Payment]──────────┘
                                                                  │
                                                                  ▼
                                                            [Governance Dashboard]
                                                                  │
                                                                  ▼
                                                            [Outcome Status]
                                                                  │
                                                                  ▼
                                                            [Geng ALIVE — Phase 3]
```

### Module Triggers & Transitions

1. **Lead → KYC**: Closer/admin creates new patient OR patient self-registers. Form submission triggers GHL sync *(Phase 3)*.
2. **KYC → KOB**: Once KYC fields complete, patient redirected to book KOB consultation. Payment confirms booking.
3. **KOB → Pakej**: After doctor recommendation during KOB, patient browses packages and pays.
4. **Pakej → Agreement**: Payment success triggers agreement template auto-load; patient must sign before treatment.
5. **Agreement → Timeline**: Signed contract auto-generates per-week schedule from `coaching_schedule` JSONB and creates session rows.
6. **Timeline → Daily Check-in**: Patient receives notifications at each scheduled activity (madu, zikir, etc.) and logs compliance.
7. **Check-in → Adherence Alert**: Low compliance (< 5 madu/day for 4-5 days) auto-triggers coach alert.
8. **Mark Hadir → Inventory Deduct**: F2F session marked attended → `psy_inventory_items.qty_in_stock` auto-decreases by the week's defined supplies.
9. **Inventory Threshold → Auto-Purchase** *(Phase 2)*: Stock ≤ 30% triggers purchase invoice generation.
10. **Treatment End → Outcome Update**: Coach updates `outcome_status` (Berhenti / OTW / Meninggal). Patient transitions to Geng ALIVE if graduated *(Phase 3)*.

**Summary:** The master workflow is centred on the treatment lifecycle. KYC → KOB → Pakej → Agreement → Timeline → Daily activities → Outcome. Every module feeds into the Governance Dashboard and Audit Log for accountability. Inventory, Payments, and Notifications operate as cross-cutting services available to all modules.

---

## Sub-Workflow 1: KYC & Pendaftaran

**Primary Users:** Admin · Closer · Patient (self-registration)

### Steps

1. **Trigger**: New patient lead enters the system (via Admin manual entry, GHL webhook *(Phase 3)*, or patient self-signup).
2. **Patient or Staff submits KYC form** containing:
   - IC Number (validation)
   - Full Name, Phone, Address
   - Emergency Contact (name + phone)
   - Medical Condition / History
   - Confirmation popup: *"Maklumat ini adalah maklumat PESAKIT, bukan pewaris"*
3. **Decision Point: Verification Status**
   - **Approved** → patient record activated, `psy_patients.status = 'active'`
   - **Pending** → admin reviews submission in KYC list
   - **Rejected** → patient notified with reason; can resubmit
4. **Auto-claim existing staff-created record**: If patient signs up with IC matching an `unregistered` staff record, system links the records.
5. **Trigger next module**: KYC approved → patient redirected to KOB booking.

### Decision Points
- **IC duplicate** → block submission with error message
- **Missing required fields** → form validation prevents submit
- **Manual creation by staff** → no KYC popup needed (staff entered all fields)

### Error Handling
- GHL sync failure *(Phase 3)*: Fallback to manual entry; queue webhook retry.
- Duplicate IC: Show existing patient record link, ask to merge or reject.

**Summary:** KYC is the entry gate. It collects mandatory patient information, validates identity, and confirms data is the patient's (not next-of-kin). Once approved, patient progresses to KOB.

---

## Sub-Workflow 2: KOB (Konsultasi Overhaul Body)

**Primary Users:** Closer · Doctor · Patient

### Steps

1. **Trigger**: KYC approved → patient sees "Tempah KOB" CTA on dashboard.
2. **Patient browses available KOB slots** from `psy_kob_slot_config` (filtered by clinic closures).
3. **Patient selects slot + makes payment** (FPX/Card/Transfer/GHL).
4. **Payment success** → `psy_patients.kob_status = 'paid'`, patient receives:
   - Welcome video (auto from package config)
   - Lokasi ISW video
   - Confirmation WhatsApp *(Phase 3)*
5. **On KOB day**: Doctor marks patient `hadir`. Recommendation note saved.
6. **Decision Point: Doctor's recommendation**
   - **Package recommended** → patient proceeds to Pakej selection
   - **No package** → closer keys in recommendation note for future reference
7. **Status updates**: `kob_status` flows through: `na → pending_payment → paid → kyc_done → booked → hadir → package_recommended → completed`.

### Decision Points
- **Patient no-show** → coach/admin marks `kob_status = 'tidak_hadir'`; auto-charge if applicable.
- **Reschedule** → patient can reschedule once free; subsequent reschedules incur RM50 charge *(future)*.

### Error Handling
- Slot already full → real-time validation prevents double-booking.
- Payment failure → kob_status stays `pending_payment`; reminder sent in 24h.

**Summary:** KOB is the diagnostic consultation. Patient pays, attends, and receives a treatment recommendation. The status progression locks subsequent modules until completed.

---

## Sub-Workflow 3: Pakej Rawatan (Treatment Package)

**Primary Users:** Admin · Patient

### Steps

1. **Trigger**: KOB completed → patient sees recommended packages in `pakej.html`.
2. **Patient browses package catalog** with filters (Kategori, Tempoh, Harga).
3. **Patient clicks Detail** → views in `pakej-detail.html`:
   - Ringkasan Pakej (price, duration, sessions)
   - Bekalan & Inventori (supplies received)
   - Timeline Rawatan (visual milestones)
   - Jadual Harian (daily activity template)
   - Kontrak Pakej (8 clauses with variable interpolation)
   - Kandungan Pakej (linked library content)
4. **Patient pays** for selected package via `payment.html`.
5. **Payment success** → triggers:
   - `psy_patients.active_package_id` set
   - Auto-create `psy_treatment_plans` row with `coaching_schedule` copied from package
   - Auto-generate per-week sessions in `psy_plan_weekly_progress`
   - Open Agreement signing flow
6. **Admin manages packages** in `pakej-edit.html`:
   - Create/edit basic info, supplies, timeline weeks, daily schedule, agreement clauses
   - Draft mode (`status = 'draft'`) hides from patient view
   - Active mode publishes to catalog

### Decision Points
- **Patient changes mind mid-flow** → cart cleared, no charge.
- **Insufficient stock** *(Phase 2)*: Block purchase if supplies unavailable.
- **Free package (RM0)** → skip payment gateway; auto-activate.

### Error Handling
- Payment timeout → status `pending_payment`; auto-cancel after 48h.
- Refund request → admin manual process (no refund button — out of scope).

**Summary:** Patients select and purchase a treatment package. Each package carries full treatment specifications (timeline, supplies, contract, content access). Admin manages packages with draft/active workflow.

---

## Sub-Workflow 4: Digital Agreement & Onboarding

**Primary Users:** Patient · Admin

### Steps

1. **Trigger**: Package payment success → agreement modal opens.
2. **System loads agreement template** from `pkg.agreement_clauses` with variable interpolation:
   - `{{patient_name}}`, `{{patient_ic}}`, `{{package_name}}`, `{{price}}`, `{{today}}`
3. **Patient reads 8 clauses**:
   1. Pengenalan
   2. Komitmen Patient
   3. Konfidensial
   4. Reaksi Pemulihan
   5. Bayaran
   6. Ketidakhadiran
   7. Pengakhiran
   8. Pengesahan
4. **Patient signs digitally** (e-signature pad).
5. **System stores signed PDF** in storage; `psy_patients.agreement_signed_at` timestamp set.
6. **Onboarding materials delivered**:
   - Welcome video link
   - Lokasi ISW video
   - Library access unlocked based on `package_ids` filter
   - First session reminder scheduled

### Decision Points
- **Patient declines signing** → treatment blocked; closer follow-up call.
- **Re-signing required** (package upgrade) → new agreement with updated terms.

### Error Handling
- Storage upload failure → retry queue; admin notified.
- Variables not populated → template uses fallback text or shows admin error.

**Summary:** Before any treatment begins, patient must sign the digital agreement. The system stores the signed document with timestamp for legal compliance.

---

## Sub-Workflow 5: Treatment Timeline & Sessions

**Primary Users:** Coach · Doctor · Admin · Patient

### Steps

1. **Trigger**: Package payment → `coaching_schedule` JSONB copied from package to `psy_treatment_plans.coaching_schedule`.
2. **System auto-generates session rows** in `psy_plan_weekly_progress` (one per week, status `booked`).
3. **Each week object contains**:
   - Week number, mode (F2F / Online / Both)
   - Guidance items (catalog refs)
   - Activity items (catalog refs)
   - Supplies (inventory item IDs with quantities)
4. **Patient sees timeline** in `plan.html`:
   - Visual milestone bar (Week 1 → Week 12)
   - Per-week details (what to expect)
   - Next session reminder
5. **Coach/Doctor edits per-week** in `plan-week.html`:
   - Update guidance/activity/supplies for specific weeks
   - Mark session as `hadir` / `tidak_hadir` / `cancel` / `reschedule`
6. **Mark Hadir flow**:
   - Status updated to `hadir`
   - **If F2F mode** → `deductSessionSupplies()` runs → inventory auto-decreases
   - Audit log entry: `inventory.auto_deducted`
   - Banner shows "📦 Bekalan ditolak: IB −1kg, Madu −2botol"
7. **Reschedule flow**:
   - Original session marked `cancel`
   - 2 new sessions created at end of timeline with status `extension_pending_payment`
   - Patient receives notification: "Bayar RM50 untuk lanjutkan ke Minggu N"
   - Payment success → extension sessions become `booked`

### Decision Points
- **Online mode** → no inventory deduction (no physical supplies).
- **Extension session** (`is_extension = true`) → skip deduction (already counted in original week).
- **Patient self-mark hadir** → blocked; only coach/doctor/admin can mark.

### Error Handling
- Item not found in inventory → log error, skip that item, continue with others.
- Stock insufficient → set qty to 0 (no negative); warning shown to coach.

**Summary:** Each package automatically generates a per-week treatment timeline. Coaches manage attendance and per-week details. F2F attendance triggers automatic inventory deduction with audit trail.

---

## Sub-Workflow 6: Daily Check-in & Adherence

**Primary Users:** Patient · Coach

### Steps

1. **Trigger**: Daily, patient opens `checkin.html` (or receives notification at scheduled times).
2. **Patient logs**:
   - Madu count (target from `pkg.madu_frequency_per_day`)
   - Mood score (1-10)
   - Energy score (1-10)
   - Activities completed (multi-select)
   - Symptoms / recovery reactions
3. **System saves** to `psy_daily_checkins` with date stamp.
4. **Auto-summary generated** in `kepatuhan.html`:
   - **Patient view**: 14-day madu chart, mood trend, streak count, session attendance
   - **Staff view**: All patients with compliance %, low-compliance highlights
5. **Adherence Alert auto-trigger**:
   - If madu count < target for 4-5 days in a week
   - Coach assigned receives alert in `psy_adherence_alerts` table
   - Alert appears in coach dashboard end-of-day
6. **Coach acknowledges alert**:
   - Reviews patient history
   - Contacts patient via WhatsApp / call
   - Marks alert as `acknowledged`

### Decision Points
- **Symptom severe (e.g., critical reaction)** *(Phase 2)*: Auto-show solution + "Call Coach" button.
- **Madu < 5/day for 4-5 days** → patient cannot attend treatment session; disclaimer shown.

### Error Handling
- Patient misses check-in → next-day reminder; streak breaks.
- Late entry (after midnight) → counted for previous day only if within 6 hours.

**Summary:** Daily check-in is the primary adherence mechanism. Patients log madu, mood, and activities; system auto-summarises for both patient and coach. Low compliance triggers automatic coach alerts.

---

## Sub-Workflow 7: Inventory Management

**Primary Users:** Admin · Manager · Coach (limited)

### Steps

1. **Admin manages inventory** in `inventory.html`:
   - Add/edit items (name, category, unit, min_qty, qty_in_stock)
   - Set `consumption_type`: `fixed` (manual) or `package` (auto-derived from active patients)
   - For `package` items: `dynamic_monthly` = (active patients) × (per-patient consumption)
2. **Auto-deduction on F2F session attendance** (see Sub-Workflow 5).
3. **Low-stock detection**:
   - **Fixed items**: `qty_in_stock ≤ min_qty` → flag low
   - **Package items**: `qty_in_stock ≤ 30% × dynamic_monthly` → flag low
4. **Auto-purchase trigger** *(Phase 2)*:
   - System generates `psy_inventory_requests` with status `pending_approval`
   - Finance reviews and approves
   - Approved request sent to purchasing
5. **Manual replenishment**:
   - Admin adds stock via "Receive Stock" form
   - Audit log entry created

### Decision Points
- **Item requires approval** (`requires_approval = true`) → manual flow even for package items.
- **Patient F2F session cancelled before attendance** → no deduction.

### Error Handling
- Negative stock attempt → cap at 0; alert admin.
- Item deleted with active references → soft-delete only (audit retention).

**Summary:** Inventory tracks all clinic supplies with auto-deduction on F2F attendance. Stock thresholds trigger purchase requests (Phase 2). Admin has full control; coaches can only view.

---

## Sub-Workflow 8: Slot Klinik (Clinic Slot Booking)

**Primary Users:** Admin · Patient · Coach

### Steps

1. **Admin configures slots** in `kob-slots.html` (renamed to "Slot Klinik"):
   - Two categories: **KOB Slots** and **Rawatan Slots**
   - Per slot: time range (e.g., "9.30 - 11.30 pg"), duration auto-calculated
   - Per day (Rabu-Ahad): ON/OFF toggle
2. **Admin manages closures** in `closures.html`:
   - Auto-seeded: Aidilfitri, Aidiladha, Deepavali (recurring)
   - Custom: any date with label and category
3. **Admin can Override Per-Tarikh**:
   - Specific date overrides default slot configuration
   - E.g., "Jumaat 15 Mei: only 2.30pm slot, lock 4.30pm"
4. **Patient books slot**:
   - Slot picker shows only ON + non-closure dates
   - On selection, slot temporarily reserved (5 min)
5. **Patient pays** → booking confirmed; slot count decremented for that date.

### Decision Points
- **Mode lock per package**: If package week is `online` → only Online slots shown; `f2f` → only F2F.
- **Slot full** → next available date shown.
- **Closure on selected date** → block selection with closure label visible.

### Error Handling
- Race condition (two patients book simultaneously) → first commit wins; second sees "slot taken".
- Admin marks slot OFF after patient booked → existing bookings honoured; new bookings blocked.

**Summary:** Slot Klinik is the operational scheduling layer. Admin defines available slots per day; clinic closures auto-lock dates. Patients book slots matching their package mode constraints.

---

## Sub-Workflow 9: Coach Dashboard & Patient Hub

**Primary Users:** Coach · Doctor · Admin

### Steps

1. **Coach logs in** → sees dashboard with:
   - List of assigned patients (and ALL patients if access elevated)
   - Today's sessions to attend / mark
   - Open adherence alerts
   - Low-compliance patients highlighted
2. **Coach opens Patient Hub** (`patient-hub.html`):
   - Overview: profile, package, current week, vitals, last check-in
   - Tabs: Sessions, Daily Check-ins, Vitals, Library access, Adherence, Audit
3. **Coach actions**:
   - Mark sessions hadir / tidak_hadir / reschedule
   - Update per-week treatment notes
   - Add coaching notes (text or voice recording *(Phase 3)*)
   - Send patient notification
   - Acknowledge adherence alert
4. **Coach updates outcome status** (when treatment ends):
   - `OTW` (On Treatment) / `berhenti` / `meninggal`
   - Triggers governance dashboard update

### Decision Points
- **Patient flagged critical** *(Phase 2)*: Red Flag Escalation banner; ward visit setup workflow.
- **Coach not assigned to patient** → read-only access (Phase 3 allows full access for all coaches).

### Error Handling
- Concurrent edits → last-write-wins with version warning.
- Note save failure → draft saved to localStorage.

**Summary:** Coaches monitor and manage their patient cohort. The Patient Hub provides 360° view of each patient. Coach actions feed back into adherence tracking and outcome reporting.

---

## Sub-Workflow 10: Notifications & Communications

**Primary Users:** All users (recipients)

### Steps

1. **System events trigger notifications**:
   - New KYC submission → admin
   - Adherence alert → coach
   - Session reminder → patient (24h, 1h before)
   - Payment success → patient
   - Inventory low → admin / manager
   - Issue submitted → admin
2. **In-app delivery**:
   - `psy_notifications` table holds all
   - Bell icon shows unread count
   - Click to mark read
3. **WhatsApp/Email delivery** *(Phase 3)*:
   - Bridge to WhatsApp Business API (WATI/360dialog)
   - Templates per event type
   - Throttling and retry logic
4. **Critical alerts**:
   - Red Flag patient → immediate notification to ALL coaches + admin
   - Inventory stockout → notification to procurement chain

### Decision Points
- **User notification preferences** → email vs WhatsApp vs both.
- **Quiet hours** *(Phase 3)*: Non-critical notifications batched.

### Error Handling
- WhatsApp delivery fail → fallback to SMS *(Phase 3)*.
- Email bounce → flag in user profile.

**Summary:** All system events flow through a central notification hub. In-app delivery works today; WhatsApp/Email integrations come in Phase 3.

---

## Sub-Workflow 11: Reporting & Governance

**Primary Users:** Admin · Manager

### Steps

1. **Admin opens Governance Dashboard** (`governance.html`):
   - 4 KPI cards: Active Patients, Adherence Rate, KYC Approved, Low Stock
   - Patient Outcome Breakdown (Dalam Rawatan / OTW / Berhenti / Meninggal)
   - Package Distribution (% per package)
   - Session Attendance Ring (30-day rate)
   - KOB Funnel
   - Inventory Health
2. **Filter capabilities** *(partial — full filters Phase 2)*:
   - By disease, age, gender, state, location, package
3. **Drill-down to Package Report** (`pakej-laporan.html`):
   - All packages overview with patient counts
   - Click row → `pakej-report.html?id=X` for detailed package activity
4. **Audit Log** (`audit.html`):
   - All sensitive actions logged
   - Filterable by actor, action type, date range
   - CSV export for compliance

### Decision Points
- **Report date range** → default last 30 days; custom range available.
- **Drill-down access** → admin sees all; manager sees ops only; coach sees own patients.

### Error Handling
- Empty data set → graceful empty state with prompt.
- Large query → pagination + loading indicator.

**Summary:** Governance dashboard gives management real-time KPIs. Audit log preserves all actions for compliance. Reports drill down from clinic-wide to per-package to per-patient.

---

## Sub-Workflow 12: Self-Help Library

**Primary Users:** Admin · Patient · Coach (view)

### Steps

1. **Admin uploads content** in `library.html`:
   - Title, description, content_type (video/article/PDF/audio/link), URL
   - Category, icon, sort order
   - **Akses Pakej** toggle: Public (all patients) OR specific package IDs
2. **Content distribution**:
   - Public items visible to all patients
   - Restricted items only visible to patients with matching `active_package_id`
3. **Patient browses library** (`library.html` patient view):
   - Filtered automatically by their `active_package_id`
   - Categories: Berjemur, Zikir Bersanad, Terapi Bumi, Pernafasan Fitrah, Herba Thoharah, etc.
4. **Coach/Doctor browses** all content for reference / sharing with patient.
5. **Linked content in Pakej Detail**:
   - `pakej-detail.html` shows section "Kandungan Pakej"
   - Filtered library items based on `package_ids` matching that package

### Decision Points
- **Content type = video** → embedded player; `link` → external open in new tab.
- **Package upgrade** → patient gains access to new package's restricted content.

### Error Handling
- Broken URL → admin alert; content hidden from patient view.
- Patient sans active package → public content only.

**Summary:** Library is the self-help knowledge base. Content can be public or package-restricted. Patient access auto-filters based on their active package; library content also surfaces in package detail pages.

---

## Cross-Cutting Module: Payment & Invoice

**Primary Users:** Admin · Patient

### Steps

1. **Payment triggered** from: KOB booking, Package purchase, Extension week, Add-on product.
2. **Payment methods** *(Phase 3 integration)*: FPX, Card, Transfer, GHL.
3. **Admin manages payments** in `payment-admin.html`:
   - Filter by status (completed/pending/failed), method, period
   - Manual entry for offline payments
   - Mark pending → completed
4. **Invoice generation**:
   - "Jana Invois" button → printable A4 invoice
   - Stable invoice number: `INV-YYYYMM-{last6id}`
   - Print stylesheet hides nav; supports browser print/PDF
5. **Future**: Auto-send invoice via WhatsApp + email *(Phase 3)*.

### Decision Points
- **Refund**: Not currently supported (out of scope).
- **Partial payment**: Not supported; full payment required.

**Summary:** Payment module is the financial layer. All transactions trace back to `psy_payments`; invoices are printable on demand.

---

## Cross-Cutting Module: Audit Log

**Primary Users:** Admin

### Steps

1. **Every sensitive action writes to** `psy_audit_log`:
   - `actor_id`, `actor_name`, `actor_role`, `action`, `target`, `meta` (JSONB)
2. **Action types include**:
   - `kyc.approved`, `kyc.rejected`
   - `package.created`, `package.updated`, `package.activated`, `package.deactivated`
   - `plan.week_hadir`, `plan.week_updated`, `plan.extension_created`
   - `inventory.auto_deducted`, `inventory.manual_adjusted`
   - `payment.created`, `payment.refunded`
   - `staff.added`, `staff.removed`
   - `issue.reported`, `issue.closed`
3. **Admin reviews** in `audit.html`:
   - Filter by action, role, date, actor
   - 500 most recent entries loaded
   - CSV export

**Summary:** All system actions are logged immutably. Audit log supports compliance review and incident investigation.

---

## Integration Dependencies (Phase 3)

The following modules are **partially built but require external integrations** to be fully functional:

| Module | External Dependency | Status |
|---|---|---|
| KYC Sync | GHL API access | Pending vendor access |
| WhatsApp Reminder | WhatsApp Business API (WATI/360dialog) | Provider selection pending |
| Invoice Auto-Send | Email service + WhatsApp API | Same as above |
| Inventory Auto-Purchase | SQL Accounting API | Vendor engagement pending |
| AI Medical Report | OpenAI/Claude API | Budget approval pending |
| Coaching Transcription | ChatGPT Whisper API | Same as above |
| NLC Class | Google Meet / Zoom | Platform decision pending |

**Summary:** External integrations are deferred to Phase 3 (Feb-Mei 2027). Phase 1 launch (25 Mei 2026) operates with in-app notifications and manual payment confirmation.

---

## Final Notes

- **Phase 1 Launch Scope (25 Mei 2026)**: KYC, KOB, Pakej Rawatan, Timeline, Daily Check-in, Adherence, Slot Klinik, Inventory Auto-Deduct, Coach Dashboard, Governance, Audit Log, Library, Pulangan Botol, Issues, Surat Generator, Payments & Invoices (manual).
- **Phase 2 Adds (Oct 2026 - Jan 2027)**: Sistem Pakar (Hakeema, Kaunselor, Fisioterapi, Hakeem), Medical Records Upload, DNA Tracking, Reaksi Pemulihan workflow, Special Patient flags, Madu Tier per package.
- **Phase 3 Adds (Feb - Mei 2027)**: All external integrations (GHL, WhatsApp, SQL Accounting, AI), Reward & Star System, Geng ALIVE features, NLC class management, Google Review.
- **Total Modules**: 17 main + 3 cross-cutting (Payment, Audit, Notifications).
- **Total User Roles**: 6 (Patient, Coach, Doctor, Manager, Admin, Specialists).

**Document prepared for Friday alignment meeting.**
