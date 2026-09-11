// ============================================================
// automations-runner — ENJIN psy_automations (COPY-PASTE, cors inline).
// Cetus tiap 15 min oleh cron. Proses automasi AKTIF:
//   - schedule (Broadcast Berjadual): hari+masa → sasaran (conditions)
//     → hantar (actions: whatsapp/inapp) → tulis psy_notification_logs
//   - sequence (psy_automation_messages), 7 trigger disokong, kongsi logik sama
//     (runSequenceAutomations) — beza cuma sumber & arah anchor (getAnchors):
//       · treatment/patient_enrolled     → psy_treatment_plans.start_date, kira MAJU
//       · package/package_expiring       → psy_patients.package_expires_at, kira MUNDUR
//       · patient/birthday               → psy_patients.date_of_birth (tahun ini), kira MAJU, ulang tiap tahun
//       · event/event_reminder           → psy_events.start_at via psy_event_registrations, kira MUNDUR
//       · event/dna_sample_reminder      → psy_appointments.appointment_time via psy_dna_test_process, kira MUNDUR
//       · installment/installment_reminder → psy_kob_installment_checkpoints.due_date, kira MUNDUR
//       · installment/installment_overdue  → sama jadual, kira MAJU (mesej sahaja — status
//         flip pending→overdue + booking_blocked KEKAL di event-reminders/runInstallmentOverdueCheck)
//     dedup ikut psy_notification_logs.message_id + patient + HARI (bukan sekali
//     selama-lamanya) — perlu utk trigger berulang macam hari jadi/renew pakej.
//   (trigger lain — session_reminder/checkin_missed/payment/patient_inactive/
//    kepatuhan_alert — mekanisme lain terus, sengaja tak dimigrate, lihat plan.)
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

// ── Sequence mesej (patient_enrolled / package_expiring / birthday) ──
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

// Anchor pesakit ikut trigger_event — setiap satu beza sumber tarikh & arah kiraan.
// countdown=true bermaksud day_offset dikira "N hari SEBELUM anchor" (cth pakej tamat);
// countdown=false bermaksud "N hari SELEPAS anchor" (cth pesakit daftar, hari jadi tahun ini).
async function getAnchors(supabase: any, triggerEvent: string, myNow: Date) {
  if (triggerEvent === 'patient_enrolled') {
    const { data: plans } = await supabase.from('psy_treatment_plans')
      .select('id, patient_id, start_date, created_at, current_week, duration_weeks').eq('status', 'active')
    return (plans || []).map((pl: any) => ({
      patientId: pl.patient_id, plan: pl, countdown: false,
      anchor: pl.start_date ? new Date(pl.start_date + 'T00:00:00Z') : new Date(pl.created_at),
    }))
  }
  if (triggerEvent === 'package_expiring') {
    const { data: pats } = await supabase.from('psy_patients').select('id, package_expires_at').not('package_expires_at', 'is', null)
    return (pats || []).map((p: any) => ({ patientId: p.id, plan: null, countdown: true, anchor: new Date(p.package_expires_at) }))
  }
  if (triggerEvent === 'birthday') {
    const { data: pats } = await supabase.from('psy_patients').select('id, date_of_birth').not('date_of_birth', 'is', null)
    return (pats || []).map((p: any) => {
      const dob = new Date(p.date_of_birth + 'T00:00:00Z')
      // Ulang tahunan — anchor = hari jadi TAHUN INI (dedup ikut hari, jadi ulang setiap tahun secara semula jadi).
      return { patientId: p.id, plan: null, countdown: false, anchor: new Date(Date.UTC(myNow.getUTCFullYear(), dob.getUTCMonth(), dob.getUTCDate())) }
    })
  }
  if (triggerEvent === 'event_reminder') {
    const { data: regs } = await supabase.from('psy_event_registrations')
      .select('patient_id, status, psy_events(start_at, status)').neq('status', 'batal')
    return (regs || [])
      .filter((r: any) => r.psy_events && r.psy_events.status === 'published' && r.psy_events.start_at)
      .map((r: any) => ({ patientId: r.patient_id, plan: null, countdown: true, anchor: new Date(r.psy_events.start_at) }))
  }
  if (triggerEvent === 'dna_sample_reminder') {
    const { data: procs } = await supabase.from('psy_dna_test_process')
      .select('patient_id, status, sample_appointment_id, psy_appointments(appointment_time, status)')
      .eq('status', 'in_progress').not('sample_appointment_id', 'is', null)
    return (procs || [])
      .filter((p: any) => p.psy_appointments && p.psy_appointments.appointment_time && p.psy_appointments.status !== 'cancelled')
      .map((p: any) => ({ patientId: p.patient_id, plan: null, countdown: true, anchor: new Date(p.psy_appointments.appointment_time) }))
  }
  if (triggerEvent === 'installment_reminder' || triggerEvent === 'installment_overdue') {
    const { data: cps } = await supabase.from('psy_kob_installment_checkpoints')
      .select('patient_id, due_date, status').eq('status', 'pending')
    return (cps || []).map((c: any) => ({
      patientId: c.patient_id, plan: null, countdown: triggerEvent === 'installment_reminder',
      anchor: new Date(c.due_date + 'T00:00:00Z'),
    }))
  }
  if (triggerEvent === 'session_confirm') {
    const { data: rows } = await supabase.from('psy_plan_weekly_progress')
      .select('id, patient_id, session_date, patient_confirmed').eq('status', 'booked')
      .is('patient_confirmed', null).not('session_date', 'is', null)
    return (rows || []).map((r: any) => ({ patientId: r.patient_id, plan: null, countdown: true, anchor: new Date(r.session_date), progressId: r.id }))
  }
  return []
}

