// ============================================================
// INVENTORY STOCK — helper untuk ubah stok melalui lokasi (bukan
// terus psy_inventory_items.qty_in_stock, yang kini aggregate
// dikawal trigger psy_sync_item_stock_total). Lihat
// database/schema/34_inventory_locations.sql.
//
// SETIAP panggilan di sini turut tulis 1 baris psy_stock_movements
// (ledger) — sumber "Recent Stock Movements" di inventory-overview.html.
// Jangan update qty_in_stock / psy_inventory_stock_by_location terus
// dari page lain, sentiasa lalu fungsi ni supaya ledger tak tertinggal.
// ============================================================

// Tambah/kurang qty pada satu lokasi bagi satu item. delta boleh negatif
// (utk stock adjustment / auto-deduct). locationName pilihan — jika tiada,
// guna lokasi sedia ada item (paling banyak stok) atau default ikut source_type.
//
// meta (pilihan): { type: 'in'|'out'|'adjustment', refType, refId, refLabel, note }
// refLabel = KOD rujukan sahaja (cth 'RCV-0001'); note = penerangan bebas (cth sebab adjustment).
// type default: delta >= 0 ? 'in' : 'out'.
async function addStockToLocation(itemId, delta, locationName, meta) {
  let locId = null;

  if (locationName) {
    const { data: loc } = await window.db.from('psy_inventory_locations').select('id').eq('name', locationName).maybeSingle();
    locId = loc?.id || null;
  }

  if (!locId) {
    const { data: rows } = await window.db.from('psy_inventory_stock_by_location')
      .select('location_id,qty_in_stock').eq('item_id', itemId).order('qty_in_stock', { ascending: false }).limit(1);
    if (rows && rows.length) locId = rows[0].location_id;
  }

  let itemName = meta?.itemName || null;
  if (!locId || !itemName) {
    const { data: item } = await window.db.from('psy_inventory_items').select('name,source_type').eq('id', itemId).single();
    itemName = itemName || item?.name || null;
    if (!locId) {
      const defaultName = item?.source_type === 'farmasi_klinikal' ? 'Clinical Pharmacy' : 'General Inventory';
      const { data: loc } = await window.db.from('psy_inventory_locations').select('id').eq('name', defaultName).maybeSingle();
      locId = loc?.id || null;
    }
  }

  if (!locId) return;

  const { data: existing } = await window.db.from('psy_inventory_stock_by_location')
    .select('id,qty_in_stock').eq('item_id', itemId).eq('location_id', locId).maybeSingle();

  let balanceAfter;
  if (existing) {
    balanceAfter = Math.max(0, Number(existing.qty_in_stock) + Number(delta));
    await window.db.from('psy_inventory_stock_by_location')
      .update({ qty_in_stock: balanceAfter, updated_at: new Date().toISOString() }).eq('id', existing.id);
  } else {
    balanceAfter = Math.max(0, Number(delta));
    await window.db.from('psy_inventory_stock_by_location')
      .insert({ item_id: itemId, location_id: locId, qty_in_stock: balanceAfter });
  }

  try {
    const { data: movement } = await window.db.from('psy_stock_movements').insert({
      item_id: itemId,
      item_name: itemName,
      location_id: locId,
      movement_type: meta?.type || (Number(delta) >= 0 ? 'in' : 'out'),
      qty: Number(delta),
      balance_after: balanceAfter,
      reference_type: meta?.refType || null,
      reference_id: meta?.refId || null,
      reference_label: meta?.refLabel || null,
      notes: meta?.note || null,
      actor_id: window.currentUser?.id || null,
      actor_name: window.currentUser?.full_name || null,
    }).select('id').single();
    return movement?.id || null;
  } catch (e) { console.warn('[inventoryStock] gagal tulis movement ledger:', e); return null; }
}
window.addStockToLocation = addStockToLocation;
