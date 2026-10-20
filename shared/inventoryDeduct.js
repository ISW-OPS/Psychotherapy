// ============================================================
// INVENTORY AUTO-DEDUCT
// Bila staff mark sesi 'hadir', deduct bekalan F2F dari inventory.
// ============================================================

/**
 * Deduct supplies for a session that was just marked as attended.
 * - Pulls plan.coaching_schedule[weekIndex].supplies (session_day=2 guna supplies_2
 *   — pakej 2 sesi/minggu ada 2 baris psy_plan_weekly_progress berasingan, satu per
 *   session_day; padan dgn getWeekCoachingItems() di plan-week.html)
 * - Skips weeks with mode='online' (no physical supplies)
 * - Each supply needs item_id + qty + auto_stock !== false, DAN mesti ditick
 *   staff dalam checklist "Bekalan" (plan-week.html) — coaching_checks[`{prefix}_supplies_{idx}`]
 *   mesti true, prefix = 'D{n}' (harian) atau label bertingkat W/M/Q (mingguan,
 *   shared/schedulePeriod.js). Item tak ditick (staff isi "Sebab belum selesai...")
 *   dilangkau — bukan semua bekalan dijadualkan automatik ditolak semata sesi ditanda Hadir.
 * - Decrements psy_inventory_items.qty_in_stock
 * - Logs to audit
 *
 * @param {string} sessionId - psy_plan_weekly_progress.id
 * @returns {Promise<{deducted: array, skipped: array, errors: array}>}
 */
