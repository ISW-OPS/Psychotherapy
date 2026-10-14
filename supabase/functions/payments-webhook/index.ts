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
import { applyInstallmentPayment } from '../_shared/kob_autocharge.ts'
import { fulfillKobDeposit, fulfillKobPackage, getPlanTemplate, seedPlanWeeklyProgress } from '../_shared/kob_deposit_fulfill.ts'

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

// Audit management #B1-28 (24 Sept 2026) — bayaran gateway (HitPay) auto-fulfill
// TAK pernah dilog ke psy_audit_log sebelum ni (cuma laluan manual/staff dilog di
// client). Sama pattern dgn ghl-booking-webhook/index.ts. Best-effort — kegagalan
// log TAK patut gagalkan webhook (fulfillment/status dah selesai).
async function auditLog(svc: any, action: string, target: string, meta: Record<string, unknown>) {
  try {
    await svc.from('psy_audit_log').insert({ actor_name: 'Gateway (HitPay)', actor_role: 'system', action, target, meta })
  } catch (_) { /* jangan gagalkan webhook */ }
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
        await auditLog(admin, 'payment.gateway_failed', payment.id, { receipt_ref: payment.receipt_ref, gateway_status: result.status })
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

    // Channel sebenar (fpx/card/dll) — panggilan TAMBAHAN, best-effort. Webhook
    // form-encoded (result di atas) tak bawa medan ni. Kegagalan di sini TAK
    // patut gagalkan webhook — bayaran dah fulfill & ditanda completed di atas.
    try {
      const provider = getProvider()
      if (provider.getPaymentChannel) {
        const { channel } = await provider.getPaymentChannel(result.gatewayRef)
        if (channel) await admin.from('psy_payments').update({ gateway_channel: channel }).eq('id', payment.id)
      }
    } catch (e) {
      console.warn('payments-webhook: getPaymentChannel gagal —', (e as Error).message)
    }

    await auditLog(admin, 'payment.gateway_completed', payment.id, { receipt_ref: payment.receipt_ref, amount: payment.total, provider: result.status })

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
  walkin_sale: () => 'Jualan Walk-in',
}

async function notifyStaffPaymentReceived(admin: any, patientId: string | null, labels: string[], total: number, receiptRef: string, buyerName?: string | null) {
  if (!labels.length) return
  const targets = new Set<string>()
  let patientLabel = buyerName || 'Pesakit'
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
        // patientId null = jualan walk-in (tiada akaun pesakit) — bawa staff ke
        // Payment Management (papar SEMUA bayaran) bukan Patient Payment (khusus pesakit).
        link: patientId ? `../staff/patient-hub.html?id=${patientId}` : 'payment-ledger.html',
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
      await fulfillKobPackage(admin, item, patientId, receiptRef)

    } else if (item.type === 'kob_deposit') {
      // Deposit ansuran ATAU bayaran penuh pakej KOB — SELALU staff-initiated
      // (payments-kob-initiate) ATAU pesakit self-checkout installment. Patient
      // self-checkout pakej PENUH guna item.type='kob_package' (kob.html), bukan ni.
      // Logik dikongsi dgn payments-webhook-recurring (deposit+saveCard=true,
      // lihat _shared/kob_deposit_fulfill.ts).
      await fulfillKobDeposit(admin, item, patientId, receiptRef)

    } else if (item.type === 'kob_installment_topup') {
      // Top-up ansuran bebas-amount, dimulakan PESAKIT sendiri (payment.html)
      // ATAU staff (butang patient-hub.html). Logik kumulatif "checkpoint mana
      // dah met" dikongsi dgn auto-caj cron (event-reminders) — lihat
      // applyInstallmentPayment() di _shared/kob_autocharge.ts.
      await applyInstallmentPayment(admin, item.kobSessionId, patientId, Number(item.amount || 0))

    } else if (item.type === 'shop_order') {
      const { data: newOrder, error: orderErr } = await admin.from('psy_orders').insert({
        order_ref: item.orderRef, patient_id: intent.userId, items: item.items,
        total: item.amount, status: 'paid', paid_at: now,
        delivery_method: item.deliveryMethod,
        delivery_address: item.deliveryAddress || null,
        courier: item.deliveryMethod === 'pos' ? 'JNT' : null,
        notes: item.deliveryMethod === 'pickup' ? 'Pickup Konsultasi' : null,
      }).select('id, order_ref').single()
      // Stok Inventori ditolak sebaik order dibayar (hanya bila order baru berjaya dicipta,
      // order_ref UNIQUE — webhook berulang tak tolak dua kali).
      if (!orderErr && newOrder) {
        try { await deductShopStock(admin, item.items, newOrder) }
        catch (e) { console.warn('[payments-webhook] gagal tolak stok Inventori:', e) }
      }
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

    } else if (item.type === 'walkin_sale') {
      // Jualan walk-in (pembeli bukan pesakit) — tiada "order" berasingan macam
      // shop_order, baris psy_payments SENDIRI ialah rekod jualan. Tolak stok
      // Inventori sahaja, guna receipt payment sebagai rujukan.
      try { await deductWalkinStock(admin, item.items, payment) }
      catch (e) { console.warn('[payments-webhook] gagal tolak stok Inventori (walk-in):', e) }
    }
  }

  try {
    await notifyStaffPaymentReceived(admin, patientId, staffLabels, payment.total, receiptRef, payment.buyer_name)
  } catch (_) { /* nota: notifikasi gagal tidak halang fulfillment */ }
}

