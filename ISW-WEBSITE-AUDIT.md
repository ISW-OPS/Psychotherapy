# ISW Website Audit — for the ISW Mobile App Team

**Audit date:** 2026-09-18
**Repository:** `ISW-OPS/Psychotherapy` (local path `C:\Users\ASUS\ISW system`), branch `main`
**Deployed at:** `https://psychotherapy-g51q.vercel.app`

> ## ⚠️ Section 0 verdict, up front: this is NOT a Next.js application
>
> It is a **plain static HTML site** — hand-written `.html` files with vanilla JavaScript, no bundler, no build step, no framework of any kind. If your planning documents say "Next.js," they are wrong and should be corrected before any porting work starts. Details and evidence below in Section 0.

This report is a factual, read-only survey. Nothing in this repository was modified to produce it. Every claim is cited as `path/to/file:line`. Where something could not be determined with confidence, it is marked `UNKNOWN` rather than guessed. No API keys, tokens, service-role secrets, or real patient/staff data are reproduced anywhere below — where a secret exists in the repo, its file path is given and it is flagged for rotation instead.

---

## Section 0 — What this codebase actually is

**Framework: none.** This is a static multi-page HTML site.

- **No `package.json` framework dependency.** The root `package.json` (`package.json:1-16`) declares exactly one runtime dependency:
  ```json
  {
    "name": "isw-system",
    "version": "1.0.0",
    "description": "ISW Health Management System",
    "main": "server.js",
    "scripts": { "start": "node server.js", "dev": "node server.js" },
    "engines": { "node": ">=18.0.0" },
    "dependencies": { "@supabase/supabase-js": "^2.108.2" }
  }
  ```
  There is **no `devDependencies` block at all** — no bundler, no compiler, no test runner, no framework. `package-lock.json` confirms the dependency tree is just `@supabase/supabase-js` and its own transitive deps (`@supabase/auth-js`, `@supabase/functions-js`, etc. — `package-lock.json:1-20`).
- **No Next.js artifacts anywhere.** No `next.config.js`, no `app/` or `pages/` router directory, no `.next/` build output, no `next` entry in `package.json`. This matches what you observed on the deployed site: `.html` URLs, relative image paths, no `__NEXT_DATA__`, no `_next/static`, no hydration markers — because there is no React runtime at all.
- **How pages are authored and served:** ~180 hand-written `.html` files live under `roles/patient/`, `roles/staff/`, `auth/`, and the repo root. Each page is a self-contained document that loads a handful of shared `<script>` files (`shared/supabase.js`, `shared/authGuard.js`, `shared/navbar.js`, `shared/theme.js`, `shared/i18n.js`, page-local `_shared.js`) via plain `<script src="...">` tags — no imports, no module bundler. Styling is Tailwind CSS loaded from a CDN at runtime (`<script src="https://cdn.tailwindcss.com">`, e.g. `auth/login.html:8`) with a small `tailwind.config` JS object assigned per page (`shared/theme.js:1-20`). There is **no build step**: what's in the repo is what's deployed, byte-for-byte.
- **Local dev server:** `server.js` (`server.js:1-49`) is a ~50-line hand-rolled Node `http` server that just serves files off disk by MIME type — not Express, not a framework dev server. `npm run dev` / `npm start` both just run `node server.js` (`package.json:6-7`).
- **Two deploy configs exist, which is worth flagging on its own:**
  - `vercel.json` (`vercel.json:1-4`, `{"cleanUrls": false, "trailingSlash": false}`) — consistent with static-file hosting on Vercel, and matches the observed `.html`-suffixed URLs on `psychotherapy-g51q.vercel.app`. Git history shows this file was added in commit `ce9e541` ("add vercel.json for static site deployment").
  - `railway.json` (`railway.json:1-21`) also exists, configured for Railway's Railpack builder with `numReplicas: 1`, added earlier in commit `9b651d5` ("railway"). Given `server.js` exists specifically to serve the static files as an HTTP app (which Vercel doesn't need — Vercel serves static files directly), **Railway was likely an earlier or parallel deployment target that uses `server.js` as its entrypoint**, while Vercel serves the same static files directly. `UNKNOWN` which one (if not both) is actually live today, or whether Railway is now dead. No `.vercel/project.json` or Railway project files are present locally to confirm a live link either way.
- **Dependencies (verbatim):**
  ```
  "dependencies": {
    "@supabase/supabase-js": "^2.108.2"
  }
  ```
  No `devDependencies` key exists in `package.json` at all.
- **Is this repo the thing deployed at `psychotherapy-g51q.vercel.app`?** Best available evidence says yes: the git remote (`git remote -v`) points to `https://github.com/ISW-OPS/Psychotherapy.git`, matching the `Psychotherapy` name embedded in the Vercel URL, and `vercel.json`'s settings (`cleanUrls: false` → `.html` suffixes stay in URLs) match what you observed live. No second repository, prototype branch, or rewrite was found — only `main` and one local work-in-progress worktree branch (`worktree-agent-a8e073c8bd9b27d0c`) exist locally, and there is only one `origin` remote.
- **Language:** All application code is vanilla JavaScript (ES6+, no TypeScript on the frontend) and HTML/CSS. The Supabase Edge Functions (backend logic, see Section 4) are written in **TypeScript**, running on Deno (`supabase/functions/*/index.ts`).
- **User-facing copy language:** Authored primarily in **Bahasa Melayu** (source language, confirmed at `shared/i18n.js:2-8`), with a runtime bilingual overlay to English (see Section 9) — the product's *default* display language is actually English (`shared/i18n.js:12,19-22`), with Malay as the fallback/source text.

---

## Section 1 — Route inventory

There are **180 HTML files** in total: 40 under `roles/patient/`, 131 under `roles/staff/`, 3 under `auth/`, and 3 at the repo root (`index.html`, `landing-preview.html`, `offline.html`). Every route below is reached as a direct `.html` file path relative to the deployed domain (e.g. `https://psychotherapy-g51q.vercel.app/roles/patient/dashboard.html`) — there is no client-side router.

### Root-level pages

| Route | Source file | Purpose | Public or authenticated | Data source |
|---|---|---|---|---|
| `/index.html` | `index.html` | Boot/bootstrap page: checks for a Supabase session, then redirects to `roles/{role}/dashboard.html` (role read from `psy_profiles.role`) or to `auth/login.html` if not logged in. Also handles Supabase invite/recovery token links in the URL hash, redirecting them to `auth/set-password.html` (`index.html:48-57`). | Public entry point, but does nothing except redirect | `psy_profiles` (`index.html:65-69`) |
| `/landing-preview.html` | `landing-preview.html` | Marketing/landing page mockup ("Ibnu Sina Wellness — Kesihatan Holistik BPS-S") with nav, hero, feature sections; uses Tailwind CDN + Google Fonts (Inter + Lora). **Not linked from anywhere else in the repository** (confirmed via repo-wide search) — appears to be a standalone design preview, not a wired-up route. | Public (no auth code), but effectively orphaned | None — static content only |
| `/offline.html` | `offline.html` | PWA offline fallback page ("Tiada Sambungan Internet"), shown by the service worker when the network is unavailable. Wired into `sw.js` (confirmed by direct reference in `sw.js`). | Public | None |

### Auth pages (`auth/`)

| Route | Source file | Purpose | Public or authenticated | Data source |
|---|---|---|---|---|
| `/auth/login.html` | `auth/login.html` | Email+password sign-in and "forgot password" trigger | Public | `psy_profiles` (post-login role lookup, via `auth/auth.js`) |
| `/auth/reset.html` | `auth/reset.html` | Password-reset landing page — consumes a Supabase recovery session and lets the user set a new password | Public (but requires a valid recovery-link session; shows "invalid/expired link" otherwise) | Supabase Auth only |
| `/auth/set-password.html` | `auth/set-password.html` | First-time password setup for staff invited via `invite-staff` edge function, or for Supabase invite/recovery links | Public (token-gated via URL hash) | Supabase Auth only |

(`auth/auth.js` is the shared logic file backing `login.html`; it is not itself a route.)

### Patient routes (`roles/patient/`, 40 files)

Every patient page (except four noted below) calls `initPatient(pageId, titleSub)` (`roles/patient/_shared.js:102`), which requires a live Supabase session (`checkAuth('patient')`) and then applies a two-gate access-control system:
- **Gate 0 (always open once logged in):** `kyc` (page file `pendaftaran.html`), `profile`, `dashboard` (`roles/patient/_shared.js:49`).
- **Gate 1 (KYC submitted, not yet approved):** unlocks `kob`, `pakej`, `payment`, `payment_overview`, `payment_plan`, `sejarah_pembayaran`, `routine`, `checkin`, `kepatuhan` (`roles/patient/_shared.js:57`).
- **Gate 2 (KYC approved AND `kob_status` is `na` or `completed`):** unlocks everything else — plan, vitals, library, medical records, events, etc. (`roles/patient/_shared.js:59-64`). Failing this redirects to `kob.html`.

