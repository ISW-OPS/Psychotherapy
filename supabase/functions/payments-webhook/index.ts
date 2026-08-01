// ============================================================
// Edge Function: payments-webhook
// LAPISAN 2 (Orkestra) — SUMBER KEBENARAN bayaran.
//
// Gateway (HitPay) PANGGIL fungsi ini server-ke-server bila status
// bayaran berubah. Kita:
//   1. Sahkan tandatangan (HMAC) via adapter — tolak kalau palsu
//   2. Cari baris pending (receipt_ref)
//   3. Idempotent — kalau dah 'completed', abaikan (webhook boleh cetus berkali)
//   4. Kalau 'completed' → fulfillOrder() (aktif pakej/plan/KOB/order)
//      → tanda payment completed
//   5. Kalau 'failed' → tanda failed
//
// Inilah SATU-SATUNYA tempat pakej/plan diaktifkan — hanya SELEPAS
// bayaran betul-betul disahkan. Client tidak lagi buat fulfillment.
//
// PUBLIC (verify-JWT OFF) — gateway panggil tanpa JWT Supabase.
// Dilindungi HMAC (HITPAY_SALT) oleh adapter.
//
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
//          PAYMENT_PROVIDER, HITPAY_SALT,
//          GHL_ISW_TOKEN, GHL_ISW_LOCATION_ID (resit WhatsApp)
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getProvider } from '../_shared/payments/index.ts'
import { sendWhatsApp } from '../_shared/ghl.ts'
import { buildReceiptPdf } from '../_shared/receipt_pdf.ts'

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

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  )

  try {
    // 1. Sahkan tandatangan gateway
    const result = await getProvider().verifyWebhook(req)
    if (!result.ok) return json({ error: 'Tandatangan tidak sah' }, 401)
    if (!result.reference) return json({ error: 'Tiada reference' }, 400)

    // 2. Cari baris bayaran
    const { data: rows } = await admin.from('psy_payments')
      .select('*').eq('receipt_ref', result.reference).limit(1)
    const payment = rows?.[0]
    if (!payment) {
      // Tiada rekod — balas 200 supaya gateway tak retry selamanya, tapi log.
      console.warn('payments-webhook: receipt tak jumpa', result.reference)
      return json({ ok: true, note: 'receipt tak jumpa' })
    }

    // 3. Idempotent — dah selesai? abaikan.
    if (payment.status === 'completed') return json({ ok: true, note: 'sudah completed' })

    // 4. Status dari gateway
    if (result.status === 'failed') {
      await admin.from('psy_payments').update({ status: 'failed', gateway_status: result.status })
        .eq('id', payment.id)
      return json({ ok: true, note: 'ditanda failed' })
    }
    if (result.status !== 'completed') {
      // pending/unknown — kemas kini status mentah sahaja, jangan fulfill lagi.
      await admin.from('psy_payments').update({ gateway_status: result.status }).eq('id', payment.id)
      return json({ ok: true, note: 'belum completed' })
    }

    // Semak silang amaun (toleransi 1 sen)
    const paidAmt = Number(result.amount || 0)
    const expected = Number(payment.total || 0)
    if (paidAmt && Math.abs(paidAmt - expected) > 0.01) {
      console.error(`payments-webhook: amaun tak padan ref=${result.reference} bayar=${paidAmt} jangka=${expected}`)
      await admin.from('psy_payments').update({ gateway_status: 'amount_mismatch' }).eq('id', payment.id)
      return json({ ok: false, error: 'amaun tak padan' }, 409)
    }

    // 5. FULFILL (aktif pakej/plan/KOB/order) — hanya sekali (dijaga oleh guard status di atas)
    await fulfillOrder(admin, payment)

    await admin.from('psy_payments').update({
      status: 'completed',
      gateway_status: result.status,
      paid_at: new Date().toISOString(),
      fulfilled_at: new Date().toISOString(),
    }).eq('id', payment.id)

    // Notifikasi pesakit
    if (payment.user_id) {
      await admin.from('psy_notifications').insert({
        user_id: payment.user_id,
        type: 'system',
        title: 'Pembayaran Berjaya ✅',
        body: `Resit ${payment.receipt_ref} — RM ${Number(payment.total).toFixed(2)} diterima.`,
        link: 'payment.html',
      }).catch(() => {})
    }

    // Resit auto ke WhatsApp — best-effort; kegagalan TIDAK gagalkan webhook
    // (fulfillment dah selesai; gateway tak patut retry sebab WA gagal).
    try {
      await sendReceiptWhatsApp(admin, payment)
    } catch (waErr) {
      console.warn('payments-webhook: resit WhatsApp gagal —', (waErr as Error).message)
    }

    return json({ ok: true })
  } catch (err) {
    console.error('payments-webhook error:', (err as Error).message)
    return json({ error: (err as Error).message }, 500)
  }
})

