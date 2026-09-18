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
//          PUBLIC_APP_URL (returnUrl pautan auto-retry kob_deposit — sama secret
//          dgn event-reminders, lihat notifyPaymentFailed)
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getProvider } from '../_shared/payments/index.ts'
import { sendPaymentReceiptWhatsApp } from '../_shared/receipt_pdf.ts'
import { sendWhatsApp } from '../_shared/ghl.ts'
import { createKobDepositLink } from '../_shared/kob_retry_link.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

// Sama pattern dgn event-reminders/index.ts — isi {placeholder} (psy_auto_messages,
// sistem lama) ATAU {{placeholder}} (psy_automation_messages, sistem baharu — Insert
// Variable di automation-builder.html sisip gaya kurungan-dua).
function fillTemplate(tpl: string, vars: Record<string, string>) {
  return Object.entries(vars).reduce((s, [k, v]) => s.split(`{{${k}}}`).join(v ?? '').split(`{${k}}`).join(v ?? ''), tpl || '').replace(/\n{3,}/g, '\n\n').trim()
}

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
      const alreadyFailed = payment.status === 'failed'
      await admin.from('psy_payments').update({ status: 'failed', gateway_status: result.status })
        .eq('id', payment.id)
      // Notifikasi (patient + staff) sekali sahaja — HitPay boleh hantar webhook
      // 'failed' berkali-kali (retry), jangan spam. Best-effort — kegagalan
      // notifikasi TIDAK gagalkan webhook (status dah ditanda failed di atas).
      if (!alreadyFailed) {
        try { await notifyPaymentFailed(admin, payment) }
        catch (e) { console.warn('payments-webhook: notifyPaymentFailed gagal —', (e as Error).message) }
      }
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

    // 5. Tuntut baris ini SECARA ATOM sebelum fulfillment. HitPay boleh hantar webhook
    // SAMA berkali-kali serentak (retry) — guard status di langkah 3 tak cukup sebab ia
    // hanya ditulis balik SELEPAS fulfillOrder() siap, jadi panggilan serentak semua lepas
    // pemeriksaan tu sebelum mana-mana sempat commit → psy_treatment_plans/psy_package_purchases
    // dicipta BERGANDA (punca pakej "Overhaul Body Diamond Y1" x4 baris kes prod 7 Ogos).
    // UPDATE...WHERE fulfilled_at IS NULL bergantung pada row-level lock Postgres — hanya
    // SATU panggilan serentak akan "menang" (dapat baris balik); yang lain dapat 0 baris & keluar.
    const { data: claimed } = await admin.from('psy_payments')
      .update({ fulfilled_at: new Date().toISOString(), gateway_status: result.status })
      .eq('id', payment.id).is('fulfilled_at', null).select('id')
    if (!claimed?.length) {
      return json({ ok: true, note: 'sedang/sudah diproses oleh panggilan lain' })
    }

    // FULFILL (aktif pakej/plan/KOB/order)
    try {
      await fulfillOrder(admin, payment)
    } catch (fulfillErr) {
      // Lepaskan claim supaya webhook retry akan datang boleh cuba semula.
      try { await admin.from('psy_payments').update({ fulfilled_at: null }).eq('id', payment.id) } catch {}
      throw fulfillErr
    }

    await admin.from('psy_payments').update({
      status: 'completed',
      paid_at: new Date().toISOString(),
    }).eq('id', payment.id)

    // Notifikasi pesakit
    if (payment.user_id) {
      try {
        await admin.from('psy_notifications').insert({
          user_id: payment.user_id,
          type: 'system',
          title: 'Pembayaran Berjaya ✅',
          body: `Resit ${payment.receipt_ref} — RM ${Number(payment.total).toFixed(2)} diterima.`,
          link: 'payment.html',
        })
      } catch {}
    }

    // Resit auto ke WhatsApp — best-effort; kegagalan TIDAK gagalkan webhook
    // (fulfillment dah selesai; gateway tak patut retry sebab WA gagal).
    try {
      await sendPaymentReceiptWhatsApp(admin, payment)
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
  kob_deposit: (item) => item.mode === 'installment' ? 'Deposit Ansuran Pakej' : 'Bayaran Penuh Pakej (KOB)',
  kob_installment_topup: () => 'Ansuran Pakej (Top-up)',
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
    try {
      await admin.from('psy_notifications').insert({
        user_id: uid, type: 'payment', title: 'Pembayaran Diterima 💳', body,
        link: patientId ? `../staff/patient-hub.html?id=${patientId}` : 'payment-admin.html',
      })
    } catch {}
  }
}

