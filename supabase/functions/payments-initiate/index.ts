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
    const promoCode: string | null = body.promoCode ? String(body.promoCode).trim() : null
    const method: string = 'gateway'
    const returnUrl: string = String(body.returnUrl || '')
    if (!items.length) return json({ error: 'Tiada item untuk dibayar' }, 400)
    if (!returnUrl) return json({ error: 'returnUrl diperlukan' }, 400)

    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } })

    // 3. SAHKAN HARGA server-side — jangan percaya amaun dari client.
    //    Pakej & produk disemak semula dari DB; jenis lain guna amaun DB-derived.
    let total = 0
    for (const it of items) {
      total += await verifiedAmount(admin, it, patientId)
    }
    if (!(total > 0)) return json({ error: 'Jumlah bayaran tidak sah' }, 400)

    // 3b. Diskaun ganjaran (psy_vouchers) — cth baucar pendaftaran rujukan.
    //     Terpakai utk MANA-MANA pembelian (bukan terhad pakej pertama sahaja) —
    //     supaya baucar tak "terperap" tak boleh guna kalau pakej pesakit
    //     diaktifkan melalui laluan lain (cth staff Tandakan Selesai KOB terus).
    //     Guna voucher AKTIF terlama (FIFO); ditanda 'used' oleh trigger DB
    //     bila psy_payments jadi 'completed' (lihat 28_rewards.sql).
    let voucherId: string | null = null
    let voucherDiscount = 0
    if (patientId) {
      const { data: voucher } = await admin.from('psy_vouchers')
        .select('id, amount').eq('patient_id', patientId).eq('status', 'active')
        .order('created_at', { ascending: true }).limit(1).maybeSingle()
      if (voucher) {
        voucherId = voucher.id
        voucherDiscount = Math.min(Number(voucher.amount) || 0, total)
        total = Math.max(1, total - voucherDiscount) // elak jumlah RM0 ke gateway
      }
    }

    // 3c. Kod promo (psy_promo_codes) — ditaip manual pesakit di cart kedai.
    //     Sah SEMULA server-side (client cuma preview) — elak race condition /
    //     usikan client. Kod tak sah/luput/habis had diabaikan senyap supaya
    //     checkout tak block (client dah validate dulu, kes ni patut jarang).
    let promoId: string | null = null
    let promoDiscount = 0
    if (promoCode && patientId) {
      const { data: promo } = await admin.from('psy_promo_codes')
        .select('id, discount_type, discount_value, min_subtotal, max_uses, used_count, max_uses_per_patient, valid_from, valid_until, is_active')
        .eq('code', promoCode.toUpperCase()).maybeSingle()
      if (promo && promo.is_active) {
        const today = new Date().toISOString().slice(0, 10)
        const dateOk = (!promo.valid_from || promo.valid_from <= today) && (!promo.valid_until || promo.valid_until >= today)
        const usesOk = promo.max_uses == null || promo.used_count < promo.max_uses
        const minOk = total >= (Number(promo.min_subtotal) || 0)
        let perPatientOk = true
        if (dateOk && usesOk && minOk && promo.max_uses_per_patient != null) {
          const { count } = await admin.from('psy_promo_redemptions')
            .select('id', { count: 'exact', head: true })
            .eq('promo_id', promo.id).eq('patient_id', patientId)
          perPatientOk = (count || 0) < promo.max_uses_per_patient
        }
        if (dateOk && usesOk && minOk && perPatientOk) {
          promoId = promo.id
          promoDiscount = promo.discount_type === 'percent'
            ? total * (Number(promo.discount_value) / 100)
            : Number(promo.discount_value)
          promoDiscount = Math.min(promoDiscount, total)
          total = Math.max(1, total - promoDiscount)
        }
      }
    }

    // 4. Cipta baris PENDING + simpan intent (untuk fulfillment oleh webhook)
    const receiptRef = 'RCP-' + Date.now().toString(36).toUpperCase() +
      '-' + Math.floor(performance.now()).toString(36).toUpperCase()
    const provider = activeProviderName()

    // kob_session_id di ROOT intent — wajib supaya sejarah/jumlah terkumpul ansuran
    // (query .eq('intent->>kob_session_id', ...) di kob-detail.html/patient-hub.html)
    // turut jumpa bayaran gateway ni, sama macam bayaran manual sedia ada.
    const kobSessionIdItem = items.find((i: any) => i.kobSessionId)
    // Gantikan percubaan pending LAMA utk sesi KOB yg sama (cth pesakit klik "Bayar"
    // >1 kali) — elak baris 'pending' berterusan tinggal selama-lamanya dlm Sejarah
    // Pembayaran, mengelirukan jumlah "Menunggu" walaupun bayaran lain dah berjaya.
    if (kobSessionIdItem) {
      await admin.from('psy_payments')
        .update({ status: 'failed', gateway_status: 'superseded', notes: 'Digantikan oleh percubaan bayaran baharu' })
        .eq('patient_id', patientId).eq('status', 'pending')
        .eq('intent->>kob_session_id', kobSessionIdItem.kobSessionId)
    }
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
      intent: {
        items, patientId, userId: user.id, method, voucherId, voucherDiscount, promoCodeId: promoId, promoDiscount,
        ...(kobSessionIdItem ? { kob_session_id: kobSessionIdItem.kobSessionId } : {}),
      },
    })
    if (insErr) throw new Error('Gagal simpan bayaran pending: ' + insErr.message)

    // 5. Panggil gateway (adapter) → URL checkout
    const webhookUrl = `${SUPABASE_URL}/functions/v1/payments-webhook`
    const redirectUrl = `${returnUrl}${returnUrl.includes('?') ? '&' : '?'}ref=${encodeURIComponent(receiptRef)}`

    // Emel/nama untuk checkout HitPay = pesakit yang SEBENARNYA bayar, bukan semestinya
    // pemanggil JWT — staff pun boleh cetus bayaran ni bagi pihak pesakit (cth coach
    // tambah sesi & jana pautan HitPay terus utk dihantar WhatsApp), jadi jangan
    // andaikan user.email ialah emel pesakit.
    let billEmail = user.email || undefined
    let billName = (user.user_metadata as any)?.full_name || undefined
    if (patientId) {
      const { data: pt } = await admin.from('psy_patients').select('email, full_name').eq('id', patientId).maybeSingle()
      if (pt?.email) billEmail = pt.email
      if (pt?.full_name) billName = pt.full_name
    }

    const created = await getProvider(provider).createPayment({
      reference: receiptRef,
      amount: money(total),
      currency: 'MYR',
      email: billEmail,
      name: billName,
      purpose: `ISW · ${items.length} item`,
      redirectUrl,
      webhookUrl,
    })

    // 6. Simpan gateway_ref untuk padan webhook nanti + checkout_url (staff boleh
    //    salin semula pautan ni dari Pembayaran kalau pesakit tak sempat bayar)
    await admin.from('psy_payments')
      .update({ gateway_ref: created.gatewayRef, checkout_url: created.checkoutUrl })
      .eq('receipt_ref', receiptRef)

    return json({ ok: true, checkoutUrl: created.checkoutUrl, receiptRef, voucherDiscount, promoDiscount })
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
async function verifiedAmount(admin: any, it: any, patientId: string | null): Promise<number> {
  const clientAmt = Number(it.amount) || 0

  if (it.type === 'kob_installment_topup') {
    // Ansuran KOB — amaun TETAP ikut checkpoint SETERUSNYA sahaja, bukan client-chosen
    // & bukan jumlah baki keseluruhan digabung. clientAmt diabaikan sepenuhnya di sini —
    // amaun diderive 100% server-side dari jadual checkpoint, sama prinsip macam
    // payments-kob-initiate (amount tak pernah dipercayai dari client).
    if (!it.kobSessionId || !patientId) return 0
    const { data: rows } = await admin.from('psy_kob_sessions')
      .select('patient_id, package_payment_mode, package_payment_status')
      .eq('id', it.kobSessionId).limit(1)
    const kob = rows?.[0]
    if (!kob || kob.patient_id !== patientId) return 0
    if (kob.package_payment_mode !== 'installment' || kob.package_payment_status !== 'partial') return 0
    const { data: paidRows } = await admin.from('psy_payments').select('total')
      .eq('status', 'completed').eq('intent->>kob_session_id', it.kobSessionId)
    const totalPaid = (paidRows || []).reduce((s: number, p: any) => s + Number(p.total || 0), 0)
    const { data: cps } = await admin.from('psy_kob_installment_checkpoints')
      .select('target_cumulative').eq('kob_session_id', it.kobSessionId).order('seq', { ascending: true })
    const nextCp = (cps || []).find((c: any) => Number(c.target_cumulative) > totalPaid + 0.005)
    const trusted = nextCp ? Math.max(0, Number(nextCp.target_cumulative) - totalPaid) : 0
    it.amount = trusted // sync — webhook fulfillment baca item.amount, bukan cuma `total`
    return trusted
  }

  if (it.type === 'kob_package') {
    // Beli pakej dicadangkan KOB (payRecommendedPackage() di kob.html) — tier Today
    // sahaja, DAN hanya bila sesi KOB betul-betul MASIH LIVE: package_payment_status
    // ==='pending' DAN kob.status!=='completed'. Sebelum ni handler ni TIADA
    // sekatan langsung — patient boleh checkout walaupun status 'declined' ATAU
    // sesi dah 'completed' (cth doktor reopen sesi declined & klik "Patient
    // Teruskan" semula utk patient yg KEMBALI — checkout sendiri MESTI tetap
    // ditutup, doktor kena proses terus di kob-detail.html). Fix.
    const key = it.packageId || it.raw?.package_id
    if (!key || !it.kobSessionId) return 0
    const { data: kobRows } = await admin.from('psy_kob_sessions')
      .select('patient_id, package_payment_status, status').eq('id', it.kobSessionId).limit(1)
    const kob = kobRows?.[0]
    if (!kob || kob.patient_id !== patientId) return 0
    if (kob.package_payment_status !== 'pending' || kob.status === 'completed') return 0
    let pkgQ = admin.from('psy_packages').select('price, today_price, is_active')
    pkgQ = isUuid(String(key)) ? pkgQ.or(`id.eq.${key},package_id.eq.${key}`) : pkgQ.eq('package_id', key)
    const { data: pkgRows } = await pkgQ.limit(1)
    const pkg = pkgRows?.[0]
    if (!pkg || pkg.is_active === false) return 0
    const price = Number(pkg.today_price ?? pkg.price)
    if (!(price > 0)) return 0
    it.amount = price
    return price
  }

  if (it.type === 'package') {
    const key = it.packageId || it.raw?.package_id
    if (key) {
      const pkg = await lookupPackage(admin, String(key))
      if (pkg && pkg.is_active !== false && Number.isFinite(Number(pkg.price))) {
        it.amount = Number(pkg.price)
        return Number(pkg.price)
      }
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
