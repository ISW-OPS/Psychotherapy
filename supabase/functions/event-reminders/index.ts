// ============================================================
// event-reminders — RUNNER auto-mesej (COPY-PASTE, cors inline).
// Cetus tiap 15 min oleh cron. Proses:
//   1) event_reminder       — peringatan kpd pendaftar sebelum acara
//   2) recurring_broadcast  — broadcast berulang (cth Manzil) ikut hari+masa
//      ke semua sasaran: WhatsApp + loceng + auto-Pengumuman
//   3) catatan_harian       — WA kpd pesakit yg belum isi Catatan Harian
//   4) kepatuhan_alert     — alert gabungan kpd COACH (amalan/checklist/skor/
//      bacaan); psy_risk_alerts + loceng + email via GHL; dedup 1×/mgg/pesakit
//   5) automations         — psy_automations (trigger 'schedule')
//   6) session_confirm     — Pengesahan Sesi (dua-hala): peringatan sahkan
//      kehadiran/tukar tarikh + escalation coach bila belum sahkan ≤ deadline
// Konfig semua dari psy_auto_messages (boleh ubah di UI).
// Secrets: GHL_ISW_TOKEN, GHL_ISW_LOCATION_ID, CRON_SECRET
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

function leadLabel(min) {
  if (!min) return 'sebentar'
  if (min >= 60) return min % 60 === 0 ? `${min / 60} jam` : `${Math.floor(min / 60)} jam ${min % 60} minit`
  return `${min} minit`
}
function fmtClock(min) {
  let h = Math.floor(min / 60), m = min % 60
  const ap = h >= 12 ? 'PTG' : 'PG'
  let hh = h % 12; if (hh === 0) hh = 12
  return `${hh}:${String(m).padStart(2, '0')} ${ap}`
}
function toE164(raw) {
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
function resolveContact(p) {
  if (p.contact_preference === 'waris' && p.emergency_contact_phone) {
    return { phone: p.emergency_contact_phone, contactName: p.emergency_contact_name || p.full_name }
  }
  return { phone: p.phone, contactName: p.full_name }
}
function fillTemplate(tpl, vars) {
  return Object.entries(vars).reduce((s, [k, v]) => s.split(`{${k}}`).join(v ?? ''), tpl).replace(/\n{3,}/g, '\n\n').trim()
}

async function ghl(path, init = {}) {
  const token = Deno.env.get('GHL_ISW_TOKEN')
  const res = await fetch(`${GHL_BASE}${path}`, { ...init, headers: { Authorization: `Bearer ${token}`, Version: GHL_VERSION, 'Content-Type': 'application/json', Accept: 'application/json', ...(init.headers || {}) } })
  const text = await res.text()
  let body = null
  try { body = text ? JSON.parse(text) : null } catch { body = text }
  if (!res.ok) throw new Error(`GHL ${path} ${res.status}: ${typeof body === 'string' ? body : JSON.stringify(body)}`)
  return body
}
async function upsertContact(locationId, phone, name) {
  const [firstName, ...rest] = String(name || '').trim().split(/\s+/)
  const r = await ghl('/contacts/upsert', { method: 'POST', body: JSON.stringify({ locationId, phone, firstName: firstName || undefined, lastName: rest.join(' ') || undefined, name: name || undefined }) })
  return r?.contact?.id || r?.id
}
async function sendWA(contactId, message) {
  return ghl('/conversations/messages', { method: 'POST', body: JSON.stringify({ type: 'SMS', contactId, message }) })
}
async function upsertEmailContact(locationId, email, name) {
  const r = await ghl('/contacts/upsert', { method: 'POST', body: JSON.stringify({ locationId, email, name: name || undefined }) })
  return r?.contact?.id || r?.id
}
async function sendEmail(contactId, subject, html, emailFrom) {
  const payload = { type: 'Email', contactId, subject, html }
  if (emailFrom) payload.emailFrom = emailFrom
  return ghl('/conversations/messages', { method: 'POST', body: JSON.stringify(payload) })
}

// ───────── 1) Peringatan acara (kpd pendaftar) ─────────
async function runEventReminders(supabase, locationId) {
  const { data: cfg } = await supabase.from('psy_auto_messages').select('*').eq('key', 'event_reminder').maybeSingle()
  if (!cfg || !cfg.is_active) return { skipped: true }
  const beforeMin = cfg.minutes_before ?? 30
  const lead = leadLabel(beforeMin)
  const now = Date.now()
  const t1 = new Date(now + (beforeMin - WINDOW_HALF_MIN) * 60000).toISOString()
  const t2 = new Date(now + (beforeMin + WINDOW_HALF_MIN) * 60000).toISOString()
  const { data: events } = await supabase.from('psy_events').select('id, title, start_at, mode, meet_link, location, maps_url').eq('status', 'published').gte('start_at', t1).lte('start_at', t2)
  if (!events?.length) return { due: 0, sent: 0 }
  const evMap = Object.fromEntries(events.map((e) => [e.id, e]))
  const { data: regs } = await supabase.from('psy_event_registrations').select('id, event_id, psy_patients(phone, full_name, emergency_contact_phone, emergency_contact_name, contact_preference)').in('event_id', events.map((e) => e.id)).is('reminder_sent_at', null).neq('status', 'batal')
  let sent = 0, skipped = 0
  const errors = []
  for (const r of regs || []) {
    const ev = evMap[r.event_id]; const p = r.psy_patients || {}; const { phone: rawPhone, contactName } = resolveContact(p); const phone = toE164(rawPhone)
    if (!ev || !phone) { skipped++; continue }
    try {
      const cid = await upsertContact(locationId, phone, contactName)
      if (!cid) throw new Error('no contactId')
      const when = new Date(ev.start_at).toLocaleString('ms-MY', { dateStyle: 'medium', timeStyle: 'short' })
      const pautan = ev.mode === 'f2f' ? [ev.location, ev.maps_url].filter(Boolean).join('\n') : (ev.meet_link || '')
      const msg = fillTemplate(cfg.message_template, { nama: p.full_name || '', acara: ev.title || '', masa: when, lead, pautan })
      await sendWA(cid, msg)
      await supabase.from('psy_event_registrations').update({ reminder_sent_at: new Date().toISOString() }).eq('id', r.id)
      sent++
    } catch (e) { errors.push(`${r.id}: ${String(e?.message || e)}`) }
  }
  return { due: events.length, sent, skipped, errors }
}

// ───────── 2) Broadcast berulang ─────────
function endOfTodayMyIso() {
  const d = new Date(Date.now() + MY_OFFSET_MS).toISOString().slice(0, 10)
  return new Date(`${d}T23:59:00+08:00`).toISOString()
}
async function runBroadcasts(supabase, locationId) {
  const { data: msgs } = await supabase.from('psy_auto_messages').select('*').eq('trigger_type', 'recurring_broadcast').eq('is_active', true)
  if (!msgs?.length) return []
  const myNow = new Date(Date.now() + MY_OFFSET_MS)
  const myDow = myNow.getUTCDay()
  const myDate = myNow.toISOString().slice(0, 10)
  const nowMin = myNow.getUTCHours() * 60 + myNow.getUTCMinutes()
  const out = []
  for (const m of msgs) {
    const days = Array.isArray(m.days_of_week) ? m.days_of_week : []
    if (!days.includes(myDow) || !m.session_time) continue
    const [sh, sm] = String(m.session_time).split(':').map(Number)
    const sessionMin = sh * 60 + sm
    const sendMin = sessionMin - (m.minutes_before ?? 0)
    if (Math.abs(nowMin - sendMin) > WINDOW_HALF_MIN) continue
    if (m.last_broadcast_at) {
      const lastMy = new Date(new Date(m.last_broadcast_at).getTime() + MY_OFFSET_MS).toISOString().slice(0, 10)
      if (lastMy === myDate) continue
    }
    // Tuntut slot dulu (elak double-send kalau timeout)
    await supabase.from('psy_auto_messages').update({ last_broadcast_at: new Date().toISOString() }).eq('id', m.id)
    out.push({ key: m.key, ...(await broadcastOne(supabase, locationId, m, sessionMin)) })
  }
  return out
}
async function broadcastOne(supabase, locationId, m, sessionMin) {
  const channels = Array.isArray(m.channels) ? m.channels : []
  const lead = leadLabel(m.minutes_before ?? 0)
  const masa = fmtClock(sessionMin)
  const link = m.link || ''
  const pkgs = Array.isArray(m.package_ids) ? m.package_ids : []
  const render = (name) => fillTemplate(m.message_template, { nama: name || '', masa, lead, pautan: link })

  const { data: pats } = await supabase.from('psy_patients').select('id, user_id, full_name, phone, active_package_id, emergency_contact_phone, emergency_contact_name, contact_preference')
  let targets = pats || []
  if (pkgs.length) targets = targets.filter((p) => p.active_package_id && pkgs.includes(p.active_package_id))

  const res = { targets: targets.length, whatsapp: 0, inapp: 0, announcement: 0, errors: [] }

  if (channels.includes('inapp')) {
    const rows = targets.filter((p) => p.user_id).map((p) => ({ user_id: p.user_id, type: 'system', title: m.name, body: render(p.full_name).slice(0, 240), link: link || 'events.html' }))
    if (rows.length) { try { await supabase.from('psy_notifications').insert(rows); res.inapp = rows.length } catch (e) { res.errors.push('inapp: ' + String(e?.message || e)) } }
  }
  if (channels.includes('announcement')) {
    try {
      await supabase.from('psy_announcements').insert({
        title: m.name, body: render('').replace(/^Salam\s*\S*\s*/, ''), category: 'Komuniti', tag: 'Komuniti',
        audience: m.audience || ['patient'], package_ids: pkgs,
        cta_label: link ? 'Sertai Sekarang' : null, cta_url: link || null,
        is_active: true, expires_at: endOfTodayMyIso(),
      })
      res.announcement = 1
    } catch (e) { res.errors.push('announcement: ' + String(e?.message || e)) }
  }
  if (channels.includes('whatsapp')) {
    const withPhone = targets.map((p) => ({ ...p, ...resolveContact(p), e164: toE164(resolveContact(p).phone) })).filter((p) => p.e164)
    const BATCH = 15
    for (let i = 0; i < withPhone.length; i += BATCH) {
      const chunk = withPhone.slice(i, i + BATCH)
      await Promise.all(chunk.map(async (p) => {
        try { const cid = await upsertContact(locationId, p.e164, p.contactName); if (cid) { await sendWA(cid, render(p.full_name)); res.whatsapp++ } }
        catch (e) { res.errors.push(`${p.id}: ${String(e?.message || e)}`) }
      }))
    }
  }
  return res
}

// ───────── 3) Peringatan Catatan Harian (kpd yang belum isi) ─────────
// daily_reminder: pada send_at_time (cth 20:00), hantar WA kpd pesakit
// aktif yang BELUM isi psy_kepatuhan_log hari ini. Dedup 1×/hari guna
// last_broadcast_at. days_of_week optional (null = setiap hari).
async function runCatatanHarianReminder(supabase, locationId) {
  const { data: cfg } = await supabase.from('psy_auto_messages').select('*').eq('key', 'catatan_harian').maybeSingle()
  if (!cfg || !cfg.is_active) return { skipped: true }
  if (!cfg.send_at_time) return { skipped: 'no time' }
  const myNow = new Date(Date.now() + MY_OFFSET_MS)
  const myDate = myNow.toISOString().slice(0, 10)
  const nowMin = myNow.getUTCHours() * 60 + myNow.getUTCMinutes()
  const [sh, sm] = String(cfg.send_at_time).split(':').map(Number)
  if (Math.abs(nowMin - (sh * 60 + sm)) > WINDOW_HALF_MIN) return { due: 0 }
  const days = Array.isArray(cfg.days_of_week) ? cfg.days_of_week : null
  if (days && days.length && !days.includes(myNow.getUTCDay())) return { due: 0 }
  // Dedup harian
  if (cfg.last_broadcast_at) {
    const lastMy = new Date(new Date(cfg.last_broadcast_at).getTime() + MY_OFFSET_MS).toISOString().slice(0, 10)
    if (lastMy === myDate) return { alreadySent: true }
  }
  await supabase.from('psy_auto_messages').update({ last_broadcast_at: new Date().toISOString() }).eq('id', cfg.id)
  // Pesakit dalam rawatan aktif (ada pakej, belum tamat)
  const { data: pats } = await supabase.from('psy_patients')
    .select('id, full_name, phone, active_package_id, package_expires_at, status, emergency_contact_phone, emergency_contact_name, contact_preference')
    .neq('status', 'deleted').neq('status', 'rejected')
  const nowIso = new Date().toISOString()
  let targets = (pats || []).filter((p) => p.active_package_id && (!p.package_expires_at || p.package_expires_at >= nowIso))
  // Tolak yang sudah isi hari ini
  const { data: filled } = await supabase.from('psy_kepatuhan_log').select('patient_id').eq('log_date', myDate)
  const done = new Set((filled || []).map((r) => r.patient_id))
  targets = targets.filter((p) => !done.has(p.id))
  const withPhone = targets.map((p) => ({ ...p, ...resolveContact(p), e164: toE164(resolveContact(p).phone) })).filter((p) => p.e164)
  const res = { targets: withPhone.length, sent: 0, errors: [] }
  const BATCH = 15
  for (let i = 0; i < withPhone.length; i += BATCH) {
    const chunk = withPhone.slice(i, i + BATCH)
    await Promise.all(chunk.map(async (p) => {
      try { const cid = await upsertContact(locationId, p.e164, p.contactName); if (cid) { await sendWA(cid, fillTemplate(cfg.message_template, { nama: p.full_name || '' })); res.sent++ } }
      catch (e) { res.errors.push(`${p.id}: ${String(e?.message || e)}`) }
    }))
  }
  return res
}

// ───────── 4) Alert Kepatuhan kepada COACH (gabungan multi-check) ─────────
// Setiap malam, untuk setiap pesakit aktif (ada coach), nilai beberapa check
// dari rule.checks → gabung jadi SATU alert (risk_alert + loceng + email).
// Checks: amalan (item checklist tak dibuat / bawah sasaran), checklist
// (hari tak isi Catatan Harian), skor (Pilihan B < min_score), vitals
// (tiada bacaan kesihatan dlm N hari). Dedup 1×/minggu/pesakit.
async function runKepatuhanAlerts(supabase, locationId) {
  const { data: cfg } = await supabase.from('psy_auto_messages').select('*').eq('key', 'kepatuhan_alert').maybeSingle()
  if (!cfg || !cfg.is_active) return { skipped: true }
  if (!cfg.send_at_time) return { skipped: 'no time' }
  const myNow = new Date(Date.now() + MY_OFFSET_MS)
  const myDate = myNow.toISOString().slice(0, 10)
  const nowMin = myNow.getUTCHours() * 60 + myNow.getUTCMinutes()
  const [sh, sm] = String(cfg.send_at_time).split(':').map(Number)
  if (Math.abs(nowMin - (sh * 60 + sm)) > WINDOW_HALF_MIN) return { due: 0 }
  const days = Array.isArray(cfg.days_of_week) ? cfg.days_of_week : null
  if (days && days.length && !days.includes(myNow.getUTCDay())) return { due: 0 }
  // Jalan sekali sehari sahaja (claim DULU elak double-run dlm window)
  if (cfg.last_broadcast_at) {
    const lastMy = new Date(new Date(cfg.last_broadcast_at).getTime() + MY_OFFSET_MS).toISOString().slice(0, 10)
    if (lastMy === myDate) return { alreadyRan: true }
  }
  await supabase.from('psy_auto_messages').update({ last_broadcast_at: new Date().toISOString() }).eq('id', cfg.id)

  const rule = cfg.rule || {}
  const checks = rule.checks || {}
  const windowDays = Number(rule.window_days ?? 7)
  const severity = ['low', 'medium', 'high', 'critical'].includes(rule.severity) ? rule.severity : 'high'
  const channels = Array.isArray(cfg.channels) ? cfg.channels : []
  const wantInapp = channels.includes('inapp')
  const wantEmail = channels.includes('email')
  const emailFrom = rule.email_from || Deno.env.get('GHL_EMAIL_FROM') || ''
  const cAmalan = checks.amalan || { on: true, min_days_short: 3 }
  const cChecklist = checks.checklist || { on: true, min_days_missing: 3 }
  const cSkor = checks.skor || { on: true, min_score: 80 }
  const cVitals = checks.vitals || { on: true, min_days_since: 7 }

  const dateStr = (offset) => new Date(myNow.getTime() - offset * 86400000).toISOString().slice(0, 10)
  const startWin = dateStr(windowDays - 1)
  const weekAgoIso = new Date(Date.now() - 7 * 86400000).toISOString()

  // Item checklist yang boleh diskor (label + target madu dari meta)
  const { data: items } = await supabase.from('psy_kepatuhan_item').select('item_key, label, jenis_input, meta, aktif, berskor')
  const itemMap = {}
  for (const it of (items || [])) {
    if (it.aktif === false || it.berskor === false) continue
    if (!['kiraan', 'pilih_satu'].includes(it.jenis_input)) continue
    if (!itemMap[it.item_key]) itemMap[it.item_key] = { label: it.label, jenis: it.jenis_input, target: Number(it?.meta?.target ?? 0) }
  }

  // Pesakit aktif yang ADA coach di-assign
  const { data: pats } = await supabase.from('psy_patients')
    .select('id, full_name, coach_id, active_package_id, package_expires_at, status')
    .neq('status', 'deleted').neq('status', 'rejected')
  const nowIso = new Date().toISOString()
  const targets = (pats || []).filter((p) => p.active_package_id && p.coach_id && (!p.package_expires_at || p.package_expires_at >= nowIso))
  if (!targets.length) return { patients: 0 }
  const ids = targets.map((p) => p.id)

  // Log kepatuhan dalam tetingkap
  const { data: logs } = await supabase.from('psy_kepatuhan_log')
    .select('patient_id, log_date, skor_harian, jawapan').gte('log_date', startWin).lte('log_date', myDate).in('patient_id', ids)
  const logsByPat = {}
  for (const l of (logs || [])) { (logsByPat[l.patient_id] ||= []).push(l) }

  // Bacaan kesihatan terkini (dlm N hari)
  const sinceN = Number(cVitals.min_days_since ?? 7)
  const { data: vitals } = await supabase.from('psy_vitals')
    .select('patient_id, reading_date').gte('reading_date', dateStr(sinceN - 1)).in('patient_id', ids)
  const vitalRecent = new Set((vitals || []).map((v) => v.patient_id))

  const emailCache = new Map()
  async function coachEmail(coachId) {
    if (emailCache.has(coachId)) return emailCache.get(coachId)
    let email = null
    try { const { data: prof } = await supabase.from('psy_profiles').select('email').eq('id', coachId).maybeSingle(); email = prof?.email || null } catch { /* no email col */ }
    if (!email) { try { const { data } = await supabase.auth.admin.getUserById(coachId); email = data?.user?.email || null } catch { email = null } }
    emailCache.set(coachId, email)
    return email
  }

  const res = { patients: targets.length, flagged: 0, alerts: 0, bells: 0, emails: 0, errors: [] }
  for (const p of targets) {
    const plogs = logsByPat[p.id] || []
    const filledDates = new Set(plogs.map((l) => l.log_date))
    const issues = []

    // 1) Amalan tidak dipatuhi (per item: 'tidak' / bawah sasaran)
    if (cAmalan.on !== false) {
      const minShort = Number(cAmalan.min_days_short ?? 3)
      const shortCount = {}
      for (const l of plogs) {
        const j = l.jawapan || {}
        for (const key in itemMap) {
          if (!(key in j)) continue
          const def = itemMap[key]; const v = j[key]
          const short = def.jenis === 'kiraan' ? (Number(v ?? 0) < (def.target > 0 ? def.target : 5)) : (v === 'tidak' || v == null || v === '')
          if (short) shortCount[key] = (shortCount[key] || 0) + 1
        }
      }
      for (const key in shortCount) {
        if (shortCount[key] < minShort) continue
        const def = itemMap[key]
        const word = def.jenis === 'kiraan' ? 'bawah sasaran' : 'tidak dilakukan'
        issues.push(`${def.label} — ${word} ${shortCount[key]} hari`)
      }
    }

    // 2) Tidak isi Catatan Harian (kira hari lepas, kecuali hari ini)
    if (cChecklist.on !== false) {
      let missing = 0
      for (let off = 1; off <= windowDays - 1; off++) { if (!filledDates.has(dateStr(off))) missing++ }
      if (missing >= Number(cChecklist.min_days_missing ?? 3)) issues.push(`Tidak isi Catatan Harian — ${missing} hari`)
    }

    // 3) Skor kepatuhan rendah (Pilihan B: Σ skor_harian ÷ windowDays)
    if (cSkor.on !== false) {
      const minScore = Number(cSkor.min_score ?? 80)
      let sum = 0
      for (const l of plogs) sum += Number(l.skor_harian || 0)
      const score = Math.round(sum / windowDays)
      if (score < minScore) issues.push(`Skor kepatuhan minggu ini — ${score}% (bawah ${minScore}%)`)
    }

    // 4) Tidak rekod bacaan kesihatan
    if (cVitals.on !== false && !vitalRecent.has(p.id)) {
      issues.push(`Tidak rekod bacaan kesihatan — tiada dalam ${sinceN} hari`)
    }

    if (!issues.length) continue
    res.flagged++
    // Dedup mingguan/pesakit
    const { data: existing } = await supabase.from('psy_risk_alerts')
      .select('id').eq('patient_id', p.id).eq('category', 'kepatuhan').gte('created_at', weekAgoIso).limit(1)
    if (existing && existing.length) continue

    const senarai = issues.map((i) => `• ${i}`).join('\n')
    const desc = `Pesakit ${p.full_name || 'ini'} perlu perhatian — ${issues.join('; ')}.`
    try {
      await supabase.from('psy_risk_alerts').insert({
        patient_id: p.id, patient_name: p.full_name, severity, category: 'kepatuhan',
        description: desc, status: 'open', created_by_name: 'Sistem (Auto-Kepatuhan)',
      })
      res.alerts++
    } catch (e) { res.errors.push(`alert ${p.id}: ${String(e?.message || e)}`); continue }
    if (wantInapp) {
      try {
        await supabase.from('psy_notifications').insert({
          user_id: p.coach_id, type: 'system',
          title: `⚠️ Kepatuhan rendah: ${p.full_name || 'Pesakit'}`,
          body: desc.slice(0, 240), link: '/roles/staff/risk.html',
        })
        res.bells++
      } catch (e) { res.errors.push(`bell ${p.id}: ${String(e?.message || e)}`) }
    }
    if (wantEmail) {
      try {
        const email = await coachEmail(p.coach_id)
        if (email) {
          const cid = await upsertEmailContact(locationId, email, null)
          if (cid) {
            const subject = `⚠️ Alert Kepatuhan — ${p.full_name || 'Pesakit'}`
            const body = fillTemplate(cfg.message_template, { nama: p.full_name || 'Pesakit', senarai })
            await sendEmail(cid, subject, body.replace(/\n/g, '<br>'), emailFrom)
            res.emails++
          }
        }
      } catch (e) { res.errors.push(`email ${p.id}: ${String(e?.message || e)}`) }
    }
  }
  return res
}

// ───────── 5) Automasi (psy_automations) — Broadcast Berjadual ─────────
// Baca automasi AKTIF trigger 'schedule' → hari+masa (dedup 1×/hari) → tapis
// conditions → hantar actions (whatsapp/inapp) → tulis psy_notification_logs.
function fillAuto(tpl, vars) {
  return Object.entries(vars).reduce((s, [k, v]) => s.split(`{{${k}}}`).join(v ?? '').split(`{${k}}`).join(v ?? ''), tpl || '').replace(/\n{3,}/g, '\n\n').trim()
}
// Pemalar klinik (sumber: shared/letterTemplates.js)
const ISW_CLINIC = { name: 'Ibnu Sina Wellness', phone: '03-8966 3702', address: 'Lot 331, Lorong Senyum Matahari B, Country Heights, 43000 Kajang, Selangor.' }
function fmtDateMs(d) { if (!d) return ''; try { return new Date(d).toLocaleDateString('ms-MY', { day: '2-digit', month: 'short', year: 'numeric' }) } catch (_) { return '' } }
// Bina objek pembolehubah (variables) untuk seorang pesakit — kunci Melayu, sumber data sebenar
function buildPatientVars(p, coachMap, pkgWeeksMap, planMap, upcomingMap) {
  const now = new Date()
  const age = p.date_of_birth ? Math.floor((Date.now() - new Date(p.date_of_birth).getTime()) / 31557600000) : ''
  const plan = planMap[p.id]
  const totalWeeks = (pkgWeeksMap[p.active_package_id] ?? plan?.duration_weeks ?? '')
  const upc = upcomingMap?.[p.id]
  return {
    nama: p.full_name || '', mrn: p.mrn || '', ic: p.ic_number || '', telefon: p.phone || '', emel: p.email || '',
    jantina: p.gender === 'M' ? 'Lelaki' : p.gender === 'F' ? 'Perempuan' : '', negeri: p.state || '', umur: age === '' ? '' : String(age),
    pakej: p.active_package_name || '', kod_pakej: p.active_package_id || '',
    minggu: plan?.current_week != null ? String(plan.current_week) : '', jumlah_minggu: totalWeeks !== '' ? String(totalWeeks) : '',
    tarikh_mula: fmtDateMs(p.package_purchased_at), tarikh_tamat: fmtDateMs(p.package_expires_at),
    coach: coachMap[p.coach_id] || '', nama_klinik: ISW_CLINIC.name, telefon_klinik: ISW_CLINIC.phone, alamat_klinik: ISW_CLINIC.address,
    tarikh: fmtDateMs(now), masa: now.toLocaleTimeString('ms-MY', { hour: '2-digit', minute: '2-digit' }),
    hari: now.toLocaleDateString('ms-MY', { weekday: 'long' }), tahun: String(now.getFullYear()), bulan: now.toLocaleDateString('ms-MY', { month: 'long' }),
    // Temujanji (sesi rawatan akan datang terdekat) — kosong jika tiada sesi 'booked'
    sesi_akan_datang: upc ? sessLabel(upc.week_number, upc.session_day) : '',
    tarikh_sesi: upc ? fmtSessDate(upc.session_date) : '', masa_sesi: upc ? fmtSessTime(upc.session_date) : '',
  }
}
function applyConds(pats, conds) {
  let t = pats
  for (const c of conds || []) {
    if (c.field === 'patient_status') t = t.filter((p) => (c.value === 'active') ? p.status === 'active' : p.status !== 'active')
    else if (c.field === 'gender') t = t.filter((p) => p.gender === c.value)
    else if (c.field === 'has_whatsapp') t = t.filter((p) => (c.value === 'yes') ? !!resolveContact(p).phone : !resolveContact(p).phone)
    else if (c.field === 'package') { const arr = Array.isArray(c.value) ? c.value : [c.value]; t = t.filter((p) => arr.includes(p.active_package_id)) }
    else if (c.field === 'state') { const arr = Array.isArray(c.value) ? c.value : [c.value]; t = t.filter((p) => arr.includes(p.state)) }
    else if (c.field === 'age') { const mn = c.value?.min, mx = c.value?.max; t = t.filter((p) => { if (!p.date_of_birth) return false; const age = Math.floor((Date.now() - new Date(p.date_of_birth).getTime()) / 31557600000); return (mn == null || age >= mn) && (mx == null || age <= mx) }) }
    else if (c.field === 'registered') { const f = c.value?.from, u = c.value?.to; t = t.filter((p) => { const d = (p.created_at || '').slice(0, 10); if (f && d < f) return false; if (u && d > u) return false; return true }) }
  }
  return t
}
async function logAuto(supabase, a, p, channel, message, status, error) {
  try {
    await supabase.from('psy_notification_logs').insert({
      automation_id: a.id, patient_id: p.id, patient_name: p.full_name, event: a.trigger_event,
      channel, status, message: (message || '').slice(0, 2000), error, sent_at: status === 'sent' ? new Date().toISOString() : null,
    })
  } catch (_) { /* jangan halang */ }
}
async function runAutomationOne(supabase, locationId, a) {
  const actions = Array.isArray(a.actions) ? a.actions : []
  const conds = (a.conditions_enabled && Array.isArray(a.conditions)) ? a.conditions : []
  const { data: pats } = await supabase.from('psy_patients')
    .select('id, user_id, full_name, phone, email, gender, status, active_package_id, active_package_name, package_purchased_at, package_expires_at, mrn, ic_number, coach_id, state, date_of_birth, created_at, emergency_contact_phone, emergency_contact_name, contact_preference').neq('status', 'deleted').neq('status', 'rejected')
  const targets = applyConds(pats || [], conds)
  // Lookup untuk pembolehubah: coach, jumlah minggu pakej, minggu semasa, sesi akan datang
  const coachMap = {}, pkgWeeksMap = {}, planMap = {}, upcomingMap = {}
  try {
    const coachIds = [...new Set(targets.map((p) => p.coach_id).filter(Boolean))]
    if (coachIds.length) { const { data } = await supabase.from('psy_profiles').select('id, full_name').in('id', coachIds); (data || []).forEach((c) => coachMap[c.id] = c.full_name) }
    const { data: pkgs } = await supabase.from('psy_packages').select('id, package_id, duration_weeks'); (pkgs || []).forEach((pk) => { if (pk.package_id) pkgWeeksMap[pk.package_id] = pk.duration_weeks; if (pk.id) pkgWeeksMap[pk.id] = pk.duration_weeks })
    const pids = targets.map((p) => p.id)
    if (pids.length) {
      const { data: plans } = await supabase.from('psy_treatment_plans').select('patient_id, current_week, duration_weeks').eq('status', 'active').in('patient_id', pids); (plans || []).forEach((pl) => { if (!planMap[pl.patient_id]) planMap[pl.patient_id] = pl })
      const { data: upc } = await supabase.from('psy_plan_weekly_progress').select('patient_id, week_number, session_day, session_date').eq('status', 'booked').gt('session_date', new Date().toISOString()).in('patient_id', pids).order('session_date', { ascending: true })
      ;(upc || []).forEach((u) => { if (!upcomingMap[u.patient_id]) upcomingMap[u.patient_id] = u })
    }
  } catch (_) { /* lookup pilihan — jangan halang hantar */ }
  const render = (p) => fillAuto(a.message_template || '', buildPatientVars(p, coachMap, pkgWeeksMap, planMap, upcomingMap))
  const res = { targets: targets.length, whatsapp: 0, inapp: 0, email: 0, failed: 0 }
  if (actions.includes('inapp')) {
    const withAcct = targets.filter((p) => p.user_id)
    if (withAcct.length) {
      try { await supabase.from('psy_notifications').insert(withAcct.map((p) => ({ user_id: p.user_id, type: 'system', title: a.name, body: render(p).slice(0, 240) }))); res.inapp = withAcct.length } catch (_) { }
      for (const p of withAcct) await logAuto(supabase, a, p, 'inapp', render(p), 'sent', null)
    }
  }
  if (actions.includes('whatsapp')) {
    const withPhone = targets.map((p) => ({ ...p, ...resolveContact(p), e164: toE164(resolveContact(p).phone) })).filter((p) => p.e164)
    const BATCH = 15
    for (let i = 0; i < withPhone.length; i += BATCH) {
      await Promise.all(withPhone.slice(i, i + BATCH).map(async (p) => {
        const msg = render(p)
        try { const cid = await upsertContact(locationId, p.e164, p.contactName); if (cid) { await sendWA(cid, msg); res.whatsapp++; await logAuto(supabase, a, p, 'whatsapp', msg, 'sent', null) } }
        catch (e) { res.failed++; await logAuto(supabase, a, p, 'whatsapp', msg, 'failed', String(e?.message || e)) }
      }))
    }
  }
  if (actions.includes('email')) {
    const emailFrom = Deno.env.get('GHL_EMAIL_FROM') || ''
    const withEmail = targets.filter((p) => p.email)
    for (const p of withEmail) {
      const msg = render(p)
      try { const cid = await upsertEmailContact(locationId, p.email, p.full_name); if (cid) { await sendEmail(cid, a.name, msg.replace(/\n/g, '<br>'), emailFrom); res.email++; await logAuto(supabase, a, p, 'email', msg, 'sent', null) } }
      catch (e) { res.failed++; await logAuto(supabase, a, p, 'email', msg, 'failed', String(e?.message || e)) }
    }
  }
  return res
}
async function runScheduledAutomations(supabase, locationId) {
  const { data: autos } = await supabase.from('psy_automations').select('*').eq('is_active', true).eq('trigger_category', 'schedule')
  const myNow = new Date(Date.now() + MY_OFFSET_MS)
  const myDow = myNow.getUTCDay(), myDate = myNow.toISOString().slice(0, 10)
  const nowMin = myNow.getUTCHours() * 60 + myNow.getUTCMinutes()
  const out = []
  for (const a of autos || []) {
    const t = a.trigger_timing || {}
    if (t.when !== 'schedule') continue
    const days = Array.isArray(t.days) ? t.days : []
    if (!days.includes(myDow) || !t.time) continue
    const [h, m] = String(t.time).split(':').map(Number)
    if (Math.abs(nowMin - (h * 60 + m)) > WINDOW_HALF_MIN) continue
    if (a.last_run_at) { const last = new Date(new Date(a.last_run_at).getTime() + MY_OFFSET_MS).toISOString().slice(0, 10); if (last === myDate) continue }
    await supabase.from('psy_automations').update({ last_run_at: new Date().toISOString() }).eq('id', a.id)
    out.push({ id: a.id, name: a.name, ...(await runAutomationOne(supabase, locationId, a)) })
  }
  return out
}

// ───────── 6) Pengesahan Sesi — peringatan (WA teks) + escalation ─────────
// Sebelum sesi rawatan: hantar peringatan WhatsApp minta pesakit BALAS TEKS
// untuk sahkan kehadiran (staff baca balasan & tandakan di kehadiran.html —
// butang "Tandakan Disahkan" / "Tukar Tarikh"). Notifikasi in-app turut
// dihantar dengan pautan ke plan.html (pesakit yang guna app boleh sahkan
// sendiri di sana — laluan pilihan, bukan wajib). Bila tinggal ≤
// deadline_hours (cth 24 jam) & masih belum ditandakan sahkan → alert COACH
// (psy_risk_alerts + loceng). Konfig psy_auto_messages key='session_confirm'.
// Dedup per-sesi: confirm_reminder_sent_at / confirm_escalated_at.
function sessLabel(w, d) { return `Minggu ${w} Sesi ${d || 1}` }
function fmtSessDate(iso) {
  const dt = new Date(new Date(iso).getTime() + MY_OFFSET_MS)
  const days = ['Ahad', 'Isnin', 'Selasa', 'Rabu', 'Khamis', 'Jumaat', 'Sabtu']
  const mons = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ogos', 'Sep', 'Okt', 'Nov', 'Dis']
  return `${days[dt.getUTCDay()]}, ${dt.getUTCDate()} ${mons[dt.getUTCMonth()]} ${dt.getUTCFullYear()}`
}
function fmtSessTime(iso) {
  const dt = new Date(new Date(iso).getTime() + MY_OFFSET_MS)
  return fmtClock(dt.getUTCHours() * 60 + dt.getUTCMinutes())
}
async function runSessionConfirm(supabase, locationId) {
  const { data: cfg } = await supabase.from('psy_auto_messages').select('*').eq('key', 'session_confirm').maybeSingle()
  if (!cfg || !cfg.is_active) return { skipped: true }
  const rule = cfg.rule || {}
  const leadDays = Number(rule.lead_days ?? 3)
  const deadlineHours = Number(rule.deadline_hours ?? 24)
  const channels = Array.isArray(cfg.channels) ? cfg.channels : ['whatsapp', 'inapp']
  const escalate = rule.escalate || { on: true, severity: 'medium' }
  const nowMs = Date.now()
  const nowIso = new Date(nowMs).toISOString()
  const deadlineIso = new Date(nowMs + deadlineHours * 3600000).toISOString()
  const leadIso = new Date(nowMs + leadDays * 86400000).toISOString()

  const reminder = { due: 0, whatsapp: 0, inapp: 0, errors: [] }
  const escal = { due: 0, alerts: 0, bells: 0, skippedNoCoach: 0, errors: [] }

  // ── A) PERINGATAN — sesi dalam (deadline, lead], belum sahkan, belum diingat ──
  // Time-gate ikut send_at_time supaya batch harian keluar waktu siang; dedup per-sesi.
  let sendWindowOk = true
  if (cfg.send_at_time) {
    const myNow = new Date(nowMs + MY_OFFSET_MS)
    const nowMin = myNow.getUTCHours() * 60 + myNow.getUTCMinutes()
    const [sh, sm] = String(cfg.send_at_time).split(':').map(Number)
    sendWindowOk = Math.abs(nowMin - (sh * 60 + sm)) <= WINDOW_HALF_MIN
  }
  if (sendWindowOk) {
    const { data: rows } = await supabase.from('psy_plan_weekly_progress')
      .select('id, week_number, session_day, session_date, patient_id, psy_patients(full_name, phone, user_id, emergency_contact_phone, emergency_contact_name, contact_preference)')
      .eq('status', 'booked').is('patient_confirmed', null).is('confirm_reminder_sent_at', null)
      .gt('session_date', deadlineIso).lte('session_date', leadIso).limit(500)
    reminder.due = (rows || []).length
    for (const r of rows || []) {
      const p = r.psy_patients || {}
      const vars = {
        nama: p.full_name || '', sesi_akan_datang: sessLabel(r.week_number, r.session_day),
        tarikh_sesi: fmtSessDate(r.session_date), masa_sesi: fmtSessTime(r.session_date),
        nama_klinik: ISW_CLINIC.name,
      }
      const msg = fillTemplate(cfg.message_template, vars)
      try {
        if (channels.includes('whatsapp')) {
          const { phone: rawPhone, contactName } = resolveContact(p)
          const e164 = toE164(rawPhone)
          if (e164) { const cid = await upsertContact(locationId, e164, contactName); if (cid) { await sendWA(cid, msg); reminder.whatsapp++ } }
        }
        if (channels.includes('inapp') && p.user_id) {
          await supabase.from('psy_notifications').insert({
            user_id: p.user_id, type: 'appointment',
            title: `Sahkan kehadiran — ${sessLabel(r.week_number, r.session_day)}`,
            body: `Sesi ${fmtSessDate(r.session_date)} · ${fmtSessTime(r.session_date)}. Sila sahkan atau tukar tarikh.`.slice(0, 240),
            link: `plan.html?confirm=${r.week_number}.${r.session_day || 1}`,
          })
          reminder.inapp++
        }
        await supabase.from('psy_plan_weekly_progress').update({ confirm_reminder_sent_at: new Date().toISOString() }).eq('id', r.id)
      } catch (e) { reminder.errors.push(`${r.id}: ${String(e?.message || e)}`) }
    }
  }

  // ── B) ESCALATION — sesi ≤ deadline, belum sahkan, belum escalate → alert coach ──
  if (escalate.on !== false) {
    const severity = ['low', 'medium', 'high', 'critical'].includes(escalate.severity) ? escalate.severity : 'medium'
    const { data: rows } = await supabase.from('psy_plan_weekly_progress')
      .select('id, week_number, session_day, session_date, patient_id, psy_patients(full_name, coach_id)')
      .eq('status', 'booked').is('patient_confirmed', null).is('confirm_escalated_at', null)
      .gt('session_date', nowIso).lte('session_date', deadlineIso).limit(500)
    escal.due = (rows || []).length
    for (const r of rows || []) {
      const p = r.psy_patients || {}
      // Tanda dulu (elak double walau tiada coach / gagal separuh)
      await supabase.from('psy_plan_weekly_progress').update({ confirm_escalated_at: new Date().toISOString() }).eq('id', r.id)
      if (!p.coach_id) { escal.skippedNoCoach++; continue }
      const label = sessLabel(r.week_number, r.session_day)
      const desc = `${p.full_name || 'Pesakit'} belum sahkan kehadiran ${label} (${fmtSessDate(r.session_date)} · ${fmtSessTime(r.session_date)}) — tinggal ≤ ${deadlineHours} jam.`
      try {
        await supabase.from('psy_risk_alerts').insert({
          patient_id: r.patient_id, patient_name: p.full_name, severity, category: 'temujanji',
          description: desc, status: 'open', created_by_name: 'Sistem (Pengesahan Sesi)',
        })
        escal.alerts++
        try {
          await supabase.from('psy_notifications').insert({
            user_id: p.coach_id, type: 'appointment',
            title: `⏳ Belum sahkan: ${p.full_name || 'Pesakit'}`,
            body: desc.slice(0, 240), link: '/roles/staff/kehadiran.html',
          })
          escal.bells++
        } catch (e) { escal.errors.push(`bell ${r.id}: ${String(e?.message || e)}`) }
      } catch (e) { escal.errors.push(`alert ${r.id}: ${String(e?.message || e)}`) }
    }
  }

  return { reminder, escalation: escal }
}

// ───────── 7) Auto Tidak Hadir — sesi lepas >24 jam belum direkod ─────────
// Sesi 'booked'/'pending' yang session_date dah lepas >24 jam & masih belum
// ditanda hadir/tidak-hadir oleh coach → auto-tanda 'cancel' (Tidak Hadir),
// notifikasi pesakit (minta hubungi coach) + loceng coach (segera hubungi
// pesakit & jadual semula). Tiada dedup khas — status 'cancel' terus keluar
// dari filter booked/pending pada run seterusnya.
async function runAutoAbsence(supabase) {
  const DEADLINE_HOURS = 24
  const cutoff = new Date(Date.now() - DEADLINE_HOURS * 3600000).toISOString()
  const { data: rows } = await supabase.from('psy_plan_weekly_progress')
    .select('id, week_number, session_day, plan_id, patient_id, session_date, psy_patients(full_name, coach_id, user_id)')
    .in('status', ['booked', 'pending']).lt('session_date', cutoff).limit(500)
  const res = { due: (rows || []).length, marked: 0, notified: 0, bells: 0, errors: [] }
  for (const r of rows || []) {
    const p = r.psy_patients || {}
    try {
      await supabase.from('psy_plan_weekly_progress').update({
        status: 'cancel', absence_reason: 'Tiada rekod kehadiran — auto-tanda selepas 24 jam',
        updated_by_name: 'Sistem (Auto-Kehadiran)', updated_at: new Date().toISOString(),
      }).eq('id', r.id)
      res.marked++
    } catch (e) { res.errors.push(`update ${r.id}: ${String(e?.message || e)}`); continue }
    if (p.user_id) {
      try {
        await supabase.from('psy_notifications').insert({
          user_id: p.user_id, type: 'plan', title: 'Sesi Ditanda Tidak Hadir',
          body: `Sesi Minggu ${r.week_number} anda ditanda tidak hadir (tiada rekod dalam 24 jam). Sila hubungi coach untuk jadual semula.`.slice(0, 240),
          link: 'plan.html',
        })
        res.notified++
      } catch (e) { res.errors.push(`notify-patient ${r.id}: ${String(e?.message || e)}`) }
    }
    if (p.coach_id) {
      try {
        await supabase.from('psy_notifications').insert({
          user_id: p.coach_id, type: 'appointment',
          title: `❌ Auto: Tidak Hadir — ${p.full_name || 'Pesakit'}`,
          body: `Sesi Minggu ${r.week_number} tak direkod >24 jam, auto-tanda tidak hadir. Sila hubungi pesakit & jadual semula.`.slice(0, 240),
          link: '/roles/staff/patient-hub.html?patient_id=' + r.patient_id,
        })
        res.bells++
      } catch (e) { res.errors.push(`bell ${r.id}: ${String(e?.message || e)}`) }
    }
  }
  return res
}

// ───────── 8) Peringatan Pengambilan Sampel DNA (sehari sebelum janji temu) ─────────
// psy_dna_test_process.sample_appointment_id (reuse psy_appointments) → hantar WA
// bila appointment_time jatuh dlm lead_days akan datang & belum diingat (dedup via
// sample_reminder_sent_at). Hanya proses yang masih Step 1 (belum kutip sampel).
async function runDnaSampleReminder(supabase, locationId) {
  const { data: cfg } = await supabase.from('psy_auto_messages').select('*').eq('key', 'dna_sample_reminder').maybeSingle()
  if (!cfg || !cfg.is_active) return { skipped: true }
  const leadDays = Number(cfg.rule?.lead_days ?? 1)
  const nowMs = Date.now()
  const leadIso = new Date(nowMs + leadDays * 86400000).toISOString()

  const { data: rows } = await supabase.from('psy_dna_test_process')
    .select('id, patient_id, sample_appointment_id, psy_patients(full_name, phone, emergency_contact_phone, emergency_contact_name, contact_preference)')
    .eq('current_step', 1).is('sample_reminder_sent_at', null).not('sample_appointment_id', 'is', null).limit(500)
  const res = { due: 0, sent: 0, errors: [] }
  if (!rows?.length) return res
  const apptIds = rows.map((r) => r.sample_appointment_id)
  const { data: appts } = await supabase.from('psy_appointments').select('id, appointment_time').in('id', apptIds)
  const apptMap = Object.fromEntries((appts || []).map((a) => [a.id, a]))

  for (const r of rows) {
    const appt = apptMap[r.sample_appointment_id]
    if (!appt || !appt.appointment_time) continue
    if (appt.appointment_time <= new Date(nowMs).toISOString() || appt.appointment_time > leadIso) continue
    res.due++
    const p = r.psy_patients || {}
    const { phone: rawPhone, contactName } = resolveContact(p)
    const phone = toE164(rawPhone)
    if (!phone) { res.errors.push(`${r.id}: tiada telefon`); continue }
    try {
      const cid = await upsertContact(locationId, phone, contactName)
      if (!cid) throw new Error('no contactId')
      const msg = fillTemplate(cfg.message_template, {
        nama: p.full_name || '', tarikh_sample: fmtSessDate(appt.appointment_time),
        masa_sample: fmtSessTime(appt.appointment_time), nama_klinik: ISW_CLINIC.name,
      })
      await sendWA(cid, msg)
      await supabase.from('psy_dna_test_process').update({ sample_reminder_sent_at: new Date().toISOString() }).eq('id', r.id)
      res.sent++
    } catch (e) { res.errors.push(`${r.id}: ${String(e?.message || e)}`) }
  }
  return res
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    if (req.headers.get('x-cron-secret') !== Deno.env.get('CRON_SECRET')) {
      return new Response(JSON.stringify({ error: 'forbidden' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
    const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))
    const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')
    const eventReminders = await runEventReminders(supabase, locationId)
    const broadcasts = await runBroadcasts(supabase, locationId)
    const catatanHarian = await runCatatanHarianReminder(supabase, locationId)
    const kepatuhanAlerts = await runKepatuhanAlerts(supabase, locationId)
    const automations = await runScheduledAutomations(supabase, locationId)
    const sessionConfirm = await runSessionConfirm(supabase, locationId)
    const autoAbsence = await runAutoAbsence(supabase)
    const dnaSampleReminder = await runDnaSampleReminder(supabase, locationId)
    return new Response(JSON.stringify({ success: true, eventReminders, broadcasts, catatanHarian, kepatuhanAlerts, automations, sessionConfirm, autoAbsence, dnaSampleReminder }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (err) {
    console.error('event-reminders error:', err)
    return new Response(JSON.stringify({ error: String(err?.message || err) }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
