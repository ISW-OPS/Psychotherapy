// ============================================================
// INVOIS BEKALAN PRODUK — psy_supply_invoices (database/schema/42_supply_invoices.sql)
// createSupplyInvoice() dipanggil SELEPAS addStockToLocation() (shared/inventoryStock.js)
// berjaya — supaya "jumlah diberi setakat ini" yg dikira di sini turut kira movement
// yang baru ditulis. Dua laluan panggil fungsi ni:
//   - roles/staff/patient-hub.html submitSupply()      (manual, "+ Bagi Bekalan")
//   - roles/staff/plan-week.html applySupplyStock()      (auto-deduct lepas Hadir)
//
// Kekunci padanan "dirancang vs diberi" SAMA dgn KPI "Baki Bekalan" di
// patient-hub.html renderSupplyKpiAndItems() — nama+unit (bukan item_id, sbb
// entri coaching_schedule.supplies kadang tiada item_id yg konsisten).
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

    const { data: hist } = await window.db.from('psy_stock_movements')
      .select('item_name, qty, psy_inventory_items(unit)')
      .eq('reference_type', 'patient_package').eq('reference_id', opts.patientId).eq('movement_type', 'out');
    const givenCum = {};
    (hist || []).forEach(h => {
      const k = key(h.item_name, h.psy_inventory_items?.unit);
      givenCum[k] = (givenCum[k] || 0) + Math.abs(Number(h.qty || 0));
    });

    const items = list.map(g => {
      const k = key(g.name, g.unit);
      const plannedTotal = planned[k] || 0;
      const cumulative = givenCum[k] || 0;
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
    return inserted;
  } catch (e) {
    console.warn('[supplyInvoice] ralat:', e);
    return null;
  }
}
window.createSupplyInvoice = createSupplyInvoice;
