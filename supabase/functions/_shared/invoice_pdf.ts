// ============================================================
// _shared/invoice_pdf.ts — jana PDF Invois (tuntutan bayaran) di server
// Cermin susun atur shared/invoice.js (jenis "Invois Ansuran" / bayaran penuh, format GHL):
//   tajuk INVOICE + logo + blok syarikat · Billed to / Invoice Number / Issue & Due Date /
//   butang Pay (pautan HitPay boleh diklik) · jadual item · Subtotal / Discount / Amount Due.
// Dilampirkan bersama pautan HitPay semasa staff tekan "Hantar WA" (lihat kob-invoice-pdf).
// Guna pdf-lib (pure JS, jalan dalam Deno Edge Function).
// ============================================================

import { PDFDocument, StandardFonts, rgb, PDFName, PDFString } from 'https://esm.sh/pdf-lib@1.17.1'
import { LOGO_ISW_PNG_BASE64 } from './logo_isw.ts'

const INK = rgb(0.12, 0.12, 0.12)
const GRAY = rgb(0.42, 0.42, 0.42)
const LIGHT = rgb(0.86, 0.86, 0.86)
const TEAL = rgb(0.169, 0.541, 0.627)   // ~#2b8aa0
const GREEN = rgb(0.184, 0.42, 0.246)   // ~#2F6B3F
const WHITE = rgb(1, 1, 1)

// Font standard (WinAnsi) tak support emoji/huruf bukan-Latin.
const clean = (s: unknown) =>
  String(s ?? '')
    .replace(/[–—]/g, '-')
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/[^\x20-\x7E\xA0-\xFF]/g, '')
    .trim() || '-'

const fmt = (n: unknown) =>
  Number(n || 0).toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const rm = (n: unknown) => `RM${fmt(n)}`
const dateLong = (v: string | Date) =>
  new Date(v).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric', timeZone: 'Asia/Kuala_Lumpur' })

export interface InvoicePdfData {
  invoiceNo: string
  issueDate: string | Date
  dueDate: string | Date
  patientName?: string | null
  phone?: string | null
  itemName: string
  listPrice: number        // harga item (sebelum diskaun)
  discount: number
  amountDue: number        // jumlah yang perlu dibayar SEKARANG (ansuran itu sahaja / baki)
  dueLabel?: string | null // cth "Installment 2 - 2 of 3"
  payUrl?: string | null   // pautan HitPay — butang Pay boleh diklik
  itemImageUrl?: string | null // gambar/logo pakej (psy_packages.image_url) — dipaparkan sebelah nama item
}

