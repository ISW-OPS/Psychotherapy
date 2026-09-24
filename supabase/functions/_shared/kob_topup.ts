// ============================================================
// _shared/kob_topup.ts — jana pautan HitPay utk checkpoint ANSURAN
// SETERUSNYA (bukan deposit/permulaan) bagi sesi KOB yang pelan
// ansurannya SEDANG BERJALAN (package_payment_status='partial').
//
// Amaun diderive 100% server-side — port terus logik verifiedAmount()
// utk it.type==='kob_installment_topup' di payments-initiate/index.ts
// (jumlah terkumpul psy_payments vs checkpoint seterusnya belum met).
//
// Dua pemanggil:
//   1. payments-kob-initiate (mode='topup') — staff klik butang di
//      patient-hub.html, JWT staff disahkan oleh pemanggil.
//   2. event-reminders runInstallmentReminderCheck — cron (CRON_SECRET),
//      jana pautan on-the-fly utk mesej peringatan N-hari-sebelum-due.
// Helper ni SENDIRI tiada auth — pemanggil yang tanggungjawab authorize.
// ============================================================
import { activeProviderName, getProvider } from './payments/index.ts'

const money = (n: number) => (Math.round(n * 100) / 100).toFixed(2)

export interface KobTopupLink {
  checkoutUrl: string
  receiptRef: string
  amount: number
  checkpointSeq: number
  checkpointLabel: string
  dueDate: string
}

export async function createKobInstallmentTopupLink(
  admin: any, kobSessionId: string, returnUrl: string,
): Promise<KobTopupLink> {
  const { data: kobRows } = await admin.from('psy_kob_sessions')
    .select('id, patient_id, recommended_package_name, package_payment_mode, package_payment_status')
    .eq('id', kobSessionId).limit(1)
  const kob = kobRows?.[0]
  if (!kob) throw new Error('Sesi KOB tidak dijumpai')
  if (kob.package_payment_mode !== 'installment' || kob.package_payment_status !== 'partial') {
    throw new Error('Sesi ini bukan ansuran aktif')
  }

  const { data: paidRows } = await admin.from('psy_payments').select('total')
    .eq('status', 'completed').eq('intent->>kob_session_id', kobSessionId)
  const totalPaid = (paidRows || []).reduce((s: number, p: any) => s + Number(p.total || 0), 0)

  const { data: cps } = await admin.from('psy_kob_installment_checkpoints')
    .select('seq, due_date, target_cumulative').eq('kob_session_id', kobSessionId).order('seq', { ascending: true })
  const nextCp = (cps || []).find((c: any) => Number(c.target_cumulative) > totalPaid + 0.005)
  if (!nextCp) throw new Error('Tiada ansuran tertunggak')

  const amount = Math.max(0, Number(nextCp.target_cumulative) - totalPaid)
  if (!(amount > 0)) throw new Error('Tiada ansuran tertunggak')

  const checkpointLabel = nextCp.seq === 0 ? 'Deposit' : `Ansuran ${nextCp.seq}`
  const itemTitle = `${checkpointLabel} — ${kob.recommended_package_name || ''}`.trim()

  const { data: ptRows } = await admin.from('psy_patients')
    .select('user_id, full_name, phone, email').eq('id', kob.patient_id).limit(1)
  const patient = ptRows?.[0]
  // psy_patients.email ialah sumber utama (lihat nota sama di kob_retry_link.ts)
  let patientEmail: string | undefined = patient?.email || undefined
  if (!patientEmail && patient?.user_id) {
    const { data: au } = await admin.auth.admin.getUserById(patient.user_id).catch(() => ({ data: null }))
    patientEmail = au?.user?.email || undefined
  }

  // Gantikan percubaan pending LAMA utk sesi KOB yg sama — sama sebab macam
  // payments-kob-initiate (elak baris 'pending' berterusan mengelirukan sejarah).
  await admin.from('psy_payments')
    .update({ status: 'failed', gateway_status: 'superseded', notes: 'Digantikan oleh pautan HitPay baharu' })
    .eq('patient_id', kob.patient_id).eq('status', 'pending')
    .eq('intent->>kob_session_id', kobSessionId)

  const receiptRef = 'RCP-' + Date.now().toString(36).toUpperCase() +
    '-' + Math.floor(performance.now()).toString(36).toUpperCase()
  const provider = activeProviderName()

  const { error: insErr } = await admin.from('psy_payments').insert({
    receipt_ref: receiptRef,
    patient_id: kob.patient_id,
    user_id: patient?.user_id || null,
    items: [{ type: 'kob_installment_topup', title: itemTitle, amount, kobSessionId, checkpointSeq: nextCp.seq }],
    subtotal: amount,
    total: amount,
    payment_method: 'gateway',
    status: 'pending',
    gateway_provider: provider,
    gateway_status: 'pending',
    intent: {
      items: [{ type: 'kob_installment_topup', title: itemTitle, amount, kobSessionId, checkpointSeq: nextCp.seq }],
      patientId: kob.patient_id,
      userId: patient?.user_id || null,
      kob_session_id: kobSessionId,
    },
  })
  if (insErr) throw new Error('Gagal simpan bayaran pending: ' + insErr.message)

  const webhookUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/payments-webhook`
  const redirectUrl = `${returnUrl}${returnUrl.includes('?') ? '&' : '?'}ref=${encodeURIComponent(receiptRef)}`

  const created = await getProvider(provider).createPayment({
    reference: receiptRef,
    amount: money(amount),
    currency: 'MYR',
    email: patientEmail,
    name: patient?.full_name || undefined,
    purpose: itemTitle,
    redirectUrl,
    webhookUrl,
  })

  await admin.from('psy_payments')
    .update({ gateway_ref: created.gatewayRef, checkout_url: created.checkoutUrl })
    .eq('receipt_ref', receiptRef)

  return {
    checkoutUrl: created.checkoutUrl, receiptRef, amount,
    checkpointSeq: nextCp.seq, checkpointLabel, dueDate: nextCp.due_date,
  }
}
