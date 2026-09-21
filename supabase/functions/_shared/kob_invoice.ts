// ============================================================
// _shared/kob_invoice.ts — kumpul data + jana PDF invois (tuntutan bayaran) untuk satu sesi KOB,
// upload ke bucket 'receipts' & pulang signed URL (7 hari).
// Dipakai oleh: kob-invoice-pdf (staff tekan Hantar WA) DAN automations-runner (peringatan
// ansuran automatik). Helper ni SENDIRI tiada auth — pemanggil yang tanggungjawab authorize.
//
//   seq    = checkpoint yang dituntut → Invois Ansuran (Amount Due = ansuran itu sahaja)
//   amount = jumlah tuntutan kalau jadual checkpoint belum wujud (cth deposit)
//   tanpa kedua-dua = invois bayaran penuh (baki pakej)
// ============================================================
import { buildInvoicePdf } from './invoice_pdf.ts'

export interface KobInvoiceOpts {
  kobSessionId: string
  seq?: number | null
  payUrl?: string | null
  amount?: number | null
}

export async function generateKobInvoiceUrl(admin: any, o: KobInvoiceOpts): Promise<{ url: string; invoiceNo: string }> {
  const { data: ks } = await admin.from('psy_kob_sessions')
    .select('patient_id, recommended_package_name, recommended_package_price, package_discount, package_payment_mode, recommended_at, created_at, invoice_no')
    .eq('id', o.kobSessionId).limit(1)
  const kob = ks?.[0]
  if (!kob) throw new Error('Sesi KOB tidak dijumpai')

  const [{ data: cps }, { data: pays }, { data: pts }] = await Promise.all([
    admin.from('psy_kob_installment_checkpoints').select('seq, due_date, target_cumulative').eq('kob_session_id', o.kobSessionId).order('seq'),
    admin.from('psy_payments').select('total').eq('status', 'completed').eq('intent->>kob_session_id', o.kobSessionId),
    admin.from('psy_patients').select('full_name, phone, user_id').eq('id', kob.patient_id).limit(1),
  ])
  let name: string | null = pts?.[0]?.full_name || null
  let phone: string | null = pts?.[0]?.phone || null
  if ((!name || !phone) && pts?.[0]?.user_id) {
    const { data: prof } = await admin.from('psy_profiles').select('full_name, phone').eq('id', pts[0].user_id).limit(1)
    name = name || prof?.[0]?.full_name || null
    phone = phone || prof?.[0]?.phone || null
  }

  const seq = o.seq === undefined || o.seq === null ? null : Number(o.seq)
  const amountOverride = o.amount != null ? Number(o.amount) : null
  const price = Number(kob.recommended_package_price || 0)
  const discount = Number(kob.package_discount || 0)
  const list = cps || []
  const isInstallment = kob.package_payment_mode === 'installment' && list.length > 0
  const owed = isInstallment ? Number(list[list.length - 1].target_cumulative) : price
  const paidTotal = (pays || []).reduce((a: number, p: any) => a + Number(p.total || 0), 0)
  const issue = kob.recommended_at || kob.created_at || new Date().toISOString()

  let invoiceNo = kob.invoice_no || 'INV'
  let dueDate: string = issue
  let amountDue: number
  let dueLabel: string | null = null
  let listPrice = owed + discount

  const cp = seq != null ? list.find((c: any) => Number(c.seq) === seq) : null
  if (cp) {
    const idx = list.findIndex((c: any) => Number(c.seq) === seq)
    const prevTarget = idx > 0 ? Number(list[idx - 1].target_cumulative) : 0
    const amount = Number(cp.target_cumulative) - prevTarget
    const paidThis = Math.min(amount, Math.max(0, paidTotal - prevTarget))
    amountDue = Math.max(0, amount - paidThis)
    dueDate = cp.due_date
    invoiceNo = `${invoiceNo}-${idx + 1}`
    dueLabel = `${seq === 0 ? 'Deposit' : `Installment ${seq}`} - ${idx + 1} of ${list.length}`
  } else if (amountOverride != null && amountOverride > 0) {
    amountDue = amountOverride
    dueLabel = seq === 0 ? 'Deposit' : null
    if (seq === 0) invoiceNo = `${invoiceNo}-1`
  } else {
    amountDue = Math.max(0, owed - paidTotal)
    listPrice = price + discount
  }

  const bytes = await buildInvoicePdf({
    invoiceNo, issueDate: issue, dueDate,
    patientName: name, phone,
    itemName: kob.recommended_package_name || 'Package',
    listPrice, discount, amountDue, dueLabel, payUrl: o.payUrl || null,
  })
  const bucket = 'receipts'
  await admin.storage.createBucket(bucket, { public: false }).catch(() => {})
  const path = `invoices/${invoiceNo}_${Date.now()}.pdf`
  const { error: upErr } = await admin.storage.from(bucket).upload(path, bytes, { contentType: 'application/pdf', upsert: true })
  if (upErr) throw upErr
  const { data: signed, error: sgErr } = await admin.storage.from(bucket).createSignedUrl(path, 7 * 24 * 3600)
  if (sgErr || !signed?.signedUrl) throw (sgErr || new Error('signed URL kosong'))
  return { url: signed.signedUrl, invoiceNo }
}
