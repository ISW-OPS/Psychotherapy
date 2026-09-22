// ============================================================
// Edge Function: payments-kob-initiate
// LAPISAN 2 (Orkestra) — staff jana pautan HitPay untuk pakej KOB
// (deposit ansuran ATAU bayaran penuh), dihantar terus ke WhatsApp
// pesakit. Beza dengan payments-initiate: caller BIASANYA STAFF (bukan
// pesakit), jadi amount TIDAK PERNAH datang dari client — semua
// diderive server-side dari psy_kob_sessions + psy_packages supaya
// tiada permukaan untuk usik amount.
//
// PENGECUALIAN — pesakit sendiri dibenarkan panggil fungsi ni TERUS
// (self-checkout dalam app, bukan lalui link WhatsApp), tapi HANYA
// mode='installment', HANYA utk psy_kob_sessions milik dia sendiri, DAN
// HANYA bila staff dah tetapkan intended_payment_mode='installment' utk
// sesi tu (wizSelectPlan() di kob-detail.html) — supaya pesakit tak boleh
// checkout ansuran utk pakej yang staff tak set sbg installment. mode
// 'full' (checkout patient sedia ada guna payments-initiate/kob_package),
// 'manual_installment' & 'topup' KEKAL staff-only. Lihat renderRecommendedPackageDetail()
// & payInstallmentDeposit() di roles/patient/kob.html.
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
// verify-JWT: ON (default) — pemanggil (staff ATAU pesakit) mesti log masuk.
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createKobInstallmentTopupLink } from '../_shared/kob_topup.ts'
import { createKobDepositLink } from '../_shared/kob_retry_link.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'POST sahaja' }, 405)

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // 1. Sahkan caller = staff ATAU pesakit pemilik sesi (pattern sama ghl-inbox utk staff)
    const authHeader = req.headers.get('Authorization') || ''
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Tidak dibenarkan (sila log masuk)' }, 401)
    const { data: profile } = await userClient.from('psy_profiles').select('role').eq('id', user.id).single()
    const isStaff = profile?.role === 'staff'

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

    if (!isStaff) {
      // Pesakit self-checkout — sempit: installment sahaja, sesi kena milik dia
      // sendiri, DAN staff kena dah pilih plan installment utk sesi ni dulu.
      if (mode !== 'installment') return json({ error: 'forbidden — staff sahaja' }, 403)
      const { data: kobRows } = await admin.from('psy_kob_sessions')
        .select('patient_id, intended_payment_mode').eq('id', kobSessionId).limit(1)
      const kobRow = kobRows?.[0]
      if (!kobRow) return json({ error: 'Sesi KOB tidak dijumpai' }, 404)
      if (kobRow.intended_payment_mode !== 'installment') return json({ error: 'forbidden — staff belum tetapkan plan installment' }, 403)
      const { data: ptRows } = await admin.from('psy_patients').select('user_id').eq('id', kobRow.patient_id).limit(1)
      if (ptRows?.[0]?.user_id !== user.id) return json({ error: 'forbidden — bukan sesi anda' }, 403)
    }

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

    // 3-7. Sahkan sesi + derive amount + cipta pending + jana checkoutUrl — logik
    // dikongsi dgn payments-webhook (auto-retry bila gagal), lihat kob_retry_link.ts.
    // Tier: staff pilih terus di kob-detail.html (Langkah 3) ATAU pesakit self-checkout
    // hantar 'today' tetap (payInstallmentDeposit di kob.html) — 'now' cuma lebih
    // MAHAL drpd 'today' (tiada insentif tamper), jadi selamat diterima dari client
    // kedua-dua kes. Default ikut status kalau body.tier tak dihantar/tak sah.
    const requestedTier = body.tier === 'today' || body.tier === 'now' ? body.tier : undefined
    try {
      const link = await createKobDepositLink(admin, {
        kobSessionId, mode: mode as 'full' | 'installment' | 'manual_installment',
        tier: requestedTier, returnUrl,
      })
      return json({ ok: true, checkoutUrl: link.checkoutUrl, receiptRef: link.receiptRef, amount: link.amount })
    } catch (err) {
      return json({ error: (err as Error).message || 'Ralat tidak diketahui' }, 400)
    }
  } catch (err) {
    return json({ error: (err as Error).message || 'Ralat tidak diketahui' }, 500)
  }
})