// ---- Notifikasi staff (coach pesakit + admin/manager) bila apa-apa jenis bayaran diterima ----
const PAYMENT_ITEM_LABELS: Record<string, (item: any) => string> = {
  appointment: () => 'Temujanji',
  package: (item) => `Pakej ${item.packageName || ''}`.trim(),
  package_existing: (item) => `Pakej ${item.raw?.package_name || ''}`.trim(),
  plan_extension: () => 'Sambungan Minggu Rawatan',
  kob: () => 'Yuran KYC/KOB',
  kob_package: () => 'Pakej KOB',
}

async function notifyStaffPaymentReceived(admin: any, patientId: string | null, labels: string[], total: number, receiptRef: string) {
  if (!labels.length) return
  const targets = new Set<string>()
  let patientLabel = 'Pesakit'
  if (patientId) {
    const { data: pt } = await admin.from('psy_patients').select('coach_id, full_name, mrn').eq('id', patientId).limit(1)
    const p = pt?.[0]
    if (p?.coach_id) targets.add(p.coach_id)
    patientLabel = p?.full_name || p?.mrn || patientLabel
  }
  const { data: staff } = await admin.from('psy_profiles').select('id').eq('role', 'staff').in('staff_role', ['admin', 'manager'])
  ;(staff || []).forEach((s: any) => targets.add(s.id))
  const body = `${patientLabel} telah membayar: ${labels.join(', ')} — RM ${Number(total || 0).toFixed(2)} (${receiptRef})`
  for (const uid of targets) {
    await admin.from('psy_notifications').insert({
      user_id: uid, type: 'payment', title: 'Pembayaran Diterima 💳', body,
      link: patientId ? `../staff/patient-hub.html?id=${patientId}` : 'payment-admin.html',
    }).catch(() => {})
  }
}

