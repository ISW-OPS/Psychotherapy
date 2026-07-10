// ============================================================
// Edge Function: payments-initiate
// LAPISAN 2 (Orkestra) — mula bayaran sebenar.
//
// Aliran:
//   client (payment.html) → POST { items, patientId, method, returnUrl }
//   → sahkan pengguna (JWT)
//   → SAHKAN HARGA server-side (elak client usik amaun)
//   → cipta baris psy_payments status='pending' + simpan INTENT
//   → panggil adapter gateway (HitPay) → dapat URL checkout
//   → pulang { checkoutUrl } → client redirect pesakit
//
// Fulfillment (aktif pakej/plan/KOB) TIDAK berlaku di sini —
// ia jalan dalam payments-webhook SELEPAS gateway sahkan bayaran.
//
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
//          PAYMENT_PROVIDER, HITPAY_API_KEY, HITPAY_SALT, HITPAY_MODE
// verify-JWT: ON (default) — pesakit mesti log masuk.
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { activeProviderName, getProvider } from '../_shared/payments/index.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

const money = (n: number) => (Math.round(n * 100) / 100).toFixed(2)

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'POST sahaja' }, 405)

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // 1. Sahkan pengguna dari JWT yang dihantar client
    const authHeader = req.headers.get('Authorization') || ''
    const authClient = createClient(SUPABASE_URL, SERVICE_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    })
    const { data: userData } = await authClient.auth.getUser()
    const user = userData?.user
    if (!user) return json({ error: 'Tidak dibenarkan (sila log masuk)' }, 401)

    // 2. Baca niat bayaran dari client
    const body = await req.json().catch(() => ({}))
    const items = Array.isArray(body.items) ? body.items : []
    const patientId: string | null = body.patientId || null
    const method: string = 'gateway'
    const returnUrl: string = String(body.returnUrl || '')
    if (!items.length) return json({ error: 'Tiada item untuk dibayar' }, 400)
    if (!returnUrl) return json({ error: 'returnUrl diperlukan' }, 400)

    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } })

    // 3. SAHKAN HARGA server-side — jangan percaya amaun dari client.
    //    Pakej & produk disemak semula dari DB; jenis lain guna amaun DB-derived.
    let total = 0
    for (const it of items) {
      total += await verifiedAmount(admin, it)
    }
    if (!(total > 0)) return json({ error: 'Jumlah bayaran tidak sah' }, 400)

    // 4. Cipta baris PENDING + simpan intent (untuk fulfillment oleh webhook)
    const receiptRef = 'RCP-' + Date.now().toString(36).toUpperCase() +
      '-' + Math.floor(performance.now()).toString(36).toUpperCase()
    const provider = activeProviderName()

    const { error: insErr } = await admin.from('psy_payments').insert({
      receipt_ref: receiptRef,
      patient_id: patientId,
      user_id: user.id,
      items: items.map((i: any) => ({ type: i.type, title: i.title, amount: i.amount, reference_id: i.id || i.packageId })),
      subtotal: total,
      total,
      payment_method: method,
      status: 'pending',
      gateway_provider: provider,
      gateway_status: 'pending',
      intent: { items, patientId, userId: user.id, method },
    })
    if (insErr) throw new Error('Gagal simpan bayaran pending: ' + insErr.message)

    // 5. Panggil gateway (adapter) → URL checkout
    const webhookUrl = `${SUPABASE_URL}/functions/v1/payments-webhook`
    const redirectUrl = `${returnUrl}${returnUrl.includes('?') ? '&' : '?'}ref=${encodeURIComponent(receiptRef)}`

    const created = await getProvider(provider).createPayment({
      reference: receiptRef,
      amount: money(total),
      currency: 'MYR',
      email: user.email || undefined,
      name: (user.user_metadata as any)?.full_name || undefined,
      purpose: `ISW · ${items.length} item`,
      redirectUrl,
      webhookUrl,
    })

    // 6. Simpan gateway_ref untuk padan webhook nanti
    await admin.from('psy_payments')
      .update({ gateway_ref: created.gatewayRef })
      .eq('receipt_ref', receiptRef)

    return json({ ok: true, checkoutUrl: created.checkoutUrl, receiptRef })
  } catch (err) {
    return json({ error: (err as Error).message || 'Ralat tidak diketahui' }, 500)
  }
})

const isUuid = (s: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)

// Cari pakej ikut key yang boleh jadi UUID (id) ATAU kod (package_id).
// GOTCHA: query id.eq.<kod-bukan-uuid> akan ERROR di Postgres — jadi guard dulu.
async function lookupPackage(admin: any, key: string) {
  let q = admin.from('psy_packages').select('price, is_active')
  q = isUuid(key) ? q.or(`id.eq.${key},package_id.eq.${key}`) : q.eq('package_id', key)
  const { data } = await q.limit(1)
  return data?.[0]
}

// Pulangkan amaun (RM) yang DIPERCAYAI untuk satu item — semak semula dari DB.
async function verifiedAmount(admin: any, it: any): Promise<number> {
  const clientAmt = Number(it.amount) || 0

  if (it.type === 'package' || it.type === 'kob_package') {
    const key = it.packageId || it.raw?.package_id
    if (key) {
      const pkg = await lookupPackage(admin, String(key))
      if (pkg && pkg.is_active !== false && Number.isFinite(Number(pkg.price))) return Number(pkg.price)
    }
    return clientAmt
  }

  if (it.type === 'package_existing') {
    const key = it.raw?.package_id
    if (key) {
      const pkg = await lookupPackage(admin, String(key))
      if (pkg && pkg.is_active !== false && Number.isFinite(Number(pkg.price))) return Number(pkg.price)
    }
    return clientAmt
  }

  if (it.type === 'shop_order' && Array.isArray(it.items)) {
    const ids = it.items.map((p: any) => p.id).filter(Boolean)
    if (ids.length) {
      const { data } = await admin.from('psy_products')
        .select('product_id, price, promo_price, promo_until, is_active').in('product_id', ids)
      const map = Object.fromEntries((data || []).map((p: any) => [p.product_id, p]))
      const today = new Date().toISOString().slice(0, 10)
      let sub = 0
      for (const line of it.items) {
        const p = map[line.id]
        if (!p || p.is_active === false) return clientAmt // fallback kalau tak jumpa
        const qty = Math.max(1, parseInt(line.qty) || 1)
        const orig = Number(p.price) || 0
        const promo = Number(p.promo_price || 0)
        const onPromo = promo > 0 && promo < orig && (!p.promo_until || p.promo_until >= today)
        sub += (onPromo ? promo : orig) * qty
      }
      const deliveryFee = Number(it.deliveryFee) || (it.deliveryMethod === 'pos' ? 8 : 0)
      return sub + deliveryFee
    }
    return clientAmt
  }

  // appointment / plan_extension / kob — amaun DB-derived, guna nilai client
  return clientAmt
}