// ---- Bayaran gagal/dibatalkan gateway (HitPay) — beritahu patient (in-app +
// WhatsApp) & staff (coach + admin/manager), supaya susulan berlaku terus tanpa
// staff kena semak Sejarah Pembayaran secara manual. Best-effort sepenuhnya —
// dipanggil dalam try/catch di caller, tidak pernah gagalkan webhook.
async function notifyPaymentFailed(admin: any, payment: any) {
  const patientId: string | null = payment.intent?.patientId || payment.patient_id || null
  const items: any[] = Array.isArray(payment.items) ? payment.items : []
  const labels = items.map(it => PAYMENT_ITEM_LABELS[it.type]?.(it)).filter(Boolean)
  const itemDesc = labels.length ? labels.join(', ') : 'pembayaran';
  const amount = Number(payment.total || 0).toFixed(2)

  let patient: { phone?: string | null; full_name?: string | null; coach_id?: string | null } | null = null
  if (patientId) {
    const { data } = await admin.from('psy_patients')
      .select('phone, full_name, coach_id').eq('id', patientId).limit(1)
    patient = data?.[0] || null
  }
  const patientLabel = patient?.full_name || 'Pesakit'

  // Notifikasi in-app pesakit
  if (payment.user_id) {
    try {
      await admin.from('psy_notifications').insert({
        user_id: payment.user_id, type: 'system', title: 'Bayaran Tidak Berjaya ⚠️',
        body: `Bayaran ${itemDesc} (RM ${amount}, resit ${payment.receipt_ref}) tidak berjaya/dibatalkan. Sila cuba lagi atau hubungi klinik.`,
        link: 'payment.html',
      })
    } catch {}
  }

  // Auto-jana pautan HitPay BAHARU untuk kob_deposit sahaja (staff-initiated —
  // pesakit KOB selalunya TIADA akaun/log masuk utk retry sendiri dalam app,
  // tak macam laluan payments-initiate/kob.html biasa yg pesakit boleh klik
  // "Cuba Bayar Semula" sendiri). Kalau sesi KOB dah tak eligible (cth status
  // berubah/staff dah proses lain) — gagal SENYAP, jatuh balik ke mesej teks
  // biasa (elak hantar pautan basi utk pakej/harga yg dah tak relevan).
  const kobItem = items.find((it: any) => it.type === 'kob_deposit' && it.kobSessionId)
  let retryUrl: string | null = null
  if (kobItem) {
    try {
      const returnUrl = `${Deno.env.get('PUBLIC_APP_URL')}/roles/patient/payment-receipt.html`
      const link = await createKobDepositLink(admin, {
        kobSessionId: kobItem.kobSessionId, mode: kobItem.mode || 'full', tier: kobItem.tier, returnUrl,
      })
      retryUrl = link.checkoutUrl
    } catch (e) {
      console.warn('notifyPaymentFailed: auto-jana pautan baharu gagal (jatuh balik ke teks biasa) —', (e as Error).message)
    }
  }

  // WhatsApp ke pesakit — best-effort, patient KOB selalunya belum ada akaun
  // (tiada user_id) jadi notifikasi in-app di atas tak sampai; WA ni jalan utama.
  // Teks diambil dari psy_auto_messages (key='payment_failed') — boleh edit di UI
  // Automatic Messages > Message Template tanpa re-deploy. is_active=false = SKIP
  // terus (sama corak dgn semua template lain, cth installment_reminder) — bukan
  // jatuh balik ke teks lain; staff yang matikan bermakna sengaja nak senyapkan WA ni.
  if (patient?.phone) {
    const { data: tplRow } = await admin.from('psy_auto_messages')
      .select('message_template, is_active').eq('key', 'payment_failed').maybeSingle()
    if (tplRow?.is_active && tplRow.message_template) {
      const pautan = retryUrl
        ? `Sila lengkapkan bayaran melalui pautan selamat di bawah:\n\n${retryUrl}`
        : 'Sila cuba semula atau hubungi Pusat Rawatan ISW untuk bantuan.'
      const waMessage = fillTemplate(tplRow.message_template, { nama: patientLabel, item: itemDesc, jumlah: amount, pautan })
      await sendWhatsApp(admin, {
        phone: patient.phone, name: patient.full_name,
        message: waMessage,
        sentByName: 'Auto — Bayaran Gagal',
      }).catch((e: Error) => console.warn('notifyPaymentFailed: WA pesakit gagal —', e.message))
    }
  }

  // Sistem BAHARU (Create Automation) — psy_automations trigger_category='payment'
  // trigger_event='payment_failed'. Berjalan SERENTAK dgn blok psy_auto_messages di
  // atas (dua-dua ada is_active sendiri, tiada koordinasi diperlukan) — staff cutover
  // dgn matikan blok lama bila dah sahkan yang baharu jalan (lihat plan migration).
  if (patient?.phone) {
    const { data: autos } = await admin.from('psy_automations')
      .select('id, psy_automation_messages(*)')
      .eq('is_active', true).eq('trigger_category', 'payment').eq('trigger_event', 'payment_failed')
    const pautan = retryUrl
      ? `Sila lengkapkan bayaran melalui pautan selamat di bawah:\n\n${retryUrl}`
      : 'Sila cuba semula atau hubungi Pusat Rawatan ISW untuk bantuan.'
    for (const auto of autos || []) {
      const msg = (auto.psy_automation_messages || []).sort((a: any, b: any) => a.position - b.position)[0]
      if (!msg || !msg.message_text) continue
      const waMessage = fillTemplate(msg.message_text, { nama: patientLabel, item: itemDesc, jumlah: amount, pautan })
      const attachments = msg.media_url ? [msg.media_url] : []
      try {
        await sendWhatsApp(admin, { phone: patient.phone, name: patient.full_name, message: waMessage, attachments, sentByName: 'Auto — Bayaran Gagal' })
        try {
          await admin.from('psy_notification_logs').insert({
            automation_id: auto.id, patient_id: patientId, patient_name: patientLabel,
            event: 'payment_failed', channel: 'whatsapp', status: 'sent', message: waMessage.slice(0, 2000),
            message_id: msg.id, sent_at: new Date().toISOString(),
          })
        } catch {}
      } catch (e) {
        console.warn('notifyPaymentFailed: WA (automation baharu) gagal —', (e as Error).message)
        try {
          await admin.from('psy_notification_logs').insert({
            automation_id: auto.id, patient_id: patientId, patient_name: patientLabel,
            event: 'payment_failed', channel: 'whatsapp', status: 'failed', message: waMessage.slice(0, 2000),
            message_id: msg.id, error: String((e as Error)?.message || e),
          })
        } catch {}
      }
    }
  }

  // Notifikasi staff (coach pesakit + admin/manager)
  const targets = new Set<string>()
  if (patient?.coach_id) targets.add(patient.coach_id)
  const { data: staff } = await admin.from('psy_profiles').select('id').eq('role', 'staff').in('staff_role', ['admin', 'manager'])
  ;(staff || []).forEach((s: any) => targets.add(s.id))
  const staffBody = `${patientLabel} — bayaran ${itemDesc} (RM ${amount}, ${payment.receipt_ref}) tidak berjaya/dibatalkan.` +
    (retryUrl ? ' Pautan baharu telah auto-dihantar ke WhatsApp pesakit.' : '')
  for (const uid of targets) {
    try {
      await admin.from('psy_notifications').insert({
        user_id: uid, type: 'payment', title: 'Bayaran Gagal ⚠️', body: staffBody,
        link: patientId ? `../staff/patient-hub.html?id=${patientId}` : 'payment-admin.html',
      })
    } catch {}
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
          const { data: newPlan } = await admin.from('psy_treatment_plans').insert({
            patient_id: patientId, doctor_id: null, name: tpl.name,
            duration_unit: tpl.duration_unit, duration_weeks: tpl.duration_weeks,
            current_week: 1, coaching_schedule: tpl.coaching_schedule, status: 'active',
          }).select('id').single()
          if (newPlan?.id) await seedPlanWeeklyProgress(admin, newPlan.id, patientId, tpl.coaching_schedule, tpl.duration_weeks)
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
      const wasAlreadyCompleted = await isKobStatusCompleted(admin, patientId)
      await admin.from('psy_patients').update({ kob_status: 'package_paid' })
        .eq('id', patientId).neq('kob_status', 'completed')
      // Pesakit beli LEWAT (kob_status dah 'completed' sebelum bayaran ni, cth self-checkout
      // Now-tier lepas declined+Selesai) — markSelesai() takkan panggil lagi utk sesi ni,
      // jadi aktifkan pakej terus di sini (bukan gantung tunggu staff).
      if (wasAlreadyCompleted) await activatePackageForPatient(admin, patientId, item.packageId, item.packageName, Number(item.amount || 0))

    } else if (item.type === 'kob_deposit') {
      // Deposit ansuran ATAU bayaran penuh pakej KOB — SELALU staff-initiated
      // (payments-kob-initiate). tier='today' ikut status 'pending' (Teruskan
      // diklik terakhir); tier='now' ikut status 'declined' (Tidak Teruskan diklik
      // terakhir, termasuk doktor reopen sesi yg dah 'completed'). Patient self-
      // checkout pakej KOB guna item.type='kob_package' (kob.html), bukan ni.
      const kobSessionId = item.kobSessionId
      const wasAlreadyCompleted = await isKobStatusCompleted(admin, patientId)
      const { data: kobRows } = await admin.from('psy_kob_sessions')
        .select('recommended_package_id, recommended_package_name').eq('id', kobSessionId).limit(1)
      const kobRow = kobRows?.[0]
      const isToday = item.tier === 'today'

      if (item.mode === 'installment') {
        let pkgQ = admin.from('psy_packages')
          .select('installment_deposit_amount, installment_duration_months, installment_monthly_amount, today_installment_deposit_amount, today_installment_duration_months, today_installment_monthly_amount')
        pkgQ = isUuid(String(kobRow?.recommended_package_id))
          ? pkgQ.or(`id.eq.${kobRow.recommended_package_id},package_id.eq.${kobRow.recommended_package_id}`)
          : pkgQ.eq('package_id', kobRow?.recommended_package_id)
        const { data: pkgRows } = await pkgQ.limit(1)
        const pkgMeta = pkgRows?.[0]
        // Tier 'today' fallback ke Now bila today_* kosong; tier 'now'/tiada = terus Now (kod asal, tiada ubah).
        const tierDepositCol = isToday ? (pkgMeta?.today_installment_deposit_amount ?? pkgMeta?.installment_deposit_amount) : pkgMeta?.installment_deposit_amount
        const tierDurationCol = isToday ? (pkgMeta?.today_installment_duration_months ?? pkgMeta?.installment_duration_months) : pkgMeta?.installment_duration_months
        const tierMonthlyCol = isToday ? (pkgMeta?.today_installment_monthly_amount ?? pkgMeta?.installment_monthly_amount) : pkgMeta?.installment_monthly_amount
        const depositAmount = Number(tierDepositCol || item.amount || 0)
        const resolved = buildInstallmentSchedule(depositAmount, tierDurationCol, tierMonthlyCol, new Date())
        const rows = [
          { kob_session_id: kobSessionId, patient_id: patientId, seq: 0, month_offset: 0,
            due_date: now.slice(0, 10), target_cumulative: depositAmount, status: 'met', met_at: now },
          ...resolved.map((r, i) => ({
            kob_session_id: kobSessionId, patient_id: patientId, seq: i + 1, month_offset: r.month_offset,
            due_date: r.due_date, target_cumulative: r.target_cumulative,
            status: depositAmount >= r.target_cumulative ? 'met' : 'pending',
            met_at: depositAmount >= r.target_cumulative ? now : null,
          })),
        ]
        await admin.from('psy_kob_installment_checkpoints').insert(rows)
        await admin.from('psy_kob_sessions').update({
          package_payment_mode: 'installment', package_payment_status: 'partial', package_receipt_ref: receiptRef,
        }).eq('id', kobSessionId)
      } else if (item.mode === 'manual_installment') {
        // Jadual custom (deposit + tiap baris, amaun tak-rata staff isi sendiri) DAH
        // disimpan sbg checkpoint 'pending' oleh ensureManualScheduleDraft() SEBELUM
        // pautan HitPay dijana (payments-kob-initiate baca amount deposit dari situ,
        // bukan dari formula pakej standard) — di sini cuma tandakan baris yg dah
        // tercapai (biasanya cuma deposit seq=0) jadi 'met'.
        const depositAmount = Number(item.amount || 0)
        await admin.from('psy_kob_installment_checkpoints')
          .update({ status: 'met', met_at: now })
          .eq('kob_session_id', kobSessionId).eq('status', 'pending')
          .lte('target_cumulative', depositAmount)
        await admin.from('psy_kob_sessions').update({
          package_payment_mode: 'installment', package_payment_status: 'partial', package_receipt_ref: receiptRef,
        }).eq('id', kobSessionId)
      } else {
        await admin.from('psy_kob_sessions').update({
          package_payment_mode: 'full', package_payment_status: 'paid',
          package_paid_at: now, package_receipt_ref: receiptRef,
        }).eq('id', kobSessionId)
      }
      // ELAK race condition — lihat nota sama di branch kob_package di atas.
      await admin.from('psy_patients').update({ kob_status: 'package_paid' })
        .eq('id', patientId).neq('kob_status', 'completed')
      if (wasAlreadyCompleted) {
        await activatePackageForPatient(admin, patientId, kobRow?.recommended_package_id, kobRow?.recommended_package_name, Number(item.amount || 0))
      }

    } else if (item.type === 'kob_installment_topup') {
      // Top-up ansuran bebas-amount, dimulakan PESAKIT sendiri (payment.html).
      // Kira semula jumlah terkumpul & semak checkpoint mana dah cecah target —
      // port logik sama patient-hub.html saveBayaranPayment().
      const kobSessionId = item.kobSessionId
      const { data: allPayments } = await admin.from('psy_payments').select('total')
        .eq('status', 'completed').eq('intent->>kob_session_id', kobSessionId)
      // Baris SEMASA belum ditanda 'completed' lagi pada ketika ni (berlaku
      // selepas fulfillOrder() siap) — tambah amount item ni secara eksplisit.
      const totalPaid = (allPayments || []).reduce((s: number, p: any) => s + Number(p.total || 0), 0) + Number(item.amount || 0)

      const { data: openCheckpoints } = await admin.from('psy_kob_installment_checkpoints')
        .select('id, target_cumulative').eq('kob_session_id', kobSessionId).neq('status', 'met')
      for (const cp of (openCheckpoints || [])) {
        if (totalPaid >= Number(cp.target_cumulative)) {
          await admin.from('psy_kob_installment_checkpoints').update({ status: 'met', met_at: now }).eq('id', cp.id)
        }
      }

      const { data: stillOverdue } = await admin.from('psy_kob_installment_checkpoints')
        .select('id').eq('patient_id', patientId).eq('status', 'overdue').limit(1)
      if (!stillOverdue?.length) {
        await admin.from('psy_patients').update({
          booking_blocked: false, booking_blocked_reason: null, booking_blocked_since: null,
        }).eq('id', patientId)
      }

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

const isUuid = (s: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)

// Port dari roles/staff/kob-detail.html buildInstallmentSchedule() — jadual
// ansuran RATA (deposit + tempoh bulan + amaun bulanan tetap), bukan checkpoint
// sewenang-wenang. Jumlah komitmen TAK semestinya = harga pakej penuh.
function buildInstallmentSchedule(depositAmount: number, durationMonths: number, monthlyAmount: number, startDate: Date) {
  const rows: { month_offset: number; target_cumulative: number; due_date: string }[] = []
  let cumulative = Number(depositAmount) || 0
  const n = Number(durationMonths) || 0
  for (let i = 1; i < n; i++) {
    cumulative += Number(monthlyAmount) || 0
    const due = new Date(startDate)
    due.setMonth(due.getMonth() + i)
    rows.push({ month_offset: i, target_cumulative: cumulative, due_date: due.toISOString().slice(0, 10) })
  }
  return rows
}

async function isKobStatusCompleted(admin: any, patientId: string | null): Promise<boolean> {
  if (!patientId) return false
  const { data } = await admin.from('psy_patients').select('kob_status').eq('id', patientId).limit(1)
  return data?.[0]?.kob_status === 'completed'
}

// Pesakit beli pakej LEWAT (KOB dah ditandakan Selesai, cth declined semasa KOB →
// self-checkout kemudian) — markSelesai() (staff, kob-detail.html) TAKKAN panggil lagi
// utk sesi ni, jadi replikasi bahagian aktifkan-pakej dia di sini. Idempotent — skip
// kalau pesakit dah ada pakej aktif (elak overwrite pakej semasa yang tak berkaitan).
async function activatePackageForPatient(admin: any, patientId: string | null, packageId: string | null, packageName: string | null, price: number) {
  if (!patientId || !packageId) return
  const { data: ptRows } = await admin.from('psy_patients').select('active_package_id').eq('id', patientId).limit(1)
  if (ptRows?.[0]?.active_package_id) return // dah ada pakej aktif — jangan overwrite

  const now = new Date().toISOString()
  const expires = new Date(); expires.setMonth(expires.getMonth() + 3)
  await admin.from('psy_package_purchases').insert({
    patient_id: patientId, package_id: packageId, package_name: packageName,
    price, expires_at: expires.toISOString(), status: 'active', payment_method: 'gateway',
  })
  await admin.from('psy_patients').update({
    active_package_id: packageId, active_package_name: packageName,
    package_purchased_at: now, package_expires_at: expires.toISOString(),
  }).eq('id', patientId)

  const { data: existing } = await admin.from('psy_treatment_plans')
    .select('id').eq('patient_id', patientId).eq('status', 'active').limit(1)
  if (!existing?.length) {
    const tpl = await getPlanTemplate(admin, packageId, packageName || '')
    const { data: newPlan } = await admin.from('psy_treatment_plans').insert({
      patient_id: patientId, doctor_id: null, name: tpl.name,
      duration_unit: tpl.duration_unit, duration_weeks: tpl.duration_weeks,
      current_week: 1, coaching_schedule: tpl.coaching_schedule, status: 'active',
    }).select('id').single()
    if (newPlan?.id) await seedPlanWeeklyProgress(admin, newPlan.id, patientId, tpl.coaching_schedule, tpl.duration_weeks)
  }
}

// Hari-sesi (1=sesi pertama, 2=sesi kedua) yang PAKEJ tetapkan minggu w. Minggu tiada entri
// weekly eksplisit → anggap [1]. Sama logik dgn "Selaraskan ikut Pakej" (patient-hub.html) —
// supaya plan yang auto-dicipta di sini terus sepadan pakej, tak perlu staff selaraskan manual.
function pkgSessionDaysForWeek(sched: any[], w: number): number[] {
  const e = (Array.isArray(sched) ? sched : []).find((it: any) => (it.period || 'week') !== 'day' && Number(it.week) === w)
  if (e && Array.isArray(e.session_days) && e.session_days.length) {
    return [...new Set(e.session_days.map(Number))].filter((d: number) => d >= 1 && d <= 7).sort((a: number, b: number) => a - b)
  }
  return [1]
}

// Skeleton mingguan (pending, tiada tarikh) ikut Timeline pakej. Tarikh ditempah kemudian bila
// pesakit/staff buka plan ("Jadualkan Semua Sesi").
async function seedPlanWeeklyProgress(admin: any, planId: string, patientId: string, coachingSchedule: any[], durationWeeks: number) {
  const rows: any[] = []
  for (let w = 1; w <= durationWeeks; w++) {
    for (const d of pkgSessionDaysForWeek(coachingSchedule, w)) {
      rows.push({ plan_id: planId, patient_id: patientId, week_number: w, session_day: d, status: 'pending', session_date: null })
    }
  }
  if (rows.length) await admin.from('psy_plan_weekly_progress').insert(rows)
}

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
