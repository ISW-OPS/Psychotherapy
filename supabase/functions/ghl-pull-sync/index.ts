// ============================================================
// Edge Function: ghl-pull-sync
// PULL berkala (cron) — GANTIKAN pendekatan Workflow/webhook GHL yang
// bermasalah (merge field GHL Workflow tak konsisten format & "Test
// workflow" tak simulasi konteks appointment). ISW panggil TERUS API
// GHL setiap 15 minit (data JSON terus, bukan merge-tag teks).
//
// Cetusan: pg_cron (lihat README.md untuk SQL cron.schedule). Dilindungi
// x-cron-secret (secret TERSENDIRI GHL_PULL_CRON_SECRET — bukan
// timpa CRON_SECRET sedia ada, elak risiko pecahkan cron event-reminders
// yang mungkin dah dijadualkan dgn nilai lama).
//
// Setiap run: scan SATU KELOMPOK contact GHL (max 8 muka surat = 800
// contact/run — akaun ni disahkan >2000 contact, terlalu besar utk scan
// penuh dalam satu panggilan tanpa timeout Edge Function). Kedudukan
// (cursor) disimpan dalam psy_settings (key 'ghl_pull_sync_cursor'),
// setiap run SAMBUNG dari cursor tersimpan — bukan mula semula. Bila
// sampai hujung senarai, cursor reset ke kosong (pusingan baharu mula
// dari atas). Merentas beberapa run (~15 min sekali), seluruh akaun
// akhirnya discan & disegerak secara berperingkat.
//
// Untuk contact yang custom field "ISW STATUS" bermula KOB/SU KOB/SU
// OB/OB (kes tak sensitif huruf) — SYARAT MASUK: mesti JUGA ada
// sekurang-kurangnya 1 appointment AKTIF pada kalendar KOB khusus
// (lihat getKobCalendarIds(), auto-resolve ikut nama kalendar
// "KONSULTASI OVERHAUL BODY", bukan ID hardcode). Status sahaja TAK
// MEMADAI — contact yang belum book diskip (skippedNoPaymentOrBooking),
// TAK dicipta dalam psy_patients.
//
// Bayaran (24 Sept 2026, keputusan user — GANTI syarat 11-12 Ogos yang
// mula-mula WAJIBKAN transaction paid/completed/succeeded juga): ADA
// sesi KOB PERCUMA (tiada caj direkod GHL langsung) — mewajibkan bayaran
// buat sesi macam ni skip SELAMA-LAMANYA walaupun booking sah. Appointment
// kalendar KOB SAHAJA kini memadai (requirePayment default FALSE).
// Bayaran (kalau ada, via getKobPaidTransactions()/`/payments/transactions`
// — ledger bersepadu Order+Invoice+Stripe) tetap disync sebagai rekod
// tambahan (psy_payments), cuma TAK gate penciptaan pesakit/sesi lagi.
//
// Pembatalan (24 Sept 2026, keputusan user): kalau appointment KOB
// dibatal/dipadam terus di GHL Calendar (bukan reschedule ke slot lain),
// sesi 'booked'/'reschedule' pesakit berkenaan di ISW turut ditanda
// 'cancelled' — lihat cancelStaleKobSessions() dalam _shared/ghl-sync.ts.
//
// Guna semula SEPENUHNYA logik teras _shared/ghl-sync.ts — TIADA logik
// sync baharu ditulis di sini, hanya orkestrasi pull+loop.
//
// Secrets:
//   GHL_ISW_TOKEN, GHL_ISW_LOCATION_ID — sedia ada
//   GHL_PULL_CRON_SECRET — BAHARU, tersendiri (bukan CRON_SECRET sedia ada)
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY — auto-inject
// Cursor disimpan dalam psy_settings (jadual sedia ada, key/value JSONB)
// — TIADA migration DB diperlukan.
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { ghl, cleanGhlName, phoneKey } from '../_shared/ghl.ts'
import { syncContactToPatient, syncAppointmentToSession, syncTransactionToPayment, findPatientIdByPhone, cancelStaleKobSessions, attributeReferralToAffiliate } from '../_shared/ghl-sync.ts'

const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

const PAGE_LIMIT = 100
const MAX_PAGES_PER_RUN = 8   // ~800 contact/run — selamat drpd timeout Edge Function
const CURSOR_KEY = 'ghl_pull_sync_cursor'

// PENTING: `GET /contacts/` pulangkan customFields sebagai {id,value}
// SAHAJA — TIADA key/name langsung. ID field ni STABIL merentas semua
// contact. Disahkan via `{debug:true, action:'list_custom_fields'}`
// (GET /locations/{locationId}/customFields — pulangkan id+fieldKey+name
// sekali, jauh lebih senang dari cross-reference contact demi contact).
const ISW_STATUS_FIELD_ID   = 'TujlPbLGNn82yJpdr4Ff'  // contact.status — "SU KOB"/"EOB KIV"/dll
const IC_NUMBER_FIELD_ID    = 'vXw0rgtYQEvfxoMY2AjV'  // contact.no_ic
const HOME_ADDRESS_FIELD_ID = 'l2TcgLHVMKISHgf6R7ps'  // contact.alamat_rumah
const WARIS_FIELD_ID        = 'f1zSoMogQ9zW7xPmKYg3'  // contact.nama_penuh_waris__pesakit (teks bebas gabungan)
const KOB_MODE_FIELD_ID      = 'n6SUABcfNkUXbmkAnrEW'  // contact.mod_sesi_kob — dropdown "F2F"/"Online" (dicipta 13 Ogos 2026)
const REFERRED_BY_AFFILIATE_FIELD_ID = 'lZ08knTmjhhGiMc0NJIQ'  // contact.referred_by_affiliate — folder "PT Sytem" (disahkan 28 Okt 2026 via list_custom_fields)

function getCustomFieldById(customFields: any[], fieldId: string): string {
  if (!Array.isArray(customFields)) return ''
  const hit = customFields.find((f: any) => f?.id === fieldId)
  return String(hit?.value ?? '')
}

// Padan "Online"/"ONLINE"/"online" → 'online'; apa-apa lain (kosong,
// "F2F", nilai tak dikenali) → 'f2f' (selamat — F2F ialah default sedia
// ada, staff boleh betulkan manual di kob-detail.html kalau tersasar).
function resolveKobMode(customFields: any[]): 'f2f' | 'online' {
  if (!KOB_MODE_FIELD_ID) return 'f2f'
  const v = getCustomFieldById(customFields, KOB_MODE_FIELD_ID).trim().toLowerCase()
  return v === 'online' ? 'online' : 'f2f'
}

// ISW STATUS di GHL ialah field DROPDOWN (single-select) dgn senarai
// TETAP 42 pilihan (disahkan user 12 Ogos 2026, tengok terus di GHL
// Custom Fields → ISW STATUS → edit). Peraturan mudah & pasti (keputusan
// user): bermula "SU" = pesakit (semua varian pakej OB/NLC/EOL/JUMPSTART
// serta KOB terkandung dalam "SU KOB..."/"SU OB..." dll — tak perlu
// senarai prefix ad-hoc lagi). "KOB..." (tanpa "SU") turut relevan
// (peringkat konsultasi terus). EOB* (lead telesale) TAK bermula
// "SU"/"KOB", jadi betul dikecualikan secara semula jadi.
const EXCLUDED_STATUS_EXACT = new Set(['KOB CANCEL', 'KOB NO SHOW'])

