# Laporan Audit Sistem ISW — 24 Jun 2026

Jumlah: 184 penemuan (8 critical, 41 high, 75 medium, 60 low) merentas 103 page + DB/RLS/keselamatan/konsistensi.


## CRITICAL

### (db) roles/patient/faq-overhaul.html — Tables psy_faq_sections and psy_faq_items do not exist in the schema
- **Di mana:** loadFaq (window.db.from('psy_faq_sections') / 'psy_faq_items')
- **Masalah:** Both patient and staff FAQ pages query psy_faq_sections and psy_faq_items (with an embedded psy_faq_sections(code) join). Neither table is defined anywhere in the repo SQL. The FAQ page will fail to load any content (PostgREST 404 on the relation). Also referenced in roles/staff/faq-overhaul.html:205-207.
- **Bukti:** `roles/patient/faq-overhaul.html:228  window.db.from('psy_faq_items').select('id, section_id, soalan, jawapan, sort_order, psy_faq_sections(code)')`
- **Cadangan:** Create psy_faq_sections (id, code, title, sort_order) and psy_faq_items (id, section_id FK, soalan, jawapan, sort_order) with a FK so PostgREST resolves the psy_faq_sections(code) embed, plus public-read RLS and staff-manage RLS.

### (db) roles/staff/consultation.html — Table psy_soap_notes does not exist in the canonical schema
- **Di mana:** loadPatientData / saveSoap (dbQuery + dbInsert 'psy_soap_notes')
- **Masalah:** consultation.html reads (dbQuery line 152) and INSERTS (dbInsert line 215) into psy_soap_notes. The table is never defined by any CREATE TABLE in database/master_migration.sql, seeds.sql, or any file under supabase/migrations (only a DROP TABLE for it exists in database/drop_all.sql). Every SOAP-note read/write throws a Postgres 'relation does not exist' / PostgREST 404 at runtime. Also consumed by roles/patient/plan-week.html:327 (loadSoap) and roles/staff/profile.html:460 (doctor stats), so the consultation note feature and patient plan view are broken.
- **Bukti:** `roles/staff/consultation.html:215  await dbInsert('psy_soap_notes', note);`
- **Cadangan:** Add a CREATE TABLE psy_soap_notes (id, patient_id, doctor_id, created_at, subjective, objective, assessment, plan, status ...) with RLS (staff manage, patient read own) to master_migration.sql, or repoint these calls to an existing notes table (e.g. psy_patient_notes).

### (db) roles/staff/kepatuhan-fill.html — Tables psy_fasa_rawatan and psy_amalan_items do not exist in the schema
- **Di mana:** loadAmalan (window.db.from('psy_fasa_rawatan') line 766, 'psy_amalan_items' line 769)
- **Masalah:** The new staff kepatuhan-fill page queries psy_fasa_rawatan (to find the patient's treatment phase row) and then psy_amalan_items (to list the practice checklist items for that phase). Neither table exists in master_migration.sql nor in the new migration supabase/migrations/20260627_staff_fill_kepatuhan.sql. The amalan/checklist lookup returns a relation-not-found error and the staff fill-in form renders no items.
- **Bukti:** `roles/staff/kepatuhan-fill.html:769  const { data:ams } = await window.db.from('psy_amalan_items').select('*').eq('fasa_id',fasa[0].id).eq('is_active',true).order('urutan');`
- **Cadangan:** Define psy_fasa_rawatan (id, patient_id, week_number ...) and psy_amalan_items (id, fasa_id FK, urutan, is_active, label ...) in the schema/migration, or repoint kepatuhan-fill to the existing psy_kepatuhan_item table that backs the patient-side checklist.

### (logic) roles/patient/feedback.html — Overall feedback insert uses non-existent column 'helpful' (real column is helpful_tags)
- **Di mana:** submitFeedback()
- **Masalah:** The psy_feedback table defines the JSONB column as helpful_tags (database/master_migration.sql line 2242). submitFeedback() inserts a field named 'helpful'. PostgREST will reject the insert with "column psy_feedback.helpful does not exist", so the overall end-of-treatment feedback NEVER saves — the user only sees the success banner/Google-Review modal but nothing is written to the DB. (The weekly insert correctly avoids this.)
- **Bukti:** `const { error } = await window.db.from('psy_feedback').insert({
      patient_id:   window.patientRecord?.id || null,
      user_id:      currentUser.id,
      patient_name: currentUser.full_name || null,
      feedback_type: 'overall',`
- **Cadangan:** Rename the insert key to match the schema: helpful_tags: Array.from(selectedHelpful).

### (logic) roles/staff/kepatuhan-fill.html — Save always fails: fasa is a raw integer but psy_kepatuhan_log.fasa has a CHECK constraint requiring an enum string
- **Di mana:** sfSave() payload / INIT currentFasa
- **Masalah:** currentFasa is set to active.current_week (a raw integer 1-12) and written into the upsert as `fasa: currentFasa`. The psy_kepatuhan_log.fasa column is `TEXT NOT NULL CHECK (fasa IN ('week1','week2_4','week5_12','fasa2','fasa3'))`. Inserting a number (or its text form) violates the CHECK constraint, so the upsert is rejected by Postgres (error 23514) on EVERY save. The user always sees 'Gagal menyimpan' and nothing is persisted. The patient version converts via weekToFasa(currentWeek) to one of the allowed strings before saving; this page does not.
- **Bukti:** `currentFasa = active?.current_week || 1;  ...  const payload = { patient_id: patientId, log_date: selectedDate, fasa: currentFasa, jawapan, skor_harian: computeSkor(), ... };`
- **Cadangan:** Map the numeric week to the allowed fasa string before saving, e.g. use the same weekToFasa() logic as roles/patient/kepatuhan.html (1->'week1', 2-4->'week2_4', 5-12->'week5_12', etc.) and store that string in payload.fasa.

### (logic) roles/staff/kepatuhan-fill.html — Amalan checklist queries non-existent tables (psy_fasa_rawatan / psy_amalan_items), so Step 2 is always empty
- **Di mana:** INIT — load amalan items
- **Masalah:** The page loads the practice checklist from psy_fasa_rawatan (filter week_number) then psy_amalan_items (filter fasa_id, is_active, order urutan). Neither table exists in the schema. The canonical source (database/master_migration.sql and roles/patient/kepatuhan.html) uses table psy_kepatuhan_item with columns fasa (enum string), aktif, urutan, and items keyed by a string fasa (weekToFasa), not a numeric week_number / fasa_id join. Both queries silently fail inside try/catch(_){}, leaving ITEMS=[] so Step 2 always shows 'Tiada amalan untuk fasa ini' and computeSkor() returns null — the scoreable checklist can never be filled.
- **Bukti:** `const { data:fasa } = await window.db.from('psy_fasa_rawatan').select('id').eq('patient_id',patientId).eq('week_number',currentFasa).limit(1); if(fasa?.[0]) { const { data:ams } = await window.db.from('psy_amalan_items').select('*').eq('fas`
- **Cadangan:** Replace with the patient-page logic: convert currentFasa to a fasa string via weekToFasa(), then query psy_kepatuhan_item .eq('fasa', fasaKey).eq('aktif', true).order('urutan') with carry-forward fallback to earlier fasa when empty.

### (logic) roles/staff/pakej-laporan.html — Selecting non-existent column 'status' on psy_packages breaks the whole page
- **Di mana:** init() - window.db.from('psy_packages').select(...)
- **Masalah:** The query requests a 'status' column, but psy_packages has no such column (schema only defines is_active; no ALTER adds status — verified in database/master_migration.sql lines 356-381 and all ALTER TABLE psy_packages blocks). PostgREST returns a 400 error for an unknown column, so pkgRes.data is null, pkgs becomes [], every KPI shows 0, and the table renders the empty state. There is also no error handling, so the user sees a silently blank report. The code even has fallback logic `p.status || (p.is_active ? 'active' : 'inactive')` showing 'status' is expected to possibly be absent — but it is hard-selected in the query, which fails before the fallback ever runs.
- **Bukti:** `window.db.from('psy_packages').select('id, name, package_id, price, icon, bg_color, status, is_active').order('sort_order', { ascending: true }),`
- **Cadangan:** Remove 'status' from the select list (rely on is_active), or add a status column to psy_packages. Also add error handling: if (pkgRes.error) { banner/notify and bail } instead of silently using `|| []`.

### (logic) roles/staff/pakej-laporan.html — Patient-to-package match compares text package code against package UUID — always 0
- **Di mana:** init() - stats = pkgs.map: const inPkg = pts.filter(x => x.active_package_id === p.id)
- **Masalah:** psy_patients.active_package_id is TEXT and stores the human package CODE (e.g. 'M 001'), set from p.package_id in patients.html (line 1137 selectedPkgCode = pakejSel.value, line 1251 active_package_id: selectedPkgCode). But here it is compared to p.id which is the psy_packages UUID. A text code can never equal a UUID, so inPkg is always empty: every package shows 0 active patients, 0 selesai, KPI Jumlah Pesakit=0, Purata=0, and 'Pakej Paling Popular' stays '—'. The whole report is effectively non-functional.
- **Bukti:** `const inPkg = pts.filter(x => x.active_package_id === p.id);`
- **Cadangan:** Match against the package code: x.active_package_id === p.package_id (and load package_id, which is already selected).


## HIGH

### (consistency) roles/staff/dashboard.html — Staff dashboard reads 'tidak_hadir' status that no code ever writes
- **Di mana:** loadAdminDashboard() ~L990 + Kepatuhan calc ~L1019-1021
- **Masalah:** The admin dashboard queries missed sessions and computes the 7-day Kepatuhan % using status='tidak_hadir'. But no writer anywhere in the session lifecycle ever sets 'tidak_hadir' — patient plan.html auto-mark, staff plan-week markStatus(), staff dashboard markMissed(), and staff patient-hub all write 'cancel' for a missed session. So the 'Tidak Hadir' metric on the staff dashboard is permanently 0 and the compliance denominator is wrong (missing all real misses), silently understating absenteeism for management.
- **Bukti:** `L990: window.db.from('psy_plan_weekly_progress')...eq('status','tidak_hadir')  |  L1021: const w7Total = weeklySessions.filter(s => ['hadir','tidak_hadir','cancel'].includes(s.status)).length;  vs writer roles/patient/plan.html L1329: await`
- **Cadangan:** Standardise on 'cancel' as THE missed-session status everywhere (it is what every writer uses). Replace 'tidak_hadir' reads in staff/dashboard.html (and governance.html L152/233/236) with 'cancel', or run a one-time migration if any legacy 'tidak_hadir' rows exist, then delete the dead alias.

### (consistency) roles/staff/patients.html — Staff-seeded plans create 1 session/week with status 'pending'; patient page expects 2 sessions and treats it as never-booked
- **Di mana:** save() auto-seed treatment plan ~L1330-1340 and ~L1434-1445
- **Masalah:** When staff assign a package, patients.html seeds psy_plan_weekly_progress with exactly ONE row per week (session_day:1, status:'pending') and does NOT set preferred_pair/schedule_setup_at on the plan. The patient plan.html lifecycle is built around 2 sessions/week: a week is only 'Selesai' when sess.length>=2 AND both attended (L458), and renderWeekPage uses the legacy single-session renderer only when preferred_pair is null. Result: staff-assigned patients see every week as a single 'Belum dijadual' card with a 'Tempah' button (status 'pending' is not handled by any branch in renderSession, so it falls through to the else 'Tempah' case), the onboarding wizard never appears (because progress rows already exist -> needsSetup=false), and the patient can never reach the 2-session 'done week' state. Staff and patient disagree on the shape of a week.
- **Bukti:** `roles/staff/patients.html L1331-1338: for (let w=1; w<=durationWeeks; w++){ rows.push({ ...week_number:w, session_day:1, status:'pending' }); }  vs roles/patient/plan.html L458: const allDone = sess.length >= 2 && sess.every(s => ['hadir','`
- **Cadangan:** Have staff seeding either (a) set preferred_pair + schedule_setup_at and seed 2 sessions/week consistent with the patient wizard's generateScheduleDates, or (b) not seed weekly_progress rows at all so the patient onboarding wizard runs. Otherwise the patient is stuck in a half-initialised plan that never reaches completion.

### (db) database/master_migration.sql — Payments INSERT policy WITH CHECK (true) lets any user forge completed payment records for any patient
- **Di mana:** psy_payments RLS policy "Patients insert own payments" (~line 441)
- **Masalah:** psy_payments has INSERT policy WITH CHECK (true), so any authenticated user (including any patient) can insert a payment row with arbitrary patient_id, total/subtotal=0, status defaults to 'completed', payment_method='manual', and a forged receipt_ref. The policy name claims 'own payments' but does NOT bind patient_id to the caller (no patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()) check). Impact: a patient can fabricate a paid receipt for themselves (bypassing payment), or write payment rows attributed to other patients, corrupting financial/billing records. Staff dashboards/reports reading psy_payments would treat these as real completed payments.
- **Bukti:** `DO $$ BEGIN CREATE POLICY "Patients insert own payments" ON psy_payments FOR INSERT WITH CHECK (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;`
- **Cadangan:** Restrict the WITH CHECK to the caller's own patient row, e.g. WITH CHECK (patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid())). Even better, do not let clients set status/total at all for self-service flows: have payments written only by the server/Edge Function (service_role) or a SECURITY DEFINER RPC that validates amount against the order, so 'completed' status cannot be client-forged.

### (db) database/master_migration.sql — Medical-reports upload policy lets a patient write files into ANOTHER patient's folder (cross-tenant write of medical data)
- **Di mana:** storage.objects policy "Patients can upload own medical reports" (~line 932-934)
- **Masalah:** The INSERT policy on storage.objects for bucket 'medical-reports' only checks that the first path segment is 'patient' AND that the caller is SOME patient (EXISTS ... WHERE user_id = auth.uid()). It does NOT verify that the second path segment (the patient id, foldername(name)[2]) belongs to the caller. The corresponding SELECT (read) policy DOES validate foldername[2] against the caller's own patient id, proving the intended convention is patient/<patientId>/... — but the write policy omits that bind. Impact: any logged-in patient can upload (and thereby plant/poison) medical report files under any other patient's folder path, a cross-tenant integrity breach on sensitive medical data.
- **Bukti:** `CREATE POLICY "Patients can upload own medical reports" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'medical-reports' AND (storage.foldername(name))[1] = 'patient' AND EXISTS (SELECT 1 FROM psy_patients WHERE user`
- **Cadangan:** Mirror the read policy's ownership bind in the WITH CHECK: ... AND EXISTS (SELECT 1 FROM psy_patients WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2]). This ensures a patient can only upload under their own patient-id folder.

### (db) roles/patient/kyc.html — RPC check_referral_code is called but not defined in the schema
- **Di mana:** validateReferral (window.db.rpc('check_referral_code') line 688)
- **Masalah:** The KYC flow calls window.db.rpc('check_referral_code', { p_code }) to validate a referral code during patient onboarding. No CREATE FUNCTION check_referral_code exists in master_migration.sql or anywhere in the repo SQL (the only defined RPC in this area is psy_library_bump_view, which IS present at master_migration.sql:2601). The referral-code validation call returns a PostgREST 404 'function not found', so referral validation during signup fails.
- **Bukti:** `roles/patient/kyc.html:688  const { data, error } = await window.db.rpc('check_referral_code', { p_code: code });`
- **Cadangan:** Add CREATE FUNCTION check_referral_code(p_code text) RETURNS ... (looking up psy_referrals) with GRANT EXECUTE TO anon, authenticated, mirroring how psy_library_bump_view is defined.

### (db) roles/patient/library.html — Table psy_library_progress does not exist in the schema
- **Di mana:** loadContinueWatching (window.db.from('psy_library_progress') line 542)
- **Masalah:** library.html selects from psy_library_progress with an embedded psy_library_items(*) join to render the 'continue watching' row. No CREATE TABLE psy_library_progress exists anywhere in the repo (the schema has psy_library_views, psy_library_bookmarks, psy_library_feedback, but no _progress). The query errors and the continue-watching section is silently empty (wrapped in try/catch).
- **Bukti:** `roles/patient/library.html:542  await window.db.from('psy_library_progress').select('*,psy_library_items(*)').eq('user_id',currentUser.id).order('last_watched_at',{ascending:false})`
- **Cadangan:** Create psy_library_progress (user_id, item_id FK to psy_library_items, last_watched_at, position ...) with owner-scoped RLS, or change the query to use psy_library_views which already exists.

