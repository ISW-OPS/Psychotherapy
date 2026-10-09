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

  // kind: 'plan' (lalai) = invois penuh — jadual semua bayaran (setakat asOfSeq kalau diberi);
  //        'installment' = invois tuntutan bayaran untuk SATU checkpoint (asOfSeq) sahaja.
  async function buildInvoiceInner(kobId, override, asOfSeq, kind) {
    const doc = D();
    if (!doc) throw new Error('shared/receipt.js belum dimuat / not loaded');
    const { esc, money, dateLong, header, TEAL, L } = doc;
    const cu = override ? { full_name: override.full_name } : (window.currentUser || {});
    const pr = override ? { phone: override.phone } : (window.patientRecord || {});

    const [{ data: kob }, { data: cps }, { data: pays }, { data: pending }] = await Promise.all([
      window.db.from('psy_kob_sessions')
        .select('recommended_package_id, recommended_package_name, recommended_package_price, package_discount, package_payment_mode, recommended_at, created_at, invoice_no')
        .eq('id', kobId).maybeSingle(),
      window.db.from('psy_kob_installment_checkpoints').select('seq, due_date, target_cumulative').eq('kob_session_id', kobId).order('seq'),
      window.db.from('psy_payments').select('total').eq('status', 'completed').eq('intent->>kob_session_id', kobId),
      window.db.from('psy_payments').select('checkout_url').eq('status', 'pending').not('checkout_url', 'is', null)
        .eq('intent->>kob_session_id', kobId).order('created_at', { ascending: false }).limit(1),
    ]);
    if (!kob) throw new Error(L('Sesi KOB tidak dijumpai', 'KOB session not found'));

    // Logo/gambar pakej (image_url ditetapkan di pakej-edit.html) — dipaparkan sebelah nama item.
    let pkgImageUrl = null;
    if (kob.recommended_package_id) {
      const { data: pkg } = await window.db.from('psy_packages').select('image_url')
        .eq('package_id', kob.recommended_package_id).maybeSingle();
      pkgImageUrl = pkg?.image_url || null;
    }
    const itemNameCell = (name) => pkgImageUrl
      ? `<div class="flex items-center gap-2"><img src="${esc(pkgImageUrl)}" class="w-8 h-8 rounded object-cover flex-shrink-0" onerror="this.remove()"><span>${esc(name)}</span></div>`
      : esc(name);

    const price = Number(kob.recommended_package_price || 0);
    const pkgDiscount = Number(kob.package_discount || 0);
    const isInstallment = kob.package_payment_mode === 'installment' && cps?.length;
    const owed = isInstallment ? Number(cps[cps.length - 1].target_cumulative) : price;
    const paidTotal = (pays || []).reduce((a, p) => a + Number(p.total || 0), 0);
    // Invois berubah bila tiap bayaran dibuat — asOfSeq = paparan setakat checkpoint itu
    // (bayaran selepasnya belum dikira); tanpa asOfSeq = keadaan semasa.
    const asOfCp = asOfSeq != null ? (cps || []).find(x => Number(x.seq) === Number(asOfSeq)) : null;
    const paid = asOfCp ? Math.min(paidTotal, Number(asOfCp.target_cumulative)) : paidTotal;
    const due = Math.max(0, owed - paid);
    // Pakej ansuran ada Harga Installment (Full) sendiri (boleh > harga tunai) — itulah harga item di invois.
    const listPrice = owed + pkgDiscount;
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
    const payUrl = pending?.[0]?.checkout_url;

    // ── Invois ANSURAN: tuntutan bayaran bulan/checkpoint itu sahaja ──
    if (kind === 'installment' && isInstallment && asOfCp) {
      const idx = cps.findIndex(x => Number(x.seq) === Number(asOfCp.seq));
      const prevTarget = idx > 0 ? Number(cps[idx - 1].target_cumulative) : 0;
      const amount = Number(asOfCp.target_cumulative) - prevTarget;
      const paidThis = Math.min(amount, Math.max(0, paidTotal - prevTarget));
      const dueThis = Math.max(0, amount - paidThis);
      const label = Number(asOfCp.seq) === 0 ? L('Deposit', 'Deposit') : `${L('Ansuran', 'Installment')} ${asOfCp.seq}`;
      const issueI = idx === 0 ? issue : cps[idx - 1].due_date;
      const thTh = 'text-[11px] font-medium uppercase tracking-wide text-ink/70 py-3';
      const payBtnI = dueThis > 0.005 && payUrl
        ? `<a href="${esc(payUrl)}" target="_blank" class="no-print inline-block bg-green-dark text-white text-xs font-semibold px-6 py-2 rounded-md hover:opacity-90">${L('Bayar', 'Pay')} ${money(dueThis)}</a>`
        : (dueThis <= 0.005 ? `<span class="inline-block text-xs font-semibold px-5 py-1.5 rounded-md border border-green text-green-dark bg-green-light/60">${L('Telah Dibayar', 'Paid')}</span>` : '');
      return `
        ${header(L('INVOIS', 'INVOICE'))}

        <div class="border-t border-ink/10 mt-6 pt-5 grid grid-cols-2 md:grid-cols-4 gap-6 text-sm">
          <div>
            <div class="font-semibold text-ink">${L('Dibilkan kepada', 'Billed to')}</div>
            <div class="text-ink/60 text-xs mt-2 leading-relaxed">${esc(cu.full_name || '—')}<br>${esc(pr.phone || '—')}<br>Malaysia</div>
          </div>
          <div><div class="font-semibold text-ink">${L('No. Invois', 'Invoice Number')}</div><div class="text-ink/60 text-xs mt-2">${esc(kob.invoice_no ? `${kob.invoice_no}-${idx + 1}` : '—')}</div></div>
          <div class="space-y-3">
            <div><div class="font-semibold text-ink">${L('Tarikh Dikeluarkan', 'Issue Date')}</div><div class="text-ink/60 text-xs mt-1">${dateLong(issueI)}</div></div>
            <div><div class="font-semibold text-ink">${L('Tarikh Akhir Bayaran', 'Due Date')}</div><div class="text-ink/60 text-xs mt-1">${dateLong(asOfCp.due_date)}</div></div>
          </div>
          <div class="text-right">${payBtnI}</div>
        </div>

        <table class="w-full mt-10 text-sm">
          <thead>
            <tr style="border-bottom:2px solid ${TEAL}">
              <th class="${thTh} text-left px-1">${L('Nama Item', 'Item Name')}</th>
              <th class="${thTh} text-right">${L('Harga', 'Price')}</th>
              <th class="${thTh} text-right w-16">${L('Kuantiti', 'Quantity')}</th>
              <th class="${thTh} text-right w-16">${L('Cukai', 'Tax')}</th>
              <th class="${thTh} text-right px-1">${L('Jumlah Kecil', 'Subtotal')}</th>
            </tr>
          </thead>
          <tbody>
            <tr class="border-b border-ink/10">
              <td class="py-4 px-1 text-xs text-ink/70 uppercase">${itemNameCell(kob.recommended_package_name || L('Pakej', 'Package'))}</td>
              <td class="py-4 text-xs text-ink/70 text-right whitespace-nowrap">${money(listPrice)}</td>
              <td class="py-4 text-xs text-ink/70 text-right">1</td>
              <td class="py-4 text-xs text-ink/70 text-right">-</td>
              <td class="py-4 px-1 text-xs text-ink/70 text-right whitespace-nowrap">${money(listPrice)}</td>
            </tr>
          </tbody>
        </table>

        <div class="flex justify-end mt-4">
          <div class="w-full max-w-xs text-sm">
            <div class="flex justify-between py-1"><span class="font-semibold text-ink">${L('Jumlah Kecil', 'Subtotal')}</span><span class="text-ink/60 text-xs">${money(listPrice)}</span></div>
            <div class="flex justify-between py-1"><span class="font-semibold text-ink">${L('Diskaun', 'Discount')}</span><span class="text-ink/60 text-xs">-${money(pkgDiscount)}</span></div>
            <div class="flex justify-between items-start py-2.5 mt-1 border-t border-ink/20">
              <span class="font-bold text-ink">${L('Baki Perlu Dibayar (MYR)', 'Amount Due (MYR)')}<span class="block text-[10px] font-normal text-ink/50 mt-0.5">${esc(label)} · ${idx + 1} ${L('daripada', 'of')} ${cps.length}</span></span>
              <span class="font-bold text-ink">${money(dueThis)}</span>
            </div>
          </div>
        </div>`;
    }
    const th = 'text-[11px] font-medium uppercase tracking-wide text-ink/70 py-3';
    const badge = (isPaid) => isPaid
      ? `<span class="inline-block text-[10px] font-semibold px-3 py-0.5 rounded-full border border-green text-green-dark bg-green-light/60 w-16 text-center">${L('Dibayar', 'Paid')}</span>`
      : `<span class="inline-block text-[10px] font-semibold px-3 py-0.5 rounded-full border border-gold text-gold-dark bg-gold/15 w-16 text-center">${L('Belum Dibayar', 'Pending')}</span>`;

    const payBtn = due > 0 && payUrl
      ? `<a href="${esc(payUrl)}" target="_blank" class="no-print inline-block bg-green-dark text-white text-xs font-semibold px-6 py-2 rounded-md hover:opacity-90">${L('Bayar', 'Pay')} ${money(due)}</a>`
      : '';

    return `
      ${header(L('INVOIS', 'INVOICE'))}

      <div class="border-t border-ink/10 mt-6 pt-5 grid grid-cols-2 md:grid-cols-4 gap-6 text-sm">
        <div>
          <div class="font-semibold text-ink">${L('Dibilkan kepada', 'Billed to')}</div>
          <div class="text-ink/60 text-xs mt-2 leading-relaxed">${esc(cu.full_name || '—')}<br>${esc(pr.phone || '—')}<br>Malaysia</div>
        </div>
        <div><div class="font-semibold text-ink">${L('No. Invois', 'Invoice Number')}</div><div class="text-ink/60 text-xs mt-2">${esc(kob.invoice_no || '—')}</div></div>
        <div class="space-y-3">
          <div><div class="font-semibold text-ink">${L('Tarikh Dikeluarkan', 'Issue Date')}</div><div class="text-ink/60 text-xs mt-1">${dateLong(issue)}</div></div>
          <div><div class="font-semibold text-ink">${L('Tarikh Akhir Bayaran', 'Due Date')}</div><div class="text-ink/60 text-xs mt-1">${dateLong(dueDate)}</div></div>
        </div>
        <div class="text-right">${payBtn}</div>
      </div>

      <table class="w-full mt-10 text-sm">
        <thead>
          <tr style="background:${TEAL}">
            <th class="${th} text-left px-3 text-white">${L('Nama Item', 'Item Name')}</th>
            <th class="${th} text-right text-white">${L('Harga', 'Price')}</th>
            <th class="${th} text-right w-16 text-white">${L('Kuantiti', 'Quantity')}</th>
            <th class="${th} text-right w-16 text-white">${L('Cukai', 'Tax')}</th>
            <th class="${th} text-right px-3 text-white">${L('Jumlah Kecil', 'Subtotal')}</th>
          </tr>
        </thead>
        <tbody>
          <tr class="border-b border-ink/10">
            <td class="py-4 px-3 text-xs text-ink/70 uppercase">${itemNameCell(kob.recommended_package_name || L('Pakej', 'Package'))}</td>
            <td class="py-4 text-xs text-ink/70 text-right whitespace-nowrap">${money(listPrice)}</td>
            <td class="py-4 text-xs text-ink/70 text-right">1</td>
            <td class="py-4 text-xs text-ink/70 text-right">-</td>
            <td class="py-4 px-3 text-xs text-ink/70 text-right whitespace-nowrap">${money(listPrice)}</td>
          </tr>
        </tbody>
      </table>

      <div class="flex justify-end mt-4">
        <div class="w-full max-w-sm text-sm">
          <div class="flex justify-between py-1"><span class="font-semibold text-ink">${L('Jumlah Kecil', 'Subtotal')}</span><span class="text-ink/60 text-xs">${money(listPrice)}</span></div>
          <div class="flex justify-between py-1"><span class="font-semibold text-ink">${L('Diskaun', 'Discount')}</span><span class="text-ink/60 text-xs">-${money(pkgDiscount)}</span></div>
          <div class="flex justify-between py-1.5 border-t border-ink/20 mt-1"><span class="font-semibold text-ink">${L('Jumlah (MYR)', 'Total (MYR)')}</span><span class="text-ink/60 text-xs">${money(owed)}</span></div>
          <div class="flex justify-between py-1"><span class="font-semibold text-ink">${L('Jumlah Dibayar (MYR)', 'Amount Paid (MYR)')}</span><span class="text-ink/60 text-xs">${money(paid)}</span></div>
          <div class="mt-2 border-t border-ink/20 pt-2 space-y-1.5">
            ${rows.map((r, i) => `<div class="flex items-center justify-between gap-3 text-xs">
              <span class="text-ink/70 w-28">${L('Bayaran', 'Payment')} ${i + 1} ${L('daripada', 'of')} ${rows.length}</span>
              ${badge(r.paid)}
              <span class="text-ink/60">${L('Akhir', 'Due')} ${dateLong(r.due)}</span>
              <span class="text-ink/70 w-24 text-right">${money(r.amount)}</span>
            </div>`).join('')}
          </div>
          <div class="flex justify-between py-2.5 mt-2 border-t border-ink/20"><span class="font-bold text-ink">${L('Baki Perlu Dibayar (MYR)', 'Amount Due (MYR)')}</span><span class="font-bold text-ink">${money(due)}</span></div>
        </div>
      </div>`;
  }

  // Invois untuk satu bayaran BUKAN pakej KOB (kedai, sambungan minggu, dll) — dibina dari baris
  // psy_payments: item, diskaun (kod promo / baucar), jumlah; Paid bila 'completed', Pay bila 'pending'.
  async function buildPaymentInvoiceInner(pay, override) {
    const doc = D();
    if (!doc) throw new Error('shared/receipt.js belum dimuat / not loaded');
    const { esc, money, dateLong, header, TEAL, L, method } = doc;
    const cu = override ? { full_name: override.full_name } : (window.currentUser || {});
    const pr = override ? { phone: override.phone, mrn: override.mrn } : (window.patientRecord || {});
    const total = Number(pay.total || 0);
    const [items, discLines, kb, supplies] = await Promise.all([
      doc.resolveItems(pay), doc.resolveDiscounts(pay), doc.resolveKobBreakdown(pay), resolvePackageSupplies(pay),
    ]);
    const disc = Math.max(Number(pay.discount || 0), discLines.reduce((a, l) => a + l.amount, 0));
    const isPaid = pay.status === 'completed';
    const th = 'text-[11px] font-medium uppercase tracking-wide text-ink/70 py-3';
    const dueAmt = pay.status === 'pending' ? total : 0;
    const pill = (cls, txt) => `<span class="inline-block text-xs font-semibold px-5 py-1.5 rounded-md border ${cls}">${txt}</span>`;
    const action = pay.status === 'pending' && pay.checkout_url
      ? `<a href="${esc(pay.checkout_url)}" target="_blank" class="no-print inline-block bg-green-dark text-white text-xs font-semibold px-6 py-2 rounded-md hover:opacity-90">${L('Bayar', 'Pay')} ${money(total)}</a>`
      : (isPaid ? pill('border-green text-green-dark bg-green-light/60', L('Telah Dibayar', 'Paid'))
        : pay.status === 'refunded' ? pill('border-gold text-gold-dark bg-gold/15', L('Dipulangkan', 'Refunded'))
        : pay.status === 'failed' ? pill('border-terracotta text-terracotta bg-terracotta/10', L('Gagal', 'Failed')) : '');
    const issue = pay.created_at || pay.paid_at;
    return `
      ${header(L('INVOIS', 'INVOICE'))}

      <div class="border-t border-ink/10 mt-6 pt-5 grid grid-cols-2 md:grid-cols-4 gap-6 text-sm">
        <div>
          <div class="font-semibold text-ink">${L('Dibilkan kepada', 'Billed to')}</div>
          <div class="text-ink/60 text-xs mt-2 leading-relaxed">${esc(cu.full_name || '—')}<br>${pr.mrn ? `MRN: ${esc(pr.mrn)}<br>` : ''}${esc(pr.phone || '—')}<br>Malaysia</div>
        </div>
        <div><div class="font-semibold text-ink">${L('No. Invois', 'Invoice Number')}</div><div class="text-ink/60 text-xs mt-2">${esc(pay.invoice_no || pay.invoice_number || pay.receipt_ref || '—')}</div></div>
        <div class="space-y-3">
          <div><div class="font-semibold text-ink">${L('Tarikh Dikeluarkan', 'Issue Date')}</div><div class="text-ink/60 text-xs mt-1">${dateLong(issue)}</div></div>
          <div><div class="font-semibold text-ink">${L('Tarikh Akhir Bayaran', 'Due Date')}</div><div class="text-ink/60 text-xs mt-1">${dateLong(issue)}</div></div>
        </div>
        <div class="text-right space-y-2">
          ${method(pay) ? `<div class="text-xs text-ink/60">${L('Kaedah Bayaran', 'Payment Method')}: ${esc(method(pay))}</div>` : ''}
          ${pay.receipt_ref ? `<div class="text-xs text-ink/45">${L('Rujukan', 'Reference')}: ${esc(pay.receipt_ref)}</div>` : ''}
          ${action}
        </div>
      </div>

      <table class="w-full mt-10 text-sm">
        <thead>
          <tr style="border-bottom:2px solid ${TEAL}">
            <th class="${th} text-left px-1">${L('Nama Item', 'Item Name')}</th>
            <th class="${th} text-right">${L('Harga', 'Price')}</th>
            <th class="${th} text-right w-16">${L('Kuantiti', 'Quantity')}</th>
            <th class="${th} text-right w-16">${L('Cukai', 'Tax')}</th>
            <th class="${th} text-right px-1">${L('Jumlah Kecil', 'Subtotal')}</th>
          </tr>
        </thead>
        <tbody>
          ${items.map(it => `<tr class="border-b border-ink/10">
            <td class="py-4 px-1 text-xs text-ink/70 uppercase">${esc(it.name)}</td>
            <td class="py-4 text-xs text-ink/70 text-right whitespace-nowrap">${money(it.price)}</td>
            <td class="py-4 text-xs text-ink/70 text-right">1</td>
            <td class="py-4 text-xs text-ink/70 text-right">-</td>
            <td class="py-4 px-1 text-xs text-ink/70 text-right whitespace-nowrap">${money(it.price)}</td>
          </tr>`).join('')}
        </tbody>
      </table>

      <div class="flex justify-end mt-4">
        <div class="w-full max-w-xs text-sm">
          <div class="flex justify-between py-1"><span class="font-semibold text-ink">${L('Jumlah Kecil', 'Subtotal')}</span><span class="text-ink/60 text-xs">${money(total + disc)}</span></div>
          ${(discLines.length ? discLines : [{ label: L('Diskaun', 'Discount'), amount: 0 }]).map(l =>
            `<div class="flex justify-between py-1"><span class="font-semibold text-ink">${esc(l.label)}</span><span class="text-ink/60 text-xs">-${money(l.amount)}</span></div>`).join('')}
          <div class="flex justify-between py-2.5 mt-1 border-t border-ink/20"><span class="font-bold text-ink">${L('Baki Perlu Dibayar (MYR)', 'Amount Due (MYR)')}</span><span class="font-bold text-ink">${money(dueAmt)}</span></div>
        </div>
      </div>

      ${kb ? `
      <div class="mt-8 border-t border-ink/10 pt-5">
        <div class="text-[11px] font-medium uppercase tracking-wide text-ink/70 mb-2">${L('Pecahan Bayaran', 'Payment Breakdown')}${kb.invoiceNo ? ` <span class="normal-case text-ink/40">· ${L('Invois', 'Invoice')} ${esc(kb.invoiceNo)}</span>` : ''}</div>
        <div class="max-w-sm ml-auto text-sm">
          ${kb.pkgDiscount > 0 ? `<div class="flex justify-between py-1"><span class="text-ink/70">${L('Harga Pakej', 'Package Price')}</span><span class="text-ink/60 text-xs">${money(kb.listPrice)}</span></div>
          <div class="flex justify-between py-1"><span class="text-ink/70">${L('Diskaun', 'Discount')}</span><span class="text-ink/60 text-xs">-${money(kb.pkgDiscount)}</span></div>` : ''}
          <div class="flex justify-between py-1.5 border-t border-ink/10 mt-1"><span class="font-semibold text-ink">${L('Jumlah Pakej', 'Package Total')}</span><span class="font-semibold text-ink">${money(kb.owed)}</span></div>
          <div class="flex justify-between py-1"><span class="text-ink/70">${L('Dibayar pada invois ini', 'Paid on this invoice')} (${esc(kb.thisLabel)})</span><span class="text-ink/60 text-xs">${money(total)}</span></div>
          <div class="flex justify-between py-1"><span class="text-ink/70">${L('Jumlah Dibayar Setakat Ini', 'Total Paid to Date')}</span><span class="text-ink/60 text-xs">${money(kb.paidToDate)}</span></div>
          <div class="flex justify-between py-2 border-t border-ink/20 mt-1"><span class="font-bold text-ink">${L('Baki Perlu Dibayar', 'Balance Remaining')}</span><span class="font-bold text-ink">${money(kb.outstanding)}</span></div>
        </div>
      </div>` : ''}

      ${supplies?.length ? `
      <div class="mt-6 border-t border-ink/10 pt-5">
        <div class="text-[11px] font-medium uppercase tracking-wide text-ink/70 mb-2">${L('Kandungan Pakej (Bekalan)', 'Package Contents (Supplies)')}</div>
        <ul class="text-xs text-ink/70 space-y-1 list-disc pl-4">
          ${supplies.map(s => `<li>${esc(s.name)}${s.qty ? ` × ${esc(String(s.qty))}` : ''}</li>`).join('')}
        </ul>
      </div>` : ''}`;
  }

  // Senarai bekalan/stok keseluruhan pakej (psy_packages.supplies) — utk invois pakej
  // KOB sahaja. Bukan pengiraan refund — sekadar rujukan kandungan pakej pada invois.
  async function resolvePackageSupplies(pay) {
    const kobId = pay.intent?.kob_session_id;
    if (!kobId || !window.db) return null;
    try {
      const { data: kob } = await window.db.from('psy_kob_sessions').select('recommended_package_id').eq('id', kobId).maybeSingle();
      if (!kob?.recommended_package_id) return null;
      const { data: pkg } = await window.db.from('psy_packages').select('supplies').eq('package_id', kob.recommended_package_id).maybeSingle();
      const list = Array.isArray(pkg?.supplies) ? pkg.supplies.filter(s => s?.name) : [];
      return list.length ? list : null;
    } catch (_) { return null; }
  }

  async function viewPaymentInvoice(pay, override) {
    const L = (window.iswDoc && window.iswDoc.L) || ((ms, en) => en);
    let inner;
    try { inner = await buildPaymentInvoiceInner(pay, override); }
    catch (e) { alert(L('Gagal muat invois: ', 'Failed to load invoice: ') + e.message); return; }
    showInvoiceModal(inner);
  }

  function showInvoiceModal(inner) {
    const L = (window.iswDoc && window.iswDoc.L) || ((ms, en) => en);
    document.getElementById('invoice-modal')?.remove();
    const modal = document.createElement('div');
    modal.id = 'invoice-modal';
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center p-4';
    modal.innerHTML = `
      <div class="absolute inset-0 bg-black/50" onclick="this.parentElement.remove()"></div>
      <div class="relative bg-white rounded-2xl max-w-3xl w-full max-h-[92vh] overflow-hidden flex flex-col">
        <div class="p-4 border-b border-ink/10 flex items-center justify-between">
          <h3 class="font-bold">${L('Invois', 'Invoice')}</h3>
          <div class="flex gap-2">
            <button type="button" id="invoice-print-btn" class="bg-navy text-white px-4 py-2 rounded-lg text-sm font-semibold">🖨 ${L('Cetak / Simpan PDF', 'Print / Save PDF')}</button>
            <button type="button" id="invoice-close-btn" class="text-ink/60 text-xl px-2" aria-label="Close">×</button>
          </div>
        </div>
        <div id="invoice-print" class="flex-1 overflow-y-auto p-8 text-ink">${inner}</div>
      </div>`;
    document.body.appendChild(modal);
    const closeModal = () => { modal.remove(); document.removeEventListener('keydown', onKey); };
    const onKey = (e) => { if (e.key === 'Escape') closeModal(); };
    document.addEventListener('keydown', onKey);
    document.getElementById('invoice-close-btn').onclick = closeModal;
    modal.firstElementChild.onclick = closeModal;
    document.getElementById('invoice-print-btn').onclick = () => window.iswDoc.printHtml(inner, 'Invoice');
  }

  async function viewInvoice(kobId, override, asOfSeq, kind) {
    const L = (window.iswDoc && window.iswDoc.L) || ((ms, en) => en);
    let inner;
    try { inner = await buildInvoiceInner(kobId, override, asOfSeq, kind); }
    catch (e) { alert(L('Gagal muat invois: ', 'Failed to load invoice: ') + e.message); return; }
    showInvoiceModal(inner);
  }

  // ── Invois Bekalan Produk (bukan duit) ────────────────────────────────────
  // Snapshot kuantiti diberi + baki pakej dari psy_supply_invoices (lihat
  // database/schema/42_supply_invoices.sql, shared/supplyInvoice.js). Guna
  // helper dokumen (window.iswDoc) sama dgn invois/resit pembayaran, tapi
  // tanpa harga/subtotal — ini bukan transaksi duit.
  async function buildSupplyInvoiceInner(inv, override) {
    const doc = D();
    if (!doc) throw new Error('shared/receipt.js belum dimuat / not loaded');
    const { esc, dateLong, header, TEAL, L } = doc;
    const cu = override ? { full_name: override.full_name } : (window.currentUser || {});
    const pr = override ? { phone: override.phone, mrn: override.mrn } : (window.patientRecord || {});
    const items = Array.isArray(inv.items) ? inv.items : [];
    const th = 'text-[11px] font-medium uppercase tracking-wide text-ink/70 py-3';

    return `
      ${header(L('INVOIS BEKALAN', 'SUPPLY INVOICE'))}

      <div class="border-t border-ink/10 mt-6 pt-5 grid grid-cols-2 md:grid-cols-3 gap-6 text-sm">
        <div>
          <div class="font-semibold text-ink">${L('Diberikan kepada', 'Issued to')}</div>
          <div class="text-ink/60 text-xs mt-2 leading-relaxed">${esc(cu.full_name || '—')}<br>${pr.mrn ? `MRN: ${esc(pr.mrn)}<br>` : ''}${esc(pr.phone || '—')}</div>
        </div>
        <div><div class="font-semibold text-ink">${L('No. Invois', 'Invoice Number')}</div><div class="text-ink/60 text-xs mt-2">${esc(inv.invoice_no || '—')}</div></div>
        <div>
          <div class="font-semibold text-ink">${L('Tarikh', 'Date')}</div><div class="text-ink/60 text-xs mt-1">${dateLong(inv.created_at)}</div>
          <div class="font-semibold text-ink mt-3">${L('Diberi oleh', 'Issued by')}</div><div class="text-ink/60 text-xs mt-1">${esc(inv.given_by_name || '—')}</div>
        </div>
      </div>

      <table class="w-full mt-10 text-sm">
        <thead>
          <tr style="background:${TEAL}">
            <th class="${th} text-left px-3 text-white">${L('Nama Produk', 'Product Name')}</th>
            <th class="${th} text-right text-white">${L('Diberi Hari Ini', 'Given Today')}</th>
            <th class="${th} text-right text-white">${L('Jumlah Pakej', 'Package Total')}</th>
            <th class="${th} text-right px-3 text-white">${L('Baki Selepas Ini', 'Remaining After This')}</th>
          </tr>
        </thead>
        <tbody>
          ${items.map(it => `<tr class="border-b border-ink/10">
            <td class="py-4 px-3 text-xs text-ink/70 uppercase">${esc(it.name)}</td>
            <td class="py-4 text-xs text-ink/70 text-right whitespace-nowrap">${esc(String(it.qty_given))} ${esc(it.unit || '')}</td>
            <td class="py-4 text-xs text-ink/70 text-right whitespace-nowrap">${esc(String(it.qty_planned_total))} ${esc(it.unit || '')}</td>
            <td class="py-4 px-3 text-xs font-bold text-ink text-right whitespace-nowrap">${esc(String(it.qty_remaining))} ${esc(it.unit || '')}</td>
          </tr>`).join('')}
        </tbody>
      </table>

      ${inv.notes ? `<div class="mt-4 text-xs text-ink/60 italic">${esc(inv.notes)}</div>` : ''}

      <div class="mt-auto pt-8 text-[11px] text-ink/50 text-center leading-relaxed">
        ${L('Invois ini merekodkan produk/bekalan yang diberikan sebagai sebahagian daripada pakej rawatan anda. Sila simpan untuk rujukan.', 'This invoice records products/supplies issued as part of your treatment package. Please keep for your reference.')}
      </div>`;
  }

  async function viewSupplyInvoice(inv, override) {
    const L = (window.iswDoc && window.iswDoc.L) || ((ms, en) => en);
    let inner;
    try { inner = await buildSupplyInvoiceInner(inv, override); }
    catch (e) { alert(L('Gagal muat invois: ', 'Failed to load invoice: ') + e.message); return; }
    showInvoiceModal(inner);
  }

  window.buildInvoiceInner = buildInvoiceInner;
  window.viewInvoice = viewInvoice;
  window.buildPaymentInvoiceInner = buildPaymentInvoiceInner;
  window.viewPaymentInvoice = viewPaymentInvoice;
  window.buildSupplyInvoiceInner = buildSupplyInvoiceInner;
  window.viewSupplyInvoice = viewSupplyInvoice;
})();