function isKobRelevantStatus(status: string): boolean {
  const s = status.toUpperCase().trim()
  if (EXCLUDED_STATUS_EXACT.has(s) || s.includes('KIV')) return false
  return s.startsWith('KOB') || s.startsWith('SU') || s.startsWith('OB ')
}

// GOTCHA dibetulkan 22 Okt 2026: EXCLUDED_STATUS_EXACT/KIV di atas dulu
// buat isKobRelevantStatus() pulang false, dan DUA-DUA tempat panggil
// (loop cursor sistematik + processOneContact) terus `continue`/`return`
// pada titik tu — sesi 'booked'/'reschedule' ISW lama TAK PERNAH dibatalkan
// bila GHL ISW STATUS contact tu bertukar ke CANCEL/NO SHOW/KIV, sebab
// tiada laluan sampai cancelStaleKobSessions() langsung. Contoh sebenar:
// Pn. Azlina Ahmad (KOB'26-00153) tersangkut 'booked' 21 hari walaupun
// cron jalan tiap 15 minit — contact dia "dijumpai" beratus kali tapi
// terus di-skip setiap kali. Fungsi ni padankan label GHL terus ke status
// sesi ISW SEBELUM gate di atas sempat skip terus.
function excludedStatusToSessionStatus(statusUpper: string): 'cancelled' | 'no_show' | 'kiv' | null {
  if (statusUpper === 'KOB CANCEL') return 'cancelled'
  if (statusUpper === 'KOB NO SHOW') return 'no_show'
  if (statusUpper.includes('KIV')) return 'kiv'
  return null
}

async function syncExcludedStatusToSession(
  svc: any, phone: string | null | undefined, targetStatus: 'cancelled' | 'no_show' | 'kiv',
): Promise<number> {
  const patientId = await findPatientIdByPhone(svc, phone).catch(() => null)
  if (!patientId) return 0
  const { data } = await svc.from('psy_kob_sessions')
    .update({ status: targetStatus })
    .eq('patient_id', patientId)
    .in('status', ['booked', 'reschedule'])
    .select('id')
  return data?.length || 0
}

const PAID_STATUSES = ['paid', 'completed', 'succeeded', 'success']

function isKobProductName(name: string): boolean {
  const n = String(name || '').toUpperCase()
  return n.includes('KOB') || n.includes('KONSULTASI')
}

// Tarik transaction succeeded/paid/completed untuk SATU contact, tapis
// **KOB SAHAJA** (keputusan user 12 Ogos 2026 — sebelum ni terima MANA-MANA
// transaction termasuk pakej/kontrak lain "buat masa sekarang", sekarang
// ketatkan). Transaction order-sourced bawa nama produk TERUS
// (`entitySourceName`, cth "KOB GA WC1 260806") — padan terus. Transaction
// invoice-sourced (manual transfer/Text2Pay) TAK bawa nama produk dalam
// transaction itu sendiri (cth "Text2Pay - EOB 260808." — generik) — kena
// rujuk invoice ASAL (`name`/`invoiceItems[].name`, cth "KONSULTASI
// OVERHAUL BODY"), padan ikut `entityId`. Dikongsi antara processOneContact
// & diagnose_gate (satu sumber logik, elak drift).
async function getKobPaidTransactions(locationId: string, contactId: string): Promise<any[]> {
  const txData = await ghl(`/payments/transactions?altId=${locationId}&altType=location&contactId=${contactId}&limit=20`, { method: 'GET' })
  const txs = txData?.data || txData?.transactions || []
  const paid = txs.filter((t: any) => PAID_STATUSES.includes(String(t.status || '').toLowerCase()))

  const hasInvoiceSourced = paid.some((t: any) => t.entityType === 'invoice')
  let kobInvoiceIds = new Set<string>()
  if (hasInvoiceSourced) {
    const invoiceData = await ghl(`/invoices/?altId=${locationId}&altType=location&contactId=${contactId}&limit=20&offset=0`, { method: 'GET' })
    const invoices = invoiceData?.invoices || []
    kobInvoiceIds = new Set(
      invoices
        .filter((inv: any) => isKobProductName(inv.name) || (inv.invoiceItems || []).some((it: any) => isKobProductName(it.name)))
        .map((inv: any) => inv._id),
    )
  }
  return paid.filter((t: any) => t.entityType === 'invoice' ? kobInvoiceIds.has(t.entityId) : isKobProductName(t.entitySourceName))
}

// Syarat masuk ISW (keputusan user 11-12 Ogos 2026): status ISW STATUS
// relevan SAHAJA TAK MEMADAI — mesti JUGA ada (a) sekurang-kurangnya 1
// GHL Transaction succeeded/paid/completed DAN (b) appointment pada
// kalendar KOB khusus (bukan mana-mana appointment). Elak lead yang baru
// tukar status GHL tapi belum benar-benar book+bayar daripada tercipta
// sebagai psy_patients.
//
// ID kalendar KOB di-auto-resolve ikut NAMA — bukan hardcode ID (kalendar
// boleh disusun semula/ditambah di GHL dashboard). PENTING: nama kalendar
// GHL sebenar TAK mengandungi singkatan "KOB" — ia nama penuh "KONSULTASI
// OVERHAUL BODY" ("KOB" = akronim KOnsultasi overhaul Body, huruf pertama
// setiap perkataan, bukan substring literal).
//
// Disahkan user 11 Ogos 2026 (`list_calendars`, akaun ada 54 kalendar
// keseluruhan) — 10 kalendar padan "KONSULTASI OVERHAUL BODY": 6 kalendar
// tapak (WC1-WC5+EG) YANG DIMAHUKAN, + 4 kalendar "KOB VIP"/"VIP 2/3/4"
// yang KEPUTUSAN USER kecualikan (bukan slot KOB tapak biasa). Jadi
// padanan nama SAHAJA tak cukup — mesti JUGA tolak "VIP".
const KOB_CALENDAR_NAME_MATCH = 'KONSULTASI OVERHAUL BODY'
const KOB_CALENDAR_NAME_EXCLUDE = 'VIP'
function isKobCalendarName(name: string): boolean {
  const n = String(name || '').toUpperCase().trim()
  return n.includes(KOB_CALENDAR_NAME_MATCH) && !n.includes(KOB_CALENDAR_NAME_EXCLUDE)
}
let kobCalendarIdsCache: Set<string> | null = null
async function getKobCalendarIds(locationId: string): Promise<Set<string>> {
  if (kobCalendarIdsCache) return kobCalendarIdsCache
  try {
    const data = await ghl(`/calendars/?locationId=${locationId}`, { method: 'GET' })
    const cals = data?.calendars || []
    kobCalendarIdsCache = new Set(cals.filter((cal: any) => isKobCalendarName(cal?.name)).map((cal: any) => cal.id))
  } catch (_) {
    kobCalendarIdsCache = new Set()   // gagal tarik senarai kalendar — jangan block seluruh run, tapi log via errors[] di pemanggil
  }
  return kobCalendarIdsCache
}

