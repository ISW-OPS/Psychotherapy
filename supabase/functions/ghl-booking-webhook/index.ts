// ============================================================
// Edge Function: ghl-booking-webhook
// Terima webhook dari GHL Workflow. TIGA jenis event (field `event`
// pada payload, opsyenal — tiada field = 'appointment', mengekalkan
// keserasian penuh dgn Workflow booking sedia ada):
//
//   event: 'appointment' (default) — closer sahkan booking KOB.
//     Push masuk ISW: cipta pesakit (jika belum wujud, padan ikut
//     phone) + cipta/kemas kini slot sesi KOB (psy_kob_sessions).
//   event: 'order'  — closer sahkan bayaran yuran KOB.
//     Cipta rekod psy_payments (payment_method='ghl') + set
//     kob_status='paid'. Supaya bayaran GHL NAMPAK dalam resit
//     pesakit & reconciliation staff (sebelum ni senyap/tak direkod).
//   event: 'contact' — maklumat pesakit dikemas kini di GHL.
//     Padan/cipta pesakit sahaja (tiada sesi/bayaran disentuh).
//
// PUBLIC (verify-JWT OFF) — GHL panggil tanpa JWT Supabase.
// Dilindungi rahsia: GHL_BOOKING_WEBHOOK_SECRET (query ?secret=... atau
// header x-ghl-booking-secret) — SAMA utk ketiga-tiga event.
//
// Payload dijangka dari GHL Workflow (Webhook action), body JSON cth (rujuk
// README.md utk senarai penuh & merge tag disahkan — full_name/kob_code
// SEBENARNYA dari DUA field GHL berasingan: last_name/first_name):
//   Appointment: { "event":"appointment", "phone":"{{contact.phone}}",
//     "full_name":"{{contact.last_name}}", "kob_code":"{{contact.first_name}}",
//     "email":"{{contact.email}}", "scheduled_at":"{{appointment.start_time}}",
//     "mode":"{{contact.mod_sesi_kob}}", "closer":"{{appointment.booked_by}}" }
//     ← "closer" field GHL diguna sbg Collector di ISW (keputusan 28 Sept 2026,
//     lihat komen dekat parsing di bawah) — label GHL ("T103 SABRINA" dll),
//     TIADA padanan psy_profiles, papar read-only. "collector_kob" custom field
//     GHL TAK LAGI diguna (papar nama Kaunselor, bukan Collector sebenar).
//     Closer di ISW sentiasa manual dropdown, tiada input dari webhook ni.
//   Order:       { "event":"order", "phone":"...", "full_name":"...",
//     "email":"...", "order_id":"{{order.id}}", "amount":"{{order.amount}}",
//     "status":"{{order.status}}" }
//   Contact:     { "event":"contact", "phone":"...", "full_name":"...",
//     "email":"..." }
//
// Nota padanan: pesakit dipadan ikut 9 digit terakhir no. telefon (sama
// corak dgn ghl-inbox-webhook). Kalau tiada padanan → cipta pesakit baru
// dengan status='pending_kyc', kob_status='paid' (bayaran luaran/GHL,
// KYC belum dihantar — makna sedia ada dalam skema).
//
// Secrets:
//   GHL_BOOKING_WEBHOOK_SECRET                — rahsia kongsi
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY  — auto-inject
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { toE164 } from '../_shared/ghl.ts'
import { syncContactToPatient, syncAppointmentToSession, syncOrderToPayment } from '../_shared/ghl-sync.ts'

const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

// Terima tarikh dalam format DD/MM/YYYY (Malaysia — cth GHL "only_start_date")
// ATAU apa-apa format yang boleh dihuraikan native oleh Date() (ISO, "August
// 13, 2026", dll). Slash "13/8/2026" secara native akan disalah anggap
// MM/DD/YYYY oleh JS — ubah dulu ke ISO sebelum gabung dgn masa.
function parseFlexibleDate(dateStr: string, timeStr?: string | null): Date | null {
  let iso = String(dateStr || '').trim()
  const slash = iso.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/)
  if (slash) {
    const [, d, m, y] = slash
    iso = `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`
  }
  let time = String(timeStr || '').trim()
  // GHL custom field masa kadang format 24-jam tanpa titik dua, cth "1530"
  // (3:30 PM) — Date() tak boleh huraikan ni terus, tukar ke "15:30" dulu.
  const bareTime = time.match(/^(\d{1,2})(\d{2})$/)
  if (bareTime) {
    const [, hh, mm] = bareTime
    time = `${hh.padStart(2, '0')}:${mm}`
  }
  const combined = time ? `${iso} ${time}` : iso
  const d = new Date(combined)
  return Number.isNaN(d.getTime()) ? null : d
}

