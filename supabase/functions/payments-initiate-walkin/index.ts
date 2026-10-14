// ============================================================
// Edge Function: payments-initiate-walkin
// LAPISAN 2 (Orkestra) — staff jana pautan HitPay utk JUALAN WALK-IN
// (pembeli BUKAN pesakit, cth datang terus ke HQ atau order jauh).
// Berasingan drpd payments-initiate (yang penuh logik self-checkout
// pesakit — voucher/promo/KOB/pakej) supaya laluan ni kekal ringkas &
// tak sentuh/risiko laluan bayaran pesakit sedia ada.
//
// Caller MESTI staff (bukan pesakit). harga/kuantiti DIPERCAYAI dari
// client — staff yang taip sendiri, sama tahap amanah dgn borang manual
// jualan-walkin.html (bukan self-checkout awam macam payments-initiate,
// jadi tiada insentif tamper). Produk itu SENDIRI disahkan wujud & boleh
// dijual (pautan Inventori aktif) supaya fulfillment nanti (tolak stok)
// pasti jumpa item yang betul.
//
// Aliran:
//   roles/staff/jualan-walkin.html (staff pilih produk+harga, klik
//   "Jana Link Bayaran")
//   → sahkan caller = staff
//   → sahkan setiap produk wujud & boleh dijual
//   → cipta psy_payments pending (patient_id NULL, buyer_name/phone,
//     intent.items=[{type:'walkin_sale', items, amount, buyerName,...}])
//   → panggil adapter gateway (HitPay) → checkoutUrl
//   → staff kongsi checkoutUrl (link/QR) dgn pembeli
//
// Fulfillment (tolak stok Inventori) berlaku di payments-webhook
// SELEPAS gateway sahkan bayaran — lihat item.type==='walkin_sale'
// dalam fulfillOrder() + deductWalkinStock().
//
// Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
//          PAYMENT_PROVIDER, HITPAY_API_KEY, HITPAY_MODE
// verify-JWT: ON (default) — staff mesti log masuk.
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

    // 2. Baca niat bayaran dari client
    const body = await req.json().catch(() => ({}))
    const items = Array.isArray(body.items) ? body.items : []
    const buyerName: string | null = body.buyerName ? String(body.buyerName).trim() : null
    const buyerPhone: string | null = body.buyerPhone ? String(body.buyerPhone).trim() : null
    const noteInput: string | null = body.notes ? String(body.notes).trim() : null
    const returnUrl: string = String(body.returnUrl || '')
    if (!items.length) return json({ error: 'Tiada produk untuk dibayar' }, 400)
    if (!returnUrl) return json({ error: 'returnUrl diperlukan' }, 400)

    // 3. Sahkan setiap produk wujud & boleh dijual (pautan Inventori aktif) —
    //    harga/kuantiti dipercayai dari staff, tapi produk sendiri mesti sah
    //    supaya deductWalkinStock() di payments-webhook pasti jumpa item betul.
    const productIds = items.map((it: any) => it.productId).filter(Boolean)
    if (!productIds.length) return json({ error: 'Produk tidak sah' }, 400)
    const { data: prods } = await admin.from('psy_products')
      .select('id, product_id, name, inventory_item_id, psy_inventory_items(status, is_active)')
      .in('id', productIds)
    const prodById = new Map((prods || []).map((p: any) => [p.id, p]))

    const lines: any[] = []
    let total = 0
    for (const it of items) {
      const prod = prodById.get(it.productId)
      if (!prod) return json({ error: `Produk tidak dijumpai: ${it.name || it.productId}` }, 400)
      if (!prod.inventory_item_id) return json({ error: `"${prod.name}" tidak boleh dijual (tiada pautan Inventori)` }, 400)
      const inv = prod.psy_inventory_items
      if (!inv || inv.is_active === false || (inv.status && inv.status !== 'active')) {
        return json({ error: `"${prod.name}" tidak lagi tersedia` }, 400)
      }
      const qty = Math.max(0, Number(it.qty) || 0)
      const price = Math.max(0, Number(it.price) || 0)
      if (!qty) return json({ error: `Kuantiti tidak sah utk "${prod.name}"` }, 400)
      total += price * qty
      lines.push({ id: prod.id, product_id: prod.product_id, name: prod.name, price, qty, subtotal: price * qty })
    }
    if (!(total > 0)) return json({ error: 'Jumlah bayaran tidak sah' }, 400)

    // 4. Cipta baris PENDING + simpan intent (fulfillment oleh payments-webhook)
    const receiptRef = 'WALKIN-' + Date.now().toString(36).toUpperCase() +
      '-' + Math.floor(performance.now()).toString(36).toUpperCase()
    const provider = activeProviderName()
    const fullNotes = `Jualan Walk-in${buyerName ? ' — ' + buyerName : ''}${noteInput ? ' · ' + noteInput : ''}`

    const { error: insErr } = await admin.from('psy_payments').insert({
      receipt_ref: receiptRef,
      patient_id: null,
      buyer_name: buyerName,
      buyer_phone: buyerPhone,
      items: lines,
      subtotal: total,
      total,
      payment_method: 'gateway',
      status: 'pending',
      paid_for_type: 'product',
      gateway_provider: provider,
      gateway_status: 'pending',
      recorded_by: user.id,
      notes: fullNotes,
      intent: {
        items: [{ type: 'walkin_sale', items: lines, amount: total, buyerName, buyerPhone }],
        buyerName, buyerPhone, initiatedBy: 'staff', recordedBy: user.id,
      },
    })
    if (insErr) throw new Error('Gagal simpan bayaran pending: ' + insErr.message)

    // 5. Panggil gateway (adapter) → URL checkout
    const webhookUrl = `${SUPABASE_URL}/functions/v1/payments-webhook`
    const redirectUrl = `${returnUrl}${returnUrl.includes('?') ? '&' : '?'}ref=${encodeURIComponent(receiptRef)}`

    const created = await getProvider(provider).createPayment({
      reference: receiptRef,
      amount: money(total),
      currency: 'MYR',
      name: buyerName || undefined,
      purpose: `ISW Walk-in · ${items.length} item`,
      redirectUrl,
      webhookUrl,
    })

    // 6. Simpan gateway_ref + checkout_url (staff boleh salin semula pautan
    //    dari Payment Management kalau pembeli tak sempat bayar lagi)
    await admin.from('psy_payments')
      .update({ gateway_ref: created.gatewayRef, checkout_url: created.checkoutUrl })
      .eq('receipt_ref', receiptRef)

    return json({ ok: true, checkoutUrl: created.checkoutUrl, receiptRef })
  } catch (err) {
    return json({ error: (err as Error).message || 'Ralat tidak diketahui' }, 500)
  }
})
