// ============================================================
// _shared/kob_autocharge.ts — Auto-Caj Ansuran KOB (kad tersimpan HitPay)
//
// Dua bahagian:
//   1. createKobCardAttachLink() — jana pautan "lampir kad" (recurring-billing,
//      save_payment_method=true) utk sesi KOB ansuran. Pemanggil:
//      payments-kob-initiate (mode='attach_card', staff/pesakit) — pattern
//      sama kob_topup.ts. Guna psy_payments PLACEHOLDER (RM1 pengesahan,
//      BUKAN ansuran) supaya payment-receipt.html + payment-receipt-public
//      (infra sedia ada) papar status tanpa laman/kod baharu — webhook
//      payments-webhook-recurring (event method_attached) tanda row ni
//      completed + psy_kob_card_authorizations status='attached'.
//   2. applyInstallmentPayment() — logik KUMULATIF kongsi "checkpoint mana
//      dah met" lepas duit masuk. Dipakai OLEH DUA laluan: webhook topup
//      biasa (payments-webhook, item.type='kob_installment_topup') DAN
//      auto-caj cron (event-reminders runInstallmentAutoChargeCheck) —
//      supaya logik kumulatif TIDAK duplicate/drift antara dua tempat.
// ============================================================
import { activeProviderName, getProvider } from './payments/index.ts'

export interface KobCardAttachLink {
  checkoutUrl: string
  receiptRef: string
}

export async function createKobCardAttachLink(
  admin: any, kobSessionId: string, returnUrl: string,
): Promise<KobCardAttachLink> {
  const { data: kobRows } = await admin.from('psy_kob_sessions')
    .select('id, patient_id, recommended_package_name, package_payment_mode')
    .eq('id', kobSessionId).limit(1)
  const kob = kobRows?.[0]
  if (!kob) throw new Error('Sesi KOB tidak dijumpai')
  if (kob.package_payment_mode !== 'installment') throw new Error('Sesi ini bukan ansuran')

  const { data: ptRows } = await admin.from('psy_patients')
    .select('user_id, full_name, phone, email').eq('id', kob.patient_id).limit(1)
  const patient = ptRows?.[0]
  // psy_patients.email ialah sumber utama (lihat nota sama di kob_retry_link.ts)
  // — HitPay recurring-billing WAJIBKAN customer_email, 422 kalau kosong.
  let patientEmail: string | undefined = patient?.email || undefined
  if (!patientEmail && patient?.user_id) {
    const { data: au } = await admin.auth.admin.getUserById(patient.user_id).catch(() => ({ data: null }))
    patientEmail = au?.user?.email || undefined
  }
  if (!patientEmail) {
    throw new Error('Pesakit ini tiada alamat emel dalam rekod — wajib untuk lampir kad (auto-caj ansuran). Kemaskini emel pesakit dulu (Pesakit → Kemaskini Pesakit).')
  }

  const providerName = activeProviderName()
  const provider = getProvider(providerName)
  if (!provider.createCardAuthorization) throw new Error(`Provider "${providerName}" tidak sokong lampiran kad`)

  const receiptRef = 'CARD-' + Date.now().toString(36).toUpperCase() +
    '-' + Math.floor(performance.now()).toString(36).toUpperCase()
  const itemTitle = `Pengesahan Kad — Ansuran Automatik (${kob.recommended_package_name || ''})`.trim()

  // Gantikan percubaan pending LAMA (staff hantar pautan lampir kad > sekali —
  // sama sebab macam kob_topup.ts/kob_retry_link.ts, elak baris pending berterusan).
  // Ditapis di JS (bukan filter JSONB nested-array PostgREST) — hanya baris
  // 'kob_card_attach' yg diganti, JANGAN sentuh pending 'kob_installment_topup'
  // sesi yang sama (laluan berasingan, boleh wujud serentak).
  const { data: oldPending } = await admin.from('psy_payments')
    .select('id, items').eq('patient_id', kob.patient_id).eq('status', 'pending')
    .eq('intent->>kob_session_id', kobSessionId)
  for (const row of (oldPending || [])) {
    if (row.items?.[0]?.type === 'kob_card_attach') {
      await admin.from('psy_payments')
        .update({ status: 'failed', gateway_status: 'superseded', notes: 'Digantikan oleh pautan lampir kad baharu' })
        .eq('id', row.id)
    }
  }

  const { error: insErr } = await admin.from('psy_payments').insert({
    receipt_ref: receiptRef,
    patient_id: kob.patient_id,
    user_id: patient?.user_id || null,
    items: [{ type: 'kob_card_attach', title: itemTitle, kobSessionId }],
    subtotal: 1, total: 1,
    payment_method: 'gateway',
    status: 'pending',
    gateway_provider: providerName,
    gateway_status: 'pending',
    intent: {
      items: [{ type: 'kob_card_attach', title: itemTitle, kobSessionId }],
      patientId: kob.patient_id, userId: patient?.user_id || null, kob_session_id: kobSessionId,
    },
  })
  if (insErr) throw new Error('Gagal simpan rekod pengesahan kad: ' + insErr.message)

  const redirectUrl = `${returnUrl}${returnUrl.includes('?') ? '&' : '?'}ref=${encodeURIComponent(receiptRef)}`
  const created = await provider.createCardAuthorization({
    reference: receiptRef,
    amount: '1.00',   // sesi lampir-kad BERDIRI SENDIRI (tiada bayaran sebenar utk ditumpang) — had minimum API
    purpose: 'Pengesahan Kad — Ansuran Automatik ISW',
    currency: 'MYR',
    customerEmail: patientEmail,
    customerName: patient?.full_name || undefined,
    redirectUrl,
  })

  await admin.from('psy_payments')
    .update({ gateway_ref: created.authRef, checkout_url: created.checkoutUrl })
    .eq('receipt_ref', receiptRef)

  // Upsert (bukan insert) — staff boleh hantar pautan lampir kad > sekali;
  // rekod lama ditimpa (UNIQUE kob_session_id, lihat migration).
  await admin.from('psy_kob_card_authorizations').upsert({
    kob_session_id: kobSessionId,
    patient_id: kob.patient_id,
    gateway_provider: providerName,
    gateway_auth_ref: created.authRef,
    status: 'pending',
  }, { onConflict: 'kob_session_id' })

  return { checkoutUrl: created.checkoutUrl, receiptRef }
}

// Selepas `newAmount` berjaya masuk utk kobSessionId (baris psy_payments
// BARU tu sendiri belum ditanda 'completed' lagi pada ketika fungsi ni
// dipanggil — sebab tu newAmount ditambah eksplisit), semak checkpoint mana
// dah cecah target_cumulative kumulatif → tanda 'met'. Buka balik
// booking_blocked kalau tiada lagi checkpoint 'overdue' tertunggak.
export async function applyInstallmentPayment(admin: any, kobSessionId: string, patientId: string, newAmount: number) {
  const now = new Date().toISOString()
  const { data: allPayments } = await admin.from('psy_payments').select('total')
    .eq('status', 'completed').eq('intent->>kob_session_id', kobSessionId)
  const totalPaid = (allPayments || []).reduce((s: number, p: any) => s + Number(p.total || 0), 0) + newAmount

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
}
