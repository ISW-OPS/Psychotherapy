// ============================================================
// _shared/ghl-sync.ts — logik teras GHL→ISW (padan/cipta pesakit,
// sync sesi KOB, sync bayaran). Dipanggil oleh DUA laluan:
//   1. ghl-booking-webhook (realtime, satu event setiap panggilan)
//   2. ghl-initial-sync (backfill, banyak rekod setiap panggilan)
// Kekal SATU sumber kebenaran supaya kedua-dua laluan tak drift.
// ============================================================

import { toE164, phoneKey } from './ghl.ts'

const ADVANCED_KOB_STATUSES = ['hadir', 'package_recommended', 'package_paid', 'completed']

// Gerakkan kob_status ke `next` — TAPI jangan turunkan pesakit yang dah
// lebih jauh (elak webhook lewat/retry reset progress doktor/pakej).
async function advanceKobStatus(svc: any, patientId: string, next: string) {
  const { data: ptRow } = await svc.from('psy_patients').select('kob_status').eq('id', patientId).single()
  if (ptRow && !ADVANCED_KOB_STATUSES.includes(ptRow.kob_status)) {
    await svc.from('psy_patients').update({ kob_status: next }).eq('id', patientId)
  }
}

// Field pendaftaran/KYC tambahan yang closer mungkin dah kumpul di GHL
// (custom fields). PRA-ISI SAHAJA — psy_patients.* dibaca terus oleh
// roles/patient/pendaftaran.html (fillForm(base), lihat pendaftaran.html
// ~1222-1254) untuk pra-isi borang bila pesakit belum pernah hantar KYC.
// Pesakit TETAP kena semak & submit sendiri (termasuk tick consent PDPA)
// — kita TIDAK cipta psy_kyc_submissions terus dari sini.
export interface GhlContactExtra {
  icNumber?: string | null
  address?: string | null
  postcode?: string | null
  city?: string | null
  state?: string | null
  dateOfBirth?: string | null   // ISO date (YYYY-MM-DD)
  gender?: string | null        // 'M' | 'F'
  maritalStatus?: string | null
  occupation?: string | null
  company?: string | null
  emergencyContactName?: string | null
  emergencyContactPhone?: string | null
  emergencyContactIc?: string | null
  emergencyContactRelationship?: string | null
  emergencyContactEmail?: string | null
  contactPreference?: 'pesakit' | 'waris' | null   // GHL "Peranan Pendaftar" (4 kategori dipermudah ke 2)
  registrantCapacity?: string | null               // GHL "Anda mengisi borang ini sebagai?" (sejauh mana terlibat)
  ghlContactId?: string | null                     // {{contact.id}} — rujukan pantas/debug sahaja, bukan kunci padanan
  kobCode?: string | null                          // GHL {{contact.first_name}} — kod KOB (medan berasingan, SUMBER UTAMA)
}

