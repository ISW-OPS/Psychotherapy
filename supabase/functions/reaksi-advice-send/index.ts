// ============================================================
// reaksi-advice-send — AUTO-HANTAR Saranan Reaksi ke WhatsApp
// ============================================================
// DUA mod:
//
// 1. MOD TERUS (klien pesakit) — body { advice_id }:
//    Dipanggil sejurus selepas Catatan Harian dihantar
//    (generateReaksiAdvice dalam roles/patient/kepatuhan.html)
//    untuk MESEJ PERTAMA sahaja (send_after = sekarang).
//
// 2. MOD CRON — header x-cron-secret (tiada JWT), body {}:
//    pg_cron tiap 5 minit. Proses SEMUA baris psy_reaksi_advice_log
//    status='draft' yang send_after <= now() (mesej ke-2 Diet & Nutrisi
//    +5 min, ke-3 Gaya Hidup Fitrah +10 min) + retry mesej pertama
//    yang gagal (berhenti selepas 5 percubaan).
//    NOTA: deploy dengan --no-verify-jwt (sama corak event-reminders).
//
// Aliran hantar (kedua-dua mod):
//   - Hantar message_text ke WhatsApp pesakit via GHL (contacts/upsert → send).
//     SEMUA saranan dihantar automatik, termasuk kecemasan (mesej kritikal
//     suruh pesakit hubungi coach/hospital segera; trigger DB turut
//     notifikasi coach 🚨).
//   - Tanda status='sent' + rekod dalam cache psy_wa_messages.
//
// Secrets (guna semula dari ghl-inbox — JANGAN timpa):
//   GHL_ISW_TOKEN, GHL_ISW_LOCATION_ID, CRON_SECRET
// Auto-injected: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-cron-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const GHL_BASE = 'https://services.leadconnectorhq.com'
const GHL_VERSION = '2021-07-28'
const MAX_ATTEMPTS = 5

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
// Pilih nombor & nama destinasi mesej ikut contact_preference pesakit.
// null bermaksud tiada keutamaan waris berkuat kuasa — caller kekalkan
// fallback psy_profiles sedia ada dalam kes tu.
function resolveContact(p: any): { phone: string | null; name: string } {
  if (p?.contact_preference === 'waris' && p?.emergency_contact_phone) {
    return { phone: p.emergency_contact_phone, name: p.emergency_contact_name || p.full_name || '' }
  }
  return { phone: p?.phone || null, name: p?.full_name || '' }
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

// Hantar SATU baris advice ke WhatsApp + tanda sent. Throw jika gagal.
async function sendOne(svc: any, locationId: string, adv: any, sentBy: string | null) {
  // ── Dapatkan nombor telefon destinasi (pesakit atau waris ikut contact_preference) ──
  const { data: patient } = await svc.from('psy_patients')
    .select('id, user_id, full_name, phone, emergency_contact_phone, emergency_contact_name, contact_preference').eq('id', adv.patient_id).single()
  const resolved = resolveContact(patient)
  let phone = resolved.phone
  let name = resolved.name
  if (!phone && patient?.user_id) {
    // Fallback profil pesakit sendiri — hanya bila tiada nombor pesakit/waris langsung
    const { data: prof2 } = await svc.from('psy_profiles').select('phone').eq('id', patient.user_id).single()
    phone = prof2?.phone || null
    name = patient?.full_name || ''
  }
  const e164 = toE164(phone)
  if (!e164) throw new Error('pesakit tiada nombor telefon')

  // ── GHL: upsert contact → hantar mesej ───────────────────
  const parts = name.trim().split(/\s+/)
  const upsertBody: any = { locationId, phone: e164 }
  if (name) { upsertBody.firstName = parts[0]; upsertBody.lastName = parts.slice(1).join(' ') || undefined; upsertBody.name = name }
  const r = await ghl('/contacts/upsert', { method: 'POST', body: JSON.stringify(upsertBody) })
  const contactId = (r?.contact || r || {}).id
  if (!contactId) throw new Error('gagal sediakan contact GHL')

  // Saluran "SMS" GHL klinik ini sebenarnya WhatsApp (sama spt ghl-inbox)
  const sent = await ghl('/conversations/messages', {
    method: 'POST',
    body: JSON.stringify({ type: 'SMS', contactId, message: adv.message_text }),
  })
  const convId = sent?.conversationId || null

  // ── Tanda sent + cache outbound ──────────────────────────
  const now = new Date().toISOString()
  await svc.from('psy_reaksi_advice_log')
    .update({ status: 'sent', sent_by: sentBy, sent_at: now, updated_at: now })
    .eq('id', adv.id)
  if (convId) {
    await svc.from('psy_wa_messages').insert({
      ghl_message_id: sent?.messageId || null,
      ghl_conversation_id: convId,
      direction: 'outbound',
      body: adv.message_text,
      msg_type: 'whatsapp',
      attachments: [],
      sent_by: sentBy,
      sent_by_name: 'Auto — Saranan Reaksi',
    })
    await svc.from('psy_wa_conversations')
      .update({ last_message: adv.message_text, last_message_at: now })
      .eq('ghl_conversation_id', convId)
  }
  return sent?.messageId || null
}

// Rekod percubaan gagal (kolum send_attempts wujud selepas migration 20260716)
async function markFailed(svc: any, adv: any) {
  try {
    await svc.from('psy_reaksi_advice_log')
      .update({ send_attempts: (adv.send_attempts || 0) + 1, updated_at: new Date().toISOString() })
      .eq('id', adv.id)
  } catch (_) { /* kolum belum wujud — abaikan */ }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const url = Deno.env.get('SUPABASE_URL')!
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!
    const svcKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')!
    const svc = createClient(url, svcKey)

    // ══ MOD CRON: proses queue (mesej tertangguh + retry) ════
    const cronSecret = req.headers.get('x-cron-secret')
    if (cronSecret) {
      if (cronSecret !== Deno.env.get('CRON_SECRET')) return json({ error: 'unauthorized' }, 401)

      // Hanya mesej ≤24 jam — saranan bersifat harian; draf basi (cth gagal
      // berhari-hari atau baris lama sebelum migration) TIDAK dihantar lewat.
      const dayAgo = new Date(Date.now() - 24 * 3600 * 1000).toISOString()
      const { data: due, error: dueErr } = await svc.from('psy_reaksi_advice_log')
        .select('*')
        .eq('status', 'draft')
        .lte('send_after', new Date().toISOString())
        .gte('created_at', dayAgo)
        .lt('send_attempts', MAX_ATTEMPTS)
        .order('send_after', { ascending: true })
        .limit(25)
      if (dueErr) return json({ error: dueErr.message }, 500)

      let sent = 0, failed = 0
      const errors: string[] = []
      for (const adv of (due || [])) {
        try { await sendOne(svc, locationId, adv, null); sent++ }
        catch (e) { failed++; errors.push(`${adv.id}: ${String((e as Error)?.message || e)}`); await markFailed(svc, adv) }
      }
      return json({ success: true, mode: 'cron', due: (due || []).length, sent, failed, errors })
    }

    // ══ MOD TERUS: klien pesakit/staff dengan advice_id ══════
    // ── 1. Sahkan caller (pesakit atau staff) ────────────────
    const authHeader = req.headers.get('Authorization') || ''
    const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'unauthorized' }, 401)

    const { advice_id } = await req.json()
    if (!advice_id) return json({ error: 'advice_id required' }, 400)

    // ── 2. Muat draf ─────────────────────────────────────────
    const { data: adv, error: advErr } = await svc.from('psy_reaksi_advice_log')
      .select('*').eq('id', advice_id).single()
    if (advErr || !adv) return json({ error: 'advice tidak dijumpai' }, 404)
    if (adv.status !== 'draft') return json({ skipped: 'bukan draf', status: adv.status })

    // Mesej berjadual (send_after akan datang) — biar cron yang hantar.
    // Toleransi 60s untuk beza jam klien vs pelayan (klien set send_after=Date.now()).
    if (adv.send_after && new Date(adv.send_after).getTime() > Date.now() + 60_000) {
      return json({ queued: true, send_after: adv.send_after })
    }

    // Kebenaran: pesakit pemilik ATAU staff
    const { data: profile } = await svc.from('psy_profiles').select('role, full_name').eq('id', user.id).single()
    if (profile?.role !== 'staff') {
      const { data: pat } = await svc.from('psy_patients').select('id, user_id').eq('id', adv.patient_id).single()
      if (!pat || pat.user_id !== user.id) return json({ error: 'forbidden' }, 403)
    }

    // ── 3. Hantar ────────────────────────────────────────────
    try {
      const messageId = await sendOne(svc, locationId, adv, user.id)
      return json({ success: true, messageId })
    } catch (e) {
      await markFailed(svc, adv)
      throw e
    }
  } catch (e) {
    return json({ error: String((e as Error)?.message || e) }, 500)
  }
})
