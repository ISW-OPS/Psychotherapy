// ============================================================
// _shared/payments/hitpay.ts
// Adapter HitPay — SATU-SATUNYA fail yang tahu pasal HitPay.
// Menterjemah kontrak neutral (types.ts) ↔ API HitPay.
//
// Untuk tukar ke Fiuu nanti: tulis fiuu.ts yang sama bentuk,
// daftar dalam index.ts. Fail ini & kod lain tak sentuh.
//
// Secrets (set di Supabase Edge Function):
//   HITPAY_API_KEY   — X-BUSINESS-API-KEY
//   HITPAY_SALT      — rahsia untuk sahkan HMAC webhook
//   HITPAY_MODE      — 'sandbox' (default) | 'live'
// ============================================================
import type {
  CardAuthIntent, CardAuthResult, ChargeResult, CreatedPayment, PaymentIntent,
  PaymentProvider, PaymentStatus, RecurringWebhookResult, WebhookResult,
} from './types.ts'

const BASE = () =>
  (Deno.env.get('HITPAY_MODE') || 'sandbox') === 'live'
    ? 'https://api.hit-pay.com/v1'
    : 'https://api.sandbox.hit-pay.com/v1'

// HMAC-SHA256 (hex) guna Web Crypto — tersedia dalam Deno.
async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  )
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message))
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

// Bandingan tetap-masa untuk elak timing attack.
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return diff === 0
}

function normalizeStatus(s: string): PaymentStatus {
  const v = (s || '').toLowerCase()
  if (v === 'completed' || v === 'succeeded' || v === 'paid') return 'completed'
  if (v === 'failed' || v === 'cancelled' || v === 'canceled' || v === 'expired') return 'failed'
  if (v === 'pending') return 'pending'
  return 'unknown'
}

