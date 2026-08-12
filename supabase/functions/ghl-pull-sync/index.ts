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
// OB/OB (kes tak sensitif huruf) — SYARAT MASUK (keputusan user 11-12
// Ogos 2026, TAMBAHAN atas filter status): mesti JUGA ada (a) sekurang-
// kurangnya 1 appointment pada kalendar KOB khusus DAN (b) sekurang-
// kurangnya 1 GHL Transaction succeeded/paid/completed (`/payments/
// transactions` — LEDGER BERSEPADU rasmi GHL, tangkap Order/checkout +
// Invoice/manual-transfer + Stripe SEKALI GUS; disahkan 12 Ogos 2026
// bukan /payments/orders sahaja SEBAB kebanyakan yuran KOB akaun ni
// dibayar transfer manual via Invoice — tak muncul dalam Orders
// langsung). Status sahaja TAK MEMADAI — contact yang belum book/bayar
// diskip (skippedNoPaymentOrBooking), TAK dicipta dalam psy_patients.
// Lihat getKobCalendarIds() (auto-resolve ikut nama kalendar "KONSULTASI
// OVERHAUL BODY", bukan ID hardcode).
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
import { syncContactToPatient, syncAppointmentToSession, syncTransactionToPayment } from '../_shared/ghl-sync.ts'

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

function getCustomFieldById(customFields: any[], fieldId: string): string {
  if (!Array.isArray(customFields)) return ''
  const hit = customFields.find((f: any) => f?.id === fieldId)
  return String(hit?.value ?? '')
}

// Relevan KOB kalau ISW STATUS bermula dgn KOB/SU KOB (peringkat konsultasi)
// ATAU salah satu stage PIPELINE "OVERHAUL BODY" sebenar di GHL (peringkat
// pakej, pesakit dah lepas KOB) — disahkan TEPAT via
// `{debug:true,action:'list_pipelines'}` (12 Ogos 2026), pipeline ni ada
// 6 stage: SU OBDY1, SU OBDX1, SU OBD1, SU NLC, SU EOL, SU JUMPSTART.
// GUNA PREFIX senarai ni (bukan "contains SU OB" generik) — elak
// terlepas stage lain (SU NLC/SU EOL tak bermula "SU OB") DAN elak
// salah tangkap status produk lain yg kebetulan ada "OB" (cth "EOB").
// "OB " (ruang, bukan bahagian pipeline ni) dikekalkan berasingan untuk
// status macam "OB LOCK HARGA" yang disahkan wujud tapi bukan stage rasmi.
const EXCLUDED_STATUS_EXACT = new Set(['KOB CANCEL', 'KOB NO SHOW'])
const OVERHAUL_BODY_PACKAGE_STAGES = ['SU OBDY1', 'SU OBDX1', 'SU OBD1', 'SU NLC', 'SU EOL', 'SU JUMPSTART']

function isKobRelevantStatus(status: string): boolean {
  const s = status.toUpperCase().trim()
  if (EXCLUDED_STATUS_EXACT.has(s) || s.includes('KIV')) return false
  if (s.startsWith('KOB') || s.startsWith('SU KOB') || s.startsWith('OB ')) return true
  return OVERHAUL_BODY_PACKAGE_STAGES.some((stage) => s.startsWith(stage))
}

