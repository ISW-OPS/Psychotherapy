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
import { buildInvoicePdf } from '../_shared/invoice_pdf.ts'

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
    const seq = body.seq === undefined || body.seq === null ? null : Number(body.seq)
    const payUrl: string | null = body.payUrl ? String(body.payUrl) : null
    const amountOverride = body.amount != null ? Number(body.amount) : null

    // 2. Data sesi + checkpoint + bayaran
    const { data: ks } = await admin.from('psy_kob_sessions')
      .select('patient_id, recommended_package_name, recommended_package_price, package_discount, package_payment_mode, recommended_at, created_at, invoice_no')
      .eq('id', kobSessionId).limit(1)
    const kob = ks?.[0]
    if (!kob) return json({ error: 'Sesi KOB tidak dijumpai' }, 404)

    const [{ data: cps }, { data: pays }, { data: pts }] = await Promise.all([
      admin.from('psy_kob_installment_checkpoints').select('seq, due_date, target_cumulative').eq('kob_session_id', kobSessionId).order('seq'),
      admin.from('psy_payments').select('total').eq('status', 'completed').eq('intent->>kob_session_id', kobSessionId),
      admin.from('psy_patients').select('full_name, phone, user_id').eq('id', kob.patient_id).limit(1),
    ])
    let name: string | null = pts?.[0]?.full_name || null
    let phone: string | null = pts?.[0]?.phone || null
    if ((!name || !phone) && pts?.[0]?.user_id) {
      const { data: prof } = await admin.from('psy_profiles').select('full_name, phone').eq('id', pts[0].user_id).limit(1)
      name = name || prof?.[0]?.full_name || null
      phone = phone || prof?.[0]?.phone || null
    }

    const price = Number(kob.recommended_package_price || 0)
    const discount = Number(kob.package_discount || 0)
    const list = cps || []
    const isInstallment = kob.package_payment_mode === 'installment' && list.length > 0
    const owed = isInstallment ? Number(list[list.length - 1].target_cumulative) : price
    const paidTotal = (pays || []).reduce((a: number, p: any) => a + Number(p.total || 0), 0)
    const issue = kob.recommended_at || kob.created_at || new Date().toISOString()

    let invoiceNo = kob.invoice_no || 'INV'
    let dueDate: string = issue
    let amountDue: number
    let dueLabel: string | null = null
    let listPrice = owed + discount

    const cp = seq != null ? list.find((c: any) => Number(c.seq) === seq) : null
    if (cp) {
      // Invois Ansuran — satu checkpoint sahaja
      const idx = list.findIndex((c: any) => Number(c.seq) === seq)
      const prevTarget = idx > 0 ? Number(list[idx - 1].target_cumulative) : 0
      const amount = Number(cp.target_cumulative) - prevTarget
      const paidThis = Math.min(amount, Math.max(0, paidTotal - prevTarget))
      amountDue = Math.max(0, amount - paidThis)
      dueDate = cp.due_date
      invoiceNo = `${invoiceNo}-${idx + 1}`
      dueLabel = `${seq === 0 ? 'Deposit' : `Installment ${seq}`} - ${idx + 1} of ${list.length}`
    } else if (amountOverride != null && amountOverride > 0) {
      // Jadual belum wujud (cth deposit) — guna amaun yang dijana server oleh payments-kob-initiate
      amountDue = amountOverride
      dueLabel = seq === 0 ? 'Deposit' : null
      if (seq === 0) invoiceNo = `${invoiceNo}-1`
    } else {
      // Bayaran penuh
      amountDue = Math.max(0, owed - paidTotal)
      listPrice = price + discount
    }

    // 3. Jana PDF + upload → signed URL (7 hari)
    const bytes = await buildInvoicePdf({
      invoiceNo, issueDate: issue, dueDate,
      patientName: name, phone,
      itemName: kob.recommended_package_name || 'Package',
      listPrice, discount, amountDue, dueLabel, payUrl,
    })
    const bucket = 'receipts'
    await admin.storage.createBucket(bucket, { public: false }).catch(() => {})
    const path = `invoices/${invoiceNo}_${Date.now()}.pdf`
    const { error: upErr } = await admin.storage.from(bucket).upload(path, bytes, { contentType: 'application/pdf', upsert: true })
    if (upErr) throw upErr
    const { data: signed, error: sgErr } = await admin.storage.from(bucket).createSignedUrl(path, 7 * 24 * 3600)
    if (sgErr || !signed?.signedUrl) throw (sgErr || new Error('signed URL kosong'))

    return json({ ok: true, url: signed.signedUrl, invoiceNo })
  } catch (err) {
    return json({ error: (err as Error).message || 'Ralat tidak diketahui' }, 500)
  }
})
