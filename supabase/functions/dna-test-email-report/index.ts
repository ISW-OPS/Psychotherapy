// ============================================================
// Edge Function: dna-test-email-report
// Hantar emel kepada pesakit berisi pautan muat turun laporan DNA
// (Step 4, dna-test.html). Dipanggil oleh staff yang log masuk.
// Emel dihantar via GHL (guna corak sama macam event-reminders).
// Secrets: GHL_ISW_TOKEN, GHL_ISW_LOCATION_ID, GHL_EMAIL_FROM
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const GHL_BASE = 'https://services.leadconnectorhq.com'
const GHL_VERSION = '2021-07-28'

async function ghl(path: string, init: RequestInit = {}) {
  const token = Deno.env.get('GHL_ISW_TOKEN')
  const res = await fetch(`${GHL_BASE}${path}`, {
    ...init,
    headers: { Authorization: `Bearer ${token}`, Version: GHL_VERSION, 'Content-Type': 'application/json', Accept: 'application/json', ...(init.headers || {}) },
  })
  const text = await res.text()
  let body: any = null
  try { body = text ? JSON.parse(text) : null } catch { body = text }
  if (!res.ok) throw new Error(`GHL ${path} ${res.status}: ${typeof body === 'string' ? body : JSON.stringify(body)}`)
  return body
}

const REPORT_LABELS: Record<string, string> = {
  plant_based: 'ISW Wellness Plant-Based Report (IB-LIFE)',
  health_risk: 'ISW Health Risk Report (IB-HRCD)',
  carrier_drug: 'ISW Carrier Status & Drug Sensitivity Report (IB-CANC)',
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing authorization')

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authHeader } } })
    const { data: { user }, error: userErr } = await userClient.auth.getUser()
    if (userErr || !user) throw new Error('Tidak sah: sila log masuk semula')
    const { data: callerProfile } = await userClient.from('psy_profiles').select('role, full_name').eq('id', user.id).single()
    if (!callerProfile || callerProfile.role !== 'staff') throw new Error('Akses ditolak: staff sahaja')

    const { process_id } = await req.json()
    if (!process_id) throw new Error('process_id diperlukan')

    const admin = createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } })

    const { data: proc, error: procErr } = await admin.from('psy_dna_test_process')
      .select('id, patient_id, report_files').eq('id', process_id).single()
    if (procErr || !proc) throw new Error('Proses DNA Test tidak dijumpai')

    const reportFiles = proc.report_files || {}
    const categories = Object.keys(reportFiles).filter(k => (reportFiles[k] || []).length > 0)
    if (!categories.length) throw new Error('Tiada laporan dimuat naik lagi')

    const { data: patient } = await admin.from('psy_patients')
      .select('full_name, mrn, email, user_id, psy_profiles!psy_patients_user_id_fkey(full_name, email)')
      .eq('id', proc.patient_id).single()
    if (!patient) throw new Error('Pesakit tidak dijumpai')

    const patientName = (patient as any).psy_profiles?.full_name || patient.full_name || patient.mrn || 'Pesakit'
    const patientEmail = (patient as any).psy_profiles?.email || patient.email
    if (!patientEmail) throw new Error('Pesakit ini tiada alamat emel berdaftar')

    // Signed URL 7 hari untuk setiap fail
    const linksHtml: string[] = []
    for (const key of categories) {
      const label = REPORT_LABELS[key] || key
      const files: string[] = reportFiles[key] || []
      const fileLinks: string[] = []
      for (const path of files) {
        const { data: signed, error: signErr } = await admin.storage.from('dna-test').createSignedUrl(path, 60 * 60 * 24 * 7)
        if (signErr || !signed) continue
        const fileName = path.split('/').pop()
        fileLinks.push(`<a href="${signed.signedUrl}">${fileName}</a>`)
      }
      if (fileLinks.length) linksHtml.push(`<li><b>${label}</b><br>${fileLinks.join('<br>')}</li>`)
    }
    if (!linksHtml.length) throw new Error('Gagal jana pautan muat turun laporan')

    const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')!
    const emailFrom = Deno.env.get('GHL_EMAIL_FROM') || ''
    const upsertRes = await ghl('/contacts/upsert', { method: 'POST', body: JSON.stringify({ locationId, email: patientEmail, name: patientName }) })
    const contactId = upsertRes?.contact?.id || upsertRes?.id
    if (!contactId) throw new Error('Gagal daftar kenalan emel di GHL')

    const html = `<p>Salam ${patientName},</p>
<p>Berikut adalah pautan muat turun laporan DNA Test anda (sah selama 7 hari):</p>
<ul>${linksHtml.join('')}</ul>
<p>Sila hubungi coach anda sekiranya ada sebarang pertanyaan.</p>
<p>Terima kasih,<br>Ibnu Sina Wellness</p>`

    const payload: Record<string, unknown> = { type: 'Email', contactId, subject: 'Laporan DNA Test Anda — Ibnu Sina Wellness', html }
    if (emailFrom) payload.emailFrom = emailFrom
    await ghl('/conversations/messages', { method: 'POST', body: JSON.stringify(payload) })

    await admin.from('psy_dna_test_process').update({ reports_emailed_at: new Date().toISOString() }).eq('id', process_id)

    return new Response(JSON.stringify({ success: true, sent_to: patientEmail }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (err) {
    console.error(err)
    return new Response(JSON.stringify({ error: (err as Error).message }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