// Tolak stok Inventori bagi produk Shop dalam order yang baru dibayar. Cermin addStockToLocation()
// (shared/inventoryStock.js): kurangkan lokasi dengan stok terbanyak + tulis ledger psy_stock_movements;
// trigger psy_sync_item_stock_total mengemas kini jumlah qty_in_stock.
async function deductShopStock(admin: any, lines: any[], order: { id: string; order_ref: string }) {
  if (!Array.isArray(lines)) return
  const { data: invs } = await admin.from('psy_inventory_items').select('id, name, source_type')
  for (const line of lines) {
    const qty = Math.max(1, parseInt(line?.qty) || 1)
    if (!line?.id) continue
    const { data: prod } = await admin.from('psy_products')
      .select('name, inventory_item_id').eq('product_id', line.id).maybeSingle()
    if (!prod) continue
    // Pautan HANYA melalui inventory_item_id (ID Inventori) — bukan nama
    const inv = (invs || []).find((i: any) => i.id === prod.inventory_item_id)
    if (!inv) { console.warn('[payments-webhook] tiada item Inventori utk produk', prod.name); continue }

    const { data: rows } = await admin.from('psy_inventory_stock_by_location')
      .select('id, location_id, qty_in_stock').eq('item_id', inv.id)
      .order('qty_in_stock', { ascending: false }).limit(1)
    const row = rows?.[0]
    if (!row) { console.warn('[payments-webhook] item Inventori tiada stok berlokasi:', inv.name); continue }

    const balanceAfter = Math.max(0, Number(row.qty_in_stock) - qty)
    await admin.from('psy_inventory_stock_by_location')
      .update({ qty_in_stock: balanceAfter, updated_at: new Date().toISOString() }).eq('id', row.id)
    await admin.from('psy_stock_movements').insert({
      item_id: inv.id, item_name: inv.name, location_id: row.location_id,
      movement_type: 'out', qty: -qty, balance_after: balanceAfter,
      reference_type: 'shop_order', reference_id: order.id, reference_label: order.order_ref,
      notes: 'Order Shop dibayar', actor_id: null, actor_name: 'Sistem (pembayaran)',
    })
  }
}

// Tolak stok Inventori bagi jualan walk-in (pembeli bukan pesakit) yang baru
// dibayar via HitPay. Sama corak dgn deductShopStock() — beza: baris
// psy_payments SENDIRI ialah rekod jualan (tiada psy_orders), dan line.id
// ialah psy_products.id (UUID) terus — dicipta oleh payments-initiate-walkin,
// bukan slug product_id macam troli Shop.
async function deductWalkinStock(admin: any, lines: any[], payment: { id: string; receipt_no?: string | null; receipt_ref: string }) {
  if (!Array.isArray(lines)) return
  const { data: invs } = await admin.from('psy_inventory_items').select('id, name, source_type')
  const refLabel = payment.receipt_no || payment.receipt_ref
  for (const line of lines) {
    const qty = Math.max(0.01, Number(line?.qty) || 0)
    if (!line?.id || !qty) continue
    const { data: prod } = await admin.from('psy_products')
      .select('name, inventory_item_id').eq('id', line.id).maybeSingle()
    if (!prod) continue
    const inv = (invs || []).find((i: any) => i.id === prod.inventory_item_id)
    if (!inv) { console.warn('[payments-webhook] tiada item Inventori utk produk', prod.name); continue }

    const { data: rows } = await admin.from('psy_inventory_stock_by_location')
      .select('id, location_id, qty_in_stock').eq('item_id', inv.id)
      .order('qty_in_stock', { ascending: false }).limit(1)
    const row = rows?.[0]
    if (!row) { console.warn('[payments-webhook] item Inventori tiada stok berlokasi:', inv.name); continue }

    const balanceAfter = Math.max(0, Number(row.qty_in_stock) - qty)
    await admin.from('psy_inventory_stock_by_location')
      .update({ qty_in_stock: balanceAfter, updated_at: new Date().toISOString() }).eq('id', row.id)
    await admin.from('psy_stock_movements').insert({
      item_id: inv.id, item_name: inv.name, location_id: row.location_id,
      movement_type: 'out', qty: -qty, balance_after: balanceAfter,
      reference_type: 'walkin_sale', reference_id: payment.id, reference_label: refLabel,
      notes: 'Jualan Walk-in dibayar (HitPay)', actor_id: null, actor_name: 'Sistem (pembayaran)',
    })
  }
}

// isUuid, buildInstallmentSchedule, isKobStatusCompleted, activatePackageForPatient,
// pkgSessionDaysForWeek, seedPlanWeeklyProgress, getPlanTemplate — DIPINDAH ke
// _shared/kob_deposit_fulfill.ts (23 Sept) supaya boleh dikongsi dgn
// payments-webhook-recurring (laluan deposit+saveCard). Lihat import di atas.
