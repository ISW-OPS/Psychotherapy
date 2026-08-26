// ============================================================
// Edge Function: payments-kob-initiate
// LAPISAN 2 (Orkestra) — staff jana pautan HitPay untuk pakej KOB
// (deposit ansuran ATAU bayaran penuh), dihantar terus ke WhatsApp
// pesakit. Beza dengan payments-initiate: caller ialah STAFF (bukan
// pesakit), jadi amount TIDAK PERNAH datang dari client — semua
// diderive server-side dari psy_kob_sessions + psy_packages supaya
// tiada permukaan untuk usik amount.
//
// Aliran:
//   kob-detail.html (staff, pilih Full/Ansuran)
//   → sahkan caller = staff
//   → sahkan sesi KOB & pakej cadangan, derive amount (deposit/penuh)
//   → cipta psy_payments pending (intent.kob_session_id di ROOT —
//     wajib supaya sejarah/jumlah terkumpul ansuran di kob-detail.html
//     & patient-hub.html [.eq('intent->>kob_session_id', ...)] jumpa
//     rekod ni sama macam bayaran manual)
//   → panggil adapter gateway (HitPay) → checkoutUrl
//   → staff hantar checkoutUrl via WhatsApp (ghl-inbox 'send')
//
// Fulfillment (cipta checkpoint ansuran / tanda pakej paid) berlaku
// di payments-webhook SELEPAS gateway sahkan bayaran — sama macam
// laluan payments-initiate biasa.
//
// Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
//          PAYMENT_PROVIDER, HITPAY_API_KEY, HITPAY_MODE
// verify-JWT: ON (default) — staff mesti log masuk.
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { activeProviderName, getProvider } from '../_shared/payments/index.ts'
import { createKobInstallmentTopupLink } from '../_shared/kob_topup.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

