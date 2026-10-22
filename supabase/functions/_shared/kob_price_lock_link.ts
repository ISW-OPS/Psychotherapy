// ============================================================
// _shared/kob_price_lock_link.ts — jana pautan HitPay utk "OB Lock Harga"
// (deposit reservation Kunci Harga, kob-detail.html Langkah 3). Beza drpd
// kob_retry_link.ts (kob_deposit): amaun DI SINI staff-entered (bukan
// diderive dari formula pakej) — selamat diterima dari client sebab mode
// ni staff-only (disahkan oleh payments-kob-initiate SEBELUM panggil helper
// ni), sama tahap amanah macam staff taip jumlah di borang Bayaran Manual.
//
// Fulfillment (freeze locked_price_* + lock_deposit_*/lock_expiry_date/
// lock_status) berlaku di payments-webhook SELEPAS gateway sahkan bayaran —
// lihat fulfillKobPriceLock() di kob_deposit_fulfill.ts.
// ============================================================
import { activeProviderName, getProvider } from './payments/index.ts'

const money = (n: number) => (Math.round(n * 100) / 100).toFixed(2)

export interface KobPriceLockLink {
  checkoutUrl: string
  receiptRef: string
  amount: number
}

export async function createKobPriceLockLink(
  admin: any,
  opts: {
    kobSessionId: string; tier: 'today' | 'now'; amount: number; days: number
    returnUrl: string; initiatedByUserId?: string | null; initiatedByName?: string | null
  },
): Promise<KobPriceLockLink> {
  const { kobSessionId, tier, amount, days, returnUrl, initiatedByUserId, initiatedByName } = opts

  const { data: kobRows } = await admin.from('psy_kob_sessions')
    .select('id, patient_id, recommended_package_id, recommended_package_name, locked_price_tier')
    .eq('id', kobSessionId).limit(1)
  const kob = kobRows?.[0]
  if (!kob) throw new Error('Sesi KOB tidak dijumpai')
  if (!kob.recommended_package_id) throw new Error('Sesi KOB ini tiada pakej dicadangkan')
  if (kob.locked_price_tier) throw new Error('Harga sesi ini sudah dikunci')

  const { data: ptRows } = await admin.from('psy_patients')
    .select('user_id, full_name, phone, email').eq('id', kob.patient_id).limit(1)
  const patient = ptRows?.[0]
  let patientEmail: string | undefined = patient?.email || undefined
  if (!patientEmail && patient?.user_id) {
    const { data: au } = await admin.auth.admin.getUserById(patient.user_id).catch(() => ({ data: null }))
    patientEmail = au?.user?.email || undefined
  }

  const receiptRef = 'RCP-' + Date.now().toString(36).toUpperCase() +
    '-' + Math.floor(performance.now()).toString(36).toUpperCase()
  const provider = activeProviderName()
  const itemTitle = `OB Lock Harga - ${kob.recommended_package_name || 'Pakej'}`

  // Gantikan percubaan pending LAMA (lock sahaja, bukan kob_package) — sama
  // pattern kob_retry_link.ts, elak baris 'pending' berterusan mengelirukan.
  await admin.from('psy_payments')
    .update({ status: 'failed', gateway_status: 'superseded', notes: 'Digantikan oleh pautan HitPay baharu' })
    .eq('patient_id', kob.patient_id).eq('status', 'pending')
    .eq('intent->>kob_session_id', kobSessionId).eq('intent->>type', 'kob_price_lock_deposit')

  const { error: insErr } = await admin.from('psy_payments').insert({
    receipt_ref: receiptRef,
    patient_id: kob.patient_id,
    user_id: patient?.user_id || null,
    items: [{ title: itemTitle, amount }],
    subtotal: amount,
    total: amount,
    payment_method: 'gateway',
    status: 'pending',
    gateway_provider: provider,
    gateway_status: 'pending',
    paid_for_type: 'price_lock',
    intent: {
      type: 'kob_price_lock_deposit',
      items: [{
        type: 'kob_price_lock', title: itemTitle, amount, kobSessionId, tier, lockDays: days,
        initiatedByUserId: initiatedByUserId || null, initiatedByName: initiatedByName || null,
      }],
      patientId: kob.patient_id, userId: patient?.user_id || null,
      kob_session_id: kobSessionId, initiated_by: 'staff',
    },
  })
  if (insErr) throw new Error('Gagal simpan bayaran pending: ' + insErr.message)

  const redirectUrl = `${returnUrl}${returnUrl.includes('?') ? '&' : '?'}ref=${encodeURIComponent(receiptRef)}`
  const providerImpl = getProvider(provider)
  const webhookUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/payments-webhook`
  const created = await providerImpl.createPayment({
    reference: receiptRef, amount: money(amount), currency: 'MYR',
    email: patientEmail, name: patient?.full_name || undefined,
    purpose: itemTitle, redirectUrl, webhookUrl,
  })

  await admin.from('psy_payments')
    .update({ gateway_ref: created.gatewayRef, checkout_url: created.checkoutUrl })
    .eq('receipt_ref', receiptRef)

  return { checkoutUrl: created.checkoutUrl, receiptRef, amount }
}
