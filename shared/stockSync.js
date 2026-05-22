// Auto-sync stok antara psy_inventory_items <-> psy_products
// Cara match: nama sama (case-insensitive, trim).
// Gunakan kalau salah satu sisi update stok manual.

window.syncStockToProducts = async function(name, newQty) {
  const qty = Number(newQty);
  if (!name || !Number.isFinite(qty)) {
    console.warn('[stockSync→products] skip — invalid args:', { name, newQty });
    return false;
  }
  try {
    const matchName = String(name).trim();
    if (!matchName) return false;
    // Ambil semua produk dan match dalam JS (lagi reliable untuk nama dengan tanda kurungan)
    const { data: matches, error } = await window.db.from('psy_products').select('id, name, stock');
    if (error) { console.warn('[stockSync→products] select error:', error); return false; }
    let synced = false;
    for (const p of (matches || [])) {
      if ((p.name || '').trim().toLowerCase() === matchName.toLowerCase()) {
        const { error: updErr } = await window.db.from('psy_products')
          .update({ stock: qty, updated_at: new Date().toISOString() })
          .eq('id', p.id);
        if (updErr) { console.warn('[stockSync→products] update error:', updErr); }
        else { console.log(`[stockSync→products] ✓ ${p.name}: ${p.stock} → ${qty}`); synced = true; }
      }
    }
    if (!synced) console.warn(`[stockSync→products] No product matched name "${matchName}"`);
    return synced;
  } catch (e) {
    console.warn('[stockSync→products] exception:', e);
    return false;
  }
};

// Auto-create inventory item kalau produk baru ditambah tapi tiada inventory dengan nama sama
window.ensureInventoryCounterpart = async function(prod) {
  if (!prod?.name) return false;
  try {
    const name = String(prod.name).trim();
    const { data: existing } = await window.db.from('psy_inventory_items').select('id, name');
    const found = (existing || []).find(i => (i.name || '').trim().toLowerCase() === name.toLowerCase());
    if (found) return false;
    const invPayload = {
      name,
      consumption_type: 'product', // bezakan dari supplies pakej
      category: 'Produk',
      unit: prod.unit || 'unit',
      qty_in_stock: Number(prod.stock) || 0,
      min_qty: Number(prod.min_stock) || 5,
      auto_reorder_enabled: false,
      requires_approval: false,
      notes: prod.description_short || null,
      updated_at: new Date().toISOString(),
    };
    const { error } = await window.db.from('psy_inventory_items').insert(invPayload);
    if (error) { console.warn('[ensureInventoryCounterpart] insert error:', error); return false; }
    console.log('[ensureInventoryCounterpart] ✓ Created inventory item:', name);
    return true;
  } catch (e) {
    console.warn('[ensureInventoryCounterpart] exception:', e);
    return false;
  }
};

window.syncStockToInventory = async function(name, newQty) {
  const qty = Number(newQty);
  if (!name || !Number.isFinite(qty)) {
    console.warn('[stockSync→inventory] skip — invalid args:', { name, newQty });
    return false;
  }
  try {
    const matchName = String(name).trim();
    if (!matchName) return false;
    const { data: invs, error } = await window.db.from('psy_inventory_items').select('id, name, qty_in_stock');
    if (error) { console.warn('[stockSync→inventory] select error:', error); return false; }
    let synced = false;
    for (const i of (invs || [])) {
      if ((i.name || '').trim().toLowerCase() === matchName.toLowerCase()) {
        const { error: updErr } = await window.db.from('psy_inventory_items')
          .update({ qty_in_stock: qty, updated_at: new Date().toISOString() })
          .eq('id', i.id);
        if (updErr) { console.warn('[stockSync→inventory] update error:', updErr); }
        else { console.log(`[stockSync→inventory] ✓ ${i.name}: ${i.qty_in_stock} → ${qty}`); synced = true; }
      }
    }
    if (!synced) console.warn(`[stockSync→inventory] No inventory matched name "${matchName}"`);
    return synced;
  } catch (e) {
    console.warn('[stockSync→inventory] exception:', e);
    return false;
  }
};
