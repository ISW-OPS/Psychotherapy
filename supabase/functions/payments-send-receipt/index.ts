// ============================================================
// Edge Function: payments-send-receipt
// LAPISAN 2 (Orkestra) — staff cetus resit PDF rasmi + WA utk bayaran
// yang direkod MANUAL (patient-hub.html tab Bayaran → "Rekod Bayaran
// Baru"). Laluan gateway (HitPay) sudah auto-hantar resit ni sendiri
// dalam payments-webhook selepas fulfillment — fungsi ni sekadar
// "trigger manual" bagi laluan bukan-gateway supaya kedua-dua laluan
// hantar resit RASMI (PDF ISW) yang sama, bukan cuma fail bukti yang
// staff upload.
//
// Aliran: patient-hub.html saveBayaranPayment() → insert psy_payments
// (payment_method:'manual') → panggil fungsi ni dgn {paymentId} → guna
// sendPaymentReceiptWhatsApp() SAMA yang dipakai payments-webhook.
//
// Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
//          GHL_ISW_TOKEN, GHL_ISW_LOCATION_ID
// verify-JWT: ON (default) — staff mesti log masuk.
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { sendPaymentReceiptWhatsApp } from '../_shared/receipt_pdf.ts'

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

    // 1. Sahkan caller = staff (pattern sama payments-kob-initiate)
    const authHeader = req.headers.get('Authorization') || ''
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Tidak dibenarkan (sila log masuk)' }, 401)
    const { data: profile } = await userClient.from('psy_profiles').select('role').eq('id', user.id).single()
    if (profile?.role !== 'staff') return json({ error: 'forbidden — staff sahaja' }, 403)

    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } })

    // 2. Baca payment
    const body = await req.json().catch(() => ({}))
    const paymentId = String(body.paymentId || '')
    if (!paymentId) return json({ error: 'paymentId diperlukan' }, 400)

    const { data: payRows } = await admin.from('psy_payments').select('*').eq('id', paymentId).limit(1)
    const payment = payRows?.[0]
    if (!payment) return json({ error: 'Rekod bayaran tidak dijumpai' }, 404)

    // 3. Jana + hantar resit rasmi (sama fungsi dgn laluan gateway)
    await sendPaymentReceiptWhatsApp(admin, payment)

    return json({ ok: true })
  } catch (err) {
    return json({ error: (err as Error).message || 'Ralat tidak diketahui' }, 500)
  }
})
