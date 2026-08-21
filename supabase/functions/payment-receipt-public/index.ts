// ============================================================
// Edge Function: payment-receipt-public
// LAPISAN 2 (Orkestra) — cari status satu bayaran ikut `ref` (receipt_ref)
// TANPA perlukan sesi log masuk pesakit.
//
// Kenapa perlu: pesakit yang doktor cipta terus semasa sesi KOB
// (roles/staff/kob-detail.html → payments-kob-initiate) selalunya BELUM
// ada akaun (user_id psy_patients null) — konsep akaun/app pesakit sendiri
// baharu utk fasa lain. Bayaran HitPay tetap berjaya (payments-webhook
// fulfill server-ke-server, tak perlu sesi pesakit langsung), tapi
// halaman pengesahan (roles/patient/payment-receipt.html) yang HitPay
// redirect balik kena boleh dibuka TANPA login.
//
// psy_payments RLS cuma benarkan baca oleh pemilik (user_id) atau staff —
// jadi fungsi ni guna SERVICE_ROLE untuk baca SATU baris ikut receipt_ref
// (token capaian sekali-guna, bukan senarai/carian). Cuma pulangkan medan
// selamat/minimum utk paparan resit — TIADA data sensitif lain didedahkan.
//
// verify-JWT: OFF (--no-verify-jwt) — pesakit tanpa akaun/sesi buka page ni terus.
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } })

    const body = await req.json().catch(() => ({}))
    const ref = String(body.ref || '').trim()
    if (!ref) return json({ error: 'ref diperlukan' }, 400)

    const { data: rows } = await admin.from('psy_payments')
      .select('status, total, items, paid_at, created_at, patient_id, gateway_provider, payment_method')
      .eq('receipt_ref', ref).limit(1)
    const p = rows?.[0]
    if (!p) return json({ found: false })

    let patientName: string | null = null
    if (p.patient_id) {
      const { data: ptRows } = await admin.from('psy_patients')
        .select('full_name').eq('id', p.patient_id).limit(1)
      patientName = ptRows?.[0]?.full_name || null
    }

    const itemTitle = Array.isArray(p.items) && p.items[0]?.title ? String(p.items[0].title) : null

    // Resit PDF (dijana & disimpan oleh payments-webhook semasa fulfill, path
    // `${receipt_ref}.pdf` dalam bucket 'receipts') — jana semula signed URL
    // bila diminta (bukan simpan URL kekal, sebab signed URL luput). Kalau
    // fail PDF tak wujud (cth fallback teks WA masa tu), pdfUrl kekal null —
    // client sorok butang muat turun senyap-senyap.
    let pdfUrl: string | null = null
    if (p.status === 'completed') {
      const { data: signed } = await admin.storage.from('receipts')
        .createSignedUrl(`${ref}.pdf`, 3600)
      pdfUrl = signed?.signedUrl || null
    }

    return json({
      found: true,
      status: p.status,          // 'pending' | 'completed' | 'failed'
      total: p.total,
      itemTitle,
      patientName,
      paidAt: p.paid_at || p.created_at,
      pdfUrl,
      method: p.gateway_provider || p.payment_method || null,
    })
  } catch (err) {
    return json({ error: (err as Error).message || 'Ralat tidak diketahui' }, 500)
  }
})
