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
import type { CreatedPayment, PaymentIntent, PaymentProvider, PaymentStatus, WebhookResult } from './types.ts'

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
}
