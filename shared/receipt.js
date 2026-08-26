// ── Resit Pembayaran (kandungan boleh guna semula) ─────────────────────────────
// Digunakan oleh resit.html (halaman penuh) & payment.html/sejarah (modal fallback).
// buildReceiptInner(r) → Promise<string> kandungan dalam #receipt-print.
// Baca window.currentUser + window.patientRecord; butiran pakej ditarik dari psy_packages.
//
// NOTA: header sengaja TIDAK papar Transaction ID / Payment Method / Payment Status
// (atas permintaan) — kaedah bayaran masih dipapar dalam bhg Payment Summary.

(function () {
  const RCPT_METHODS = {
    fpx: 'FPX Online Banking', card: 'Kad Kredit/Debit', transfer: 'Bank Transfer',
    ghl: 'GHL Payment', manual: 'Manual', gateway: 'Online (FPX/Kad)',
  };
  const rEsc = (s) => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const rFmt = (n) => Number(n || 0).toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const rList = (v) => Array.isArray(v)
    ? v.map(x => String(x).trim()).filter(Boolean)
    : (typeof v === 'string' ? v.split('\n').map(s => s.trim()).filter(Boolean) : []);

  // Bina kandungan resit (tanpa bekas modal/halaman). Async — tarik butiran pakej.
  // `override` (pilihan) — bagi laluan STAFF (patient-hub.html) yang tiada
  // window.currentUser/patientRecord (session staff, bukan pesakit): hantar
  // {full_name, ic_number, mrn, email, phone} terus, elak bergantung pada
  // globals sesi pesakit. Laluan pesakit (resit.html/payment.html) tak hantar
  // override — kekal guna window.currentUser/patientRecord macam sedia ada.
  async function buildReceiptInner(r, override) {
    const cu = override ? { full_name: override.full_name, email: override.email } : (window.currentUser || {});
    const pr = override ? { ic_number: override.ic_number, mrn: override.mrn, phone: override.phone } : (window.patientRecord || {});

    const total = Number(r.total || 0);
    const email = cu.email || '—';
    const dateStr = r.paid_at ? new Date(r.paid_at).toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—';

    const infoLine = (label, value) => `<div class="flex gap-2">
      <span class="text-ink/60 font-medium w-32 flex-shrink-0">${label}</span><span class="text-ink/40">:</span>
      <span class="font-semibold text-ink break-words">${rEsc(value)}</span></div>`;

    const sectionHead = (icon, title) => `<div class="flex items-center gap-3 mb-3">
      <span class="text-green-dark">${icon}</span>
      <h3 class="text-sm font-bold text-navy tracking-wide">${title}</h3>
      <div class="flex-1 border-t border-ink/15"></div></div>`;

    return `
      <!-- Header -->
      <div class="flex justify-between items-start gap-6 flex-wrap">
        <div class="min-w-[220px]">
          <img src="../../image/Logo_ISW.png" alt="Ibnu Sina Wellness" class="h-14 object-contain mb-1" onerror="this.style.display='none'">
          <div class="text-[11px] font-semibold text-green-dark tracking-wide mb-3">Natural • Purification • Wellness</div>
          <div class="text-sm font-bold text-ink">Ibnu Sina Wellness Sdn Bhd (1319021-P)</div>
          <div class="text-xs text-ink/60 mt-1 leading-relaxed">
            Lot 331, Lorong Senyum Matahari B,<br>Country Heights, 43000 Kajang, Selangor, Malaysia.
          </div>
          <div class="text-xs text-ink/60 mt-2 space-y-0.5">
            <div>📞 03-8966 3702 &nbsp; ✉️ hello@ibnusinawellness.com</div>
            <div>🌐 www.ibnusinawellness.com</div>
          </div>
        </div>
        <div class="text-right">
          <div class="text-3xl font-extrabold text-navy leading-none">PAYMENT RECEIPT</div>
          <div class="text-sm font-semibold text-green-dark tracking-wide mt-1">RESIT PEMBAYARAN</div>
          <div class="mt-4 text-sm space-y-1.5 inline-block text-left">
            <div class="flex gap-2"><span class="text-ink/60 font-medium w-28">Receipt No.</span><span class="text-ink/40">:</span><span class="font-bold text-ink">${rEsc(r.receipt_ref || '—')}</span></div>
            <div class="flex gap-2"><span class="text-ink/60 font-medium w-28">Receipt Date</span><span class="text-ink/40">:</span><span class="font-semibold text-ink">${dateStr}</span></div>
          </div>
        </div>
      </div>

      <div class="border-t-4 border-navy my-6"></div>

      <!-- Patient info -->
      ${sectionHead('👤', 'PATIENT INFORMATION')}
      <div class="grid sm:grid-cols-2 gap-x-10 gap-y-2 text-sm mb-6">
        ${infoLine('Patient Name', cu.full_name || '—')}
        ${infoLine('NRIC', pr.ic_number || '—')}
        ${infoLine('MRN', pr.mrn || '—')}
        ${infoLine('Email', email)}
        ${infoLine('Phone', pr.phone || '—')}
      </div>

      <!-- Payment summary (item + jumlah, digabungkan) -->
      ${sectionHead('🧾', 'PAYMENT SUMMARY')}
      <div class="text-sm">
        ${(r.items || []).map(it => {
          const nm = (it.title || it.name || it.packageName || 'Item').replace(/^Pakej:\s*/, '');
          return `<div class="flex justify-between py-1"><span class="font-semibold text-ink">${rEsc(nm)}</span><span class="text-ink">${rFmt(it.amount)}</span></div>`;
        }).join('')}
        <div class="flex justify-between py-1 border-t border-ink/10 mt-1 pt-2"><span class="text-ink/60">Subtotal</span><span class="text-ink">RM ${rFmt(total)}</span></div>
        <div class="flex justify-between py-1"><span class="text-ink/60">Discount</span><span class="text-ink">RM 0.00</span></div>
        <div class="flex justify-between py-1"><span class="text-ink/60">Tax (0%)</span><span class="text-ink">RM 0.00</span></div>
        <div class="flex justify-between py-2.5 mt-1 border-t border-ink/15">
          <span class="font-bold text-navy">TOTAL AMOUNT PAID</span><span class="font-bold text-green-dark">RM ${rFmt(total)}</span>
        </div>
      </div>

      <!-- Footer disclaimer (ditolak ke bawah sekali halaman) -->
      <div class="mt-auto pt-6 border-t border-ink/10 text-[11px] text-ink/50 text-center leading-relaxed">
        This is an official receipt and serves as proof of payment. Please keep this receipt for your reference. No refund is applicable once the payment is made.
      </div>`;
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
            <button onclick="window.print()" class="bg-navy text-white px-4 py-2 rounded-lg text-sm font-semibold">🖨 Print / Save PDF</button>
            <button onclick="this.closest('.fixed').remove()" class="text-ink/60 text-xl px-2">×</button>
          </div>
        </div>
        <div id="receipt-print" class="flex-1 overflow-y-auto p-8 text-ink">${inner}</div>
      </div>`;
    document.body.appendChild(modal);
  }

  // Terus ke print/save PDF — render resit ke bekas tersembunyi & panggil window.print().
  // Print CSS (@media print) papar #receipt-print sahaja.
  async function printReceipt(id) {
    const r = (window._receipts || []).find(x => x.id === id);
    if (!r) return;
    const inner = await buildReceiptInner(r);
    // Cipta semula holder setiap kali (elak kandungan basi pada tekan berikutnya)
    const old = document.getElementById('print-holder');
    if (old) old.remove();
    const holder = document.createElement('div');
    holder.id = 'print-holder';
    holder.style.cssText = 'position:fixed;left:-9999px;top:0;width:800px;';
    holder.innerHTML = `<div id="receipt-print" class="p-8 text-ink bg-white">${inner}</div>`;
    document.body.appendChild(holder);
    document.body.classList.add('printing-receipt');
    const cleanup = () => {
      document.body.classList.remove('printing-receipt');
      const h = document.getElementById('print-holder');
      if (h) h.remove();
      window.removeEventListener('afterprint', cleanup);
    };
    window.addEventListener('afterprint', cleanup);
    window.print();
  }

  window.buildReceiptInner = buildReceiptInner;
  window.viewReceiptPDF = viewReceiptPDF;
  window.printReceipt = printReceipt;
})();