// ---- Fulfillment: replay INTENT tersimpan (port dari processPayment client) ----
async function fulfillOrder(admin: any, payment: any) {
  const intent = payment.intent || {}
  const items: any[] = Array.isArray(intent.items) ? intent.items : []
  const patientId: string | null = intent.patientId || payment.patient_id || null
  const receiptRef: string = payment.receipt_ref
  const method = 'gateway'
  const now = new Date().toISOString()
  const staffLabels: string[] = []

  for (const item of items) {
    if (PAYMENT_ITEM_LABELS[item.type]) staffLabels.push(PAYMENT_ITEM_LABELS[item.type](item))
    if (item.type === 'appointment') {
      const cleanNotes = String(item.raw?.notes || '').replace('[PENDING PAYMENT]', '').trim()
      await admin.from('psy_appointments').update({ notes: `[PAID · ${receiptRef}] ${cleanNotes}` }).eq('id', item.id)

    } else if (item.type === 'package') {
      const expires = new Date(); expires.setMonth(expires.getMonth() + 3)

      // Continuity (pakej sambungan): jika pesakit MASIH ada pakej aktif belum tamat,
      // pakej baru ini BERATUR (queued) — auto-aktif bila pakej semasa selesai
      // (trigger fn_auto_inactive_on_session_done / step93). Jangan aktif serta-merta.
      let queue = false
      if (item.continuity && patientId) {
        const { data: ptRows } = await admin.from('psy_patients')
          .select('active_package_id, package_expires_at').eq('id', patientId).limit(1)
        const cur = ptRows?.[0]
        queue = !!(cur?.active_package_id &&
          (!cur.package_expires_at || new Date(cur.package_expires_at) >= new Date()))
      }

      if (queue) {
        await admin.from('psy_package_purchases').insert({
          patient_id: patientId, package_id: item.packageId, package_name: item.packageName,
          price: item.amount, expires_at: expires.toISOString(), status: 'queued', payment_method: method,
        })
        await admin.from('psy_patients').update({
          next_package_id: item.packageId, next_package_name: item.packageName,
        }).eq('id', patientId)
        // Tiada pengaktifan / cipta plan di sini — trigger buat bila pakej semasa selesai.
      } else {
        await admin.from('psy_package_purchases').insert({
          patient_id: patientId, package_id: item.packageId, package_name: item.packageName,
          price: item.amount, expires_at: expires.toISOString(), status: 'active', payment_method: method,
        })
        await admin.from('psy_patients').update({
          active_package_id: item.packageId, active_package_name: item.packageName,
          package_purchased_at: now, package_expires_at: expires.toISOString(),
        }).eq('id', patientId)

        // Auto-cipta treatment plan jika belum ada yang aktif
        const { data: existing } = await admin.from('psy_treatment_plans')
          .select('id').eq('patient_id', patientId).eq('status', 'active').limit(1)
        if (!existing?.length) {
          const tpl = await getPlanTemplate(admin, item.packageId, item.packageName)
          await admin.from('psy_treatment_plans').insert({
            patient_id: patientId, doctor_id: null, name: tpl.name,
            duration_unit: tpl.duration_unit, duration_weeks: tpl.duration_weeks,
            current_week: 1, coaching_schedule: tpl.coaching_schedule, status: 'active',
          })
        }
      }

    } else if (item.type === 'package_existing') {
      await admin.from('psy_package_purchases').update({ status: 'active', payment_method: method }).eq('id', item.id)
      const exp = item.raw?.expires_at || (() => { const d = new Date(); d.setMonth(d.getMonth() + 3); return d.toISOString() })()
      await admin.from('psy_patients').update({
        active_package_id: item.raw?.package_id, active_package_name: item.raw?.package_name,
        package_purchased_at: item.raw?.purchased_at || now, package_expires_at: exp,
      }).eq('id', patientId)

    } else if (item.type === 'plan_extension') {
      for (const rowId of (item.rowIds || [])) {
        await admin.from('psy_plan_weekly_progress')
          .update({ status: 'extension_paid', extension_paid_at: now }).eq('id', rowId)
      }

    } else if (item.type === 'kob') {
      await admin.from('psy_patients').update({ kob_status: 'paid' }).eq('id', patientId)

    } else if (item.type === 'kob_package') {
      if (item.kobSessionId) {
        await admin.from('psy_kob_sessions').update({
          package_payment_status: 'paid', package_paid_at: now, package_receipt_ref: receiptRef,
        }).eq('id', item.kobSessionId)
      }
      // ELAK race condition: kalau doktor dah tandakan KOB 'completed' (markSelesai
      // di kob-detail.html) SEBELUM webhook ni sempat jalan (cth webhook lambat/
      // pembayaran lewat disahkan), jangan turunkan balik status ke 'package_paid'.
      await admin.from('psy_patients').update({ kob_status: 'package_paid' })
        .eq('id', patientId).neq('kob_status', 'completed')

    } else if (item.type === 'shop_order') {
      await admin.from('psy_orders').insert({
        order_ref: item.orderRef, patient_id: intent.userId, items: item.items,
        total: item.amount, status: 'paid', paid_at: now,
        delivery_method: item.deliveryMethod,
        delivery_address: item.deliveryAddress || null,
        courier: item.deliveryMethod === 'pos' ? 'JNT' : null,
        notes: item.deliveryMethod === 'pickup' ? 'Pickup Konsultasi' : null,
      })
      // Notify admin & manager
      try {
        const { data: staff } = await admin.from('psy_profiles')
          .select('id').eq('role', 'staff').in('staff_role', ['admin', 'manager'])
        for (const s of (staff || [])) {
          await admin.from('psy_notifications').insert({
            user_id: s.id, type: 'order', title: 'Pesanan Baru Diterima',
            body: `Pesanan baru diterima (RM${Number(item.amount).toFixed(2)}).`,
            link: '../staff/orders.html',
          })
        }
      } catch (_) { /* nota: notifikasi gagal tidak halang fulfillment */ }
    }
  }

  try {
    await notifyStaffPaymentReceived(admin, patientId, staffLabels, payment.total, receiptRef)
  } catch (_) { /* nota: notifikasi gagal tidak halang fulfillment */ }
}

