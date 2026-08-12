// ============================================================
// Edge Function: ghl-initial-sync
// Backfill SEKALI SAHAJA — tarik Contacts/Appointments/Orders LAMA dari
// GHL (pesakit yang datang sebelum ghl-booking-webhook dipasang, atau
// semasa downtime) masuk ISW. Guna semula logik teras yang sama dengan
// ghl-booking-webhook (_shared/ghl-sync.ts) supaya tiada drift.
//
// BUKAN webhook realtime — dipanggil MANUAL oleh admin (curl/Postman),
// satu muka surat data setiap panggilan (elak timeout Edge Function).
// Ulang panggil dengan `cursor` yang dipulangkan sehingga `hasMore:false`.
// Lihat README.md untuk contoh curl-loop.
//
// JWT ON — hanya staff dengan staff_role='super_admin' boleh panggil
// (operasi bulk-write, bukan untuk penggunaan harian).
//
// Secrets (guna semula, TIADA secret baharu):
//   GHL_ISW_TOKEN, GHL_ISW_LOCATION_ID
//   SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY — auto-inject
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { ghl } from '../_shared/ghl.ts'
import { syncContactToPatient, syncAppointmentToSession, syncOrderToPayment } from '../_shared/ghl-sync.ts'

const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

const PAGE_LIMIT = 100

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const url = Deno.env.get('SUPABASE_URL')!
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!
    const svcKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')!

    // ── Sahkan caller = super_admin ──────────────────────────
    const authHeader = req.headers.get('Authorization') || ''
    const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'unauthorized' }, 401)
    const { data: profile } = await userClient
      .from('psy_profiles').select('role, staff_role').eq('id', user.id).single()
    if (profile?.role !== 'staff' || profile?.staff_role !== 'super_admin') {
      return json({ error: 'forbidden — super_admin sahaja' }, 403)
    }

    const svc = createClient(url, svcKey)
    const body = await req.json().catch(() => ({}))
    const action = body.action as string
    const cursor = body.cursor || {}

    // ── action=contacts — GET /contacts/ ─────────────────────
    if (action === 'contacts') {
      let path = `/contacts/?locationId=${locationId}&limit=${PAGE_LIMIT}`
      if (cursor.startAfterId) path += `&startAfterId=${cursor.startAfterId}`
      if (cursor.startAfter) path += `&startAfter=${cursor.startAfter}`
      const data = await ghl(path, { method: 'GET' })
      const contacts = data?.contacts || []

      let processed = 0
      const errors: string[] = []
      for (const c of contacts) {
        try {
          await syncContactToPatient(svc, { phone: c.phone, fullName: c.contactName || c.firstName, email: c.email })
          processed++
        } catch (e) { errors.push(`${c.id}: ${(e as Error).message}`) }
      }

      const last = contacts[contacts.length - 1]
      const hasMore = contacts.length >= PAGE_LIMIT
      const nextCursor = hasMore && last ? { startAfterId: last.id, startAfter: last.dateAdded } : null
      return json({ processed, total: contacts.length, errors, cursor: nextCursor, hasMore })
    }

    // ── action=appointments — GET /calendars/events (v3) ────
    // Nota: filter kalendar KOB [WC] (WC1-WC5+EG) — isi CALENDAR_IDS di
    // bawah dgn ID kalendar sebenar (GET /calendars/?locationId=...).
    if (action === 'appointments') {
      if (!body.calendarId) return json({ error: 'calendarId wajib (satu kalendar setiap panggilan)' }, 400)
      let path = `/calendars/events?locationId=${locationId}&calendarId=${body.calendarId}&limit=${PAGE_LIMIT}`
      if (body.startTime) path += `&startTime=${body.startTime}`
      if (body.endTime) path += `&endTime=${body.endTime}`
      if (cursor.offset) path += `&offset=${cursor.offset}`
      const data = await ghl(path, { method: 'GET' })
      const events = data?.events || data?.appointments || []

      let processed = 0
      const errors: string[] = []
      for (const ev of events) {
        try {
          const contact = ev.contact || {}
          const { patientId } = await syncContactToPatient(svc, { phone: contact.phone, fullName: contact.name, email: contact.email })
          await syncAppointmentToSession(svc, patientId, {
            scheduledAt: new Date(ev.startTime),
            mode: ev.appointmentStatus === 'online' ? 'online' : 'f2f',
          })
          processed++
        } catch (e) { errors.push(`${ev.id}: ${(e as Error).message}`) }
      }

      const offset = (cursor.offset || 0) + events.length
      const hasMore = events.length >= PAGE_LIMIT
      return json({ processed, total: events.length, errors, cursor: hasMore ? { offset } : null, hasMore })
    }

    // ── action=orders — GET /payments/orders ─────────────────
    if (action === 'orders') {
      let path = `/payments/orders?altId=${locationId}&altType=location&limit=${PAGE_LIMIT}`
      if (cursor.offset) path += `&offset=${cursor.offset}`
      const data = await ghl(path, { method: 'GET' })
      const orders = data?.data || data?.orders || []

      let processed = 0
      const errors: string[] = []
      for (const o of orders) {
        try {
          const contact = o.contactSnapshot || o.contact || {}
          const { patientId } = await syncContactToPatient(svc, { phone: contact.phone, fullName: contact.name || contact.contactName, email: contact.email })
          const result = await syncOrderToPayment(svc, patientId, { orderId: o._id || o.id, amount: o.amount ?? o.total, status: o.status })
          if (!result.skipped) processed++
        } catch (e) { errors.push(`${o._id || o.id}: ${(e as Error).message}`) }
      }

      const offset = (cursor.offset || 0) + orders.length
      const hasMore = orders.length >= PAGE_LIMIT
      return json({ processed, total: orders.length, errors, cursor: hasMore ? { offset } : null, hasMore })
    }

    return json({ error: "action wajib — 'contacts' | 'appointments' | 'orders'" }, 400)
  } catch (err) {
    console.error('ghl-initial-sync error:', err)
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
