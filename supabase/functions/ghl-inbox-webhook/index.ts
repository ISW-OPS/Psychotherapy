// ============================================================
// Edge Function: ghl-inbox-webhook
// Fasa +2 — terima webhook GHL bila ada mesej WhatsApp baru,
// simpan ke cache (psy_wa_messages + psy_wa_conversations),
// supaya inbox ISW kemas kini REALTIME + badge unread naik.
//
// PUBLIC (verify-JWT OFF) — GHL panggil tanpa JWT Supabase.
// Dilindungi rahsia: WA_WEBHOOK_SECRET (query ?secret=... atau header x-wa-secret).
//
// Payload minimum dari GHL Workflow (Webhook action) — hantar JSON:
//   { "conversationId": "{{conversation.id}}" }   ← cukup ni sahaja
// (function akan TARIK mesej terkini dari GHL guna conversationId,
//  jadi tak perlu petakan body/media satu-satu dalam GHL.)
//
// Secrets:
//   GHL_ISW_TOKEN, GHL_ISW_LOCATION_ID   — guna semula (sama macam ghl-inbox)
//   WA_WEBHOOK_SECRET                    — rahsia kongsi (set baru)
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY — auto-inject
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-wa-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const GHL_BASE = 'https://services.leadconnectorhq.com'
const GHL_VERSION = '2021-07-28'
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

