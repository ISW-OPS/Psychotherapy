// ============================================================
// _shared/kob_retry_link.ts — jana pautan HitPay bayaran pakej KOB
// (deposit ansuran / ansuran manual / bayaran penuh) — amaun diderive
// 100% server-side. Logik ni PORT terus dari payments-kob-initiate
// (mode full/installment/manual_installment) supaya SATU sumber
// kebenaran harga, dikongsi antara:
//
//   1. payments-kob-initiate — staff klik "Jana & Hantar Pautan" manual
//      di kob-detail.html (JWT staff disahkan oleh pemanggil).
//   2. payments-webhook — auto-jana pautan BAHARU bila bayaran kob_deposit
//      gagal, sebab pesakit KOB selalunya tiada akaun/log masuk utk
//      retry sendiri (bukan macam laluan payments-initiate/kob.html biasa).
//
// Helper ni SENDIRI tiada auth — pemanggil yang tanggungjawab authorize.
// Nota mode='topup' (ansuran SETERUSNYA, pelan sedia berjalan) BUKAN di
// sini — kekal di kob_topup.ts (laluan/precondition berbeza sepenuhnya).
// ============================================================
import { activeProviderName, getProvider } from './payments/index.ts'

const money = (n: number) => (Math.round(n * 100) / 100).toFixed(2)
const isUuid = (s: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)

export interface KobDepositLink {
  checkoutUrl: string
  receiptRef: string
  amount: number
  itemTitle: string
}

