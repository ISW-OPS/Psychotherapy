// ============================================================
// automations-runner — ENJIN psy_automations (COPY-PASTE, cors inline).
// Cetus tiap 15 min oleh cron. Proses automasi AKTIF:
//   - schedule (Broadcast Berjadual): hari+masa → sasaran (conditions)
//     → hantar (actions: whatsapp/inapp) → tulis psy_notification_logs
//   (trigger lain — session_reminder/package_expiring/checkin_missed —
//    akan ditambah berperingkat.)
// Secrets: GHL_ISW_TOKEN, GHL_ISW_LOCATION_ID, CRON_SECRET,
//          SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-cron-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const GHL_BASE = 'https://services.leadconnectorhq.com'
const GHL_VERSION = '2021-07-28'
const WINDOW_HALF_MIN = 10
const MY_OFFSET_MS = 8 * 3600 * 1000   // Malaysia = UTC+8

function toE164(raw: string) {
  if (!raw) return null
  let n = String(raw).replace(/[^\d+]/g, '')
  if (n.startsWith('+')) return n
  if (n.startsWith('60')) return '+' + n
  if (n.startsWith('0')) return '+60' + n.slice(1)
  return '+' + n
}
function fillTemplate(tpl: string, vars: Record<string, string>) {
  return Object.entries(vars).reduce((s, [k, v]) => s.split(`{{${k}}}`).join(v ?? '').split(`{${k}}`).join(v ?? ''), tpl || '').replace(/\n{3,}/g, '\n\n').trim()
}
async function ghl(path: string, init: any = {}) {
  const token = Deno.env.get('GHL_ISW_TOKEN')
  const res = await fetch(`${GHL_BASE}${path}`, { ...init, headers: { Authorization: `Bearer ${token}`, Version: GHL_VERSION, 'Content-Type': 'application/json', Accept: 'application/json', ...(init.headers || {}) } })
  const text = await res.text()
  let body: any = null
  try { body = text ? JSON.parse(text) : null } catch { body = text }
  if (!res.ok) throw new Error(`GHL ${path} ${res.status}: ${typeof body === 'string' ? body : JSON.stringify(body)}`)
  return body
}
async function upsertContact(locationId: string, phone: string, name: string) {
  const [firstName, ...rest] = String(name || '').trim().split(/\s+/)
  const r = await ghl('/contacts/upsert', { method: 'POST', body: JSON.stringify({ locationId, phone, firstName: firstName || undefined, lastName: rest.join(' ') || undefined, name: name || undefined }) })
  return r?.contact?.id || r?.id
}
async function sendWA(contactId: string, message: string) {
  return ghl('/conversations/messages', { method: 'POST', body: JSON.stringify({ type: 'SMS', contactId, message }) })
}

async function logSend(supabase: any, a: any, p: any, channel: string, message: string, status: string, error: string | null) {
  try {
    await supabase.from('psy_notification_logs').insert({
      automation_id: a.id, patient_id: p.id, patient_name: p.full_name, event: a.trigger_event,
      channel, status, message: (message || '').slice(0, 2000), error,
      sent_at: status === 'sent' ? new Date().toISOString() : null,
    })
  } catch (_) { /* jangan halang aliran */ }
}

// Tapis sasaran ikut conditions (AND)
function applyConditions(pats: any[], conds: any[]) {
  let t = pats
  for (const c of conds || []) {
    if (c.field === 'patient_status') t = t.filter((p) => (c.value === 'active') ? p.status === 'active' : p.status !== 'active')
    else if (c.field === 'gender') t = t.filter((p) => p.gender === c.value)
    else if (c.field === 'has_whatsapp') t = t.filter((p) => (c.value === 'yes') ? !!p.phone : !p.phone)
  }
  return t
}

async function runOne(supabase: any, locationId: string, a: any) {
  const actions = Array.isArray(a.actions) ? a.actions : []
  const conds = (a.conditions_enabled && Array.isArray(a.conditions)) ? a.conditions : []
  const { data: pats } = await supabase.from('psy_patients')
    .select('id, user_id, full_name, phone, gender, status, active_package_id')
    .neq('status', 'deleted').neq('status', 'rejected')
  const targets = applyConditions(pats || [], conds)
  const render = (name: string) => fillTemplate(a.message_template || '', { nama: name || '' })
  const res: any = { targets: targets.length, whatsapp: 0, inapp: 0, failed: 0 }

  if (actions.includes('inapp')) {
    const withAcct = targets.filter((p) => p.user_id)
    if (withAcct.length) {
      const rows = withAcct.map((p) => ({ user_id: p.user_id, type: 'system', title: a.name, body: render(p.full_name).slice(0, 240) }))
      try { await supabase.from('psy_notifications').insert(rows); res.inapp = rows.length } catch (_) { /* */ }
      for (const p of withAcct) await logSend(supabase, a, p, 'inapp', render(p.full_name), 'sent', null)
    }
  }
  if (actions.includes('whatsapp')) {
    const withPhone = targets.map((p) => ({ ...p, e164: toE164(p.phone) })).filter((p) => p.e164)
    const BATCH = 15
    for (let i = 0; i < withPhone.length; i += BATCH) {
      const chunk = withPhone.slice(i, i + BATCH)
      await Promise.all(chunk.map(async (p) => {
        const msg = render(p.full_name)
        try { const cid = await upsertContact(locationId, p.e164, p.full_name); if (cid) { await sendWA(cid, msg); res.whatsapp++; await logSend(supabase, a, p, 'whatsapp', msg, 'sent', null) } }
        catch (e) { res.failed++; await logSend(supabase, a, p, 'whatsapp', msg, 'failed', String((e as any)?.message || e)) }
      }))
    }
  }
  return res
}

// Broadcast berjadual — hari + masa
async function runScheduled(supabase: any, locationId: string) {
  const { data: autos } = await supabase.from('psy_automations').select('*').eq('is_active', true).eq('trigger_category', 'schedule')
  const myNow = new Date(Date.now() + MY_OFFSET_MS)
  const myDow = myNow.getUTCDay()
  const myDate = myNow.toISOString().slice(0, 10)
  const nowMin = myNow.getUTCHours() * 60 + myNow.getUTCMinutes()
  const out: any[] = []
  for (const a of autos || []) {
    const t = a.trigger_timing || {}
    if (t.when !== 'schedule') continue
    const days = Array.isArray(t.days) ? t.days : []
    if (!days.includes(myDow) || !t.time) continue
    const [h, m] = String(t.time).split(':').map(Number)
    if (Math.abs(nowMin - (h * 60 + m)) > WINDOW_HALF_MIN) continue
    if (a.last_run_at) {
      const last = new Date(new Date(a.last_run_at).getTime() + MY_OFFSET_MS).toISOString().slice(0, 10)
      if (last === myDate) continue   // dedup 1×/hari
    }
    await supabase.from('psy_automations').update({ last_run_at: new Date().toISOString() }).eq('id', a.id)
    out.push({ id: a.id, name: a.name, ...(await runOne(supabase, locationId, a)) })
  }
  return out
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    if (req.headers.get('x-cron-secret') !== Deno.env.get('CRON_SECRET')) {
      return new Response(JSON.stringify({ error: 'forbidden' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')!
    const scheduled = await runScheduled(supabase, locationId)
    return new Response(JSON.stringify({ success: true, scheduled }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (err) {
    console.error('automations-runner error:', err)
    return new Response(JSON.stringify({ error: String((err as any)?.message || err) }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