// ---- Resit WhatsApp: PDF rasmi (attachment) + mesej ringkas ----
// PDF gagal jana/upload → fallback hantar teks ringkasan sahaja.
async function sendReceiptWhatsApp(admin: any, payment: any) {
  // Butiran pesakit: psy_patients dulu, fallback psy_profiles + auth (email)
  let phone: string | null = null, name: string | null = null
  let nric: string | null = null, mrn: string | null = null, email: string | null = null
  let userId: string | null = payment.user_id || null
  const patientId = payment.patient_id || payment.intent?.patientId || null

  if (patientId) {
    const { data: pt } = await admin.from('psy_patients')
      .select('full_name, phone, ic_number, mrn, user_id').eq('id', patientId).limit(1)
    const p = pt?.[0]
    if (p) {
      phone = p.phone || null; name = p.full_name || null
      nric = p.ic_number || null; mrn = p.mrn || null
      userId = userId || p.user_id || null
    }
  }
  if ((!phone || !name) && userId) {
    const { data: prof } = await admin.from('psy_profiles')
      .select('full_name, phone').eq('id', userId).limit(1)
    phone = phone || prof?.[0]?.phone || null
    name = name || prof?.[0]?.full_name || null
  }
  if (userId) {
    const { data: au } = await admin.auth.admin.getUserById(userId).catch(() => ({ data: null }))
    email = au?.user?.email || null
  }
  if (!phone) throw new Error('pesakit tiada nombor telefon')

  const items: any[] = Array.isArray(payment.items) ? payment.items : []
  const paidAt = payment.paid_at || new Date().toISOString()

  // ── Jana PDF + upload ke Storage → signed URL ────────────
  let pdfUrl: string | null = null
  try {
    const bytes = await buildReceiptPdf({
      receiptRef: payment.receipt_ref, paidAt,
      patientName: name, nric, mrn, email, phone,
      items, total: Number(payment.total || 0),
    })
    const bucket = 'receipts'
    // Cipta bucket kalau belum ada (idempotent — abaikan 'already exists')
    await admin.storage.createBucket(bucket, { public: false }).catch(() => {})
    const path = `${payment.receipt_ref}.pdf`
    const { error: upErr } = await admin.storage.from(bucket)
      .upload(path, bytes, { contentType: 'application/pdf', upsert: true })
    if (upErr) throw upErr
    const { data: signed, error: sgErr } = await admin.storage.from(bucket)
      .createSignedUrl(path, 7 * 24 * 3600) // 7 hari — GHL muat turun serta-merta
    if (sgErr || !signed?.signedUrl) throw (sgErr || new Error('signed URL kosong'))
    pdfUrl = signed.signedUrl
  } catch (pdfErr) {
    console.warn('payments-webhook: PDF resit gagal, fallback teks —', (pdfErr as Error).message)
  }

  // ── Mesej WhatsApp ────────────────────────────────────────
  const my = new Date(new Date(paidAt).getTime() + 8 * 3600 * 1000)
  const pad = (n: number) => String(n).padStart(2, '0')
  const tarikh = `${pad(my.getUTCDate())}/${pad(my.getUTCMonth() + 1)}/${my.getUTCFullYear()} ${pad(my.getUTCHours())}:${pad(my.getUTCMinutes())}`

  let message: string
  if (pdfUrl) {
    // PDF dilampirkan — mesej ringkas sahaja
    message = [
      '🧾 *RESIT PEMBAYARAN — ISW*',
      '',
      `Terima kasih${name ? `, ${name}` : ''}! Pembayaran anda telah diterima. ✅`,
      '',
      `No. Resit: ${payment.receipt_ref}`,
      `*Jumlah: RM ${Number(payment.total || 0).toFixed(2)}*`,
      '',
      'Resit rasmi dilampirkan (PDF). Salinan juga tersedia dalam aplikasi di menu *Sejarah Pembayaran & Resit*.',
    ].join('\n')
  } else {
    // Fallback: ringkasan penuh dalam teks
    const lines = items
      .map((i) => `• ${i.title || i.type} — RM ${Number(i.amount || 0).toFixed(2)}`)
      .join('\n')
    message = [
      '🧾 *RESIT PEMBAYARAN — ISW*',
      '',
      `Terima kasih${name ? `, ${name}` : ''}! Pembayaran anda telah diterima. ✅`,
      '',
      `No. Resit: ${payment.receipt_ref}`,
      `Tarikh: ${tarikh}`,
      ...(lines ? ['', lines] : []),
      '',
      `*Jumlah: RM ${Number(payment.total || 0).toFixed(2)}*`,
      '',
      'Resit rasmi (PDF) boleh dimuat turun dalam aplikasi di menu *Sejarah Pembayaran & Resit*.',
    ].join('\n')
  }

  await sendWhatsApp(admin, {
    phone,
    name,
    message,
    attachments: pdfUrl ? [pdfUrl] : [],
    sentByName: 'Auto — Resit Pembayaran',
  })
}

const isUuid = (s: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)

async function getPlanTemplate(admin: any, packageId: string, packageName: string) {
  // GOTCHA: id.eq.<kod-bukan-uuid> error di Postgres — guard ikut format key.
  let q = admin.from('psy_packages').select('name, duration_weeks, duration_unit, coaching_schedule')
  q = isUuid(String(packageId)) ? q.or(`id.eq.${packageId},package_id.eq.${packageId}`) : q.eq('package_id', packageId)
  const { data } = await q.limit(1)
  const p = data?.[0]
  if (!p) return { name: `${packageName} Plan`, duration_weeks: 12, duration_unit: 'week', coaching_schedule: [] }
  return {
    name: `${p.name} Treatment Plan`,
    duration_weeks: p.duration_weeks || 12,
    duration_unit: p.duration_unit || 'week',
    coaching_schedule: p.coaching_schedule || [],
  }
}
