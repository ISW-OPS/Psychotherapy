// ============================================================
// INVENTORY AUTO-DEDUCT
// Bila staff mark sesi 'hadir', deduct bekalan F2F dari inventory.
// ============================================================

/**
 * Deduct supplies for a session that was just marked as attended.
 * - Pulls plan.coaching_schedule[weekIndex].supplies
 * - Skips weeks with mode='online' (no physical supplies)
 * - Each supply needs item_id + qty + auto_stock !== false
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
      .select('id, plan_id, week_number, patient_id, is_extension')
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
    if (!weekObj) { result.skipped.push(`Minggu ${sess.week_number} tiada dalam jadual`); return result; }

    // Online sessions have no physical supplies to deduct
    if (weekObj.mode === 'online') { result.skipped.push('Sesi online — tiada bekalan'); return result; }

    const supplies = Array.isArray(weekObj.supplies) ? weekObj.supplies : [];
    if (!supplies.length) { result.skipped.push('Tiada bekalan disetkan untuk minggu ini'); return result; }

    // Process each supply
    for (const s of supplies) {
      const itemId = s?.item_id;
      const qty    = Number(s?.qty || s?.quantity || 0);
      const auto   = s?.auto_stock !== false; // default true

      if (!itemId) { result.skipped.push(`Item tanpa ID: ${s?.item_name || s?.name || '(unknown)'}`); continue; }
      if (qty <= 0) { result.skipped.push(`Item qty=0: ${s?.item_name || itemId}`); continue; }
      if (!auto)   { result.skipped.push(`Auto-stock off: ${s?.item_name || itemId}`); continue; }

      // Fetch current stock
      const { data: item } = await window.db
        .from('psy_inventory_items')
        .select('id, name, qty_in_stock, unit')
        .eq('id', itemId)
        .single();
      if (!item) { result.errors.push(`Item ${itemId} tidak ditemui`); continue; }

      const currentQty = Number(item.qty_in_stock) || 0;
      const newQty     = Math.max(0, currentQty - qty);

      // Update stock
      const { error: updErr } = await window.db
        .from('psy_inventory_items')
        .update({ qty_in_stock: newQty, updated_at: new Date().toISOString() })
        .eq('id', itemId);
      if (updErr) { result.errors.push(`Update ${item.name}: ${updErr.message}`); continue; }

      result.deducted.push({
        item_id:   itemId,
        item_name: item.name,
        qty,
        unit:      item.unit,
        before:    currentQty,
        after:     newQty,
        low_stock: newQty < currentQty && newQty < 5,
      });
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
