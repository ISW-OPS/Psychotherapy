// ============================================================
// Edge Function: sync-ghl
// Sync ISW → GoHighLevel (PT→GHL). Dua cabang, dua Database Webhook
// berasingan (lihat README.md):
//   1. psy_patients UPDATE/INSERT (kob_status/status) — isi mrn/
//      isw_registration_status/pt_in_system + gerak Opportunity (Fasa 1,
//      pipeline stage belum dikonfigur — lihat STAGE_MAP).
//   2. psy_kob_sessions UPDATE/INSERT (handleKobSession) — 7 medan operasi
//      KOB (22 Okt 2026): kob_date, kob_time, mode, isw_status_2026,
//      collector_kob, closer_kob, ob_package. Collector/Closer/Pakej
//      Dicadang SEHALA ISW→GHL (ISW sumber kebenaran, staff assign di
//      kob-list.html/kob-detail.html — GHL tak pernah bekalkan nilai ni).
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
// Skop dikecilkan 22 Okt 2026 (keputusan user) — fokus SEMATA-MATA pada
// 7 medan operasi KOB (tarikh/waktu/mode/status/collector/closer/pakej).
// kob_stage/kob_status_raw/kob_package(lama)/kob_package_expires DIBUANG —
// field tu tak pernah wujud di GHL, tiada faedah push ke field yang tiada.
const CF = {
  mrn:          'isw_mrn',
  kobDate:      'kob_date',           // DIBETULKAN — dulu 'kob_session_date' (field tu TAK WUJUD di GHL)
  kobTime:      'kob_time',
  mode:         'mod_sesi_kob',
  regStatus:    'isw_registration_status',
  inSystem:     'pt_in_system',
  iswStatus:    'isw_status_2026',    // TEXTBOX_LIST — field_value MESTI array, lihat ghlCustomField()
  // 3 field baharu (22 Okt 2026) — SEHALA ISW→GHL sahaja (ISW ialah sumber
  // kebenaran; Collector/Closer/Pakej Dicadang semua staff assign/pilih
  // dalam ISW, GHL cuma papar). collector_kob REPURPOSE field lama (yang
  // dulu papar nama Kaunselor, silap konfig) — user dah padam & cipta semula.
  collector:    'collector_kob',
  closer:       'closer_kob',
  obPackage:    'ob_package',
}

// isw_status_2026 jenis GHL TEXTBOX_LIST — API jangka field_value array,
// BUKAN string tunggal macam field TEXT biasa. Field lain semua TEXT.
function ghlCustomField(key: string, value: string) {
  return key === CF.iswStatus
    ? { key, field_value: value ? [value] : [] }
    : { key, field_value: value }
}

// mode ISW ('f2f'/'online') → label dropdown GHL "mod_sesi_kob" (pilihan
// sebenar "F2F"/"Online", disahkan 22 Okt 2026).
function modeLabel(mode: string | null | undefined): string {
  return mode === 'online' ? 'Online' : 'F2F'
}

