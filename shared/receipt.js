// ── Resit Pembayaran (kandungan boleh guna semula) ─────────────────────────────
// Digunakan oleh resit.html (halaman penuh) & payment.html/sejarah (modal fallback).
// buildReceiptInner(r) → Promise<string> kandungan dalam #receipt-print.
// Baca window.currentUser + window.patientRecord; butiran pakej ditarik dari psy_packages.
//
// Format ikut rujukan GHL: tajuk RECEIPT, Billed to, Receipt No, Date Paid, jadual item, Subtotal/Discount/Amount Paid.
// Helper dokumen (window.iswDoc) dikongsi dengan shared/invoice.js.

(function () {
  const RCPT_METHODS = {
    fpx: 'FPX Online Banking', card: 'Kad Kredit/Debit', transfer: 'Bank Transfer',
    ghl: 'GHL Payment', manual: 'Manual', gateway: 'Online (FPX/Kad)',
  };
  // Dwibahasa: L(BM, EN) — bahasa semasa (i18n.js). Default EN kalau i18n belum dimuat.
  const L = (ms, en) => (window.iswL ? window.iswL(ms, en) : en);
  const rEsc = (s) => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const rFmt = (n) => Number(n || 0).toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const rList = (v) => Array.isArray(v)
    ? v.map(x => String(x).trim()).filter(Boolean)
    : (typeof v === 'string' ? v.split('\n').map(s => s.trim()).filter(Boolean) : []);

  // ── Elemen dokumen bersama (Resit + Invois) ─────────────────────────────────
  const DOC_TEAL = '#2b8aa0';
  const rMoney = (n) => 'RM' + rFmt(n);
  const rMethod = (r) => ({ transfer: L('Pindahan Bank', 'Bank Transfer'), cash: L('Tunai', 'Cash'), other: L('Lain-lain', 'Other') }[r.manual_method]
    || (r.payment_method === 'manual' ? '' : RCPT_METHODS[r.payment_method] || ''));
  const rDateLong = (v) => v
    ? new Date(v).toLocaleDateString(L('ms-MY', 'en-US'), { month: 'long', day: 'numeric', year: 'numeric', timeZone: 'Asia/Kuala_Lumpur' })
    : '—';

  // Tajuk dokumen (kanan atas) + garis + blok syarikat rata-kanan.
  function docHeaderHtml(title) {
    return `
      <div class="text-right">
        <div class="text-[28px] md:text-[32px] font-medium tracking-tight text-ink leading-none">${rEsc(title)}</div>
      </div>
      <div class="border-t-2 border-ink/70 mt-2 mb-5"></div>
      <div class="flex items-start justify-between gap-6">
        <img src="${location.origin}/image/Logo_ISW.png" alt="Ibnu Sina Wellness" class="h-14 object-contain" onerror="this.style.display='none'">
        <div class="text-right">
          <div class="text-lg text-ink">Ibnu Sina Wellness Sdn Bhd (1319021-P)</div>
          <div class="text-xs text-ink/60 mt-1 leading-relaxed">
            03-8966 3702<br>
            Lot 331, Lorong Senyum Matahari B, Country Heights,<br>
            Kajang, Selangor 43000<br>Malaysia<br>
            www.ibnusinawellness.com
          </div>
        </div>
      </div>`;
  }

  // Nama item untuk resit: items[] kalau ada; kalau tiada (bayaran KOB manual) tarik nama pakej
  // dari sesi KOB (intent.kob_session_id), akhir sekali petikan dalam nota.
  async function resolveReceiptItems(r) {
    const disc = Number(r.discount || 0);
    const total = Number(r.total || 0);
    const given = (r.items || []).filter(it => it && (it.title || it.name || it.packageName));
    if (given.length) {
      return given.map(it => ({
        name: String(it.title || it.name || it.packageName).replace(/^Pakej:\s*/, ''),
        price: Number(it.amount || 0),
      }));
    }
    let name = '';
    const kobId = r.intent?.kob_session_id;
    if (kobId && window.db) {
      try {
        const { data } = await window.db.from('psy_kob_sessions').select('recommended_package_name').eq('id', kobId).maybeSingle();
        name = data?.recommended_package_name || '';
      } catch (_) { /* fallback di bawah */ }
    }
    if (!name) name = (String(r.notes || '').match(/"([^"]+)"/) || [])[1] || L('Pembayaran', 'Payment');
    return [{ name, price: total + disc }];
  }

  // Baris diskaun berlabel: kod promo (dari intent / cari psy_promo_codes), baucar ganjaran,
  // atau "Discount" umum (medan psy_payments.discount). Jumlah = yang terbesar antara medan & baris.
  async function resolveDiscountLines(r) {
    const it = r.intent || {};
    const lines = [];
    const promoAmt = Number(it.promoDiscount || 0);
    if (promoAmt > 0) {
      let code = it.promoCode || '';
      if (!code && it.promoCodeId && window.db) {
        try {
          const { data } = await window.db.from('psy_promo_codes').select('code').eq('id', it.promoCodeId).maybeSingle();
          code = data?.code || '';
        } catch (_) { /* tanpa kod */ }
      }
      lines.push({ label: code ? `${L('Kod Promo', 'Promo Code')} (${code})` : L('Kod Promo', 'Promo Code'), amount: promoAmt });
    }
    const voucherAmt = Number(it.voucherDiscount || 0);
    if (voucherAmt > 0) lines.push({ label: L('Baucar Ganjaran', 'Reward Voucher'), amount: voucherAmt });
    const explained = lines.reduce((a, l) => a + l.amount, 0);
    const extra = Number(r.discount || 0) - explained;
    if (extra > 0.005) lines.push({ label: L('Diskaun', 'Discount'), amount: extra });
    return lines;
  }

  // Pecahan bayaran pakej KOB: harga pakej, diskaun, komitmen, bayaran ini, terkumpul, baki tertunggak
  // (dikira setakat bayaran ini — bukan jumlah semasa). null kalau bukan bayaran pakej KOB.
  async function resolveKobBreakdown(r) {
    const kobId = r.intent?.kob_session_id;
    if (!kobId || !window.db) return null;
    try {
      const [{ data: kob }, { data: cps }, { data: pays }] = await Promise.all([
        window.db.from('psy_kob_sessions')
          .select('recommended_package_name, recommended_package_price, package_discount, package_payment_mode, invoice_no')
          .eq('id', kobId).maybeSingle(),
        window.db.from('psy_kob_installment_checkpoints').select('target_cumulative').eq('kob_session_id', kobId).order('seq', { ascending: false }).limit(1),
        window.db.from('psy_payments').select('id, total, paid_at, created_at').eq('status', 'completed').eq('intent->>kob_session_id', kobId),
      ]);
      if (!kob) return null;
      const price = Number(kob.recommended_package_price || 0);
      const pkgDiscount = Number(kob.package_discount || 0);
      const isInstallment = kob.package_payment_mode === 'installment' && cps?.[0];
      const owed = isInstallment ? Number(cps[0].target_cumulative) : price;
      const ts = (p) => new Date(p.paid_at || p.created_at).getTime();
      const upTo = (pays || []).filter(p => p.id === r.id || ts(p) < ts(r) || (ts(p) === ts(r) && p.id <= r.id))
        .sort((a, b) => ts(a) - ts(b));
      const idx = Math.max(0, upTo.findIndex(p => p.id === r.id));
      const paidToDate = upTo.reduce((a, p) => a + Number(p.total || 0), 0);
      const label = isInstallment ? (idx === 0 ? L('Deposit', 'Deposit') : `${L('Ansuran', 'Installment')} ${idx}`)
        : (paidToDate >= owed - 0.005 && idx === 0 ? L('Bayaran Penuh', 'Full Payment') : `${L('Bayaran', 'Payment')} ${idx + 1}`);
      return {
        listPrice: owed + pkgDiscount, pkgDiscount, price, owed,
        thisLabel: label, paidToDate, outstanding: Math.max(0, owed - paidToDate),
        invoiceNo: kob.invoice_no || '',
      };
    } catch (_) { return null; }
  }

  // Bina kandungan resit (tanpa bekas modal/halaman). Async — tarik nama item.
  // `override` (pilihan) — bagi laluan STAFF (patient-hub.html) yang tiada
  // window.currentUser/patientRecord (session staff, bukan pesakit): hantar
  // {full_name, ic_number, mrn, email, phone} terus, elak bergantung pada
  // globals sesi pesakit. Laluan pesakit (resit.html/payment.html) tak hantar
  // override — kekal guna window.currentUser/patientRecord macam sedia ada.
  async function buildReceiptInner(r, override) {
    const cu = override ? { full_name: override.full_name } : (window.currentUser || {});
    const pr = override ? { phone: override.phone } : (window.patientRecord || {});

    const total = Number(r.total || 0);
    const [items, discLines, kb] = await Promise.all([resolveReceiptItems(r), resolveDiscountLines(r), resolveKobBreakdown(r)]);
    const disc = Math.max(Number(r.discount || 0), discLines.reduce((a, l) => a + l.amount, 0));
    const th = 'text-[11px] font-medium uppercase tracking-wide text-ink/70 py-3';

    return `
      ${docHeaderHtml(L('RESIT', 'RECEIPT'))}

      <div class="border-t border-ink/10 mt-6 pt-5 grid grid-cols-2 gap-6 text-sm">
        <div>
          <div class="font-semibold text-ink">${L('Dibilkan kepada', 'Billed to')}</div>
          <div class="text-ink/60 text-xs mt-2 leading-relaxed">
            ${rEsc(cu.full_name || '—')}<br>${rEsc(pr.phone || '—')}<br>Malaysia
          </div>
        </div>
        <div class="space-y-3">
          <div><div class="font-semibold text-ink">${L('No. Resit', 'Receipt No')}</div><div class="text-ink/60 text-xs mt-1">${rEsc(r.receipt_no || r.receipt_ref || '—')}</div></div>
          <div><div class="font-semibold text-ink">${L('Tarikh Bayaran', 'Date Paid')}</div><div class="text-ink/60 text-xs mt-1">${rDateLong(r.paid_at)}</div></div>
          ${rMethod(r) ? `<div><div class="font-semibold text-ink">${L('Kaedah Bayaran', 'Payment Method')}</div><div class="text-ink/60 text-xs mt-1">${rEsc(rMethod(r))}</div></div>` : ''}
        </div>
      </div>

      <table class="w-full mt-10 text-sm">
        <thead>
          <tr class="border-b-2" style="border-color:${DOC_TEAL}">
            <th class="${th} text-left">${L('Nama Item', 'Item Name')}</th>
            <th class="${th} text-right">${L('Harga', 'Price')}</th>
            <th class="${th} text-right w-16">${L('Kuantiti', 'Qty')}</th>
            <th class="${th} text-right">${L('Jumlah Kecil', 'Subtotal')}</th>
          </tr>
        </thead>
        <tbody>
          ${items.map(it => `<tr class="border-b border-ink/10">
            <td class="py-4 text-xs text-ink/70 uppercase">${rEsc(it.name)}</td>
            <td class="py-4 text-xs text-ink/70 text-right whitespace-nowrap">${rMoney(it.price)}</td>
            <td class="py-4 text-xs text-ink/70 text-right">1</td>
            <td class="py-4 text-xs text-ink/70 text-right whitespace-nowrap">${rMoney(it.price)}</td>
          </tr>`).join('')}
        </tbody>
      </table>

      <div class="flex justify-end mt-4">
        <div class="w-full max-w-xs text-sm">
          <div class="flex justify-between py-1.5"><span class="font-semibold text-ink">${L('Jumlah Kecil', 'Subtotal')}</span><span class="text-ink/60 text-xs">${rMoney(total + disc)}</span></div>
          ${(discLines.length ? discLines : [{ label: L('Diskaun', 'Discount'), amount: 0 }]).map(l =>
            `<div class="flex justify-between py-1.5"><span class="font-semibold text-ink">${rEsc(l.label)}</span><span class="text-ink/60 text-xs">-${rMoney(l.amount)}</span></div>`).join('')}
          <div class="flex justify-between py-2.5 mt-1 border-t border-ink/20"><span class="font-bold text-ink">${L('Jumlah Dibayar (MYR)', 'Amount Paid (MYR)')}</span><span class="font-bold text-ink">${rMoney(total)}</span></div>
        </div>
      </div>

      ${kb ? `
      <div class="mt-8 border-t border-ink/10 pt-5">
        <div class="text-[11px] font-medium uppercase tracking-wide text-ink/70 mb-2">${L('Pecahan Bayaran', 'Payment Breakdown')}${kb.invoiceNo ? ` <span class="normal-case text-ink/40">· ${L('Invois', 'Invoice')} ${rEsc(kb.invoiceNo)}</span>` : ''}</div>
        <div class="max-w-sm ml-auto text-sm">
          ${kb.pkgDiscount > 0 ? `<div class="flex justify-between py-1"><span class="text-ink/70">${L('Harga Pakej', 'Package Price')}</span><span class="text-ink/60 text-xs">${rMoney(kb.listPrice)}</span></div>
          <div class="flex justify-between py-1"><span class="text-ink/70">${L('Diskaun', 'Discount')}</span><span class="text-ink/60 text-xs">-${rMoney(kb.pkgDiscount)}</span></div>` : ''}
          <div class="flex justify-between py-1.5 border-t border-ink/10 mt-1"><span class="font-semibold text-ink">${L('Jumlah Pakej', 'Package Total')}</span><span class="font-semibold text-ink">${rMoney(kb.owed)}</span></div>
          <div class="flex justify-between py-1"><span class="text-ink/70">${L('Dibayar pada resit ini', 'Paid on this receipt')} (${rEsc(kb.thisLabel)})</span><span class="text-ink/60 text-xs">${rMoney(total)}</span></div>
          <div class="flex justify-between py-1"><span class="text-ink/70">${L('Jumlah Dibayar Setakat Ini', 'Total Paid to Date')}</span><span class="text-ink/60 text-xs">${rMoney(kb.paidToDate)}</span></div>
          <div class="flex justify-between py-2 border-t border-ink/20 mt-1"><span class="font-bold text-ink">${L('Baki Perlu Dibayar', 'Balance Remaining')}</span><span class="font-bold text-ink">${rMoney(kb.outstanding)}</span></div>
        </div>
      </div>` : ''}

      <!-- Footer disclaimer (ditolak ke bawah sekali halaman) -->
      <div class="mt-auto pt-8 text-[11px] text-ink/50 text-center leading-relaxed">
        ${L('Ini ialah resit rasmi dan bukti pembayaran. Sila simpan resit ini untuk rujukan anda. Tiada bayaran balik selepas pembayaran dibuat.', 'This is an official receipt and serves as proof of payment. Please keep this receipt for your reference. No refund is applicable once the payment is made.')}
      </div>`;
  }

  // Cetak dokumen dalam tetingkap BERSIH (hanya dokumen, satu muka surat A4) — elak
  // window.print() pada halaman induk yg cetak tajuk halaman + kandungan modal terpotong.
  function printHtml(inner, title) {
    const w = window.open('', '_blank');
    if (!w) { alert(L('Benarkan pop-up untuk mencetak.', 'Allow pop-ups to print.')); return; }
    w.document.write(`<!DOCTYPE html><html><head><meta charset="UTF-8"><title>${rEsc(title || '')}</title>
      <script src="https://cdn.tailwindcss.com"><\/script>
      <script src="${location.origin}/shared/theme.js"><\/script>
      <script>tailwind.config = window.ISW_TAILWIND_CONFIG || {};<\/script>
      <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
      <style>@page { size: A4; margin: 12mm; } body { font-family: Inter, system-ui, sans-serif; margin: 0; } .no-print { display: none !important; }</style>
      </head><body class="bg-white text-ink"><div class="flex flex-col p-2" style="min-height:96vh">${inner}</div>
      <script>window.onload = function () { setTimeout(function () { window.print(); }, 700); };<\/script></body></html>`);
    w.document.close();
  }

  // Modal fallback (jika mahu buka resit tanpa navigasi halaman)
  async function viewReceiptPDF(id, override) {
    const r = (window._receipts || []).find(x => x.id === id);
    if (!r) return;
    const inner = await buildReceiptInner(r, override);
    const modal = document.createElement('div');
    modal.id = 'pdf-modal';
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center p-4';
    modal.innerHTML = `
      <div class="absolute inset-0 bg-black/50" onclick="this.parentElement.remove()"></div>
      <div class="relative bg-white rounded-2xl max-w-3xl w-full max-h-[92vh] overflow-hidden flex flex-col">
        <div class="no-print p-4 border-b border-ink/10 flex items-center justify-between">
          <h3 class="font-bold">Resit Pembayaran</h3>
          <div class="flex gap-2">
            <button type="button" id="receipt-print-btn" class="bg-navy text-white px-4 py-2 rounded-lg text-sm font-semibold">🖨 Print / Save PDF</button>
            <button onclick="this.closest('.fixed').remove()" class="text-ink/60 text-xl px-2">×</button>
          </div>
        </div>
        <div id="receipt-print" class="flex-1 overflow-y-auto p-8 text-ink">${inner}</div>
      </div>`;
    document.body.appendChild(modal);
    document.getElementById('receipt-print-btn').onclick = () => printHtml(inner, r.receipt_no || r.receipt_ref);
  }

  // Terus ke print/save PDF — tetingkap bersih (lihat printHtml).
  async function printReceipt(id) {
    const r = (window._receipts || []).find(x => x.id === id);
    if (!r) return;
    printHtml(await buildReceiptInner(r), r.receipt_no || r.receipt_ref);
  }

  window.iswDoc = { header: docHeaderHtml, money: rMoney, dateLong: rDateLong, esc: rEsc, L, printHtml, TEAL: DOC_TEAL };
  window.buildReceiptInner = buildReceiptInner;
  window.viewReceiptPDF = viewReceiptPDF;
  window.printReceipt = printReceipt;
})();
