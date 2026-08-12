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
  dateOfBirth?: string | null   // ISO date (YYYY-MM-DD)
  gender?: string | null        // 'M' | 'F'
  emergencyContactName?: string | null
  emergencyContactPhone?: string | null
  emergencyContactIc?: string | null
  emergencyContactRelationship?: string | null
  emergencyContactEmail?: string | null
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

  const { data: candidates } = await svc.from('psy_patients')
    .select(`id, phone, emergency_contact_phone, full_name, email, ic_number, address,
      date_of_birth, gender, emergency_contact_name, emergency_contact_ic,
      emergency_contact_relationship, emergency_contact_email`)
    .or(`phone.ilike.%${key},emergency_contact_phone.ilike.%${key}`)
  const match = (candidates || []).find(
    (p: any) => phoneKey(p.phone) === key || phoneKey(p.emergency_contact_phone) === key,
  )

  // Peta field GHL → kolum psy_patients — isi field KOSONG sahaja, jangan
  // timpa data yang pesakit/staff dah sahkan (borang KYC ialah sumber
  // kebenaran lebih tinggi selepas dihantar).
  const fieldMap: Record<string, any> = {
    full_name: opts.fullName,
    email: opts.email,
    ic_number: opts.icNumber,
    address: opts.address,
    date_of_birth: opts.dateOfBirth,
    gender: opts.gender,
    emergency_contact_name: opts.emergencyContactName,
    emergency_contact_phone: opts.emergencyContactPhone,
    emergency_contact_ic: opts.emergencyContactIc,
    emergency_contact_relationship: opts.emergencyContactRelationship,
    emergency_contact_email: opts.emergencyContactEmail,
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
    }).select('id').single()
    if (error) throw error
    kobSessionId = session.id
  }

  await advanceKobStatus(svc, patientId, 'booked')
  return { kobSessionId }
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
