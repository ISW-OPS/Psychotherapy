// ============================================================
// INVOIS BEKALAN PRODUK — psy_supply_invoices (database/schema/42_supply_invoices.sql)
// createSupplyInvoice() boleh dipanggil SELEPAS addStockToLocation() (shared/
// inventoryStock.js) berjaya (laluan NORMAL, tolak stok sebenar), ATAU terus tanpa
// addStockToLocation langsung (laluan SEJARAH/catch-up — markSupplyHistorical() di
// plan-week.html, pesakit lama yg data kertas baru dimasukkan, barang dah diberi
// fizikal lama dulu, elak tolak baki stok semasa). TIGA laluan panggil fungsi ni:
//   - roles/staff/patient-hub.html submitSupply()      (manual, "+ Bagi Bekalan")
//   - roles/staff/plan-week.html applySupplyStock()      (auto-deduct lepas Hadir)
//   - roles/staff/plan-week.html markSupplyHistorical()   (rekod sejarah, TIADA tolak stok)
//
// "Jumlah diberi setakat ini" dikira dari SNAPSHOT psy_supply_invoices terkini
// (bukan jumlah psy_stock_movements) — supaya kekal konsisten tak kira laluan mana
// yg cipta baris tu (ada/tiada movement sekali pun).
//
// Kekunci padanan "dirancang vs diberi" SAMA dgn KPI "Baki Bekalan" di
// patient-hub.html renderSupplyKpiAndItems() — nama+unit (bukan item_id, sbb
// entri coaching_schedule.supplies kadang tiada item_id yg konsisten). GOTCHA: kalau
// SATU item_id Inventori dirujuk guna BEBERAPA nama/unit berlainan merentas minggu/
// pakej (cth lepas konsolidasi semula Inventori — lihat
// project_inventory_seed_destructive_delete), baris2 tu akan dikira sbg "produk"
// berasingan di sini (key = text, bukan id) — jumlah/baki per produk boleh terpecah
// tak tepat. Belum dibetulkan (skop besar, perlu ubah kekunci ke item_id merentas
// fail ni + renderSupplyKpiAndItems() + invoice.js sekali).
// ============================================================