export const hitpay: PaymentProvider = {
  name: 'hitpay',

  // Cipta payment request → pulang URL checkout untuk redirect pesakit.
  async createPayment(intent: PaymentIntent): Promise<CreatedPayment> {
    const apiKey = Deno.env.get('HITPAY_API_KEY')
    if (!apiKey) throw new Error('HITPAY_API_KEY tidak diset')

    const body = new URLSearchParams({
      amount: intent.amount,
      currency: intent.currency || 'MYR',
      reference_number: intent.reference,
      redirect_url: intent.redirectUrl,
      webhook: intent.webhookUrl,
      ...(intent.email ? { email: intent.email } : {}),
      ...(intent.name ? { name: intent.name } : {}),
      ...(intent.purpose ? { purpose: intent.purpose } : {}),
    })

    const res = await fetch(`${BASE()}/payment-requests`, {
      method: 'POST',
      headers: {
        'X-BUSINESS-API-KEY': apiKey,
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body,
    })
    const text = await res.text()
    let data: any = null
    try { data = text ? JSON.parse(text) : null } catch { data = text }
    if (!res.ok) throw new Error(`HitPay create ${res.status}: ${typeof data === 'string' ? data : JSON.stringify(data)}`)

    if (!data?.url || !data?.id) throw new Error('HitPay: respons tiada url/id')
    return { gatewayRef: String(data.id), checkoutUrl: String(data.url), raw: data }
  },

  // Sahkan webhook HitPay (form-encoded + medan hmac).
  async verifyWebhook(req: Request): Promise<WebhookResult> {
    const salt = Deno.env.get('HITPAY_SALT')
    if (!salt) throw new Error('HITPAY_SALT tidak diset')

    const form = await req.formData()
    const fields: Record<string, string> = {}
    for (const [k, v] of form.entries()) fields[k] = String(v)

    const providedHmac = fields.hmac || ''
    delete fields.hmac

    // HitPay: susun kunci ikut abjad, cantum key+value, HMAC-SHA256 guna salt.
    const message = Object.keys(fields).sort().map((k) => `${k}${fields[k]}`).join('')
    const expected = await hmacHex(salt, message)
    const ok = safeEqual(expected, providedHmac.toLowerCase())

    return {
      ok,
      reference: fields.reference_number || '',
      gatewayRef: fields.payment_request_id || fields.payment_id || '',
      status: normalizeStatus(fields.status || ''),
      amount: fields.amount,
      raw: fields,
    }
  },

  // Channel sebenar (fpx/card/paynow_online/dll) — webhook form-encoded lama
  // (verifyWebhook di atas) TAK bawa medan ni, cuma status/amount/reference.
  // Panggilan BERASINGAN ke GET /payment-requests/{id} (respons JSON penuh,
  // ada array `payments[]`, setiap satu ada `payment_type`). Dipanggil SELEPAS
  // webhook disahkan — best-effort, kegagalan di sini TAK patut gagalkan
  // fulfillment bayaran (lihat pemanggil, payments-webhook/index.ts).
  async getPaymentChannel(gatewayRef: string): Promise<{ channel: string | null; raw: unknown }> {
    const apiKey = Deno.env.get('HITPAY_API_KEY')
    if (!apiKey || !gatewayRef) return { channel: null, raw: null }

    const res = await fetch(`${BASE()}/payment-requests/${encodeURIComponent(gatewayRef)}`, {
      method: 'GET',
      headers: { 'X-BUSINESS-API-KEY': apiKey, 'X-Requested-With': 'XMLHttpRequest' },
    })
    if (!res.ok) return { channel: null, raw: { status: res.status } }

    const data = await res.json().catch(() => null)
    const payments: any[] = Array.isArray(data?.payments) ? data.payments : []
    // Pilih bayaran yang berjaya kalau ada lebih dari satu cubaan (retry pesakit) —
    // fallback ke yang pertama kalau tiada status 'succeeded' ditemui.
    const chosen = payments.find((p) => String(p?.status || '').toLowerCase() === 'succeeded') || payments[0]
    return { channel: chosen?.payment_type ? String(chosen.payment_type) : null, raw: data }
  },

  // Cipta sesi "lampir kad" (recurring-billing, save_payment_method=true) —
  // pesakit isi kad SEKALI di hosted page HitPay, tiada cycle/subscription
  // (kita caj ON-DEMAND kemudian ikut checkpoint, bukan HitPay punya jadual).
  // amount BOLEH jumlah SEBENAR (cth deposit ansuran, guna dari kob_retry_link.ts
  // bila HITPAY_INSTALLMENT_SAVE_CARD=true) — lampir kad berlaku SERENTAK dgn
  // bayaran sebenar, bukan sesi RM1 berasingan. Untuk sesi lampir-kad BERDIRI
  // SENDIRI (kob_autocharge.ts createKobCardAttachLink), amount='1.00' (had
  // minimum API HitPay bila tiada bayaran sebenar utk "tumpang").
  async createCardAuthorization(intent: CardAuthIntent): Promise<CardAuthResult> {
    const apiKey = Deno.env.get('HITPAY_API_KEY')
    if (!apiKey) throw new Error('HITPAY_API_KEY tidak diset')

    const body = new URLSearchParams({
      name: intent.purpose || 'Pengesahan Kad — Ansuran Automatik ISW',
      amount: intent.amount,
      currency: intent.currency || 'MYR',
      reference: intent.reference,
      redirect_url: intent.redirectUrl,
      save_payment_method: 'true',
      ...(intent.customerEmail ? { customer_email: intent.customerEmail } : {}),
      ...(intent.customerName ? { customer_name: intent.customerName } : {}),
    })
    for (const m of (intent.paymentMethods?.length ? intent.paymentMethods : ['card'])) {
      body.append('payment_methods[]', m)
    }

    const res = await fetch(`${BASE()}/recurring-billing`, {
      method: 'POST',
      headers: {
        'X-BUSINESS-API-KEY': apiKey,
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body,
    })
    const text = await res.text()
    let data: any = null
    try { data = text ? JSON.parse(text) : null } catch { data = text }
    if (!res.ok) throw new Error(`HitPay recurring-billing ${res.status}: ${typeof data === 'string' ? data : JSON.stringify(data)}`)
    if (!data?.url || !data?.id) throw new Error('HitPay: respons recurring-billing tiada url/id')

    return { authRef: String(data.id), checkoutUrl: String(data.url), raw: data }
  },

  // Caj ON-DEMAND kad tersimpan (bukan cycle automatik HitPay) — respons
  // SEGERA (bukan redirect+webhook macam createPayment), jadi pemanggil
  // (cron event-reminders) boleh fulfill terus dari status respons ini.
  async chargeSavedCard(authRef: string, amount: string, currency: string): Promise<ChargeResult> {
    const apiKey = Deno.env.get('HITPAY_API_KEY')
    if (!apiKey) throw new Error('HITPAY_API_KEY tidak diset')

    const body = new URLSearchParams({ amount, currency: currency || 'MYR' })
    const res = await fetch(`${BASE()}/charge/recurring-billing/${encodeURIComponent(authRef)}`, {
      method: 'POST',
      headers: {
        'X-BUSINESS-API-KEY': apiKey,
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body,
    })
    const text = await res.text()
    let data: any = null
    try { data = text ? JSON.parse(text) : null } catch { data = text }
    if (!res.ok) {
      return { ok: false, chargeRef: '', status: 'failed', raw: data ?? text }
    }
    const status = normalizeStatus(data?.status || '')
    return { ok: status === 'completed', chargeRef: String(data?.payment_id || ''), status, raw: data }
  },

  // Sahkan webhook JSON "recurring billing" (Hitpay-Signature = HMAC-SHA256
  // guna salt atas RAW body JSON) — bentuk BEZA drpd verifyWebhook() atas
  // (form-encoded + medan `hmac`, khusus payment-requests biasa).
  async verifyRecurringWebhook(req: Request): Promise<RecurringWebhookResult> {
    const salt = Deno.env.get('HITPAY_SALT')
    if (!salt) throw new Error('HITPAY_SALT tidak diset')

    const raw = await req.text()
    const providedSig = req.headers.get('Hitpay-Signature') || ''
    const expected = await hmacHex(salt, raw)
    const ok = safeEqual(expected, providedSig.toLowerCase())

    let data: any = {}
    try { data = raw ? JSON.parse(raw) : {} } catch { data = {} }

    const eventTypeHeader = req.headers.get('Hitpay-Event-Type') || ''
    const objectType = data?.object || data?.type || eventTypeHeader
    let eventType: RecurringWebhookResult['eventType'] = 'unknown'
    if (String(objectType).includes('method_attached')) eventType = 'method_attached'
    else if (String(objectType).includes('method_detached')) eventType = 'method_detached'
    else if (String(objectType).includes('subscription_updated')) eventType = 'subscription_updated'
    else if (String(objectType).includes('charge')) eventType = 'charge_created'

    const authRef = String(data?.recurring_billing_id || data?.id || data?.data?.id || '')
    const reference = data?.reference || data?.data?.reference ? String(data.reference || data.data.reference) : undefined
    const card = data?.payment_method?.card || data?.card || {}

    return {
      ok,
      eventType,
      authRef,
      reference,
      status: data?.status ? String(data.status) : undefined,
      cardLast4: card?.last4 ? String(card.last4) : undefined,
      cardBrand: card?.brand ? String(card.brand) : undefined,
      raw: data,
    }
  },
}
