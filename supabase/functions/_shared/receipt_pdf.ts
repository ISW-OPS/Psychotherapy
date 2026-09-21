// ============================================================
// _shared/receipt_pdf.ts — jana PDF Resit Pembayaran di server
// Cermin susun atur shared/receipt.js (format rujukan GHL):
//   tajuk RECEIPT + blok syarikat · Billed to / Receipt No / Date Paid ·
//   jadual item · Subtotal/Discount(kod promo, baucar)/Amount Paid ·
//   Payment Breakdown (bayaran pakej KOB: komitmen, terkumpul, baki) · disclaimer.
// Guna pdf-lib (pure JS, jalan dalam Deno Edge Function).
// ============================================================

import { PDFDocument, StandardFonts, rgb } from 'https://esm.sh/pdf-lib@1.17.1'
import { LOGO_ISW_PNG_BASE64 } from './logo_isw.ts'
import { sendWhatsApp } from './ghl.ts'

const INK = rgb(0.12, 0.12, 0.12)
const GRAY = rgb(0.42, 0.42, 0.42)
const LIGHT = rgb(0.86, 0.86, 0.86)
const TEAL = rgb(0.169, 0.541, 0.627)     // ~#2b8aa0

// Font standard (WinAnsi) tak support emoji/huruf bukan-Latin — tukar
// aksara tipografi biasa ke ASCII dulu, kemudian buang selebihnya.
const clean = (s: unknown) =>
  String(s ?? '')
    .replace(/[–—]/g, '-')      // – — → -
    .replace(/[‘’]/g, "'")      // ‘ ’ → '
    .replace(/[“”]/g, '"')      // “ ” → "
    .replace(/•/g, '-')              // • → -
    .replace(/[^\x20-\x7E\xA0-\xFF]/g, '')
    .trim() || '-'

const fmt = (n: unknown) =>
  Number(n || 0).toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const rm = (n: unknown) => `RM${fmt(n)}`

const dateLong = (v: string | Date) =>
  new Date(v).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric', timeZone: 'Asia/Kuala_Lumpur' })

export interface KobBreakdown {
  listPrice: number
  pkgDiscount: number
  owed: number
  installmentCharge: number
  thisLabel: string
  paidToDate: number
  outstanding: number
  invoiceNo?: string
}

export interface ReceiptData {
  receiptNo: string
  paidAt: string | Date          // ISO — dipapar waktu Malaysia
  patientName?: string | null
  phone?: string | null
  method?: string | null
  items: Array<{ name: string; price: number }>
  total: number
  discountLines: Array<{ label: string; amount: number }>
  kob?: KobBreakdown | null
}

