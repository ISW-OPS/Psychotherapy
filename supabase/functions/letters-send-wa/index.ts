// ============================================================
// Edge Function: letters-send-wa
// Audit #143 — "auto-send" surat: lepas staff lulus & tandatangan surat
// di surat-issue.html (psy_letter_issued baru dicipta), fungsi ni hantar
// WhatsApp KEPADA PESAKIT memberitahu surat dah sedia. Notifikasi
// dalam-app (psy_notifications, via notify()) sudah wujud — ni tambahan
// SAHAJA, tak gantikan notify().
//
// Aliran: surat-issue.html confirmSign() → insert psy_letter_issued →
// notify() (dalam-app, tak berubah) → panggil fungsi ni dgn {issuedId}.
// Guna sendWhatsApp() SAMA helper yang dipakai payments-send-receipt
// (_shared/ghl.ts) — ikut corak sedia ada, bukan integrasi baharu.
//
// Surat internal (patient_id NULL, cth surat pengesahan kerja staff
// sendiri) — TIADA pesakit, jadi skip terus (ok:true, skipped:true).
//
// Rekod status penghantaran pada psy_letter_issued.wa_sent_at /
// wa_send_status ('sent' | 'failed') — lihat database/schema/15_letters.sql
// + supabase/migrations/20261007_surat_auto_send_wa.sql.
//
// Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
//          GHL_ISW_TOKEN, GHL_ISW_LOCATION_ID
// verify-JWT: ON (default) — staff mesti log masuk.
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { sendWhatsApp } from '../_shared/ghl.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'POST sahaja' }, 405)

  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
  const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
  const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } })
  let issuedId = ''

  try {
    // 1. Sahkan caller = staff (pattern sama payments-send-receipt)
    const authHeader = req.headers.get('Authorization') || ''
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Tidak dibenarkan (sila log masuk)' }, 401)
    const { data: profile } = await userClient.from('psy_profiles').select('role').eq('id', user.id).single()
    if (profile?.role !== 'staff') return json({ error: 'forbidden — staff sahaja' }, 403)

    // 2. Baca surat yang dikeluarkan
    const body = await req.json().catch(() => ({}))
    issuedId = String(body.issuedId || '')
    if (!issuedId) return json({ error: 'issuedId diperlukan' }, 400)

    const { data: rows } = await admin.from('psy_letter_issued').select('*').eq('id', issuedId).limit(1)
    const letter = rows?.[0]
    if (!letter) return json({ error: 'Surat tidak dijumpai' }, 404)

    // Surat internal (bukan untuk pesakit) — tiada pesakit nak dihantar WA, skip senyap.
    if (!letter.patient_id) return json({ ok: true, skipped: 'internal_document' })

    // 3. Butiran pesakit — phone + nama (ikut contact_preference waris, sama corak resit)
    const { data: pt } = await admin.from('psy_patients')
      .select('full_name, phone, user_id, emergency_contact_phone, emergency_contact_name, contact_preference')
      .eq('id', letter.patient_id).limit(1)
    const p = pt?.[0]
    if (!p) return json({ error: 'Rekod pesakit tidak dijumpai' }, 404)

    let phone: string | null, contactName: string | null
    const name = p.full_name || letter.patient_name || null
    if (p.contact_preference === 'waris' && p.emergency_contact_phone) {
      phone = p.emergency_contact_phone
      contactName = p.emergency_contact_name || name
    } else {
      phone = p.phone || null
      contactName = name
    }
    if (!phone) return json({ error: 'pesakit tiada nombor telefon' }, 400)

    // 4. Mesej WhatsApp — ikut gaya sedia ada (payments-send-receipt)
    const message = [
      '✉️ *SURAT ANDA SEDIA — ISW*',
      '',
      `Assalamualaikum${name ? ` ${name}` : ''}, surat *${letter.template_name}* anda sudah sedia.`,
      '',
      `No. Rujukan: ${letter.ref_number || '-'}`,
      '',
      'Sila log masuk ke portal pesakit anda (menu *Surat*) untuk semak & muat turun.',
    ].join('\n')

    // file_url (kalau staff upload PDF rasmi selepas isu) — lampirkan terus kalau wujud.
    const attachments = letter.file_url ? [letter.file_url] : []

    await sendWhatsApp(admin, {
      phone,
      name: contactName,
      message,
      attachments,
      sentByName: 'Auto — Surat Dikeluarkan',
    })

    await admin.from('psy_letter_issued')
      .update({ wa_sent_at: new Date().toISOString(), wa_send_status: 'sent' })
      .eq('id', issuedId)

    return json({ ok: true })
  } catch (err) {
    if (issuedId) {
      try {
        await admin.from('psy_letter_issued')
          .update({ wa_send_status: 'failed' })
          .eq('id', issuedId)
      } catch { /* jangan halang response ralat utama */ }
    }
    return json({ error: (err as Error).message || 'Ralat tidak diketahui' }, 500)
  }
})
