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

    // 3-7. Sahkan sesi + derive amount + cipta pending + jana checkoutUrl — logik
    // dikongsi dgn payments-webhook (auto-retry bila gagal), lihat kob_retry_link.ts.
    // Tier: doktor pilih terus di kob-detail.html (Langkah 3), dipercayai sbb caller
    // staff (sahkan di atas). Default ikut status kalau body.tier tak dihantar/tak sah.
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