const digits = (s: any) => String(s || '').replace(/\D/g, '')
const phoneKey = (s: any) => { const d = digits(s); return d.length >= 9 ? d.slice(-9) : '' }
function toE164(raw: any): string | null {
  if (!raw) return null
  let n = String(raw).replace(/[^\d+]/g, '')
  if (n.startsWith('+')) return n
  if (n.startsWith('60')) return '+' + n
  if (n.startsWith('0')) return '+60' + n.slice(1)
  return '+' + n
}
async function ghl(path: string, init: RequestInit = {}) {
  const token = Deno.env.get('GHL_ISW_TOKEN')!
  const res = await fetch(`${GHL_BASE}${path}`, {
    ...init,
    headers: { Authorization: `Bearer ${token}`, Version: GHL_VERSION, 'Content-Type': 'application/json', Accept: 'application/json', ...(init.headers || {}) },
  })
  const text = await res.text()
  let body: any = null
  try { body = text ? JSON.parse(text) : null } catch { body = text }
  if (!res.ok) throw new Error(`GHL ${path} → ${res.status}: ${typeof body === 'string' ? body : JSON.stringify(body)}`)
  return body
}
const pickAtts = (arr: any) => (arr || []).map((a: any) => (typeof a === 'string' ? a : (a?.url || a?.link || a?.fileUrl || ''))).filter(Boolean)
const isMediaPlaceholder = (b: string) => /">?[A-Z]{3,}<"|>[A-Z]{3,}</.test(b || '')
const stripPlaceholder = (b: string) => (b || '').replace(/>[A-Z]{3,}</g, '').trim()

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const u = new URL(req.url)
    const secret = u.searchParams.get('secret') || req.headers.get('x-wa-secret')
    if (secret !== Deno.env.get('WA_WEBHOOK_SECRET')) return json({ error: 'forbidden' }, 403)

    const payload = await req.json().catch(() => ({}))
    const url = Deno.env.get('SUPABASE_URL')!
    const svc = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')!

    // GHL hantar pelbagai bentuk — cari conversationId
    let conversationId = payload.conversationId || payload.conversation_id || payload.conversation?.id
    const contactId = payload.contactId || payload.contact_id || payload.contact?.id
    // Fallback: kalau hanya contactId, cari conversation terkini contact tu
    if (!conversationId && contactId) {
      try {
        const s = await ghl(`/conversations/search?locationId=${locationId}&contactId=${contactId}&limit=1`, { method: 'GET' })
        conversationId = s?.conversations?.[0]?.id
      } catch (_) { /* abaikan */ }
    }
    if (!conversationId) return json({ skipped: 'no conversationId' })

    // 1. Tarik mesej terkini perbualan dari GHL (source of truth)
    const data = await ghl(`/conversations/${conversationId}/messages?limit=30`, { method: 'GET' })
    const raw = data?.messages?.messages || data?.messages || []
    const msgs = raw.map((m: any) => ({
      ghl_message_id: m.id,
      ghl_conversation_id: conversationId,
      direction: m.direction === 'inbound' ? 'inbound' : 'outbound',
      body: m.body || m.message || '',
      msg_type: 'whatsapp',
      attachments: pickAtts(m.attachments),
      created_at: m.dateAdded ? new Date(m.dateAdded).toISOString() : new Date().toISOString(),
    }))
    // enrich media placeholder (ambil URL dari mesej tunggal)
    await Promise.all(msgs.map(async (msg: any) => {
      if (msg.attachments.length || !isMediaPlaceholder(msg.body)) return
      try {
        const d = await ghl(`/conversations/messages/${msg.ghl_message_id}`, { method: 'GET' })
        const mm = d?.message || d
        msg.attachments = pickAtts(mm?.attachments)
        if (msg.attachments.length) msg.body = stripPlaceholder(msg.body)
      } catch (_) { /* abaikan */ }
    }))
    if (msgs.length) await svc.from('psy_wa_messages').upsert(msgs, { onConflict: 'ghl_message_id' })

    // 2. Mesej terbaru → kemas kini perbualan
    msgs.sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
    const newest = msgs[0]

    // 3. Metadata perbualan (nama/phone/contact) — fetch kalau perlu
    let meta: any = {}
    try { meta = await ghl(`/conversations/${conversationId}`, { method: 'GET' }) } catch (_) { /* abaikan */ }
    const conv = meta?.conversation || meta || {}
    const phone = toE164(conv.phone || payload.phone)

    // padan pesakit ikut 9 digit terakhir
    let patient_id: string | null = null
    const key = phoneKey(phone)
    if (key) {
      const { data: profs } = await svc.from('psy_profiles').select('id, phone').or(`phone.ilike.%${key}`)
      const uids = (profs || []).filter((p: any) => phoneKey(p.phone) === key).map((p: any) => p.id)
      const { data: pat1 } = await svc.from('psy_patients').select('id, user_id, phone').or(`phone.ilike.%${key}`)
      const hit = (pat1 || []).find((p: any) => phoneKey(p.phone) === key)
      if (hit) patient_id = hit.id
      else if (uids.length) {
        const { data: pat2 } = await svc.from('psy_patients').select('id').in('user_id', uids).limit(1)
        if (pat2?.[0]) patient_id = pat2[0].id
      }
    }

    // unread: +1 kalau mesej terbaru inbound (kira dari nilai sedia ada)
    const { data: existing } = await svc.from('psy_wa_conversations')
      .select('unread').eq('ghl_conversation_id', conversationId).maybeSingle()
    const prevUnread = existing?.unread || 0
    const bumpUnread = newest?.direction === 'inbound' ? prevUnread + 1 : prevUnread

    await svc.from('psy_wa_conversations').upsert({
      ghl_conversation_id: conversationId,
      ghl_contact_id: conv.contactId || payload.contactId || null,
      contact_name: conv.fullName || conv.contactName || conv.name || payload.contactName || '(tanpa nama)',
      phone_e164: phone,
      last_message: newest?.body || conv.lastMessageBody || '',
      last_message_at: newest?.created_at || new Date().toISOString(),
      unread: bumpUnread,
      patient_id,
      synced_at: new Date().toISOString(),
    }, { onConflict: 'ghl_conversation_id' })

    return json({ success: true, conversationId, messages: msgs.length, unread: bumpUnread })
  } catch (err) {
    console.error('ghl-inbox-webhook error:', err)
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