function midnightMY(d: Date) { const my = new Date(d.getTime() + MY_OFFSET_MS); return Date.UTC(my.getUTCFullYear(), my.getUTCMonth(), my.getUTCDate()) }

async function runSequenceAutomations(supabase: any, locationId: string) {
  const { data: autos } = await supabase.from('psy_automations').select('*, psy_automation_messages(*)')
    .eq('is_active', true).in('trigger_event', ['patient_enrolled', 'package_expiring', 'birthday', 'event_reminder', 'dna_sample_reminder', 'installment_reminder', 'installment_overdue'])
  const out: any[] = []
  const myNow = new Date(Date.now() + MY_OFFSET_MS)
  const myTodayKey = `${myNow.getUTCFullYear()}-${String(myNow.getUTCMonth() + 1).padStart(2, '0')}-${String(myNow.getUTCDate()).padStart(2, '0')}`

  for (const a of autos || []) {
    const messages = (a.psy_automation_messages || []).sort((x: any, y: any) => x.position - y.position)
    if (!messages.length) continue
    const conds = (a.conditions_enabled && Array.isArray(a.conditions)) ? a.conditions : []
    const actions = Array.isArray(a.actions) ? a.actions : []

    const anchors = await getAnchors(supabase, a.trigger_event, myNow)
    if (!anchors.length) continue
    const patientIds = [...new Set(anchors.map((x: any) => x.patientId))]
    const { data: pats } = await supabase.from('psy_patients')
      .select('id, user_id, full_name, mrn, ic_number, phone, email, gender, state, date_of_birth, status, active_package_id, active_package_name, package_expires_at, coach_id, emergency_contact_phone, emergency_contact_name, contact_preference')
      .in('id', patientIds).neq('status', 'deleted').neq('status', 'rejected')
    if (!pats || !pats.length) continue
    const patById = new Map(pats.map((p: any) => [p.id, p]))
    const targetIds = new Set(applyConditions(pats, conds).map((p: any) => p.id))

    const coachIds = [...new Set(pats.map((p: any) => p.coach_id).filter(Boolean))]
    let coachNames: Record<string, string> = {}
    let coachProfiles: Record<string, any> = {}
    if (coachIds.length) {
      const { data: coaches } = await supabase.from('psy_profiles').select('id, full_name, phone, email').in('id', coachIds)
      coachNames = Object.fromEntries((coaches || []).map((c: any) => [c.id, c.full_name]))
      coachProfiles = Object.fromEntries((coaches || []).map((c: any) => [c.id, c]))
    }

    // Dedup PER HARI (bukan sekali sahaja selama-lamanya) — perlu utk trigger berulang
    // (hari jadi tiap tahun, pakej tamat tiap kitaran renew), tapi selamat jugak utk
    // sequence sekali-sahaja (patient_enrolled) sebab tiap mesej cuma layak SATU hari je.
    const msgIds = messages.map((m: any) => m.id)
    const { data: existingLogs } = await supabase.from('psy_notification_logs').select('message_id, patient_id, sent_at, created_at').in('message_id', msgIds)
    const sentSet = new Set((existingLogs || []).map((l: any) => {
      const t = new Date(new Date(l.sent_at || l.created_at).getTime() + MY_OFFSET_MS)
      const d = `${t.getUTCFullYear()}-${String(t.getUTCMonth() + 1).padStart(2, '0')}-${String(t.getUTCDate()).padStart(2, '0')}`
      return `${l.message_id}:${l.patient_id}:${d}`
    }))

    for (const anc of anchors) {
      const p = patById.get(anc.patientId)
      if (!p || !targetIds.has(p.id)) continue
      const dayNum = anc.countdown
        ? Math.floor((midnightMY(anc.anchor) - midnightMY(myNow)) / 86400000)   // hari BAKI sebelum anchor
        : Math.floor((midnightMY(myNow) - midnightMY(anc.anchor)) / 86400000)  // hari SELEPAS anchor
      if (dayNum < 0) continue

      for (const m of messages) {
        const dedupKey = `${m.id}:${p.id}:${myTodayKey}`
        if (sentSet.has(dedupKey)) continue
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
          // Anchor MUNDUR (event akan datang) → "selepas tempoh" bermaksud SEBELUM anchor
          // (cth "24 jam selepas pencetus" utk sesi = 24 jam sebelum sesi). Anchor MAJU
          // (patient_enrolled/birthday) kekal tambah macam asal.
          const targetMs = anc.countdown ? anc.anchor.getTime() - m.delay_value * unitMs : anc.anchor.getTime() + m.delay_value * unitMs
          eligible = Math.abs(Date.now() - targetMs) <= WINDOW_HALF_MIN * 60000
        }
        if (!eligible) continue

        // Guard khusus session_confirm — semak SEMULA patient_confirmed masa hantar
        // (bukan hanya masa query anchor) sebab pesakit mungkin dah sahkan dalam tempoh
        // antara fetch & hantar (terutama Mesej 2 eskalasi yang jaraknya lagi jauh).
        if (a.trigger_event === 'session_confirm' && anc.progressId) {
          const { data: freshRow } = await supabase.from('psy_plan_weekly_progress').select('patient_confirmed').eq('id', anc.progressId).maybeSingle()
          if (freshRow && freshRow.patient_confirmed !== null) continue
        }

        // Recipient — pesakit (lalai) atau coach pesakit (cth eskalasi Sesi Confirm).
        const toCoach = m.recipient === 'coach'
        const recipient = toCoach ? coachProfiles[p.coach_id] : null
        if (toCoach && !recipient) continue   // tiada coach ditugaskan — tiada sesiapa nak dihantar

        const vars = buildVars(p, anc.plan, coachNames[p.coach_id] || '')
        const text = fillTemplate(m.message_text || '', vars)
        const fullText = (m.content_type === 'link' && m.link_url) ? `${text}\n\n${m.link_label || m.link_url}\n${m.link_url}` : text
        const attachments = m.media_url ? [m.media_url] : []

        const inappUserId = toCoach ? recipient.id : p.user_id
        if (actions.includes('inapp') && inappUserId) {
          try { await supabase.from('psy_notifications').insert({ user_id: inappUserId, type: 'system', title: a.name, body: fullText.slice(0, 240) }) } catch (_) { /* */ }
          await logSend(supabase, a, p, 'inapp', fullText, 'sent', null, m.id)
        }
        if (actions.includes('whatsapp')) {
          const contact = toCoach ? { phone: recipient.phone, contactName: recipient.full_name } : resolveContact(p)
          const e164 = toE164(contact.phone)
          if (e164) {
            try {
              const cid = await upsertContact(locationId, e164, contact.contactName)
              if (cid) { await sendWA(cid, fullText, attachments); await logSend(supabase, a, p, 'whatsapp', fullText, 'sent', null, m.id) }
            } catch (e) { await logSend(supabase, a, p, 'whatsapp', fullText, 'failed', String((e as any)?.message || e), m.id) }
          }
        }
        sentSet.add(dedupKey)
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
    const sequences = await runSequenceAutomations(supabase, locationId)
    return new Response(JSON.stringify({ success: true, scheduled, sequences }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (err) {
    console.error('automations-runner error:', err)
    return new Response(JSON.stringify({ error: String((err as any)?.message || err) }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