// GHL "GENDER" (radio) hantar label bebas ikut apa staff pilih — padankan
// variasi biasa (BM/EN/singkatan) ke 'M'/'F' yang psy_patients.gender jangka.
// Nilai tak dikenali → null (elak simpan sampah yg tak sepadan CHECK constraint).
function normalizeGender(raw: unknown): 'M' | 'F' | null {
  const v = String(raw || '').trim().toLowerCase()
  if (['m', 'male', 'lelaki', 'l'].includes(v)) return 'M'
  if (['f', 'female', 'perempuan', 'p'].includes(v)) return 'F'
  return null
}

// GHL "{{contact.isw_location}}" TEXT bebas (staff taip sendiri) — bukan
// f2f/online terus. Anggap "online" bila teks ada perkataan online/virtual/
// zoom; selainnya (F2F, In-Person, atau alamat fizikal) → 'f2f' (default).
function normalizeMode(raw: unknown): 'f2f' | 'online' {
  const v = String(raw || '').trim().toLowerCase()
  if (/online|virtual|zoom/.test(v)) return 'online'
  return 'f2f'
}

// GHL "Peranan Pendaftar" — 4 kategori (Pesakit/Waris Bertanggungjawab/
// Waris Wakil/Waris) dipermudah ke 2 nilai psy_patients.contact_preference
// jangka (padan mana-mana perkataan "waris" → 'waris', selainnya → 'pesakit').
function normalizeContactPreference(raw: unknown): 'pesakit' | 'waris' | null {
  const v = String(raw || '').trim().toLowerCase()
  if (!v) return null
  if (v.includes('waris')) return 'waris'
  if (v.includes('pesakit')) return 'pesakit'
  return null
}

// GHL "Anda mengisi borang ini sebagai?" — sejauh mana pendaftar terlibat
// (BEZA drpd contact_preference/"siapa"). Padankan 3 label biasa ke kod
// pendek; teks lain/tak dikenali disimpan APA ADANYA (jangan buang data).
function normalizeRegistrantCapacity(raw: unknown): string | null {
  const v = String(raw || '').trim()
  if (!v) return null
  const lower = v.toLowerCase()
  if (lower.includes('sendiri')) return 'sendiri'
  if (lower.includes('urus segala') || lower.includes('urus semua')) return 'urus_penuh'
  if (lower.includes('bantu')) return 'bantu_isi'
  return v
}

// "Peranan Pendaftar" (4 kategori) SEBENARNYA dah sekaligus jawab "sejauh
// mana terlibat" juga (disahkan dgn user 25 Sept 2026):
//   PESAKIT                → isi sendiri, dia lah pesakit        → 'sendiri'
//   WARIS BERTANGGUNGJAWAB → urus semua, kuasa penuh             → 'urus_penuh'
//   WARIS WAKIL            → bantu je, kuasa terhad              → 'bantu_isi'
//   WARIS (biasa/tanpa butiran)                                  → tak spesifik, null
// Jadi ni SUMBER UTAMA registrant_capacity (lebih tepat, kategori tetap) —
// `borang_isi_sebagai` (teks lebih bebas) cuma FALLBACK bila peranan_pendaftar
// tak beri butiran (cth "WARIS" biasa) atau langsung tak dihantar.
function deriveCapacityFromRole(raw: unknown): string | null {
  const v = String(raw || '').trim().toLowerCase()
  if (!v) return null
  if (v.includes('bertanggungjawab')) return 'urus_penuh'
  if (v.includes('wakil')) return 'bantu_isi'
  if (v.includes('pesakit')) return 'sendiri'
  return null
}

