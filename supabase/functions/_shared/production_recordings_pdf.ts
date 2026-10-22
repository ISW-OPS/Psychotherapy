// ============================================================
// _shared/production_recordings_pdf.ts — jana PDF jadual rakaman
// Production (21 Okt 2026, lanjutan Jadual Rakaman Production).
// Ikut pola pdf-lib sama macam _shared/receipt_pdf.ts, satu jadual
// ringkas: Nama | Package | Week | Penyakit, utk Team Production
// (luar sistem) lampir dlm SATU mesej WhatsApp harian — bukan
// berbilang mesej berasingan.
// ============================================================

import { PDFDocument, StandardFonts, rgb } from 'https://esm.sh/pdf-lib@1.17.1'
import { LOGO_ISW_PNG_BASE64 } from './logo_isw.ts'

const INK = rgb(0.12, 0.12, 0.12)
const GRAY = rgb(0.42, 0.42, 0.42)
const LIGHT = rgb(0.86, 0.86, 0.86)
const TEAL = rgb(0.169, 0.541, 0.627)

// Font standard (WinAnsi) tak support emoji/aksara bukan-Latin.
const clean = (s: unknown) =>
  String(s ?? '')
    .replace(/[–—]/g, '-')
    .replace(/[‘’]/g, "'")
    .replace(/[""]/g, '"')
    .replace(/•/g, '-')
    .replace(/[^\x20-\x7E\xA0-\xFF]/g, '')
    .trim() || '-'

export interface ProductionRecordingRow {
  patientName: string
  packageName: string
  milestoneLabel: string
  condition: string
  dueDate: string // YYYY-MM-DD
}

export async function buildProductionRecordingsPdf(rows: ProductionRecordingRow[], label: string): Promise<Uint8Array> {
  const doc = await PDFDocument.create()
  let page = doc.addPage([595.28, 841.89]) // A4
  const bold = await doc.embedFont(StandardFonts.HelveticaBold)
  const reg = await doc.embedFont(StandardFonts.Helvetica)

  const M = 40
  const W = 595.28 - M * 2
  const R = M + W
  let y = 841.89 - M

  const text = (s: string, x: number, size: number, opt: { font?: any; color?: any; right?: boolean } = {}) => {
    const f = opt.font || reg
    const str = clean(s)
    const xx = opt.right ? x - f.widthOfTextAtSize(str, size) : x
    page.drawText(str, { x: xx, y, size, font: f, color: opt.color || INK })
  }
  const hr = (thick = 0.7, color = LIGHT) => {
    page.drawLine({ start: { x: M, y }, end: { x: R, y }, thickness: thick, color })
  }
  // Baris teks berbalut (wrap) ringkas ikut lebar lajur — font standard pdf-lib
  // tiada auto-wrap terbina dalam, jadi dibahagi manual ikut widthOfTextAtSize.
  const wrapLines = (s: string, maxWidth: number, size: number, f: any) => {
    const words = clean(s).split(' ')
    const lines: string[] = []
    let cur = ''
    for (const w of words) {
      const t = cur ? cur + ' ' + w : w
      if (f.widthOfTextAtSize(t, size) > maxWidth && cur) { lines.push(cur); cur = w } else { cur = t }
    }
    if (cur) lines.push(cur)
    return lines
  }

  // ── Tajuk + logo ──────────────────────────────────────────
  try {
    const logoBytes = Uint8Array.from(atob(LOGO_ISW_PNG_BASE64), (c) => c.charCodeAt(0))
    const logo = await doc.embedPng(logoBytes)
    const lh = 36
    page.drawImage(logo, { x: M, y: y - lh + 8, width: (logo.width / logo.height) * lh, height: lh })
  } catch (_) { /* logo gagal — teruskan tanpa imej */ }
  text('JADUAL RAKAMAN PRODUCTION', R, 18, { font: bold, right: true }); y -= 16
  text(label, R, 11, { color: GRAY, right: true }); y -= 26
  hr(1.2, INK); y -= 20

  // ── Jadual: Nama | Package | Week | Penyakit ───────────────
  const colX = { nama: M, pkg: M + 150, week: M + 230, penyakit: M + 300 }
  const colW = { penyakit: R - colX.penyakit }
  text('NAMA', colX.nama, 9, { font: bold, color: GRAY })
  text('PACKAGE', colX.pkg, 9, { font: bold, color: GRAY })
  text('WEEK', colX.week, 9, { font: bold, color: GRAY })
  text('PENYAKIT', colX.penyakit, 9, { font: bold, color: GRAY })
  y -= 6; hr(); y -= 14

  for (const r of rows) {
    const condLines = wrapLines(r.condition || 'Tiada maklumat diisi', colW.penyakit, 9, reg)
    const rowLines = Math.max(1, condLines.length)
    const rowHeight = rowLines * 12 + 6

    if (y - rowHeight < M + 40) { // page break
      page = doc.addPage([595.28, 841.89])
      y = 841.89 - M
      text('JADUAL RAKAMAN PRODUCTION (samb.)', R, 12, { font: bold, right: true }); y -= 18
      hr(); y -= 14
    }

    text(r.patientName, colX.nama, 10, { font: bold })
    text(r.packageName || '-', colX.pkg, 9)
    text(r.milestoneLabel, colX.week, 9)
    let cy = y
    for (const line of condLines) { page.drawText(line, { x: colX.penyakit, y: cy, size: 9, font: reg, color: INK }); cy -= 12 }
    y -= rowHeight
    hr(0.4);
    y -= 10
  }

  if (!rows.length) { text('Tiada rekod.', M, 11, { color: GRAY }); y -= 16 }

  text(`Dijana automatik — ${rows.length} pesakit`, M, 8, { color: GRAY })

  return doc.save()
}