window.deductSessionSupplies = async function (sessionId) {
  const result = { deducted: [], skipped: [], errors: [] };
  try {
    // Get session detail
    const { data: sess, error: sessErr } = await window.db
      .from('psy_plan_weekly_progress')
      .select('id, plan_id, week_number, session_day, patient_id, is_extension, coaching_checks')
      .eq('id', sessionId)
      .single();
    if (sessErr || !sess) { result.errors.push('Sesi tidak ditemui'); return result; }
    if (sess.is_extension) { result.skipped.push('Sesi extension — tiada bekalan'); return result; }

    // Get plan coaching_schedule
    const { data: plan, error: planErr } = await window.db
      .from('psy_treatment_plans')
      .select('id, coaching_schedule')
      .eq('id', sess.plan_id)
      .single();
    if (planErr || !plan) { result.errors.push('Plan tidak ditemui'); return result; }

    const schedule = Array.isArray(plan.coaching_schedule) ? plan.coaching_schedule : [];
    const weekObj  = schedule.find(w => w.week === sess.week_number) || schedule[sess.week_number - 1];
    if (!weekObj) { result.skipped.push(`${window.iswPeriodLabel(sess.week_number)} tiada dalam jadual`); return result; }

    // Online sessions have no physical supplies to deduct
    if (weekObj.mode === 'online') { result.skipped.push('Sesi online — tiada bekalan'); return result; }

    // Sesi 2 (session_day=2) guna senarai bekalan berasingan — lihat nota fungsi di atas.
    const activeDay = sess.session_day || 1;
    const suppliesRaw = activeDay === 2 ? weekObj.supplies_2 : weekObj.supplies;
    const supplies = Array.isArray(suppliesRaw) ? suppliesRaw : [];
    if (!supplies.length) { result.skipped.push('Tiada bekalan disetkan untuk minggu ini'); return result; }

    const coachingChecks = sess.coaching_checks || {};
    const movementIds = [];

    // Process each supply
    for (let idx = 0; idx < supplies.length; idx++) {
      const s = supplies[idx];
      const itemId = s?.item_id;
      const qty    = Number(s?.qty || s?.quantity || 0);
      const auto   = s?.auto_stock !== false; // default true
      // Prefix checklist kunci MESTI padan apa yg plan-week.html tulis (checklistSection()):
      // 'D{n}' utk pakej harian, atau label bertingkat W/M/Q utk pakej mingguan
      // (shared/schedulePeriod.js) — bukan 'M{n}' tegar lagi.
      const checkPrefix = weekObj.period === 'day' ? `D${sess.week_number}` : window.iswPeriodLabel(sess.week_number);
      const ticked = coachingChecks[`${checkPrefix}_supplies_${idx}`] === true;

      if (!itemId) { result.skipped.push(`Item tanpa ID: ${s?.item_name || s?.name || '(unknown)'}`); continue; }
      if (qty <= 0) { result.skipped.push(`Item qty=0: ${s?.item_name || itemId}`); continue; }
      if (!auto)   { result.skipped.push(`Auto-stock off: ${s?.item_name || itemId}`); continue; }
      if (!ticked) { result.skipped.push(`Belum ditick di checklist Bekalan: ${s?.item_name || itemId}`); continue; }

      // Fetch current stock
      const { data: item } = await window.db
        .from('psy_inventory_items')
        .select('id, name, qty_in_stock, unit')
        .eq('id', itemId)
        .single();
      if (!item) { result.errors.push(`Item ${itemId} tidak ditemui`); continue; }

      const currentQty = Number(item.qty_in_stock) || 0;
      // Elak lebih tolak dari stok sedia ada (sama kelakuan Math.max(0,...) yang asal).
      const actualDelta = -Math.min(qty, currentQty);

      // addStockToLocation() (bukan update qty_in_stock terus) — supaya stok per-lokasi
      // (psy_inventory_stock_by_location) & ledger (psy_stock_movements) turut betul; update
      // terus di sini sebelum ni bypass sistem lokasi & boleh ditimpa semula oleh trigger
      // psy_sync_item_stock_total() pada Stock In/adjustment seterusnya.
      try {
        const movementId = await window.addStockToLocation(itemId, actualDelta, null, {
          type: 'out', refType: 'patient_package', refId: sess.patient_id,
          note: `Sesi minggu ${sess.week_number}`, itemName: item.name,
        });
        if (movementId) movementIds.push(movementId);
      } catch (e) { result.errors.push(`Update ${item.name}: ${e.message}`); continue; }

      const newQty = Math.max(0, currentQty + actualDelta);

      result.deducted.push({
        item_id:   itemId,
        item_name: item.name,
        qty,
        unit:      item.unit,
        before:    currentQty,
        after:     newQty,
        low_stock: newQty < currentQty && newQty < 5,
      });

      // Barang yang sama juga dijual berasingan di Shop (psy_products, dipadan ikut
      // nama) — tanpa ni, stok Shop jadi lapuk selepas auto-tolak sesi coaching.
      try { await window.syncStockToProducts?.(item.name, newQty); } catch (e) { console.warn('syncStockToProducts gagal:', e); }
    }

    // Cipta psy_supply_invoices — TANPA ni, bekalan yg auto-ditolak di sini tak
    // pernah muncul di "Invois Bekalan Pakej" (shared/invoice.js, dibuka dari
    // plan-week.html "📄 Lihat Invois"), walaupun stok dah betul2 ditolak di atas.
    // Sama laluan dgn applySupplyStock() (plan-week.html, tick manual checklist
    // Bekalan) — lihat shared/supplyInvoice.js createSupplyInvoice(). Gagal cipta
    // invois TAK sekat/rollback potongan stok yg dah berjaya (createSupplyInvoice()
    // pulang null senyap kalau gagal).
    if (result.deducted.length) {
      try {
        const givenForInvoice = result.deducted.map(d => ({
          item_id: d.item_id, name: d.item_name, unit: d.unit, qty_given: d.qty,
        }));
        const supplyInvoice = await window.createSupplyInvoice?.(givenForInvoice, {
          patientId: sess.patient_id, activePlan: plan, planId: sess.plan_id,
          weekNumber: sess.week_number, source: 'auto_weekly',
          notes: `Sesi minggu ${sess.week_number}`,
        });
        if (supplyInvoice && movementIds.length) {
          await window.db.from('psy_stock_movements').update({ supply_invoice_id: supplyInvoice.id }).in('id', movementIds);
        }
      } catch (e) { console.warn('[deductSessionSupplies] gagal cipta invois bekalan:', e); }
    }

    // Audit log (one entry per session, listing all deductions)
    if (result.deducted.length) {
      try {
        await window.db.from('psy_audit_log').insert({
          actor_id:   window.currentUser?.id,
          actor_name: window.currentUser?.full_name || 'Staff',
          actor_role: 'staff',
          action:     'inventory.auto_deducted',
          target:     sess.plan_id,
          meta: {
            session_id:  sess.id,
            patient_id:  sess.patient_id,
            week_number: sess.week_number,
            items:       result.deducted,
          },
        });
      } catch (e) { console.warn('Audit log failed:', e); }
    }

    return result;
  } catch (e) {
    result.errors.push(e.message || String(e));
    return result;
  }
};

/**
 * Display deduction summary to user via banner.
 * @param {{deducted: array, errors: array}} result
 */
window.showDeductSummary = function (result) {
  if (!window.banner) return;
  if (result.errors?.length) {
    window.banner(`⚠️ Ralat inventori: ${result.errors[0]}`, 'error');
    return;
  }
  if (!result.deducted?.length) return;

  const list = result.deducted.map(d => `${d.item_name} −${d.qty}${d.unit}`).join(', ');
  const lowStock = result.deducted.filter(d => d.low_stock);
  if (lowStock.length) {
    window.banner(`📦 Bekalan ditolak: ${list} · ⚠️ ${lowStock.length} item stok rendah`, 'error');
  } else {
    window.banner(`📦 Bekalan ditolak: ${list}`);
  }
};