async function auditLog(svc: any, action: string, target: string, meta: Record<string, unknown>) {
  try {
    await svc.from('psy_audit_log').insert({ actor_name: 'GHL', actor_role: 'system', action, target, meta })
  } catch (_) { /* audit log gagal tak patut gagalkan webhook — fulfillment dah selesai */ }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { ...corsHeaders, 'Access-Control-Allow-Headers': 'content-type, x-ghl-booking-secret' } })
  }

  try {
    const u = new URL(req.url)
    const secret = u.searchParams.get('secret') || req.headers.get('x-ghl-booking-secret')
    if (secret !== Deno.env.get('GHL_BOOKING_WEBHOOK_SECRET')) return json({ error: 'forbidden' }, 403)

    const payload = await req.json().catch(() => ({}))
    const event = payload.event === 'order' || payload.event === 'contact' ? payload.event : 'appointment'

    const phoneRaw = payload.phone || payload.contact?.phone
    const fullName = String(payload.full_name || payload.contact?.full_name || payload.name || '').trim() || null
    const email = payload.email || payload.contact?.email || null
    const phone = toE164(phoneRaw)
    if (!phone) return json({ error: 'phone wajib' }, 400)

    const svc = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

    // Field pendaftaran/KYC tambahan — pra-isi sahaja (lihat _shared/ghl-sync.ts).
    // Hanya relevan/dihantar utk event='contact', tapi selamat dihantar sekali
    // dgn event lain juga (fieldMap hanya isi kalau nilai wujud).
    const { patientId, created } = await syncContactToPatient(svc, {
      phone, fullName, email,
      icNumber: payload.ic_number || null,
      address: payload.address || null,
      postcode: payload.postcode || null,
      city: payload.city || null,
      state: payload.state || null,
      dateOfBirth: payload.date_of_birth || null,
      gender: normalizeGender(payload.gender),
      maritalStatus: payload.marital_status || null,
      occupation: payload.occupation || null,
      company: payload.company || null,
      emergencyContactName: payload.emergency_contact_name || null,
      emergencyContactPhone: payload.emergency_contact_phone || null,
      emergencyContactIc: payload.emergency_contact_ic || null,
      emergencyContactRelationship: payload.emergency_contact_relationship || null,
      emergencyContactEmail: payload.emergency_contact_email || null,
      contactPreference: normalizeContactPreference(payload.peranan_pendaftar),
      registrantCapacity: deriveCapacityFromRole(payload.peranan_pendaftar) || normalizeRegistrantCapacity(payload.borang_isi_sebagai),
      ghlContactId: payload.contact_id || payload.contactId || null,
      kobCode: payload.kob_code || payload.kobCode || null,
    })

    if (event === 'contact') {
      await auditLog(svc, 'ghl_contact.received', patientId, { created_patient: created })
      return json({ success: true, event, patient_id: patientId, patient_created: created })
    }

    if (event === 'order') {
      const orderId = String(payload.order_id || payload.orderId || payload.id || '')
      const amount = payload.amount ?? payload.total ?? 0
      const status = payload.status || payload.payment_status || ''
      const result = await syncOrderToPayment(svc, patientId, { orderId, amount, status })
      await auditLog(svc, 'ghl_order.received', patientId, {
        created_patient: created, order_id: orderId, payment_id: result.paymentId, skipped: result.skipped || null,
      })
      return json({ success: true, event, patient_id: patientId, patient_created: created, payment_id: result.paymentId, skipped: result.skipped })
    }

    // event === 'appointment'
    // Terima SAMA ADA satu field gabungan (scheduled_at, ISO 8601) ATAU dua
    // field berasingan (scheduled_date + scheduled_time, cth "13/08/2026" +
    // "3:30 PM" — padanan dgn merge field only_start_date/only_start_time
    // yang GHL Workflow sedia ada dah guna).
    const scheduledAtRaw = payload.scheduled_at || payload.scheduledAt || payload.appointment?.start_time
    let scheduledAt = scheduledAtRaw ? new Date(scheduledAtRaw) : null
    if ((!scheduledAt || Number.isNaN(scheduledAt.getTime())) && payload.scheduled_date) {
      scheduledAt = parseFlexibleDate(payload.scheduled_date, payload.scheduled_time)
    }
    if (!scheduledAt || Number.isNaN(scheduledAt.getTime())) {
      return json({ error: 'scheduled_at (ISO 8601) ATAU scheduled_date+scheduled_time wajib' }, 400)
    }
    const mode = normalizeMode(payload.mode)
    // Nama staff GHL — label GHL, bukan akaun ISW. Papar terus sbg Collector (teks,
    // read-only) di kob-list.html/kob-detail.html.
    // collector = "{{appointment.booked_by}}" (siapa buat/sahkan booking KOB —
    //   ejen telesales yg collect/book lead tu masuk slot) — keputusan 28 Sept 2026,
    //   gantikan "{{contact.collector_kob}}" lama (field tu sebenarnya papar nama
    //   Kaunselor, bukan Collector — silap konfig GHL).
    // closer TIDAK diambil dari GHL langsung — sentiasa manual dropdown di ISW,
    //   sebab closer sebenar (yg tutup jualan pakej) cuma diketahui semasa sesi
    //   KOB berlangsung, GHL tak boleh tahu awal-awal lagi.
    const collectorName = String(payload.closer || payload.booked_by || payload.bookedBy || '').trim() || null
    const closerName = null

    const { kobSessionId } = await syncAppointmentToSession(svc, patientId, { scheduledAt, mode, closerName, collectorName })
    await auditLog(svc, 'ghl_booking.received', patientId, {
      created_patient: created, kob_session_id: kobSessionId, scheduled_at: scheduledAt.toISOString(), mode,
    })
    return json({ success: true, event, patient_id: patientId, patient_created: created, kob_session_id: kobSessionId })
  } catch (err) {
    console.error('ghl-booking-webhook error:', err)
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