// ── MAPPING: psy_kob_sessions.status → label "ISW STATUS" di GHL ──
// Disahkan dgn user 25 Sept 2026.
// 'completed' SENGAJA TAK DALAM SENARAI NI — labelnya bukan SATU nilai
// tetap, ia ikut PAKEJ yang disignup (cth "SU OBD1", "SU EOL", "SU
// JUMPSTART" ... ~20 kemungkinan). Perlukan padanan package_id→label
// berasingan sebelum boleh automate — buat masa ni field ISW STATUS
// TAK disentuh bila status='completed' (staf isi manual di GHL kalau perlu).
const KOB_STATUS_TO_ISW: Record<string, string> = {
  booked:     'SU KOB',
  reschedule: 'KOB RESCHEDULE',
  cancelled:  'KOB CANCEL',
  kiv:        'KOB KIV',
  no_show:    'KOB NO SHOW',
  hadir:      'SU KOB A',
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
    // Tarikh/waktu sesi KOB TAK disentuh di sini lagi (22 Okt 2026) — itu
    // tanggungjawab handleKobSession() sepenuhnya (dicetus terus bila
    // psy_kob_sessions berubah, data lagi tepat drpd lookup berasingan ni).

    // JANGAN hantar firstName/lastName — Workflow "SU KOB Auto ID" GHL letak
    // KOD KOB dalam first_name (bukan nama), nama sebenar dalam last_name
    // (lihat ghl-booking-webhook README). Upsert dgn firstName/lastName
    // terbitan drpd full_name akan TIMPA/musnahkan kod tu senyap-senyap.
    const upsertBody = {
      locationId,
      phone,
      customFields: [
        { key: CF.mrn,         field_value: record.mrn || '' },
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

// ── Webhook psy_kob_sessions: sync 7 medan operasi KOB → GHL ─
// Dicetus bila patient tempah/reschedule/batal slot KOB, ATAU staff
// tukar Collector/Closer/Mode/Pakej Dicadang di ISW (kob-list.html/
// kob-detail.html). ISW ialah SUMBER KEBENARAN utk Collector/Closer/
// Pakej Dicadang — GHL cuma papar (sehala ISW→GHL utk 3 field tu).
async function handleKobSession(record: any, oldRecord: any): Promise<Response> {
  if (!record?.patient_id) return json({ skipped: 'no patient_id' })

  // Skip kalau TIADA satu pun medan relevan berubah (elak spam GHL pada
  // update lain, cth notes/questionnaire yang tak kena dgn GHL langsung).
  const watched = ['scheduled_at', 'status', 'mode', 'collector_name', 'closer_name', 'recommended_package_name']
  if (oldRecord && watched.every(f => oldRecord[f] === record[f])) {
    return json({ skipped: 'no watched field changed' })
  }

  const relevant = ['booked', 'reschedule', 'cancelled', 'kiv', 'no_show', 'hadir', 'completed']
  if (!relevant.includes(record.status)) {
    return json({ skipped: `status ${record.status}` })
  }

  const [patient] = await sbSelect(
    `psy_patients?id=eq.${record.patient_id}&select=id,full_name,phone,mrn`,
  )
  if (!patient) return json({ skipped: 'patient not found', patient_id: record.patient_id })

  const phone = toE164(patient.phone)
  if (!phone) return json({ skipped: 'no phone', patient: patient.id })

  // Tarikh+waktu tetap tunjuk SEBENAR walau slot tak lagi aktif (cancel/kiv/
  // no_show/reschedule) — beza drpd label gabungan kobDateLabel() lama (yang
  // kosongkan terus), sebab kob_date/kob_time kini 2 field BERASINGAN
  // (bukan satu label teks) — biar staff GHL nampak tarikh asal utk rujukan,
  // ISW STATUS field (bawah) dah cukup tunjuk slot tu tak aktif lagi.
  const dt = record.scheduled_at ? new Date(record.scheduled_at) : null
  // kob_date jenis GHL DATE tulen (bukan TEXT) — API GHL jangka ISO
  // "YYYY-MM-DD", BUKAN format paparan DD/MM/YYYY (akan gagal/senyap kalau salah).
  // en-CA locale bagi terus format tu (sv-SE pun boleh, en-CA lebih biasa).
  const kobDateValue = dt && !Number.isNaN(dt.getTime())
    ? new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kuala_Lumpur', day: '2-digit', month: '2-digit', year: 'numeric' }).format(dt)
    : ''
  const kobTimeValue = dt && !Number.isNaN(dt.getTime())
    ? new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kuala_Lumpur', hour: '2-digit', minute: '2-digit', hour12: true }).format(dt)
    : ''

  const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')!
  const iswStatusLabel = KOB_STATUS_TO_ISW[record.status]
  const customFields = [
    ghlCustomField(CF.kobDate, kobDateValue),
    ghlCustomField(CF.kobTime, kobTimeValue),
    ghlCustomField(CF.mode, modeLabel(record.mode)),
    ghlCustomField(CF.mrn, patient.mrn || ''),
    ghlCustomField(CF.collector, record.collector_name || ''),
    ghlCustomField(CF.closer, record.closer_name || ''),
    ghlCustomField(CF.obPackage, record.recommended_package_name || ''),
  ]
  // 'completed' sengaja tak ada dlm KOB_STATUS_TO_ISW (lihat komen jadual
  // di atas) — field ISW STATUS tak disentuh utk status tu, field lain
  // (tarikh/waktu/mode/collector/closer/pakej) tetap push macam biasa.
  if (iswStatusLabel) customFields.push(ghlCustomField(CF.iswStatus, iswStatusLabel))

  const upsert = await ghl('/contacts/upsert', {
    method: 'POST',
    body: JSON.stringify({
      // JANGAN hantar firstName/lastName — lihat nota di handler psy_patients
      // atas (kod KOB tersimpan dalam first_name GHL, elak ditimpa).
      locationId,
      phone,
      customFields,
      tags: ['patient', 'isw-kob'],
    }),
  })
  const contactId = upsert?.contact?.id || upsert?.id
  return json({
    success: true, contactId, session_status: record.status,
    kob_date: kobDateValue, kob_time: kobTimeValue, mode: modeLabel(record.mode),
    collector: record.collector_name || null, closer: record.closer_name || null,
    ob_package: record.recommended_package_name || null,
  })
}