| Route | Source file | Purpose | Public/Auth | Data source |
|---|---|---|---|---|
| `/roles/patient/dashboard.html` | dashboard.html | Home overview: treatment status, announcements, vitals, emergency zone | Auth, Gate 0 | `psy_announcements`, `psy_continuity_offers`, `psy_daily_checkins`, `psy_daily_completions`, `psy_emergency_alerts`, `psy_event_registrations`, `psy_events`, `psy_kepatuhan_log`, `psy_kob_installment_checkpoints`, `psy_kob_sessions`, `psy_kyc_submissions`, `psy_packages`, `psy_patients`, `psy_payments`, `psy_plan_weekly_progress`, `psy_profiles`, `psy_reaksi_item`, `psy_treatment_plans` |
| `/roles/patient/profile.html` | profile.html | Account/profile management + security | Auth, Gate 0 | `psy_affiliate_payouts`, `psy_kyc_submissions`, `psy_patients`, `psy_profiles`, `psy_referrals`, `psy_vouchers` |
| `/roles/patient/pendaftaran.html` | pendaftaran.html | KYC/registration form (internal `pageId` still `'kyc'` — UI-text-only rename) | Auth, Gate 0 | `psy_kyc_submissions`, `psy_notifications`, `psy_patients`, `psy_profiles` |
| `/roles/patient/kob.html` | kob.html | KOB onboarding: agreement e-signature, slot booking, package intro | Auth, Gate 1 | `psy_clinic_closures`, `psy_kob_agreements`, `psy_kob_installment_checkpoints`, `psy_kob_sessions`, `psy_kob_slot_config`, `psy_kyc_submissions`, `psy_packages`, `psy_patients`, `psy_payments`, `psy_profiles`; edge fn `payments-initiate` |
| `/roles/patient/kob-agreement.html` | kob-agreement.html | **Dead redirect stub** — `location.replace` to `kob.html`, discards any `?kob_id=` param it receives (still linked-to with that param from `roles/staff/kob-detail.html:2435`) | N/A (redirect only) | none |
| `/roles/patient/pakej.html` | pakej.html | Browse/choose treatment packages | Auth, Gate 1 | `psy_kob_agreements`, `psy_kob_sessions`, `psy_package_purchases`, `psy_packages`, `psy_patients`, `psy_plan_weekly_progress` |
| `/roles/patient/pakej-detail.html` | pakej-detail.html | Detail view of one package | Auth, Gate 2 | `psy_package_purchases`, `psy_patients`, `psy_packages`, `psy_treatment_plans` |
| `/roles/patient/payment.html` | payment.html | Checkout/payment for a package or product | Auth, Gate 1 | `psy_appointments`, `psy_kob_installment_checkpoints`, `psy_kob_sessions`, `psy_package_purchases`, `psy_packages`, `psy_patients`, `psy_payments`, `psy_plan_weekly_progress`, `psy_products`, `psy_promo_codes`, `psy_vouchers`; edge fn `payments-initiate` |
| `/roles/patient/payment-overview.html` | payment-overview.html | Summary of all packages + payment commitments | Auth, Gate 1 | `psy_kob_installment_checkpoints`, `psy_kob_sessions`, `psy_payments` |
| `/roles/patient/payment-plan.html` | payment-plan.html | Installment schedule for a package | Auth, Gate 1 | `psy_kob_installment_checkpoints`, `psy_kob_sessions`, `psy_payments`; edge fn `payments-initiate` |
| `/roles/patient/payment-receipt.html` | payment-receipt.html | Payment-confirmation page keyed by `?ref=` (e.g. HitPay redirect target) | **PUBLIC — no auth at all** | edge fn `payment-receipt-public` only |
| `/roles/patient/resit.html` | resit.html | Single receipt lookup/detail | Auth, Gate 1 | `psy_payments` |
| `/roles/patient/sejarah-pembayaran.html` | sejarah-pembayaran.html | Full payment history list | Auth, Gate 1 | `psy_payments` |
| `/roles/patient/vouchers.html` | vouchers.html | Claimable discount vouchers & points | Auth, Gate 2 | `psy_point_rewards`, `psy_points_balance`, `psy_promo_claims` |
| `/roles/patient/shop.html` | shop.html | À-la-carte product shop | Auth, Gate 2 | `psy_inventory_items`, `psy_products`, `psy_promo_claims`, `psy_promo_codes` |
| `/roles/patient/checkout.html` | checkout.html | **Orphan mockup** — explicit dev comment "statik — versi akhir guna shared/navbar.js"; no auth, no Supabase includes, no DB calls, no inbound links from anywhere | N/A (unwired) | none |
| `/roles/patient/orders.html` | orders.html | Order & delivery tracking for shop purchases | Auth, Gate 2 | `psy_orders` |
| `/roles/patient/vitals.html` | vitals.html | Health vitals/measurements log | Auth, Gate 2 | `psy_treatment_plans`, `psy_vitals` |
| `/roles/patient/plan.html` | plan.html | Treatment plan overview (BPS-S, 4 pillars) | Auth, Gate 2 | `psy_appointments`, `psy_clinic_closures`, `psy_kob_slot_config`, `psy_packages`, `psy_plan_weekly_progress`, `psy_treatment_plans` |
| `/roles/patient/plan-week.html` | plan-week.html | Detail of one week's plan (sessions, reschedule/absence) | Auth, Gate 2 | `psy_feedback`, `psy_packages`, `psy_patient_documents`, `psy_patient_reaksi_reports`, `psy_plan_compliance`, `psy_plan_week_overrides`, `psy_plan_weekly_progress`, `psy_reaksi_item`, `psy_reaksi_kategori`, `psy_treatment_plans`, `psy_vitals` |
| `/roles/patient/routine.html` | routine.html | Daily schedule + compliance history | Auth, Gate 2 | `psy_daily_completions`, `psy_packages`, `psy_patients` |
| `/roles/patient/kepatuhan.html` | kepatuhan.html | Daily compliance checklist ("Catatan Harian") | Auth, Gate 1 | `psy_auto_messages`, `psy_daily_checkins`, `psy_kepatuhan_item`, `psy_kepatuhan_log`, `psy_patients`, `psy_profiles`, `psy_reaksi_action_map`, `psy_reaksi_advice_log`, `psy_reaksi_item`, `psy_reaksi_kategori`, `psy_treatment_plans`; edge fn `reaksi-advice-send` |
| `/roles/patient/kepatuhan-flow-preview.html` | kepatuhan-flow-preview.html | **Orphan mockup** — mobile-flow UI preview for the daily checklist, no auth, no backend, no inbound links | N/A (unwired) | none |
| `/roles/patient/checkin.html` | checkin.html | Daily mood/wellbeing poll | Auth, Gate 1 | `psy_daily_checkins` |
| `/roles/patient/rekod-perubatan.html` | rekod-perubatan.html | Medical records list (X-Ray/MRI/CT/DNA reports) | Auth, Gate 2 | `psy_appointments`, `psy_dna_test_process`, `psy_medical_reports` |
| `/roles/patient/rekod-detail.html` | rekod-detail.html | Single medical record detail + comments | Auth, Gate 2 | `psy_medical_report_comments`, `psy_medical_reports` |
| `/roles/patient/rekod-tambah.html` | rekod-tambah.html | Add/upload new medical record | Auth, Gate 2 | `psy_medical_reports` |
| `/roles/patient/library.html` | library.html | Knowledge/content library listing | Auth, Gate 2 | `psy_library_bookmarks`, `psy_library_items`, `psy_library_views`, `psy_packages` |
| `/roles/patient/library-detail.html` | library-detail.html | Single library item content | Auth, Gate 2 | `psy_library_bookmarks`, `psy_library_feedback`, `psy_library_items`, `psy_packages` |
| `/roles/patient/faq.html` | faq.html | Standard FAQ page (nav-linked) | Auth, Gate 2 | `psy_library_feedback`, `psy_library_items` |
| `/roles/patient/faq-overhaul.html` | faq-overhaul.html | Alternate FAQ page for KOB/"Overhaul Body" treatment — **unreferenced anywhere else in the repo**, looks superseded by `faq.html` | Auth | `psy_faq_items`, `psy_faq_sections` |
| `/roles/patient/events.html` | events.html | Community events/classes listing | Auth, Gate 2 | `psy_event_registrations`, `psy_events` |
| `/roles/patient/event-detail.html` | event-detail.html | Single event detail + registration | Auth, Gate 2 | `psy_event_materials`, `psy_event_registrations`, `psy_events` |
| `/roles/patient/announcements.html` | announcements.html | Clinic announcements/news feed | Auth, Gate 2 | `psy_announcements` |
| `/roles/patient/issue.html` | issue.html | Report a product/appointment issue | Auth, Gate 2 | `psy_audit_log` (no dedicated issues table) |
| `/roles/patient/issue-thread.html` | issue-thread.html | Conversation thread for a reported issue | Auth, Gate 2 | `psy_audit_log` |
| `/roles/patient/feedback.html` | feedback.html | Treatment feedback form | Auth, Gate 2 | `psy_audit_log`, `psy_feedback`, `psy_plan_weekly_progress`, `psy_treatment_plans` |
| `/roles/patient/pulangan.html` | pulangan.html | Honey-bottle return tracker | Auth, Gate 2 | `psy_audit_log`, `psy_bottle_returns` |
| `/roles/patient/surat.html` | surat.html | Official letter requests list + download | Auth, Gate 2 | `psy_audit_log`, `psy_letter_issued`, `psy_letter_request_attachments`, `psy_letter_requests`, `psy_letter_templates` |
| `/roles/patient/surat-detail.html` | surat-detail.html | Single letter-request detail | Auth, Gate 2 | same as above |

### Staff routes (`roles/staff/`, 131 files)

Every staff page calls `initStaff(pageId, titleSub[, rbacId])` (`roles/staff/_shared.js:7`), which requires a Supabase session **and** `psy_profiles.role === 'staff'` (`shared/authGuard.js:1-22`) — any other role is signed out and redirected to login. On top of that, a database-driven RBAC system gates each page by module: `window.pageAllowed(permId)` (`shared/authGuard.js:127-130`) looks up the page's module in `window.PAGE_MODULE` (`shared/authGuard.js:44-125`) and checks `can(module,'view')` against `psy_user_effective_permissions`, which is configured per-role in `roles/staff/peranan.html`. `staff_role === 'super_admin'` bypasses all module checks (`shared/authGuard.js:148`). Individual buttons are further gated with `data-rbac="module.action"` attributes, auto-hidden by an observer for non-privileged users (`shared/authGuard.js:158-182`).

