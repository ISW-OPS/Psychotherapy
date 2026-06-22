// ============================================================
// event-reminders — VERSI COPY-PASTE untuk Supabase Dashboard editor.
// (cors di-INLINE; tiada import ../_shared/cors.ts)
// Deploy: Dashboard → Edge Functions → Create function → nama "event-reminders"
//         → paste fail ini → Verify JWT = OFF → Deploy.
// Secrets perlu: GHL_ISW_TOKEN, GHL_ISW_LOCATION_ID, CRON_SECRET
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-cron-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const GHL_BASE = 'https://services.leadconnectorhq.com'
const GHL_VERSION = '2021-07-28'
const REMIND_BEFORE_MIN = 60
const WINDOW_HALF_MIN = 10

function toE164(raw: string | null | undefined): string | null {
  if (!raw) return null
  let n = String(raw).replace(/[^\d+]/g, '')
  if (n.startsWith('+')) return n
  if (n.startsWith('60')) return '+' + n
  if (n.startsWith('0')) return '+60' + n.slice(1)
  return '+' + n
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
  if (!res.ok) throw new Error(`GHL ${path} → ${res.status}: ${typeof body === 'string' ? body : JSON.stringify(body)}`)
  return body
}

async function upsertContact(locationId: string, phone: string, name?: string | null) {
  const [firstName, ...rest] = String(name || '').trim().split(/\s+/)
  const r = await ghl('/contacts/upsert', {
    method: 'POST',
    body: JSON.stringify({ locationId, phone, firstName: firstName || undefined, lastName: rest.join(' ') || undefined, name: name || undefined }),
  })
  return r?.contact?.id || r?.id
}

// type:'SMS' — saluran SMS GHL klinik di-route ke WhatsApp (sama macam ghl-inbox).
async function sendWhatsApp(contactId: string, message: string) {
  return ghl('/conversations/messages', { method: 'POST', body: JSON.stringify({ type: 'SMS', contactId, message }) })
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    if (req.headers.get('x-cron-secret') !== Deno.env.get('CRON_SECRET')) {
      return new Response(JSON.stringify({ error: 'forbidden' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')!
    const now = Date.now()
    const t1 = new Date(now + (REMIND_BEFORE_MIN - WINDOW_HALF_MIN) * 60000).toISOString()
    const t2 = new Date(now + (REMIND_BEFORE_MIN + WINDOW_HALF_MIN) * 60000).toISOString()
    const { data: events, error: evErr } = await supabase.from('psy_events')
      .select('id, title, start_at, mode, meet_link, location, maps_url')
      .eq('status', 'published').gte('start_at', t1).lte('start_at', t2)
    if (evErr) throw evErr
    if (!events?.length) return new Response(JSON.stringify({ success: true, due: 0, sent: 0, reason: 'no events due' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    const evMap: Record<string, any> = Object.fromEntries(events.map((e: any) => [e.id, e]))
    const { data: regs, error: regErr } = await supabase.from('psy_event_registrations')
      .select('id, event_id, psy_patients(phone, full_name)')
      .in('event_id', events.map((e: any) => e.id)).is('reminder_sent_at', null).neq('status', 'batal')
    if (regErr) throw regErr
    let sent = 0, skipped = 0
    const errors: string[] = []
    for (const r of regs || []) {
      const ev = evMap[(r as any).event_id]
      const p = (r as any).psy_patients || {}
      const phone = toE164(p.phone)
      if (!ev || !phone) { skipped++; continue }
      try {
        const cid = await upsertContact(locationId, phone, p.full_name)
        if (!cid) throw new Error('no contactId')
        const when = new Date(ev.start_at).toLocaleString('ms-MY', { dateStyle: 'medium', timeStyle: 'short' })
        const extra = ev.mode === 'f2f' ? (ev.location ? `📍 Lokasi: ${ev.location}` + (ev.maps_url ? `\n🗺 ${ev.maps_url}` : '') : '') : (ev.meet_link ? `📹 Sertai: ${ev.meet_link}` : '')
        const msg = `Salam ${p.full_name || ''} 👋\n\nPeringatan: acara *${ev.title}* akan bermula lebih kurang sejam lagi (${when}).\n${extra}\n\n— Ibnu Sina Wellness`
        await sendWhatsApp(cid, msg)
        await supabase.from('psy_event_registrations').update({ reminder_sent_at: new Date().toISOString() }).eq('id', (r as any).id)
        sent++
      } catch (e) { errors.push(`${(r as any).id}: ${String((e as any)?.message || e)}`) }
    }
    return new Response(JSON.stringify({ success: true, due: events.length, candidates: regs?.length || 0, sent, skipped, errors }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (err) {
    console.error('event-reminders error:', err)
    return new Response(JSON.stringify({ error: String((err as any)?.message || err) }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