### (link) roles/patient/faq.html — "Hubungi Sokongan" links to a placeholder WhatsApp number in production
- **Di mana:** SUPPORT_WA constant + btn-support href override (IIFE)
- **Masalah:** SUPPORT_WA is a hardcoded dummy value '60123456789' (the code comment itself says it must be replaced with the clinic's real WhatsApp Business number). Because the IIFE always sets sBtn.href to https://wa.me/60123456789?... whenever SUPPORT_WA is truthy (and it always is), the page's only support CTA opens WhatsApp to a non-existent/wrong number. The original static href="issue.html" is silently overridden. A patient who cannot find an answer and clicks 'Hubungi Sokongan' reaches a dead WhatsApp chat.
- **Bukti:** `const SUPPORT_WA='60123456789'; ... if(sBtn && SUPPORT_WA){ ... sBtn.href=`https://wa.me/${SUPPORT_WA}?text=${encodeURIComponent(msg)}`; }`
- **Cadangan:** Replace the placeholder with the real clinic WhatsApp Business number (or load it from config), and/or leave the href as issue.html if SUPPORT_WA is still the placeholder so the fallback support page is reachable.

### (link) roles/patient/plan.html — getElementById('content') targets an id that does not exist in this page
- **Di mana:** loadPlan() — no-active-package branch
- **Masalah:** loadPlan() writes its 'no package', auto-create-failure, and 'plan will be ready' states into document.getElementById('content').innerHTML, but there is no element with id="content" anywhere in this HTML (the page uses id="weekly-list", id="setup-wizard", id="app-shell", etc.). For any patient WITHOUT an active package (a very common real state before purchase), getElementById('content') returns null and `.innerHTML = ...` throws "Cannot set properties of null", aborting loadPlan(). The patient sees a blank/stuck page (loading spinner already hidden by initPatient or no content shown) and the intended 'Belum Ada Pelan Rawatan' call-to-action is never rendered.
- **Bukti:** `document.getElementById('content').innerHTML = `
      <div class="max-w-xl mx-auto bg-white rounded-2xl border border-ink/10 p-8 md:p-10 text-center mt-10">
        <div class="text-6xl mb-4">📦</div>
        <h2 class="text-2xl font-bold t`
- **Cadangan:** Add a container with id="content" in the page body (e.g. wrap the weekly-progress-block / stats area), or change these getElementById('content') calls to target an element that exists (e.g. the #weekly-progress-block / a dedicated empty-state container).

### (link) roles/patient/routine.html — loadStats() targets stat-* elements that do not exist in the HTML
- **Di mana:** loadStats()
- **Masalah:** loadStats() writes to getElementById('stat-7d'), 'stat-30d', 'stat-streak', 'stat-missed', and 'stat-heatmap', but none of these elements exist anywhere in the page (there is no Stats pane/markup). When invoked, the first .textContent on a null element throws a TypeError ('Cannot set properties of null'), aborting the function. The entire stats feature is dead/broken code that will crash if ever reached.
- **Bukti:** `document.getElementById('stat-7d').textContent  = avgPctSince(7)  + '%';
    document.getElementById('stat-30d').textContent = avgPctSince(30) + '%';`
- **Cadangan:** Either add the missing Stats tab markup (stat-7d, stat-30d, stat-streak, stat-missed, stat-heatmap, plus a tab button/pane-stats) or remove the dead loadStats() function and its switchTab('stats') branch.

### (logic) roles/patient/event-detail.html — DB write errors are swallowed; always shows success banner
- **Di mana:** toggleReg()
- **Masalah:** The Supabase JS client does NOT throw on query errors (RLS denial, constraint, network-level row error) — it resolves to { data, error }. The code never inspects the returned error object, so even when the update/upsert silently fails, the code proceeds to set REG and shows 'Berjaya daftar ✓' / 'Pendaftaran dibatalkan'. The try/catch only catches thrown exceptions, not query errors. A patient can be told registration succeeded when it did not.
- **Bukti:** `await window.db.from('psy_event_registrations').update({ status:'batal' })
        .eq('event_id', EV.id).eq('patient_id', window.patientRecord.id);
      REG = { ...REG, status:'batal' };
      banner('Pendaftaran dibatalkan');`
- **Cadangan:** Capture and check the error: `const { error } = await window.db...; if (error) throw error;` for both the update and upsert branches before updating REG and showing the success banner.

### (logic) roles/patient/issue.html — Success banner shown even when the report insert fails
- **Di mana:** submitIssue()
- **Masalah:** auditLog() in config/supabase.js wraps its insert in try/catch and swallows all errors (catch(_){}), returning void on both success and failure. submitIssue() does not (and cannot) detect a failed insert, yet unconditionally shows the success banner and clears the form. If the DB insert fails (RLS, network, validation), the patient is told their report was sent and the form is wiped, but nothing was saved.
- **Bukti:** `await auditLog('issue.reported', window.currentUser.id, {
    type, description: desc, photo_url: photoUrl,
  });

  banner('Laporan dihantar. Admin akan hubungi anda dalam 24 jam.');
  document.getElementById('issue-desc').value = '';`
- **Cadangan:** Have auditLog return the {error}/inserted row (or use a direct insert here that surfaces the error) and only show the success banner + clear the form when there is no error; otherwise show an error banner so the patient can retry.

### (logic) roles/patient/kyc.html — Duplicate-IC self-exclusion always fails (window.patientRecord is never set)
- **Di mana:** submitKYC / checkIcDuplicate — myPatientId
- **Masalah:** The patient record is stored in a module-scoped `let patientRecord` (declared line 463, assigned line 1074), but both duplicate-IC guards read `window.patientRecord?.id`. `window.patientRecord` is never assigned anywhere in the file, so it is always undefined and `myPatientId` always falls back to the all-zeros UUID. Therefore `.neq('id', myPatientId)` never excludes the patient's OWN existing psy_patients row. A returning patient whose IC already exists in psy_patients gets a false 'IC already exists' warning while typing (line 542) and, worse, is hard-blocked at submit (line 977) with 'No. IC ini sudah didaftarkan atas nama ...' — they cannot resubmit/edit their own rejected/pending KYC.
- **Bukti:** `const myPatientId = window.patientRecord?.id || '00000000-0000-0000-0000-000000000000';
    const { data: icDup } = await window.db.from('psy_patients')
      .select('id, mrn, full_name').eq('ic_number', icVal).neq('id', myPatientId).limit`
- **Cadangan:** Reference the actual variable `patientRecord?.id` (not window.patientRecord) at lines 537 and 974, or assign `window.patientRecord = patRes` inside loadExistingKYC so the window lookup resolves.

### (logic) roles/patient/library.html — Fabricated random watch-progress shown to patient
- **Di mana:** renderContinueWatching()
- **Masalah:** When a psy_library_progress row has no progress_pct, the UI invents a random number between 10 and 89 and displays it as '% selesai'. The patient sees a fake completion figure unrelated to what they actually watched, and because Math.random() runs inside render it changes on every re-render. Misleading data presented as real progress.
- **Bukti:** `const pct=prog.progress_pct||Math.floor(Math.random()*80)+10;`
- **Cadangan:** Use a real default such as const pct=Math.round(prog.progress_pct||0); and only show the bar/label when a genuine value exists.

### (logic) roles/patient/payment.html — Batal Semua does not cancel plan_extension charges in the DB, so they reappear
- **Di mana:** cancelAll()
- **Masalah:** cancelAll() only reverts DB state for item.type 'appointment' (sets cancelled) and 'package_existing' (deletes the purchase). For 'plan_extension' items there is no branch, so the underlying psy_plan_weekly_progress rows stay with status 'extension_pending_payment'. After clearing pendingItems and calling loadPayments(), loadPayments() re-queries those same extension rows (filter r.is_extension && r.status === 'extension_pending_payment') and re-adds them to the invoice. The user is told 'Semua bayaran dibatalkan' but the extra-week charge immediately comes back, making cancel appear broken.
- **Bukti:** `for (const item of pendingItems) {
      if (item.type === 'appointment') {
        await dbUpdate('psy_appointments', item.id, { status: 'cancelled', notes: '[CANCELLED]' });
      } else if (item.type === 'package_existing') {
        awa`
- **Cadangan:** Add an else-if for item.type === 'plan_extension' that flips each item.rowIds row back to a cancelled/non-pending status (e.g. dbUpdate('psy_plan_weekly_progress', rowId, { status: 'extension_cancelled' })) so they no longer match the pending filter on reload.

### (logic) roles/patient/plan-week.html — Unmapped weekEntry.status (extension_pending_payment / extension_paid) crashes renderHero
- **Di mana:** renderHero()
- **Masalah:** statusStyles only defines hadir/reschedule/cancel/booked/pending/unbooked. The staff side (roles/staff/plan-week.html lines 809-811) writes status='extension_pending_payment' onto psy_plan_weekly_progress, and roles/patient/plan.html (lines 479, 839, 1274) also uses 'extension_paid'/'extension_pending_payment'. When such a row is weekEntry, s = statusStyles[status] is undefined and the next line dereferences s.color / s.icon / s.label, throwing a TypeError. renderHero aborts mid-build, leaving the hero (and the page flow that follows) broken for any patient viewing an extension week.
- **Bukti:** `const s = statusStyles[status];
... 
<span class="${s.color} text-xs font-semibold flex items-center gap-1">· ${s.icon} ${s.label}</span>`
- **Cadangan:** Add a safe fallback, e.g. const s = statusStyles[status] || statusStyles.unbooked; and add explicit entries for extension_pending_payment / extension_paid.

### (logic) roles/patient/rekod-detail.html — Detail record fetched by id only, not scoped to the logged-in patient (IDOR)
- **Di mana:** IIFE main loader, fetch of psy_medical_reports by id
- **Masalah:** The detail page loads any medical report purely by the URL ?id=... with no patient_id filter, then renders the document, doctor comments and a download link. The list page that links here scopes its query with .eq('patient_id', patientRecord.id) (rekod-perubatan.html line 347), so this page is inconsistent. If RLS on psy_medical_reports is not strictly per-patient, a patient can change the id in the URL and view another patient's medical report, comments and signed file URL. Relies entirely on RLS being correct; the client provides no authorization guard.
- **Bukti:** `const id=new URLSearchParams(location.search).get('id');
  if(!id){ window.location.href='rekod-perubatan.html'; return; }
  const { data }=await window.db.from('psy_medical_reports').select('*').eq('id',id).maybeSingle();`
- **Cadangan:** Scope the query to the current patient, e.g. add .eq('patient_id', window.patientRecord.id) (matching rekod-perubatan.html), and treat a null result as 'not found'. Do not rely solely on RLS for a record that exposes a signed file URL.

### (logic) roles/patient/vitals.html — Patient edit of own reading silently saves nothing (no RLS UPDATE policy on psy_vitals)
- **Di mana:** saveSelfVitals() — editingVitalId update branch
- **Masalah:** The Edit flow calls window.db.from('psy_vitals').update(payload).eq('id', editingVitalId). In the DB schema psy_vitals only has policies: 'Staff manage vitals' (FOR ALL, staff role only), 'Patients read own vitals' (SELECT), and 'Patients insert own vitals' (INSERT). There is NO patient UPDATE policy. Under RLS the patient's UPDATE matches zero rows and Supabase returns no error (error is null). The code therefore throws nothing, shows banner('Bacaan dikemaskini ✅') and re-loads, so the user believes their edit was saved when in fact the row is unchanged. Data-loss / false-success bug for the Edit Bacaan Hari Ini feature.
- **Bukti:** `if (editingVitalId) {
  ({ error } = await window.db.from('psy_vitals').update(payload).eq('id', editingVitalId));
}
...
banner(editingVitalId ? 'Bacaan dikemaskini ✅' : 'Bacaan disimpan ✅');`
- **Cadangan:** Add an RLS UPDATE policy on psy_vitals for patients on their own patient_self rows (USING patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()) AND source='patient_self'), or verify the update affected a row (use .select() and check returned data length) and surface an error to the user if 0 rows changed.

### (logic) roles/staff/appointments.html — Wrong column name: plan.total_weeks does not exist (schema column is duration_weeks)
- **Di mana:** autoFillPlan / saveSession (plan.total_weeks)
- **Masalah:** The psy_treatment_plans table defines duration_weeks (INT DEFAULT 13), not total_weeks. The code reads plan.total_weeks in the plan display and in the week-bounds validation. plan.total_weeks is always undefined, so the display always shows '?', and the guard 'if (plan?.total_weeks && week > plan.total_weeks)' never fires — staff can book a week number beyond the plan duration with no validation. total_weeks appears nowhere else in the entire codebase, confirming it is a typo for duration_weeks.
- **Bukti:** `display.textContent = `${plan.name} · Minggu ${plan.current_week || 0}/${plan.total_weeks || '?'}`;
...
  if (plan?.total_weeks && week > plan.total_weeks) {
    errEl.textContent = `Minggu ${week} melebihi jumlah minggu plan ini (${plan.to`
- **Cadangan:** Replace plan.total_weeks with plan.duration_weeks in all three spots (lines 1034, 1103, 1104).

### (logic) roles/staff/audit.html — Records beyond 125 are unreachable while UI claims they exist
- **Di mana:** loadLog / renderPage pagination
- **Masalah:** loadLog() only fetches up to 5 pages worth of rows (PAGE_SIZE*5-1 = 125 rows) into allRows, but totalCount is the EXACT full count from the DB. The pagination footer renders 'daripada {totalCount} log' and the count chip shows the full total, yet changePage/renderPage only ever paginate within the 125 cached rows (next disables when end >= allRows.length). So if a filter matches more than 125 records, the user sees e.g. '5,000 rekod' but can never page past row 125 — older logs are silently inaccessible. For an audit log this is a real correctness problem (auditors will conclude records are missing).
- **Bukti:** `const { data, count } = await q.range(0, PAGE_SIZE * 5 - 1); // grab 5 pages worth
  allRows = data || [];
  totalCount = count || 0;
  ...
  document.getElementById('page-next').disabled = end >= allRows.length;`
- **Cadangan:** Either implement true server-side pagination (fetch q.range(currentPage*PAGE_SIZE, ...) on each changePage), or at minimum cap the displayed total to the fetched window (e.g. show Math.min(totalCount, allRows.length)) and surface a 'memaparkan 125 terkini' note so the UI does not promise unreachable rows.

### (logic) roles/staff/coaching-catalog.html — Supabase errors not detected; success banner shown on failed save
- **Di mana:** saveItem()
- **Masalah:** The supabase-js client does not throw on DB errors (RLS denial, constraint violation, not-null, etc.); it returns { data, error }. saveItem awaits insert/update but never reads the returned `error`, so the try/catch never fires for a DB-level failure. The code always proceeds to banner('Disimpan'), closeForm(), load() even when nothing was written, telling the user the item was saved when it was not.
- **Bukti:** `if (editingId) {
      await window.db.from('psy_coaching_catalog').update(data).eq('id', editingId);
    } else {
      await window.db.from('psy_coaching_catalog').insert({...});
    }
    banner('Disimpan');`
- **Cadangan:** Capture and check the result, e.g. `const { error } = await window.db...update(...)`; `if (error) { banner('Ralat: ' + error.message, 'error'); return; }` for both branches before showing success.

### (logic) roles/staff/coaching-catalog.html — toggleActive ignores Supabase error and always reports success
- **Di mana:** toggleActive()
- **Masalah:** Same root cause: supabase-js returns { error } instead of throwing. toggleActive awaits the update without reading `error`, so the try/catch cannot catch a DB-level failure (e.g. RLS). The user sees 'Diaktifkan'/'Dinyahaktif' even if the update was rejected; load() then re-renders the unchanged state, confusing the user.
- **Bukti:** `await window.db.from('psy_coaching_catalog').update({ is_active: newState, updated_at: new Date().toISOString() }).eq('id', id);
    banner(newState ? 'Diaktifkan' : 'Dinyahaktif');`
- **Cadangan:** Use `const { error } = await ...; if (error) { banner('Ralat: ' + error.message, 'error'); return; }` before the success banner.

### (logic) roles/staff/coaching-catalog.html — deleteItem ignores Supabase error; 'Dibuang' shown even when delete blocked
- **Di mana:** deleteItem()
- **Masalah:** Destructive delete awaits the supabase-js call without reading `error`. Since supabase-js does not throw on RLS/foreign-key failures, the try/catch will not trigger, and banner('Dibuang') is shown even if the row was not deleted. load() then re-renders the item still present, contradicting the success message.
- **Bukti:** `await window.db.from('psy_coaching_catalog').delete().eq('id', id);
    banner('Dibuang');
    load();`
- **Cadangan:** Capture `const { error } = await ...` and only show 'Dibuang' when !error; otherwise banner the error.

### (logic) roles/staff/coaching.html — 'Minggu Ini' chip double-counts past-week sessions and omits upcoming ones
- **Di mana:** main load IIFE — count-week assignment (line 173)
- **Masalah:** weekSessions is already filtered to (>= weekStart && <= weekEnd && < todayStart). The third term of the count-week sum filters the SAME range (>= weekStart && < todayStart), so every before-today session this week is added twice. The result is an inflated, wrong number. It also never adds the upcomingWeek sessions (sessions later this week after today), so the chip neither matches its label ('Minggu Ini') nor the cards rendered below. The chip count is simply incorrect.
- **Bukti:** `document.getElementById('count-week').textContent  = todaySessions.length + weekSessions.length + all.filter(s => s.session_date >= weekStart && s.session_date < todayStart).length;`
- **Cadangan:** Compute a single deterministic week set and use its length, e.g. const weekAll = all.filter(s => s.session_date >= weekStart && s.session_date <= weekEnd); document.getElementById('count-week').textContent = weekAll.length;

### (logic) roles/staff/inventory-detail.html — Reads computed-only field dynamic_monthly off the raw DB row (always undefined)
- **Di mana:** renderDetail() — needed = Number(item.dynamic_monthly)
- **Masalah:** dynamic_monthly is NOT a column on psy_inventory_items (DB schema only has name, category, unit, qty_in_stock, min_qty, requires_approval, notes, consumption_type, supplier_info, last_auto_po_at). It is computed at runtime only by computeDynamicDemand() in inventory.html. This page loads the item via select('*') and never computes it, so item.dynamic_monthly is always undefined → needed=0. Consequently weeklyUsage=0, runway=null, the package threshold falls back to min_qty, and 'Anggaran penggunaan' / 'Runway' always show '—' for package items. The whole per-package demand calculation on this detail page is dead.
- **Bukti:** `const needed = Number(item.dynamic_monthly) || 0;`
- **Cadangan:** Compute demand on this page too: load active patients + packages + kits and run the same computeDynamicDemand logic (ideally extract it into shared/stockSync.js or _shared.js and reuse), or persist dynamic_monthly/demand_breakdown server-side. Do not read them as if they were DB columns.

### (logic) roles/staff/inventory-detail.html — Reads computed-only field demand_breakdown off raw DB row → 'Permintaan Berdasarkan Pakej' card always shows empty state
- **Di mana:** renderDetail() — const bd = item.demand_breakdown || []
- **Masalah:** Like dynamic_monthly, demand_breakdown is only ever set in-memory by computeDynamicDemand() in inventory.html; it is not a column on psy_inventory_items. Here item.demand_breakdown is always undefined → bd=[]. Because of `if (!bd.length || type !== 'package')`, the card permanently renders the 'Item ini tidak dikira berdasarkan pakej' empty state even for genuine package-type items, making the headline 'Permintaan Berdasarkan Pakej' feature non-functional on this page.
- **Bukti:** `const bd = item.demand_breakdown || [];
  if (!bd.length || type !== 'package') {`
- **Cadangan:** Populate demand_breakdown by running the demand computation on this page (shared helper), or fetch it from a view/RPC. Until then the package-demand card cannot work.

### (logic) roles/staff/issue-detail.html — renderChat references out-of-scope variables 'approvals' and 'rejects' (ReferenceError)
- **Di mana:** renderChat()
- **Masalah:** Inside renderChat(), the code reads `approvals` and `rejects` to build approvedReqIds/rejectedReqIds sets. But these two variables are declared with `const` only inside loadDetail() (lines 187-188) and are NOT module-level (only currentIssue, productsList, issueId are). When the chat thread contains any 'issue.replacement_requested' message — the only branch that needs approvedReqIds/rejectedReqIds — and even before that, the two Set constructions run unconditionally at the top of renderChat, so accessing the undeclared identifiers throws a ReferenceError. This aborts renderChat, leaving the chat area blank/broken for any issue that has replacement activity.
- **Bukti:** `const approvedReqIds = new Set(approvals.map(a => a.meta?.request_id).filter(Boolean));
  const rejectedReqIds = new Set(rejects.map(r => r.meta?.request_id).filter(Boolean));`
- **Cadangan:** Pass approvals/rejects into renderChat as arguments (e.g. renderChat(currentIssue, allMsgs, approvals, rejects)) or hoist them to module scope so they are reachable from renderChat. Currently loadDetail calls renderChat(currentIssue, allMsgs) without them.

### (logic) roles/staff/kepatuhan-fill.html — Amalan item render reads wrong field names (it.description / it.icon) vs schema (nota / meta.icon)
- **Di mana:** sfRenderAmalan()
- **Masalah:** Even if the item query were fixed, the render uses it.description and it.icon, but psy_kepatuhan_item exposes `nota` (description text) and `meta.icon` (icon). The patient version uses it.meta?.icon and it.nota. As written, descriptions and icons would never display.
- **Bukti:** `${it.icon||'💊'}  ...  ${it.description?`<div ...>${it.description}</div>`:''}`
- **Cadangan:** Use it.meta?.icon (fallback to a default) and it.nota to match the psy_kepatuhan_item schema, consistent with roles/patient/kepatuhan.html.

### (logic) roles/staff/kob-list.html — Patient name with apostrophe breaks the Padam (delete) button onclick
- **Di mana:** render() — delete button onclick
- **Masalah:** The delete button passes patName/dateStr into an inline onclick as JS single-quoted string arguments, but uses escapeHtml() which converts ' to the HTML entity &#39;. The browser decodes the attribute back to a literal ' before the JS parser runs, so a name like O'Brien produces deleteKob('id','O'Brien','...') — a JS syntax error that makes the Padam button throw and do nothing for any patient whose name (or formatted date) contains an apostrophe. The codebase has a dedicated escapeJsAttr() helper in shared/utils.js intended for exactly this (JS single-quoted string inside an HTML attribute).
- **Bukti:** `<button onclick="deleteKob('${k.id}','${escapeHtml(patName)}','${escapeHtml(dateStr)}')" class="text-xs text-terracotta font-semibold hover:underline">Padam</button>`
- **Cadangan:** Use window.escapeJsAttr(patName) / escapeJsAttr(dateStr) for the onclick string arguments (keep escapeHtml only for values rendered as HTML text).

### (logic) roles/staff/kob-slots.html — Slot 'Nota' is collected but never saved to psy_kob_slot_config
- **Di mana:** submitSlotModal()
- **Masalah:** The slot modal has a Nota textarea (#slot-note). submitSlotModal reads it into `note` (const note = ...trim()), and openEditSlot loads it back via sample.note. But NONE of the insert/update calls for psy_kob_slot_config include a `note` column. The update (line 768) sets only {label, slot_start, slot_end, updated_at}; both inserts (lines 770, 781) omit note entirely. Result: any note the staff types is silently discarded and never persisted, so editing later always shows an empty/old note. The `note` variable is a dead write.
- **Bukti:** `const note = document.getElementById('slot-note').value.trim();
...
await window.db.from('psy_kob_slot_config').update({ label, slot_start: start, slot_end: end, updated_at: new Date().toISOString() }).eq('id', existingByDay[day].id);
...
c`
- **Cadangan:** Include `note` in both the insert payloads and the update payload, e.g. add `note: note || null` to the row objects in submitSlotModal so the value the user typed is actually saved.

### (logic) roles/staff/pakej-edit.html — "Simpan Draft" sets f-status to 'draft' but the select has no 'draft' option, so it silently saves as active=false/status=active
- **Di mana:** saveAsDraft() + #f-status select
- **Masalah:** saveAsDraft() does document.getElementById('f-status').value = 'draft' then calls savePackage(). The <select id="f-status"> only declares options value="active" and value="inactive" — no 'draft' option. Setting .value to a non-existent option makes the select's value become '' (empty string). In savePackage(), status becomes ('' || 'active') = 'active', while is_active = ('' === 'active') = false. Result: the row is saved with the contradictory pair status='active' + is_active=false, never status='draft'. The draft is never actually flagged as a draft, and syncHeader()'s status chip falls back to 'Aktif' instead of 'Draft'. The whole 'Simpan Draft' button does not do what it claims.
- **Bukti:** `function saveAsDraft() {
  document.getElementById('f-status').value = 'draft';
  syncHeader();
  savePackage();
}
... 
<select id="f-status" onchange="syncHeader()" ...>
  <option value="active">Aktif</option>
  <option value="inactive">Ti`
- **Cadangan:** Add <option value="draft">Draft</option> to the #f-status select (the syncHeader map already supports 'draft'), or have saveAsDraft() carry the draft status through a dedicated variable/payload override instead of relying on the select value.

### (logic) roles/staff/pakej-laporan.html — doneCount checks for status 'completed' which is not an allowed patient status
- **Di mana:** init() - doneCount = inPkg.filter(x => x.status === 'completed' || ...)
- **Masalah:** psy_patients.status has a CHECK constraint allowing only ('pending_kyc','active','inactive','rejected') (master_migration.sql line 92). There is no 'completed' value, so the 'completed' branch of the doneCount filter can never match. The 'Selesai' column will only ever count 'inactive' patients, which is likely not the intended meaning of completed/finished treatment.
- **Bukti:** `const doneCount   = inPkg.filter(x => x.status === 'completed' || x.status === 'inactive').length;`
- **Cadangan:** Align with the actual schema: decide what 'selesai' means (e.g. package_expires_at in the past, or a dedicated outcome status) rather than a non-existent 'completed' status, or add 'completed' to the allowed status set.

### (logic) roles/staff/pakej.html — Status filter 'Tidak Aktif' (value=inactive) never filters anything
- **Di mana:** pkgFiltered() vs #pkg-status-filter options
- **Masalah:** The status dropdown emits value 'inactive' for the inactive option, but pkgFiltered() only handles statusF==='active' and statusF==='draft'. The 'inactive' value matches neither branch, so selecting 'Tidak Aktif' returns ALL packages instead of only inactive ones. The filter silently does nothing.
- **Bukti:** `<option value="inactive">Tidak Aktif</option> ... if (statusF === 'active' && !p.is_active) return false; if (statusF === 'draft'  &&  p.is_active) return false;`
- **Cadangan:** Change the condition to `if (statusF === 'inactive' && p.is_active) return false;` (or change the option value to 'draft') so the dropdown value and the filter branch agree.

### (logic) roles/staff/pengumuman-baru.html — Event validation failures leave Save/Publish buttons permanently disabled
- **Di mana:** submitForm() — event branch validation after btns disabled
- **Masalah:** The buttons are disabled (btns.forEach(b => b.disabled = true)) BEFORE the event-specific validation runs inside the try block. The checks for missing date/start time and missing location call `return fail(...)`, which shows the error but does NOT re-enable the buttons (only the catch block re-enables them). So if a user picks an event type, leaves the date or location blank, and clicks Save/Publish, both buttons become disabled forever and the user cannot retry without reloading the page.
- **Bukti:** `const btns = document.querySelectorAll('#publish-btn, [onclick^="submitForm"]');
  btns.forEach(b => b.disabled = true);
  try {
    if (t.kind === 'event') {
      ...
      if (!date || !start) return fail('Tarikh & Masa Mula event wajib`
- **Cadangan:** Move the event date/start/location validation ABOVE the `btns.forEach(b => b.disabled = true)` line (alongside the other up-front validations), or re-enable buttons in each early-return: `btns.forEach(b => b.disabled = false); return fail(...)`.

### (logic) roles/staff/peranan.html — All audit log rows record actor_id/actor_email = null (window.currentUser never set on this page)
- **Di mana:** init() + all window.db.from('psy_permission_audit').insert(...) calls
- **Masalah:** The inline init() calls checkAuth('staff') and stores the result in a LOCAL const `user`, but never assigns window.currentUser. window.currentUser is only set inside initStaff() in _shared.js, which this page never calls (it has its own init()). So window.currentUser stays null (the value it is initialised to in _shared.js line 5) for the whole page. Every audit insert in saveMatrix, saveRole, deleteCurrentRole, cycleOverride, clearAllOverrides and toggleRoleActive therefore writes actor_id:null and actor_email:null. On a Super-Admin-only RBAC/security page, the audit trail loses who made every permission change.
- **Bukti:** `const user = await checkAuth('staff'); ... actor_id: window.currentUser?.id || null, actor_email: window.currentUser?.email || null,`
- **Cadangan:** After checkAuth in init(), set window.currentUser = user; (or call initStaff() like other staff pages) so audit rows capture the acting Super Admin.

### (logic) roles/staff/plan-week.html — Staff per-week editor cannot represent or set 'consultation_done'/'booked'/extension statuses
- **Di mana:** renderHero() statusMap ~L585-592 and attendance buttons ~L608-643
- **Masalah:** The main coach editor's statusMap only knows hadir/reschedule/cancel/pending. When a session is 'consultation_done' (set by staff/consultation.html when SOAP signed), 'booked', 'extension_pending_payment' or 'extension_paid', renderHero falls back to 'pending' (⏳ Pending) — so a completed/booked session displays as Pending to the coach. The attendance buttons also only offer 'hadir' and 'cancel'; a coach cannot move a session to 'consultation_done' here, yet the patient page and patient-hub treat 'consultation_done' as the terminal 'Selesai' state. The two surfaces disagree about whether the same row is done vs pending.
- **Bukti:** `L586-591: const statusMap = { hadir:..., reschedule:..., cancel:..., pending:... };  const s = statusMap[status] || statusMap.pending;  (no consultation_done / booked / extension_* keys)  vs roles/patient/plan.html L825 'if (status === "had`
- **Cadangan:** Add consultation_done/booked/extension_pending_payment/extension_paid entries to the staff plan-week statusMap (mirror patient-hub L2780 map) so a finished or booked session is not mislabelled 'Pending' in the coach editor.

### (logic) roles/staff/products.html — Supabase update error never caught — shows success banner on failure
- **Di mana:** toggleStatus()
- **Masalah:** Supabase JS does not reject/throw on a DB error; it resolves with an { error } object. toggleStatus() awaits the update without destructuring { error }, so a failed update (RLS denial, constraint, network-level DB error) still falls through to the success banner and the local state is mutated optimistically. The catch block only fires on a thrown network exception, not on returned DB errors. User sees 'Produk diaktifkan' even though nothing changed in the DB.
- **Bukti:** `await window.db.from('psy_products').update({ status: newStatus, is_active: newStatus === 'active' }).eq('id', id);
    p.status = newStatus; p.is_active = newStatus === 'active';
    banner(newStatus === 'active' ? 'Produk diaktifkan ✅' :`
- **Cadangan:** Destructure and check the error: const { error } = await window.db.from('psy_products').update({...}).eq('id', id); if (error) throw error;

### (logic) roles/staff/products.html — Supabase delete error never caught — shows success banner and removes row on failure
- **Di mana:** delProduct()
- **Masalah:** Same pattern as toggleStatus: the delete() result is awaited but { error } is never read. Supabase returns errors as a value, not a thrown exception, so an RLS/constraint failure (e.g. FK reference from orders) returns { error } and the code proceeds to filter the product out of allProducts and show 'Produk dipadam', misleading the user into thinking a still-present product was deleted. The row reappears on next load.
- **Bukti:** `await window.db.from('psy_products').delete().eq('id', id);
    allProducts = allProducts.filter(p => p.id !== id);
    banner('Produk dipadam ⛔');`
- **Cadangan:** const { error } = await window.db.from('psy_products').delete().eq('id', id); if (error) throw error; (then proceed).

### (logic) roles/staff/risk.html — Resolve writes to non-existent column action_notes — every resolve fails
- **Di mana:** confirmRiskAction()
- **Masalah:** confirmRiskAction calls dbUpdate('psy_risk_alerts', id, { status, resolved_at, action_notes }). The psy_risk_alerts table (database/master_migration.sql lines 832-845, and part2_step11_20.sql) has columns id, patient_id, patient_name, created_by, created_by_name, severity, category, description, status, acknowledged_by, resolved_at, created_at — but NO action_notes column. 'action_notes' appears nowhere in any .sql migration in the repo (only in this file). dbUpdate (config/supabase.js) does .update(updates)...select() and throws on error, so PostgREST returns a schema-cache error ('Could not find the action_notes column of psy_risk_alerts') and the resolve always throws. The user always sees the 'Ralat:' banner and the alert is NEVER marked resolved — the core action of the page is broken.
- **Bukti:** `await dbUpdate('psy_risk_alerts', pendingAction.id, {
      status: 'resolved',
      resolved_at: new Date().toISOString(),
      action_notes: notes,
    });`
- **Cadangan:** Add an action_notes (TEXT) column to psy_risk_alerts via migration AND to database/master_migration.sql, OR drop the action_notes field from the update payload (and remove the notes textarea if it is not stored). If notes should be persisted, also add the column to the base schema so it survives a fresh deploy.

### (logic) roles/staff/session-notes.html — Risk alert insert uses non-existent columns source/note — silently fails inside try/catch
- **Di mana:** saveNotes() — psy_risk_alerts insert
- **Masalah:** When signing a SOAP note flagged high/critical, the code inserts into psy_risk_alerts using columns `source` and `note`. The psy_risk_alerts table (database/master_migration.sql:832 and part2_step11_20.sql:208) has NO `source` or `note` columns; its descriptive column is `description`. The insert will be rejected by PostgREST (unknown column), but it is wrapped in `try { ... } catch {}` with an empty catch, so the failure is swallowed silently. Result: the UI promises 'Risiko >= Medium akan trigger risk alert untuk follow-up' but no risk alert row is ever created for high/critical sessions, and neither the coach nor the dev sees any error.
- **Bukti:** `await window.db.from('psy_risk_alerts').insert({
          patient_id: currentRow.patient_id,
          severity:   currentRisk,
          source:     'session_notes',
          note:       payload.risk_note || 'Risk flagged dalam SOAP note`
- **Cadangan:** Match the real schema: drop `source`, put the text into `description` (e.g. description: (payload.risk_note ? payload.risk_note+' ' : '') + '[Sumber: SOAP session notes]'), and optionally set patient_name: currentRow.patient?.full_name and created_by_name. Also remove the empty catch (or at least banner a warning) so a failed risk-alert insert is not silently lost.

### (logic) roles/staff/surat-edit.html — Undefined variable DEFAULT_AUTO_FIELDS throws ReferenceError when adding a new auto-field
- **Di mana:** saveAutoField()
- **Masalah:** saveAutoField() references DEFAULT_AUTO_FIELDS to compute the list of reserved default keys, but no variable named DEFAULT_AUTO_FIELDS exists anywhere — this file defines DEFAULT_AUTO_FIELDS_SEED (line 691) instead, and shared/letterTemplates.js / _shared.js never export DEFAULT_AUTO_FIELDS. When a staff clicks Simpan in the Add Auto Field modal, the line `const defaultKeys = DEFAULT_AUTO_FIELDS.map(...)` throws 'DEFAULT_AUTO_FIELDS is not defined'. The throw happens BEFORE the try/catch (line 660), so it is uncaught: no banner shown, the modal stays open, and the auto-field is never inserted into psy_letter_auto_fields. Creating new auto-fields is fully broken.
- **Bukti:** `const defaultKeys = DEFAULT_AUTO_FIELDS.map(f => f.key);
  if (defaultKeys.includes(key) && !editingAutoFieldId) { banner('Key dah ada sebagai default', 'error'); return; }`
- **Cadangan:** Use the actually-defined constant: `const defaultKeys = DEFAULT_AUTO_FIELDS_SEED.map(f => f.key);` (or rename DEFAULT_AUTO_FIELDS_SEED to DEFAULT_AUTO_FIELDS).

### (security) database/master_migration.sql — psy_payments INSERT policy uses WITH CHECK (true) — any user can forge payment records
- **Di mana:** psy_payments RLS policy 'Patients insert own payments' (line 441)
- **Masalah:** psy_payments holds financial records (receipt_ref, patient_id, total, status='completed'). The INSERT policy named 'Patients insert own payments' has WITH CHECK (true), so ANY authenticated user can insert a payment row for ANY patient_id with status 'completed' and an arbitrary total. There is no check tying patient_id to auth.uid(). This lets a patient fabricate paid-receipt rows (and pollute another patient's payment history). Client code does insert into this table from roles/patient/payment.html and roles/patient/_shared.js.
- **Bukti:** `database/master_migration.sql:441  CREATE POLICY "Patients insert own payments" ON psy_payments FOR INSERT WITH CHECK (true);`
- **Cadangan:** Tighten WITH CHECK to patient_id IN (SELECT id FROM psy_patients WHERE user_id = auth.uid()), or restrict payment inserts to service_role / an Edge Function and remove the client-side insert path.


## MEDIUM

### (consistency) roles/staff/plan-week.html — 'reschedule' status is read by both sides but no UI path actually writes it; patient/staff label it differently from 'cancel'
- **Di mana:** renderHero() missControl/markStatus comments ~L587-590, L716 vs patient renderSession L836
- **Masalah:** Both patient plan.html (renderSession L836 '🔄 Reschedule', legacy L643) and staff plan-week (statusMap L588) render a distinct 'reschedule' state, and staff dashboard markMissed writes status:'reschedule' (dashboard L785). However the actual coach reschedule flow (coachReschedule L757) and patient quickReschedule both set status back to 'booked', not 'reschedule'. So a session can be put into 'reschedule' only from the staff dashboard quick-action, and the patient's auto-mark instead uses 'cancel' for the same real-world event (missed/needs rebook). The same concept 'needs rebooking' is split across 'cancel' (patient auto) and 'reschedule' (staff dashboard), labelled 'Tidak Hadir' vs 'Reschedule' to the user.
- **Bukti:** `roles/staff/dashboard.html L785: .update({ status: 'reschedule' })  vs roles/patient/plan.html L1329: status:'cancel' for missed; coachReschedule roles/staff/plan-week.html L757: upsertProgress({ ... status:'booked' })`
- **Cadangan:** Define a single status for 'missed/needs rebooking' (recommend 'cancel', which the auto-mark and most readers use) and have the staff dashboard quick-action use it too, or formally document 'reschedule' as distinct and make the patient auto-mark + readers consistent with it.

### (db) database/master_migration.sql — Notifications INSERT policy WITH CHECK (true) allows spoofed/spam notifications to any user
- **Di mana:** psy_notifications policy "Anyone insert notifications" (~line 335)
- **Masalah:** psy_notifications has FOR INSERT WITH CHECK (true). Any authenticated user can insert notification rows targeting an arbitrary user_id with arbitrary title/body/link. Combined with the UPDATE policy that only lets the recipient mark their own notifications read, this is a phishing/spam vector: a patient could push a notification (e.g. a malicious link or fake 'staff' message) into another user's or a staff member's notification bell. Lower severity than the payments/medical issues because it does not directly mutate clinical/financial state, but it is still an unauthenticated-intent abuse channel.
- **Bukti:** `CREATE POLICY "Anyone insert notifications" ON psy_notifications FOR INSERT WITH CHECK (true);`
- **Cadangan:** Restrict notification creation to staff and to system/service contexts, e.g. WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id = auth.uid() AND role = 'staff')) for staff-originated notices, and create all automated/cross-user notifications via the service_role Edge Functions or a SECURITY DEFINER RPC rather than directly from the anon/authenticated client.

### (link) roles/staff/library.html — openPreview() calls undefined aksesBadge() and is never wired to any UI
- **Di mana:** openPreview()
- **Masalah:** openPreview() builds the preview modal and calls aksesBadge(it), but aksesBadge is not defined in this file nor in any loaded script (config/supabase.js, shared/*.js, _shared.js). It only exists in the sibling file library-view.html. Additionally, no element in this page ever invokes openPreview() (the 'Lihat' eye button navigates to library-view.html instead, and the prev-modal/prev-body are otherwise orphaned). So the entire preview feature is dead/unreachable, and if any future wiring triggers it, it will throw a ReferenceError on aksesBadge and the modal body will fail to render.
- **Bukti:** `function openPreview(id) {
  ...
      ${aksesBadge(it)}
  ...
  document.getElementById('prev-modal').classList.remove('hidden');`
- **Cadangan:** Either remove the dead openPreview()/prev-modal block, or wire the eye button to openPreview(it.id) and define/import aksesBadge() in this file (copy from library-view.html or move it into _shared.js).

### (link) roles/staff/pakej.html — Inactive packages labelled 'Draft' but filter/KPI call them inactive — terminology mismatch causes confusion only, not a hard break
- **Di mana:** renderPkgKpi() 'Pakej Aktif' card / statusChip()
- **Masalah:** statusChip renders non-active packages as 'Draft' while the filter dropdown labels the same state 'Tidak Aktif'. This is inconsistent labelling for the same boolean. Lower severity since it is cosmetic, but combined with the 'inactive' vs 'draft' value bug it makes the inactive filter appear broken to users (chip says Draft, filter option says Tidak Aktif, selecting it shows everything).
- **Bukti:** `return '<span ...>Draft</span>'; (statusChip)  vs  <option value="inactive">Tidak Aktif</option>`
- **Cadangan:** Pick one term (Tidak Aktif or Draft) and use it consistently in statusChip, the filter option label, and its value.

### (link) roles/staff/patient-hub.html — 'Nota Mingguan' button in Senarai Sesi does nothing (wnSetWeek undefined)
- **Di mana:** snViewNote() / renderSnTable() '📋 Nota Mingguan' button
- **Masalah:** Each row in the Sessions table renders a button onclick="snViewNote(week)". snViewNote only calls wnSetWeek(week) if typeof wnSetWeek === 'function', but wnSetWeek is never defined anywhere in the file (the week navigator uses wnJump/wnRender instead). So clicking '📋 Nota Mingguan' silently does nothing — no navigation, no error, the user gets zero feedback. Intended behaviour was almost certainly to jump the week navigator to that week.
- **Bukti:** `function snViewNote(week) { if (week && typeof wnSetWeek === 'function') wnSetWeek(week); }`
- **Cadangan:** Replace with the existing navigator API, e.g. function snViewNote(week){ if(week){ wnCurrentIdx = week-1; wnRender(); document.getElementById('week-nav')?.scrollIntoView({behavior:'smooth'}); } } (wnJump expects a 0-based index).

### (logic) roles/patient/checkin.html — Clicking a past completed day passes ?date= that kepatuhan.html ignores for patients
- **Di mana:** selectDay()
- **Masalah:** When a patient clicks a previously-completed day in the week strip, selectDay() navigates to 'kepatuhan.html?date=${ds}'. However kepatuhan.html only honours the 'date' query param when in staff-fill mode (_kfStaffPid truthy): line 1636 sets `const _kfDate = _kfStaffPid ? _kfQ.get('date') : null;`. For a normal patient _kfStaffPid is null, so _kfDate is forced null and _kfTarget falls back to today (line 1637). The patient silently lands on today's check-in instead of the historical date they clicked, so past-day review/edit from the calendar does not work.
- **Bukti:** `} else if (checkinDates.has(ds)) {
      location.href = `kepatuhan.html?date=${ds}`;
    }`
- **Cadangan:** Either make kepatuhan.html accept the patient-facing 'date' param (e.g. `const _kfDate = (_kfStaffPid ? _kfQ.get('date') : _kfQ.get('date'));` with a guard that the date is within an allowed window), or in checkin.html only allow selecting today and remove the past-day navigation so the link does not appear to do something it cannot.

### (logic) roles/patient/kepatuhan-flow-preview.html — Free-text 'Lain-lain' / 'Perasaan lain' / 'Reaksi lain' inputs are never captured
- **Di mana:** flow.addEventListener('input', ...) (lines 246-249)
- **Masalah:** The HTML renders text inputs with data-kfhother (emo/reaksi 'other'), data-kfotherinput (item/multi 'other'), but the only 'input' event handler matches just [data-kfsleep]. Typing into these fields never updates healthData.emotionOther, healthData.reaksiOther, or answersText[...], so the values are silently lost (and on re-render the field shows empty/old value). All the 'other' free-text capture is dead.
- **Bukti:** `flow.addEventListener('input',(e)=>{
  const sl=e.target.closest('[data-kfsleep]'); if(sl){ if(sl.dataset.kfsleep==='tidur')healthData.tidur=sl.value; else healthData.bangun=sl.value;
    const c=document.getElementById('kf-sleep-calc'); if`
- **Cadangan:** In the same input listener add handlers: const ho=e.target.closest('[data-kfhother]'); if(ho){ if(ho.dataset.kfhother==='emo')healthData.emotionOther=ho.value; else healthData.reaksiOther=ho.value; return; } const oi=e.target.closest('[data-kfotherinput]'); if(oi){ answersText[oi.dataset.kfotherinput]=oi.value; return; }

### (logic) roles/patient/kob.html — KYC self-heal query has no order — may evaluate a non-latest (e.g. old/rejected) submission
- **Di mana:** init() self-heal for pending_payment/paid (~line 1462)
- **Masalah:** When kob_status is 'pending_payment' or 'paid', the self-heal fetches one KYC submission with limit:1 but NO ordering. dbQuery() only applies ordering when an `order` option is passed, so Postgres returns an arbitrary row. If a patient has more than one submission (e.g. an old rejected one plus a newer pending one), the decision `subs[0].status !== 'rejected'` can be made on the wrong row, wrongly advancing (or failing to advance) kob_status to kyc_done. Everywhere else in this file the same table is queried WITH `.order('created_at',{ascending:false})` (e.g. line 691, 906), confirming latest-row is the intended semantics.
- **Bukti:** `const subs = await dbQuery('psy_kyc_submissions', { eq: { user_id: user.id }, limit: 1 }).catch(() => []);
    if (subs[0] && subs[0].status !== 'rejected') {`
- **Cadangan:** Add ordering so the latest row is evaluated: dbQuery('psy_kyc_submissions', { eq:{user_id:user.id}, order:{col:'created_at',asc:false}, limit:1 }).

### (logic) roles/patient/kob.html — Payment amount/title pulled from currentKob columns that may be unset, can send RM0 / 'undefined' to checkout
- **Di mana:** payRecommendedPackage()
- **Masalah:** The package detail view (renderRecommendedPackageDetail) loads name/price from the psy_packages row via recommended_package_id, but payRecommendedPackage instead reads currentKob.recommended_package_name and currentKob.recommended_package_price. If the doctor set recommended_package_id but those denormalized *_name/*_price columns are null/blank, `parseFloat(currentKob.recommended_package_price) || 0` yields amount 0 and the title shows 'Pakej: undefined'. The only guard checks recommended_package_id is present, not that price/name exist, so the patient can be routed to payment.html for an RM0 charge.
- **Bukti:** `amount: parseFloat(currentKob.recommended_package_price) || 0,
    packageId: currentKob.recommended_package_id,
    packageName: currentKob.recommended_package_name,`
- **Cadangan:** Source the price/name from the loaded psy_packages row (as renderRecommendedPackageDetail already does), or validate recommended_package_price > 0 before storing isw_pending_payment and routing to checkout.

### (logic) roles/patient/plan.html — offsetDays computed from row.session_date after it was already mutated
- **Di mana:** quickReschedule()
- **Masalah:** In quickReschedule, after dbUpdate sets session_date to newDate, the code does `const orig = new Date(row.session_date)` to compute the cascade offset. But `row` is the in-memory object from weeklyProgressRows and its session_date was NOT mutated by dbUpdate (dbUpdate only writes to DB), so `orig` still holds the original date — this part is actually fine. However the original missed session being rescheduled has status 'cancel', and cascadeShiftSessions filters out rows with status 'cancel', so the just-moved session is excluded from cascade (correct). The real concern: offsetDays here is the gap between the ORIGINAL cancelled date and the new suggested date, which for a missed (past) session is typically large/positive, so cascadeShiftSessions may push all subsequent booked weeks forward by that large offset unexpectedly. Verify this is intended; if not, cascade after a missed-session quick reschedule can shift the whole remaining plan by many days.
- **Bukti:** `const orig = new Date(row.session_date);
        const offsetDays = Math.round((newDate.getTime() - orig.getTime()) / 86400000);
        if (offsetDays !== 0) {
          const shifted = await cascadeShiftSessions(week, day, offsetDays);`
- **Cadangan:** Confirm whether a quick-reschedule of a single missed session should cascade-shift all later weeks by the (potentially large) gap. If not, scope the cascade to same-week only or skip cascade for 'cancel'→reschedule transitions.

### (logic) roles/patient/pulangan.html — Return submitted with empty photo_urls when all uploads fail, despite photos being mandatory
- **Di mana:** submitReturn()
- **Masalah:** Photos are declared mandatory (the '*' marker and the early guard `if (!photoFiles.length)`), but inside the upload loop a failed upload only does console.warn and `continue`. If every upload fails (RLS denial, missing/misconfigured 'issue-photos' bucket, network), `photoUrls` ends up `[]`, yet the code still inserts the row with `photo_urls: []`, shows the success banner, and resets the form. The patient believes evidence was sent; staff then see a return with zero photos to verify. There is no check that at least one photo uploaded before insert.
- **Bukti:** `for (const f of photoFiles) {
      const path = `returns/${window.currentUser.id}/${Date.now()}_${f.name}`;
      const { error } = await window.db.storage.from('issue-photos').upload(path, f);
      if (error) { console.warn('Photo upload`
- **Cadangan:** After the upload loop, guard before insert: if (!photoUrls.length) { banner('Foto gagal dimuat naik — sila cuba semula', 'error'); return; } so a return is never created without the required evidence photos.

### (logic) roles/patient/routine.html — switchTab handles 'stats' tab that has no button or pane
- **Di mana:** switchTab()
- **Masalah:** switchTab iterates only ['today','history'] for pane/button toggling, but then has a branch `if (tab === 'stats') loadStats();`. There is no tab-stats button or pane-stats element in the HTML, so 'stats' can never be triggered by the UI, and if it were it would call the broken loadStats(). This is leftover dead branching that signals an incomplete feature.
- **Bukti:** `if (tab === 'history') loadHistory();
  if (tab === 'stats') loadStats();`
- **Cadangan:** Remove the 'stats' branch (and loadStats) unless the Stats tab UI is being added.

### (logic) roles/patient/routine.html — Select/usage of completed_at column may not exist; activity stored but counts vs total can exceed 100%
- **Di mana:** loadHistory() / loadStats() — column 'completed_at'
- **Masalah:** loadHistory selects 'completed_at' and renders new Date(it.completed_at).toLocaleTimeString(...). If psy_daily_completions has no completed_at column the select errors out (data undefined) and 'Tiada rekod' shows even when records exist; if the column exists but is null, toLocaleTimeString renders 'Invalid Date'. Separately, history pct uses items.length / dailyCurrent.length: if the schedule was later shortened, a day with more completions than the current schedule length yields >100%. These are data-integrity edge cases worth confirming against the table schema.
- **Bukti:** `.select('log_date, item_time, activity, completed_at')
...
<span class="text-[10px] text-ink/40">${new Date(it.completed_at).toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit'})}</span>`
- **Cadangan:** Confirm psy_daily_completions has completed_at; guard the time render against null; clamp pct to 100 (Math.min(100, ...)).

### (logic) roles/patient/surat.html — Insert error not checked — failed request shows false success
- **Di mana:** submitRequest()
- **Masalah:** The Supabase .insert() into psy_letter_requests does not destructure or check the returned { error }. supabase-js does not throw on a row-level/RLS/constraint failure, so the surrounding try/catch never fires. On a silent failure the code still runs banner('Permohonan dihantar'), clears the form, and reloads the list — telling the patient their letter request was sent when nothing was saved. Every other patient page (kyc.html, feedback.html, kepatuhan.html, kob.html) uses the `const { error } = await ...; if (error) throw error;` pattern; this one omits it.
- **Bukti:** `await window.db.from('psy_letter_requests').insert({
      patient_id: patientRecord.id,
      patient_name: window.currentUser.full_name,
      template_code,
      template_name,
      reason,
      assigned_signer_id,
      status: 'pend`
- **Cadangan:** Capture the result and throw on failure so the catch block surfaces it: `const { error } = await window.db.from('psy_letter_requests').insert({...}); if (error) throw error;`

### (logic) roles/staff/acara-detail.html — Inconsistent event mode value checked ('online' vs 'f2f')
- **Di mana:** mode checks: tabPanel joinSteps (line 118) vs render (lines 166-167,202) vs Keperluan (135-136)
- **Masalah:** joinSteps and the Keperluan block branch on EV.mode === 'online' (online when equal to 'online'), while the date/platform grid and Lokasi block branch on EV.mode === 'f2f' (online for anything not 'f2f'). If EV.mode stores a third value (e.g. empty/null or 'hybrid'), the two halves of the page disagree: one half renders the online flow, the other renders the f2f flow, producing contradictory instructions for the same event.
- **Bukti:** `const joinSteps = EV.mode === 'online' ? [...] : [...];
...
${EV.mode==='f2f'?'F2F':'Online'}
...
${EV.mode==='f2f'?(EV.location||'Bersemuka'):'Google Meet'}`
- **Cadangan:** Pick one canonical check (e.g. const isOnline = EV.mode !== 'f2f') and use it everywhere so both halves agree.

### (logic) roles/staff/appointments.html — Timezone bug: wkYmd uses toISOString() on local-midnight dates, shifting the day in UTC+ zones
- **Di mana:** wkYmd / wkSame (week view)
- **Masalah:** wkYmd(d) returns d.toISOString().split('T')[0], which converts to UTC. Day-column dates are built from wkStartOfWeek which calls setHours(0,0,0,0) (LOCAL midnight). In Malaysia (UTC+8) local midnight becomes 16:00 the PREVIOUS day in UTC, so wkYmd returns the wrong (previous) date. The rest of the file deliberately uses localDateStr() to avoid exactly this. As a result wkSame(new Date(s.session_date), d) and closureMap[ymd] lookups in the week view can match the wrong day near day boundaries, putting sessions/closures in the wrong column. The month view (which uses localDateStr) is correct, so week and month views can disagree.
- **Bukti:** `function wkYmd(d)     { return d.toISOString().split('T')[0]; }
function wkSame(a, b) { return wkYmd(a) === wkYmd(b); }`
- **Cadangan:** Make wkYmd use localDateStr(d) (the existing local-date helper) instead of toISOString().

### (logic) roles/staff/appointments.html — markHadir sets current_week unconditionally, can move plan backward / inconsistent with advancePlanWeek
- **Di mana:** markHadir
- **Masalah:** markHadir does `await window.db.from('psy_treatment_plans').update({ current_week: week })` with no guard, so marking an EARLIER week as Hadir overwrites current_week with a smaller value and rewinds the plan. The parallel online path (joinMeet -> advancePlanWeek) instead advances to week+1 and guards with `nextWeek > current_week`. So F2F 'Hadir' and online 'Join Meet' produce different current_week values for the same session, and F2F can regress the plan progression.
- **Bukti:** `await window.db.from('psy_treatment_plans').update({ current_week: week }).eq('id', planId);`
- **Cadangan:** Use the same advancePlanWeek(planId, week) logic (advance to week+1, only if greater than current_week) in markHadir, instead of blindly setting current_week = week.

### (logic) roles/staff/assignment-review.html — Coach dropdown options are re-appended (duplicated) after every assignment
- **Di mana:** renderActionPanel() coach dropdown populate (line ~439)
- **Masalah:** renderActionPanel() is called once on load and again at the end of doAssign() (line 494). When isAdmin, it appends the full coachList to #coach-select without ever clearing previously appended <option> elements. After an admin reassigns a patient, the dropdown shows every coach twice (and again on each subsequent reassignment), corrupting the select. The initial HTML placeholder option is fine, but the JS-appended options accumulate.
- **Bukti:** `const sel = document.getElementById('coach-select');
    coachList.forEach(c => {
      const opt = document.createElement('option');
      opt.value = c.id;
      opt.textContent = c.full_name + (c.id === patient.coach_id ? ' (semasa)' : '`
- **Cadangan:** Before the forEach, reset the select to just the placeholder, e.g. sel.innerHTML = '<option value="">-- Pilih coach --</option>'; (or guard so options are only built once).

### (logic) roles/staff/assignment-review.html — super_admin role is excluded from the coach reassignment UI
- **Di mana:** renderActionPanel() isAdmin check (line 418) vs initStaff super_admin handling
- **Masalah:** isAdmin only matches 'admin' or 'manager'. _shared.js initStaff treats 'super_admin' as a privileged role that bypasses all access checks, yet on this page a super_admin sees no coach dropdown / reassign controls and can only 'Assign to Me'. A super_admin cannot reassign a patient to a colleague, which is almost certainly unintended.
- **Bukti:** `const isAdmin    = myRole === 'admin' || myRole === 'manager';`
- **Cadangan:** Include super_admin: const isAdmin = ['admin','manager','super_admin'].includes(myRole);

### (logic) roles/staff/assignments.html — Role checks read window.currentUser.staff_role but doArchivePatient/loadStats use myRole and the two can diverge for actor_role audit
- **Di mana:** quickAssign / doUnassign / loadData role gate
- **Masalah:** quickAssign and doUnassign gate on role = window.currentUser.staff_role ('admin'/'manager'/'coach'), while loadStats/doArchivePatient gate on myRole (also staff_role). However the psy_audit_log insert writes actor_role: window.currentUser.role || 'staff'. window.currentUser.role is the profile role (e.g. 'staff'/'patient'), NOT staff_role, so every audit entry records the generic profile role instead of the actual staff_role (admin/coach), making the audit trail misleading about who performed admin-only actions like unassign/archive.
- **Bukti:** `const role = window.currentUser.staff_role; ... actor_role: window.currentUser.role || 'staff',`
- **Cadangan:** Use window.currentUser.staff_role (or the already-captured role/myRole) for actor_role in the audit inserts so the log reflects the real staff role.

### (logic) roles/staff/audit-kebenaran.html — Actor filter applied client-side after server-side limit(200), so matches beyond the latest 200 rows are silently missed
- **Di mana:** loadAudit()
- **Masalah:** The query fetches only the 200 most-recent rows matching the date/action/module filters via .limit(200). The 'Carian Aktor' filter is then applied in JS on those already-truncated rows (rows.filter on actor_email). If the actor's activity is older than the latest 200 matching rows, the search returns nothing even though matching records exist, making the actor search appear broken for active environments. Because actor is presented as a top-level filter (and the DB column actor_email exists, so it could be pushed to the server with .ilike), users will reasonably expect a full search.
- **Bukti:** `let q = window.db.from('psy_permission_audit').select('*').order('created_at',{ascending:false}).limit(200);
...
const { data, error } = await q;
...
let rows = data || [];
if (fActor) rows = rows.filter(r => (r.actor_email || '').toLowerCa`
- **Cadangan:** Push the actor filter to the server before limiting, e.g. `if (fActor) q = q.ilike('actor_email', '%' + fActor + '%');`, so the limit applies to actor-matched rows rather than filtering an already-capped page.

### (logic) roles/staff/audit.html — Single quote in logged data breaks the raw-view button and onclick
- **Di mana:** renderRow / showRaw onclick attribute
- **Masalah:** The ⋮ button embeds the row JSON into an onclick attribute that is delimited by single quotes. JSON.stringify escapes double quotes and backslashes but NOT single quotes (apostrophes). Audit meta routinely contains free text (issue titles, rejection reasons, patient names) which can include an apostrophe (e.g. "O'Brien", "can't"). Any such character terminates the single-quoted HTML attribute early, producing broken markup and a JS syntax error when the button is clicked, so showRaw fails for those rows.
- **Bukti:** `<button onclick='showRaw(${JSON.stringify(JSON.stringify(r))})' class="text-ink/40 ..." title="Lihat data mentah">⋮</button>`
- **Cadangan:** Avoid inlining the JSON in the attribute. Store rows by index and call showRaw(idx) reading from allRows, or HTML-escape the attribute value (replace ' with &#39; and " with &quot;) before injecting.

### (logic) roles/staff/coaching.html — Join button reads s.meet_link, a column that does not exist on psy_plan_weekly_progress
- **Di mana:** sessionCard() — meet_link rendering (line 107)
- **Masalah:** The session rows come from psy_plan_weekly_progress (select '*'). That table's schema has no meet_link column (columns: plan_id, patient_id, week_number, status, score, notes, coaching_checks, appointment_id, updated_by, updated_by_name, session_date, ...). So s.meet_link is always undefined and the conditional '🎥 Join' button never renders for any session. If a video-join link is intended, it must be sourced from the related appointment/meeting record (e.g. via appointment_id) rather than this table.
- **Bukti:** `${s.meet_link ? `<a href="${escapeHtml(s.meet_link)}" target="_blank" ...>🎥 Join</a>` : ''}`
- **Cadangan:** Join from psy_appointments (via appointment_id) to fetch the meeting link, or remove the dead Join button. Confirm the actual column name (e.g. meeting_link / meet_link on psy_appointments) before wiring it.

### (logic) roles/staff/inventory.html — Managers cannot see 'Tandakan Dibeli' button despite being authorized
- **Di mana:** renderRequests() — approved-status action branch
- **Masalah:** The 'Tandakan Dibeli' (mark purchased) button only renders when staffRole === 'admin'. But markPurchased() itself gates on isManagerOrAdmin() (can('inventory','approve')), which permits managers too. So a manager who is allowed to mark a request purchased can never reach the button in the UI — the action is effectively dead for managers. The visibility check and the handler's permission check are inconsistent.
- **Bukti:** `} else if (req.status === 'approved' && staffRole === 'admin') {
        actions = `
        <button onclick="markPurchased('${req.id}','${req.item_id}','${req.qty_requested}')"`
- **Cadangan:** Gate the button on the same permission used by the handler, e.g. `} else if (req.status === 'approved' && isManagerOrAdmin()) {` (or `can('inventory','approve')`), so managers see the action they are allowed to perform.

### (logic) roles/staff/issue.html — Replacement order_ref derived from a row COUNT can collide on UNIQUE column
- **Di mana:** confirmReplacement() — manager branch, order_ref generation
- **Masalah:** The replacement order reference is built from a count of existing REP-% orders plus one: 'REP-' + (repCount+1). order_ref is declared UNIQUE NOT NULL in psy_orders. If the count query errors (repCount is undefined -> falls back to 0 -> 'REP-001') or two replacements are created concurrently, two inserts compute the same ref and the second insert fails with a unique-constraint violation. The error is surfaced to the user as 'Ralat: ...' and the legitimate replacement silently fails to be created. There is no retry/guard on the count result.
- **Bukti:** `const { count: repCount } = await window.db.from('psy_orders').select('*', { count: 'exact', head: true }).like('order_ref', 'REP-%');
        const orderRef = 'REP-' + String((repCount || 0) + 1).padStart(3, '0');`
- **Cadangan:** Make order_ref collision-proof: append a short random/timestamp suffix (e.g. 'REP-' + Date.now().toString(36)) or generate the ref via a DB sequence/RPC, and on a unique-violation retry once before showing the error.

### (logic) roles/staff/kit-edit.html — Reads data.id without null/error guard after insert
- **Di mana:** saveKit() insert branch
- **Masalah:** On the create path, the insert result is destructured as { data } only (error ignored). If the insert fails (RLS denial, constraint, etc.) Supabase returns data=null, and the next line dereferences data.id, throwing 'Cannot read properties of null'. The thrown TypeError is caught by the surrounding try/catch but produces a confusing 'Cannot read properties of null' banner instead of the real DB error, masking the actual cause for the user/dev.
- **Bukti:** `const { data } = await window.db.from('psy_procedure_kits')
        .insert({ ...payload, created_by: window.currentUser.id })
        .select('id').single();
      document.getElementById('kit-id').value = data.id;`
- **Cadangan:** Destructure error too and check it / guard data: const { data, error } = await ...; if (error) throw error; if (!data) throw new Error('Insert returned no row'); before reading data.id.

### (logic) roles/staff/kit-prosedur.html — Supabase delete error not detected — false success on failure
- **Di mana:** deleteKit
- **Masalah:** The Supabase JS client does not throw on a query error; it resolves with an { error } object. The delete call ignores the returned error, so the catch block only fires on a thrown exception (e.g. network), not on a DB/RLS-rejected delete. On a failed delete the user still sees 'Kit dipadam' and the row reappears after init() reloads, giving a misleading success message.
- **Bukti:** `await window.db.from('psy_procedure_kits').delete().eq('id', id);
    banner('Kit dipadam');`
- **Cadangan:** Capture and check the error: const { error } = await window.db.from('psy_procedure_kits').delete().eq('id', id); if (error) { banner('Ralat: ' + error.message, 'error'); return; } then show success.

### (logic) roles/staff/kob-detail.html — Patient null-deref crashes render mid-way if patient join fails
- **Di mana:** render() lines 449-458
- **Masalah:** loadKob() swallows errors on the psy_patients query and sets patient = patData (which can be null on error/missing row). render() guards the header with patient?. but then unconditionally dereferences patient.user_id (KYC query) and patient.id (agreement query). If patient is null, this throws 'Cannot read properties of null' partway through render(), leaving the page half-rendered (name/status shown, but no agreement/questionnaire/buttons) with only a console error and no user-facing message.
- **Bukti:** `const { data: kycData } = await window.db.from('psy_kyc_submissions').select('documents').eq('user_id', patient.user_id) ... .eq('patient_id', patient.id)`
- **Cadangan:** After loading, guard: if (!patient) { show an error banner / message in app-shell and return; } or use patient?.user_id / patient?.id consistently and skip the dependent queries when patient is missing.

### (logic) roles/staff/kyc-review.html — Approving a self-registered KYC with no existing patient row never creates/activates the patient
- **Di mana:** doReview('approved') — psy_patients branch
- **Masalah:** On approval the code only acts when `pts?.[0]` exists (UPDATE ... WHERE id = pts[0].id). For a patient who self-registers and submits KYC, no psy_patients row is created at signup (handle_new_user only inserts psy_profiles) nor by kyc.html (it only inserts into psy_kyc_submissions), and the DB trigger sync_kyc_to_patient also only UPDATEs WHERE user_id (no INSERT). So if no patient row exists yet, approval updates only psy_profiles and sends the notification 'Akaun anda telah disahkan...', but no active psy_patients record is ever produced, leaving the approved user without a usable patient profile.
- **Bukti:** `const { data: pts } = await window.db.from('psy_patients').select('id').eq('user_id', kyc.user_id).limit(1);

      if (status === 'approved') {
        if (pts?.[0]) {
          await window.db.from('psy_patients').update({ ... }).eq('id',`
- **Cadangan:** Add an else-branch that inserts a new psy_patients row (user_id + KYC fields, status 'active') when pts?.[0] is falsy, or upsert on user_id, so self-registered approvals always result in an active patient record.

### (logic) roles/staff/library-categories.html — Category name with a double-quote breaks the inline onclick handler
- **Di mana:** loadCats() — rename/delete onclick attribute generation
- **Masalah:** escH() only escapes & < > but NOT double-quotes. The category name is injected inside a double-quoted onclick attribute (deleteCat('...','NAME')). A name containing a " character will terminate the attribute early, producing malformed HTML so the Padam (and the surrounding) buttons stop working for that row. Names are free-text from the Tambah/Edit prompts, so this is reachable.
- **Bukti:** `<button onclick="deleteCat('${c.id}','${escH(c.name).replace(/'/g,'')}')" class="text-xs font-semibold text-terracotta hover:underline">Padam</button>`
- **Cadangan:** Pass only the id and look the name up from CATS inside deleteCat (e.g. deleteCat('${c.id}')), or extend escH to also escape " (&quot;) and ' before interpolating into attributes.

### (logic) roles/staff/library-faq-edit.html — Private (Mengikut Pakej) FAQ with zero packages ticked silently becomes public
- **Di mana:** saveItem()
- **Masalah:** When the user picks akses='private' but ticks no packages, collectPkg() returns [] and package_ids is saved as null. On the patient side null/empty package_ids means 'all patients can see'. So a FAQ the staff intended to restrict is silently published to everyone. On reload the form even reverts the access radio back to 'Semua Pesakit' (hasPkg is false), hiding the mistake. There is no validation forcing at least one package when 'Mengikut Pakej' is selected.
- **Bukti:** `const pkgIds=akses==='private'?collectPkg():[];
... package_ids: pkgIds.length?pkgIds:null,`
- **Cadangan:** If akses==='private' and pkgIds.length===0, block save with banner('Sila pilih sekurang-kurangnya satu pakej','error') instead of saving null (which makes it public).

### (logic) roles/staff/patient-hub.html — Patient and staff compute treatment progress with different denominators/units
- **Di mana:** overview attendance ~L1854-1863 vs patient plan.html doneWeeks ~L456-460
- **Masalah:** Staff patient-hub overview computes done = count of weekly_progress ROWS with status in [hadir,consultation_done] and shows done/total where total = duration_weeks (i.e. it counts attended SESSIONS but labels them out of WEEKS). Patient plan.html computes doneWeeks by grouping rows per week and only incrementing when a week has >=2 sessions both attended. For a normal 2-session/week plan, staff will show roughly double the patient's completion (e.g. 4 attended sessions => staff '4/12 selesai' / 33%, patient '2/12 weeks' / 17%). The two roles see contradictory progress numbers for the same patient.
- **Bukti:** `roles/staff/patient-hub.html L1854: const done = ovWeeklyRows.filter(p => ['hadir','consultation_done'].includes(p.status)).length;  L1861: ov-attendance = `${done}/${total}` (total=duration_weeks)  vs roles/patient/plan.html L456-459: Obje`
- **Cadangan:** Pick one definition of a 'completed unit' (per-week-both-sessions, or per-session) and use it on both surfaces. If progress is reported per week, staff overview should aggregate sessions into weeks like the patient page does before dividing by duration_weeks.

### (logic) roles/staff/payment-admin.html — DB query errors are swallowed and crash silently
- **Di mana:** loadData / Promise.all
- **Masalah:** loadData() awaits two Supabase queries via Promise.all but never checks payRes.error / patRes.error. If the psy_payments or psy_patients query fails (RLS, network, bad column), payRes.data is null, allPayments falls back to [] and the page silently shows an empty table with no error feedback to the user. There is no try/catch around init()->loadData() either, so a thrown error leaves the loading spinner (#app-loading still controlled by initStaff) / table blank with no banner.
- **Bukti:** `const [payRes, patRes] = await Promise.all([
    query,
    window.db.from('psy_patients').select('id, mrn, status, psy_profiles(full_name)'),
  ]);

  allPayments = payRes.data || [];`
- **Cadangan:** Check payRes.error/patRes.error and surface via banner('Ralat memuatkan pembayaran', 'error'); wrap loadData body in try/catch.

### (logic) roles/staff/payment-admin.html — monthStart string-slice breaks for single-digit days in some month boundaries is fine, but >= compares ISO timestamp to date prefix relying on lexicographic match
- **Di mana:** renderKpi monthStart computation
- **Masalah:** todayTotal/monthTotal filter with p.paid_at >= today where today is 'YYYY-MM-DD' (10 chars) and paid_at is a full ISO timestamp. The comparison works only because the timestamp string starts with the same date prefix; however paid_at is stored in UTC (new Date().toISOString()) while today is derived from toISOString() too, so a payment made late local-evening can be attributed to the wrong calendar day vs the staff's local timezone (Malaysia UTC+8). Kutipan Hari Ini can show RM 0 or wrong totals near midnight.
- **Bukti:** `const today = new Date().toISOString().split('T')[0];
  ...
  const todayTotal  = allPayments.filter(p => p.status==='completed' && p.paid_at >= today)`
- **Cadangan:** Compute today/monthStart in local time (or compare on local-date strings derived from paid_at), since the clinic operates in UTC+8 and paid_at is stored as UTC.

### (logic) roles/staff/pengumuman-edit.html — Event draft shows wrong toggle button label ("Nyahaktifkan" instead of "Aktifkan")
- **Di mana:** render() statusTxt vs toggleActive button label (event branch)
- **Masalah:** For events, statusTxt is computed as (IT.status === 'published' ? 'Aktif' : IT.status), so a draft event yields the lowercase string 'draft'. The toggle button then compares statusTxt==='Draft' (capital D) which is never true for events. Result: a draft event renders the button as 'Nyahaktifkan Pengumuman' even though clicking it actually publishes/activates it (toggleActive flips draft->published). The button label is inverted/misleading for draft events. The same lowercase value also breaks the status pill color check (statusTxt==='Aktif') for non-published events, but the label inversion is the user-facing bug.
- **Bukti:** `const statusTxt = (isEvent ? (IT.status === 'published' ? 'Aktif' : IT.status) : (IT.is_active ? 'Aktif' : 'Draft'));
...
<button onclick="toggleActive()" ...>⊘ ${statusTxt==='Draft'?'Aktifkan':'Nyahaktifkan'} Pengumuman</button>`
- **Cadangan:** Normalize the event status to a label first, e.g. const statusTxt = isEvent ? (IT.status === 'published' ? 'Aktif' : 'Draft') : (IT.is_active ? 'Aktif' : 'Draft'); so the 'Draft' comparison works for both kinds.

### (logic) roles/staff/peranan.html — User override matrix renders ALL modules (no scope filter), unlike the role matrix which filters by scope
- **Di mana:** renderOverrideMatrix() vs renderMatrix()
- **Masalah:** renderMatrix() builds scopedModules = modules.filter(m => isPatientRole ? m.scope==='patient' : m.scope!=='patient'). The override modal's renderOverrideMatrix() instead maps over the full `modules` array unfiltered. Because openOverrideModal is only reachable for staff users (patient role shows no user list), staff users see patient-scoped (pat_*) module rows in their override matrix that are never shown in the role matrix, creating an inconsistent UI and allowing per-user overrides on modules outside the staff scope. The 'Berkesan' counter (modActions.forEach) likewise iterates every module|action pair across both scopes rather than the user's scope.
- **Bukti:** `document.getElementById('om-body').innerHTML = modules.map(m => { ... // no scope filter, compare renderMatrix(): const scopedModules = modules.filter(m => isPatientRole ? m.scope === 'patient' : m.scope !== 'patient');`
- **Cadangan:** Filter modules by m.scope !== 'patient' (staff scope) in renderOverrideMatrix and scope the effective-count loop the same way, matching renderMatrix.

### (logic) roles/staff/plan-week.html — Extension dedup keys disagree between staff (extension_for_week) and patient banner (week_number set)
- **Di mana:** createExtensionForWeek() ~L788-823 + autoMarkMissedAndExtend removed on patient side
- **Masalah:** Staff opens extension weeks keyed by extension_for_week and dedups on that column. The patient plan.html extension banner and the patient-side auto-mark logic key/group purely by week_number and is_extension, and never reads extension_for_week. removePendingExtensionIfResolved (staff) deletes pending extensions by extension_for_week. If a row was created by an older/other path without extension_for_week populated (e.g. patient-hub L1788-1789 inserts extension rows WITHOUT extension_for_week), staff cleanup will silently fail to find/void them while the patient still sees the 'bayar' banner — a broken hand-off where one side's voiding never reaches rows the other side created.
- **Bukti:** `roles/staff/plan-week.html L790 .eq('extension_for_week', origWeek) (dedup) & L830 .eq('extension_for_week', origWeek) (void)  vs roles/staff/patient-hub.html L1788: { ... status:'extension_pending_payment', is_extension:true, extension_pri`
- **Cadangan:** Always populate extension_for_week when inserting extension rows (fix patient-hub.html L1788-1789), and have the patient banner/void logic agree on that key so created and voided extensions reconcile across both roles.

### (logic) roles/staff/plan-week.html — .catch() chained directly on a raw Supabase query builder throws TypeError
- **Di mana:** loadGoals()
- **Masalah:** The Supabase PostgrestFilterBuilder is a thenable that implements .then() but NOT .catch(). Calling .catch() directly on window.db.from(...).select(...).eq(...) throws 'catch is not a function' synchronously, rejecting loadGoals(). Because loadGoals() runs inside the await Promise.all([...]) in loadWeek() (which has no try/catch), the whole loadWeek tail rejects: the BPS-S goals panel never renders and wireQuickCards() after the Promise.all may not run. Note other pages use .catch() on the dbQuery() wrapper (a real Promise), not on the raw builder, so this pattern is unique and broken here.
- **Bukti:** `const { data: checkIns } = await window.db.from('psy_plan_check_ins')
    .select('*').eq('plan_id', activePlan.id).eq('week_number', weekNumber).catch(() => ({ data: [] }));`
- **Cadangan:** Drop the .catch and use the normal destructure (errors come back in the { error } field), or wrap in try/catch: const { data: checkIns } = await window.db.from('psy_plan_check_ins').select('*').eq('plan_id', activePlan.id).eq('week_number', weekNumber); — then guard with (checkIns || []).

### (logic) roles/staff/product-detail.html — Duplicating spreads the full select('*') row into insert, risking insert errors on read-only/extra columns
- **Di mana:** duplicate()
- **Masalah:** duplicate() does `const clone = { ...product }` from a `select('*')` row, deletes only id/created_at/updated_at, then inserts the entire object. Any column present in the SELECT but not writable on insert (generated columns, columns dropped from the insert grant, or future-added server-managed fields) will cause the insert to fail. The failure is caught and shown as a banner, so it is not silent, but the clone feature can break whenever the table schema gains a non-insertable column.
- **Bukti:** `const clone = { ...product };
    delete clone.id; delete clone.created_at; delete clone.updated_at;`
- **Cadangan:** Build the insert payload from an explicit whitelist of known product columns (name, sku, product_id, category, price, stock, etc.) instead of spreading the whole select('*') row.

### (logic) roles/staff/products.html — Product name with double-quote breaks onclick attribute / entity-escaping leaks into confirm
- **Di mana:** renderTable() — delProduct onclick template
- **Masalah:** The delete button injects the product name into an inline onclick via escHtml(p.name).replace(/'/g,''). The onclick attribute value is wrapped in double quotes, but escHtml does NOT escape double quotes, so a product name containing a " terminates the attribute early and breaks the button (or injects attributes). Additionally, because the name is HTML-entity-escaped (& -> &amp; etc.) before being placed in a JS string, the confirm() dialog and any error context show entity-encoded text (e.g. 'Madu & Herba' shows as 'Madu &amp; Herba').
- **Bukti:** `<button onclick="delProduct('${p.id}', '${escHtml(p.name).replace(/'/g,'')}')" ...>`
- **Cadangan:** Do not pass the name through the onclick string at all — pass only the id and look up p.name inside delProduct (as duplicate() already does for confirm). Then escHtml is unnecessary for the JS arg.

### (logic) roles/staff/profile.html — 'Sesi Selesai' stat is not scoped to the current staff member
- **Di mana:** loadStats() — 'Sesi Selesai' query on psy_plan_weekly_progress
- **Masalah:** The personal 'Statistik Kerja' card 'Sesi Selesai' counts EVERY attended weekly-progress row in the date range, system-wide. The query selects the 'updated_by' column but never filters on it (no .eq('updated_by', u.id)), while every other card (patients via coach_id, appointments via staff_id, soap via doctor_id) is correctly scoped to u.id. Result: each staff sees the clinic-wide session count as if it were their own work, inflating the number.
- **Bukti:** `window.db.from('psy_plan_weekly_progress').select('id, status, session_date, updated_by').eq('status','hadir').gte('session_date', start).lte('session_date', end).then(r => r.data || [], () => [])`
- **Cadangan:** Add .eq('updated_by', u.id) to the psy_plan_weekly_progress query so the count reflects only sessions this staff member marked attended.

### (logic) roles/staff/profile.html — Patients and SOAP stats ignore the range end date, over-counting for 'Bulan Lepas'
- **Di mana:** loadStats() — patients & soap queries vs 'lastmonth' range
- **Masalah:** rangeBounds('lastmonth') sets end (now) to the last day of the previous month, and the sessions/appointments queries correctly apply both .gte(start) and .lte(end). But the patients and soap queries apply only .gte('created_at', start) with NO upper bound. So for 'Bulan Lepas' (and any past-window range) those two cards include all records from the start date right up to the real present moment, mixing current-month data into the last-month figure.
- **Bukti:** `window.db.from('psy_patients').select('id, created_at').gte('created_at', start).then(...)  /* no .lte('created_at', end) */ ... window.db.from('psy_soap_notes').select('id, created_at, doctor_id').eq('doctor_id', u.id).gte('created_at', st`
- **Cadangan:** Add .lte('created_at', end) to both the psy_patients and psy_soap_notes queries so they respect the computed range end like the other two cards.

### (logic) roles/staff/pulangan.html — Update result error not checked — failed verify/reject shows success banner
- **Di mana:** verifyReturn
- **Masalah:** The Supabase update call is awaited but its returned { error } is never inspected. Supabase JS does not throw on query errors (RLS denial, constraint, network 4xx) — it resolves with { data, error }. So if the update fails, no exception is thrown, the catch never fires, and the code proceeds to show 'Pulangan diterima/ditolak' banner and reload — but the row status is unchanged. Staff believe a return was verified when it was not. The patient side (roles/patient/pulangan.html line 253) correctly destructures and checks insertErr, so this is an inconsistency.
- **Bukti:** `await window.db.from('psy_bottle_returns').update({
      status: action,
      reject_reason: isReject ? reason.trim() : null,
      ...
    }).eq('id', returnId);
    // (no const { error } = ... ; no if(error) check)
    ...
    banner(i`
- **Cadangan:** Capture and check the error: const { error } = await window.db.from('psy_bottle_returns').update({...}).eq('id', returnId); if (error) throw error; before showing the success banner.

### (logic) roles/staff/pulangan.html — Insert result error not checked — failed message send appears to succeed
- **Di mana:** sendMessage
- **Masalah:** The psy_audit_log insert is awaited without destructuring/checking { error }. If the insert fails (RLS, network), Supabase JS resolves with an error object rather than throwing, so the catch block is not hit; the code clears the input (input.value = '') and calls loadReturns(), making it look like the message was sent when it was not. No user feedback on the silent failure.
- **Bukti:** `await window.db.from('psy_audit_log').insert({
      actor_id: window.currentUser.id,
      ...
      meta: { return_id: returnId, message: text },
    });
    // no { error } check
    ...
    input.value = '';
    loadReturns();`
- **Cadangan:** const { error } = await window.db.from('psy_audit_log').insert({...}); if (error) throw error; so the existing catch surfaces a banner and the input is not cleared on failure.

### (logic) roles/staff/services.html — Service name with an apostrophe breaks the delete button onclick
- **Di mana:** loadServices() row template — deleteService inline onclick
- **Masalah:** The service name is interpolated raw inside a single-quoted JS string argument in the inline onclick. If a service name contains a single quote (e.g. "Doctor's Visit") the generated attribute becomes onclick="deleteService('id','Doctor's Visit')" which produces a JS syntax error, so the Padam button throws on click and does nothing. Names are free text entered via the form so this is reachable.
- **Bukti:** `<button onclick="deleteService('${s.id}','${s.name}')" class="text-terracotta text-xs font-semibold">Padam</button>`
- **Cadangan:** Avoid embedding the raw name in inline JS. Pass only the id (e.g. deleteService('${s.id}')) and look up the name from data inside the handler, or escape the name (replace ' with \'/HTML-encode) before interpolating.

### (logic) roles/staff/staff-detail.html — Editing a super_admin staff silently demotes them to admin
- **Di mana:** enterEdit() / saveStaff() — #f-role <select>
- **Masalah:** The role dropdown only lists admin/doctor/coach/manager. The system actually defines 5 roles in psy_roles (super_admin, manager, admin, doctor, coach). When a super_admin staff record is opened, enterEdit() runs document.getElementById('f-role').value = 'super_admin', but since no such <option> exists the <select> silently falls back to its first option ('admin'). On Simpan, saveStaff() reads document.getElementById('f-role').value (now 'admin') and sends it to the update edge function, silently demoting a super_admin to admin without any warning. staff_management.html intentionally excludes super_admin from its create dropdown for security, but this detail page lets any save overwrite the role.
- **Bukti:** `<select id="f-role" ...>
  <option value="admin">Admin</option>
  <option value="doctor">Doctor</option>
  <option value="coach">Coach</option>
  <option value="manager">Manager</option>
</select>  ... document.getElementById('f-role').valu`
- **Cadangan:** Populate the f-role <select> dynamically from psy_roles (as staff_management.html does), or at minimum add a guard: if currentStaff.staff_role is not among the available options, append it as an option (or block editing) so a super_admin cannot be silently downgraded on save.

### (logic) roles/staff/surat.html — Template preview never loads auto-fields (AUTO_FIELDS stays empty)
- **Di mana:** previewTpl()
- **Masalah:** previewTpl() builds dummyValues from AUTO_FIELDS and the template's own fields, then calls renderLetterFull(). But AUTO_FIELDS is initialised empty ([]) in letterTemplates.js and only populated by the async loadCustomAutoFields() call. surat.html never calls loadCustomAutoFields() anywhere (the sibling surat-edit.html calls it before previewing). As a result, when staff click 'Preview' on the Templat tab, every auto-field placeholder (e.g. system date __today__, ref number, patient/staff data fields) is substituted with an empty string instead of a '[Label]' placeholder, so the preview shows blank gaps for those fields and misrepresents the real issued letter.
- **Bukti:** `function previewTpl(id) {
  const tpl = allTemplates.find(t => t.id === id);
  if (!tpl) return;
  const dummyValues = {};
  AUTO_FIELDS.forEach(f => dummyValues[f.key] = '[' + f.label + ']');`
- **Cadangan:** Call await loadCustomAutoFields() before rendering the preview (e.g. inside loadData() after window.db is ready, mirroring surat-edit.html), or make previewTpl async and await loadCustomAutoFields() at its start so AUTO_FIELDS is populated before building dummyValues.

### (security) database/master_migration.sql — psy_notifications INSERT policy uses WITH CHECK (true) — any user can forge notifications to any user
- **Di mana:** psy_notifications RLS policy 'Anyone insert notifications' (line 335)
- **Masalah:** The INSERT policy on psy_notifications is WITH CHECK (true), allowing any authenticated client to insert a notification row with an arbitrary user_id (target). A malicious patient could spam or spoof notifications to staff or other patients. SELECT/UPDATE are correctly scoped to user_id = auth.uid(), but the open INSERT undermines trust in the notification channel.
- **Bukti:** `database/master_migration.sql:335  CREATE POLICY "Anyone insert notifications" ON psy_notifications FOR INSERT WITH CHECK (true);`
- **Cadangan:** Restrict notification inserts to service_role / SECURITY DEFINER functions (notifications are typically system-generated), or at minimum require the inserter to be staff, instead of WITH CHECK (true).

### (security) roles/staff/kepatuhan-fill.html — Staff write to psy_kepatuhan_log will be blocked by RLS (staff has SELECT only)
- **Di mana:** saveLog (upsert into psy_kepatuhan_log line 703)
- **Masalah:** kepatuhan-fill.html lets a staff/coach upsert daily compliance logs on behalf of a patient. But psy_kepatuhan_log RLS grants staff only SELECT ('kepatuhan_log_staff_read'); the only write policy ('kepatuhan_log_patient_all') requires patient_id to map to the CURRENT user's auth.uid() via psy_patients. A staff user is not that patient, so the upsert is rejected by RLS at runtime and the staff fill-in feature silently fails to save. This is a schema/RLS vs. code mismatch introduced by the new staff-fill feature.
- **Bukti:** `roles/staff/kepatuhan-fill.html:703  const { error } = await window.db.from('psy_kepatuhan_log').upsert(payload, { onConflict:'patient_id,log_date' });`
- **Cadangan:** Add a staff write policy on psy_kepatuhan_log (and psy_kepatuhan_weekly) e.g. FOR ALL USING/ WITH CHECK (EXISTS (SELECT 1 FROM psy_profiles WHERE id=auth.uid() AND role='staff')), shipped in migration 20260627_staff_fill_kepatuhan.sql.

### (ux) auth/set-password.html — Page can get stuck forever on 'Mengesahkan pautan...' loading state if a DB/auth call throws
- **Di mana:** init IIFE (async () => { ... })()
- **Masalah:** The init IIFE awaits window.db.auth.getSession() / setSession() with no try/catch. On a network failure or any thrown exception, the promise rejects, none of show('state-invalid')/show('state-form') run, and the UI remains on the initial #state-loading panel ('Mengesahkan pautan...') indefinitely with no way for the user to recover or retry. An invited user simply sees a permanent spinner.
- **Bukti:** `(async () => {
  ...
  const { data: { session } } = await window.db.auth.getSession();
  ...
  const { data, error } = await window.db.auth.setSession({ access_token: accessToken, refresh_token: refreshToken || '' });
  ...
})();`
- **Cadangan:** Wrap the IIFE body in try/catch and call show('state-invalid') (or surface a retry/contact-admin message) in the catch so a failed network/auth call does not leave the page stuck on the loading panel.

### (ux) auth/set-password.html — User stuck on success screen with no redirect if getSession/profile lookup throws
- **Di mana:** setPassword() -> setTimeout(async () => { ... }, 1500)
- **Masalah:** After the password is saved, the redirect runs inside an async setTimeout callback with no try/catch. The success panel says 'Anda akan diarahkan ke dashboard...'. If window.db.auth.getSession() or the psy_profiles query rejects (network/RLS error), the callback throws, the fallback window.location.href='login.html' line is never reached, and the user is permanently parked on the success screen with no navigation and no feedback.
- **Bukti:** `setTimeout(async () => {
    const { data: { session } } = await window.db.auth.getSession();
    if (session) {
      const { data: profile } = await window.db
        .from('psy_profiles').select('role').eq('id', session.user.id).single()`
- **Cadangan:** Wrap the timeout callback body in try/catch and fall back to window.location.href='login.html' in the catch, so a failed session/profile lookup still navigates the user somewhere instead of stranding them on the success screen.

### (ux) roles/patient/event-detail.html — Cancel registration is destructive with no confirmation
- **Di mana:** actionHtml() / toggleReg()
- **Masalah:** The 'Batal pendaftaran' button calls toggleReg() directly, which immediately sets the registration status to 'batal' in the DB with no confirm() prompt. An accidental tap cancels a patient's event registration instantly.
- **Bukti:** `<button onclick="toggleReg()" class="w-full text-sm font-bold text-terracotta hover:text-terracotta/70 mt-2">Batal pendaftaran</button>`
- **Cadangan:** Guard the cancel path with a confirm dialog, e.g. inside toggleReg() when registered: `if (registered && !confirm('Batalkan pendaftaran acara ini?')) return;`

### (ux) roles/patient/issue.html — Photo upload failure is silent; report submits without the photo with no warning
- **Di mana:** submitIssue() photo upload block
- **Masalah:** When storage.upload returns an error (or throws), photoUrl stays null and execution continues to submit the report without the photo. The user attached a photo as evidence but gets no indication it was dropped — they will believe the photo was included. The only trace is a console.warn the patient never sees.
- **Bukti:** `const { error } = await window.db.storage.from('issue-photos').upload(path, issuePhotoFile);
      if (!error) {
        const { data } = window.db.storage.from('issue-photos').getPublicUrl(path);
        photoUrl = data.publicUrl;
      }`
- **Cadangan:** On upload error, surface a warning to the user (e.g. banner) and/or block submission so they can retry, instead of silently submitting without the evidence photo.

### (ux) roles/patient/library.html — Filter panel's 'Guna Filter' (Apply) button actually resets all filters
- **Di mana:** resetFilters() bound to 'Guna Filter' button
- **Masalah:** The filter panel's only action button reads 'Guna Filter' (Apply Filter) but its onclick calls resetFilters(), which clears search, sort, status (f-saved) and category before closing. A user who picks 'Disimpan Sahaja' and clicks the confirm button has the selection wiped instead of applied, the opposite of expected behaviour.
- **Bukti:** `<button onclick="resetFilters()" ...>Guna Filter</button>  ...  function resetFilters(){document.getElementById('f-search').value='';document.getElementById('f-sort').value='new';document.getElementById('f-saved').value='';state.cat='';rend`
- **Cadangan:** Bind this button to an apply+close handler (selects already auto-apply on change so it only needs to close the panel) and add a separate 'Reset'/'Tetap Semula' button for resetFilters().

### (ux) roles/patient/orders.html — Irreversible 'parcel received' status change with no confirmation
- **Di mana:** confirmDelivered / orderRow confirm button
- **Masalah:** Clicking 'Saya Dah Terima Parsel' immediately updates the order status to 'delivered' with no confirm() dialog. The button only renders while status==='shipped' and disappears once delivered, so the patient cannot undo a mis-tap from this page. A single accidental tap permanently closes the order and ends any in-transit follow-up.
- **Bukti:** ``<button onclick="event.stopPropagation();confirmDelivered('${o.id}')" ...>✅ Saya Dah Terima Parsel</button>` and confirmDelivered: `.update({ status: 'delivered', delivered_at: new Date().toISOString() }).eq('id', orderId);` with no confir`
- **Cadangan:** Add a confirm guard at the top of confirmDelivered(), e.g. `if (!confirm('Sahkan anda sudah menerima parsel ini?')) return;`.

### (ux) roles/patient/profile.html — Profile save has no error handling — failures are silent
- **Di mana:** saveProfile()
- **Masalah:** saveProfile() calls dbUpdate('psy_profiles', ...) and window.db.from('psy_patients').update(...) with no try/catch. dbUpdate throws on error (config/supabase.js: 'if (error) throw error'). If the update fails (RLS, network, validation), the exception propagates as an unhandled promise rejection: the user gets NO error feedback. The success banner 'Profil dikemaskini' is never shown, but the user is left with no indication the save failed (and the height write to psy_patients can fail independently after psy_profiles already succeeded, leaving a partial save with no notice).
- **Bukti:** `await dbUpdate('psy_profiles', currentUser.id, { full_name: name, phone });
  const heightVal = parseFloat(document.getElementById('prof-height-in').value) || null;
  if (patientRecord?.id) {
    await window.db.from('psy_patients').update(`
- **Cadangan:** Wrap the DB calls in try/catch and call banner('Ralat menyimpan: ' + e.message, 'error') on failure (matching the pattern already used in uploadPatientDocs and changePassword).

### (ux) roles/patient/shop.html — Delivery fee row uses both `hidden` and `flex` classes, so `flex` overrides `hidden` and the row never hides
- **Di mana:** #delivery-fee-row static markup
- **Masalah:** The element has class="hidden flex justify-between". In Tailwind's generated CSS, the `.flex { display:flex }` rule is emitted after `.hidden { display:none }`, so display:flex wins and the row is always visible. toggleDelivery() then toggles the `hidden` class, but because `flex` is still present the row never actually hides — so the 'Penghantaran RM 8.00' line shows even when delivery method is Pickup (no fee), confusing the user. The same pattern is safe for delivery-fee logic only if `hidden` truly hid it.
- **Bukti:** `<div id="delivery-fee-row" class="hidden flex justify-between"><span class="text-ink/60">Penghantaran</span><span class="font-medium">RM 8.00</span></div>`
- **Cadangan:** Remove the static `flex` class and apply it conditionally, e.g. keep only `hidden justify-between` and in toggleDelivery() do row.classList.toggle('flex', isPos) alongside toggling 'hidden', or restructure so the hidden state isn't overridden by flex.

### (ux) roles/patient/vitals.html — DB load error is swallowed, leaving table silently empty
- **Di mana:** loadVitals()
- **Masalah:** loadVitals destructures only { data } from the query and never checks error. If the psy_vitals select fails (network, RLS, schema), data is null, allVitals becomes [], and renderTable() shows 'Tiada bacaan direkod lagi.' The patient sees an empty history that looks like 'no readings' rather than an error, even when they actually have readings. No feedback distinguishes failure from genuinely empty.
- **Bukti:** `const { data } = await window.db.from('psy_vitals')
  .select('*').eq('patient_id', patientId)
  .order('reading_date', { ascending: false, nullsFirst: false })
  .order('created_at', { ascending: false });
allVitals = data || [];`
- **Cadangan:** Destructure { data, error } and, on error, render a distinct error state in the table (e.g. 'Gagal memuatkan bacaan, sila cuba lagi') and/or call banner with the error instead of falling through to the empty state.

### (ux) roles/staff/acara-detail.html — Re-render after add wipes file/url inputs but success leaves button in success-text state only via re-render; on success the inputs are not explicitly cleared before render
- **Di mana:** addMaterial
- **Masalah:** On successful add, the code calls render() which rebuilds the whole panel from scratch, so the form is reset. However the file input element (#mat-file) is the same DOM that gets replaced; this is fine. The real concrete gap: if insert succeeds but the subsequent re-fetch select() returns an error, `data` is undefined and MATERIALS is silently set to [] (data || []), discarding the just-added material from the UI even though it was inserted. The user sees the new material disappear with no error.
- **Bukti:** `const { data } = await window.db.from('psy_event_materials').select('*').eq('event_id', EV.id).order('created_at', { ascending: true });
    MATERIALS = data || []; banner('Bahan ditambah ✓'); render();`
- **Cadangan:** Destructure { data, error: selErr } and on error keep prior MATERIALS or push the inserted row instead of overwriting with [].

### (ux) roles/staff/appointments.html — No error handling around loadSessions; a failed query leaves the page silently broken
- **Di mana:** loadSessions / IIFE bootstrap
- **Masalah:** loadSessions() uses Promise.all with dbQuery, which THROWS on any Supabase error. It is called from the bootstrap IIFE (and after every action) with no try/catch and no await. If the initial psy_plan_weekly_progress / psy_treatment_plans query fails (RLS, network), the promise rejects unhandled, renderCalendar/renderList never run, and the user is left with an empty calendar/list and no error banner — no indication anything failed.
- **Bukti:** `document.getElementById('f-status').addEventListener('change', renderList);
  loadSessions();
})();`
- **Cadangan:** Wrap loadSessions body (or the call) in try/catch and show banner('Ralat memuat sesi: '+err.message,'error') on failure so the UI does not silently render empty.

### (ux) roles/staff/auto-mesej.html — Broadcast targeted to 'Pakej tertentu' can be saved with zero packages selected, silently targeting nobody
- **Di mana:** saveMsg() recurring_broadcast branch + getAudiencePkgs()
- **Masalah:** When the audience radio 'pkg' (Pakej tertentu) is chosen but the user ticks no package checkboxes, getAudiencePkgs() returns []. saveMsg validates days, session time, minutes_before and channels, but never validates that at least one package is selected. payload.package_ids becomes [], so the broadcast is saved as 'package-targeted' with an empty target list. There is no warning, so the staff believes the recurring broadcast is configured while it will effectively reach no patients.
- **Bukti:** `function getAudiencePkgs(){ const pkg = document.querySelector('input[name=aud][value=pkg]').checked; return pkg ? Array.from(document.querySelectorAll('.pkg-cb:checked')).map(c=>c.value) : []; }
...
payload.package_ids = getAudiencePkgs();`
- **Cadangan:** In the recurring_broadcast branch of saveMsg, after computing the audience, if the 'pkg' radio is checked and getAudiencePkgs().length === 0, show an error ('Pilih sekurang-kurangnya satu pakej') and return instead of saving.

### (ux) roles/staff/coaching-catalog.html — Failed catalog load silently shows empty state with no error feedback
- **Di mana:** load()
- **Masalah:** load() destructures only `data` and ignores `error`. If the query fails (network/RLS), `data` is null, `allItems` becomes [], and render() shows 'Tiada item dalam kategori ini.' The user cannot distinguish a real empty catalog from a load failure, and there is no retry/error message.
- **Bukti:** `const { data } = await window.db.from('psy_coaching_catalog')
    .select('*').order('type').order('sort_order').order('name');
  allItems = data || [];`
- **Cadangan:** Destructure `{ data, error }`; on error render an error/retry state instead of the empty-state message.

### (ux) roles/staff/consultation.html — No error handling around dbQuery Promise.all leaves chart panels blank
- **Di mana:** loadPatientChart()
- **Masalah:** dbQuery() (config/supabase.js) THROWS on Supabase error (it does `if (error) throw error`). In loadPatientChart the soap-form is already un-hidden (line 140) BEFORE the Promise.all of dbQuery calls runs. If either psy_vitals or psy_soap_notes query errors (RLS, network), the function throws unhandled, so #chart-info, #latest-vitals and #past-notes are never filled and the doctor sees a half-rendered form with empty panels and no error feedback.
- **Bukti:** `document.getElementById('soap-form').classList.remove('hidden');
...
const [vitals, notes] = await Promise.all([
  dbQuery('psy_vitals', { eq: { patient_id: patientId }, order: { col: 'created_at' }, limit: 1 }),
  dbQuery('psy_soap_notes',`
- **Cadangan:** Wrap the Promise.all (and chart rendering) in try/catch and call banner('Ralat memuat carta: '+err.message,'error') on failure, or render placeholder text in the panels.

### (ux) roles/staff/events.html — Registrations modal, edit and delete are unreachable from the events list UI
- **Di mana:** renderEvents() event card vs openRegs/openEventModal/deleteEvent
- **Masalah:** The event card markup rendered by renderEvents() contains only a single 'Lihat Detail' link to acara-detail.html. No button on the card calls openRegs(), openEventModal() or deleteEvent(). Those functions are fully implemented (Pendaftar/registrations modal, edit modal, attendance marking, delete) and their supporting modals exist in the DOM, but the only way to trigger them is via manual ?edit= / ?regs= URL params (handled in the IIFE at the bottom). From the grid a staff user cannot open registrations/attendance, edit, or delete an event — so the entire registrations + attendance feature on this page is effectively dead UI.
- **Bukti:** `<a href="acara-detail.html?id=${ev.id}" class="mt-3 text-center text-[12px] font-bold text-navy hover:underline">Lihat Detail ›</a>`
- **Cadangan:** Add buttons to each card (e.g. 'Pendaftar', 'Edit', 'Padam') wired to openRegs(ev.id), openEventModal(ev.id), deleteEvent(ev.id); or, if registrations are managed solely on acara-detail.html, remove the now-unused functions and modals.

### (ux) roles/staff/kepatuhan-fill.html — 'Lain-lain' free-text input loses focus on every keystroke
- **Di mana:** sfOtherInput() / sf-item-other input in sfRenderAmalan()
- **Masalah:** The amalan 'other' text input's oninput handler calls sfOtherInput(), which calls sfRenderAmalan(). That re-renders the whole list innerHTML, destroying and recreating the input element, so the field loses focus after each character and the caret resets. The staff can effectively only type one character at a time.
- **Bukti:** `oninput="sfOtherInput(this,'${escAttr(it.item_key)}','${it.jenis_input||''}')"  ...  function sfOtherInput(el, key, type) { answersText[key] = el.value; if(type!=='pilih_banyak' && el.value.trim()) answers[key]='other'; sfRenderAmalan(); }`
- **Cadangan:** Do not re-render the whole list on text input; update state only (as sfReaksiOther does), or re-render selection state without rebuilding the textarea/input, or restore focus after render.

### (ux) roles/staff/kob-slots.html — Status Default radio not reset when opening Edit modal (shows stale value)
- **Di mana:** openEditSlot()
- **Masalah:** openEditSlot configures type, label, start/end, days, and note, but never sets the 'slot-default-status' radio to reflect the slot's current is_active state. So the ON/OFF radio shows whatever was last left in the modal (e.g. 'on' from a previous Add). On submit during edit, that radio's value (isActive) is only applied to NEWLY inserted day rows (line 770 insert sets is_active: isActive) and not to updates, so adding a new day to an existing slot can mark it ON/OFF based on a stale, misleading radio the user never intentionally set.
- **Bukti:** `function openEditSlot(type, sortOrder) {
  ...
  document.getElementById('slot-note').value = sample.note || '';
  const activeDays = new Set(rows.map(r => r.day_of_week));
  document.querySelectorAll('.slot-day').forEach(el => el.checked =`
- **Cadangan:** In openEditSlot, set the status radio from the loaded slot, e.g. document.querySelector(`input[name="slot-default-status"][value="${sample.is_active ? 'on' : 'off'}"]`).checked = true; and apply is_active on the update branch too for consistency.

### (ux) roles/staff/kyc-review.html — Transient/RLS load failure silently boots reviewer to list with no message
- **Di mana:** loadKYC()
- **Masalah:** The select destructures only `data` and ignores `error`. If the query fails (network blip, RLS denial, bad id), `data` is undefined, so `kyc` is undefined and the page immediately redirects to kyc-list.html. The reviewer gets no indication that an error occurred vs. the record genuinely not existing, and a momentary failure throws them off a valid page.
- **Bukti:** `const { data } = await window.db.from('psy_kyc_submissions')
    .select('*, psy_profiles!psy_kyc_submissions_reviewed_by_fkey(full_name)')
    .eq('id', kycId).limit(1);

  kyc = data?.[0];
  if (!kyc) { location.href = 'kyc-list.html'; re`
- **Cadangan:** Capture `error` and, when set, show an inline error/retry state instead of redirecting; only redirect when the query succeeds but returns zero rows.

### (ux) roles/staff/library-detail.html — Activate/deactivate toggle has no error handling or failure feedback
- **Di mana:** toggleStatus()
- **Masalah:** dbUpdate() throws on any DB/RLS/network error (it does `if (error) throw error`). toggleStatus() awaits it with no try/catch and no user feedback on failure. If the update fails, the line that flips currentItem.is_active never runs, renderView is never reached, and the user gets an unhandled promise rejection with no banner — the button silently appears to do nothing. By contrast saveItem() wraps the same dbUpdate call in try/catch and shows an error. The status toggle is a state-changing action and should surface failures.
- **Bukti:** `async function toggleStatus() {
  if (!currentItem) return;
  await dbUpdate('psy_library_items', currentItem.id, { is_active: !currentItem.is_active });
  currentItem.is_active = !currentItem.is_active;
  renderView(currentItem);
  banner(`
- **Cadangan:** Wrap the dbUpdate call in try/catch and call banner('Gagal kemaskini status','error') on failure (and optionally disable/restore the button), mirroring saveItem()'s error handling.

### (ux) roles/staff/library-edit.html — Scheduled publish date is restored into a hidden field on edit
- **Di mana:** init IIFE edit-mode restore (line ~850)
- **Masalah:** When editing an item that has a created_at, the code populates #f-date but never selects the 'later' schedule radio nor calls onSchedChange(). The Jadual Terbit stays on 'Terbit Sekarang' and the #sched-fields wrapper stays hidden, so the staff cannot see or change the scheduled date that was actually set. The summary table (rs-terbit) also shows '📅 Sekarang' even though the item is scheduled, which is misleading.
- **Bukti:** `if(item.created_at){const d=new Date(item.created_at);const p=n=>String(n).padStart(2,'0');document.getElementById('f-date').value=`${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;}`
- **Cadangan:** After setting #f-date in edit mode, detect whether created_at is in the future (scheduled) and if so set the 'later' radio checked, call onSchedChange() to reveal #sched-fields, then run updateSummary() so the preview reflects the scheduled date.

### (ux) roles/staff/orders.html — Pickup confirm button mislabeled 'Sedia Pickup' but actually marks order as delivered/received
- **Di mana:** buildActions() — pickup 'packed' branch (line 425-427)
- **Masalah:** For a pickup order in status 'packed', the card already shows the info text 'Sedia untuk diambil di konsultasi' (i.e. it is ALREADY ready for pickup). The adjacent action button is labeled '✅ Sedia Pickup' but its onclick calls markStatus(id,'delivered'), which sets the order to the terminal 'delivered' (received) state and sends the patient a 'Pesanan selesai ✅ ... Terima kasih!' notification. A staff member reading the button will think they are marking the parcel 'ready for pickup' (the state it is already in) and will instead prematurely close out the order as collected, notifying the patient it is complete before they have actually picked it up. The label does not match the action.
- **Bukti:** `if (o.status === 'packed') return isPickup ? `
    <div class="text-xs text-green-dark bg-green-light rounded-lg px-3 py-2 flex-1">📍 Sedia untuk diambil di konsultasi</div>
    <button onclick="markStatus('${id}','delivered')" class="bg-gre`
- **Cadangan:** Relabel the button to reflect what it does, e.g. '✅ Sahkan Diambil' / 'Tandakan Telah Diambil' (confirm collected), so staff know it marks the order as received/closed rather than just 'ready for pickup'.

### (ux) roles/staff/pakej-laporan.html — No error handling on DB failures leaves the page silently blank
- **Di mana:** init() - const pkgs = pkgRes.data || []; (and ptRes/logRes)
- **Masalah:** All three Promise.all results are coerced with `|| []` and errors are never inspected. If any query fails (RLS denial, the bad 'status' column above, network), the page just shows '0' KPIs and the 'Tiada pakej ditemui' empty state with no indication that loading failed, so staff cannot distinguish 'no data' from 'broken query'.
- **Bukti:** `const pkgs = pkgRes.data || [];
  const pts  = ptRes.data  || [];
  const logs = logRes.data || [];`
- **Cadangan:** Check pkgRes.error/ptRes.error/logRes.error and surface a visible error state (e.g. banner/notify) when a query fails, instead of falling through to the empty state.

### (ux) roles/staff/service-detail.html — toggleStatus has no error handling — silent failure on DB error
- **Di mana:** toggleStatus()
- **Masalah:** dbUpdate() throws on Supabase/RLS/network error (see config/supabase.js: 'if (error) throw error'). toggleStatus() does not wrap the call in try/catch. If the update fails, the promise rejects unhandled: the local state flip, renderView, and success banner never run, and the user gets NO feedback that activating/deactivating the service failed. The UI silently does nothing. Compare with saveService() which correctly wraps dbUpdate in try/catch with an error banner.
- **Bukti:** `async function toggleStatus() {
  if (!currentSvc) return;
  await dbUpdate('psy_services', currentSvc.id, { is_active: !currentSvc.is_active });
  currentSvc.is_active = !currentSvc.is_active;
  renderView(currentSvc);
  banner(currentSvc.`
- **Cadangan:** Wrap the dbUpdate call in try/catch and show banner('Ralat: ' + err.message, 'error') on failure, mirroring saveService().

### (ux) roles/staff/services.html — No error handling — DB failure leaves the table permanently blank with no feedback
- **Di mana:** loadServices()
- **Masalah:** dbQuery throws on any Supabase error (it does `if (error) throw error`). loadServices has no try/catch, and it is called from the IIFE and from save/toggle/delete handlers without a catch. On a query error the rejection is unhandled, services-body innerHTML is never set, and the user sees an empty table body with no banner/error, unable to tell load failed vs. genuinely empty.
- **Bukti:** `async function loadServices() {
  const data = await dbQuery('psy_services', { order: { col: 'sort_order', asc: true } });
  document.getElementById('services-body').innerHTML = data.length`
- **Cadangan:** Wrap the dbQuery in try/catch and render an error row (and call banner('Ralat memuat services','error')) on failure so the user gets feedback instead of a silent blank table.

### (ux) roles/staff/staff-stats.html — Patient Analytics tab stays permanently blank on DB error
- **Di mana:** loadPatientAnalytics() + switchTab()
- **Masalah:** switchTab sets patientLoaded=true BEFORE calling loadPatientAnalytics(), and loadPatientAnalytics() on a query error only does console.error + return without rendering any message. The KPI row and all charts (#pat-kpi-row, #age-chart, #gender-bars, #condition-list, #reg-chart) start empty, so a failed first load leaves the entire tab blank with no feedback, and because patientLoaded is already true, re-clicking the tab never retries the load.
- **Bukti:** `if (tab === 'patient' && !patientLoaded) { patientLoaded = true; loadPatientAnalytics(); }  ...  if (error) { console.error('Patient analytics error:', error.message); return; }`
- **Cadangan:** Only set patientLoaded=true after a successful load (or reset it on error), and on error render a visible message into #pat-kpi-row (e.g. 'Gagal memuatkan analitik pesakit') so the user knows the tab failed rather than seeing a blank screen.

### (ux) roles/staff/staff_management.html — loadStaff has no try/catch — a DB error leaves the table permanently blank with no message
- **Di mana:** loadStaff()
- **Masalah:** dbQuery() throws on any Supabase error (it does `if (error) throw error;`). loadStaff() awaits dbQuery with no try/catch and is invoked from the IIFE without await/catch. If the query fails (RLS, network, table issue), the promise rejects, _staffData is never set, renderStats()/renderTable() never run, and #staff-body / the stat cards stay at their initial empty/zero state. The user sees a blank table and '0' stats with no error feedback or retry — they cannot tell the load failed vs. genuinely no staff.
- **Bukti:** `async function loadStaff() {
  _staffData = await dbQuery('psy_profiles', { eq: { role: 'staff' }, order: { col: 'created_at' } });
  renderStats();
  renderTable();
}`
- **Cadangan:** Wrap the dbQuery in try/catch; on failure render an error state in #staff-body (e.g. a row with colspan=7 and a 'Gagal memuatkan staf — cuba lagi' message) and surface the error, instead of leaving the UI silently blank.


## LOW

### (link) roles/patient/kepatuhan-flow-preview.html — Close (×) button has no handler and does nothing
- **Di mana:** <button class="kf-close"> (line 89)
- **Masalah:** The header close button has no onclick and is not matched by any delegated handler (the click delegation on #kep-flow only handles .kf-back, .kf-finish, and the data-kf* chips/options). Clicking × does nothing, leaving no way to exit the flow.
- **Bukti:** `<button class="kf-close">&times;</button>`
- **Cadangan:** Add a delegated case e.g. if(e.target.closest('.kf-close')){ /* close/return to dashboard */ return; } or an onclick handler.

### (link) roles/staff/dashboard.html — Coach trend sparkline targets an element id that does not exist
- **Di mana:** renderCoachDashboard → drawTrendSvg('c-trend-svg', ...)
- **Masalah:** The end of renderCoachDashboard computes 7-day adherence points and calls drawTrendSvg('c-trend-svg', points, dayLabels). drawTrendSvg does document.getElementById('c-trend-svg') and returns early if not found. There is no element with id 'c-trend-svg' anywhere in the coach view markup (only c-kpi-grid, c-adherence-banner, c-reschedule-banner, c-adherence-tbody, c-weekly-list, c-needaction, c-kepatuhan-summary, c-data-updated exist). The trend chart is silently never rendered — wasted computation and a missing UI element the dev intended to show.
- **Bukti:** `drawTrendSvg('c-trend-svg', points, dayLabels);  // function: const svg = document.getElementById(id); if (!svg) return;`
- **Cadangan:** Either add an <svg id="c-trend-svg"> element to the coach view where the sparkline should appear, or remove the dead points/drawTrendSvg computation.

### (link) roles/staff/plans.html — openTracker references DOM ids (tracker-section, tracker-plan-name, tracker-patient, tracker-weeks) that do not exist in this page
- **Di mana:** openTracker()
- **Masalah:** openTracker (and markWeek which calls it) read/write #tracker-section, #tracker-plan-name, #tracker-patient and #tracker-weeks via getElementById without null guards. None of these ids exist anywhere in plans.html (the page renders plan rows that navigate to plan-week.html instead). If any of these functions were ever wired to a control they would throw 'Cannot read properties of null'. Currently they are orphaned (no caller in the HTML or in onclick strings), so this is dead/broken code rather than a live crash, but it is a latent broken reference.
- **Bukti:** `document.getElementById('tracker-section').classList.remove('hidden');
  document.getElementById('tracker-plan-name').textContent = plan.name;
  ...
  document.getElementById('tracker-weeks').innerHTML = html;`
- **Cadangan:** Remove the dead openTracker/markWeek/openCompliance/updateScore/updateNotes functions, or add the corresponding tracker-section markup and wire them, and guard getElementById results before use.

### (logic) roles/patient/dashboard.html — 'Sesi Minggu Ini' counter can show sessions that are weeks away
- **Di mana:** IIFE — Sesi Akan Datang / stat-sess-count
- **Masalah:** The hero stat is labelled 'Sesi Minggu Ini' (sessions THIS WEEK), but when there are no sessions today the fallback shows upcomingRows.length. upcomingRows is built from psy_plan_weekly_progress filtered only by session_date >= today (limit 5) with no upper bound on the week, so the displayed number can include sessions that are weeks in the future, not the current week. The count therefore does not match its label.
- **Bukti:** `const todaySessions = upcomingRows.filter(r => r.session_date === today);
    document.getElementById('stat-sess-count').textContent = todaySessions.length || upcomingRows.length;`
- **Cadangan:** Either relabel the stat to 'Sesi Akan Datang' / 'Sesi Terdekat', or compute the count from sessions whose session_date falls within the current calendar week (today .. end-of-week) instead of falling back to all upcoming rows.

### (logic) roles/patient/events.html — toggleReg() is defined but never invoked in this file (dead code)
- **Di mana:** toggleReg(eventId)
- **Masalah:** The async function toggleReg(eventId) handles registration/cancellation, fires banner('Berjaya daftar') and notify(...), but nothing in events.html ever calls it. The event cards in eventCard() render plain anchor links (<a href="event-detail.html?id=...">) and the only click handler on the page (document.addEventListener('click', ...)) handles .ev-tab filter buttons exclusively. Actual registration is performed by a separate toggleReg() in event-detail.html. As written, this entire function (and its banner/notify side effects) is unreachable, so it is dead code that can mislead maintainers into thinking events.html performs in-place registration. No user-facing breakage, but it should be removed or wired up.
- **Bukti:** `async function toggleReg(eventId) {
  if (!window.patientRecord?.id) { (window.banner || alert)('Rekod pesakit tidak ditemui'); return; } ... }

// only click handler present:
document.addEventListener('click', (e) => { const tab = e.target`
- **Cadangan:** Remove the unused toggleReg() from events.html (registration is handled in event-detail.html), or if in-page registration is intended, add a clickable control and dispatch toggleReg(eventId) from the click delegate.

### (logic) roles/patient/feedback.html — Weekly eligibility filter includes non-existent status 'completed'
- **Di mana:** showWeeklyMode()
- **Masalah:** psy_plan_weekly_progress.status CHECK constraint only allows 'pending','booked','hadir','reschedule','cancel','consultation_done','extension_pending_payment','extension_paid' (database/master_migration.sql line 4753). There is no 'completed' value, so the 'completed' branch of the filter is dead. Not user-breaking (rows with status 'hadir' still match), but if the intent was to also surface finished consultation sessions, those rows now have status 'consultation_done' and are silently excluded from feedback.
- **Bukti:** `const eligible = weeklyRows.filter(r => ['hadir','completed'].includes(r.status));`
- **Cadangan:** Replace 'completed' with the real statuses, e.g. ['hadir','consultation_done'].

### (logic) roles/patient/kepatuhan.html — Symptom emoji/icon lookup keys do not match the actual symptom strings, so most reaksi symptoms fall back to the default heart
- **Di mana:** REAKSI_CARD / REAKSI_CATS key mismatch (case)
- **Masalah:** REAKSI_CATS lists symptoms in Title Case ('Banyak Angin','Najis Hitam','Tekanan Darah Tinggi','Sakit Badan','Mukus Keluar','Badan Panas','Kurang Tenaga','Sesak Nafas', etc.), but REAKSI_CARD and CUSTOM_ICONS are keyed in lowercase/different casing ('Banyak angin','Najis hitam','Tekanan darah tinggi','Sakit badan','Mukus keluar','Badan panas','Kurang tenaga','Sesak nafas'). reaksi_sym does `REAKSI_CARD[it]` where `it` comes from REAKSI_CATS, so the lookup misses and almost every symptom renders the generic fallback {bg:'#ede9fe', emoji:'💜'} instead of its intended colour/icon. Also REAKSI_CARD defines 'Banyak membuang air besar' and 'Tiada simptom' which never appear in any REAKSI_CATS list, while the real list value 'Banyak Angin' has no card.
- **Bukti:** `'Pencernaan': ['Kembung','Banyak Angin','Sembelit','Cirit-birit','Najis Hitam'] ... const ec = REAKSI_CARD[it] || { bg:'#ede9fe', emoji:'💜' }; const icon = CUSTOM_ICONS[it] || ec.emoji;`
- **Cadangan:** Make REAKSI_CARD/CUSTOM_ICONS keys exactly match the strings in REAKSI_CATS (consistent casing), or normalise the key (e.g. lowercase both sides) before lookup.

### (logic) roles/patient/kepatuhan.html — Mood sub-feeling cards never match EMO_CARD, but the file does not actually consume EMO_CARD in mood_detail render
- **Di mana:** EMO_CARD vs MOOD_FLOW.detail values (case mismatch)
- **Masalah:** EMO_CARD is keyed in mixed case ('Biasa sahaja','Kosong jiwa','Hilang arah tujuan hidup','Letih emosi') while MOOD_FLOW.detail uses Title Case ('Kosong Jiwa','Hilang Arah Tujuan Hidup','Letih Emosi'). mood_detail render uses KF_PAL palette colours, not EMO_CARD, so this is dead/inconsistent data rather than a visible break — flagged as low because the constant suggests intended styling that is not wired up.
- **Bukti:** `detail:['Letih Emosi','Hilang Motivasi','Hilang Fokus','Tiada Tenaga','Tidak Yakin Diri'] ... 'Letih emosi': { bg:'#D9F99D', emoji:'😮‍💨' }`
- **Cadangan:** Remove the unused EMO_CARD/EMO_TIPS/REAKSI_TIPS maps if no longer consumed, or align their keys and actually use them in the render to avoid future regressions.

### (logic) roles/patient/pulangan.html — Bottle-return chat messages fetched across ALL returns, not scoped to this patient
- **Di mana:** loadHistory()
- **Masalah:** loadHistory queries psy_audit_log for every row with action 'bottle_return.message' with no patient/return filter in the query, then filters client-side via returnIds.includes(m.meta?.return_id). Functionally the client-side filter keeps it correct, but it pulls the entire bottle_return.message history for all patients each load (grows unbounded; relies entirely on RLS to avoid leaking other patients' messages). It should constrain the query, e.g. by target/return_id, rather than fetching all rows and filtering in JS.
- **Bukti:** `const { data } = await window.db.from('psy_audit_log')
      .select('*').eq('action', 'bottle_return.message')
      .order('created_at', { ascending: true });
    allMsgs = (data || []).filter(m => returnIds.includes(m.meta?.return_id));`
- **Cadangan:** Scope the query to this patient's returns, e.g. .in('target', returnIds) (sendMessage stores returnId in `target`), so only relevant rows are fetched.

### (logic) roles/patient/rekod-perubatan.html — Search filter references non-existent column r.source
- **Di mana:** getFiltered()
- **Masalah:** getFiltered builds the searchable string from `${r.title} ${r.file_name} ${r.source}`, but psy_medical_reports has no `source` column (the related field is referral_source on psy_patients, not on reports). r.source is always undefined, so this token is always empty. Search silently never matches on that intended field; not a crash but the search is narrower than the code implies.
- **Bukti:** `if(q && !(`${r.title||''} ${r.file_name||''} ${r.source||''}`.toLowerCase().includes(q))) return false;`
- **Cadangan:** Drop r.source, or replace with an actual column such as r.notes / r.doctor_name that exists on psy_medical_reports.

### (logic) roles/patient/rekod-perubatan.html — Last-updated uses lexicographic sort on raw timestamps which can pick the wrong record
- **Di mana:** renderStats() — last-updated computation
- **Masalah:** renderStats computes the most recent upload via RECS.map(r=>r.uploaded_at).filter(Boolean).sort().slice(-1)[0]. A plain Array.sort() compares strings lexicographically; this only works if all uploaded_at values share an identical ISO format/timezone offset. The records are already fetched ordered by uploaded_at DESC, so the latest is simply RECS[0].uploaded_at — relying on a string sort is fragile and can surface a wrong 'Terakhir Dikemaskini' if formats differ.
- **Bukti:** `const last=RECS.map(r=>r.uploaded_at).filter(Boolean).sort().slice(-1)[0];`
- **Cadangan:** Use the already-DESC-ordered data: const last = (RECS.find(r=>r.uploaded_at)||{}).uploaded_at; or sort by new Date(x)-new Date(y).

### (logic) roles/patient/rekod-tambah.html — Unguarded patientRecord.id can throw when patient has no linked record
- **Di mana:** saveRec() — for(const f of FILES) loop
- **Masalah:** saveRec() reads patientRecord.id (both for the upload folder path and as patient_id) without checking that window.patientRecord exists. In _shared.js initPatient(), if the auto-create of a fresh patient record fails, the error is swallowed (console.warn only) and window.patientRecord is left null, yet initPatient still returns a valid user so the page loads normally. A user in that state who clicks Simpan triggers 'Cannot read properties of null (reading id)'. It is caught by the surrounding try/catch and shown as a generic 'Gagal' banner, so it degrades rather than crashing the page, but the user gets a confusing error with no path to resolve it.
- **Bukti:** `const path=await up(f,`patient/${patientRecord.id}`);
      rows.push({
        patient_id: patientRecord.id,`
- **Cadangan:** Guard at the top of saveRec(): if(!window.patientRecord){ fail('Rekod pesakit anda belum siap. Sila muat semula halaman atau lengkapkan profil.'); } before attempting upload/insert.

### (logic) roles/patient/routine.html — Activity text with backslash/newline can break the inline onchange handler string
- **Di mana:** renderDailyList() — checkbox onchange escaping
- **Masalah:** The checkbox onchange passes the activity into an inline JS string literal via single-quote escaping only (escActivity). An activity containing a newline or a backslash before a quote can still break the generated onchange attribute, throwing a syntax error when toggled. The activity is patient-editable free text, so malformed input is plausible.
- **Bukti:** `const escActivity = (it.activity || '').replace(/'/g, "\\'").replace(/"/g, '&quot;');
...
onchange="toggleDailyDone('${it.time}', '${escActivity}', this.checked)"`
- **Cadangan:** Avoid inline-string injection: bind via a data-attribute / closure, or pass only the index (toggleDailyDone(i, checked)) and look up the activity from dailyCurrent[i].

### (logic) roles/staff/announcement-detail.html — Toggle on completed/cancelled event silently re-publishes it
- **Di mana:** toggleActive() event branch
- **Masalah:** For events the toggle computes nv = IT.status === 'published' ? 'draft' : 'published'. If an event has status 'completed' or 'cancelled', statusKey() returns 'tamat' so the button is labelled 'Nyahaktifkan' (deactivate), but clicking it sets status to 'published' — re-publishing a finished/cancelled event, the opposite of the button's implied intent. statusKey() explicitly handles 'cancelled'/'completed', so these states are reachable.
- **Bukti:** `const nv = IT.status === 'published' ? 'draft' : 'published';
      await window.db.from('psy_events').update({ status: nv }).eq('id', IT.id);`
- **Cadangan:** Only treat 'draft' as the off-state for the activate path, and guard completed/cancelled: e.g. nv = IT.status === 'draft' ? 'published' : 'draft', and skip/disable the toggle when status is 'completed' or 'cancelled'.

### (logic) roles/staff/announcements.html — Staff-entered title/body/category injected into table HTML without escaping
- **Di mana:** renderTable() row template
- **Masalah:** it.title, it.body and it.category come straight from psy_announcements/psy_events rows and are interpolated into innerHTML with no escaping. A title containing HTML (e.g. '<img onerror=...>' or stray quotes/angle brackets) will break the table layout or execute markup. Since the same staff editor saves these fields, a malformed or malicious title renders broken/unsafe in the management table.
- **Bukti:** `<div class="font-bold text-ink text-sm truncate max-w-[260px]">${it.title}</div>
${it.body ? `<div class="text-[11px] text-ink/50 truncate max-w-[260px]">${String(it.body).replace(/<[^>]+>/g,'')}</div>` : ''}`
- **Cadangan:** HTML-escape it.title and it.category (and it.body before the tag-strip) via a small escapeHtml() helper before interpolation.

### (logic) roles/staff/assignment-review.html — Audit log records actor_role as generic 'staff' instead of the staff sub-role
- **Di mana:** doAssign() audit insert actor_role (line 484)
- **Masalah:** window.currentUser.role is the top-level role ('staff'), not the meaningful staff_role ('coach'/'admin'/'manager'). Everywhere else in this file the sub-role is read via staff_role (e.g. myRole = window.currentUser.staff_role, role = window.currentUser?.staff_role). The audit trail will log actor_role:'staff' for every assignment, losing who-did-what granularity.
- **Bukti:** `actor_role: window.currentUser.role, action: 'patient.assigned', target: patientId,`
- **Cadangan:** Use window.currentUser.staff_role for actor_role to match the rest of the file and produce a meaningful audit entry.

### (logic) roles/staff/assignments.html — Initials derivation can emit literal 'undefined' for names containing double spaces
- **Di mana:** renderTable() initials
- **Masalah:** name.split(' ').slice(0,2).map(w => w[0]).join('') will produce undefined for an empty token (e.g. a name with two consecutive spaces), yielding strings like 'Aundefined' in the avatar. The trailing '|| ?' only fires when the joined string is completely empty, not when it contains 'undefined'.
- **Bukti:** `const initials = name.split(' ').slice(0,2).map(w => w[0]).join('').toUpperCase() || '?';`
- **Cadangan:** Filter empty tokens first: name.trim().split(/\s+/).slice(0,2).map(w => w[0] || '').join('').toUpperCase() || '?'

### (logic) roles/staff/coaching.html — statusMap key 'tidak_hadir' is dead and 'pending' status is unhandled
- **Di mana:** sessionCard() — statusMap (lines 83-90)
- **Masalah:** psy_plan_weekly_progress.status CHECK constraint allows only ('booked','hadir','reschedule','cancel','pending'). The statusMap has a 'tidak_hadir' entry that can never match any real row (dead code), while a real 'pending' status has no entry and falls through to statusMap.booked, so a pending session is mislabelled 'Ditempah' (Booked) with the wrong colour. This shows incorrect status to the coach.
- **Bukti:** `tidak_hadir:{ label:'Tidak Hadir', cls:'bg-terracotta-light text-terracotta' },
    reschedule: { label:'Reschedule',  cls:'bg-gold-light text-gold-dark' },`
- **Cadangan:** Replace the unreachable 'tidak_hadir' key with a 'pending' entry (e.g. label 'Pending', neutral colour) to match the allowed status set.

### (logic) roles/staff/consultation.html — Inconsistent timezone handling when matching session_date for the same day
- **Di mana:** loadPatientsForDate() vs saveSoap()
- **Masalah:** loadPatientsForDate filters psy_plan_weekly_progress by naive local-string boundaries (dateStr + 'T00:00:00' / 'T23:59:59', no Z), while saveSoap matches the session for that same day using UTC ISO boundaries via new Date(...).toISOString(). For a non-UTC timezone (Malaysia is UTC+8) these two day-windows differ by up to 8 hours, so a session shown as bookable for the date may not be matched (or a wrong day's session matched) when auto-marking status='consultation_done', causing the 'session ditanda Selesai' update to silently skip the intended row.
- **Bukti:** `// loadPatientsForDate
.gte('session_date', dateStr + 'T00:00:00')
.lte('session_date', dateStr + 'T23:59:59')
// saveSoap
const dayStart = new Date(`${dateStr}T00:00:00`).toISOString();
const dayEnd = new Date(`${dateStr}T23:59:59.999`).to`
- **Cadangan:** Use the same boundary computation in both places (either both naive local strings or both UTC ISO) so the patient-picker filter and the session auto-complete match the identical row set.

### (logic) roles/staff/dashboard.html — Orphaned action handlers never wired and reference non-existent DOM
- **Di mana:** ackAdherence / markHadir / markReschedule
- **Masalah:** ackAdherence(), markHadir(sessionId) and markReschedule(sessionId) are defined but never invoked — the file has zero onclick/onchange/oninput handlers, and none of these are referenced from any rendered HTML string. Additionally markHadir/markReschedule manipulate document.getElementById(`row-${sessionId}`) and querySelector('.flex.gap-2')/('.flex.items-center.gap-2'), but no rendered row carries id='row-...' or those exact action-div class shapes, so even if wired they would no-op on the DOM. This is dead/stale code that will silently do nothing (e.g. ackAdherence would update the DB then location.reload with no visible effect tied to a button).
- **Bukti:** `async function markHadir(sessionId) { ... const row = document.getElementById(`row-${sessionId}`); if (row) { ... const actDiv = row.querySelector('.flex.gap-2'); ... } }`
- **Cadangan:** Remove the unused handlers, or wire them to buttons and emit row markup with matching id='row-<sessionId>' and the expected action-div classes.

### (logic) roles/staff/kepatuhan.html — Per-amalan label uses logs[0].fasa for all keys, mislabels if patient changed fasa mid-week
- **Di mana:** openModal() — pctHtml label lookup
- **Masalah:** scoredKeys are collected per-log using each log's own l.fasa (line 518), but when rendering the per-amalan percentage list the ITEM_INDEX label lookup is keyed only off r.logs[0].fasa. If a patient's logs in that week span more than one fasa, items belonging to a different fasa than logs[0] resolve def=undefined and fall back to showing the raw item_key instead of the human label. Cosmetic but visible mislabel in the detail modal.
- **Bukti:** `const def=ITEM_INDEX[`${r.logs[0]?.fasa}::${k}`];`
- **Cadangan:** Track the fasa alongside each scored key (e.g. push {key,fasa} while iterating r.logs) and use that fasa for the label lookup, mirroring the per-log lookup used elsewhere (ITEM_INDEX[`${l.fasa}::${k}`]).

### (logic) roles/staff/kit-edit.html — Update DB call result not checked for error
- **Di mana:** saveKit() update branch
- **Masalah:** The update call's result is not destructured or awaited for error. await window.db...update(payload).eq('id', id) does not throw on a Supabase error (it resolves with { error }); so a failed update (e.g. RLS) still shows the success banner 'Kit disimpan' and 'Disimpan <time>', misleading the user into thinking the save succeeded.
- **Bukti:** `if (id) {
      await window.db.from('psy_procedure_kits').update(payload).eq('id', id);
    } else {`
- **Cadangan:** Capture and check the error: const { error } = await window.db...update(payload).eq('id', id); if (error) throw error;

### (logic) roles/staff/kob-detail.html — new Date(null) when doctor name set but timestamp missing
- **Di mana:** render() lines 545-546 (doctor-info)
- **Masalah:** doctorInfo is built using kob.doctor_hadir_name with new Date(kob.hadir_at), and doctor_selesai_name with new Date(kob.selesai_at). If a name column is populated but its paired *_at timestamp is null (data inconsistency), new Date(null) yields the Unix epoch (01/01/1970) which is displayed to staff as the action time, which is misleading.
- **Bukti:** `if (kob.doctor_hadir_name) doctorInfo += `Hadir oleh: <strong>${escapeHtml(kob.doctor_hadir_name)}</strong> · ${new Date(kob.hadir_at).toLocaleString('en-GB')}<br>`;`
- **Cadangan:** Only render the timestamp when the *_at value is present, e.g. kob.hadir_at ? new Date(kob.hadir_at).toLocaleString('en-GB') : ''.

### (logic) roles/staff/kyc-review.html — Avatar initials can render 'undefined' when a name word is empty
- **Di mana:** renderAll() — initials computation
- **Masalah:** name.split(' ') on a name with leading/double spaces yields empty-string words; w[0] on '' is undefined, and join('') then includes 'undefined' or blanks. Cosmetic but produces a broken avatar for names with irregular spacing.
- **Bukti:** `const initials = name.split(' ').slice(0,2).map(w => w[0]).join('').toUpperCase();`
- **Cadangan:** Filter empties first: name.split(/\s+/).filter(Boolean).slice(0,2).map(w => w[0]).join('').toUpperCase().

### (logic) roles/staff/library-categories.html — DB error in loadCats silently yields an empty 'Tiada kategori' list
- **Di mana:** loadCats()
- **Masalah:** loadCats destructures only { data } and never checks error. If the select fails (RLS, network, missing column), data is null, CATS becomes [], and the UI shows 'Tiada kategori' with no error feedback — a super admin would believe all categories were deleted rather than a load failure.
- **Bukti:** `const { data }=await window.db.from('psy_library_categories').select('*').eq('scope',SCOPE).order('sort_order',{ascending:true});
  CATS=data||[];`
- **Cadangan:** Destructure { data, error } and show banner('Gagal memuatkan kategori','error') (and avoid clearing the list) when error is present.

### (logic) roles/staff/library-edit.html — delItem() is defined but never wired to any UI control
- **Di mana:** delItem()
- **Masalah:** The delete handler delItem() (with confirm + dbDelete + auditLog + banner) exists in the inline script, but no button, link, or onclick anywhere in the page invokes it (grep finds only its definition). Staff therefore have no way to delete an item from this editor; the function is dead code, suggesting a missing 'Padam' button on the edit screen.
- **Bukti:** `async function delItem(){
  const editId=document.getElementById('edit-id').value;if(!editId)return;
  if(!confirm('Padam kandungan ini? Tindakan tidak boleh diundur.'))return;`
- **Cadangan:** Either add a 'Padam' button (visible only in edit mode) with onclick="delItem()", or remove the unused function to avoid confusion.

### (logic) roles/staff/pakej-report.html — "Aktiviti (30 hari)" KPI is computed from a 30-row-capped, undated query so it can be inaccurate
- **Di mana:** renderActivity / kpi-activity
- **Masalah:** The audit query uses .limit(30) with no date filter, then the KPI counts how many of those rows fall within the last 30 days. For a package with many lifetime audit rows, the 30 most-recent rows may all be older than 30 days (count understated), or conversely the cap hides genuinely recent activity beyond the 30 newest rows. The label promises a clean 30-day activity count but the value is bounded by an arbitrary row cap rather than a time window.
- **Bukti:** `const { data } = await window.db.from('psy_audit_log')
    .select('id, action, actor_name, meta, created_at')
    .or(`target.eq.${pkg.id},meta->>package_id.eq.${pkg.id}`)
    .order('created_at', { ascending: false })
    .limit(30);
...`
- **Cadangan:** For the KPI, run a dedicated count query with a created_at >= (now - 30 days) filter (and { count: 'exact', head: true }) instead of deriving it from the display list capped at 30 rows.

### (logic) roles/staff/pakej.html — resetPkgImageCrop render flag is dead code — both branches call renderPkgImageCrop()
- **Di mana:** resetPkgImageCrop()
- **Masalah:** The function takes a `render` parameter to decide whether to re-render the crop, but both the if and else branches call renderPkgImageCrop(), so passing render=false (from applyPkgImageAdjustment(reset=true) -> resetPkgImageCrop(false)) still triggers a render. Not user-visible breakage, but the guard is meaningless and may cause an unintended extra render of a possibly not-yet-ready crop image.
- **Bukti:** `if (render) renderPkgImageCrop();
  else renderPkgImageCrop();`
- **Cadangan:** Make the else branch a no-op (remove the redundant call) if the intent was to skip rendering, or remove the parameter entirely.

### (logic) roles/staff/patient-hub.html — Personal-info card reads profile columns never fetched by the join
- **Di mana:** renderPersonalInfo()
- **Masalah:** renderPersonalInfo derives prof from patient.psy_profiles and reads prof.dob/prof.tarikh_lahir/prof.ic_number/prof.gender/prof.marital_status/prof.email/prof.address. The psy_profiles join in loadPatient only selects (full_name, phone, email, avatar_url), so all those extra prof.* fields are always undefined and the card silently always falls back to the patient row. The profile->patient fallback masks it, but the prof branch is dead and misleading; if patient.* is also missing the card shows '—' even when profile data exists.
- **Bukti:** `const dob = prof.dob || p.dob || prof.tarikh_lahir; ... { lbl: 'No. Kad Pengenalan', val: prof.ic_number || p.ic_number || '—' }, ... .select('*, psy_profiles!psy_patients_user_id_fkey(full_name, phone, email, avatar_url)')`
- **Cadangan:** Either expand the psy_profiles select to include the columns actually read, or drop the non-existent prof.* references since the join never returns them.

### (logic) roles/staff/patient-hub.html — Newly uploaded reports default to report_type 'dna' which no filter option matches
- **Di mana:** renderDnaList() / uploadDnaReports()
- **Masalah:** uploadDnaReports inserts into psy_medical_reports without report_type, so renderDnaList treats them as (r.report_type || 'dna') = 'dna'. The filter <select> only offers laporan/ujian/imaging/rujukan/lain (no 'dna' option). With 'Semua Jenis' selected they appear, but selecting ANY specific type filters out every freshly-uploaded report, making them seem to vanish.
- **Bukti:** `const filtered = filter ? allMedicalReports.filter(r => (r.report_type || 'dna') === filter) : allMedicalReports;`
- **Cadangan:** Set report_type:'laporan' (or a sensible default) on insert in uploadDnaReports, or default to 'lain' in renderDnaList so it matches the 'Lain-lain' filter option.

### (logic) roles/staff/patients.html — Restoring an archived patient always downgrades status to inactive/unregistered
- **Di mana:** restorePatient()
- **Masalah:** deletePatient() captures a full snapshot of the row before soft-deleting (status set to 'deleted'). restorePatient() ignores that snapshot and unconditionally sets status to 'inactive' (if user_id present) or 'unregistered'. A patient who was 'active' before being archived is silently restored as 'inactive', losing their real status with no warning. The snapshot needed to restore the correct status was already saved at archive time but is not used.
- **Bukti:** `const restoreStatus = pt?.user_id ? 'inactive' : 'unregistered';
        const { error } = await window.db.from('psy_patients').update({ status: restoreStatus }).eq('id', id);`
- **Cadangan:** Restore the previous status from the archive snapshot (auditLog meta.snapshot.status) when available, falling back to the current inactive/unregistered default only if no prior status is known.

### (logic) roles/staff/product-detail.html — Audit-log OR filter clause `meta->>product_id` never matches any row
- **Di mana:** renderLog()
- **Masalah:** renderLog filters with `.or(target.eq.<id>, meta->>product_id.eq.<id>)`, but no audit-log writer in the app stores product_id inside meta. auditLog() (config/supabase.js) writes `target: <id>` and `meta: { name }`/`{ name, sku }` only. The second OR clause is dead and can never contribute rows; all matches come from `target.eq`. Harmless today but misleading and silently relies on `target` always being set.
- **Bukti:** `.or(`target.eq.${product.id},meta->>product_id.eq.${product.id}`)`
- **Cadangan:** Drop the unused `meta->>product_id` clause, or make the audit writers actually populate meta.product_id if that lookup path is intended.

### (logic) roles/staff/product-edit.html — Duplicate declaration of pickInventoryById
- **Di mana:** pickInventoryById
- **Masalah:** The function pickInventoryById is declared twice with an identical body (once at the top of the picker block and again after escAttr). In strict/module contexts this would be a SyntaxError; in sloppy script mode the second hoisted declaration silently overrides the first. It is dead/confusing duplication that should be removed to avoid future divergence.
- **Bukti:** `// Legacy entry point (kalau code lain panggil by id)
function pickInventoryById(id) {
  const item = (window._invPickerAvailable || []).find(i => String(i.id) === String(id));
  if (item) pickInventoryItem(item);
}
...
function pickInvento`
- **Cadangan:** Delete one of the two identical pickInventoryById definitions so only a single declaration remains.

### (logic) roles/staff/staff-stats.html — Doctor 'Pesakit' metric counts treatment plans, not distinct patients
- **Di mana:** loadStats() - patientsPerDoctor
- **Masalah:** patientsPerDoctor is built by incrementing per treatment-plan row, then used as the doctor's patient count. There is no UNIQUE(patient_id) constraint on psy_treatment_plans, so a doctor with multiple plans for the same patient (e.g. plan renewals) is over-counted in the 'Pesakit' column/card, overstating doctor patient load.
- **Bukti:** `const patientsPerDoctor = {};
plansAll.forEach(p => { if (p.doctor_id) patientsPerDoctor[p.doctor_id] = (patientsPerDoctor[p.doctor_id]||0)+1; });`
- **Cadangan:** Count distinct patient_id per doctor (select patient_id from psy_treatment_plans and dedupe into a Set per doctor) instead of counting plan rows.

### (logic) roles/staff/vitals.html — loadRecent has no error guard and is awaited inconsistently
- **Di mana:** loadRecent()
- **Masalah:** loadRecent() calls dbQuery('psy_vitals', ...) and window.db.from('psy_patients') without any try/catch or .catch fallback (unlike loadPatientVitalsHistory which uses .catch(() => [])). If either query throws (RLS, network), the function rejects. It is invoked un-awaited from the init IIFE (line 218) and from saveVitals (line 132) after the success banner. On failure the 'Vitals Terkini' table is silently left blank (or stale) with no error feedback, and produces an unhandled promise rejection. After a successful save the user sees 'Vitals disimpan' but the recent table may not refresh.
- **Bukti:** `const data = await dbQuery('psy_vitals', { order: { col: 'created_at' }, limit: 20 });  ...  const patientsRes = await window.db.from('psy_patients').select(...);  // (no try/catch; called as `loadRecent();` un-awaited on lines 132 and 218)`
- **Cadangan:** Wrap loadRecent body in try/catch and render an error/empty state in #recent-vitals-body on failure, mirroring the .catch(() => []) pattern already used in loadPatientVitalsHistory.

### (ux) roles/patient/faq.html — Feedback shows success banner even when the DB upsert fails
- **Di mana:** fbFaq()
- **Masalah:** The upsert error is swallowed with .catch(()=>{}) and banner('Terima kasih...') is shown unconditionally afterward. If the write fails (RLS, network, no session), the user still sees a success/thank-you message while their feedback was never saved, giving false confirmation.
- **Bukti:** `await window.db.from('psy_library_feedback').upsert({...},{onConflict:'user_id,item_id'}).catch(()=>{});
  banner(helpful?'Terima kasih 👍':'Terima kasih, kami akan perbaiki 👎');`
- **Cadangan:** Capture the upsert result/error and only show the thank-you banner on success; on error show an error banner (banner('Gagal menyimpan maklum balas','error')) and optionally roll back the optimistic FB[itemId] state.

### (ux) roles/patient/feedback.html — Weekly submit button has no disabled/loading state, allowing double-submit
- **Di mana:** submitWeeklyFeedback()
- **Masalah:** Unlike submitFeedback() (which disables the button and shows 'Menghantar...'), submitWeeklyFeedback() does not disable its trigger button during the async insert. A user who taps twice quickly can create duplicate weekly feedback rows for the same week before the UI resets.
- **Bukti:** `async function submitWeeklyFeedback() {
  if (!selectedWeek) { banner('Pilih minggu', 'error'); return; }
  if (!wOverall) { banner('Sila bagi rating overall', 'error'); return; }
  ...
    const { error } = await window.db.from('psy_feedba`
- **Cadangan:** Disable the submit button and show a sending state for the duration of the insert, re-enabling in a finally block (mirroring submitFeedback).

### (ux) roles/patient/issue-thread.html — Transient load error silently redirects away, losing context
- **Di mana:** loadThread()
- **Masalah:** The initial issue fetch destructures only { data: rows } and ignores the error. On any transient failure (network blip, RLS hiccup) rows is undefined, so currentIssue becomes undefined and the user is silently bounced back to issue.html with no error shown. A real fetch failure is indistinguishable from an invalid id, and the user loses their open thread without explanation.
- **Bukti:** `const { data: rows } = await window.db
    .from('psy_audit_log').select('*').eq('id', issueId).limit(1);

  currentIssue = rows?.[0];
  if (!currentIssue) { window.location.href = 'issue.html'; return; }`
- **Cadangan:** Capture { data: rows, error }; if error, show a visible error/retry message instead of redirecting, and only redirect when the row is genuinely absent (no error).

### (ux) roles/patient/issue.html — No enforcement of the advertised 5MB / image size limit
- **Di mana:** previewPhoto()
- **Masalah:** The upload UI states 'JPG, PNG — max 5MB' but previewPhoto() accepts any selected file with no size check. A patient can pick a large file; the over-limit upload may then fail at the storage layer and (per the silent-failure bug above) the report submits without the photo with no explanation.
- **Bukti:** `<div class="text-xs text-ink/50 mt-0.5">JPG, PNG — max 5MB</div>
...
function previewPhoto(e) {
  const file = e.target.files[0];
  if (!file) return;
  issuePhotoFile = file;`
- **Cadangan:** Validate file.size (e.g. > 5 * 1024 * 1024) in previewPhoto() and reject with a banner before storing issuePhotoFile.

### (ux) roles/patient/kepatuhan.html — Week load swallows DB errors silently, leaving an empty week strip with no feedback
- **Di mana:** loadWeek()
- **Masalah:** loadWeek only reads logsRes.data/ckRes.data with `|| []` and never inspects logsRes.error or ckRes.error. If either query fails (RLS, network), the week strip and filled-state simply render as if nothing was logged, with no banner or retry, so the patient may think their previous entries were lost.
- **Bukti:** `(logsRes.data || []).forEach(r => { logCache[r.log_date] = r.jawapan || {}; }); (ckRes.data || []).forEach(r => { healthCache[r.checkin_date] = r; });`
- **Cadangan:** Check logsRes.error/ckRes.error and surface a banner('Gagal memuat rekod minggu', 'error') (or retry) instead of silently showing an empty week.

### (ux) roles/patient/orders.html — DB load error is masked by the 'no orders' empty state
- **Di mana:** loadOrders
- **Masalah:** On a query error, loadOrders shows a transient banner but then continues with `allOrders = orders || []` (orders is null on error) and renderOrders() draws the normal empty state ('Tiada orders lagi.'). A patient whose orders failed to load sees a 'no orders' screen indistinguishable from genuinely having none, and the misleading state persists after the banner fades.
- **Bukti:** `if (error) banner('Ralat memuatkan order: ' + error.message, 'error');

  allOrders = orders || [];
  renderTabs();
  renderOrders();`
- **Cadangan:** On error, return early or render a distinct error state with a retry action rather than falling through to the empty-orders UI.

### (ux) roles/patient/pakej-detail.html — setHeaderBack call is dead because renderHeader immediately hides the header
- **Di mana:** IIFE init — setHeaderBack then renderHeader (lines 316-317)
- **Masalah:** setHeaderBack('pakej.html','Kembali ke Senarai Pakej') injects a back button into #page-header, but the next line renderHeader() sets #page-header to display:none (shared/navbar.js renderHeader: `if (header) header.style.display = 'none';`). So the 'Kembali ke Senarai Pakej' button never renders. Minor because the page also has its own visible goBackSmart button, but the labeled header back link silently does nothing, unlike sibling library-detail.html which calls setHeaderBack without a following renderHeader and shows it.
- **Bukti:** `setHeaderBack('pakej.html', 'Kembali ke Senarai Pakej');
  renderHeader(pkg.name, pkg.desc);`
- **Cadangan:** Remove the redundant setHeaderBack call (the in-page goBackSmart button already covers navigation), or drop renderHeader if the header back button is meant to show.

### (ux) roles/patient/rekod-perubatan.html — No error handling on the records query leaves UI stuck on loading or silently empty
- **Di mana:** load IIFE — window.db.from('psy_medical_reports').select(...)
- **Masalah:** The initial fetch destructures only { data } and ignores { error }. On a network/RLS error, data is null so RECS=[] and the page renders an empty 'Tiada dokumen' state with no indication that loading failed. Also app-loading is hidden by initStaff/initPatient/navbar shell logic, but if the query throws (rejected promise) the await is unguarded and the rest of init (renderStats/render/tc-all) never runs, leaving stale UI.
- **Bukti:** `const { data }=await window.db.from('psy_medical_reports').select('*').eq('patient_id',patientRecord.id).order('uploaded_at',{ascending:false});
  RECS=data||[];`
- **Cadangan:** Capture { data, error }; on error show a visible error/retry state instead of a blank 'no documents' table, and wrap the call in try/catch so a thrown query does not abort the rest of init.

### (ux) roles/staff/acara-detail.html — Registrations/materials/creator queries ignore their error fields
- **Di mana:** main IIFE loader (lines 331-340)
- **Masalah:** The loader only destructures { data } for the registrations, materials, and creator-profile queries. If any of those calls returns an error (RLS, network), data is undefined and the code silently falls back to empty arrays (regs||[], mats||[]) so the staff sees an event with zero participants/materials with no indication anything failed, which is misleading for a clinic operator deciding attendance.
- **Bukti:** `const { data: regs } = await window.db.from('psy_event_registrations')
      .select(...).eq('event_id', id).neq('status', 'batal')...;
    REGS = regs || [];`
- **Cadangan:** Capture error on each query and surface a banner/inline notice when a sub-query fails rather than silently showing empty data.

### (ux) roles/staff/announcement-detail.html — Status-changing action has no confirmation
- **Di mana:** toggleActive()
- **Masalah:** Nyahaktifkan/Aktifkan immediately writes to the DB on a single click with no confirm dialog. Deactivating an active announcement hides it from all patients instantly; an accidental click changes visibility for everyone with no undo prompt. There is success/error banner feedback, but no guard before the write.
- **Bukti:** `<button onclick="toggleActive()" ...>${statusKey()==='draft'?'✓ Aktifkan':'⊘ Nyahaktifkan'}</button>`
- **Cadangan:** Wrap the deactivate path in a confirm() (or modal) before calling window.db.update, at least when transitioning an active item to draft.

### (ux) roles/staff/assignments.html — No error/empty handling when psy_patients query fails — page silently shows zeros
- **Di mana:** loadData()
- **Masalah:** The main load destructures only { data } from the psy_patients select and never checks error. On a network/RLS failure data is null, allPatients becomes [], and the table just shows the empty state ('Tiada rekod ditemui') with no indication anything went wrong, so the user cannot distinguish a real empty list from a failed load.
- **Bukti:** `const { data } = await window.db.from('psy_patients').select(...).neq('status','deleted').order('created_at',{ascending:false});
  allPatients = data || [];`
- **Cadangan:** Capture { data, error } and, if error, show a visible error banner/state instead of the generic empty message.

### (ux) roles/staff/assignments.html — Export produces a header-only file with no feedback when the list is empty
- **Di mana:** exportList()
- **Masalah:** exportList() builds rows from the filtered list with no guard for an empty result. If there are no patients in the current tab/filter, it still writes an .xlsx containing only the header row, and the user gets no message that nothing was exported.
- **Bukti:** `const rows = [ ['No','Patient ID',...], ...list.map(...) ]; ... XLSX.writeFile(wb, ...);`
- **Cadangan:** If list.length === 0, banner('Tiada pesakit untuk dieksport') and return before building the workbook.

### (ux) roles/staff/inventory.html — Inventory table colspan=6 but table only has 5 columns
- **Di mana:** inv-tbody loading row + renderItems() empty state
- **Masalah:** The inventory <thead> defines exactly 5 columns (Item, Kategori, Stok Semasa, Diperlukan, Status), but the loading placeholder row and the empty/no-match message row both span 6 columns. This creates a phantom extra column cell when the loading or empty message is shown, slightly mis-aligning the placeholder. Cosmetic only.
- **Bukti:** `<tr><td colspan="6" class="text-center py-12 text-ink/40 text-sm">Memuatkan...</td></tr>`
- **Cadangan:** Change colspan="6" to colspan="5" on both the inv-tbody loading row and the empty-state row in renderItems().

### (ux) roles/staff/inventory.html — Requests table loading row colspan=6 but table has 8 columns
- **Di mana:** req-tbody loading row
- **Masalah:** The requests <thead> defines 8 columns (Item, Qty, Harga/Unit, Jumlah, Status, Pemohon, Tarikh, Tindakan), and the empty-state row in renderRequests() correctly uses colspan=8, but the initial 'Memuatkan...' placeholder row uses colspan=6. The loading message is therefore not centered across the full table width. Cosmetic only.
- **Bukti:** `<tr><td colspan="6" class="text-center py-12 text-ink/40 text-sm italic">Memuatkan...</td></tr>`
- **Cadangan:** Change the req-tbody loading row to colspan="8" to match the header and the empty-state row.

### (ux) roles/staff/issue.html — DB query failure is swallowed and shown as empty 'Tiada isu'
- **Di mana:** loadIssues()
- **Masalah:** loadIssues runs seven Promise.all queries but never inspects the .error fields. On any failure (RLS denial, network blip) issueRes.data is null, allIssues becomes [], and renderList() displays the 'Tiada isu' empty state. A staff member cannot distinguish 'genuinely no issues' from 'the data failed to load', so a real load error looks like a working empty inbox.
- **Bukti:** `const [issueRes, respRes, followRes, closedRes, reqRes, appRes, rejRes] = await Promise.all([ ... ]);

      allIssues = issueRes.data || [];`
- **Cadangan:** Check issueRes.error (and the others) and render a distinct error state with a retry option instead of the empty-state when a query fails.

### (ux) roles/staff/kepatuhan.html — No error handling if patient/log queries fail; UI silently shows empty data
- **Di mana:** loadData() / loadMonthly() — Promise.all DB calls
- **Masalah:** loadData and loadMonthly read patientsRes.data/logsRes.data with `|| []` fallback but never check the Supabase error field. If a query fails (RLS, network, bad column), the page renders as if there are zero patients/logs (empty table, 0% KPIs, empty heatmap) with no banner or error state, leaving staff to think no one is enrolled rather than that the load failed.
- **Bukti:** `const patients = (patientsRes.data || []).filter(p => p.active_package_id ...); const logs = logsRes.data || [];`
- **Cadangan:** Check patientsRes.error / logsRes.error (and the monthly equivalents) and surface banner('Gagal memuatkan data: '+err.message,'error') instead of falling through to an empty rendered state.

### (ux) roles/staff/library-faq-edit.html — Saved topic that is not in the category list is silently dropped on edit
- **Di mana:** load IIFE (edit mode) line 229 + loadCategories()
- **Masalah:** In edit mode f-topic value is set to it.topic, but the <select> options come from psy_library_categories (scope=faq) plus a hardcoded fallback list. If the item's saved topic was later renamed/deactivated/deleted as a category, sel.value=it.topic matches no <option> and the select silently falls back to the empty 'Pilih kategori'. The staff sees a blank category and, if they save without noticing, overwrites the original topic with '' (which then fails the required-category validation only if they happen to re-save). The original category is effectively lost on view.
- **Bukti:** `document.getElementById('f-topic').value=it.topic||'';`
- **Cadangan:** When it.topic is non-empty but not present among the select options, inject a temporary <option> with that value (selected) so the existing category is preserved and visible.

### (ux) roles/staff/patient-hub.html — 'Lihat Semua' alerts link is a dead href="#"
- **Di mana:** Check-in tab 'Peringatan Terkini' header link
- **Masalah:** The 'Peringatan Terkini' panel header has a 'Lihat Semua' anchor with href="#" and no handler. Clicking it just jumps to top of page (or does nothing), giving the impression the feature is broken with no way to actually view all alerts.
- **Bukti:** `<a href="#" class="text-[11px] font-semibold text-[#6366f1] hover:underline">Lihat Semua</a>`
- **Cadangan:** Point it to the real alerts/kepatuhan page (e.g. kepatuhan.html?patient_id=...) or remove the link until implemented.

### (ux) roles/staff/patients.html — window.open result not null-checked before document.write
- **Di mana:** printPatientReport() / printList()
- **Masalah:** Both print functions open a new window and immediately call w.document.write(html). If the browser blocks the popup (common when print is triggered outside a direct user gesture, or with popup blockers), window.open returns null and the next line throws 'Cannot read properties of null (reading document)'. The print silently fails with an uncaught TypeError and no banner/feedback to the user.
- **Bukti:** `const w = window.open('', '_blank', 'width=800,height=700');
      w.document.write(html);
      w.document.close();`
- **Cadangan:** Guard the return value: const w = window.open(...); if (!w) { banner('Popup disekat oleh pelayar. Sila benarkan popup untuk cetak.', 'error'); return; } before calling w.document.write.

### (ux) roles/staff/payment-admin.html — Manual payment save: no disable/guard against double-submit
- **Di mana:** saveManual
- **Masalah:** saveManual() does an async insert then loadData(); the Simpan button is never disabled during the await, so a quick double-click can insert two duplicate completed payment records (each with a different Date.now() receipt ref, so no dedup catches them).
- **Bukti:** `<button onclick="saveManual()" class="w-full bg-navy text-white font-semibold py-2.5 rounded-lg hover:bg-navy-dark transition-colors">
        Simpan Bayaran
      </button>`
- **Cadangan:** Disable the button (or set a saving flag) at the start of saveManual and re-enable in finally.

### (ux) roles/staff/plans.html — Compliance modal and Create-Plan modal are unreachable — no UI control opens them
- **Di mana:** compliance-modal / #modal (create plan)
- **Masalah:** The '#compliance-modal' (with saveCompliance) and '#modal' create-plan dialog (with savePlan/openModal) are fully built and wired to close/save handlers, but nothing in the page ever calls openCompliance() or openModal(). The '+ Plan Baru' button was intentionally removed (comment line 28) and openCompliance has no trigger. The result is dead UI: a staff user cannot create a plan or record compliance from this page even though the modals and save logic exist.
- **Bukti:** `<!-- "+ Plan Baru" dibuang ... -->
... function openModal() { ... }  // never called
... async function openCompliance(planId, patientId, week) { ... }  // never called`
- **Cadangan:** Either remove the orphaned modals and their handler functions, or add the trigger buttons (and confirm whether compliance recording is intended to live on this page or on plan-week.html).

### (ux) roles/staff/product-detail.html — Audit-log query error is swallowed and shown as 'Tiada aktiviti'
- **Di mana:** renderLog()
- **Masalah:** The Supabase call destructures only `{ data }` and ignores `error`. On a query failure (RLS denial, bad filter, network), `data` is undefined, `list` becomes [], and the panel renders 'Tiada aktiviti' as if the product genuinely has no history. The dev/user gets no error feedback and cannot distinguish a failure from an empty log.
- **Bukti:** `const { data } = await window.db.from('psy_audit_log')
    .select('id, action, actor_name, meta, created_at')
    .or(`target.eq.${product.id},meta->>product_id.eq.${product.id}`)
    .order('created_at', { ascending: false })
    .limit(1`
- **Cadangan:** Capture `{ data, error }` and render a distinct error state (e.g. 'Gagal memuatkan log') when error is set, instead of falling through to the empty state.

### (ux) roles/staff/product-edit.html — Inventory load failure leaves picker silently empty
- **Di mana:** openInventoryPicker
- **Masalah:** The query to psy_inventory_items destructures only { data } and ignores error. On a network/RLS failure data is null, _invItemsCache becomes [], and the modal shows 'Tiada item ditemui' with no indication the load actually failed, so the user cannot tell the difference between an empty inventory and a broken fetch.
- **Bukti:** `const { data } = await window.db.from('psy_inventory_items')
      .select('id, name, category, unit, qty_in_stock, min_qty, notes').order('name');
    _invItemsCache = data || [];`
- **Cadangan:** Capture { data, error } and call banner('Gagal memuatkan inventori', 'error') (or show an error state in the list) when error is set.

### (ux) roles/staff/service-detail.html — Initial data load has no error handling — blank shell on query failure
- **Di mana:** IIFE bootstrap — Promise.all DB load
- **Masalah:** initStaff() reveals app-shell and hides app-loading before the data query runs. If the Promise.all rejects (e.g. network error / Supabase outage on the psy_services or psy_inventory_items fetch), the IIFE rejects unhandled, renderView never runs, and the user is left staring at an empty card shell with no error message. Only the null-result path (service not found) is handled, not a thrown error.
- **Bukti:** `const [{ data: s }, { data: inv }] = await Promise.all([
    window.db.from('psy_services').select('*').eq('id', id).single(),
    window.db.from('psy_inventory_items').select('id,name,unit').order('name'),
  ]);
  allInvItems = inv || [];`
- **Cadangan:** Wrap the load in try/catch and banner an error on failure so the user knows the page failed to load.

### (ux) roles/staff/surat.html — 'Draf' status card and filter are dead — no record can ever have status 'draft'
- **Di mana:** renderStats() / filterStatus('draft') / 'Draf' stat-card
- **Masalah:** The UI has a 'Draf' stat card (stat-draft), a renderStats() count for status==='draft', a statusChip case 'draft', and a filterStatus('draft') branch in renderList(). However the psy_letter_requests CHECK constraint only permits ('pending','issued','rejected','cancelled') and the only insert path (patient surat.html) writes status:'pending'. No code anywhere creates a 'draft' request, so the Draf card always shows 0 and clicking it always yields an empty list. This is misleading dead UI for staff.
- **Bukti:** `const draft    = allRequests.filter(r => r.status === 'draft').length;
...
<div class="text-[11px] text-ink/55 font-semibold">Draf</div>
<div id="stat-draft" class="text-2xl font-bold mt-0.5">0</div>`
- **Cadangan:** Either remove the Draf stat card / filter / statusChip case until a draft flow actually exists, or implement and persist a 'draft' status (and add it to the DB CHECK constraint) if save-as-draft is intended.
