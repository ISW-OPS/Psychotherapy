// ============================================================
// _shared/kob_deposit_fulfill.ts — fulfillment KONGSI utk item.type
// 'kob_package' & 'kob_deposit' (aktifkan pakej/ansuran lepas bayaran sah).
//
// Diextract dari payments-webhook/index.ts fulfillOrder() (23 Sept) supaya
// BOLEH dipanggil dari DUA webhook berbeza:
//   1. payments-webhook (form-encoded, laluan payment-requests biasa —
//      deposit dibayar FPX/e-wallet/kad TANPA simpan kad)
//   2. payments-webhook-recurring (JSON Hitpay-Signature, event
//      method_attached — deposit mode='installment' DENGAN saveCard=true,
//      pesakit pilih 'Kad' semasa checkout → kad disimpan SERENTAK dgn
//      deposit, lihat kob_retry_link.ts createKobDepositLink)
//
// Logik kumulatif/aktifkan pakej mesti SATU sumber kebenaran — jangan
// duplicate antara dua webhook (risiko drift macam bug pakej berganda 7 Ogos).
// ============================================================

const isUuid = (s: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)

// Port dari roles/staff/kob-detail.html buildInstallmentSchedule() — jadual
// ansuran RATA (deposit + tempoh bulan + amaun bulanan tetap), bukan checkpoint
// sewenang-wenang. Jumlah komitmen TAK semestinya = harga pakej penuh.
function buildInstallmentSchedule(depositAmount: number, durationMonths: number, monthlyAmount: number, startDate: Date) {
  const rows: { month_offset: number; target_cumulative: number; due_date: string }[] = []
  let cumulative = Number(depositAmount) || 0
  const n = Number(durationMonths) || 0
  for (let i = 1; i < n; i++) {
    cumulative += Number(monthlyAmount) || 0
    const due = new Date(startDate)
    due.setMonth(due.getMonth() + i)
    rows.push({ month_offset: i, target_cumulative: cumulative, due_date: due.toISOString().slice(0, 10) })
  }
  return rows
}

export async function isKobStatusCompleted(admin: any, patientId: string | null): Promise<boolean> {
  if (!patientId) return false
  const { data } = await admin.from('psy_patients').select('kob_status').eq('id', patientId).limit(1)
  return data?.[0]?.kob_status === 'completed'
}

// Hari-sesi (1=sesi pertama, 2=sesi kedua) yang PAKEJ tetapkan minggu w. Minggu tiada entri
// weekly eksplisit → anggap [1]. Sama logik dgn "Selaraskan ikut Pakej" (patient-hub.html).
function pkgSessionDaysForWeek(sched: any[], w: number): number[] {
  const e = (Array.isArray(sched) ? sched : []).find((it: any) => (it.period || 'week') !== 'day' && Number(it.week) === w)
  if (e && Array.isArray(e.session_days) && e.session_days.length) {
    return [...new Set(e.session_days.map(Number))].filter((d: number) => d >= 1 && d <= 7).sort((a: number, b: number) => a - b)
  }
  return [1]
}

// Skeleton mingguan (pending, tiada tarikh) ikut Timeline pakej. Tarikh ditempah kemudian bila
// pesakit/staff buka plan ("Jadualkan Semua Sesi"). Diexport — dipakai JUGA oleh
// payments-webhook fulfillOrder() cabang 'package' biasa (bukan KOB).
export async function seedPlanWeeklyProgress(admin: any, planId: string, patientId: string, coachingSchedule: any[], durationWeeks: number) {
  const rows: any[] = []
  for (let w = 1; w <= durationWeeks; w++) {
    for (const d of pkgSessionDaysForWeek(coachingSchedule, w)) {
      rows.push({ plan_id: planId, patient_id: patientId, week_number: w, session_day: d, status: 'pending', session_date: null })
    }
  }
  if (rows.length) await admin.from('psy_plan_weekly_progress').insert(rows)
}