export async function createKobDepositLink(
  admin: any,
  opts: { kobSessionId: string; mode: 'full' | 'installment' | 'manual_installment'; tier?: 'today' | 'now'; returnUrl: string },
): Promise<KobDepositLink> {
  const { kobSessionId, mode, returnUrl } = opts

  const { data: kobRows } = await admin.from('psy_kob_sessions')
    .select('id, patient_id, recommended_package_id, recommended_package_name, recommended_package_price, package_payment_status')
    .eq('id', kobSessionId).limit(1)
  const kob = kobRows?.[0]
  if (!kob) throw new Error('Sesi KOB tidak dijumpai')
  if (!kob.recommended_package_id) throw new Error('Sesi KOB ini tiada pakej dicadangkan')
  if (kob.package_payment_status !== 'pending' && kob.package_payment_status !== 'declined') {
    throw new Error('Bayaran pakej sesi ini bukan lagi berstatus pending/declined')
  }

  const tier: 'today' | 'now' = (opts.tier === 'today' || opts.tier === 'now')
    ? opts.tier : (kob.package_payment_status === 'pending' ? 'today' : 'now')

  let pkgQ = admin.from('psy_packages')
    .select('price, today_price, installment_allowed, installment_deposit_amount, installment_duration_months, installment_monthly_amount, today_installment_deposit_amount, today_installment_duration_months, today_installment_monthly_amount')
  pkgQ = isUuid(kob.recommended_package_id)
    ? pkgQ.or(`id.eq.${kob.recommended_package_id},package_id.eq.${kob.recommended_package_id}`)
    : pkgQ.eq('package_id', kob.recommended_package_id)
  const { data: pkgRows } = await pkgQ.limit(1)
  const pkgMeta = pkgRows?.[0]

  const packagePrice = tier === 'today'
    ? Number(kob.recommended_package_price || 0)
    : Number(pkgMeta?.price || 0)
  if (!(packagePrice > 0)) throw new Error('Harga pakej tidak sah')

  const tierDepositAmount = tier === 'today'
    ? (pkgMeta?.today_installment_deposit_amount ?? pkgMeta?.installment_deposit_amount)
    : pkgMeta?.installment_deposit_amount
  const tierDurationMonths = tier === 'today'
    ? (pkgMeta?.today_installment_duration_months ?? pkgMeta?.installment_duration_months)
    : pkgMeta?.installment_duration_months
  const tierMonthlyAmount = tier === 'today'
    ? (pkgMeta?.today_installment_monthly_amount ?? pkgMeta?.installment_monthly_amount)
    : pkgMeta?.installment_monthly_amount

  let amount: number
  if (mode === 'installment') {
    const installmentAllowed = !!pkgMeta?.installment_allowed && Number(tierDepositAmount) > 0 &&
      Number(tierDurationMonths) > 1 && Number(tierMonthlyAmount) > 0
    if (!installmentAllowed) throw new Error('Pakej ini tidak membenarkan ansuran')
    amount = Number(tierDepositAmount)
  } else if (mode === 'manual_installment') {
    // Jadual custom mesti dah disimpan sbg checkpoint 'pending' (seq=0=deposit)
    // oleh ensureManualScheduleDraft() SEBELUM ni — sama precondition macam
    // payments-kob-initiate. Kalau tiada, gagal (caller patut fallback).
    const { data: cpRows } = await admin.from('psy_kob_installment_checkpoints')
      .select('target_cumulative, status').eq('kob_session_id', kobSessionId).eq('seq', 0).limit(1)
    const cp = cpRows?.[0]
    if (!cp || cp.status !== 'pending') throw new Error('Jadual Ansuran Manual belum disediakan')
    amount = Number(cp.target_cumulative)
  } else {
    amount = packagePrice
  }

  const { data: ptRows } = await admin.from('psy_patients')
    .select('user_id, full_name, phone').eq('id', kob.patient_id).limit(1)
  const patient = ptRows?.[0]
  let patientEmail: string | undefined
  if (patient?.user_id) {
    const { data: au } = await admin.auth.admin.getUserById(patient.user_id).catch(() => ({ data: null }))
    patientEmail = au?.user?.email || undefined
  }

  const receiptRef = 'RCP-' + Date.now().toString(36).toUpperCase() +
    '-' + Math.floor(performance.now()).toString(36).toUpperCase()
  const provider = activeProviderName()
  const itemTitle = `${mode === 'full' ? 'Bayaran Penuh' : mode === 'manual_installment' ? 'Deposit Ansuran Manual' : 'Deposit Ansuran'} — ${kob.recommended_package_name || ''}`.trim()

  // Gantikan percubaan pending LAMA utk sesi KOB yg sama — elak baris 'pending'
  // berterusan mengelirukan sejarah/jumlah "Menunggu".
  await admin.from('psy_payments')
    .update({ status: 'failed', gateway_status: 'superseded', notes: 'Digantikan oleh pautan HitPay baharu' })
    .eq('patient_id', kob.patient_id).eq('status', 'pending')
    .eq('intent->>kob_session_id', kobSessionId)

  const { error: insErr } = await admin.from('psy_payments').insert({
    receipt_ref: receiptRef,
    patient_id: kob.patient_id,
    user_id: patient?.user_id || null,
    items: [{ type: 'kob_deposit', title: itemTitle, amount, kobSessionId, mode, tier }],
    subtotal: amount,
    total: amount,
    payment_method: 'gateway',
    status: 'pending',
    gateway_provider: provider,
    gateway_status: 'pending',
    intent: {
      items: [{ type: 'kob_deposit', title: itemTitle, amount, kobSessionId, mode, tier }],
      patientId: kob.patient_id,
      userId: patient?.user_id || null,
      kob_session_id: kobSessionId,
    },
  })
  if (insErr) throw new Error('Gagal simpan bayaran pending: ' + insErr.message)

  const webhookUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/payments-webhook`
  const redirectUrl = `${returnUrl}${returnUrl.includes('?') ? '&' : '?'}ref=${encodeURIComponent(receiptRef)}`

  const created = await getProvider(provider).createPayment({
    reference: receiptRef,
    amount: money(amount),
    currency: 'MYR',
    email: patientEmail,
    name: patient?.full_name || undefined,
    purpose: itemTitle,
    redirectUrl,
    webhookUrl,
  })

  await admin.from('psy_payments').update({ gateway_ref: created.gatewayRef }).eq('receipt_ref', receiptRef)

  return { checkoutUrl: created.checkoutUrl, receiptRef, amount, itemTitle }
}