export async function buildReceiptPdf(d: ReceiptData): Promise<Uint8Array> {
  const doc = await PDFDocument.create()
  const page = doc.addPage([595.28, 841.89]) // A4
  const bold = await doc.embedFont(StandardFonts.HelveticaBold)
  const reg = await doc.embedFont(StandardFonts.Helvetica)

  const M = 50                    // margin
  const W = 595.28 - M * 2        // lebar kandungan
  const R = M + W                 // tepi kanan
  let y = 841.89 - M

  const text = (s: string, x: number, size: number, opt: { font?: any; color?: any; right?: boolean } = {}) => {
    const f = opt.font || reg
    const str = clean(s)
    const xx = opt.right ? x - f.widthOfTextAtSize(str, size) : x
    page.drawText(str, { x: xx, y, size, font: f, color: opt.color || INK })
  }
  const hr = (thick = 0.7, color = LIGHT, x1 = M, x2 = R) => {
    page.drawLine({ start: { x: x1, y }, end: { x: x2, y }, thickness: thick, color })
  }

  // ── Tajuk + garis ─────────────────────────────────────────
  text('RECEIPT', R, 26, { right: true }); y -= 14
  hr(1.4, INK); y -= 26

  // ── Logo (kiri) + blok syarikat (rata kanan) ──────────────
  const companyTop = y
  try {
    const logoBytes = Uint8Array.from(atob(LOGO_ISW_PNG_BASE64), (c) => c.charCodeAt(0))
    const logo = await doc.embedPng(logoBytes)
    const lh = 48
    page.drawImage(logo, { x: M, y: y - lh, width: (logo.width / logo.height) * lh, height: lh })
  } catch (_) { /* logo gagal — teruskan tanpa imej */ }
  y = companyTop - 10
  text('Ibnu Sina Wellness Sdn Bhd (1319021-P)', R, 12, { right: true }); y -= 14
  for (const ln of ['03-8966 3702', 'Lot 331, Lorong Senyum Matahari B, Country Heights,', 'Kajang, Selangor 43000', 'Malaysia', 'www.ibnusinawellness.com']) {
    text(ln, R, 8, { color: GRAY, right: true }); y -= 11
  }
  y -= 10
  hr(); y -= 22

  // ── Billed to / Receipt No + Date Paid ────────────────────
  const blockY = y
  text('Billed to', M, 10, { font: bold }); y -= 15
  for (const ln of [d.patientName || '-', d.phone || '-', 'Malaysia']) {
    text(ln, M, 8.5, { color: GRAY }); y -= 12
  }
  const leftEnd = y
  y = blockY
  const colX = M + W / 2 + 20
  text('Receipt No', colX, 10, { font: bold }); y -= 13
  text(d.receiptNo, colX, 8.5, { color: GRAY }); y -= 20
  text('Date Paid', colX, 10, { font: bold }); y -= 13
  text(dateLong(d.paidAt), colX, 8.5, { color: GRAY })
  if (d.method) { y -= 20; text('Payment Method', colX, 10, { font: bold }); y -= 13; text(d.method, colX, 8.5, { color: GRAY }) }
  y = Math.min(y, leftEnd) - 34

  // ── Jadual item ───────────────────────────────────────────
  const cPrice = R - 150, cQty = R - 85
  text('ITEM NAME', M, 8, { font: bold, color: GRAY })
  text('PRICE', cPrice, 8, { font: bold, color: GRAY, right: true })
  text('QTY', cQty, 8, { font: bold, color: GRAY, right: true })
  text('SUBTOTAL', R, 8, { font: bold, color: GRAY, right: true })
  y -= 10
  hr(1.6, TEAL); y -= 20
  for (const it of d.items) {
    text(String(it.name).toUpperCase(), M, 8.5, { color: GRAY })
    text(rm(it.price), cPrice, 8.5, { color: GRAY, right: true })
    text('1', cQty, 8.5, { color: GRAY, right: true })
    text(rm(it.price), R, 8.5, { color: GRAY, right: true })
    y -= 10
    hr(0.5); y -= 18
  }
  y -= 4

  // ── Jumlah: Subtotal / diskaun berlabel / Amount Paid ─────
  const discTotal = d.discountLines.reduce((a, l) => a + l.amount, 0)
  const tx = R - 190
  const row = (label: string, val: string, boldRow = false) => {
    text(label, tx, boldRow ? 10 : 9.5, { font: bold })
    text(val, R, boldRow ? 10 : 8.5, { font: boldRow ? bold : reg, color: boldRow ? INK : GRAY, right: true })
    y -= 16
  }
  row('Subtotal', rm(d.total + discTotal))
  if (d.discountLines.length) for (const l of d.discountLines) row(l.label, `-${rm(l.amount)}`)
  else row('Discount', `-${rm(0)}`)
  y += 4
  hr(0.8, LIGHT, tx, R); y -= 15
  row('Amount Paid (MYR)', rm(d.total), true)

  // ── Payment Breakdown (bayaran pakej KOB) ─────────────────
  if (d.kob) {
    const k = d.kob
    y -= 14
    hr(); y -= 16
    text('PAYMENT BREAKDOWN' + (k.invoiceNo ? `  -  Invoice ${k.invoiceNo}` : ''), M, 8, { font: bold, color: GRAY }); y -= 18
    if (k.pkgDiscount > 0) {
      row('Package Price', rm(k.listPrice))
      row('Discount', `-${rm(k.pkgDiscount)}`)
    }
    row('Package Total', rm(k.owed), true)
    row(`Paid on this receipt (${k.thisLabel})`, rm(d.total))
    row('Total Paid to Date', rm(k.paidToDate))
    y += 4
    hr(0.8, LIGHT, tx, R); y -= 15
    row('Balance Remaining', rm(k.outstanding), true)
  }

  // ── Disclaimer bawah halaman ───────────────────────────────
  y = M + 18
  const disc = 'This is an official receipt and serves as proof of payment. Please keep this receipt for your reference.'
  const disc2 = 'No refund is applicable once the payment is made.'
  const center = (s: string, size: number) => {
    const wd = reg.widthOfTextAtSize(s, size)
    page.drawText(s, { x: M + (W - wd) / 2, y, size, font: reg, color: GRAY })
  }
  center(disc, 7); y -= 10
  center(disc2, 7)

  return await doc.save()
}