// Diexport — dipakai JUGA oleh payments-webhook fulfillOrder() cabang 'package' biasa.
export async function getPlanTemplate(admin: any, packageId: string, packageName: string) {
  // GOTCHA: id.eq.<kod-bukan-uuid> error di Postgres — guard ikut format key.
  let q = admin.from('psy_packages').select('name, duration_weeks, duration_unit, coaching_schedule')
  q = isUuid(String(packageId)) ? q.or(`id.eq.${packageId},package_id.eq.${packageId}`) : q.eq('package_id', packageId)
  const { data } = await q.limit(1)
  const p = data?.[0]
  if (!p) return { name: `${packageName} Plan`, duration_weeks: 12, duration_unit: 'week', coaching_schedule: [] }
  return {
    name: `${p.name} Treatment Plan`,
    duration_weeks: p.duration_weeks || 12,
    duration_unit: p.duration_unit || 'week',
    coaching_schedule: p.coaching_schedule || [],
  }
}

// Pesakit beli pakej LEWAT (KOB dah ditandakan Selesai, cth declined semasa KOB →
// self-checkout kemudian) — markSelesai() (staff, kob-detail.html) TAKKAN panggil lagi
// utk sesi ni, jadi replikasi bahagian aktifkan-pakej dia di sini. Idempotent — skip
// kalau pesakit dah ada pakej aktif (elak overwrite pakej semasa yang tak berkaitan).
export async function activatePackageForPatient(admin: any, patientId: string | null, packageId: string | null, packageName: string | null, price: number) {
  if (!patientId || !packageId) return
  const { data: ptRows } = await admin.from('psy_patients').select('active_package_id').eq('id', patientId).limit(1)
  if (ptRows?.[0]?.active_package_id) return // dah ada pakej aktif — jangan overwrite

  const now = new Date().toISOString()
  const expires = new Date(); expires.setMonth(expires.getMonth() + 3)
  await admin.from('psy_package_purchases').insert({
    patient_id: patientId, package_id: packageId, package_name: packageName,
    price, expires_at: expires.toISOString(), status: 'active', payment_method: 'gateway',
  })
  await admin.from('psy_patients').update({
    active_package_id: packageId, active_package_name: packageName,
    package_purchased_at: now, package_expires_at: expires.toISOString(),
  }).eq('id', patientId)

  const { data: existing } = await admin.from('psy_treatment_plans')
    .select('id').eq('patient_id', patientId).eq('status', 'active').limit(1)
  if (!existing?.length) {
    const tpl = await getPlanTemplate(admin, packageId, packageName || '')
    const { data: newPlan } = await admin.from('psy_treatment_plans').insert({
      patient_id: patientId, doctor_id: null, name: tpl.name,
      duration_unit: tpl.duration_unit, duration_weeks: tpl.duration_weeks,
      current_week: 1, coaching_schedule: tpl.coaching_schedule, status: 'active',
    }).select('id').single()
    if (newPlan?.id) await seedPlanWeeklyProgress(admin, newPlan.id, patientId, tpl.coaching_schedule, tpl.duration_weeks)
  }
}

// item.type === 'kob_package' — pesakit self-checkout pakej terus dari kob.html.
export async function fulfillKobPackage(admin: any, item: any, patientId: string | null, receiptRef: string) {
  const now = new Date().toISOString()
  if (item.kobSessionId) {
    await admin.from('psy_kob_sessions').update({
      package_payment_status: 'paid', package_paid_at: now, package_receipt_ref: receiptRef,
    }).eq('id', item.kobSessionId)
  }
  // ELAK race condition: kalau doktor dah tandakan KOB 'completed' (markSelesai
  // di kob-detail.html) SEBELUM webhook ni sempat jalan, jangan turunkan balik status.
  const wasAlreadyCompleted = await isKobStatusCompleted(admin, patientId)
  await admin.from('psy_patients').update({ kob_status: 'package_paid' })
    .eq('id', patientId).neq('kob_status', 'completed')
  if (wasAlreadyCompleted) await activatePackageForPatient(admin, patientId, item.packageId, item.packageName, Number(item.amount || 0))
}