const PAID_STATUSES = ['paid', 'completed', 'succeeded', 'success']

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
        const result = await ghl(`/locations/${locationId}/customFields`, {
          method: 'POST',
          body: JSON.stringify({ name: body.name, dataType: body.dataType || 'TEXT', model: 'contact' }),
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
          })
          return json({ debug: true, action: 'sync_one', contact: { id: c.id, phone: c.phone, fullName }, result })
        } catch (e) {
          return json({ debug: true, action: 'sync_one', contact: { id: c.id, phone: c.phone }, error: String((e as Error).message) })
        }
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
              passed: kobEvents.length > 0 && paidTransactionCount > 0,
            })
          }
          if (cs.length < PAGE_LIMIT) break
          const last = cs[cs.length - 1]
          sAfterId = last?.id
          sAfter = last?.dateAdded ? new Date(last.dateAdded).getTime() : undefined
        }
        return json({ debug: true, action: 'diagnose_gate', scanned, kobRelevantSeen, diagnostics })
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
        try {
          const iswStatus = getCustomFieldById(c.customFields, ISW_STATUS_FIELD_ID)
          if (!isKobRelevantStatus(iswStatus)) continue
          kobRelevant++

          // ── Syarat masuk (11-12 Ogos 2026): tarik appointment+transaction
          // DULU, sebelum cipta/kemas kini psy_patients — kena ADA
          // appointment kalendar KOB DAN sekurang-kurangnya 1 transaction
          // succeeded/paid/completed. Status ISW STATUS relevan sahaja TAK
          // MEMADAI (elak lead yang baru tukar status tapi belum benar-
          // benar book+bayar). Guna /payments/transactions (ledger
          // bersepadu GHL, tangkap Order+Invoice+Stripe+Manual SEKALI) —
          // bukan /payments/orders sahaja (disahkan 12 Ogos: kebanyakan
          // yuran KOB akaun ni dibayar transfer manual via Invoice, TAK
          // muncul dalam Orders langsung).
          let latestKobAppt: any = null
          try {
            const apptData = await ghl(`/contacts/${c.id}/appointments`, { method: 'GET' })
            const kobCalIds = await getKobCalendarIds(locationId)
            const events = (apptData?.events || apptData?.appointments || [])
              .filter((a: any) => !a.deleted && kobCalIds.has(a.calendarId))
            events.sort((a: any, b: any) => new Date(b.startTime).getTime() - new Date(a.startTime).getTime())
            latestKobAppt = events[0] || null
          } catch (e) { errors.push(`appt-check ${c.id}: ${(e as Error).message}`) }

          let paidTransactions: any[] = []
          try {
            const txData = await ghl(`/payments/transactions?altId=${locationId}&altType=location&contactId=${c.id}&limit=20`, { method: 'GET' })
            const txs = txData?.data || txData?.transactions || []
            paidTransactions = txs.filter((t: any) => PAID_STATUSES.includes(String(t.status || '').toLowerCase()))
          } catch (e) { errors.push(`transaction-check ${c.id}: ${(e as Error).message}`) }

          if (!latestKobAppt || paidTransactions.length === 0) { skippedNoPaymentOrBooking++; continue }

          // firstNameRaw/lastNameRaw kekal huruf besar/kecil asal (cth "Hjh
          // Azah"); contactName/firstName/lastName sentiasa lowercase +
          // ada prefix kod booking ("kob'26-00090. hjh azah") — elak guna.
          // Nama ASAL dari GHL terus (termasuk prefix kod booking cth
          // "OB'26-0751 Pn. ...") — staff boleh edit sendiri di ISW kalau
          // perlu; jangan auto-bersihkan (keputusan user 10 Ogos 2026).
          const fullName = [c.firstNameRaw, c.lastNameRaw].filter(Boolean).join(' ').trim() || c.contactName || null
          const { patientId } = await syncContactToPatient(svc, {
            phone: c.phone,
            fullName,
            email: c.email,
            icNumber: getCustomFieldById(c.customFields, IC_NUMBER_FIELD_ID) || null,
            address: getCustomFieldById(c.customFields, HOME_ADDRESS_FIELD_ID) || c.address1 || null,
            // Field GHL ni gabungan bebas (nama+no.+emel waris dalam satu
            // teks) — tak boleh dipisah bersih ke name/phone/email berasingan.
            emergencyContactName: getCustomFieldById(c.customFields, WARIS_FIELD_ID) || null,
          })
          patientsSynced++

          // ── Appointment terkini (kalendar KOB, dah disahkan di atas) ──
          try {
            // startTime GHL: "2026-08-13 15:30:00" TANPA offset zon masa —
            // ni waktu Malaysia (lokasi klinik). Server Edge Function jalan
            // UTC, jadi anchor eksplisit +08:00 (elak salah anggap UTC →
            // beza 8 jam).
            const iso = String(latestKobAppt.startTime).replace(' ', 'T') + '+08:00'
            const scheduledAt = new Date(iso)
            if (!Number.isNaN(scheduledAt.getTime())) {
              await syncAppointmentToSession(svc, patientId, { scheduledAt, mode: 'f2f' })
              appointmentsSynced++
            }
          } catch (e) { errors.push(`appt-sync ${c.id}: ${(e as Error).message}`) }

          // ── Bayaran (transaction succeeded, dah disahkan di atas) ──
          try {
            for (const t of paidTransactions) {
              const result = await syncTransactionToPayment(svc, patientId, {
                transactionId: t._id || t.id, amount: t.amount, status: t.status,
              })
              if (!result.skipped) paymentsSynced++
            }
          } catch (e) { errors.push(`transaction-sync ${c.id}: ${(e as Error).message}`) }
        } catch (e) { errors.push(`contact ${c.id}: ${(e as Error).message}`) }
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

    const summary = { totalContacts, kobRelevant, skippedNoPaymentOrBooking, patientsSynced, appointmentsSynced, paymentsSynced, errorCount: errors.length, errors: errors.slice(0, 20), reachedEnd, nextCursor }

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
