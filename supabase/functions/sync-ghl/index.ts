// ============================================================
// Edge Function: sync-ghl
// Fasa 1 — Sync sehala status KOB (ISW → GoHighLevel).
//
// Dicetuskan oleh Supabase Database Webhook pada UPDATE/INSERT
// psy_patients. Bila kob_status bertukar, function ni:
//   1. Upsert contact dalam GHL ikut no. telefon (E.164)
//   2. Set custom fields (kob_stage, pakej, tarikh, MRN ...)
//   3. Gerak / cipta Opportunity ke pipeline stage yang padan
//
// Closer kekal di inbox WhatsApp GHL — konteks KOB auto-masuk.
//
// Secrets diperlukan (set via `supabase secrets set`):
//   GHL_ISW_TOKEN        — Private Integration token ISW (Bearer); nama tersendiri
//                          supaya tak timpa GHL_API_TOKEN integrasi lain
//   GHL_ISW_LOCATION_ID  — Location/Sub-account ID ISW (secret tersendiri,
//                          bukan GHL_LOCATION_ID integrasi lain)
//   GHL_PIPELINE_ID      — Pipeline ID untuk funnel KOB
//   SYNC_WEBHOOK_SECRET  — rahsia kongsi; webhook hantar header x-sync-secret
// ============================================================

import { corsHeaders } from '../_shared/cors.ts'

const GHL_BASE = 'https://services.leadconnectorhq.com'
const GHL_VERSION = '2021-07-28'

// ── MAPPING: kob_status → label + GHL pipeline stage ────────
// Isi STAGE_ID dengan ID stage sebenar dari pipeline GHL anda.
// Cara dapat ID: GET {GHL_BASE}/opportunities/pipelines?locationId=...
// (lihat README.md dalam folder ni untuk arahan penuh).
const STAGE_MAP: Record<string, { label: string; stageId: string }> = {
  pending_payment:     { label: 'Baru daftar — belum bayar KOB', stageId: 'FILL_STAGE_PENDING_PAYMENT' },
  paid:                { label: 'Bayar KOB — belum isi KYC',     stageId: 'FILL_STAGE_PAID' },
  kyc_done:            { label: 'KYC selesai — belum tempah',    stageId: 'FILL_STAGE_KYC_DONE' },
  booked:              { label: 'Slot KOB ditempah',             stageId: 'FILL_STAGE_BOOKED' },
  hadir:               { label: 'Hadir KOB (sesi berlangsung)',  stageId: 'FILL_STAGE_HADIR' },
  package_recommended: { label: 'Pakej dicadang — belum bayar',  stageId: 'FILL_STAGE_PKG_RECOMMENDED' },
  package_paid:        { label: 'Pakej dibayar',                 stageId: 'FILL_STAGE_PKG_PAID' },
  completed:           { label: 'KOB selesai — pakej aktif',     stageId: 'FILL_STAGE_COMPLETED' },
  na:                  { label: 'N/A (staff-created)',           stageId: '' }, // '' = skip opportunity
}

// ── Custom field KEYS dalam GHL ─────────────────────────────
// Cipta dulu custom fields ni di GHL (Settings → Custom Fields),
// guna key persis macam bawah (GHL prefix dgn "contact.").
const CF = {
  kobStage:     'kob_stage',
  kobStatus:    'kob_status_raw',
  package:      'kob_package',
  packageEnds:  'kob_package_expires',
  mrn:          'isw_mrn',
  kobDate:      'kob_session_date',
  regStatus:    'isw_registration_status',
  inSystem:     'pt_in_system',
}