Given the size (131 files), the full page-by-page table is grouped by feature area below rather than reproduced in full; every page in this list is **staff-authenticated**, and "RBAC module" indicates the permission gate. Two file naming ranges were separately verified in detail by different research passes; row-level citations exist for every page (`roles/staff/<file>.html:<line>` for its `initStaff(...)` call).

| Feature area | Pages | RBAC module(s) | Notes |
|---|---|---|---|
| Dashboard | `dashboard.html` | none (open to all staff) | Main KPI/alerts landing page |
| Patients | `patients.html`, `patient-form.html`, `patient-hub.html` (largest file in the repo, ~6,800 lines), `progres-pesakit.html` | `psy_patients`, `progres_pesakit` | `patient-hub.html` is the full per-patient management console; several destructive actions inside it are hard-coded `super_admin`-only in addition to RBAC (`patient-hub.html:6458,6752`) |
| KYC/registration review | `assignment-review.html` | `coaching` | `assignments.html` is a **dead redirect stub** → `patients.html?tab=unassigned` |
| KOB (intake consultation) | `kob-list.html`, `kob-detail.html`, `kob-report.html`, `kob-sign.html`, `kob-slots.html` | `kob`, `kob_slots` | `kob-sign.html` and `kob-report.html` are new/untracked in git status but functionally complete (in-clinic e-signature capture and a conversion report, respectively) |
| Treatment plans / scheduling | `plans.html`, `plan-week.html` (~3,450 lines), `weekly-plan.html`, `appointments.html`, `kehadiran.html` | `coaching`, `plan_week`, `schedule`, `kehadiran` | `closures.html` is a **dead redirect stub** → `appointments.html` |
| Packages | `pakej.html`, `pakej-detail.html`, `pakej-edit.html`, `pakej-laporan.html`, `pakej-report.html` | `pakej`, `pakej_laporan` | list/detail/report triad, not duplicates |
| Payments | `payment-admin.html`, `payment-ledger.html` | `payment` | `payment-ledger.html` reads a DB view `vw_payment_ledger` combining direct payments with the GHL transaction mirror |
| Vitals | `vitals.html`, `vitals-detail.html`, `vitals-history.html` | `vitals` | |
| Compliance | `kepatuhan.html`, `kepatuhan-fill.html` | `kepatuhan` | |
| Reaksi & Tindakan (advice engine) | `reaksi-item.html`, `reaksi-laporan.html`, `reaksi-preview.html` | `reaksi` (rbacId `reaksi_advice`) | |
| Sesi 1:1 | `sesi-1on1.html`, `sesi-1on1-detail.html`, `sesi-1on1-form.html` | `rujukan` | |
| Clinical events (peristiwa) | `peristiwa.html`, `peristiwa-baru.html`, `peristiwa-detail.html`, `lawatan-detail.html` | `peristiwa` | `lawatan.html` and `peristiwa-kalendar.html` are **dead redirect stubs** (→ `peristiwa.html?view=visits` and `appointments.html` respectively) |
| Inventory & suppliers | `inventory.html`, `inventory-detail.html`, `inventory-overview.html`, `item-form.html`, `stock-alerts.html`, `stock-in.html`, `stock-movement.html`, `suppliers.html`, `supplier-detail.html`, `supplier-edit.html`, `kit-prosedur.html`, `kit-edit.html` | `inventory` | |
| Purchase requests | `purchase-requests.html`, `purchase-request-detail.html`, `purchase-request-form.html` | `inventory` | Purchase *Orders* module was built then deliberately removed (see Section 3) |
| Products / shop | `products.html`, `product-detail.html`, `product-edit.html`, `product-select-inventory.html`, `orders.html`, `promo-codes.html`, `point-rewards.html` | `products` | |
| Letters (surat) | `surat.html`, `surat-templates.html`, `surat-template-detail.html`, `surat-edit.html`, `surat-preview.html`, `surat-issue.html`, `surat-request.html`, `surat-request-new.html`, `surat-request-detail.html`, `surat-management-review.html` | `surat` (some intentionally **not** RBAC-registered — open to all staff, see `shared/authGuard.js:101-108`) | `surat-issue.html` confirmed still live/active, not deprecated; old `?req=` URL param removed, replaced by the request/review flow |
| Knowledge Base | `kb-dashboard.html`, `kb-resources.html`, `kb-detail.html`, `kb-categories.html`, `kb-upload.html`, `kb-version.html`, `kb-bookmarks.html`, `kb-notes.html`, `kb-training.html`, `kb-admin.html` | `kb` | |
| Announcements & events | `announcements.html`, `announcement-detail.html`, `pengumuman-baru.html`, `pengumuman-edit.html`, `events.html`, `acara-baru.html`, `acara-detail.html`, `acara-edit.html` | `announcements`, `events_admin` | |
| Automations & messaging | `automations.html`, `automation-dashboard.html`, `automation-builder.html`, `automation-detail.html`, `automation-audience.html`, `automation-logs.html`, `automation-queue.html`, `auto-mesej.html`, `variables-library.html`, `test-automation.html`, `inbox.html` | `auto_messages`, `announcements` | `test-automation.html` is a real RBAC-gated QA tool (sends real prefixed test WhatsApp messages), not a dev scaffold; `inbox.html` is the staff WhatsApp inbox, entirely edge-function-backed (no direct table reads) |
| DNA test | `dna-test.html`, `dna-test-list.html` | `dna_test` | |
| Emergency | `emergency.html` | `emergency` | Red Emergency Protocol monitoring queue |
| Affiliate / rewards | `affiliate.html`, `point-rewards.html`, `pulangan.html` | `affiliate`, `products`, `pulangan` | |
| Staff & RBAC admin | `staff_management.html`, `staff-detail.html`, `staff-stats.html`, `profile.html`, `peranan.html`, `audit-kebenaran.html`, `audit.html`, `governance.html` | `staff`, `staff_stats`, `profile`, `rbac`, `audit` | `peranan.html` and `audit-kebenaran.html` are **hard-coded `super_admin`-only**, on top of / bypassing normal RBAC |
| Settings | `tetapan.html` | `settings` | Hard-coded `super_admin`-only in addition to RBAC (`tetapan.html:961-966`) — double-locked |
| Services & coaching catalog | `services.html`, `service-detail.html`, `coaching.html`, `coaching-catalog.html` | `operations`, `coaching` | |
| Issues/feedback | `issue.html`, `issue-detail.html`, `feedback.html` | `issue` | `issue.html` has no dedicated table — implemented on filtered `psy_audit_log` rows |
| Library (staff-facing) | `library.html`, `library-view.html`, `library-detail.html`, `library-edit.html`, `library-categories.html`, `library-faq-edit.html`, `faq-overhaul.html` | `library` | `library-categories.html` is hard-coded `super_admin`-only |

**Auth summary (all routes):**
- **Reachable without login:** only `/roles/patient/payment-receipt.html` (intentional, token-gated by `?ref=`) plus the three inert/unwired pages (`landing-preview.html`, `checkout.html`, `kepatuhan-flow-preview.html`) which have no auth code simply because they are disconnected mockups, not real public routes.
- **Role-specific areas:** yes — `roles/patient/` vs `roles/staff/` is enforced by `psy_profiles.role`, and within staff, a further `staff_role` (super_admin/admin/doctor/coach/manager) plus a fine-grained module×action RBAC matrix (`psy_user_effective_permissions`) gates individual pages/buttons (see Section 5 for full detail).
- **Routes likely to change soon:** the four dead redirect stubs (`assignments.html`, `closures.html`, `lawatan.html`, `peristiwa-kalendar.html`) are candidates for deletion; `kob-report.html`/`kob-sign.html` are freshly added and still uncommitted per git status; `faq-overhaul.html` (patient) looks superseded by `faq.html` but wasn't removed.

---

## Section 2 — Component and UI inventory

