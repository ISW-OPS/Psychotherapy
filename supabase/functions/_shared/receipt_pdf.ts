// ============================================================
// _shared/receipt_pdf.ts — jana PDF Resit Pembayaran di server
// Cermin susun atur shared/receipt.js (resit rasmi dalam app):
//   header syarikat + PAYMENT RECEIPT · Patient Information ·
//   Payment Summary (item/subtotal/discount/tax/total) · disclaimer.
// Guna pdf-lib (pure JS, jalan dalam Deno Edge Function).
// ============================================================

import { PDFDocument, StandardFonts, rgb } from 'https://esm.sh/pdf-lib@1.17.1'
import { LOGO_ISW_PNG_BASE64 } from './logo_isw.ts'

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