// Status akaun pesakit (psy_patients.status) → binari mudah untuk
// automation GHL filter. BEZA dari kob_status (peringkat funnel KOB) —
// ni jawab "pesakit tu dah SIGNUP/daftar dalam ISW atau tak". Hanya
// status='active' (dah hantar borang pendaftaran) dikira "Active";
// semua status lain (pending_kyc/unregistered/inactive/dll) = "Not Active".
function registrationLabel(status: string | null | undefined): string {
  return status === 'active' ? 'Active' : 'Not Active'
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

// Format timestamp → waktu Malaysia, mudah dibaca closer: "26/07/2026, 10:00 am"
function fmtMYT(iso: string | null | undefined): string {
  if (!iso) return ''
  try {
    return new Intl.DateTimeFormat('en-GB', {
      timeZone: 'Asia/Kuala_Lumpur',
      day: '2-digit', month: '2-digit', year: 'numeric',
      hour: '2-digit', minute: '2-digit', hour12: true,
    }).format(new Date(iso))
  } catch { return String(iso) }
}

// Label tarikh sesi KOB utk custom field: tarikh + mod ("... (online)")
function kobDateLabel(scheduledAt: string | null | undefined, mode: string | null | undefined): string {
  const d = fmtMYT(scheduledAt)
  if (!d) return ''
  return `${d} (${mode === 'online' ? 'online' : 'fizikal'})`
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// Query Supabase REST guna service role (auto-injected oleh Supabase).
async function sbSelect(path: string): Promise<any[]> {
  const url = Deno.env.get('SUPABASE_URL')!
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const res = await fetch(`${url}/rest/v1/${path}`, {
    headers: { apikey: key, Authorization: `Bearer ${key}` },
  })
  if (!res.ok) throw new Error(`DB ${path} → ${res.status}: ${await res.text()}`)
  return res.json()
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
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { ...corsHeaders, 'Access-Control-Allow-Headers': 'content-type, x-sync-secret' } })
  }

  try {
    // ── 1. Sahkan webhook secret (elak orang luar panggil) ──
    const secret = req.headers.get('x-sync-secret')
    if (secret !== Deno.env.get('SYNC_WEBHOOK_SECRET')) {
      return new Response(JSON.stringify({ error: 'forbidden' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const payload = await req.json()
    // Supabase DB webhook shape: { type, table, record, old_record }
    const record = payload.record ?? payload
    const oldRecord = payload.old_record ?? null

    // ── Cabang ikut jadual sumber webhook ───────────────────
    if (payload.table === 'psy_kob_sessions') {
      return await handleKobSession(record, oldRecord)
    }

    // ── 2. Proses bila kob_status ATAU status pendaftaran berubah ──
    const status = record?.kob_status as string | undefined
    if (!status) {
      return new Response(JSON.stringify({ skipped: 'no kob_status' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    const regStatusChanged = !oldRecord || oldRecord.status !== record.status
    if (oldRecord && oldRecord.kob_status === status && !regStatusChanged) {
      return new Response(JSON.stringify({ skipped: 'kob_status & status unchanged' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const phone = toE164(record.phone)
    const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')!
    const stageInfo = STAGE_MAP[status] ?? { label: status, stageId: '' }

    if (!phone) {
      // Tiada phone → tak boleh match contact. Log & skip dengan elegan.
      return new Response(JSON.stringify({ skipped: 'no phone', patient: record.id }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ── 3. Upsert contact ikut phone + set custom fields ────
    // Tarikh sesi KOB terkini (booked/reschedule/hadir/completed) — jangan
    // gagalkan sync utama kalau lookup gagal.
    let kobDate = ''
    try {
      const sessions = await sbSelect(
        `psy_kob_sessions?patient_id=eq.${record.id}` +
        `&status=in.(booked,reschedule,hadir,completed)` +
        `&order=scheduled_at.desc&limit=1&select=scheduled_at,mode`,
      )
      if (sessions?.[0]) kobDate = kobDateLabel(sessions[0].scheduled_at, sessions[0].mode)
    } catch (e) { console.error('sync-ghl: kob date lookup failed:', e) }

    const [firstName, ...rest] = String(record.full_name || '').trim().split(/\s+/)
    const upsertBody = {
      locationId,
      phone,
      firstName: firstName || undefined,
      lastName: rest.join(' ') || undefined,
      name: record.full_name || undefined,
      customFields: [
        { key: CF.kobStage,    field_value: stageInfo.label },
        { key: CF.kobStatus,   field_value: status },
        { key: CF.package,     field_value: record.active_package_name || '' },
        { key: CF.packageEnds, field_value: record.package_expires_at || '' },
        { key: CF.mrn,         field_value: record.mrn || '' },
        { key: CF.kobDate,     field_value: kobDate },
        { key: CF.regStatus,   field_value: registrationLabel(record.status) },
        // Sentiasa 'Yes' — fungsi ni cuma jalan bila rekod psy_patients
        // MEMANG wujud (webhook dicetus oleh perubahan pada rekod tu).
        // Field ni KOSONG di GHL = ISW tak pernah ada rekod pesakit tu.
        { key: CF.inSystem,    field_value: 'Yes' },
      ],
      // 'patient' = penanda kekal utk automation GHL (cth. exclude dari
      // sales flow "EOB CREATED" guna filter Tag none-of: patient)
      tags: ['patient', 'isw-kob', `kob:${status}`],
    }

    const upsert = await ghl('/contacts/upsert', {
      method: 'POST',
      body: JSON.stringify(upsertBody),
    })
    const contactId = upsert?.contact?.id || upsert?.id
    if (!contactId) throw new Error('No contactId returned from upsert')

    // ── 4. Gerak / cipta Opportunity ke stage yang padan ────
    let opportunityResult: string = 'skipped'
    const pipelineId = Deno.env.get('GHL_PIPELINE_ID')
    if (pipelineId && stageInfo.stageId && !stageInfo.stageId.startsWith('FILL_')) {
      // Cari opportunity sedia ada untuk contact ni dalam pipeline KOB
      const search = await ghl(
        `/opportunities/search?location_id=${locationId}&contact_id=${contactId}&pipeline_id=${pipelineId}`,
        { method: 'GET' },
      )
      const existing = search?.opportunities?.[0]
      const oppBody = {
        pipelineId,
        pipelineStageId: stageInfo.stageId,
        name: `KOB — ${record.full_name || phone}`,
        status: status === 'completed' || status === 'package_paid' ? 'won' : 'open',
      }
      if (existing?.id) {
        await ghl(`/opportunities/${existing.id}`, { method: 'PUT', body: JSON.stringify(oppBody) })
        opportunityResult = `updated:${existing.id}`
      } else {
        const created = await ghl('/opportunities/', {
          method: 'POST',
          body: JSON.stringify({ ...oppBody, locationId, contactId }),
        })
        opportunityResult = `created:${created?.opportunity?.id || created?.id || '?'}`
      }
    }

    return new Response(
      JSON.stringify({ success: true, contactId, status, stage: stageInfo.label, opportunity: opportunityResult }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('sync-ghl error:', err)
    return new Response(JSON.stringify({ error: String(err?.message || err) }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

// ── Webhook psy_kob_sessions: sync tarikh booking → GHL ─────
// Dicetus bila patient tempah / reschedule / batal slot KOB.
// Hanya update custom field tarikh pada contact — Opportunity stage
// diuruskan oleh aliran psy_patients (kob_status → 'booked').
async function handleKobSession(record: any, oldRecord: any): Promise<Response> {
  if (!record?.patient_id) return json({ skipped: 'no patient_id' })

  // Skip kalau tarikh & status tak berubah (elak spam GHL pada update lain)
  if (oldRecord &&
      oldRecord.scheduled_at === record.scheduled_at &&
      oldRecord.status === record.status) {
    return json({ skipped: 'session unchanged' })
  }

  const relevant = ['booked', 'reschedule', 'cancelled']
  if (!relevant.includes(record.status)) {
    return json({ skipped: `status ${record.status}` })
  }

  const [patient] = await sbSelect(
    `psy_patients?id=eq.${record.patient_id}&select=id,full_name,phone,mrn`,
  )
  if (!patient) return json({ skipped: 'patient not found', patient_id: record.patient_id })

  const phone = toE164(patient.phone)
  if (!phone) return json({ skipped: 'no phone', patient: patient.id })

  // Batal → kosongkan tarikh; booked/reschedule → tarikh baru
  const dateValue = record.status === 'cancelled'
    ? ''
    : kobDateLabel(record.scheduled_at, record.mode)

  const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')!
  const [firstName, ...rest] = String(patient.full_name || '').trim().split(/\s+/)
  const upsert = await ghl('/contacts/upsert', {
    method: 'POST',
    body: JSON.stringify({
      locationId,
      phone,
      firstName: firstName || undefined,
      lastName: rest.join(' ') || undefined,
      name: patient.full_name || undefined,
      customFields: [
        { key: CF.kobDate, field_value: dateValue },
        { key: CF.mrn,     field_value: patient.mrn || '' },
      ],
      tags: ['patient', 'isw-kob'],
    }),
  })
  const contactId = upsert?.contact?.id || upsert?.id
  return json({ success: true, contactId, kob_session_date: dateValue, session_status: record.status })
}
