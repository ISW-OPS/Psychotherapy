// ============================================================
// Edge Function: ghl-inbox
// Fasa 2 — ISW WhatsApp Inbox. Proxy ke GHL Conversations API v2
// supaya coach balas WhatsApp dari ISW tanpa buka GHL.
//
// Satu function, tiga action (body: { action, ... }):
//   action='list'      → senarai 50 perbualan terkini (kedua-dua nombor)
//   action='messages'  → mesej untuk satu perbualan { conversationId }
//   action='send'      → hantar WhatsApp { contactId, message }
//
// Keselamatan: caller WAJIB staff (verify JWT → semak psy_profiles.role).
// Cache ditulis guna service role ke psy_wa_conversations / psy_wa_messages.
//
// Secrets (guna semula dari sync-ghl — JANGAN timpa):
//   GHL_ISW_TOKEN        — Private Integration token (pit-...) ISW
//   GHL_ISW_LOCATION_ID  — Location ID ISW (cVOgqxddpXRzqaIXFkxl)
// Auto-injected oleh Supabase: SUPABASE_URL, SUPABASE_ANON_KEY,
//   SUPABASE_SERVICE_ROLE_KEY
//
// Token GHL perlu scope: conversations.readonly/write +
//   conversations/message.readonly/write
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// cors di-inline (bukan import) supaya fail ni boleh paste terus dalam
// Supabase Dashboard → Edge Functions editor tanpa fail jiran.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const GHL_BASE = 'https://services.leadconnectorhq.com'
const GHL_VERSION = '2021-07-28'

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// Tukar nombor MY → E.164 (+60). "0123456789" → "+60123456789"
function toE164(raw: string | null | undefined): string | null {
  if (!raw) return null
  let n = String(raw).replace(/[^\d+]/g, '')
  if (n.startsWith('+')) return n
  if (n.startsWith('60')) return '+' + n
  if (n.startsWith('0')) return '+60' + n.slice(1)
  return '+' + n
}

// Buang semua bukan-digit
const digits = (s: any) => String(s || '').replace(/\D/g, '')
// Kunci padanan = 9 digit terakhir (stabil merentas +60 / 0 / sengkang)
const phoneKey = (s: any) => { const d = digits(s); return d.length >= 9 ? d.slice(-9) : '' }

// Teka MIME dari sambungan URL (fallback bila header generik)
function mimeFromUrl(u: string): string {
  const ext = (u.split('?')[0].split('.').pop() || '').toLowerCase()
  const map: Record<string, string> = {
    jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp', gif: 'image/gif',
    mp4: 'video/mp4', webm: 'video/webm', mov: 'video/quicktime', '3gp': 'video/3gpp',
    mp3: 'audio/mpeg', ogg: 'audio/ogg', oga: 'audio/ogg', m4a: 'audio/mp4', wav: 'audio/wav', aac: 'audio/aac', amr: 'audio/amr',
    pdf: 'application/pdf',
  }
  return map[ext] || ''
}