// Proses SATU contact ikut syarat penuh (status + kalendar KOB, ± bayaran)
// — sumber tunggal dikongsi antara scan sistematik (loop utama) DAN
// carian sasaran (action sync_matching). Elak drift dua salinan logik.
//
// `requirePayment` (default FALSE sejak 24 Sept 2026, keputusan user) —
// asalnya (11-12 Ogos) mesti ada appointment KOB DAN bayaran sah, tapi ada
// sesi KOB PERCUMA (tiada caj/transaction direkod GHL) — gate bayaran
// sebelum ni buat sesi macam ni skip SELAMA-LAMANYA. Sekarang tempahan
// pada kalendar KOB SAHAJA sudah memadai (`requireAppointment`, default
// true) — bayaran (kalau ada) tetap disync sebagai rekod tambahan, cuma
// TAK gate lagi.
//
// Pembatalan (24 Sept 2026, keputusan user): kalau contact tiada LANGSUNG
// appointment KOB aktif semasa (dibatal/dipadam di GHL Calendar) tapi
// pesakit tu dah wujud di ISW (pernah disync), batalkan sesi
// 'booked'/'reschedule' dia — lihat cancelStaleKobSessions().
async function processOneContact(svc: any, locationId: string, c: any, requirePayment = false, requireAppointment = true): Promise<{
  status: 'not_relevant' | 'skipped_gate' | 'synced'
  patientId?: string
  appointmentSynced?: boolean
  sessionsCancelled?: number
  paymentsSynced?: number
  error?: string
}> {
  try {
    const iswStatus = getCustomFieldById(c.customFields, ISW_STATUS_FIELD_ID)
    const excludedTarget = excludedStatusToSessionStatus(iswStatus.toUpperCase().trim())
    if (excludedTarget) {
      const sessionsCancelled = await syncExcludedStatusToSession(svc, c.phone, excludedTarget).catch(() => 0)
      return { status: 'not_relevant', sessionsCancelled }
    }
    if (!isKobRelevantStatus(iswStatus)) return { status: 'not_relevant' }

    let latestKobAppt: any = null
    let activeKobIsoTimes: string[] = []
    try {
      const apptData = await ghl(`/contacts/${c.id}/appointments`, { method: 'GET' })
      const kobCalIds = await getKobCalendarIds(locationId)
      const activeEvents = (apptData?.events || apptData?.appointments || [])
        .filter((a: any) => !a.deleted && a.appointmentStatus !== 'cancelled' && kobCalIds.has(a.calendarId))
      activeKobIsoTimes = activeEvents
        .map((a: any) => { const d = new Date(String(a.startTime).replace(' ', 'T') + '+08:00'); return Number.isNaN(d.getTime()) ? null : d.toISOString() })
        .filter((s: string | null): s is string => !!s)
      activeEvents.sort((a: any, b: any) => new Date(b.startTime).getTime() - new Date(a.startTime).getTime())
      latestKobAppt = activeEvents[0] || null
    } catch (e) { return { status: 'skipped_gate', error: `appt-check: ${(e as Error).message}` } }

    let paidTransactions: any[] = []
    try {
      paidTransactions = await getKobPaidTransactions(locationId, c.id)
    } catch (e) { /* bayaran gagal tarik TAK block sync appointment — bayaran cuma rekod tambahan, bukan gate lagi */ }

    if ((requireAppointment && !latestKobAppt) || (requirePayment && paidTransactions.length === 0)) {
      // Tiada appointment KOB aktif — kalau pesakit ni dah wujud (pernah
      // disync dari appointment sebelum ni), batalkan sesi 'booked'/
      // 'reschedule' dia (appointment dibatal/dipadam di GHL Calendar).
      let sessionsCancelled: number | undefined
      if (!latestKobAppt) {
        const existingPatientId = await findPatientIdByPhone(svc, c.phone).catch(() => null)
        if (existingPatientId) {
          const r = await cancelStaleKobSessions(svc, existingPatientId, activeKobIsoTimes).catch(() => null)
          if (r) sessionsCancelled = r.cancelled
        }
      }
      return { status: 'skipped_gate', sessionsCancelled }
    }

    const fullName = [c.firstNameRaw, c.lastNameRaw].filter(Boolean).join(' ').trim() || c.contactName || null
    const referredByAffiliateName = getCustomFieldById(c.customFields, REFERRED_BY_AFFILIATE_FIELD_ID) || null
    const { patientId } = await syncContactToPatient(svc, {
      phone: c.phone,
      fullName,
      email: c.email,
      icNumber: getCustomFieldById(c.customFields, IC_NUMBER_FIELD_ID) || null,
      address: getCustomFieldById(c.customFields, HOME_ADDRESS_FIELD_ID) || c.address1 || null,
      emergencyContactName: getCustomFieldById(c.customFields, WARIS_FIELD_ID) || null,
      referredByAffiliateName,
    })

    // Cuba atribut rujukan kpd affiliate GHL (28 Okt 2026, padan ikut nama,
    // best-effort — lihat attributeReferralToAffiliate() di _shared/ghl-sync.ts).
    // Kegagalan di sini TAK gagalkan sync contact ni.
    if (referredByAffiliateName) {
      try { await attributeReferralToAffiliate(svc, { patientId, affiliateName: referredByAffiliateName }) }
      catch (_) { /* best-effort, tak kritikal */ }
    }

    let appointmentSynced = false
    if (latestKobAppt) {
      try {
        const iso = String(latestKobAppt.startTime).replace(' ', 'T') + '+08:00'
        const scheduledAt = new Date(iso)
        if (!Number.isNaN(scheduledAt.getTime())) {
          await syncAppointmentToSession(svc, patientId, { scheduledAt, mode: resolveKobMode(c.customFields) })
          appointmentSynced = true
        }
      } catch (e) { return { status: 'synced', patientId, error: `appt-sync: ${(e as Error).message}` } }
    }

    // Batalkan sesi lama patient ni yang TAK LAGI wujud dalam senarai
    // appointment KOB aktif semasa (cth slot lain sebelum ni dibatal di
    // GHL, bukan reschedule) — dedup tambahan selain hard-delete dalam
    // syncAppointmentToSession (yang cuma buang bila ADA booking baharu).
    let sessionsCancelled = 0
    try {
      const r = await cancelStaleKobSessions(svc, patientId, activeKobIsoTimes)
      sessionsCancelled = r.cancelled
    } catch (_) { /* gagal batal tak patut gagalkan keseluruhan sync contact ni */ }

    let paymentsSynced = 0
    try {
      for (const t of paidTransactions) {
        const result = await syncTransactionToPayment(svc, patientId, {
          transactionId: t._id || t.id, amount: t.amount, status: t.status,
        })
        if (!result.skipped) paymentsSynced++
      }
    } catch (e) { return { status: 'synced', patientId, appointmentSynced, sessionsCancelled, error: `transaction-sync: ${(e as Error).message}` } }

    return { status: 'synced', patientId, appointmentSynced, sessionsCancelled, paymentsSynced }
  } catch (e) {
    return { status: 'skipped_gate', error: `contact: ${(e as Error).message}` }
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    if (req.headers.get('x-cron-secret') !== Deno.env.get('GHL_PULL_CRON_SECRET')) {
      return json({ error: 'forbidden' }, 403)
    }

    const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')!
    const svc = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

    // ── DEBUG sahaja — tinjau bentuk data mentah sebelum jalan penuh ──
    // POST { debug: true, query: '<carian, cth 9 digit telefon>' }
    const body = await req.json().catch(() => ({}))
    if (body?.debug) {
      if (body.contactId) {
        if (body.raw) {
          const c = await ghl(`/contacts/${body.contactId}`, { method: 'GET' }).catch((e) => ({ __error: String(e.message || e) }))
          return json({ debug: true, contact: c })
        }
        const appts = await ghl(`/contacts/${body.contactId}/appointments`, { method: 'GET' }).catch((e) => ({ __error: String(e.message || e) }))
        const orders = await ghl(`/payments/orders?altId=${locationId}&altType=location&contactId=${body.contactId}&limit=20`, { method: 'GET' }).catch((e) => ({ __error: String(e.message || e) }))
        // Siasat hipotesis 12 Ogos: yuran manual transfer mungkin ditanda "paid"
        // via GHL Invoice (objek berasingan dari Orders/checkout) — /payments/orders
        // tak nampak invoice. Cuba endpoint invoices utk sahkan.
        const invoices = await ghl(`/invoices/?altId=${locationId}&altType=location&contactId=${body.contactId}&limit=20&offset=0`, { method: 'GET' }).catch((e) => ({ __error: String(e.message || e) }))
        // Siasat 12 Ogos — dashboard GHL "Transactions" (Manual+Stripe, status
        // "Succeeded") nampak lebih lengkap dari Orders/Invoices berasingan.
        const transactions = await ghl(`/payments/transactions?altId=${locationId}&altType=location&contactId=${body.contactId}&limit=20`, { method: 'GET' }).catch((e) => ({ __error: String(e.message || e) }))
        return json({ debug: true, appts, orders, invoices, transactions })
      }
      if (body.action === 'create_custom_field') {
        // { debug:true, action:'create_custom_field', name:'KOB Stage', dataType:'TEXT' }
        // Dropdown: tambah { dataType:'SINGLE_OPTIONS', options:['F2F','Online'] }
        const payload: any = { name: body.name, dataType: body.dataType || 'TEXT', model: body.model || 'contact' }
        if (Array.isArray(body.options)) payload.options = body.options
        const result = await ghl(`/locations/${locationId}/customFields`, {
          method: 'POST',
          body: JSON.stringify(payload),
        })
        return json({ debug: true, action: 'create_custom_field', result })
      }
      if (body.action === 'update_custom_field') {
        // { debug:true, action:'update_custom_field', fieldId:'...', name:'PT Mrn' }
        // Tukar NAMA PAPARAN sahaja — fieldKey kekal sama (dicipta sekali,
        // tak berubah), jadi kod (CF map dalam sync-ghl) TAK perlu diubah.
        const result = await ghl(`/locations/${locationId}/customFields/${body.fieldId}`, {
          method: 'PUT',
          body: JSON.stringify({ name: body.name }),
        })
        return json({ debug: true, action: 'update_custom_field', result })
      }
      if (body.action === 'delete_custom_field') {
        const result = await ghl(`/locations/${locationId}/customFields/${body.fieldId}`, { method: 'DELETE' })
        return json({ debug: true, action: 'delete_custom_field', result })
      }
      if (body.action === 'list_pipelines') {
        const data = await ghl(`/opportunities/pipelines?locationId=${locationId}`, { method: 'GET' })
        return json({ debug: true, action: 'list_pipelines', raw: data })
      }
      if (body.action === 'count_ghl_patients') {
        // Kiraan CEPAT (service role, langkau RLS) — sahkan angka sebenar
        // psy_patients bersumber GHL selepas backfill sync_matching.
        const { count, error } = await svc.from('psy_patients').select('id', { count: 'exact', head: true }).eq('referral_source', 'GHL')
        if (error) return json({ debug: true, action: 'count_ghl_patients', error: error.message }, 500)
        return json({ debug: true, action: 'count_ghl_patients', count })
      }
      if (body.action === 'sync_one') {
        // Paksa sync SATU contact (ikut phone/contactId), abaikan filter
        // status — untuk diagnos kenapa contact tertentu tak masuk ISW.
        let c: any = body.contact
        if (!c && body.query) {
          const found = await ghl(`/contacts/?locationId=${locationId}&query=${encodeURIComponent(body.query)}&limit=5`, { method: 'GET' })
          c = (found?.contacts || [])[0]
        }
        if (!c) return json({ debug: true, action: 'sync_one', error: 'contact tak jumpa' }, 404)
        try {
          // Nama ASAL dari GHL terus (termasuk prefix kod booking cth
          // "OB'26-0751 Pn. ...") — staff boleh edit sendiri di ISW kalau
          // perlu; jangan auto-bersihkan (keputusan user 10 Ogos 2026).
          const fullName = [c.firstNameRaw, c.lastNameRaw].filter(Boolean).join(' ').trim() || c.contactName || null
          const result = await syncContactToPatient(svc, {
            phone: c.phone, fullName, email: c.email,
            icNumber: getCustomFieldById(c.customFields, IC_NUMBER_FIELD_ID) || null,
            address: getCustomFieldById(c.customFields, HOME_ADDRESS_FIELD_ID) || c.address1 || null,
            emergencyContactName: getCustomFieldById(c.customFields, WARIS_FIELD_ID) || null,
            referredByAffiliateName: getCustomFieldById(c.customFields, REFERRED_BY_AFFILIATE_FIELD_ID) || null,
          })
          return json({ debug: true, action: 'sync_one', contact: { id: c.id, phone: c.phone, fullName }, result })
        } catch (e) {
          return json({ debug: true, action: 'sync_one', contact: { id: c.id, phone: c.phone }, error: String((e as Error).message) })
        }
      }
      if (body.action === 'sync_matching') {
        // { debug:true, action:'sync_matching', query:'SU' | 'JS' | ..., requirePayment?:true, requireAppointment?:false }
        // Carian TERUS (GHL text search, bukan scan cursor sistematik) —
        // utk utamakan kelompok pesakit tertentu (cth nama "SU"/"JS")
        // TANPA tunggu giliran scan menyeluruh. Lalui syarat status
        // SENTIASA via processOneContact(). Default (24 Sept 2026) padan
        // loop scan sistematik: requirePayment FALSE (appointment KOB
        // sahaja memadai — ada sesi percuma), requireAppointment true.
        // Override eksplisit `requirePayment:true` kalau perlu ketatkan
        // semula utk carian sasaran ni sahaja.
        const q = String(body.query || '')
        if (!q) return json({ debug: true, action: 'sync_matching', error: 'query wajib' }, 400)
        const requirePayment = body.requirePayment === true
        const requireAppointment = body.requireAppointment !== false
        let sAfterId: string | undefined = body.startAfterId
        let sAfter: number | undefined = body.startAfter
        const pages = Math.min(Number(body.pages) || 5, 10)
        let scanned = 0, kobRel = 0, skippedGate = 0, synced = 0
        const results: any[] = []
        for (let pg = 0; pg < pages; pg++) {
          let path = `/contacts/?locationId=${locationId}&query=${encodeURIComponent(q)}&limit=${PAGE_LIMIT}`
          if (sAfterId) path += `&startAfterId=${sAfterId}`
          if (sAfter) path += `&startAfter=${sAfter}`
          const d = await ghl(path, { method: 'GET' }).catch(() => null)
          if (!d) break
          const cs = d?.contacts || []
          scanned += cs.length
          for (const c of cs) {
            const iswStatus = getCustomFieldById(c.customFields, ISW_STATUS_FIELD_ID)
            const excludedTarget = excludedStatusToSessionStatus(iswStatus.toUpperCase().trim())
            if (excludedTarget) { await syncExcludedStatusToSession(svc, c.phone, excludedTarget).catch(() => 0); continue }
            if (!isKobRelevantStatus(iswStatus)) continue
            kobRel++
            const r = await processOneContact(svc, locationId, c, requirePayment, requireAppointment)
            if (r.status === 'skipped_gate') { skippedGate++; continue }
            if (r.status === 'synced') {
              synced++
              results.push({ name: c.contactName, patientId: r.patientId, appointmentSynced: r.appointmentSynced, paymentsSynced: r.paymentsSynced })
            }
          }
          if (cs.length < PAGE_LIMIT) { sAfterId = undefined; sAfter = undefined; break }
          const last = cs[cs.length - 1]
          sAfterId = last?.id
          sAfter = last?.dateAdded ? new Date(last.dateAdded).getTime() : undefined
        }
        return json({ debug: true, action: 'sync_matching', query: q, requirePayment, requireAppointment, scanned, kobRelevant: kobRel, skippedGate, patientsSynced: synced, results, nextCursor: sAfterId ? { startAfterId: sAfterId, startAfter: sAfter } : null })
      }
      if (body.action === 'list_calendars') {
        // Semak SEBELUM jalan penuh — sahkan nama kalendar KOB sebenar
        // padan isKobCalendarName() (getKobCalendarIds() guna fungsi
        // sama). Kalau tiada calendar match, gate payment+booking akan
        // skip SEMUA contact (kobCalendarIdsCache jadi set kosong).
        const data = await ghl(`/calendars/?locationId=${locationId}`, { method: 'GET' })
        const cals = data?.calendars || []
        const matched = cals.filter((cal: any) => isKobCalendarName(cal?.name))
        return json({ debug: true, action: 'list_calendars', total: cals.length, matchedKob: matched.map((c: any) => ({ id: c.id, name: c.name })), all: cals.map((c: any) => ({ id: c.id, name: c.name })) })
      }
      if (body.action === 'diagnose_gate') {
        // Dry-run — TIADA sync/write. Siasat KENAPA contact status-relevan
        // gagal syarat payment+booking (bukan sekadar kira, tapi tunjuk
        // punca sebenar per-contact: tiada appointment KOB langsung, ada
        // appointment tapi kalendar lain, ada bayaran tapi status bukan
        // paid/completed, dll). Guna lepas run penuh nampak nisbah rendah
        // (cth "1 daripada 219") — sahkan gate memang betul, bukan tersasar.
        // `passed` guna Transactions (sama macam gate sebenar); orders/
        // invoices raw turut dipapar sekadar konteks siasatan manusia.
        const maxDiag = Math.min(Number(body.limit) || 20, 50)
        const pages = Math.min(Number(body.pages) || 3, 10)
        const kobCalIds = await getKobCalendarIds(locationId)
        const diagnostics: any[] = []
        let sAfterId: string | undefined, sAfter: number | undefined
        let scanned = 0, kobRelevantSeen = 0
        for (let p = 0; p < pages && diagnostics.length < maxDiag; p++) {
          let path = `/contacts/?locationId=${locationId}&limit=${PAGE_LIMIT}`
          if (sAfterId) path += `&startAfterId=${sAfterId}`
          if (sAfter) path += `&startAfter=${sAfter}`
          const d = await ghl(path, { method: 'GET' }).catch(() => null)
          if (!d) break
          const cs = d?.contacts || []
          scanned += cs.length
          for (const c of cs) {
            if (diagnostics.length >= maxDiag) break
            const status = getCustomFieldById(c.customFields, ISW_STATUS_FIELD_ID)
            if (!isKobRelevantStatus(status)) continue
            kobRelevantSeen++

            const apptData = await ghl(`/contacts/${c.id}/appointments`, { method: 'GET' }).catch((e) => ({ __error: String(e.message || e) }))
            const allEvents = (apptData?.events || apptData?.appointments || []).filter((a: any) => !a.deleted)
            const kobEvents = allEvents.filter((a: any) => kobCalIds.has(a.calendarId))

            const orderData = await ghl(`/payments/orders?altId=${locationId}&altType=location&contactId=${c.id}&limit=20`, { method: 'GET' }).catch((e) => ({ __error: String(e.message || e) }))
            const orders = orderData?.data || orderData?.orders || []
            const orderStatuses = [...new Set(orders.map((o: any) => o.status))]
            const paidOrderCount = orders.filter((o: any) => PAID_STATUSES.includes(String(o.status || '').toLowerCase())).length

            const invoiceData = await ghl(`/invoices/?altId=${locationId}&altType=location&contactId=${c.id}&limit=20&offset=0`, { method: 'GET' }).catch((e) => ({ __error: String(e.message || e) }))
            const invoices = invoiceData?.invoices || []
            const invoiceStatuses = [...new Set(invoices.map((inv: any) => inv.status))]

            const txData = await ghl(`/payments/transactions?altId=${locationId}&altType=location&contactId=${c.id}&limit=20`, { method: 'GET' }).catch((e) => ({ __error: String(e.message || e) }))
            const txs = txData?.data || txData?.transactions || []
            const transactionStatuses = [...new Set(txs.map((t: any) => t.status))]
            const paidTransactionCount = txs.filter((t: any) => PAID_STATUSES.includes(String(t.status || '').toLowerCase())).length
            const kobPaidTransactionCount = await getKobPaidTransactions(locationId, c.id).then(r => r.length).catch(() => 0)

            diagnostics.push({
              id: c.id, phone: c.phone, status,
              totalAppointments: allEvents.length,
              kobCalendarAppointments: kobEvents.length,
              otherCalendarIds: [...new Set(allEvents.filter((a: any) => !kobCalIds.has(a.calendarId)).map((a: any) => a.calendarId))],
              totalOrders: orders.length,
              orderStatuses,
              paidOrders: paidOrderCount,
              totalInvoices: invoices.length,
              invoiceStatuses,
              totalTransactions: txs.length,
              transactionStatuses,
              paidTransactions: paidTransactionCount,
              kobPaidTransactions: kobPaidTransactionCount,
              // 24 Sept 2026: appointment kalendar KOB sahaja memadai (bayaran
              // tak digate lagi — ada sesi KOB percuma). `passed` cerminkan
              // gate SEBENAR processOneContact() guna sekarang.
              passed: kobEvents.length > 0,
            })
          }
          if (cs.length < PAGE_LIMIT) break
          const last = cs[cs.length - 1]
          sAfterId = last?.id
          sAfter = last?.dateAdded ? new Date(last.dateAdded).getTime() : undefined
        }
        return json({ debug: true, action: 'diagnose_gate', scanned, kobRelevantSeen, diagnostics })
      }
      if (body.action === 'probe_location_transactions') {
        // Siasat SEBELUM bina sync ledger umum (bukan KOB sahaja): adakah
        // /payments/transactions boleh disenaraikan PERINGKAT LOKASI (tanpa
        // contactId, banyak contact sekali gus) — semua panggilan SEDIA ADA
        // dalam fail ni (getKobPaidTransactions/diagnose_gate) SENTIASA
        // hantar contactId, jadi tingkah laku tanpa contactId TAK PERNAH
        // disahkan. Kalau berjaya (pulang transaction merentas >1 contactId
        // berbeza), sync ledger umum boleh guna 1 loop pagination transaksi
        // (cekap). Kalau gagal/pulang kosong/error, terpaksa loop per-contact
        // (lebih berat — ikut corak processOneContact sedia ada).
        const limit = Math.min(Number(body.limit) || 20, 100)
        let path = `/payments/transactions?altId=${locationId}&altType=location&limit=${limit}`
        if (body.startAfterId) path += `&startAfterId=${body.startAfterId}`
        if (body.startAfter) path += `&startAfter=${body.startAfter}`
        if (body.offset != null) path += `&offset=${body.offset}`
        if (body.page != null) path += `&page=${body.page}`
        const data = await ghl(path, { method: 'GET' }).catch((e) => ({ __error: String(e.message || e) }))
        const txs = data?.data || data?.transactions || []
        const distinctContacts = new Set(txs.map((t: any) => t.contactId || t.contact_id).filter(Boolean))
        return json({
          debug: true, action: 'probe_location_transactions',
          count: txs.length, distinctContactIds: distinctContacts.size,
          sample: txs.slice(0, 3), meta: data?.meta || null, raw: data,
        })
      }
      if (body.action === 'list_custom_fields') {
        const data = await ghl(`/locations/${locationId}/customFields`, { method: 'GET' })
        return json({ debug: true, action: 'list_custom_fields', raw: data })
      }
      if (body.action === 'stats_status_values') {
        // Dry-run — TIADA sync/write. Kira taburan nilai ISW STATUS
        // merentas N muka surat contact, supaya kita nampak SEMUA status
        // wujud (bukan cuma yang ada "kob") sebelum putuskan filter.
        const pages = Math.min(Number(body.pages) || 5, 15)
        const counts: Record<string, number> = {}
        let sAfterId: string | undefined, sAfter: number | undefined
        let scanned = 0
        for (let p = 0; p < pages; p++) {
          let path = `/contacts/?locationId=${locationId}&limit=${PAGE_LIMIT}`
          if (sAfterId) path += `&startAfterId=${sAfterId}`
          if (sAfter) path += `&startAfter=${sAfter}`
          const d = await ghl(path, { method: 'GET' }).catch(() => null)
          if (!d) break
          const cs = d?.contacts || []
          scanned += cs.length
          for (const c of cs) {
            const v = getCustomFieldById(c.customFields, ISW_STATUS_FIELD_ID) || '(kosong)'
            counts[v] = (counts[v] || 0) + 1
          }
          if (cs.length < PAGE_LIMIT) break
          const last = cs[cs.length - 1]
          sAfterId = last?.id
          sAfter = last?.dateAdded ? new Date(last.dateAdded).getTime() : undefined
        }
        return json({ debug: true, action: 'stats_status_values', scanned, counts })
      }
      if (body.action === 'cleanup_excluded_status') {
        // Pembetulan SEKALI SAHAJA — buang RETROAKTIF pesakit yang dah
        // disync sebelum EXCLUDED_STATUS_EXACT/KIV wujud. Soft-delete
        // (status='deleted', sama pattern dgn deletePatient() staff UI —
        // boleh dipulihkan oleh admin), bukan hard-delete.
        const pages = Math.min(Number(body.pages) || 10, 25)
        const { data: patients } = await svc.from('psy_patients')
          .select('id, phone, status').eq('referral_source', 'GHL').neq('status', 'deleted').limit(2000)
        const byPhone: Record<string, any> = {}
        for (const p of patients || []) {
          const key = phoneKey(p.phone)
          if (key) byPhone[key] = p
        }
        let sAfterId: string | undefined = body.startAfterId
        let sAfter: number | undefined = body.startAfter
        let scanned = 0, deleted = 0
        for (let pg = 0; pg < pages; pg++) {
          let path = `/contacts/?locationId=${locationId}&limit=${PAGE_LIMIT}`
          if (sAfterId) path += `&startAfterId=${sAfterId}`
          if (sAfter) path += `&startAfter=${sAfter}`
          const d = await ghl(path, { method: 'GET' }).catch(() => null)
          if (!d) break
          const cs = d?.contacts || []
          scanned += cs.length
          for (const c of cs) {
            const key = phoneKey(c.phone)
            const match = key ? byPhone[key] : null
            if (!match) continue
            const status = getCustomFieldById(c.customFields, ISW_STATUS_FIELD_ID)
            const s = status.toUpperCase().trim()
            if (EXCLUDED_STATUS_EXACT.has(s) || s.includes('KIV')) {
              await svc.from('psy_patients').update({ status: 'deleted' }).eq('id', match.id)
              deleted++
            }
          }
          if (cs.length < PAGE_LIMIT) break
          const last = cs[cs.length - 1]
          sAfterId = last?.id
          sAfter = last?.dateAdded ? new Date(last.dateAdded).getTime() : undefined
        }
        const reachedEnd = scanned < pages * PAGE_LIMIT
        return json({ debug: true, action: 'cleanup_excluded_status', totalGhlPatients: (patients || []).length, scanned, deleted, reachedEnd, nextCursor: reachedEnd ? null : { startAfterId: sAfterId, startAfter: sAfter } })
      }
      if (body.action === 'backfill_excluded_sessions') {
        // Pembetulan SEKALI SAHAJA (22 Okt 2026) — betulkan rekod SEDIA ADA
        // yang tersangkut 'booked'/'reschedule' di ISW walaupun GHL ISW STATUS
        // contact tu DAH CANCEL/NO SHOW/KIV, sebab gate isKobRelevantStatus()
        // dulu terus skip (lihat excludedStatusToSessionStatus/syncExcludedStatusToSession
        // di atas — fix cron akan datang, tapi contact lama ni statusnya dah
        // STABIL, cron biasa takkan "jumpa perubahan" lagi utk proses dia).
        // TAK padam/sentuh psy_patients langsung (beza drpd cleanup_excluded_status
        // di atas) — cuma betulkan status psy_kob_sessions sahaja.
        const pages = Math.min(Number(body.pages) || 10, 25)
        let sAfterId: string | undefined = body.startAfterId
        let sAfter: number | undefined = body.startAfter
        let scanned = 0, matched = 0, sessionsFixed = 0
        const fixedList: any[] = []
        for (let pg = 0; pg < pages; pg++) {
          let path = `/contacts/?locationId=${locationId}&limit=${PAGE_LIMIT}`
          if (sAfterId) path += `&startAfterId=${sAfterId}`
          if (sAfter) path += `&startAfter=${sAfter}`
          const d = await ghl(path, { method: 'GET' }).catch(() => null)
          if (!d) break
          const cs = d?.contacts || []
          scanned += cs.length
          for (const c of cs) {
            const status = getCustomFieldById(c.customFields, ISW_STATUS_FIELD_ID)
            const target = excludedStatusToSessionStatus(status.toUpperCase().trim())
            if (!target) continue
            matched++
            const n = await syncExcludedStatusToSession(svc, c.phone, target).catch(() => 0)
            if (n > 0) {
              sessionsFixed += n
              fixedList.push({ name: c.contactName, phone: c.phone, target, sessionsFixed: n })
            }
          }
          if (cs.length < PAGE_LIMIT) { sAfterId = undefined; sAfter = undefined; break }
          const last = cs[cs.length - 1]
          sAfterId = last?.id
          sAfter = last?.dateAdded ? new Date(last.dateAdded).getTime() : undefined
        }
        return json({ debug: true, action: 'backfill_excluded_sessions', scanned, matched, sessionsFixed, fixed: fixedList, nextCursor: sAfterId ? { startAfterId: sAfterId, startAfter: sAfter } : null })
      }
      if (body.action === 'detect_deleted_contacts') {
        // (28 Okt 2026) Kesan pesakit ISW yang contact GHL dia DAH DIPADAM
        // (GHL tiada webhook "Contact Deleted" — satu-satunya cara ialah
        // cuba GET /contacts/:id, 404 = dah tiada). HANYA semak pesakit
        // referral_source='GHL' + ada ghl_contact_id + belum ditanda
        // deleted. TINDAKAN MANUAL/DEBUG sahaja (bukan sebahagian cron
        // automatik 15-minit) — elak risiko: kalau GHL API bermasalah
        // sementara (rate-limit/auth), ralat tu BUKAN 404 sebenar, jadi
        // TAK ditanda deleted (selamat by design, lihat catch di bawah).
        // { dryRun:true } (default) — SEKADAR LAPORAN, tiada apa diubah.
        // { dryRun:false } — betul-betul tanda status='deleted' (soft-delete,
        // sama pattern dgn cleanup_excluded_status/deletePatient() staff UI).
        const limit = Math.min(Number(body.limit) || 50, 200)
        const dryRun = body.dryRun !== false
        const { data: patients } = await svc.from('psy_patients')
          .select('id, ghl_contact_id, full_name, phone')
          .eq('referral_source', 'GHL')
          .not('ghl_contact_id', 'is', null)
          .neq('status', 'deleted')
          .limit(limit)
        let checked = 0, confirmedDeleted = 0, inconclusiveErrors = 0
        const deletedList: any[] = []
        const errorList: any[] = []
        for (const p of patients || []) {
          checked++
          try {
            await ghl(`/contacts/${p.ghl_contact_id}`, { method: 'GET' })
            // Contact masih wujud di GHL — tiada tindakan.
          } catch (e) {
            const msg = String((e as Error).message || '')
            if (/→ 404/.test(msg) || /not found/i.test(msg)) {
              confirmedDeleted++
              deletedList.push({ id: p.id, full_name: p.full_name, phone: p.phone, ghl_contact_id: p.ghl_contact_id })
              if (!dryRun) {
                await svc.from('psy_patients').update({ status: 'deleted' }).eq('id', p.id)
              }
            } else {
              // Ralat LAIN (rangkaian/rate-limit/auth) — BUKAN bukti dipadam,
              // jangan sentuh rekod ni, cuma lapor utk disemak manual.
              inconclusiveErrors++
              errorList.push({ id: p.id, full_name: p.full_name, error: msg })
            }
          }
        }
        return json({
          debug: true, action: 'detect_deleted_contacts', dryRun,
          totalCandidates: (patients || []).length, checked, confirmedDeleted, inconclusiveErrors,
          deletedList, errorList,
          note: dryRun ? 'Dry-run — tiada rekod diubah. Hantar {dryRun:false} untuk betul-betul tandakan deleted.' : 'Rekod dalam deletedList dah ditandakan status=deleted.',
        })
      }
      if (body.action === 'restore_raw_names') {
        // Pembetulan SEKALI SAHAJA — kebalikan cleanup_names. Beberapa
        // rekod pesakit "terkunci" dgn nama BERSIH dari sebelum cleaning
        // dimatikan (peraturan isi-kosong-sahaja elak sync biasa timpa
        // balik). Force-update full_name → nama MENTAH GHL semasa,
        // padan ikut phoneKey (bukan tunggu field kosong).
        const pages = Math.min(Number(body.pages) || 10, 25)
        const { data: patients } = await svc.from('psy_patients')
          .select('id, phone, full_name').eq('referral_source', 'GHL').limit(2000)
        const byPhone: Record<string, any> = {}
        for (const p of patients || []) {
          const key = phoneKey(p.phone)
          if (key) byPhone[key] = p
        }
        // Sambung dari cursor diberi (body.startAfterId/startAfter) kalau ada.
        let sAfterId: string | undefined = body.startAfterId
        let sAfter: number | undefined = body.startAfter
        let scanned = 0, updated = 0
        for (let pg = 0; pg < pages; pg++) {
          let path = `/contacts/?locationId=${locationId}&limit=${PAGE_LIMIT}`
          if (sAfterId) path += `&startAfterId=${sAfterId}`
          if (sAfter) path += `&startAfter=${sAfter}`
          const d = await ghl(path, { method: 'GET' }).catch(() => null)
          if (!d) break
          const cs = d?.contacts || []
          scanned += cs.length
          for (const c of cs) {
            const key = phoneKey(c.phone)
            const match = key ? byPhone[key] : null
            if (!match) continue
            const rawName = [c.firstNameRaw, c.lastNameRaw].filter(Boolean).join(' ').trim() || c.contactName || ''
            if (rawName && rawName !== match.full_name) {
              await svc.from('psy_patients').update({ full_name: rawName }).eq('id', match.id)
              updated++
            }
          }
          if (cs.length < PAGE_LIMIT) break
          const last = cs[cs.length - 1]
          sAfterId = last?.id
          sAfter = last?.dateAdded ? new Date(last.dateAdded).getTime() : undefined
        }
        const reachedEnd = scanned < pages * PAGE_LIMIT
        return json({ debug: true, action: 'restore_raw_names', totalGhlPatients: (patients || []).length, scanned, updated, reachedEnd, nextCursor: reachedEnd ? null : { startAfterId: sAfterId, startAfter: sAfter } })
      }
      if (body.action === 'cleanup_names') {
        // Pembetulan SEKALI SAHAJA — bersihkan full_name pesakit sedia ada
        // yang tersimpan dgn prefix kod booking GHL (disync sebelum
        // cleanGhlName() ditambah). Selamat diulang (idempotent — nama
        // dah bersih tak berubah).
        const { data: rows } = await svc.from('psy_patients')
          .select('id, full_name').eq('referral_source', 'GHL').limit(2000)
        let updated = 0
        for (const r of rows || []) {
          const cleaned = cleanGhlName(r.full_name)
          if (cleaned && cleaned !== r.full_name) {
            await svc.from('psy_patients').update({ full_name: cleaned }).eq('id', r.id)
            updated++
          }
        }
        return json({ debug: true, action: 'cleanup_names', scanned: (rows || []).length, updated })
      }
      const q = String(body.query || '')
      const data = await ghl(`/contacts/?locationId=${locationId}&query=${encodeURIComponent(q)}&limit=5`, { method: 'GET' })
      return json({ debug: true, raw: data })
    }

    // ── Laluan pantas: booking TERKINI terus dari Calendar Events API ──
    // Cursor contact (di bawah) scan SEMUA contact lama→baharu (dateAdded
    // ascending) — bermakna booking BAHARU jadi yang PALING LAMBAT disync
    // (akaun besar boleh ambil berjam-jam sepusingan). Laluan ni pula tanya
    // terus kalendar KOB utk appointment 7 hari lepas → 60 hari depan
    // SETIAP run (~15 minit) — booking baharu/reschedule nampak dlm minit,
    // tanpa tunggu giliran cursor. Cursor lama TETAP jalan di bawah utk
    // backfill sejarah/contact tanpa appointment KOB aktif. Keputusan
    // 28 Sept 2026 (punca: booking hari sama tak muncul, cursor takde
    // sampai lagi sebab contact tu paling baharu = paling akhir dicapai).
    let recentScanned = 0
    let recentSynced = 0
    const recentErrors: string[] = []
    // DIMATIKAN 28 Sept 2026 — punca pendua pesakit/sesi KOB setiap 15 minit
    // (cipta rekod BAHARU berulang utk contact SAMA walaupun dah 3 pendekatan
    // dicuba: .or() '%', .or() '*', .ilike() rasmi — semua gagal cari padanan
    // sedia ada atas sebab yg belum disahkan). JANGAN aktifkan semula sebelum
    // punca sebenar disahkan & diuji — laluan cursor lama di bawah (stabil,
    // tiada isu ni) kekal jalan sahaja buat masa ini.
    if (false) try {
      const kobCalIds = await getKobCalendarIds(locationId)
      const now = Date.now()
      const startTime = now - 7 * 24 * 60 * 60 * 1000
      const endTime = now + 60 * 24 * 60 * 60 * 1000
      for (const calId of kobCalIds) {
        try {
          const evData = await ghl(`/calendars/events?locationId=${locationId}&calendarId=${calId}&startTime=${startTime}&endTime=${endTime}`, { method: 'GET' })
          const events = (evData?.events || []).filter((e: any) => !e.deleted && e.appointmentStatus !== 'cancelled' && e.contactId)
          for (const ev of events) {
            recentScanned++
            try {
              const cRes = await ghl(`/contacts/${ev.contactId}`, { method: 'GET' })
              const contact = cRes?.contact || cRes || {}
              // GET /contacts/:id (single) bagi firstName/lastName/name — BUKAN
              // firstNameRaw/lastNameRaw macam GET /contacts/ (senarai). processOneContact
              // hanya baca *Raw / contactName, jadi tanpa normalize ni fullName jadi
              // kosong (bug jumpa 28 Sept 2026 — punca full_name null utk sesi
              // laluan pantas ni).
              if (!contact.firstNameRaw && !contact.lastNameRaw && !contact.contactName) {
                contact.contactName = contact.name || [contact.firstName, contact.lastName].filter(Boolean).join(' ') || null
              }
              const r = await processOneContact(svc, locationId, contact)
              if (r.status === 'synced' && r.appointmentSynced) recentSynced++
              if (r.error) recentErrors.push(`${ev.contactId}: ${r.error}`)
            } catch (e) { recentErrors.push(`contact ${ev.contactId}: ${(e as Error).message}`) }
          }
        } catch (e) { recentErrors.push(`calendar ${calId}: ${(e as Error).message}`) }
      }
    } catch (e) { recentErrors.push(`kob-calendars: ${(e as Error).message}`) }

    // ── Muatkan cursor dari run sebelum ini (psy_settings) ──
    const { data: cursorRow } = await svc.from('psy_settings').select('value').eq('key', CURSOR_KEY).maybeSingle()
    let startAfterId: string | undefined = cursorRow?.value?.startAfterId
    let startAfter: number | undefined = cursorRow?.value?.startAfter
    let reachedEnd = false
    let totalContacts = 0
    let kobRelevant = 0
    let skippedNoPaymentOrBooking = 0
    let patientsSynced = 0
    let appointmentsSynced = 0
    let sessionsCancelled = 0
    let paymentsSynced = 0
    const errors: string[] = []

    for (let page = 0; page < MAX_PAGES_PER_RUN; page++) {
      let path = `/contacts/?locationId=${locationId}&limit=${PAGE_LIMIT}`
      if (startAfterId) path += `&startAfterId=${startAfterId}`
      if (startAfter) path += `&startAfter=${startAfter}`
      let data: any
      try {
        data = await ghl(path, { method: 'GET' })
      } catch (e) {
        // Gagal tarik muka surat SETERUSNYA — jangan buang progres muka
        // surat SEBELUM ni, hentikan loop dengan elegan & lapor error.
        errors.push(`page ${page} fetch: ${(e as Error).message}`)
        break
      }
      const contacts = data?.contacts || []
      totalContacts += contacts.length

      for (const c of contacts) {
        const iswStatus = getCustomFieldById(c.customFields, ISW_STATUS_FIELD_ID)
        const excludedTarget = excludedStatusToSessionStatus(iswStatus.toUpperCase().trim())
        if (excludedTarget) {
          sessionsCancelled += await syncExcludedStatusToSession(svc, c.phone, excludedTarget).catch(() => 0)
          continue
        }
        if (!isKobRelevantStatus(iswStatus)) continue
        kobRelevant++

        const r = await processOneContact(svc, locationId, c)
        if (r.status === 'skipped_gate') {
          skippedNoPaymentOrBooking++
          sessionsCancelled += r.sessionsCancelled || 0
          if (r.error) errors.push(`${c.id}: ${r.error}`)
          continue
        }
        if (r.status === 'synced') {
          patientsSynced++
          if (r.appointmentSynced) appointmentsSynced++
          sessionsCancelled += r.sessionsCancelled || 0
          paymentsSynced += r.paymentsSynced || 0
          if (r.error) errors.push(`${c.id}: ${r.error}`)
        }
      }

      if (contacts.length < PAGE_LIMIT) { reachedEnd = true; break }  // habis semua muka surat — pusingan penuh selesai
      const last = contacts[contacts.length - 1]
      startAfterId = last?.id
      // GHL jangka startAfter = epoch millis (nombor), bukan ISO string.
      startAfter = last?.dateAdded ? new Date(last.dateAdded).getTime() : undefined
    }

    // ── Simpan cursor untuk run seterusnya (reset ke kosong bila
    //    sampai hujung — pusingan baharu mula dari atas run lepas ni) ──
    const nextCursor = reachedEnd ? {} : { startAfterId, startAfter }
    try {
      await svc.from('psy_settings').upsert({ key: CURSOR_KEY, value: nextCursor, updated_at: new Date().toISOString() })
    } catch (_) { /* cursor gagal simpan — run seterusnya mula semula, tak fatal */ }

    const summary = {
      recentScanned, recentSynced, recentErrorCount: recentErrors.length, recentErrors: recentErrors.slice(0, 20),
      totalContacts, kobRelevant, skippedNoPaymentOrBooking, patientsSynced, appointmentsSynced, sessionsCancelled, paymentsSynced, errorCount: errors.length, errors: errors.slice(0, 20), reachedEnd, nextCursor,
    }

    try {
      await svc.from('psy_audit_log').insert({
        actor_name: 'GHL', actor_role: 'system', action: 'ghl_pull_sync.run', target: 'system', meta: summary,
      })
    } catch (_) { /* audit log gagal tak patut gagalkan run */ }

    return json({ success: true, ...summary })
  } catch (err) {
    console.error('ghl-pull-sync error:', err)
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
