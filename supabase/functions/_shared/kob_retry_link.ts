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
  opts: {
    kobSessionId: string; mode: 'full' | 'installment' | 'manual_installment'; tier?: 'today' | 'now'
    returnUrl: string; initiatedBy?: 'staff' | 'patient'
    // Pesakit pilih 'Kad' semasa deposit (bukan FPX/e-wallet/lain) — kad DISIMPAN
    // SERENTAK dgn deposit (lalu recurring-billing, bukan payment-requests biasa),
    // supaya ansuran seterusnya boleh di-auto-caj TANPA sesi "lampir kad" berasingan.
    // Hanya berkesan bila mode==='installment' (checkpoint ansuran wujud); diabaikan
    // senyap utk 'full'/'manual_installment'. Fulfillment lalu payments-webhook-recurring
    // (event method_attached), BUKAN payments-webhook biasa — lihat kob_deposit_fulfill.ts.
    saveCard?: boolean
  },
): Promise<KobDepositLink> {
  const { kobSessionId, mode, returnUrl, initiatedBy = 'staff' } = opts
  const useSaveCard = !!opts.saveCard && mode === 'installment'

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
    .select('user_id, full_name, phone, email').eq('id', kob.patient_id).limit(1)
  const patient = ptRows?.[0]
  // psy_patients.email (diisi masa pendaftaran) ialah sumber utama — auth user
  // email cuma fallback (patient boleh wujud tanpa user_id, atau akaun auth
  // tiada email kalau daftar guna telefon). HitPay recurring-billing WAJIBKAN
  // customer_email (422 kalau kosong), jadi ni bukan cuma "nice to have".
  let patientEmail: string | undefined = patient?.email || undefined
  if (!patientEmail && patient?.user_id) {
    const { data: au } = await admin.auth.admin.getUserById(patient.user_id).catch(() => ({ data: null }))
    patientEmail = au?.user?.email || undefined
  }
  if (useSaveCard && !patientEmail) {
    throw new Error('Pesakit ini tiada alamat emel dalam rekod — wajib untuk simpan kad (auto-caj ansuran). Kemaskini emel pesakit dulu (Pesakit → Kemaskini Pesakit), atau tanggalkan tanda "Simpan kad" dan hantar pautan biasa.')
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
      // Pesakit sendiri boleh cetus laluan ni sekarang (self-checkout installment,
      // payments-kob-initiate) — bukan staff sahaja macam asal. kob-detail.html
      // baca field ni utk elak silap anggap SETIAP pending gateway payment
      // bermaksud "staff dah hantar pautan WhatsApp" (lihat hitpayStateChecked).
      initiated_by: initiatedBy,
    },
  })
  if (insErr) throw new Error('Gagal simpan bayaran pending: ' + insErr.message)

  const redirectUrl = `${returnUrl}${returnUrl.includes('?') ? '&' : '?'}ref=${encodeURIComponent(receiptRef)}`
  const providerImpl = getProvider(provider)

  let gatewayRef: string, checkoutUrl: string
  if (useSaveCard) {
    if (!providerImpl.createCardAuthorization) throw new Error(`Provider "${provider}" tidak sokong simpan kad`)
    // Deposit + lampir kad SERENTAK — SATU sesi HitPay (recurring-billing, kad
    // SAHAJA, amount=deposit SEBENAR, bukan RM1 token). Lihat createKobCardAttachLink
    // (kob_autocharge.ts) utk sesi lampir-kad BERDIRI SENDIRI (amount=1.00).
    const created = await providerImpl.createCardAuthorization({
      reference: receiptRef, amount: money(amount), purpose: itemTitle, currency: 'MYR',
      customerEmail: patientEmail, customerName: patient?.full_name || undefined, redirectUrl,
    })
    gatewayRef = created.authRef
    checkoutUrl = created.checkoutUrl
    // Upsert (bukan insert) — kalau staff jana pautan >1x, rekod lama ditimpa.
    await admin.from('psy_kob_card_authorizations').upsert({
      kob_session_id: kobSessionId, patient_id: kob.patient_id,
      gateway_provider: provider, gateway_auth_ref: gatewayRef, status: 'pending',
    }, { onConflict: 'kob_session_id' })
  } else {
    const webhookUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/payments-webhook`
    const created = await providerImpl.createPayment({
      reference: receiptRef, amount: money(amount), currency: 'MYR',
      email: patientEmail, name: patient?.full_name || undefined,
      purpose: itemTitle, redirectUrl, webhookUrl,
    })
    gatewayRef = created.gatewayRef
    checkoutUrl = created.checkoutUrl
  }

  await admin.from('psy_payments')
    .update({ gateway_ref: gatewayRef, checkout_url: checkoutUrl })
    .eq('receipt_ref', receiptRef)

  return { checkoutUrl, receiptRef, amount, itemTitle }
}