// Kenal jenis dari byte pertama fail (magic number) — paling tepat
function mimeFromBytes(b: Uint8Array): string {
  if (b.length < 12) return ''
  if (b[0] === 0xFF && b[1] === 0xD8 && b[2] === 0xFF) return 'image/jpeg'
  if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4E && b[3] === 0x47) return 'image/png'
  if (b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46) return 'image/gif'
  if (b[0] === 0x52 && b[1] === 0x49 && b[2] === 0x46 && b[8] === 0x57 && b[9] === 0x45) return 'image/webp' // RIFF....WEBP
  if (b[0] === 0x25 && b[1] === 0x50 && b[2] === 0x44 && b[3] === 0x46) return 'application/pdf' // %PDF
  if (b[4] === 0x66 && b[5] === 0x74 && b[6] === 0x79 && b[7] === 0x70) return 'video/mp4' // ftyp
  if (b[0] === 0x4F && b[1] === 0x67 && b[2] === 0x67 && b[3] === 0x53) return 'audio/ogg' // OggS
  if (b[0] === 0x49 && b[1] === 0x44 && b[2] === 0x33) return 'audio/mpeg' // ID3 (mp3)
  return ''
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

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const url = Deno.env.get('SUPABASE_URL')!
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!
    const svcKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // ── 1. Sahkan caller = staff ────────────────────────────
    const authHeader = req.headers.get('Authorization') || ''
    const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'unauthorized' }, 401)

    const { data: profile } = await userClient
      .from('psy_profiles').select('role, full_name').eq('id', user.id).single()
    if (profile?.role !== 'staff') return json({ error: 'forbidden — staff only' }, 403)

    const svc = createClient(url, svcKey)
    const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')!
    const { action, conversationId, contactId, message, mediaUrl, patientId, before, startAfter, startAfterDate, phone, name, attachments } = await req.json()

    // ── 2a. LIST — perbualan (pagination: Muat Lagi) ────────
    if (action === 'list') {
      let lpath = `/conversations/search?locationId=${locationId}&limit=50&sortBy=last_message_date&sort=desc`
      if (startAfterDate) lpath += `&startAfterDate=${startAfterDate}`
      if (startAfter) lpath += `&startAfter=${startAfter}`
      const data = await ghl(lpath, { method: 'GET' })
      const rawList = data?.conversations || []
      const lastRaw = rawList[rawList.length - 1]
      const cursor = lastRaw ? { startAfterDate: lastRaw.lastMessageDate, startAfter: lastRaw.id } : null
      const hasMore = rawList.length >= 50
      const convos = rawList.map((c: any) => ({
        ghl_conversation_id: c.id,
        ghl_contact_id: c.contactId,
        contact_name: c.fullName || c.contactName || c.name || '(tanpa nama)',
        phone_e164: toE164(c.phone),
        wa_number: null, // GHL search tak pulang nombor talian penerima; isi nanti via webhook (Fasa +2)
        last_message: c.lastMessageBody || '',
        last_message_at: c.lastMessageDate ? new Date(c.lastMessageDate).toISOString() : null,
        unread: c.unreadCount || 0,
        synced_at: new Date().toISOString(),
      }))
      // ── Padan pesakit ikut 9 digit terakhir (merentas psy_patients + psy_profiles) ──
      const keys = [...new Set(convos.map((c: any) => phoneKey(c.phone_e164)).filter(Boolean))]
      const keyToPatient: Record<string, string> = {}
      if (keys.length) {
        const orFilter = keys.map((k) => `phone.ilike.%${k}`).join(',')
        // a) profiles yang padan → user_id → key
        const { data: profs } = await svc.from('psy_profiles').select('id, phone').or(orFilter)
        const userKey: Record<string, string> = {}
        for (const p of profs || []) { const k = phoneKey(p.phone); if (k) userKey[p.id] = k }
        // b) patients yang padan ikut phone sendiri
        const { data: pat1 } = await svc.from('psy_patients').select('id, user_id, phone').or(orFilter)
        for (const p of pat1 || []) { const k = phoneKey(p.phone); if (k) keyToPatient[k] = p.id }
        // c) patients ikut user_id profil yang padan (phone ada di profil, bukan di patient)
        const uids = Object.keys(userKey)
        if (uids.length) {
          const { data: pat2 } = await svc.from('psy_patients').select('id, user_id').in('user_id', uids)
          for (const p of pat2 || []) { const k = userKey[p.user_id]; if (k && !keyToPatient[k]) keyToPatient[k] = p.id }
        }
      }
      const out = convos.map((c: any) => ({ ...c, patient_id: keyToPatient[phoneKey(c.phone_e164)] || null }))
      if (out.length) {
        // simpan termasuk patient_id ke cache
        await svc.from('psy_wa_conversations').upsert(out, { onConflict: 'ghl_conversation_id' })
      }
      return json({ conversations: out, cursor, hasMore })
    }

    // ── 2b. MESSAGES — mesej satu perbualan ─────────────────
    if (action === 'messages') {
      if (!conversationId) return json({ error: 'conversationId required' }, 400)
      let mpath = `/conversations/${conversationId}/messages?limit=50`
      if (before) mpath += `&lastMessageId=${before}` // tarik mesej LEBIH LAMA
      const data = await ghl(mpath, { method: 'GET' })
      // GHL nest: { messages: { messages: [...] } }
      const raw = data?.messages?.messages || data?.messages || []
      const moreCursor = data?.messages?.lastMessageId || null
      const moreAvail = !!data?.messages?.nextPage
      const pickAtts = (arr: any) => (arr || [])
        .map((a: any) => (typeof a === 'string' ? a : (a?.url || a?.link || a?.fileUrl || ''))).filter(Boolean)
      // GHL kadang pulangkan body literal teks "undefined"/"null" (bukan medan kosong sebenar)
      const cleanApiBody = (b: any) => (b == null || b === 'undefined' || b === 'null') ? '' : b
      // placeholder media GHL: body MENGANDUNGI token ">IMAGE<" / ">VIDEO<" / ">AUDIO<" / ">DOCUMENT<"
      // (kadang ada teks tambahan macam "[Received on ...]" selepasnya)
      const isMediaPlaceholder = (b: string) => /">?[A-Z]{3,}<"|>[A-Z]{3,}</.test(b || '')
      const stripPlaceholder = (b: string) => (b || '').replace(/>[A-Z]{3,}</g, '').trim()

      // Kenal jenis mesej GHL (untuk tapis email di inbox WhatsApp)
      const typeOf = (m: any) => {
        const t = String(m.messageType || m.type || '').toUpperCase()
        if (t.includes('EMAIL')) return 'email'
        if (t.includes('SMS')) return 'sms'
        if (t.includes('WHATSAPP')) return 'whatsapp'
        return 'other'
      }
      const msgs = raw.map((m: any) => ({
        ghl_message_id: m.id,
        ghl_conversation_id: conversationId,
        direction: m.direction === 'inbound' ? 'inbound' : 'outbound',
        body: cleanApiBody(m.body) || cleanApiBody(m.message) || '',
        msg_type: typeOf(m),
        attachments: pickAtts(m.attachments),
        created_at: m.dateAdded ? new Date(m.dateAdded).toISOString() : new Date().toISOString(),
      }))

      // Bila attachments kosong tapi body = placeholder media → ambil URL dari mesej tunggal
      await Promise.all(msgs.map(async (msg: any) => {
        if (msg.attachments.length || !isMediaPlaceholder(msg.body)) return
        try {
          const d = await ghl(`/conversations/messages/${msg.ghl_message_id}`, { method: 'GET' })
          const mm = d?.message || d
          msg.attachments = pickAtts(mm?.attachments)
          if (msg.attachments.length) msg.body = stripPlaceholder(msg.body) // buang token ">IMAGE<", kekal teks lain
        } catch (_) { /* biar placeholder kalau gagal */ }
      }))

      if (msgs.length) {
        await svc.from('psy_wa_messages').upsert(msgs, { onConflict: 'ghl_message_id' })
      }
      // susun lama→baru untuk paparan chat
      msgs.sort((a: any, b: any) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime())
      return json({ messages: msgs, moreCursor, hasMore: moreAvail })
    }

    // ── 2b-ii. PATIENT — info pesakit untuk panel inbox ─────
    if (action === 'patient') {
      if (!patientId) return json({ error: 'patientId required' }, 400)
      const { data: p } = await svc.from('psy_patients')
        .select('*, prof:psy_profiles!psy_patients_user_id_fkey(full_name, phone, email)')
        .eq('id', patientId).maybeSingle()
      if (!p) return json({ patient: null })
      const prof = (p as any).prof || {}
      return json({
        patient: {
          id: p.id,
          name: prof.full_name || p.full_name || '(tanpa nama)',
          phone: prof.phone || p.phone || null,
          email: prof.email || null,
          mrn: p.mrn || null,
          status: p.status || null,
          kob_status: p.kob_status || null,
          package: p.active_package_name || null,
          package_expires: p.package_expires_at || null,
          outcome: p.outcome || null,
        },
      })
    }

    // ── 2b-iv. GHLCONTACT — butiran contact GHL untuk panel (macam Contact Details GHL) ──
    if (action === 'ghlcontact') {
      if (!contactId) return json({ error: 'contactId required' }, 400)
      const cRes = await ghl(`/contacts/${contactId}`, { method: 'GET' })
      const ct: any = cRes?.contact || cRes || {}

      // peta id custom field → nama (perlu definisi field)
      const defs: Record<string, string> = {}
      try {
        const d = await ghl(`/locations/${locationId}/customFields`, { method: 'GET' })
        for (const f of (d?.customFields || [])) defs[f.id] = f.name
      } catch (_) { /* scope mungkin tiada — abaikan */ }

      const fields = (ct.customFields || [])
        .map((f: any) => ({ name: defs[f.id] || f.id, value: f.value ?? f.field_value ?? '' }))
        .filter((f: any) => f.value !== '' && f.value != null)

      // nama owner (assignedTo = user id)
      let owner: string | null = null
      if (ct.assignedTo) {
        try {
          const u = await ghl(`/users/${ct.assignedTo}`, { method: 'GET' })
          owner = u?.name || [u?.firstName, u?.lastName].filter(Boolean).join(' ') || null
        } catch (_) { owner = null }
      }

      return json({
        contact: {
          name: ct.contactName || [ct.firstName, ct.lastName].filter(Boolean).join(' ') || ct.name || '(tanpa nama)',
          phone: ct.phone || null,
          email: ct.email || null,
          tags: ct.tags || [],
          owner,
          fields,
        },
      })
    }

    // ── 2b-iii. MARKREAD — tandai perbualan dibaca (unread=0) ──
    if (action === 'markread') {
      if (!conversationId) return json({ error: 'conversationId required' }, 400)
      await svc.from('psy_wa_conversations').update({ unread: 0 }).eq('ghl_conversation_id', conversationId)
      return json({ success: true })
    }

    // ── 2b-v. FINDCONV — cari perbualan ikut phone (dari patient-hub) ──
    if (action === 'findconv') {
      if (!phone) return json({ error: 'phone required' }, 400)
      const last9 = phoneKey(phone)
      const q = last9 || digits(phone)
      const data = await ghl(`/conversations/search?locationId=${locationId}&query=${encodeURIComponent(q)}&limit=20`, { method: 'GET' })
      const raw = data?.conversations || []
      const match = raw.find((c: any) => phoneKey(c.phone) === last9) || raw[0]
      if (!match) return json({ conversation: null })

      // padan pesakit ikut 9 digit terakhir
      let patient_id: string | null = null
      if (last9) {
        const { data: profs } = await svc.from('psy_profiles').select('id, phone').or(`phone.ilike.%${last9}`)
        const uids = (profs || []).filter((p: any) => phoneKey(p.phone) === last9).map((p: any) => p.id)
        const { data: pat1 } = await svc.from('psy_patients').select('id, user_id, phone').or(`phone.ilike.%${last9}`)
        const hit = (pat1 || []).find((p: any) => phoneKey(p.phone) === last9)
        if (hit) patient_id = hit.id
        else if (uids.length) {
          const { data: pat2 } = await svc.from('psy_patients').select('id').in('user_id', uids).limit(1)
          if (pat2?.[0]) patient_id = pat2[0].id
        }
      }

      const conv = {
        ghl_conversation_id: match.id,
        ghl_contact_id: match.contactId,
        contact_name: match.fullName || match.contactName || match.name || '(tanpa nama)',
        phone_e164: toE164(match.phone),
        wa_number: null,
        last_message: match.lastMessageBody || '',
        last_message_at: match.lastMessageDate ? new Date(match.lastMessageDate).toISOString() : null,
        unread: match.unreadCount || 0,
        patient_id,
        synced_at: new Date().toISOString(),
      }
      await svc.from('psy_wa_conversations').upsert(conv, { onConflict: 'ghl_conversation_id' })
      return json({ conversation: conv })
    }

    // ── 2b-vi. FINDCONTACT — cari contact GHL ikut phone (untuk mula chat baru) ──
    if (action === 'findcontact') {
      if (!phone) return json({ error: 'phone required' }, 400)
      const last9 = phoneKey(phone)
      const e164 = toE164(phone)
      let ct: any = null
      try {
        const d = await ghl(`/contacts/?locationId=${locationId}&query=${encodeURIComponent(last9 || digits(phone))}&limit=20`, { method: 'GET' })
        const list = d?.contacts || []
        ct = list.find((c: any) => phoneKey(c.phone) === last9) || list[0] || null
      } catch (_) { ct = null }
      if (!ct) return json({ contact: null })

      let patient_id: string | null = null
      if (last9) {
        const { data: profs } = await svc.from('psy_profiles').select('id, phone').or(`phone.ilike.%${last9}`)
        const uids = (profs || []).filter((p: any) => phoneKey(p.phone) === last9).map((p: any) => p.id)
        const { data: pat1 } = await svc.from('psy_patients').select('id, user_id, phone').or(`phone.ilike.%${last9}`)
        const hit = (pat1 || []).find((p: any) => phoneKey(p.phone) === last9)
        if (hit) patient_id = hit.id
        else if (uids.length) {
          const { data: pat2 } = await svc.from('psy_patients').select('id').in('user_id', uids).limit(1)
          if (pat2?.[0]) patient_id = pat2[0].id
        }
      }

      return json({
        contact: {
          contactId: ct.id,
          name: ct.contactName || [ct.firstName, ct.lastName].filter(Boolean).join(' ') || e164 || '(tanpa nama)',
          phone: e164,
          patient_id,
        },
      })
    }

    // ── 2b-vii. ENSURECONTACT — cari-atau-cipta contact GHL (untuk mula chat) ──
    if (action === 'ensurecontact') {
      if (!phone) return json({ error: 'phone required' }, 400)
      const e164 = toE164(phone)
      const last9 = phoneKey(phone)
      const parts = String(name || '').trim().split(/\s+/)
      const upsertBody: any = { locationId, phone: e164 }
      if (name) { upsertBody.firstName = parts[0]; upsertBody.lastName = parts.slice(1).join(' ') || undefined; upsertBody.name = name }
      // upsert = cari ikut phone, cipta kalau tiada (takkan duplicate)
      const r = await ghl('/contacts/upsert', { method: 'POST', body: JSON.stringify(upsertBody) })
      const ct: any = r?.contact || r || {}
      if (!ct.id) return json({ contact: null })

      let patient_id: string | null = null
      if (last9) {
        const { data: profs } = await svc.from('psy_profiles').select('id, phone').or(`phone.ilike.%${last9}`)
        const uids = (profs || []).filter((p: any) => phoneKey(p.phone) === last9).map((p: any) => p.id)
        const { data: pat1 } = await svc.from('psy_patients').select('id, user_id, phone').or(`phone.ilike.%${last9}`)
        const hit = (pat1 || []).find((p: any) => phoneKey(p.phone) === last9)
        if (hit) patient_id = hit.id
        else if (uids.length) {
          const { data: pat2 } = await svc.from('psy_patients').select('id').in('user_id', uids).limit(1)
          if (pat2?.[0]) patient_id = pat2[0].id
        }
      }

      return json({
        contact: {
          contactId: ct.id,
          name: ct.contactName || name || [ct.firstName, ct.lastName].filter(Boolean).join(' ') || e164 || '(tanpa nama)',
          phone: e164,
          patient_id,
        },
      })
    }

    // ── 2c. SEND — hantar WhatsApp (teks + media) via GHL ───
    if (action === 'send') {
      const atts: string[] = Array.isArray(attachments) ? attachments.filter(Boolean) : []
      const text = (message || '').trim()
      if (!contactId || (!text && !atts.length)) return json({ error: 'contactId & (message atau attachments) diperlukan' }, 400)
      // Nota: saluran "SMS" GHL klinik ini sebenarnya disambung ke WhatsApp
      // (saluran "WhatsApp" rasmi GHL tak disambung → type:WhatsApp gagal).
      const sendBody: any = { type: 'SMS', contactId }
      if (text) sendBody.message = text
      if (atts.length) sendBody.attachments = atts // GHL muat turun URL & hantar
      const sent = await ghl('/conversations/messages', {
        method: 'POST',
        body: JSON.stringify(sendBody),
      })
      const convId = sent?.conversationId || conversationId || null
      // rekod outbound dalam cache
      if (convId) {
        await svc.from('psy_wa_messages').insert({
          ghl_message_id: sent?.messageId || null,
          ghl_conversation_id: convId,
          direction: 'outbound',
          body: text,
          msg_type: 'whatsapp',
          attachments: atts,
          sent_by: user.id,
          sent_by_name: profile?.full_name || null,
        })
        await svc.from('psy_wa_conversations')
          .update({ last_message: text || '📎 Lampiran', last_message_at: new Date().toISOString() })
          .eq('ghl_conversation_id', convId)
      }
      return json({ success: true, messageId: sent?.messageId || null, conversationId: convId })
    }

    // ── 2d. MEDIA — proxy fail media GHL (perlu token) → data URL ──
    if (action === 'media') {
      if (!mediaUrl) return json({ error: 'mediaUrl required' }, 400)
      // Kebanyakan media GHL di Google Cloud Storage (awam) — JANGAN hantar token
      // (Google tolak token GHL → 401). Cuba tanpa auth dulu; kalau ditolak,
      // baru retry dengan token GHL (untuk URL leadconnector yang berkunci).
      let res = await fetch(mediaUrl)
      if (!res.ok && (res.status === 401 || res.status === 403)) {
        const token = Deno.env.get('GHL_ISW_TOKEN')!
        res = await fetch(mediaUrl, { headers: { Authorization: `Bearer ${token}`, Version: GHL_VERSION } })
      }
      if (!res.ok) return json({ error: `media ${res.status}`, url: mediaUrl }, 400)
      const buf = new Uint8Array(await res.arrayBuffer())
      // had saiz ~12MB elak letupkan memori function
      if (buf.length > 12 * 1024 * 1024) return json({ error: 'media too large', url: mediaUrl }, 413)
      // Tentukan MIME: header dulu, tapi kalau generik → kenal dari byte, kemudian sambungan URL
      let ct = res.headers.get('content-type') || ''
      if (!ct || ct.includes('octet-stream') || ct.includes('binary')) {
        ct = mimeFromBytes(buf) || mimeFromUrl(mediaUrl) || ct || 'application/octet-stream'
      }
      let bin = ''
      const CH = 0x8000
      for (let i = 0; i < buf.length; i += CH) {
        bin += String.fromCharCode(...buf.subarray(i, i + CH))
      }
      const b64 = btoa(bin)
      return json({ dataUrl: `data:${ct};base64,${b64}`, contentType: ct })
    }

    return json({ error: 'unknown action' }, 400)
  } catch (err) {
    console.error('ghl-inbox error:', err)
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
