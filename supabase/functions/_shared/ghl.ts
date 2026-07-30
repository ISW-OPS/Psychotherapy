// ============================================================
// _shared/ghl.ts — helper hantar WhatsApp via GoHighLevel
// Corak sama seperti reaksi-advice-send / ghl-inbox:
//   contacts/upsert → conversations/messages (type 'SMS' = WhatsApp
//   untuk lokasi klinik ini) → cache psy_wa_messages.
// Secrets diperlukan: GHL_ISW_TOKEN, GHL_ISW_LOCATION_ID
// ============================================================

const GHL_BASE = 'https://services.leadconnectorhq.com'
const GHL_VERSION = '2021-07-28'

// Tukar nombor MY → E.164 (+60). "0123456789" → "+60123456789"
export function toE164(raw: string | null | undefined): string | null {
  if (!raw) return null
  const n = String(raw).replace(/[^\d+]/g, '')
  if (n.startsWith('+')) return n
  if (n.startsWith('60')) return '+' + n
  if (n.startsWith('0')) return '+60' + n.slice(1)
  return '+' + n
}

async function ghl(path: string, init: RequestInit = {}) {
  const token = Deno.env.get('GHL_ISW_TOKEN')!
  const res = await fetch(`${GHL_BASE}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      Version: GHL_VERSION,
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(init.headers || {}),
    },
  })
  const text = await res.text()
  let body: any = null
  try { body = text ? JSON.parse(text) : null } catch { body = text }
  if (!res.ok) {
    throw new Error(`GHL ${path} → ${res.status}: ${typeof body === 'string' ? body : JSON.stringify(body)}`)
  }
  return body
}

// Hantar satu mesej WhatsApp ke nombor pesakit + cache outbound.
// Throw jika gagal — pemanggil putuskan sama ada gagal itu kritikal.
export async function sendWhatsApp(svc: any, opts: {
  phone: string | null | undefined
  name?: string | null
  message: string
  attachments?: string[]      // URL awam/signed — GHL muat turun & hantar sebagai media
  sentByName: string          // label dalam psy_wa_messages, cth 'Auto — Resit Pembayaran'
  sentBy?: string | null      // user_id staf jika ada; null = automatik
}): Promise<string | null> {
  const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')!
  const e164 = toE164(opts.phone)
  if (!e164) throw new Error('tiada nombor telefon')

  const name = (opts.name || '').trim()
  const parts = name.split(/\s+/)
  const upsertBody: any = { locationId, phone: e164 }
  if (name) {
    upsertBody.firstName = parts[0]
    upsertBody.lastName = parts.slice(1).join(' ') || undefined
    upsertBody.name = name
  }
  const r = await ghl('/contacts/upsert', { method: 'POST', body: JSON.stringify(upsertBody) })
  const contactId = (r?.contact || r || {}).id
  if (!contactId) throw new Error('gagal sediakan contact GHL')

  const atts = (opts.attachments || []).filter(Boolean)
  const sendBody: any = { type: 'SMS', contactId, message: opts.message }
  if (atts.length) sendBody.attachments = atts
  const sent = await ghl('/conversations/messages', {
    method: 'POST',
    body: JSON.stringify(sendBody),
  })

  // Cache outbound supaya muncul dalam inbox WhatsApp staf
  const convId = sent?.conversationId || null
  if (convId) {
    const now = new Date().toISOString()
    await svc.from('psy_wa_messages').insert({
      ghl_message_id: sent?.messageId || null,
      ghl_conversation_id: convId,
      direction: 'outbound',
      body: opts.message,
      msg_type: 'whatsapp',
      attachments: atts,
      sent_by: opts.sentBy || null,
      sent_by_name: opts.sentByName,
    }).catch(() => {})
    await svc.from('psy_wa_conversations')
      .update({ last_message: opts.message, last_message_at: now })
      .eq('ghl_conversation_id', convId)
      .catch(() => {})
  }
  return sent?.messageId || null
}