// item.type === 'kob_deposit' — deposit ansuran ATAU bayaran penuh pakej KOB.
// mode: 'installment' (formula pakej standard) | 'manual_installment' (jadual
// custom staff) | 'full' (bayaran penuh). tier='today'/'now' ikut status
// terkini sesi (lihat kob_retry_link.ts).
export async function fulfillKobDeposit(admin: any, item: any, patientId: string | null, receiptRef: string) {
  const now = new Date().toISOString()
  const kobSessionId = item.kobSessionId
  const wasAlreadyCompleted = await isKobStatusCompleted(admin, patientId)
  const { data: kobRows } = await admin.from('psy_kob_sessions')
    .select('recommended_package_id, recommended_package_name').eq('id', kobSessionId).limit(1)
  const kobRow = kobRows?.[0]
  const isToday = item.tier === 'today'

  if (item.mode === 'installment') {
    let pkgQ = admin.from('psy_packages')
      .select('installment_deposit_amount, installment_duration_months, installment_monthly_amount, today_installment_deposit_amount, today_installment_duration_months, today_installment_monthly_amount')
    pkgQ = isUuid(String(kobRow?.recommended_package_id))
      ? pkgQ.or(`id.eq.${kobRow.recommended_package_id},package_id.eq.${kobRow.recommended_package_id}`)
      : pkgQ.eq('package_id', kobRow?.recommended_package_id)
    const { data: pkgRows } = await pkgQ.limit(1)
    const pkgMeta = pkgRows?.[0]
    // Tier 'today' fallback ke Now bila today_* kosong; tier 'now'/tiada = terus Now (kod asal, tiada ubah).
    const tierDepositCol = isToday ? (pkgMeta?.today_installment_deposit_amount ?? pkgMeta?.installment_deposit_amount) : pkgMeta?.installment_deposit_amount
    const tierDurationCol = isToday ? (pkgMeta?.today_installment_duration_months ?? pkgMeta?.installment_duration_months) : pkgMeta?.installment_duration_months
    const tierMonthlyCol = isToday ? (pkgMeta?.today_installment_monthly_amount ?? pkgMeta?.installment_monthly_amount) : pkgMeta?.installment_monthly_amount
    const depositAmount = Number(tierDepositCol || item.amount || 0)
    const resolved = buildInstallmentSchedule(depositAmount, tierDurationCol, tierMonthlyCol, new Date())
    const rows = [
      { kob_session_id: kobSessionId, patient_id: patientId, seq: 0, month_offset: 0,
        due_date: now.slice(0, 10), target_cumulative: depositAmount, status: 'met', met_at: now },
      ...resolved.map((r, i) => ({
        kob_session_id: kobSessionId, patient_id: patientId, seq: i + 1, month_offset: r.month_offset,
        due_date: r.due_date, target_cumulative: r.target_cumulative,
        status: depositAmount >= r.target_cumulative ? 'met' : 'pending',
        met_at: depositAmount >= r.target_cumulative ? now : null,
      })),
    ]
    await admin.from('psy_kob_installment_checkpoints').insert(rows)
    await admin.from('psy_kob_sessions').update({
      package_payment_mode: 'installment', package_payment_status: 'partial', package_receipt_ref: receiptRef,
    }).eq('id', kobSessionId)
  } else if (item.mode === 'manual_installment') {
    // Jadual custom (deposit + tiap baris, amaun tak-rata staff isi sendiri) DAH
    // disimpan sbg checkpoint 'pending' oleh ensureManualScheduleDraft() SEBELUM
    // pautan HitPay dijana — di sini cuma tandakan baris yg dah tercapai 'met'.
    const depositAmount = Number(item.amount || 0)
    await admin.from('psy_kob_installment_checkpoints')
      .update({ status: 'met', met_at: now })
      .eq('kob_session_id', kobSessionId).eq('status', 'pending')
      .lte('target_cumulative', depositAmount)
    await admin.from('psy_kob_sessions').update({
      package_payment_mode: 'installment', package_payment_status: 'partial', package_receipt_ref: receiptRef,
    }).eq('id', kobSessionId)
  } else {
    await admin.from('psy_kob_sessions').update({
      package_payment_mode: 'full', package_payment_status: 'paid',
      package_paid_at: now, package_receipt_ref: receiptRef,
    }).eq('id', kobSessionId)
  }
  // ELAK race condition — lihat nota sama di fulfillKobPackage.
  await admin.from('psy_patients').update({ kob_status: 'package_paid' })
    .eq('id', patientId).neq('kob_status', 'completed')
  if (wasAlreadyCompleted) {
    await activatePackageForPatient(admin, patientId, kobRow?.recommended_package_id, kobRow?.recommended_package_name, Number(item.amount || 0))
  }
}