export async function buildInvoicePdf(d: InvoicePdfData): Promise<Uint8Array> {
  const doc = await PDFDocument.create()
  const page = doc.addPage([595.28, 841.89]) // A4
  const bold = await doc.embedFont(StandardFonts.HelveticaBold)
  const reg = await doc.embedFont(StandardFonts.Helvetica)

  const M = 50
  const W = 595.28 - M * 2
  const R = M + W
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
  text('INVOICE', R, 26, { right: true }); y -= 14
  hr(1.4, INK); y -= 14

  // ── Logo (kiri) + blok syarikat (kanan) ───────────────────
  const blockTop = y
  try {
    const logoBytes = Uint8Array.from(atob(LOGO_ISW_PNG_BASE64), (c) => c.charCodeAt(0))
    const logo = await doc.embedPng(logoBytes)
    const lh = 48
    const lw = (logo.width / logo.height) * lh
    page.drawImage(logo, { x: M, y: y - lh, width: lw, height: lh })
  } catch (_) { /* logo gagal — teruskan tanpa imej */ }
  y = blockTop - 10
  text('Ibnu Sina Wellness Sdn Bhd (1319021-P)', R, 12, { right: true }); y -= 14
  for (const ln of ['03-8966 3702', 'Lot 331, Lorong Senyum Matahari B, Country Heights,', 'Kajang, Selangor 43000', 'Malaysia', 'www.ibnusinawellness.com']) {
    text(ln, R, 8, { color: GRAY, right: true }); y -= 11
  }
  y -= 12
  hr(); y -= 22

  // ── Billed to / Invoice Number / Issue+Due Date / Pay ─────
  const rowTop = y
  const c2 = M + 150, c3 = M + 290
  text('Billed to', M, 10, { font: bold }); y -= 15
  for (const ln of [d.patientName || '-', d.phone || '-', 'Malaysia']) { text(ln, M, 8.5, { color: GRAY }); y -= 12 }
  const leftEnd = y

  y = rowTop
  text('Invoice Number', c2, 10, { font: bold }); y -= 15
  text(d.invoiceNo, c2, 8.5, { color: GRAY })

  y = rowTop
  text('Issue Date', c3, 10, { font: bold }); y -= 13
  text(dateLong(d.issueDate), c3, 8.5, { color: GRAY }); y -= 20
  text('Due Date', c3, 10, { font: bold }); y -= 13
  text(dateLong(d.dueDate), c3, 8.5, { color: GRAY })

  // Butang Pay (hijau) — boleh diklik kalau ada pautan; kalau tiada baki, tanda "Paid"
  const bw = 130, bh = 26, bx = R - bw, by = rowTop - bh + 10
  const paid = d.amountDue <= 0.005
  if (paid || d.payUrl) {
    page.drawRectangle({ x: bx, y: by, width: bw, height: bh, color: paid ? rgb(0.9, 0.95, 0.91) : GREEN, borderColor: GREEN, borderWidth: 1 })
    const label = paid ? 'Paid' : `Pay ${rm(d.amountDue)}`
    const lw2 = bold.widthOfTextAtSize(label, 10)
    page.drawText(label, { x: bx + (bw - lw2) / 2, y: by + 9, size: 10, font: bold, color: paid ? GREEN : WHITE })
    if (!paid && d.payUrl) {
      const annot = doc.context.obj({
        Type: 'Annot', Subtype: 'Link', Rect: [bx, by, bx + bw, by + bh], Border: [0, 0, 0],
        A: { Type: 'Action', S: 'URI', URI: PDFString.of(d.payUrl) },
      })
      page.node.set(PDFName.of('Annots'), doc.context.obj([doc.context.register(annot)]))
    }
  }
  y = Math.min(y, leftEnd) - 40

  // ── Jadual item (pita teal) ───────────────────────────────
  page.drawRectangle({ x: M, y: y - 8, width: W, height: 24, color: TEAL })
  const cPrice = R - 190, cQty = R - 120, cTax = R - 75
  const hdr = (s: string, x: number, right = false) => {
    const str = s.toUpperCase()
    const xx = right ? x - bold.widthOfTextAtSize(str, 8) : x
    page.drawText(str, { x: xx, y: y - 1, size: 8, font: bold, color: WHITE })
  }
  hdr('Item Name', M + 8)
  hdr('Price', cPrice, true); hdr('Quantity', cQty, true); hdr('Tax', cTax, true); hdr('Subtotal', R - 8, true)
  y -= 34
  let itemNameX = M + 8
  if (d.itemImageUrl) {
    try {
      const res = await fetch(d.itemImageUrl)
      const buf = new Uint8Array(await res.arrayBuffer())
      const ct = res.headers.get('content-type') || ''
      const img = ct.includes('png') ? await doc.embedPng(buf) : await doc.embedJpg(buf)
      const ih = 16
      const iw = (img.width / img.height) * ih
      page.drawImage(img, { x: M + 8, y: y - 4, width: iw, height: ih })
      itemNameX = M + 8 + iw + 8
    } catch (_) { /* gambar pakej gagal muat — teruskan tanpa imej */ }
  }
  text(String(d.itemName).toUpperCase(), itemNameX, 8.5, { color: GRAY })
  text(rm(d.listPrice), cPrice, 8.5, { color: GRAY, right: true })
  text('1', cQty, 8.5, { color: GRAY, right: true })
  text('-', cTax, 8.5, { color: GRAY, right: true })
  text(rm(d.listPrice), R - 8, 8.5, { color: GRAY, right: true })
  y -= 12
  hr(0.5); y -= 24

  // ── Jumlah: Subtotal / Discount / Amount Due ──────────────
  const tx = R - 210
  const row = (label: string, val: string, boldRow = false) => {
    text(label, tx, boldRow ? 10 : 9.5, { font: bold })
    text(val, R, boldRow ? 10 : 8.5, { font: boldRow ? bold : reg, color: boldRow ? INK : GRAY, right: true })
    y -= 16
  }
  row('Subtotal', rm(d.listPrice))
  row('Discount', `-${rm(d.discount)}`)
  y += 4
  hr(0.8, LIGHT, tx, R); y -= 15
  text('Amount Due (MYR)', tx, 10, { font: bold })
  text(rm(d.amountDue), R, 10, { font: bold, right: true }); y -= 12
  if (d.dueLabel) { text(d.dueLabel, tx, 8, { color: GRAY }); y -= 12 }

  // ── Nota bawah halaman ────────────────────────────────────
  y = M + 12
  const note = 'Please make payment by the due date. Thank you.'
  page.drawText(note, { x: M + (W - reg.widthOfTextAtSize(note, 7)) / 2, y, size: 7, font: reg, color: GRAY })

  return await doc.save()
}