// ---- Bina data resit dari baris psy_payments (nama item, baris diskaun, pecahan KOB) ----
async function loadReceiptContext(admin: any, payment: any) {
  // Muat semula baris — receipt_no ditetapkan trigger DB sebaik status jadi 'completed'
  const { data: fresh } = await admin.from('psy_payments')
    .select('receipt_no, receipt_ref, discount, notes, intent, items, total, paid_at, id, manual_method, payment_method')
    .eq('id', payment.id).limit(1)
  const r = { ...payment, ...(fresh?.[0] || {}) }
  const intent = r.intent || {}

  // Diskaun berlabel
  const discountLines: Array<{ label: string; amount: number }> = []
  const promoAmt = Number(intent.promoDiscount || 0)
  if (promoAmt > 0) {
    let code: string = intent.promoCode || ''
    if (!code && intent.promoCodeId) {
      const { data: pc } = await admin.from('psy_promo_codes').select('code').eq('id', intent.promoCodeId).limit(1)
      code = pc?.[0]?.code || ''
    }
    discountLines.push({ label: code ? `Promo Code (${code})` : 'Promo Code', amount: promoAmt })
  }
  const voucherAmt = Number(intent.voucherDiscount || 0)
  if (voucherAmt > 0) discountLines.push({ label: 'Reward Voucher', amount: voucherAmt })
  const extra = Number(r.discount || 0) - discountLines.reduce((a, l) => a + l.amount, 0)
  if (extra > 0.005) discountLines.push({ label: 'Discount', amount: extra })
  const discTotal = discountLines.reduce((a, l) => a + l.amount, 0)

  // Pecahan bayaran pakej KOB
  let kob: KobBreakdown | null = null
  let kobName = ''
  const kobId = intent.kob_session_id
  if (kobId) {
    const [{ data: ks }, { data: cps }, { data: pays }] = await Promise.all([
      admin.from('psy_kob_sessions')
        .select('recommended_package_name, recommended_package_price, package_discount, package_payment_mode, invoice_no')
        .eq('id', kobId).limit(1),
      admin.from('psy_kob_installment_checkpoints').select('target_cumulative').eq('kob_session_id', kobId).order('seq', { ascending: false }).limit(1),
      admin.from('psy_payments').select('id, total, paid_at, created_at').eq('status', 'completed').eq('intent->>kob_session_id', kobId),
    ])
    const k = ks?.[0]
    if (k) {
      kobName = k.recommended_package_name || ''
      const price = Number(k.recommended_package_price || 0)
      const pkgDiscount = Number(k.package_discount || 0)
      const isInstallment = k.package_payment_mode === 'installment' && cps?.[0]
      const owed = isInstallment ? Number(cps![0].target_cumulative) : price
      const ts = (p: any) => new Date(p.paid_at || p.created_at).getTime()
      const upTo = (pays || []).filter((p: any) => p.id === r.id || ts(p) < ts(r) || (ts(p) === ts(r) && p.id <= r.id))
        .sort((a: any, b: any) => ts(a) - ts(b))
      const idx = Math.max(0, upTo.findIndex((p: any) => p.id === r.id))
      const paidToDate = upTo.reduce((a: number, p: any) => a + Number(p.total || 0), 0)
      const thisLabel = isInstallment ? (idx === 0 ? 'Deposit' : `Installment ${idx}`)
        : (paidToDate >= owed - 0.005 && idx === 0 ? 'Full Payment' : `Payment ${idx + 1}`)
      kob = {
        listPrice: owed + pkgDiscount, pkgDiscount, owed,
        installmentCharge: 0,
        thisLabel, paidToDate, outstanding: Math.max(0, owed - paidToDate), invoiceNo: k.invoice_no || '',
      }
    }
  }

  // Nama item: items[] → nama pakej KOB → petikan dalam nota
  const given = (Array.isArray(r.items) ? r.items : []).filter((i: any) => i && (i.title || i.name || i.packageName))
  const total = Number(r.total || 0)
  const items = given.length
    ? given.map((i: any) => ({ name: String(i.title || i.name || i.packageName).replace(/^Pakej:\s*/, ''), price: Number(i.amount || 0) }))
    : [{ name: kobName || (String(r.notes || '').match(/"([^"]+)"/) || [])[1] || 'Pembayaran', price: total + discTotal }]

  const methodMap: Record<string, string> = { transfer: 'Bank Transfer', cash: 'Cash', other: 'Other', fpx: 'FPX Online Banking', card: 'Credit/Debit Card', gateway: 'Online (FPX/Card)', ghl: 'GHL Payment' }
  const method = methodMap[r.manual_method] || (r.payment_method === 'manual' ? '' : methodMap[r.payment_method] || '')

  return { r, items, discountLines, kob, method }
}

// ---- Resit WhatsApp: PDF rasmi (attachment) + mesej ringkas ----
// PDF gagal jana/upload → fallback hantar teks ringkasan sahaja. Dipanggil oleh
// payments-webhook (fulfillment gateway) DAN payments-send-receipt (staff rekod
// bayaran manual di patient-hub.html) — satu-satunya sumber resit rasmi, supaya
// kedua-dua laluan hantar PDF & mesej sama format.
export async function sendPaymentReceiptWhatsApp(admin: any, payment: any) {
  // Butiran pesakit: psy_patients dulu, fallback psy_profiles + auth (email)
  // `name` = nama PESAKIT (untuk PDF resit & ucapan dalam mesej — TAK berubah).
  // `contactName` = nama untuk label kenalan GHL sahaja — jadi nama waris bila
  // contact_preference='waris' (staff nampak siapa sebenarnya terima mesej ni).
  let phone: string | null = null, name: string | null = null, contactName: string | null = null
  let nric: string | null = null, mrn: string | null = null, email: string | null = null
  let userId: string | null = payment.user_id || null
  const patientId = payment.patient_id || payment.intent?.patientId || null

  if (patientId) {
    const { data: pt } = await admin.from('psy_patients')
      .select('full_name, phone, ic_number, mrn, user_id, emergency_contact_phone, emergency_contact_name, contact_preference').eq('id', patientId).limit(1)
    const p = pt?.[0]
    if (p) {
      name = p.full_name || null
      nric = p.ic_number || null; mrn = p.mrn || null
      userId = userId || p.user_id || null
      if (p.contact_preference === 'waris' && p.emergency_contact_phone) {
        phone = p.emergency_contact_phone
        contactName = p.emergency_contact_name || name
      } else {
        phone = p.phone || null
        contactName = name
      }
    }
  }
  if ((!phone || !name) && userId) {
    const { data: prof } = await admin.from('psy_profiles')
      .select('full_name, phone').eq('id', userId).limit(1)
    phone = phone || prof?.[0]?.phone || null
    name = name || prof?.[0]?.full_name || null
    contactName = contactName || name
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
  let receiptNo: string = payment.receipt_ref
  try {
    const ctx = await loadReceiptContext(admin, payment)
    receiptNo = ctx.r.receipt_no || payment.receipt_ref
    const bytes = await buildReceiptPdf({
      receiptNo, paidAt,
      patientName: name, phone, method: ctx.method,
      items: ctx.items, total: Number(payment.total || 0),
      discountLines: ctx.discountLines, kob: ctx.kob,
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
    console.warn('receipt_pdf: PDF resit gagal, fallback teks —', (pdfErr as Error).message)
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
      `No. Resit: ${receiptNo}`,
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
      `No. Resit: ${receiptNo}`,
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
    name: contactName,
    message,
    attachments: pdfUrl ? [pdfUrl] : [],
    sentByName: 'Auto — Resit Pembayaran',
  })
}