const money = (n: number) => (Math.round(n * 100) / 100).toFixed(2)
const isUuid = (s: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'POST sahaja' }, 405)

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // 1. Sahkan caller = staff (pattern sama ghl-inbox)
    const authHeader = req.headers.get('Authorization') || ''
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Tidak dibenarkan (sila log masuk)' }, 401)
    const { data: profile } = await userClient.from('psy_profiles').select('role').eq('id', user.id).single()
    if (profile?.role !== 'staff') return json({ error: 'forbidden — staff sahaja' }, 403)

    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } })

    // 2. Baca niat: sesi KOB + mod bayaran
    const body = await req.json().catch(() => ({}))
    const kobSessionId: string = String(body.kobSessionId || '')
    const mode: string = String(body.mode || '')
    const returnUrl: string = String(body.returnUrl || '')
    if (!kobSessionId) return json({ error: 'kobSessionId diperlukan' }, 400)
    if (mode !== 'full' && mode !== 'installment' && mode !== 'manual_installment' && mode !== 'topup') {
      return json({ error: "mode mesti 'full', 'installment', 'manual_installment' atau 'topup'" }, 400)
    }
    if (!returnUrl) return json({ error: 'returnUrl diperlukan' }, 400)

    // Mod 'topup' — pelan ansuran SEDANG BERJALAN (bukan permulaan), staff jana
    // pautan utk checkpoint SETERUSNYA belum met dari patient-hub.html (tab
    // Bayaran). Amaun diderive sepenuhnya oleh helper — laluan berasingan drpd
    // full/installment/manual_installment di bawah (yang untuk MULAKAN pelan).
    if (mode === 'topup') {
      try {
        const link = await createKobInstallmentTopupLink(admin, kobSessionId, returnUrl)
        return json({ ok: true, checkoutUrl: link.checkoutUrl, receiptRef: link.receiptRef, amount: link.amount })
      } catch (err) {
        return json({ error: (err as Error).message || 'Ralat tidak diketahui' }, 400)
      }
    }

    // 3. Sahkan sesi KOB — amount TIDAK diambil dari client
    const { data: kobRows } = await admin.from('psy_kob_sessions')
      .select('id, patient_id, recommended_package_id, recommended_package_name, recommended_package_price, package_payment_status')
      .eq('id', kobSessionId).limit(1)
    const kob = kobRows?.[0]
    if (!kob) return json({ error: 'Sesi KOB tidak dijumpai' }, 404)
    if (!kob.recommended_package_id) return json({ error: 'Sesi KOB ini tiada pakej dicadangkan' }, 400)
    if (kob.package_payment_status !== 'pending' && kob.package_payment_status !== 'declined') {
      return json({ error: 'Bayaran pakej sesi ini bukan lagi berstatus pending/declined' }, 409)
    }

    // Tier: doktor pilih terus di kob-detail.html (Langkah 3 — kad "Harga Sekarang"/
    // "Harga Hari Ini", bebas klik mana-mana, tak terikat status pending/declined).
    // Dipercayai sbb caller staff (bukan patient) — sahkan di atas (role==='staff').
    // Default ikut status kalau body.tier tak dihantar/tak sah.
    const requestedTier = body.tier === 'today' || body.tier === 'now' ? body.tier : null
    const tier: 'today' | 'now' = requestedTier ?? (kob.package_payment_status === 'pending' ? 'today' : 'now')

    // 4. Derive pkgMeta (harga penuh + installment_*, tier Today + fallback Now) dari psy_packages
    let pkgQ = admin.from('psy_packages')
      .select('price, today_price, installment_allowed, installment_deposit_amount, installment_duration_months, installment_monthly_amount, today_installment_deposit_amount, today_installment_duration_months, today_installment_monthly_amount')
    pkgQ = isUuid(kob.recommended_package_id)
      ? pkgQ.or(`id.eq.${kob.recommended_package_id},package_id.eq.${kob.recommended_package_id}`)
      : pkgQ.eq('package_id', kob.recommended_package_id)
    const { data: pkgRows } = await pkgQ.limit(1)
    const pkgMeta = pkgRows?.[0]

    // Tier 'today' → dibekukan sbg recommended_package_price masa cadangan asal
    // (saveRecommendation() di kob-detail.html); tier 'now' → harga SEMASA dari
    // psy_packages (bukan "dibekukan time-limited" macam Today, boleh berubah).
    const packagePrice = tier === 'today'
      ? Number(kob.recommended_package_price || 0)
      : Number(pkgMeta?.price || 0)
    if (!(packagePrice > 0)) return json({ error: 'Harga pakej tidak sah' }, 400)

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
      if (!installmentAllowed) return json({ error: 'Pakej ini tidak membenarkan ansuran' }, 400)
      amount = Number(tierDepositAmount)
    } else if (mode === 'manual_installment') {
      // Ansuran Manual: staff isi jadual custom (deposit + tiap baris) di kob-detail.html —
      // client TAK PERNAH boleh hantar amount terus (keselamatan bayaran). Jadual tu
      // mesti dah disimpan sbg checkpoint 'pending' dulu (seq=0 = deposit) oleh
      // ensureManualScheduleDraft() SEBELUM panggilan ni — amount diderive dari situ.
      const { data: cpRows } = await admin.from('psy_kob_installment_checkpoints')
        .select('target_cumulative, status').eq('kob_session_id', kobSessionId).eq('seq', 0).limit(1)
      const cp = cpRows?.[0]
      if (!cp || cp.status !== 'pending') {
        return json({ error: 'Jadual Ansuran Manual belum disediakan — lengkapkan Langkah 4 dahulu.' }, 400)
      }
      amount = Number(cp.target_cumulative)
    } else {
      amount = packagePrice
    }

    // 5. Butiran pesakit (untuk checkout HitPay: email/nama)
    const { data: ptRows } = await admin.from('psy_patients')
      .select('user_id, full_name, phone').eq('id', kob.patient_id).limit(1)
    const patient = ptRows?.[0]
    let patientEmail: string | undefined
    if (patient?.user_id) {
      const { data: au } = await admin.auth.admin.getUserById(patient.user_id).catch(() => ({ data: null }))
      patientEmail = au?.user?.email || undefined
    }

    // 6. Cipta baris pending — intent.kob_session_id di ROOT (wajib untuk
    //    query sejarah/jumlah terkumpul sedia ada di kob-detail.html/patient-hub.html)
    const receiptRef = 'RCP-' + Date.now().toString(36).toUpperCase() +
      '-' + Math.floor(performance.now()).toString(36).toUpperCase()
    const provider = activeProviderName()
    const itemTitle = `${mode === 'full' ? 'Bayaran Penuh' : mode === 'manual_installment' ? 'Deposit Ansuran Manual' : 'Deposit Ansuran'} — ${kob.recommended_package_name || ''}`.trim()

    // Gantikan percubaan pending LAMA utk sesi KOB yg sama (cth staff klik "Jana &
    // Hantar Pautan" >1 kali) — elak baris 'pending' berterusan tinggal selama-lamanya
    // dlm Sejarah Pembayaran, mengelirukan jumlah "Menunggu" walaupun bayaran lain dah
    // berjaya (pautan lama tetap valid di HitPay, tapi rekod kita dah tak relevan).
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

    // 7. Panggil gateway (adapter) → URL checkout
    const webhookUrl = `${SUPABASE_URL}/functions/v1/payments-webhook`
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

    return json({ ok: true, checkoutUrl: created.checkoutUrl, receiptRef, amount })
  } catch (err) {
    return json({ error: (err as Error).message || 'Ralat tidak diketahui' }, 500)
  }
})
