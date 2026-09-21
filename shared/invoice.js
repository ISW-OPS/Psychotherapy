// ── Invois Pakej (KOB) ─────────────────────────────────────────────────────────
// Format ikut rujukan GHL: tajuk INVOICE, Billed to, Invoice Number, Issue/Due Date,
// jadual item, Subtotal/Discount/Total/Amount Paid, jadual "Payment k of n" (Paid/Pending)
// dan Amount Due. Bergantung pada shared/receipt.js (window.iswDoc) — muat receipt.js dahulu.
//
//   buildInvoiceInner(kobSessionId, override?) → Promise<string>
//   viewInvoice(kobSessionId, override?)        → modal + Print / Save PDF
// `override` = {full_name, phone} — laluan staff (tiada window.currentUser pesakit).

(function () {
  const D = () => window.iswDoc;

  async function buildInvoiceInner(kobId, override) {
    const doc = D();
    if (!doc) throw new Error('shared/receipt.js belum dimuat');
    const { esc, money, dateLong, header, TEAL } = doc;
    const cu = override ? { full_name: override.full_name } : (window.currentUser || {});
    const pr = override ? { phone: override.phone } : (window.patientRecord || {});

    const [{ data: kob }, { data: cps }, { data: pays }, { data: pending }] = await Promise.all([
      window.db.from('psy_kob_sessions')
        .select('recommended_package_name, recommended_package_price, package_discount, package_payment_mode, recommended_at, created_at, invoice_no')
        .eq('id', kobId).maybeSingle(),
      window.db.from('psy_kob_installment_checkpoints').select('seq, due_date, target_cumulative').eq('kob_session_id', kobId).order('seq'),
      window.db.from('psy_payments').select('total').eq('status', 'completed').eq('intent->>kob_session_id', kobId),
      window.db.from('psy_payments').select('checkout_url').eq('status', 'pending').not('checkout_url', 'is', null)
        .eq('intent->>kob_session_id', kobId).order('created_at', { ascending: false }).limit(1),
    ]);
    if (!kob) throw new Error('Sesi KOB tidak dijumpai');

    const price = Number(kob.recommended_package_price || 0);
    const pkgDiscount = Number(kob.package_discount || 0);
    const isInstallment = kob.package_payment_mode === 'installment' && cps?.length;
    const owed = isInstallment ? Number(cps[cps.length - 1].target_cumulative) : price;
    const paid = (pays || []).reduce((a, p) => a + Number(p.total || 0), 0);
    const due = Math.max(0, owed - paid);
    const issue = kob.recommended_at || kob.created_at;

    // Jadual bayaran: satu baris per checkpoint (amaun = beza sasaran terkumpul), atau satu baris (bayaran penuh)
    let rows;
    if (isInstallment) {
      let prev = 0;
      rows = cps.map(cp => {
        const amt = Number(cp.target_cumulative) - prev;
        prev = Number(cp.target_cumulative);
        return { due: cp.due_date, amount: amt, paid: paid >= Number(cp.target_cumulative) - 0.005 };
      });
    } else {
      rows = [{ due: issue, amount: price, paid: paid >= price - 0.005 }];
    }
    const dueDate = rows[rows.length - 1].due || issue;
    const th = 'text-[11px] font-medium uppercase tracking-wide text-ink/70 py-3';
    const badge = (isPaid) => isPaid
      ? '<span class="inline-block text-[10px] font-semibold px-3 py-0.5 rounded-full border border-green text-green-dark bg-green-light/60 w-14 text-center">Paid</span>'
      : '<span class="inline-block text-[10px] font-semibold px-3 py-0.5 rounded-full border border-gold text-gold-dark bg-gold/15 w-14 text-center">Pending</span>';

    const payUrl = pending?.[0]?.checkout_url;
    const payBtn = due > 0 && payUrl
      ? `<a href="${esc(payUrl)}" target="_blank" class="no-print inline-block bg-green-dark text-white text-xs font-semibold px-6 py-2 rounded-md hover:opacity-90">Pay ${money(due)}</a>`
      : '';

    return `
      ${header('INVOICE')}

      <div class="border-t border-ink/10 mt-6 pt-5 grid grid-cols-2 md:grid-cols-4 gap-6 text-sm">
        <div>
          <div class="font-semibold text-ink">Billed to</div>
          <div class="text-ink/60 text-xs mt-2 leading-relaxed">${esc(cu.full_name || '—')}<br>${esc(pr.phone || '—')}<br>Malaysia</div>
        </div>
        <div><div class="font-semibold text-ink">Invoice Number</div><div class="text-ink/60 text-xs mt-2">${esc(kob.invoice_no || '—')}</div></div>
        <div class="space-y-3">
          <div><div class="font-semibold text-ink">Issue Date</div><div class="text-ink/60 text-xs mt-1">${dateLong(issue)}</div></div>
          <div><div class="font-semibold text-ink">Due Date</div><div class="text-ink/60 text-xs mt-1">${dateLong(dueDate)}</div></div>
        </div>
        <div class="text-right">${payBtn}</div>
      </div>

      <table class="w-full mt-10 text-sm">
        <thead>
          <tr style="background:${TEAL}">
            <th class="${th} text-left px-3 text-white">Item Name</th>
            <th class="${th} text-right text-white">Price</th>
            <th class="${th} text-right w-16 text-white">Quantity</th>
            <th class="${th} text-right w-16 text-white">Tax</th>
            <th class="${th} text-right px-3 text-white">Subtotal</th>
          </tr>
        </thead>
        <tbody>
          <tr class="border-b border-ink/10">
            <td class="py-4 px-3 text-xs text-ink/70 uppercase">${esc(kob.recommended_package_name || 'Pakej')}</td>
            <td class="py-4 text-xs text-ink/70 text-right whitespace-nowrap">${money(price + pkgDiscount)}</td>
            <td class="py-4 text-xs text-ink/70 text-right">1</td>
            <td class="py-4 text-xs text-ink/70 text-right">-</td>
            <td class="py-4 px-3 text-xs text-ink/70 text-right whitespace-nowrap">${money(price + pkgDiscount)}</td>
          </tr>
        </tbody>
      </table>

      <div class="flex justify-end mt-4">
        <div class="w-full max-w-sm text-sm">
          <div class="flex justify-between py-1"><span class="font-semibold text-ink">Subtotal</span><span class="text-ink/60 text-xs">${money(price + pkgDiscount)}</span></div>
          <div class="flex justify-between py-1"><span class="font-semibold text-ink">Discount</span><span class="text-ink/60 text-xs">-${money(pkgDiscount)}</span></div>
          ${owed > price ? `<div class="flex justify-between py-1"><span class="font-semibold text-ink">Installment Charges</span><span class="text-ink/60 text-xs">${money(owed - price)}</span></div>` : ''}
          <div class="flex justify-between py-1.5 border-t border-ink/20 mt-1"><span class="font-semibold text-ink">Total (MYR)</span><span class="text-ink/60 text-xs">${money(owed)}</span></div>
          <div class="flex justify-between py-1"><span class="font-semibold text-ink">Amount Paid (MYR)</span><span class="text-ink/60 text-xs">${money(paid)}</span></div>
          <div class="mt-2 border-t border-ink/20 pt-2 space-y-1.5">
            ${rows.map((r, i) => `<div class="flex items-center justify-between gap-3 text-xs">
              <span class="text-ink/70 w-24">Payment ${i + 1} of ${rows.length}</span>
              ${badge(r.paid)}
              <span class="text-ink/60">Due ${dateLong(r.due)}</span>
              <span class="text-ink/70 w-24 text-right">${money(r.amount)}</span>
            </div>`).join('')}
          </div>
          <div class="flex justify-between py-2.5 mt-2 border-t border-ink/20"><span class="font-bold text-ink">Amount Due (MYR)</span><span class="font-bold text-ink">${money(due)}</span></div>
        </div>
      </div>`;
  }

  async function viewInvoice(kobId, override) {
    let inner;
    try { inner = await buildInvoiceInner(kobId, override); }
    catch (e) { alert('Gagal muat invois: ' + e.message); return; }
    document.getElementById('invoice-modal')?.remove();
    const modal = document.createElement('div');
    modal.id = 'invoice-modal';
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center p-4';
    modal.innerHTML = `
      <div class="absolute inset-0 bg-black/50" onclick="this.parentElement.remove()"></div>
      <div class="relative bg-white rounded-2xl max-w-3xl w-full max-h-[92vh] overflow-hidden flex flex-col">
        <div class="p-4 border-b border-ink/10 flex items-center justify-between">
          <h3 class="font-bold">Invois</h3>
          <div class="flex gap-2">
            <button type="button" id="invoice-print-btn" class="bg-navy text-white px-4 py-2 rounded-lg text-sm font-semibold">🖨 Print / Save PDF</button>
            <button type="button" onclick="this.closest('.fixed').remove()" class="text-ink/60 text-xl px-2">×</button>
          </div>
        </div>
        <div id="invoice-print" class="flex-1 overflow-y-auto p-8 text-ink">${inner}</div>
      </div>`;
    document.body.appendChild(modal);
    document.getElementById('invoice-print-btn').onclick = () => {
      // Tetingkap berasingan — elak bergantung pada CSS cetak halaman induk.
      const w = window.open('', '_blank');
      if (!w) { alert('Benarkan pop-up untuk cetak invois.'); return; }
      w.document.write(`<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Invoice</title>
        <script src="https://cdn.tailwindcss.com"><\/script>
        <script>tailwind.config = { theme: { extend: { colors: { ink: '#1a1a1a', navy: '#1B2A4A', green: { DEFAULT: '#2F6B3F', dark: '#245532', light: '#E6F1E9' }, gold: { DEFAULT: '#C9A227', dark: '#8A6D12' } } } } }<\/script>
        </head><body class="p-10 text-ink bg-white">${document.getElementById('invoice-print').innerHTML}
        <style>.no-print{display:none!important}</style>
        <script>window.onload = () => setTimeout(() => window.print(), 600)<\/script></body></html>`);
      w.document.close();
    };
  }

  window.buildInvoiceInner = buildInvoiceInner;
  window.viewInvoice = viewInvoice;
})();
