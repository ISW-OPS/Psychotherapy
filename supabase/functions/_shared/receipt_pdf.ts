// ============================================================
// _shared/receipt_pdf.ts — jana PDF Resit Pembayaran di server
// Cermin susun atur shared/receipt.js (resit rasmi dalam app):
//   header syarikat + PAYMENT RECEIPT · Patient Information ·
//   Payment Summary (item/subtotal/discount/tax/total) · disclaimer.
// Guna pdf-lib (pure JS, jalan dalam Deno Edge Function).
// ============================================================

import { PDFDocument, StandardFonts, rgb } from 'https://esm.sh/pdf-lib@1.17.1'
import { LOGO_ISW_PNG_BASE64 } from './logo_isw.ts'
import { sendWhatsApp } from './ghl.ts'

const NAVY = rgb(0.106, 0.165, 0.29)      // ~#1B2A4A
const GREEN = rgb(0.184, 0.42, 0.246)     // ~#2F6B3F
const INK = rgb(0.15, 0.15, 0.15)
const GRAY = rgb(0.45, 0.45, 0.45)
const LIGHT = rgb(0.85, 0.85, 0.85)

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

export interface ReceiptData {
  receiptRef: string
  paidAt: string | Date          // ISO — dipapar waktu Malaysia
  patientName?: string | null
  nric?: string | null
  mrn?: string | null
  email?: string | null
  phone?: string | null
  items: Array<{ title?: string | null; amount?: number | null }>
  total: number
}

export async function buildReceiptPdf(d: ReceiptData): Promise<Uint8Array> {
  const doc = await PDFDocument.create()
  const page = doc.addPage([595.28, 841.89]) // A4
  const bold = await doc.embedFont(StandardFonts.HelveticaBold)
  const reg = await doc.embedFont(StandardFonts.Helvetica)

  const M = 50                    // margin
  const W = 595.28 - M * 2        // lebar kandungan
  let y = 841.89 - M

  const text = (s: string, x: number, size: number, opt: { font?: any; color?: any; right?: boolean } = {}) => {
    const f = opt.font || reg
    const str = clean(s)
    const xx = opt.right ? x - f.widthOfTextAtSize(str, size) : x
    page.drawText(str, { x: xx, y, size, font: f, color: opt.color || INK })
  }
  const hr = (thick = 0.7, color = LIGHT) => {
    page.drawLine({ start: { x: M, y }, end: { x: M + W, y }, thickness: thick, color })
  }

  // ── Header kiri: logo + syarikat ───────────────────────────
  const topY = y
  try {
    const logoBytes = Uint8Array.from(atob(LOGO_ISW_PNG_BASE64), (c) => c.charCodeAt(0))
    const logo = await doc.embedPng(logoBytes)
    const lh = 42                                  // ~h-14 resit app
    const lw = (logo.width / logo.height) * lh
    page.drawImage(logo, { x: M, y: y - lh + 8, width: lw, height: lh })
    y -= lh + 4
  } catch (_) { /* logo gagal — teruskan tanpa imej */ }
  text('Natural - Purification - Wellness', M, 8, { color: GREEN, font: bold }); y -= 14
  text('Ibnu Sina Wellness Sdn Bhd (1319021-P)', M, 10, { font: bold }); y -= 13
  text('Lot 331, Lorong Senyum Matahari B,', M, 8, { color: GRAY }); y -= 10
  text('Country Heights, 43000 Kajang, Selangor, Malaysia.', M, 8, { color: GRAY }); y -= 12
  text('Tel: 03-8966 3702  ·  hello@ibnusinawellness.com', M, 8, { color: GRAY }); y -= 10
  text('www.ibnusinawellness.com', M, 8, { color: GRAY })
  const leftEndY = y

  // ── Header kanan: tajuk + no/tarikh resit ─────────────────
  y = topY - 4
  text('PAYMENT RECEIPT', M + W, 20, { font: bold, color: NAVY, right: true }); y -= 15
  text('RESIT PEMBAYARAN', M + W, 10, { font: bold, color: GREEN, right: true }); y -= 22

  const paidDate = new Date(new Date(d.paidAt).getTime() + 8 * 3600 * 1000) // UTC+8
  const p2 = (n: number) => String(n).padStart(2, '0')
  const dateStr = `${p2(paidDate.getUTCDate())}/${p2(paidDate.getUTCMonth() + 1)}/${paidDate.getUTCFullYear()} ${p2(paidDate.getUTCHours())}:${p2(paidDate.getUTCMinutes())}`
  text(`Receipt No. : ${d.receiptRef}`, M + W, 9, { font: bold, right: true }); y -= 12
  text(`Receipt Date : ${dateStr}`, M + W, 9, { right: true })

  // ── Garis navy tebal ───────────────────────────────────────
  y = Math.min(y, leftEndY) - 22
  hr(2.5, NAVY); y -= 24

  // ── PATIENT INFORMATION ────────────────────────────────────
  text('PATIENT INFORMATION', M, 10, { font: bold, color: NAVY }); y -= 6
  hr(); y -= 14
  const info: Array<[string, string]> = [
    ['Patient Name', d.patientName || '-'],
    ['NRIC', d.nric || '-'],
    ['MRN', d.mrn || '-'],
    ['Email', d.email || '-'],
    ['Phone', d.phone || '-'],
  ]
  for (const [label, val] of info) {
    text(label, M, 9, { color: GRAY })
    text(':', M + 95, 9, { color: GRAY })
    text(val, M + 105, 9, { font: bold })
    y -= 14
  }
  y -= 12

  // ── PAYMENT SUMMARY ────────────────────────────────────────
  text('PAYMENT SUMMARY', M, 10, { font: bold, color: NAVY }); y -= 6
  hr(); y -= 14
  for (const it of (d.items || [])) {
    const nm = String(it.title || 'Item').replace(/^Pakej:\s*/, '')
    text(nm, M, 9, { font: bold })
    text(fmt(it.amount), M + W, 9, { right: true })
    y -= 14
  }
  y -= 2; hr(); y -= 14
  const row = (label: string, val: string) => {
    text(label, M, 9, { color: GRAY })
    text(val, M + W, 9, { right: true })
    y -= 14
  }
  row('Subtotal', `RM ${fmt(d.total)}`)
  row('Discount', 'RM 0.00')
  row('Tax (0%)', 'RM 0.00')
  y -= 2; hr(); y -= 16
  text('TOTAL AMOUNT PAID', M, 11, { font: bold, color: NAVY })
  text(`RM ${fmt(d.total)}`, M + W, 11, { font: bold, color: GREEN, right: true })

  // ── Disclaimer bawah halaman ───────────────────────────────
  y = M + 18
  hr(); y -= 14
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
    name: contactName,
    message,
    attachments: pdfUrl ? [pdfUrl] : [],
    sentByName: 'Auto — Resit Pembayaran',
  })
}