- **Structure:** no component framework — each `.html` file is a full, independent document. Reuse happens through **shared JavaScript files loaded via `<script>` tags**, not templates or includes:
  - `shared/authGuard.js` (9,894 bytes) — auth/RBAC gate logic, shared by every patient and staff page.
  - `shared/navbar.js` (59,453 bytes) — renders the role-appropriate sidebar/top navigation into the DOM at runtime (large — it's effectively the whole nav data structure + rendering logic for both roles).
  - `shared/theme.js` (7,019 bytes) — Tailwind config object, dark-mode CSS injection, runtime brand-colour override.
  - `shared/supabase.js` (204,619 bytes) — a locally vendored, minified copy of the `@supabase/supabase-js` browser SDK bundle (not hand-written code).
  - `shared/i18n.js` + `shared/i18n-dict.js` + `shared/i18n-dict-ms.js` — the bilingual text-substitution engine (see Section 9).
  - `roles/patient/_shared.js` and `roles/staff/_shared.js` — per-role bootstrap helpers (`initPatient()`, `initStaff()`) wrapping `authGuard.js`.
  - `roles/staff/_kb.js` — shared data-access helper specifically for the Knowledge Base pages.
  - Smaller single-purpose helpers: `shared/adherence.js`, `shared/inventoryDeduct.js`, `shared/inventoryForecast.js`, `shared/inventoryStock.js`, `shared/inventoryUnits.js`, `shared/letterTemplates.js`, `shared/receipt.js`, `shared/referral.js`, `shared/settings.js`, `shared/stockSync.js`, `shared/pwa.js`, `shared/utils.js`, `shared/logout.js`, `shared/defaultAgreement.js`, `shared/defaultDailySchedule.js`, `shared/hk1.js`.
  - Two small role-scoped CSS files, `roles/staff/_styles.css` and `roles/patient/_styles.css`, define the sidebar-accent CSS custom properties (`--rp`, `--rpm`, `--rpa`, `--rpl`, `--rptx`) and a handful of hand-rolled component classes (`.chip`, `.stepper-dot`, `.sidebar-toggle-fab`).
  - There is **no HTML partial/include system** (no server-side includes, no client-side templating) — every page's `<head>`/nav markup is repeated inline per file, with only the *behavior* (not the markup) shared via JS.

- **Styling approach:** **Tailwind CSS, loaded from the CDN at runtime** (`<script src="https://cdn.tailwindcss.com">`, e.g. `auth/login.html:8`), not a build-time Tailwind install (no `tailwind.config.js` file, no PostCSS pipeline, confirmed — no such config file exists in the repo). Per-page, a small JS object is assigned to `tailwind.config` (sourced from `shared/theme.js:1-20`) to extend the colour palette and font family. Beyond that, styling is inline Tailwind utility classes directly in the markup, plus the two small `_styles.css` files above for a handful of custom components. There is no CSS Modules, no styled-components, no separate design-system package.

- **Component/template count (approximate):** ~180 page-level "templates" (the HTML files themselves), no smaller reusable component library beneath that — reuse is at the shared-JS-behavior level (nav, auth, theme) rather than the markup-component level. `shared/navbar.js` is the closest thing to a single large reusable UI component (it renders the entire sidebar/nav for both roles).

- **Ten most-reused pieces of "UI logic"** (by how many pages load them):
  1. `shared/supabase.js` — Supabase client bootstrap, loaded on nearly every page.
  2. `shared/authGuard.js` — auth/RBAC gate, loaded on every protected page.
  3. `shared/navbar.js` — sidebar/topbar navigation, loaded on every patient/staff page.
  4. `shared/theme.js` — Tailwind config + dark mode, loaded on every page.
  5. `shared/i18n.js` (+ the two dict files) — bilingual text substitution, loaded on most pages.
  6. `roles/patient/_shared.js` — patient auth/KYC-gate bootstrap.
  7. `roles/staff/_shared.js` — staff auth/RBAC bootstrap.
  8. `roles/staff/_styles.css` / `roles/patient/_styles.css` — sidebar accent tokens + small component classes.
  9. `shared/pwa.js` — PWA/service-worker registration helper.
  10. `config/supabase.js` — environment-specific Supabase URL/key selection + a small `dbQuery`/`dbInsert`/`dbUpdate`/`dbDelete`/`auditLog` query-helper API used across most pages.

- **Design system:** No formal design system or component library exists. Colour and font tokens are centralized in `shared/theme.js` (see Section 6), but spacing, radii, shadows, and most typography sizing are ad hoc Tailwind utility classes chosen per element, with no documented scale.

---

## Section 3 — Data model

**Provider: Supabase (Postgres).** Confirmed by: `UUID PRIMARY KEY DEFAULT gen_random_uuid()` used ~110 times across `database/schema/*.sql`; `psy_profiles.id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE` (`database/schema/02_profiles_staff.sql:12`) plus a trigger on `auth.users` insert (`02_profiles_staff.sql:88-90`); `storage.buckets`/`storage.objects` policies (`database/schema/24_storage.sql`); pervasive Postgres Row Level Security (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY` + `CREATE POLICY`, ~430 occurrences); `auth.uid()`/`auth.role()` used throughout RLS predicates (e.g. `database/schema/03_rbac_security.sql:21-32`).

### Source of truth

`database/schema/` contains **36 domain files** (`02_profiles_staff.sql` through `38_automation_recipient.sql`, numbering skips 01 and 33), holding **117 `CREATE TABLE` statements**, all named `psy_*`. `database/master_migration.sql` (8,716 lines) is a **generated** concatenation of these files, produced by `database/_generate_master.py` — it must never be hand-edited (per its own docstring).

### Entity list (grouped by domain file — abbreviated; full column lists are in the schema files themselves)

| Domain file | Key tables | Purpose |
|---|---|---|
| `02_profiles_staff.sql` | `psy_profiles` | Identity root — one row per `auth.users` entry, `role` (patient/staff), `staff_role` |
| `03_rbac_security.sql` | `psy_audit_log`, `psy_roles`, `psy_modules`, `psy_actions`, `psy_module_actions`, `psy_role_module_actions`, `psy_user_overrides`, `psy_permission_audit`, view `psy_user_effective_permissions` | Generic audit trail + full module×action RBAC matrix |
| `04_patients.sql` | `psy_patients`, `psy_kyc_submissions`, `psy_patient_notes`, `psy_patient_documents` | Core patient record — `mrn`, `status`, `kob_status`, `coach_id`, `active_package_id` (see relationship note below) |
| `05_packages.sql` | `psy_packages`, `psy_package_purchases`, `psy_package_categories`, `psy_continuity_offers` | Treatment package definitions, 4-tier pricing, purchase records |
| `06_payments.sql` | `psy_payments`, `psy_orders`, `psy_ghl_transactions` | Payment ledger, shop delivery orders, mirrored GHL transaction ledger |
| `07_treatment_plans.sql` | `psy_treatment_plans`, `psy_plan_weekly_progress`, `psy_plan_check_ins`, `psy_plan_compliance`, `psy_plan_week_overrides`, `psy_supply_disbursements` | Treatment plan + weekly session engine |
| `08_sessions_scheduling.sql` | `psy_appointments`, `psy_coaching_sessions`, `psy_clinic_closures`, `psy_slot_date_overrides`, `psy_coaching_catalog`, `psy_services` | Scheduling (note: `psy_soap_notes` was dropped in a 20260626 migration and is not recreated) |
| `09_kob.sql` | `psy_kob_sessions`, `psy_kob_installment_checkpoints`, `psy_kob_agreements`, `psy_kob_slot_config` | KOB intake consultation workflow + e-signature agreement |
| `10_vitals.sql` | `psy_vitals` | BP/HR/SpO2/temp/weight/BMI readings |
| `11_checkins_kepatuhan.sql` | `psy_daily_checkins`, `psy_daily_completions`, `psy_kepatuhan_item`, `psy_kepatuhan_log`, `psy_kepatuhan_weekly` | Daily check-ins + compliance scoring |
| `12_reaksi.sql` | `psy_reaksi_item`, `psy_reaksi_kategori`, `psy_reaksi_actions`, `psy_reaksi_action_map`, `psy_reaksi_advice_log`, `psy_patient_reaksi_reports` | "Reaksi & Tindakan" symptom→advice engine |
| `13_library_faq.sql` | `psy_library_items`, `psy_library_bookmarks`, `psy_library_feedback`, `psy_library_views`, `psy_library_categories`, `psy_faq_sections`, `psy_faq_items` | Patient-facing content library + FAQ |
| `14_products_inventory.sql` | `psy_inventory_items`, `psy_inventory_requests`, `psy_inventory_request_items`, `psy_products`, `psy_procedure_kits`, `psy_bottle_returns` | Internal inventory + shop products (separate entities) |
| `15_letters.sql` | `psy_letter_templates`, `psy_letter_requests`, `psy_letter_issued`, `psy_letter_request_attachments`, `psy_letter_auto_fields` | Official letter system |
| `16_medical_records.sql` | `psy_medical_reports`, `psy_medical_report_comments` | Patient-uploaded medical reports (renamed from `psy_dna_reports`) |
| `17_whatsapp.sql` | `psy_wa_conversations`, `psy_wa_messages` | Mirror of GoHighLevel WhatsApp conversations |
| `18_notifications_automations.sql` | `psy_notifications`, `psy_emergency_alerts`, `psy_auto_messages`, `psy_automations`, `psy_notification_logs`, `psy_audiences`, `psy_adherence_alerts`, `psy_risk_alerts`, `psy_coach_tasks` | Largest domain file — notifications, emergency protocol, two parallel automation systems |
| `19_events_announcements.sql` | `psy_announcements`, `psy_events`, `psy_event_registrations`, `psy_event_materials`, `psy_announcement_categories`, `psy_announcement_types` | |
| `20_referrals.sql` | `psy_referrals`, `psy_clinical_referrals` | Patient-referral rewards + internal staff referrals (only the latter is still used, via Sesi 1:1) |
| `21_feedback.sql` | `psy_feedback`, `psy_weekly_feedback` | |
| `22_knowledge_base.sql` | `psy_kb_categories`, `psy_kb_resources`, `psy_kb_versions`, `psy_kb_bookmarks`, `psy_kb_views`, `psy_kb_note_folders`, `psy_kb_notes`, `psy_kb_trainings`, `psy_kb_training_progress`, `psy_kb_certificates` | Internal staff Knowledge Base |
| `23_settings.sql` | `psy_settings` | Global key/value (JSONB) settings store |
| `24_storage.sql` | (Supabase `storage.buckets`/`storage.objects` policies only, no `psy_*` tables) | |
| `25_patient_events.sql` | `psy_patient_events`, `psy_patient_event_visits`, `psy_patient_event_logs`, `psy_patient_event_docs` | Hospitalization/ICU/death tracking |
| `26_dna_test.sql` | `psy_dna_test_process` | Single wide table modeling the 6-step DNA test wizard |
| `27_affiliate.sql` | `psy_affiliate_commission_rules`, `psy_affiliate_payouts` | |
| `28_rewards.sql` | `psy_vouchers` | Generic RM voucher ledger, fed by multiple reward source types |
| `29_promo_codes.sql` / `30_promo_claims.sql` | `psy_promo_codes`, `psy_promo_redemptions`, `psy_promo_claims` | Two deliberate layers: typed-at-checkout codes vs. claimed-to-wallet codes |
| `31_points.sql` | `psy_points_ledger`, `psy_point_rewards` | Signed points ledger — no client INSERT policy, write-only via trigger/RPC |
| `32_suppliers.sql` | `psy_suppliers`, `psy_supplier_contacts`, `psy_supplier_documents` | |
| `34_inventory_locations.sql` | `psy_inventory_locations`, `psy_inventory_stock_by_location` | Multi-warehouse stock, auto-aggregated to `psy_inventory_items.qty_in_stock` via trigger |
| `35_stock_in.sql` | `psy_stock_in_records`, `psy_stock_in_items`, `psy_stock_in_documents` | Batch/expiry-tracked goods receipt |
| `36_stock_movements.sql` | `psy_stock_movements` | Append-only stock ledger |
| `37_automation_sequences.sql` | `psy_automation_messages` | Multi-message day-by-day automation sequences |
| `38_automation_recipient.sql` | (column addition only — `recipient` on `psy_automation_messages`) | |

### Row Level Security

RLS is enabled on effectively every table. Recurring patterns:
1. **Own-record self-access (patient):** `patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())` — e.g. `psy_payments` (`06_payments.sql:44-53`), `psy_treatment_plans` (`07_treatment_plans.sql:44-56`), `psy_appointments` (`08_sessions_scheduling.sql:35-45`).
2. **Staff-wide access:** `EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')` or a SECURITY DEFINER helper `public.isw_is_staff()` (`03_rbac_security.sql:21-34`) — grants staff full CRUD on most operational tables.
3. **Super-admin-only writes** on RBAC/settings tables via `staff_role = 'super_admin'` checks (`03_rbac_security.sql:108-111,131-134,151-154,219-222`).
4. **Own-user-record (non-patient):** `user_id = auth.uid()` — used for KB/library bookmarks, notes, training progress.
5. **No client INSERT at all** on some tables — write only via trigger/RPC to prevent forgery, e.g. `psy_points_ledger` (`31_points.sql:27-28`, comment: prevents patients forging their own points).
6. **Storage object policies** mirror the patient/staff split using `storage.foldername(name)` path parsing (`24_storage.sql:93-108,128-156`).
7. **Public/permissive reads** for catalog data — e.g. `psy_packages` SELECT is `USING (true)` for everyone (`05_packages.sql:91-93`).

### Relationships

- `psy_profiles.id` → `auth.users.id` (1:1 identity root).
- `psy_patients.user_id` → `psy_profiles.id` (unique, 1:1); `psy_patients.coach_id` → `psy_profiles.id`.
- **`psy_patients.active_package_id` is a loose `TEXT` reference, not a foreign key** to `psy_packages.id` (`04_patients.sql:46`) — confirmed inconsistent across environments (testing stores a UUID, production stores a human-readable code like `OBDY1`); any query joining on it must match both `psy_packages.id` and `psy_packages.package_id`.
- `psy_treatment_plans.patient_id` → `psy_patients.id`; `psy_plan_weekly_progress.plan_id` → `psy_treatment_plans.id` (also carries a denormalized `patient_id`).
- `psy_kob_sessions.patient_id` → `psy_patients.id`; installment checkpoints are reconciled against summed `psy_payments` rows rather than a direct FK.
- `psy_inventory_stock_by_location.item_id` → `psy_inventory_items.id`, aggregated back to `psy_inventory_items.qty_in_stock` via a Postgres trigger (`psy_sync_item_stock_total`) — application code must never write `qty_in_stock` directly.
- `psy_stock_movements.reference_type`/`reference_id` is a polymorphic soft-reference (not an FK) to whichever table caused the movement.
- Some tables deliberately declare a bare `UUID` column with the FK constraint added later in the same file (an intentional cross-file FK-patching pattern to avoid forward-reference ordering issues), e.g. `psy_supply_disbursements.item_id` and `psy_continuity_offers.plan_id`.

### Migrations

- **Primary source of truth:** `database/schema/*.sql` (36 domain files).
- **Generated aggregate:** `database/master_migration.sql`, produced by `database/_generate_master.py` — never hand-edited.
- **Incremental live migrations:** `supabase/migrations/*.sql`, one file per dated change. Per `supabase/migrations/README.md`, migrations up to `20260730` have already been folded back into `database/schema/` and deleted from this folder; only later files remain.
- **Confirmed drift:** `psy_kob_installments` (created by `supabase/migrations/20260813_installment_payments.sql`) is **not yet reflected** in `database/schema/09_kob.sql` — a real gap between "source of truth" and the live database that the mobile team should be aware of before trusting `database/schema/` as 100% current. (`psy_hk1_slot_config` was also created then dropped one day later, correctly reconciled to nothing.)
- **Two untracked, not-yet-run SQL files** exist in git status: `database/normalize_inventory_units.sql` (data-migration to standardize 16 unit values + add a CHECK constraint, per the "Inventory unit standardization" work) and `database/fix_obpx1plus_audit_label.sql` (a one-row audit-log label correction). Neither has been run yet per project tracking.
- **Purchase Orders module was built then deliberately dropped:** `supabase/migrations/20260830_purchase_orders_module.sql` created `psy_purchase_orders`/`psy_purchase_order_items`; `20260831_drop_purchase_orders_module.sql` removed them the next day (staff buy supplies directly after a Purchase *Request* is approved, rather than issuing formal POs). Correctly absent from `database/schema/`.

---

## Section 4 — API surface

The frontend talks to the Supabase Postgres database **directly** via the Supabase JS SDK's PostgREST wrapper (`window.db.from('table')...`) — plain HTTPS with a bearer JWT, governed entirely by Postgres RLS (Section 3). This pattern is used on nearly every page (hundreds of call sites; example: `roles/patient/dashboard.html:474,482,505`, `auth/auth.js:63`). **A mobile client could call the same PostgREST endpoints directly** using the Supabase SDK for React Native/Expo with the same project URL and anon key, subject to the same RLS policies.

In addition, 17 **Supabase Edge Functions** (Deno/TypeScript, one directory per function under `supabase/functions/`) handle logic that needs a service-role key, an external API secret, or cross-record orchestration that must not run under the caller's own RLS-scoped JWT. There is no `supabase/config.toml` in the repo, so each function's JWT-verification requirement is enforced in its own code rather than declared centrally.

| Endpoint | Method | Called from | Request shape | Response shape | Auth required |
|---|---|---|---|---|---|
| `automations-runner` | POST | Not called from any page — cron-only (pg_cron, every 15 min) | `{}` | `{success, scheduled[], sequences[]}` | `x-cron-secret` header (`CRON_SECRET`) |
| `dna-test-email-report` | POST | `roles/staff/dna-test.html:991` | `{process_id}` | `{success, sent_to}` | JWT + `psy_profiles.role==='staff'` |
| `event-reminders` | POST | Not called from any page — cron-only, every 15 min, runs 10 sub-jobs (reminders, broadcasts, checklist alerts, installment overdue, etc.) | `{}` | `{success, ...per-subjob counts}` | `x-cron-secret` (`CRON_SECRET`) |
| `ghl-booking-webhook` | POST | External — called by a GoHighLevel Workflow, not by this frontend | `{event?, phone, full_name, ...}` | `{success, event, patient_id, ...}` | `?secret=`/`x-ghl-booking-secret` (`GHL_BOOKING_WEBHOOK_SECRET`), no JWT |
| `ghl-inbox` | POST (`action` param: list/messages/patient/send/media/…) | `roles/staff/kob-detail.html:2273`, `inbox.html:426`, `plan-week.html:1189`, `patient-hub.html:2029,4835`, `sesi-1on1-detail.html:327`, `test-automation.html:193` | `{action, conversationId?, message?, ...}` | Varies by action | JWT + `psy_profiles.role==='staff'` |
| `ghl-inbox-webhook` | POST | External — GHL webhook on new WhatsApp message | `{conversationId}` | `{success, conversationId, messages, unread}` | `?secret=`/`x-wa-secret` (`WA_WEBHOOK_SECRET`), no JWT |
| `ghl-initial-sync` | POST (`action`: contacts/appointments/orders) | Not called from any page — manual one-time backfill | `{action, cursor?, ...}` | `{processed, total, errors[], hasMore}` | JWT + `staff_role==='super_admin'` |
| `ghl-pull-sync` | POST | Not called from any page — cron-only (~15 min) | `{}` | Not fully inspected — returns processed/skipped counts | `x-cron-secret` (`GHL_PULL_CRON_SECRET`) |
| `ghl-transactions-sync` | POST | Not called from any page — cron-only, full pull of GHL transactions into `psy_ghl_transactions` | `{}` | `{success, totalCount, synced, errors[]}` | `x-cron-secret` (`GHL_PULL_CRON_SECRET`) |
| `invite-staff` | POST | `roles/staff/staff-detail.html:278`, `staff_management.html:242` | `{email, full_name, staff_role, ...}` | `{success, user_id, message}` | JWT + `staff_role` in `admin/manager/super_admin` |
| `payment-receipt-public` | POST | `roles/patient/payment-receipt.html:159` | `{ref}` | `{found, status, total, pdfUrl, ...}` | **Public — no auth**, token-gated by `ref` only |
| `payments-initiate` | POST | `roles/patient/payment.html:785`, `payment-plan.html:67`, `kob.html:2149`, `roles/staff/patient-hub.html:2850,4630` | `{items[], patientId?, promoCode?, returnUrl}` | `{ok, checkoutUrl, receiptRef, ...}` | JWT (any authenticated user) |
| `payments-kob-initiate` | POST | `roles/staff/kob-detail.html:2302,2344`, `patient-hub.html:4850` | `{kobSessionId, mode, tier?, returnUrl}` | `{ok, checkoutUrl, receiptRef, amount}` | JWT + `psy_profiles.role==='staff'` |
| `payments-send-receipt` | POST | `roles/staff/patient-hub.html:4934` | `{paymentId}` | `{ok: true}` | JWT + `psy_profiles.role==='staff'` |
| `payments-webhook` | POST | External — HitPay gateway server-to-server callback | Gateway-defined | `{ok, note?}` | HMAC signature (`HITPAY_SALT`), no JWT |
| `reaksi-advice-send` | POST (dual mode) | `roles/patient/kepatuhan.html:1660` (direct mode) | `{advice_id}` or `{}` (cron mode) | Not fully inspected | Direct: JWT. Cron: `x-cron-secret` |
| `sync-ghl` | POST | External — triggered by a Supabase Database Webhook on `psy_patients` change | DB webhook payload | Not fully inspected | `x-sync-secret` (`SYNC_WEBHOOK_SECRET`) |
| `whatsapp-inbox` | N/A | **Not deployed** — directory contains only a `PLAN.md`, no `index.ts`; superseded by `ghl-inbox`/`ghl-inbox-webhook` | — | — | — |

**Other findings:**
- **CORS:** wide open on every function — `Access-Control-Allow-Origin: '*'` (shared definition at `supabase/functions/_shared/cors.ts:1-5`, duplicated inline in most `index.ts` files). This imposes no client-origin restriction; the only real access control is the auth/secret checks listed above.
- **Rate limiting:** none found in the application code. `UNKNOWN` whether Supabase's platform-level rate limits apply, since nothing in-repo configures them.
- **Auth mechanisms used, in summary:** (1) Supabase JWT via `Authorization: Bearer <token>` + `auth.getUser()`, usually followed by a `psy_profiles.role`/`staff_role` check; (2) custom shared-secret headers for cron/webhook calls (`x-cron-secret`, `x-ghl-booking-secret`, `x-wa-secret`, `x-sync-secret` — four different secret env vars); (3) HMAC signature verification for the HitPay payment webhook; (4) token-only (no auth) for the public receipt lookup, by design.
- **Repo hygiene note:** `supabase/functions/event-reminders/_paste_this.ts` and `supabase/functions/invite-staff/_paste_this.ts` are older, functionally different scratch copies (not the deployed `index.ts`) — likely dashboard-paste artifacts left in the repo. Not live endpoints.

---

## Section 5 — Authentication

- **Provider: Supabase Auth**, confirmed directly. Sign-in: `window.db.auth.signInWithPassword({email, password})` (`auth/auth.js:27`). Signup: `window.db.auth.signUp({email, password, options:{data:{full_name, role}}})` (`auth/auth.js:137-143`). Password update: `window.db.auth.updateUser({password})` (`auth/reset.html:95`, `auth/set-password.html:112`). Admin-side account creation: `adminClient.auth.admin.inviteUserByEmail(...)` / `createUser(...)` inside the `invite-staff` edge function.

- **Session representation & lifetime:** Standard Supabase Auth JWT + refresh-token pair, stored in browser `localStorage` — this is the SDK's default behavior, confirmed by reading the actual client init: `config/supabase.js:29` calls `window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY)` with **no options object**, so no custom storage adapter overrides the default (`persistSession: true`, `autoRefreshToken: true`, `detectSessionInUrl: true`). Access tokens are short-lived (Supabase default ~1 hour) and silently refreshed by the SDK as long as the refresh token remains valid. No custom cookie-session mechanism exists anywhere in `auth/`, `config/`, or `shared/`.

- **Could a website account sign in from a mobile app without re-registering? Yes.** This is unmodified Supabase Auth against the same project (same `SUPABASE_URL`/anon key pair are defined per-environment in `config/supabase.js:1-12`) — accounts live in Supabase's own `auth.users` table, not an ISW-specific session store. A mobile app using any official Supabase SDK (or a raw call to `/auth/v1/token?grant_type=password`) against the same project would authenticate the same account.

- **Sign-in methods:** **Email + password only.** No `signInWithOtp`, `signInWithOAuth`, or phone-based sign-in calls exist anywhere in the repo (confirmed by search). Signup is also email+password only.

- **Roles and permission levels — two-tier model:**
  1. **Top-level `psy_profiles.role`:** `'patient'` or `'staff'`. Enforced by `checkAuth(requiredRole)` (`shared/authGuard.js:1-22`), which signs out and redirects to login on mismatch.
  2. **Staff sub-role `psy_profiles.staff_role`:** `super_admin`, `admin`, `doctor`, `coach`, `manager` (enumerated at `roles/staff/staff-detail.html:137-141`). `super_admin` unconditionally bypasses all permission checks (`shared/authGuard.js:148`). Only `admin`/`manager`/`super_admin` can invite new staff; only `super_admin` can run `ghl-initial-sync` or reach `peranan.html` (RBAC admin console), `audit-kebenaran.html` (permission audit log), or `tetapan.html` (system settings) — these three pages hard-code the `super_admin` check in addition to the normal RBAC system.
  3. **Fine-grained module×action RBAC:** `psy_user_effective_permissions` (a DB view resolving role defaults minus per-user revokes plus per-user grants) gates individual pages/buttons independent of `staff_role`, configured through `roles/staff/peranan.html`. A parallel, simpler system (`window.PAGE_PATIENT_MODULE` / `canPatient(pageId)`) turns entire patient-side features on/off globally per role.
  4. **Patient KYC/KOB gating** (separate from RBAC): the two-gate system described in Section 1 — Gate 1 (KYC submitted) and Gate 2 (KYC approved + KOB complete/not-applicable), enforced in `roles/patient/_shared.js:46-66`.

- **Password reset:** `auth/login.html` → `resetPasswordForEmail(email, {redirectTo: 'auth/reset.html'})` (`auth/auth.js:96`). `auth/reset.html` checks for a valid Supabase recovery session (auto-established by following the emailed link); if present, shows a set-new-password form; if not, shows an "invalid/expired link" state.

- **Staff invitation / no separate patient email verification found:** the `invite-staff` edge function (callable only by an authenticated admin/manager/super_admin) either sends a genuine Supabase invite email (landing on `auth/set-password.html`, which parses the invite token from the URL hash and calls `updateUser({password})`) or creates the account directly with a temp password and `email_confirm: true`, skipping the email step when configured to. No patient-side email-confirmation-required flow was found in the signup code.

---

## Section 6 — Design tokens

**Where defined:** `shared/theme.js:1-20` (a JS object assigned to `tailwind.config` per page, since Tailwind is loaded from the CDN with no build step) is the closest thing to a central token source. A second, smaller layer of CSS custom properties (`--rp`, `--rpm`, `--rpa`, `--rpl`, `--rptx`) lives in `roles/staff/_styles.css` and `roles/patient/_styles.css`. Everything else (spacing, radii, shadows, most type sizes) is ad hoc Tailwind utility classes with no central scale file.

**Colours** (all hex, from `shared/theme.js:1-20`):

| Token | Hex |
|---|---|
| `cream` | `#F5F0E6` |
| `ink` | `#3C4F5C` |
| `green.light` / `green.DEFAULT` / `green.dark` | `#E3F1E5` / `#2E8B3E` / `#1F6E2B` |
| `navy.light` / `navy.DEFAULT` / `navy.dark` | `#DCE6F3` / `#1B4E9C` / `#0F2E5F` |
| `terracotta.light` / `terracotta.DEFAULT` | `#FCF6F5` / `#B85042` |
| `gold.light` / `gold.DEFAULT` / `gold.dark` | `#F7F0DE` / `#C9A86A` / `#B8860B` |
| `teal.DEFAULT` | `#50808E` |
| `bio` / `psycho` / `social` / `spiritual` (BPS-S "4 pillars" semantic colours) | `#2E8B3E` / `#1B4E9C` / `#C9A86A` / `#50808E` |

`manifest.json:11-12`: PWA `background_color` `#f5f0e6` (matches `cream`); `theme_color` `#1a3a5c` (does **not** exactly match `navy.dark` `#0F2E5F` — a minor inconsistency worth resolving before picking a splash/status-bar colour for the mobile app).

**Per-role accent tokens** (`roles/staff/_styles.css:1-17`, same block in `roles/patient/_styles.css`): default (patient/navy) `--rp #0F2E5F` / `--rpm #1B4E9C` / `--rpa #C9A86A` / `--rpl #DCE6F3` / `--rptx #1B4E9C`. Staff `staff_role` overrides: admin (indigo) `#312e81/#4f46e5/#a5b4fc/#ede9fe/#4338ca`; doctor (orange) `#7c2d12/#c2550a/#fdba74/#fff7ed/#c2550a`; coach (green) `#064e3b/#059669/#6ee7b7/#d1fae5/#047857`; manager (blue) `#1e3a5f/#2563eb/#93c5fd/#dbeafe/#1d4ed8`.

**Runtime-overridable primary colour:** a super-admin-configurable `psy_settings.primary_color` (default `#1B4E9C`, cached in `localStorage.isw_primary_color`) is mixed toward black/white at runtime to derive dark/light variants and injected as CSS overrides (`shared/theme.js:30,51-70`) — the "navy" brand colour is tenant-configurable, not a hardcoded constant.

**Typography:** Inter (Google Fonts CDN), weights vary by page (some load 400;500;600;700, others add 800 — not centralized), fallback `system-ui, sans-serif`. One outlier page, `landing-preview.html`, also loads **Lora** (serif) — unused elsewhere, looks like a one-off landing-page experiment. **No explicit type scale exists** — font sizes are ad hoc Tailwind utility classes (`text-xs`…`text-2xl`) chosen per element.

**Spacing / radii / shadows:** `shared/theme.js`'s `tailwind.config.theme.extend` only extends `colors` and `fontFamily` — no spacing/radius/shadow keys, so these fall back to stock Tailwind defaults, chosen per-element. A few raw hardcoded values exist in the two `_styles.css` files (`.chip{border-radius:999px}`, `.sidebar-toggle-fab{box-shadow:0 2px 6px rgba(0,0,0,.25)}`). **Finding: no formal spacing/radius/shadow scale.**

**Motion:** only in the two `_styles.css` files, all hardcoded per-rule, no shared duration/easing tokens: `.sidebar{transition:transform 0.3s ease}`, `.sidebar{transition:width 0.2s ease}` (desktop), `.sidebar-toggle-fab{transition:left 0.2s ease}`, `@keyframes pulse` (`.risk-pulse{animation:pulse 1.5s infinite}`, staff-only urgent indicator). No cubic-bezier easing curves found anywhere.

**Dark mode:** Yes, but custom-built — **not** Tailwind's `dark:` variant (zero matches repo-wide) and not a CSS `@media (prefers-color-scheme: dark)` rule (only consulted from JS via `matchMedia`). `shared/theme.js:75-142` sets `<html data-theme="dark|light">` from `localStorage.isw_theme` (default `light`) and injects a `<style>` block that force-overrides specific Tailwind-generated class selectors with hardcoded dark hex values (body `#0B1220`, card surface `#131E33`, input bg `#0E1830`, etc.).

**Font files:** Not self-hosted — no `.woff`/`.woff2`/`.ttf`/`.otf` files exist anywhere in the repo. Inter (and Lora, on the one unused page) load exclusively from Google Fonts CDN via a per-page `<link>` tag, repeated inconsistently across ~150+ files (not centralized). No font-licensing documentation exists in `docs/`.

---

## Section 7 — Media

**`image/` directory** (8 files, 492 KB total, all PWA icon assets referenced from `manifest.json:15-23`):

| File | Size |
|---|---|
| `Logo_ISW.png` | 282,856 bytes |
| `icon-512.png` | 77,240 bytes |
| `icon-maskable-512.png` | 53,546 bytes |
| `icon-192.png` | 18,997 bytes |
| `apple-touch-icon.png` | 16,138 bytes |
| `icon-maskable-192.png` | 13,931 bytes |
| `favicon.ico` | 12,422 bytes |
| `favicon-64.png` | 4,834 bytes |

**`icon/` directory** (separate from `image/` — 93 PNG files, much larger, mixed purpose): dozens of small (<30 KB) inline UI glyphs used directly in-app (e.g. `<img src="../../icon/heart-rate.png">`, `roles/patient/dashboard.html:204`), plus a set of large (~2–2.3 MB each) apparently uncompressed screenshots/reference images (`ATGC 1.png`…`ATGC 6.png`, `barcode 1.png`…`barcode 5.png`, `Madu.png`, `Poll.png`, `Genetik Keturunan.png`, etc.). **Flag for the mobile team:** these are roughly 20× the size of anything in `image/` and, being PNG rather than JPG/WebP, are almost certainly uncompressed — worth auditing before bundling into a mobile app or CDN.

**No audio or video** found anywhere — searched all `roles/**/*.html` for `<video`, `<audio`, YouTube/Vimeo embeds: zero matches. The Library/Knowledge Base modules model a `media_type` field in their database tables, but any actual video/audio content would live as an external URL inside the database, not embedded in static HTML — not independently verifiable from source alone.

**Supabase Storage buckets** (found via `.storage.from(` call sites, ~36 across ~30 files):

*Private, accessed only via signed URLs:* `kob-signatures`, `kob-documents`, `dna-test`, `medical-reports`, `referral-docs`, `letter-attachments`, `event-docs`, `receipts`, `agreement-templates`, `pakej-rujukan`.

*Public (`getPublicUrl`):* `issue-photos`, `order-photos`, `inventory-images`, `product-images`, `avatars`, `automation-media`, `wa-outbox`, `library-media` (code comment confirms: "existing public bucket, staff write / everyone read"), `kb-media`.

*Ambiguous:* `stock-in-docs` — only an `.upload()` call site was found, no corresponding read call turned up in this pass; its RLS/access policy needs manual verification.

**Alt text:** spot-checked `roles/patient/dashboard.html` — inline icon glyphs consistently use `alt=""` (empty/decorative), sized via Tailwind classes rather than `width`/`height` attributes. Alt text is not populated beyond that; would need to be authored for a mobile app if any of these icons convey information non-decoratively.

---

## Section 8 — Third-party services

| Service | Used for | Configured/called from |
|---|---|---|
| **Supabase** | Entire backend: Postgres DB, Auth, Storage, Edge Functions | `shared/supabase.js`, `config/supabase.js`, ~40 edge functions under `supabase/functions/` |
| **HitPay** | Payment gateway (sandbox/live modes, HMAC-signed webhooks) | `supabase/functions/_shared/payments/hitpay.ts`; invoked from `payments-initiate`, `payments-webhook`, `payments-kob-initiate`. Env vars: `HITPAY_API_KEY`, `HITPAY_SALT`, `HITPAY_MODE` (names only — not reproduced) |
| **GoHighLevel (GHL)** | CRM + WhatsApp messaging + transactional email + booking sync + payment-ledger reconciliation ("Central Payment Module") | `supabase/functions/_shared/ghl.ts`; ~9 edge functions (`ghl-transactions-sync`, `ghl-pull-sync`, `ghl-initial-sync`, `ghl-booking-webhook`, `sync-ghl`, plus calls from `payments-*`, `event-reminders`, `automations-runner`, `dna-test-email-report`). Env vars: `GHL_ISW_TOKEN`, `GHL_ISW_LOCATION_ID`, `GHL_EMAIL_FROM`. **Note: outbound transactional email is sent through GHL** — no separate email provider (Resend/SendGrid/Postmark/SMTP) exists anywhere in the codebase |
| **Google Fonts** | Web font CDN (Inter, and Lora on one unused page) | Per-page `<link>` tags, e.g. `auth/login.html:15` |

**No analytics or error-tracking service found anywhere** — searched for `gtag`, `google-analytics`, `sentry`, `posthog`, `mixpanel`, `hotjar`, `intercom`, `crisp.chat`: zero matches repo-wide. No reCAPTCHA, Google Maps, Stripe, or PayPal integration found either. The site currently ships with **no analytics and no crash/error reporting** — this will need to be added fresh for the mobile app.

---

## Section 9 — Content and copy

**Where text lives:** overwhelmingly hardcoded directly in HTML markup, authored in Bahasa Melayu (source language per `shared/i18n.js:2-8`), with a bilingual overlay layered on top rather than a true externalized content store:
- `shared/i18n.js` (322 lines) — the engine. Walks the DOM (text nodes + `placeholder`/`title`/`aria-label` attributes) via `TreeWalker` and a `MutationObserver` (for dynamically-injected nav/list/modal content), swapping strings through one of two dictionaries.
- `shared/i18n-dict.js` (9,203 lines) — `window.ISW_I18N_EXTRA`, an auto-generated Malay→English dictionary (its own header says "do not hand-edit — always go through the merge script").
- `shared/i18n-dict-ms.js` (724 lines) — the reverse (English-authored strings → Malay).
- A hand-maintained seed dictionary of ~150 entries also exists inline (`shared/i18n.js:26-183`) and takes precedence over the auto-generated one.

**Dictionary structure:** flat `{"Malay source string": "English translation"}` objects, matched against whitespace-normalized DOM text. Anything missing from the dictionary is left as-authored rather than erroring — so a stale dictionary produces mixed-language pages silently. Roughly **~9,900 source→translation key pairs** across the two generated dict files combined.

**Language toggle:** `localStorage.isw_lang`, default `'en'` (a deliberate product decision per `shared/i18n.js:12`, despite Malay being the source-authored language) — toggled via a topbar button (`[data-isw-lang-btn]`). Elements can opt out of translation with a `data-i18n-skip` attribute.

**Who edits copy / how it ships:** no CMS or database-backed content store for UI copy — it is hardcoded across the ~170 HTML files plus the two dictionary JS files, edited by developers, and shipped via git push/deploy (consistent with the rest of this codebase — no other publishing pipeline was found). Some *data*-driven content (Knowledge Base, Library, announcements/events) is pulled from Supabase tables rather than hardcoded HTML, but the page chrome and static labels around it are still hardcoded HTML + i18n-dict.

**Clinical/safeguarding content found:**
- **Emergency/crisis protocol:** staff-side monitoring queue (`roles/staff/emergency.html`) with RED/YELLOW/GREEN risk zones and a manual "report emergency" flow; patient-side crisis section at the bottom of `roles/patient/dashboard.html` with a `tel:999` call button, coach/family emergency contact buttons, and copy explicitly telling patients not to wait for the daily log if their condition worsens.
- **Treatment consent/agreement (KOB):** an e-signature flow in `roles/patient/kob.html` titled "Perjanjian Rawatan & Terma Perkhidmatan" (Treatment Agreement & Terms of Service), with copy stating the agreement is legally binding once electronically signed, and requiring name/IC number/signature (guardian signature for dependents) before a treatment plan is generated. A signed PDF is offered for download afterward.
- Similar consent/terms checkboxes ("Saya bersetuju dengan Terma Perkhidmatan dan Dasar Privasi") appear in the registration (`pendaftaran.html`) and checkout (`checkout.html`) flows.
- **No standalone Terms-of-Service or Privacy-Policy page was found anywhere in the repo** — the "Terma Perkhidmatan"/"Dasar Privasi" references are inline checkbox labels, not links to a dedicated policy document. Worth flagging: the mobile team will need to locate or draft one before shipping a native app that needs its own consent flow.

---

## Section 10 — Environment variables

No `.env` file or values are present in this survey — names and purposes only, gathered from `Deno.env.get(...)` calls in the edge functions and `process.env` in `server.js`.

| Variable | Purpose | Client-side or server-only |
|---|---|---|
| `PORT` | Port for the local static-file dev server | Server-only (`server.js`) |
| `SUPABASE_URL` | Supabase project URL, used server-side by every edge function that needs an elevated client | Server-only (edge functions) |
| `SUPABASE_ANON_KEY` | Supabase anonymous/publishable key, used by a few edge functions for RLS-scoped operations | Server-only in edge functions (also present **client-side, hardcoded** — see note below) |
| `SUPABASE_SERVICE_ROLE_KEY` | Full-privilege Supabase key, used by nearly every edge function to bypass RLS for administrative operations | Server-only — required |
| `HITPAY_API_KEY` | HitPay payment gateway API key | Server-only (`supabase/functions/_shared/payments/hitpay.ts`) |
| `HITPAY_SALT` | HitPay webhook HMAC signature verification secret | Server-only |
| `HITPAY_MODE` | Selects HitPay sandbox vs. live API base URL | Server-only |
| `PAYMENT_PROVIDER` | Selects which payment provider adapter to use | Server-only |
| `GHL_ISW_TOKEN` | GoHighLevel API bearer token | Server-only |
| `GHL_ISW_LOCATION_ID` | GoHighLevel account/location identifier | Server-only |
| `GHL_EMAIL_FROM` | From-address for transactional email sent via GHL | Server-only |
| `GHL_PIPELINE_ID` | GoHighLevel CRM pipeline identifier used by the sync function | Server-only |
| `GHL_PULL_CRON_SECRET` | Shared secret authorizing scheduled GHL-pull cron calls | Server-only |
| `GHL_BOOKING_WEBHOOK_SECRET` | Shared secret authorizing the GHL booking webhook | Server-only |
| `WA_WEBHOOK_SECRET` | Shared secret authorizing the WhatsApp inbound-message webhook | Server-only |
| `SYNC_WEBHOOK_SECRET` | Shared secret authorizing the outbound patient-sync webhook | Server-only |
| `CRON_SECRET` | Shared secret authorizing scheduled `automations-runner`/`event-reminders` calls | Server-only |
| `PUBLIC_APP_URL` | Base URL of the deployed web app, used to build redirect/return links from edge functions | Server-only |

**Required to run at all:** `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (or `SUPABASE_ANON_KEY` where used) are required by essentially every edge function; `PORT` is optional (defaults to 3000) for the local dev server only.

**Flag for the mobile/ops team, not a values leak:** the client-side Supabase **anon/publishable** key and project URL are hardcoded (not read from an env var) directly in `config/supabase.js:1-12`, for both the `production` and `testing` Supabase projects, with a developer-only environment-switcher badge (`config/supabase.js:34-69`). This is standard Supabase practice — anon keys are meant to be public and are constrained entirely by RLS policies — but it does mean both project URLs and their anon keys are visible to anyone who views the page source. No service-role key was found in any client-side file (searched explicitly — zero matches for `SERVICE_ROLE`/`service_role` in `*.html`).

---

## Section 11 — Domain and deep links

- **Production domain:** `https://psychotherapy-g51q.vercel.app` is the only domain referenced anywhere as the live deployment target (per this audit's brief) — no custom/branded domain (e.g. `ibnusinawellness.com` or similar) was found configured in the repository (`vercel.json` has no `domains`/custom-domain configuration; no `CNAME` file). `UNKNOWN` whether a custom domain is planned or already attached at the Vercel project level, since that configuration lives in the Vercel dashboard, not in this repo.
- **`.well-known/` directory:** does not currently exist anywhere in the repo (searched explicitly). Since this is a static site with a simple root-relative file server (`vercel.json`, `server.js`), adding `public/.well-known/apple-app-site-association` and `public/.well-known/assetlinks.json` (served from the domain root) would be straightforward — no server-side routing exists to conflict with it.
- **Hosting/deploy:** Two deployment configs exist in the repo, which is worth resolving before deep-link setup:
  - `vercel.json` (`{"cleanUrls": false, "trailingSlash": false}`) — consistent with the static `.html`-suffixed URLs observed live on `psychotherapy-g51q.vercel.app`. No `.vercel/project.json` exists locally, so the linked Vercel project/branch is `UNKNOWN` from the repo alone — Vercel projects are typically configured to auto-deploy the `main` branch, but this should be confirmed in the Vercel dashboard, not assumed.
  - `railway.json` also exists (Railpack builder, single replica), and `server.js` (a working static-file HTTP server) appears to exist specifically to support a non-Vercel host like Railway, since Vercel doesn't need a Node process to serve static files. `UNKNOWN` whether Railway is a currently-active second deployment or a retired earlier attempt — this should be confirmed with whoever manages the Vercel/Railway accounts before assuming only one hosting target exists.
- **Who would host the two deep-link files:** whoever has access to the Vercel project (or Railway, if that's also live) — since they're just two static JSON/text files, they need to be committed into the repo (e.g. under a `public/.well-known/` or root-level path the host serves verbatim) and pushed like any other change; no separate infrastructure is needed given the current static-hosting setup.

---

## Section 12 — What the mobile team should know

**Unfinished, fragile, or known-broken:**
- Three pages are disconnected mockups with zero backend wiring and zero inbound links: `landing-preview.html`, `roles/patient/checkout.html` (explicit dev comment marking it a static placeholder), and `roles/patient/kepatuhan-flow-preview.html`. Don't treat these as real routes.
- Four dead redirect stubs still exist in the repo, each just doing a client-side `location.replace()` to wherever the real feature moved: `roles/staff/assignments.html` → `patients.html?tab=unassigned`, `roles/staff/closures.html` → `appointments.html`, `roles/staff/lawatan.html` → `peristiwa.html?view=visits`, `roles/staff/peristiwa-kalendar.html` → `appointments.html`. `roles/patient/kob-agreement.html` is also a dead stub, and notably a staff page (`kob-detail.html`) still links to it with a `?kob_id=` param the stub silently discards.
- `database/schema/` (the documented "source of truth" for the data model) is confirmed to be **out of sync** with the live database in at least one place: `psy_kob_installments` exists live (via a 2026-08-13 migration) but isn't reflected in the domain schema files. Don't assume the schema files are 100% current without cross-checking `supabase/migrations/`.
- Two SQL files sit uncommitted/unrun in the repo (`database/normalize_inventory_units.sql`, `database/fix_obpx1plus_audit_label.sql`) — the inventory-unit data isn't standardized in the live DB yet.
- No analytics and no error/crash tracking exist anywhere in this codebase — there is no web-side precedent to port for either.
- No standalone Terms of Service or Privacy Policy page exists — only inline consent checkboxes referencing those documents by name.
- One inventory image directory (`icon/`) contains ~2 MB uncompressed PNGs mixed in with small UI glyphs — don't assume everything under `icon/` is meant for in-app use at that size.

**Actively being worked on:** `roles/staff/kob-report.html` and `roles/staff/kob-sign.html` are brand-new (untracked in git), fully functional KOB reporting/e-signature pages. Several `database/schema/*.sql` files (packages, KOB, inventory, storage) are mid-edit per git status, alongside the new inventory-unit-standardization work.

**What may surprise you:**
- This entire ~180-page application has no framework, no bundler, and no build step — every deploy is a literal copy of the files in this repo.
- The frontend talks to the database directly (PostgREST via the Supabase SDK) on almost every page; there is no conventional REST/GraphQL API layer in front of the data. Row Level Security policies are the *only* real authorization boundary for data access — the anon key embedded in the client is, by design, public.
- Two parallel automation/messaging systems exist side by side (`psy_auto_messages` — older, event-triggered; `psy_automations` — newer, campaign-builder), sharing one RBAC module. Treat them as two distinct features, not one.
- Outbound transactional email rides entirely on GoHighLevel — there is no dedicated email service (no SendGrid/Postmark/Resend/SMTP) anywhere in the codebase.
- Both a `vercel.json` and a `railway.json` exist, with a hand-rolled `server.js` that only makes sense as a Railway (or similar Node-host) entrypoint — worth clarifying with whoever manages hosting which one is actually authoritative before the mobile team relies on API behavior being identical across both.

**Looks like a prototype rather than a finished product:** `landing-preview.html` and `kepatuhan-flow-preview.html` read as design explorations that were never wired in or removed. The dead redirect stubs suggest routes get superseded faster than they get cleaned up. Otherwise, the bulk of the application (both patient and staff sides) reads as a mature, actively-maintained production system — extensive RBAC, RLS, audit logging, and a 117-table domain model are not prototype-grade signals.

**Likely-wrong assumptions to correct before building:**
- "This is a Next.js app" — corrected in Section 0; it is static HTML with zero framework.
- "There's a REST API to port" — mostly false; most functionality is direct-to-Postgres via RLS-scoped Supabase calls, not a bespoke API. The ~17 edge functions in Section 4 are the exception, for anything needing elevated privilege or a third-party secret.
- "Roles are just patient/staff" — there's a third layer (`staff_role`: super_admin/admin/doctor/coach/manager) plus a fully data-driven module×action permission matrix on top of that; a hardcoded two-role model in the mobile app would miss most of the real access-control surface.
- "The Malay text is the only language" — the shipped default is actually English, via a client-side translation-substitution layer over Malay-authored source markup, not real i18n message catalogs — there's no clean single source of truth per string to port to a mobile i18n system.

---

*End of audit. All findings above are cited to specific files and line numbers within `C:\Users\ASUS\ISW system` as of 2026-09-18. No secrets, credentials, or real patient/staff data were reproduced in this document.*
