// ============================================================
// Edge Function: ghl-booking-webhook
// Terima webhook dari GHL Workflow (cth. dicetus bila tag "KOB-Paid"
// ditambah pada contact selepas closer sahkan bayaran + tarikh temujanji).
// Push masuk ISW: cipta pesakit baru (jika belum wujud, padan ikut phone)
// + cipta slot sesi KOB (psy_kob_sessions) pada tarikh yang dihantar GHL.
//
// PUBLIC (verify-JWT OFF) — GHL panggil tanpa JWT Supabase.
// Dilindungi rahsia: GHL_BOOKING_WEBHOOK_SECRET (query ?secret=... atau
// header x-ghl-booking-secret).
//
// Payload dijangka dari GHL Workflow (Webhook action), body JSON cth:
//   {
//     "phone":        "{{contact.phone}}",
//     "full_name":    "{{contact.full_name}}",
//     "email":        "{{contact.email}}",
//     "scheduled_at": "{{appointment.start_time}}",   // ISO 8601, WAJIB
//     "mode":         "f2f"                            // "f2f" | "online", opsyenal
//   }
// (Field scheduled_at boleh juga datang dari custom field tarikh
//  temujanji yang closer isi manual di GHL — sesuaikan mapping di GHL
//  Workflow, bukan di function ni.)
//
// Nota padanan: pesakit dipadan ikut 9 digit terakhir no. telefon (sama
// corak dgn ghl-inbox-webhook). Kalau tiada padanan → cipta pesakit baru
// dengan status='pending_kyc', kob_status='paid' (bayaran luaran/GHL,
// KYC belum dihantar — makna sedia ada dalam skema).
//
// Secrets:
//   GHL_BOOKING_WEBHOOK_SECRET                — rahsia kongsi (set baru)
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY  — auto-inject
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { toE164 } from '../_shared/ghl.ts'

const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

const digits = (s: any) => String(s || '').replace(/\D/g, '')
const phoneKey = (s: any) => { const d = digits(s); return d.length >= 9 ? d.slice(-9) : '' }

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { ...corsHeaders, 'Access-Control-Allow-Headers': 'content-type, x-ghl-booking-secret' } })
  }

  try {
    const u = new URL(req.url)
    const secret = u.searchParams.get('secret') || req.headers.get('x-ghl-booking-secret')
    if (secret !== Deno.env.get('GHL_BOOKING_WEBHOOK_SECRET')) return json({ error: 'forbidden' }, 403)

    const payload = await req.json().catch(() => ({}))
    const phoneRaw = payload.phone || payload.contact?.phone
    const scheduledAtRaw = payload.scheduled_at || payload.scheduledAt || payload.appointment?.start_time
    const fullName = String(payload.full_name || payload.contact?.full_name || payload.name || '').trim() || null
    const email = payload.email || payload.contact?.email || null
    const mode = payload.mode === 'online' ? 'online' : 'f2f'

    const phone = toE164(phoneRaw)
    if (!phone) return json({ error: 'phone wajib' }, 400)
    const scheduledAt = scheduledAtRaw ? new Date(scheduledAtRaw) : null
    if (!scheduledAt || Number.isNaN(scheduledAt.getTime())) return json({ error: 'scheduled_at wajib (ISO 8601)' }, 400)

    const svc = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

    // ── 1. Padan pesakit sedia ada ikut 9 digit terakhir telefon (sendiri atau waris) ──
    const key = phoneKey(phone)
    const { data: candidates } = await svc.from('psy_patients')
      .select('id, phone, emergency_contact_phone').or(`phone.ilike.%${key},emergency_contact_phone.ilike.%${key}`)
    let patientId = (candidates || []).find((p: any) => phoneKey(p.phone) === key || phoneKey(p.emergency_contact_phone) === key)?.id || null
    let created = false

    // ── 2. Tiada padanan → cipta pesakit baru (belum ada di ISW) ──
    if (!patientId) {
      const { data: inserted, error: insErr } = await svc.from('psy_patients').insert({
        full_name: fullName,
        phone,
        email,
        status: 'pending_kyc',
        kob_status: 'paid',
        created_by_staff: false,
        referral_source: 'GHL',
      }).select('id').single()
      if (insErr) throw insErr
      patientId = inserted.id
      created = true
    }

    // ── 3. Elak duplikat slot bila webhook tercetus > sekali ──
    const { data: dupe } = await svc.from('psy_kob_sessions')
      .select('id').eq('patient_id', patientId).eq('scheduled_at', scheduledAt.toISOString())
      .in('status', ['booked', 'hadir', 'completed']).maybeSingle()

    let kobSessionId = dupe?.id || null
    if (!kobSessionId) {
      // Reschedule dari GHL (tarikh baru) → buang tempahan 'booked'/'reschedule' lama supaya
      // hanya satu KOB aktif sahaja (sama corak dgn bookSlot() dalam kob.html). Sesi
      // 'hadir'/'completed' TIDAK disentuh.
      await svc.from('psy_kob_sessions').delete()
        .eq('patient_id', patientId).in('status', ['booked', 'reschedule'])
      const { data: session, error: sesErr } = await svc.from('psy_kob_sessions').insert({
        patient_id: patientId,
        scheduled_at: scheduledAt.toISOString(),
        mode,
        status: 'booked',
      }).select('id').single()
      if (sesErr) throw sesErr
      kobSessionId = session.id
    }

    // ── 4. Segerak kob_status → 'booked' supaya kob.html papar tarikh GHL terus
    //      (bukan kalendar tempah-sendiri ISW). Jangan turunkan kalau pesakit dah lebih
    //      jauh (hadir/pakej/dsb — reschedule sesi lama tak patut reset progress). ──
    const advancedStatuses = ['hadir', 'package_recommended', 'package_paid', 'completed']
    const { data: ptRow } = await svc.from('psy_patients').select('kob_status').eq('id', patientId).single()
    if (ptRow && !advancedStatuses.includes(ptRow.kob_status)) {
      await svc.from('psy_patients').update({ kob_status: 'booked' }).eq('id', patientId)
    }

    try {
      await svc.from('psy_audit_log').insert({
        actor_name: 'GHL', actor_role: 'system',
        action: 'ghl_booking.received',
        target: patientId,
        meta: { created_patient: created, kob_session_id: kobSessionId, scheduled_at: scheduledAt.toISOString(), mode },
      })
    } catch (_) { /* audit log gagal tak patut gagalkan webhook — fulfillment dah selesai */ }

    return json({ success: true, patient_id: patientId, patient_created: created, kob_session_id: kobSessionId })
  } catch (err) {
    console.error('ghl-booking-webhook error:', err)
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