// item.type === 'kob_price_lock' — OB Lock Harga dibayar via HitPay. Ganti
// terus apa yang wizConfirmLockPrice() (kob-detail.html) buat client-side utk
// laluan Bayaran Manual — freeze locked_price_*, rekod lock_deposit_*/
// lock_expiry_date, lock_status='active'. tier/lockDays/amount DIPERCAYAI dari
// item sebab mode ni staff-only (disahkan payments-kob-initiate SEBELUM
// createKobPriceLockLink dipanggil — sama tahap amanah macam staff taip jumlah
// di borang Bayaran Manual, BUKAN kes amount pesakit boleh usik).
export async function fulfillKobPriceLock(admin: any, item: any, receiptRef: string, paymentId: string) {
  const kobSessionId = item.kobSessionId
  const now = new Date().toISOString()
  const { data: kobRows } = await admin.from('psy_kob_sessions')
    .select('recommended_package_id, recommended_package_price, locked_price_tier')
    .eq('id', kobSessionId).limit(1)
  const kobRow = kobRows?.[0]
  // Idempotent/race-safe — kalau sesi dah dikunci (cth staff sempat kunci manual
  // semasa pesakit tengah bayar via pautan), JANGAN timpa; deposit tetap
  // direkod (psy_payments), cuma kob_sessions tak diubah lagi.
  if (!kobRow || kobRow.locked_price_tier) return

  const tier: 'today' | 'now' = item.tier === 'now' ? 'now' : 'today'
  let packagePrice: number
  if (tier === 'today') {
    packagePrice = Number(kobRow.recommended_package_price || 0)
  } else {
    const isUuid = (s: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)
    let pkgQ = admin.from('psy_packages').select('price')
    pkgQ = isUuid(String(kobRow.recommended_package_id))
      ? pkgQ.or(`id.eq.${kobRow.recommended_package_id},package_id.eq.${kobRow.recommended_package_id}`)
      : pkgQ.eq('package_id', kobRow.recommended_package_id)
    const { data: pkgRows } = await pkgQ.limit(1)
    packagePrice = Number(pkgRows?.[0]?.price || 0)
  }

  const days = Number(item.lockDays || 0)
  const expiry = new Date(); expiry.setDate(expiry.getDate() + days)

  await admin.from('psy_kob_sessions').update({
    locked_price_tier: tier,
    locked_price_amount: packagePrice,
    locked_at: now,
    locked_by: item.initiatedByUserId || null,
    locked_by_name: item.initiatedByName || null,
    lock_deposit_amount: Number(item.amount || 0),
    lock_deposit_payment_id: paymentId,
    lock_deposit_paid_at: now,
    lock_deposit_method: 'gateway',
    lock_deposit_reference: receiptRef,
    lock_deposit_recorded_by: item.initiatedByUserId || null,
    lock_deposit_recorded_by_name: item.initiatedByName || null,
    lock_expiry_date: expiry.toISOString().slice(0, 10),
    lock_status: 'active',
    lock_extended_count: 0,
    lock_forfeited_at: null, lock_forfeited_by: null, lock_forfeited_by_name: null,
  }).eq('id', kobSessionId)

  await admin.from('psy_audit_log').insert({
    actor_name: 'Gateway (HitPay)', actor_role: 'system', action: 'kob.price_locked',
    target: kobSessionId, meta: { tier, amount: packagePrice, deposit: Number(item.amount || 0), via: 'hitpay' },
  }).catch(() => { /* audit gagal tak patut gagalkan webhook */ })
}