// givenItems: [{ item_id, name, unit, qty_given }]
// opts: { patientId (wajib), activePlan? (ada coaching_schedule, elak refetch),
//         planId?, weekNumber?, source: 'manual'|'auto_weekly', notes? }
// Return: baris psy_supply_invoices baru (ada invoice_no), atau null kalau gagal —
// gagal keluarkan invois TAK PATUT sekat/rollback bekalan yg dah direkod dlm ledger.
async function createSupplyInvoice(givenItems, opts) {
  try {
    const list = (givenItems || []).filter(g => g && g.name && Number(g.qty_given) > 0);
    if (!list.length || !opts?.patientId) return null;

    let plan = opts.activePlan || null;
    if (!plan?.coaching_schedule) {
      const { data: plans } = await window.db.from('psy_treatment_plans')
        .select('id, status, coaching_schedule').eq('patient_id', opts.patientId)
        .order('created_at', { ascending: false });
      plan = (plans || []).find(p => p.status === 'active') || (plans || [])[0] || null;
    }

    const key = (name, unit) => name + '|' + (unit || 'unit');

    const planned = {};
    (plan?.coaching_schedule || []).forEach(w => {
      [...(w.supplies || []), ...(w.supplies_2 || [])].forEach(s => {
        const name = s.item_name || s.name || (typeof s === 'string' ? s : null);
        if (!name) return;
        const k = key(name, s.item_unit || s.unit);
        planned[k] = (planned[k] || 0) + Number(s.qty || s.quantity || 0);
      });
    });

    // Kumulatif "diberi setakat ini" — dari SNAPSHOT psy_supply_invoices TERKINI
    // (baris psy_supply_invoices SEBELUM transaksi ni), bukan jumlah psy_stock_movements
    // terus. Supaya kekal betul walau ada campuran rekod sebenar (tolak stok) & rekod
    // sejarah/catch-up (tiada tolak stok — lihat markSupplyHistorical() di
    // plan-week.html, utk pesakit lama yg data kertas dimasukkan lewat) — rekod
    // sejarah ni TIADA baris psy_stock_movements, jadi asas lama (stock_movements)
    // akan senyap abaikan sumbangan dia.
    const { data: priorRows } = await window.db.from('psy_supply_invoices')
      .select('items').eq('patient_id', opts.patientId).order('created_at', { ascending: true });
    const givenCum = {};
    (priorRows || []).forEach(r => (Array.isArray(r.items) ? r.items : []).forEach(it => {
      givenCum[key(it.name, it.unit)] = Number(it.qty_given_cumulative || 0); // snapshot TERKINI, bukan tambah
    }));

    const items = list.map(g => {
      const k = key(g.name, g.unit);
      const plannedTotal = planned[k] || 0;
      const cumulative = (givenCum[k] || 0) + Number(g.qty_given);
      return {
        item_id: g.item_id || null, name: g.name, unit: g.unit || 'unit',
        qty_given: Number(g.qty_given),
        qty_planned_total: plannedTotal,
        qty_given_cumulative: cumulative,
        qty_remaining: Math.max(0, plannedTotal - cumulative),
      };
    });

    const { data: inserted, error } = await window.db.from('psy_supply_invoices').insert({
      patient_id: opts.patientId,
      plan_id: plan?.id || opts.planId || null,
      week_number: opts.weekNumber ?? null,
      source: opts.source || 'manual',
      items,
      given_by: window.currentUser?.id || null,
      given_by_name: window.currentUser?.full_name || null,
      notes: opts.notes || null,
    }).select().single();

    if (error) { console.warn('[supplyInvoice] gagal cipta invois:', error); return null; }

    // Pastikan header "Invois Bekalan Pakej" (nombor tetap seluruh pakej, lihat
    // 43_package_supply_invoices.sql) wujud dari transaksi PERTAMA — tak sekat/rollback
    // invois transaksi di atas kalau gagal (sama semangat dgn ralat insert di atas).
    if (plan?.id) {
      try { await getOrCreatePackageSupplyInvoiceNo(opts.patientId, plan.id); }
      catch (e) { console.warn('[supplyInvoice] gagal pastikan header invois pakej:', e); }
    }

    return inserted;
  } catch (e) {
    console.warn('[supplyInvoice] ralat:', e);
    return null;
  }
}
window.createSupplyInvoice = createSupplyInvoice;

// ── Invois Bekalan PAKEJ (header nombor tetap) ────────────────────────────
// Get-or-create: pulangkan baris psy_package_supply_invoices sedia ada untuk
// (patientId, planId), atau cipta baharu (trigger DB jana invoice_no). Idempoten
// — selamat dipanggil berulang kali (give-event baharu, atau bila staf/pesakit
// buka paparan invois). Lihat database/schema/43_package_supply_invoices.sql.
async function getOrCreatePackageSupplyInvoiceNo(patientId, planId) {
  if (!patientId || !planId) return null;
  const { data: existing } = await window.db.from('psy_package_supply_invoices')
    .select('*').eq('patient_id', patientId).eq('plan_id', planId).maybeSingle();
  if (existing) return existing;

  const { data: inserted, error } = await window.db.from('psy_package_supply_invoices')
    .insert({ patient_id: patientId, plan_id: planId }).select().single();
  if (!error) return inserted;

  // Race: tab/panggilan lain mungkin dah cipta serentak (UNIQUE patient_id+plan_id) — baca semula.
  const { data: retry } = await window.db.from('psy_package_supply_invoices')
    .select('*').eq('patient_id', patientId).eq('plan_id', planId).maybeSingle();
  if (!retry) console.warn('[supplyInvoice] gagal get-or-create header invois pakej:', error);
  return retry || null;
}
window.getOrCreatePackageSupplyInvoiceNo = getOrCreatePackageSupplyInvoiceNo;