// GHL (Workflow "SU KOB Auto ID") dulu prepend kod macam "KOB'26-000139"
// terus dalam SATU field nama ("KOB'26-000139. Pn Syamira") — kod ni
// KEKAL sbg FALLBACK (parse dari fullName) utk contact lama/laluan lain.
// SUMBER UTAMA sekarang: `opts.kobCode` (medan GHL berasingan,
// {{contact.first_name}} — disahkan 25 Sept 2026, lebih boleh dipercayai
// drpd regex parse). Kod masuk `ghl_kob_code` (BUKAN `reference_code`/"Kod
// Pesakit" — tu medan lain, diisi lepas pesakit signup pakej OB).
const GHL_NAME_CODE_RE = /^([A-Za-z]{2,6}'\d{2}-\d{3,6})[.\s]+(.+)$/

function splitGhlNameCode(rawName: string | null | undefined): { name: string | null; code: string | null } {
  const raw = String(rawName || '').trim()
  const m = raw.match(GHL_NAME_CODE_RE)
  if (!m) return { name: raw || null, code: null }
  return { name: m[2].trim(), code: m[1] }
}

// ── 1. Padan/cipta pesakit ikut telefon ─────────────────────
export async function syncContactToPatient(svc: any, opts: {
  phone: string | null | undefined
  fullName?: string | null
  email?: string | null
} & GhlContactExtra): Promise<{ patientId: string; created: boolean }> {
  const phone = toE164(opts.phone)
  if (!phone) throw new Error('phone wajib')
  const key = phoneKey(phone)
  if (!key) throw new Error('phone tidak sah (kurang 9 digit)')

  // SUMBER UTAMA: opts.kobCode (medan GHL berasingan). FALLBACK: parse
  // dari fullName (contact lama/laluan lain yg masih gabung kod+nama).
  const { name: parsedName, code: parsedCode } = splitGhlNameCode(opts.fullName)
  const cleanFullName = opts.kobCode ? (opts.fullName?.trim() || parsedName) : parsedName
  const ghlRefCode = opts.kobCode || parsedCode

  // PENTING: elak .or(`col.ilike.*${key}`) — string DSL .or() manual ni
  // TERBUKTI tak boleh dipercayai (dicuba 28 Sept 2026, dua kali — baik '%'
  // mahupun '*' sebagai wildcard TETAP gagal cari padanan sedia ada dlm
  // ujian sebenar PROD, punca sebenar tak dapat disahkan). Guna DUA panggilan
  // `.ilike()` berasingan (kaedah rasmi supabase-js, bukan string DSL tulis
  // tangan) + gabung dalam JS — cara PALING selamat/telus, elak dedup
  // "senyap" gagal & cipta pesakit BAHARU setiap kali dipanggil semula utk
  // contact yg sama (punca pendua KOB bila laluan pantas ghl-pull-sync
  // re-check contact sama setiap 15 minit).
  // PENTING: select() SATU BARIS SAHAJA — versi lama guna template string
  // merentas beberapa baris (aksara baris-baru terbenam dlm parameter select),
  // disyaki punca sebenar dedup ni GAGAL SENYAP (PostgREST mungkin tersalah
  // hurai senarai lajur bila ada \n terbenam, `error` pun tak pernah disemak
  // sebelum ni — silap besar). Fix 29 Sept 2026.
  const selectCols = 'id, phone, emergency_contact_phone, full_name, email, ic_number, address, postcode, city, state, date_of_birth, gender, marital_status, occupation, company, ghl_kob_code, contact_preference, registrant_capacity, ghl_contact_id, emergency_contact_name, emergency_contact_ic, emergency_contact_relationship, emergency_contact_email'
  const [byPhone, byEmergency] = await Promise.all([
    svc.from('psy_patients').select(selectCols).ilike('phone', `%${key}`),
    svc.from('psy_patients').select(selectCols).ilike('emergency_contact_phone', `%${key}`),
  ])
  if (byPhone.error || byEmergency.error) {
    throw new Error(`candidate lookup gagal: ${byPhone.error?.message || ''} ${byEmergency.error?.message || ''}`.trim())
  }
  const candidates = [...(byPhone.data || []), ...(byEmergency.data || [])]
  const match = candidates.find(
    (p: any) => phoneKey(p.phone) === key || phoneKey(p.emergency_contact_phone) === key,
  )

  // Peta field GHL → kolum psy_patients — isi field KOSONG sahaja, jangan
  // timpa data yang pesakit/staff dah sahkan (borang KYC ialah sumber
  // kebenaran lebih tinggi selepas dihantar).
  // Nota: contact_preference ada DEFAULT 'pesakit' di DB (tak pernah NULL
  // utk pesakit sedia ada), jadi peraturan "isi kosong sahaja" ni hanya
  // berkesan bila CIPTA pesakit baru — utk pesakit sedia ada, nilai GHL
  // tak akan timpa default/pilihan sedia ada (selamat by design).
  const fieldMap: Record<string, any> = {
    full_name: cleanFullName,
    ghl_kob_code: ghlRefCode,
    email: opts.email,
    ic_number: opts.icNumber,
    address: opts.address,
    postcode: opts.postcode,
    city: opts.city,
    state: opts.state,
    date_of_birth: opts.dateOfBirth,
    gender: opts.gender,
    marital_status: opts.maritalStatus,
    occupation: opts.occupation,
    company: opts.company,
    emergency_contact_name: opts.emergencyContactName,
    emergency_contact_phone: opts.emergencyContactPhone,
    emergency_contact_ic: opts.emergencyContactIc,
    emergency_contact_relationship: opts.emergencyContactRelationship,
    emergency_contact_email: opts.emergencyContactEmail,
    contact_preference: opts.contactPreference,
    registrant_capacity: opts.registrantCapacity,
    ghl_contact_id: opts.ghlContactId,
  }

  if (match) {
    const patch: Record<string, any> = {}
    for (const [col, val] of Object.entries(fieldMap)) {
      if (!match[col] && val) patch[col] = val
    }
    if (Object.keys(patch).length) {
      await svc.from('psy_patients').update(patch).eq('id', match.id)
    }
    return { patientId: match.id, created: false }
  }

  const insertBody: Record<string, any> = {
    phone,
    status: 'pending_kyc',
    kob_status: 'paid',
    created_by_staff: false,
    referral_source: 'GHL',
  }
  for (const [col, val] of Object.entries(fieldMap)) {
    if (val) insertBody[col] = val
  }

  const { data: inserted, error } = await svc.from('psy_patients').insert(insertBody).select('id').single()
  if (error) throw error
  return { patientId: inserted.id, created: true }
}

// ── 2. Sync sesi KOB (booking/reschedule) ───────────────────
export async function syncAppointmentToSession(svc: any, patientId: string, opts: {
  scheduledAt: Date
  mode: 'f2f' | 'online'
  // Nama staff GHL — label GHL sendiri (cth. "T103 SABRINA"), TIADA padanan
  // psy_profiles di ISW. Simpan sebagai TEKS sahaja (collector_id/closer_id
  // kekal kosong — bukan akaun staff ISW sebenar). Collector papar read-only
  // di kob-list.html (data GHL); Closer kekal boleh dipilih/timpa manual di
  // sana — GHL TAK PERNAH bekalkan nilai closer (keputusan 28 Sept 2026).
  // collectorName = "{{appointment.booked_by}}" (ejen telesales yg buat/sahkan
  //   booking KOB) — keputusan 28 Sept 2026, gantikan "{{contact.collector_kob}}"
  //   lama (field tu rupanya papar nama Kaunselor, bukan Collector — silap konfig).
  // closerName selalunya null — closer sebenar (tutup jualan) cuma diketahui
  //   semasa sesi KOB, bukan waktu booking; staff set manual di ISW.
  closerName?: string | null
  collectorName?: string | null
}): Promise<{ kobSessionId: string }> {
  const iso = opts.scheduledAt.toISOString()

  // Elak duplikat bila webhook tercetus > sekali.
  const { data: dupe } = await svc.from('psy_kob_sessions')
    .select('id').eq('patient_id', patientId).eq('scheduled_at', iso)
    .in('status', ['booked', 'hadir', 'completed']).maybeSingle()

  let kobSessionId = dupe?.id || null
  if (!kobSessionId) {
    // Reschedule (tarikh baru) → buang tempahan 'booked'/'reschedule' lama supaya
    // hanya satu KOB aktif sahaja. Sesi 'hadir'/'completed' TIDAK disentuh.
    await svc.from('psy_kob_sessions').delete()
      .eq('patient_id', patientId).in('status', ['booked', 'reschedule'])
    const { data: session, error } = await svc.from('psy_kob_sessions').insert({
      patient_id: patientId,
      scheduled_at: iso,
      mode: opts.mode,
      status: 'booked',
      source: 'ghl',
      collector_name: opts.collectorName || null,
      closer_name: opts.closerName || null,
    }).select('id').single()
    if (error) throw error
    kobSessionId = session.id
  }

  await advanceKobStatus(svc, patientId, 'booked')
  return { kobSessionId }
}

// Padan pesakit ikut telefon TANPA cipta baharu — dipakai bila kita cuma
// nak semak/kemaskini rekod sedia ada (cth batalkan sesi), bukan sync
// penuh (elak cipta psy_patients untuk contact yang appointment dia
// dah dibatal/dipadam di GHL — tiada apa nak disync lagi).
export async function findPatientIdByPhone(svc: any, phone: string | null | undefined): Promise<string | null> {
  const p = toE164(phone)
  if (!p) return null
  const key = phoneKey(p)
  if (!key) return null
  // .ilike() rasmi berasingan + gabung JS — lihat nota sama di syncContactToPatient().
  const [byPhone, byEmergency] = await Promise.all([
    svc.from('psy_patients').select('id, phone, emergency_contact_phone').ilike('phone', `%${key}`),
    svc.from('psy_patients').select('id, phone, emergency_contact_phone').ilike('emergency_contact_phone', `%${key}`),
  ])
  const candidates = [...(byPhone.data || []), ...(byEmergency.data || [])]
  const match = candidates.find(
    (row: any) => phoneKey(row.phone) === key || phoneKey(row.emergency_contact_phone) === key,
  )
  return match?.id || null
}

// Batalkan sesi KOB 'booked'/'reschedule' pesakit yang TAK LAGI wujud dalam
// senarai appointment KOB AKTIF semasa di GHL (dibatal/dipadam di GHL
// Calendar). Sesi 'hadir'/'completed' TIDAK disentuh — dah lepas peringkat
// tempahan, pembatalan calendar lewat tak patut buang progres klinikal.
export async function cancelStaleKobSessions(
  svc: any, patientId: string, activeScheduledIso: string[],
): Promise<{ cancelled: number }> {
  const { data: rows } = await svc.from('psy_kob_sessions')
    .select('id, scheduled_at').eq('patient_id', patientId).in('status', ['booked', 'reschedule'])
  const activeSet = new Set(activeScheduledIso)
  const staleIds = (rows || [])
    .filter((r: any) => !activeSet.has(new Date(r.scheduled_at).toISOString()))
    .map((r: any) => r.id)
  if (!staleIds.length) return { cancelled: 0 }
  await svc.from('psy_kob_sessions').update({ status: 'cancelled' }).in('id', staleIds)
  return { cancelled: staleIds.length }
}

// ── 3. Sync bayaran (yuran KOB dari GHL) ────────────────────
const PAID_LIKE = new Set(['paid', 'completed', 'succeeded', 'success'])

export async function syncOrderToPayment(svc: any, patientId: string, opts: {
  orderId: string
  amount: number | string
  status: string
}): Promise<{ paymentId: string | null; skipped?: string }> {
  if (!PAID_LIKE.has(String(opts.status || '').toLowerCase())) {
    return { paymentId: null, skipped: `status ${opts.status}` }
  }
  if (!opts.orderId) throw new Error('order_id wajib')

  // Idempotent — webhook retry tak patut cipta rekod berganda.
  const { data: existing } = await svc.from('psy_payments')
    .select('id').eq('ghl_transaction_id', opts.orderId).maybeSingle()
  if (existing) return { paymentId: existing.id, skipped: 'dupe' }

  const amount = Number(opts.amount) || 0
  const receiptRef = 'RCP-GHL-' + Date.now().toString(36).toUpperCase() +
    '-' + Math.floor(performance.now()).toString(36).toUpperCase()

  const { data: inserted, error } = await svc.from('psy_payments').insert({
    receipt_ref: receiptRef,
    patient_id: patientId,
    user_id: null,
    items: [{ type: 'kob', title: 'Yuran KOB (GHL)', amount, reference_id: opts.orderId }],
    subtotal: amount,
    service_charge: 0,
    sst: 0,
    total: amount,
    payment_method: 'ghl',
    ghl_transaction_id: opts.orderId,
    status: 'completed',
    paid_at: new Date().toISOString(),
  }).select('id').single()
  if (error) throw error

  await advanceKobStatus(svc, patientId, 'paid')
  return { paymentId: inserted.id }
}

// ── 4. Sync bayaran via GHL Transaction (`/payments/transactions`) —
// LEDGER BERSEPADU rasmi GHL, tangkap SEMUA kaedah bayaran (Order/
// checkout, Invoice/manual-transfer, Stripe) dalam SATU objek konsisten
// (`status:'succeeded'`, `entityType:'order'|'invoice'`). Disahkan 12
// Ogos 2026 via 2 contact ujian: (a) "Hjh Azah" — appointment KOB wujud,
// /payments/orders KOSONG, tapi transaction succeeded (entityType
// 'invoice', bayaran manual/Text2Pay); (b) contact lain — 3 order
// completed, SEMUA turut muncul sebagai transaction succeeded
// (entityType 'order'). Jadi Transactions superset Order+Invoice —
// GANTI dua semakan berasingan (syncOrderToPayment dipanggil di
// ghl-booking-webhook/ghl-initial-sync sahaja sekarang, bukan sini).
export async function syncTransactionToPayment(svc: any, patientId: string, opts: {
  transactionId: string
  amount: number | string
  status: string
}): Promise<{ paymentId: string | null; skipped?: string }> {
  if (!PAID_LIKE.has(String(opts.status || '').toLowerCase())) {
    return { paymentId: null, skipped: `status ${opts.status}` }
  }
  if (!opts.transactionId) throw new Error('transaction_id wajib')

  const { data: existing } = await svc.from('psy_payments')
    .select('id').eq('ghl_transaction_id', opts.transactionId).maybeSingle()
  if (existing) return { paymentId: existing.id, skipped: 'dupe' }

  const amount = Number(opts.amount) || 0
  const receiptRef = 'RCP-GHL-' + Date.now().toString(36).toUpperCase() +
    '-' + Math.floor(performance.now()).toString(36).toUpperCase()

  const { data: inserted, error } = await svc.from('psy_payments').insert({
    receipt_ref: receiptRef,
    patient_id: patientId,
    user_id: null,
    items: [{ type: 'kob', title: 'Yuran KOB (GHL)', amount, reference_id: opts.transactionId }],
    subtotal: amount,
    service_charge: 0,
    sst: 0,
    total: amount,
    payment_method: 'ghl',
    ghl_transaction_id: opts.transactionId,
    status: 'completed',
    paid_at: new Date().toISOString(),
  }).select('id').single()
  if (error) throw error

  await advanceKobStatus(svc, patientId, 'paid')
  return { paymentId: inserted.id }
}
