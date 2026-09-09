// ============================================================
// automations-runner — ENJIN psy_automations (COPY-PASTE, cors inline).
// Cetus tiap 15 min oleh cron. Proses automasi AKTIF:
//   - schedule (Broadcast Berjadual): hari+masa → sasaran (conditions)
//     → hantar (actions: whatsapp/inapp) → tulis psy_notification_logs
//   - treatment/patient_enrolled (sequence perjalanan pesakit — psy_automation_messages):
//     setiap mesej dalam sequence ada waktu sendiri (serta-merta/selepas
//     tempoh/hari+waktu tertentu) relatif ke psy_treatment_plans.start_date
//     → dedup ikut psy_notification_logs.message_id
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
// Pilih nombor & nama destinasi mesej ikut contact_preference pesakit.
// Templat mesej (cth {nama}) kekal guna nama PESAKIT — cuma nombor & nama
// paparan kenalan GHL yang berubah bila waris jadi destinasi.
function resolveContact(p: any) {
  if (p.contact_preference === 'waris' && p.emergency_contact_phone) {
    return { phone: p.emergency_contact_phone, contactName: p.emergency_contact_name || p.full_name }
  }
  return { phone: p.phone, contactName: p.full_name }
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
async function sendWA(contactId: string, message: string, attachments?: string[]) {
  const body: any = { type: 'SMS', contactId, message }
  if (attachments && attachments.length) body.attachments = attachments
  return ghl('/conversations/messages', { method: 'POST', body: JSON.stringify(body) })
}

async function logSend(supabase: any, a: any, p: any, channel: string, message: string, status: string, error: string | null, messageId?: string | null) {
  try {
    await supabase.from('psy_notification_logs').insert({
      automation_id: a.id, patient_id: p.id, patient_name: p.full_name, event: a.trigger_event,
      channel, status, message: (message || '').slice(0, 2000), error, message_id: messageId || null,
      sent_at: status === 'sent' ? new Date().toISOString() : null,
    })
  } catch (_) { /* jangan halang aliran */ }
}

function calcAgeNum(dob: string | null) {
  if (!dob) return null
  const d = new Date(dob), now = new Date(Date.now() + MY_OFFSET_MS)
  let age = now.getUTCFullYear() - d.getUTCFullYear()
  if (now.getUTCMonth() < d.getUTCMonth() || (now.getUTCMonth() === d.getUTCMonth() && now.getUTCDate() < d.getUTCDate())) age--
  return age
}

// Tapis sasaran ikut conditions (AND)
function applyConditions(pats: any[], conds: any[]) {
  let t = pats
  for (const c of conds || []) {
    if (c.field === 'patient_status') t = t.filter((p) => (c.value === 'active') ? p.status === 'active' : p.status !== 'active')
    else if (c.field === 'gender') t = t.filter((p) => p.gender === c.value)
    else if (c.field === 'has_whatsapp') t = t.filter((p) => (c.value === 'yes') ? !!resolveContact(p).phone : !resolveContact(p).phone)
    else if (c.field === 'package') { const vals = (Array.isArray(c.value) ? c.value : [c.value]).map(String); t = t.filter((p) => vals.includes(String(p.active_package_id))) }
    else if (c.field === 'age') { const { min, max } = c.value || {}; t = t.filter((p) => { const age = calcAgeNum(p.date_of_birth); if (age == null) return false; if (min != null && age < min) return false; if (max != null && age > max) return false; return true }) }
    else if (c.field === 'state') { const vals = (Array.isArray(c.value) ? c.value : [c.value]).map(String); t = t.filter((p) => vals.includes(String(p.state))) }
  }
  return t
}

async function runOne(supabase: any, locationId: string, a: any) {
  const actions = Array.isArray(a.actions) ? a.actions : []
  const conds = (a.conditions_enabled && Array.isArray(a.conditions)) ? a.conditions : []
  const { data: pats } = await supabase.from('psy_patients')
    .select('id, user_id, full_name, phone, gender, status, active_package_id, date_of_birth, state, emergency_contact_phone, emergency_contact_name, contact_preference')
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
    const withPhone = targets.map((p) => ({ ...p, ...resolveContact(p), e164: toE164(resolveContact(p).phone) })).filter((p) => p.e164)
    const BATCH = 15
    for (let i = 0; i < withPhone.length; i += BATCH) {
      const chunk = withPhone.slice(i, i + BATCH)
      await Promise.all(chunk.map(async (p) => {
        const msg = render(p.full_name)
        try { const cid = await upsertContact(locationId, p.e164, p.contactName); if (cid) { await sendWA(cid, msg); res.whatsapp++; await logSend(supabase, a, p, 'whatsapp', msg, 'sent', null) } }
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

// ── Sequence perjalanan pesakit (treatment / patient_enrolled) ──
const CLINIC_VARS = { nama_klinik: 'Ibnu Sina Wellness', telefon_klinik: '03-8966 3702', alamat_klinik: 'Kajang, Selangor' }
const HARI_MS = ['Ahad', 'Isnin', 'Selasa', 'Rabu', 'Khamis', 'Jumaat', 'Sabtu']
const BULAN_MS = ['Januari', 'Februari', 'Mac', 'April', 'Mei', 'Jun', 'Julai', 'Ogos', 'September', 'Oktober', 'November', 'Disember']
function fmtDateMY(d: Date) { return `${String(d.getUTCDate()).padStart(2, '0')} ${BULAN_MS[d.getUTCMonth()]} ${d.getUTCFullYear()}` }
function fmtTimeMY(d: Date) { const h = d.getUTCHours(), m = d.getUTCMinutes(); const ap = h >= 12 ? 'PTG' : 'PG'; let hh = h % 12; if (hh === 0) hh = 12; return `${hh}:${String(m).padStart(2, '0')} ${ap}` }

function buildVars(p: any, plan: any, coachName: string) {
  const myNow = new Date(Date.now() + MY_OFFSET_MS)
  const age = calcAgeNum(p.date_of_birth)
  return {
    nama: p.full_name || '', mrn: p.mrn || '', ic: p.ic_number || '', telefon: p.phone || '', emel: p.email || '',
    jantina: p.gender === 'M' ? 'Lelaki' : p.gender === 'F' ? 'Perempuan' : '', negeri: p.state || '', umur: age != null ? String(age) : '',
    pakej: p.active_package_name || '', kod_pakej: p.active_package_id || '',
    minggu: plan?.current_week != null ? String(plan.current_week) : '',
    jumlah_minggu: plan?.duration_weeks != null ? String(plan.duration_weeks) : '',
    tarikh_mula: plan?.start_date ? fmtDateMY(new Date(plan.start_date + 'T00:00:00Z')) : (plan?.created_at ? fmtDateMY(new Date(plan.created_at)) : ''),
    tarikh_tamat: p.package_expires_at ? fmtDateMY(new Date(p.package_expires_at)) : '',
    coach: coachName || '',
    ...CLINIC_VARS,
    tarikh: fmtDateMY(myNow), masa: fmtTimeMY(myNow), hari: HARI_MS[myNow.getUTCDay()],
    tahun: String(myNow.getUTCFullYear()), bulan: BULAN_MS[myNow.getUTCMonth()],
  }
}

async function runEnrollmentSequences(supabase: any, locationId: string) {
  const { data: autos } = await supabase.from('psy_automations').select('*, psy_automation_messages(*)')
    .eq('is_active', true).eq('trigger_category', 'treatment').eq('trigger_event', 'patient_enrolled')
  const out: any[] = []
  const myNow = new Date(Date.now() + MY_OFFSET_MS)

  for (const a of autos || []) {
    const messages = (a.psy_automation_messages || []).sort((x: any, y: any) => x.position - y.position)
    if (!messages.length) continue
    const conds = (a.conditions_enabled && Array.isArray(a.conditions)) ? a.conditions : []
    const actions = Array.isArray(a.actions) ? a.actions : []

    const { data: plans } = await supabase.from('psy_treatment_plans')
      .select('id, patient_id, start_date, created_at, current_week, duration_weeks').eq('status', 'active')
    if (!plans || !plans.length) continue
    const patientIds = [...new Set(plans.map((pl: any) => pl.patient_id))]
    const { data: pats } = await supabase.from('psy_patients')
      .select('id, user_id, full_name, mrn, ic_number, phone, email, gender, state, date_of_birth, status, active_package_id, active_package_name, package_expires_at, coach_id, emergency_contact_phone, emergency_contact_name, contact_preference')
      .in('id', patientIds).neq('status', 'deleted').neq('status', 'rejected')
    if (!pats || !pats.length) continue
    const patById = new Map(pats.map((p: any) => [p.id, p]))
    const targetIds = new Set(applyConditions(pats, conds).map((p: any) => p.id))

    const coachIds = [...new Set(pats.map((p: any) => p.coach_id).filter(Boolean))]
    let coachNames: Record<string, string> = {}
    if (coachIds.length) {
      const { data: coaches } = await supabase.from('psy_profiles').select('id, full_name').in('id', coachIds)
      coachNames = Object.fromEntries((coaches || []).map((c: any) => [c.id, c.full_name]))
    }

    const msgIds = messages.map((m: any) => m.id)
    const { data: existingLogs } = await supabase.from('psy_notification_logs').select('message_id, patient_id').in('message_id', msgIds)
    const sentSet = new Set((existingLogs || []).map((l: any) => `${l.message_id}:${l.patient_id}`))

    for (const plan of plans) {
      const p = patById.get(plan.patient_id)
      if (!p || !targetIds.has(p.id)) continue
      const anchor = plan.start_date ? new Date(plan.start_date + 'T00:00:00Z') : new Date(plan.created_at)
      const anchorMY = new Date(anchor.getTime() + MY_OFFSET_MS)
      const dayNum = Math.floor((Date.UTC(myNow.getUTCFullYear(), myNow.getUTCMonth(), myNow.getUTCDate()) - Date.UTC(anchorMY.getUTCFullYear(), anchorMY.getUTCMonth(), anchorMY.getUTCDate())) / 86400000)
      if (dayNum < 0) continue

      for (const m of messages) {
        if (sentSet.has(`${m.id}:${p.id}`)) continue
        let eligible = false
        if (m.send_mode === 'immediate') {
          eligible = dayNum === (m.day_offset || 0)
        } else if (m.send_mode === 'specific_time' && m.send_time) {
          if (dayNum === (m.day_offset || 0)) {
            const [h, mm] = String(m.send_time).split(':').map(Number)
            const nowMin = myNow.getUTCHours() * 60 + myNow.getUTCMinutes()
            eligible = Math.abs(nowMin - (h * 60 + mm)) <= WINDOW_HALF_MIN
          }
        } else if (m.send_mode === 'after_delay' && m.delay_value) {
          const unitMs = m.delay_unit === 'minute' ? 60000 : m.delay_unit === 'day' ? 86400000 : 3600000
          const targetMs = anchor.getTime() + m.delay_value * unitMs
          eligible = Math.abs(Date.now() - targetMs) <= WINDOW_HALF_MIN * 60000
        }
        if (!eligible) continue

        const vars = buildVars(p, plan, coachNames[p.coach_id] || '')
        const text = fillTemplate(m.message_text || '', vars)
        const fullText = (m.content_type === 'link' && m.link_url) ? `${text}\n\n${m.link_label || m.link_url}\n${m.link_url}` : text
        const attachments = m.media_url ? [m.media_url] : []

        if (actions.includes('inapp') && p.user_id) {
          try { await supabase.from('psy_notifications').insert({ user_id: p.user_id, type: 'system', title: a.name, body: fullText.slice(0, 240) }) } catch (_) { /* */ }
          await logSend(supabase, a, p, 'inapp', fullText, 'sent', null, m.id)
        }
        if (actions.includes('whatsapp')) {
          const contact = resolveContact(p)
          const e164 = toE164(contact.phone)
          if (e164) {
            try {
              const cid = await upsertContact(locationId, e164, contact.contactName)
              if (cid) { await sendWA(cid, fullText, attachments); await logSend(supabase, a, p, 'whatsapp', fullText, 'sent', null, m.id) }
            } catch (e) { await logSend(supabase, a, p, 'whatsapp', fullText, 'failed', String((e as any)?.message || e), m.id) }
          }
        }
        sentSet.add(`${m.id}:${p.id}`)
        out.push({ automation: a.name, message: m.position, patient: p.full_name })
      }
    }
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
    const sequences = await runEnrollmentSequences(supabase, locationId)
    return new Response(JSON.stringify({ success: true, scheduled, sequences }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (err) {
    console.error('automations-runner error:', err)
    return new Response(JSON.stringify({ error: String((err as any)?.message || err) }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
