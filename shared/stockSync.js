// Auto-sync stok antara psy_inventory_items <-> psy_products
// Cara match: nama sama (case-insensitive, trim).
// Gunakan kalau salah satu sisi update stok manual.

// DIPERSARA: stok Produk Shop kini dibaca terus dari Inventori (tiada salinan stok pada psy_products).
// Fungsi dikekalkan sebagai no-op supaya pemanggil lama tidak rosak.
window.syncStockToProducts = async function () { return true; };

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
