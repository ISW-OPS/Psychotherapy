// ============================================================
// Edge Function: kob-invoice-pdf
// Jana PDF INVOIS (tuntutan bayaran) untuk satu sesi KOB & pulangkan signed URL —
// dilampirkan bersama pautan HitPay semasa staff tekan "Hantar WA"
// (patient-hub.html sendAnsuranLink · kob-detail.html sendKobHitpayLink).
//
// Body: { kobSessionId, seq?, payUrl?, amount? }
//   seq   = checkpoint ansuran yang dituntut (Invois Ansuran — Amount Due = ansuran itu sahaja)
//   amount= jumlah tuntutan kalau jadual checkpoint belum wujud (cth deposit sebelum draf jadual)
//   tanpa seq & amount = invois bayaran penuh (baki pakej)
// Auth: staff sahaja (verify-JWT ON). Fail disimpan dalam bucket 'receipts' (private), URL 7 hari.
// Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { generateKobInvoiceUrl } from '../_shared/kob_invoice.ts'

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

    // 1. Sahkan caller = staff
    const authHeader = req.headers.get('Authorization') || ''
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Tidak dibenarkan (sila log masuk)' }, 401)
    const { data: profile } = await userClient.from('psy_profiles').select('role').eq('id', user.id).single()
    if (profile?.role !== 'staff') return json({ error: 'forbidden — staff sahaja' }, 403)

    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } })

    const body = await req.json().catch(() => ({}))
    const kobSessionId = String(body.kobSessionId || '')
    if (!kobSessionId) return json({ error: 'kobSessionId diperlukan' }, 400)

    const { url, invoiceNo } = await generateKobInvoiceUrl(admin, {
      kobSessionId,
      seq: body.seq === undefined || body.seq === null ? null : Number(body.seq),
      payUrl: body.payUrl ? String(body.payUrl) : null,
      amount: body.amount != null ? Number(body.amount) : null,
    })
    return json({ ok: true, url, invoiceNo })
  } catch (err) {
    return json({ error: (err as Error).message || 'Ralat tidak diketahui' }, 500)
  }
})
