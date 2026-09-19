// Kaitan Inventori ↔ Produk Shop.
// Produk Shop (psy_products) dipaut ke item inventori melalui inventory_item_id (FK) ATAU nama sama
// (case-insensitive, trim) — sama cara shop.html memadankan stok. Kalau item inventori tidak aktif,
// produk yang dipaut tidak boleh dijual (shop sorok + payment tolak + pelayan tolak) dan staf diberi amaran.

// Item inventori dianggap tidak aktif jika status bukan 'active' (inactive/discontinued);
// baris lama tanpa kolum status jatuh balik ke is_active.
window.iswInvItemInactive = function (inv) {
  if (!inv) return false;
  const st = inv.status || (inv.is_active === false ? 'inactive' : 'active');
  return st !== 'active';
};

// Status inventori bagi SETIAP produk Shop — untuk pesakit. Pesakit tak boleh baca psy_inventory_items (RLS), jadi
// dibuat oleh fungsi SECURITY DEFINER psy_shop_product_inventory() (database/add_shop_inventory_link.sql).
// Pulang Map(product_id → { name, linked, itemStatus, qty, unit, sellable }).
// Produk BOLEH DIJUAL hanya bila ada item Inventori dipaut DAN item itu aktif.
// Fungsi belum dipasang / ralat → Map kosong (fail-open: tiada produk disorok); sekatan pelayan tetap berkuat kuasa.
window.iswShopInventoryMap = async function () {
  try {
    const { data, error } = await window.db.rpc('psy_shop_product_inventory');
    if (error) { console.warn('[inventoryLink] psy_shop_product_inventory:', error.message); return new Map(); }
    return new Map((data || []).map(r => [r.product_id, {
      name: r.name, linked: !!r.linked, itemStatus: r.item_status,
      qty: r.qty_in_stock == null ? null : Number(r.qty_in_stock), unit: r.unit, sellable: !!r.sellable,
    }]));
  } catch (_) { return new Map(); }
};

// Map(product_id → nama) bagi produk yang TIDAK boleh dijual (tiada di Inventori / item tidak aktif).
window.iswShopBlockedProducts = async function () {
  const inv = await window.iswShopInventoryMap();
  return new Map([...inv].filter(([, v]) => !v.sellable).map(([id, v]) => [id, v.name]));
};

// Produk Shop yang dipaut ke item inventori ini. Lalai: aktif sahaja (untuk amaran staf);
// { includeInactive: true } utk paparan senarai pada halaman detail item.
window.iswShopProductsForItem = async function (item, opts) {
  const items = (Array.isArray(item) ? item : [item]).filter(Boolean);
  if (!items.length) return [];
  try {
    const { data, error } = await window.db.from('psy_products')
      .select('id, name, product_id, sku, price, promo_price, is_active, status, visible_in_shop, inventory_item_id');
    if (error) return [];
    const ids = new Set(items.map(i => i.id));
    const names = new Set(items.map(i => (i.name || '').trim().toLowerCase()));
    return (data || []).filter(p => (opts?.includeInactive || p.is_active !== false)
      && (ids.has(p.inventory_item_id) || names.has((p.name || '').trim().toLowerCase())));
  } catch (_) { return []; }
};

// Nyahaktifkan produk Shop (is_active=false, status='inactive') supaya senarai Produk staf turut menunjukkannya.
// Wajib bila item DIPADAM: FK inventory_item_id jadi NULL (ON DELETE SET NULL) dan pautan hilang, kalau tidak
// produk kekal dijual berdasarkan lajur stok lama. Bila item diaktifkan semula, produk TIDAK diaktifkan
// automatik (tak boleh bezakan Inactive manual vs auto) — staf aktifkan di halaman Produk.
window.iswDeactivateShopProducts = async function (products) {
  const ids = (products || []).map(p => p.id);
  if (!ids.length) return 0;
  const { error } = await window.db.from('psy_products')
    .update({ is_active: false, status: 'inactive', updated_at: new Date().toISOString() }).in('id', ids);
  return error ? 0 : ids.length;
};

// Dialog amaran; resolve senarai produk terkesan (boleh kosong) kalau staf mahu teruskan, false kalau batal.
window.iswConfirmShopImpact = async function (item, actionLabel) {
  const linked = await window.iswShopProductsForItem(item);
  if (!linked.length) return linked;
  const names = linked.slice(0, 8).map(p => '• ' + p.name).join('\n') + (linked.length > 8 ? `\n• …dan ${linked.length - 8} lagi` : '');
  const subject = Array.isArray(item) ? `${item.length} item terpilih` : `"${item.name}"`;
  return confirm(`⚠️ ${subject} dipaut kepada ${linked.length} produk Shop:\n\n${names}\n\nBila item ${Array.isArray(item) ? 'ini' : 'ini'} ${actionLabel}, produk di atas akan turut DINYAHAKTIFKAN (tidak lagi dijual kepada pesakit).\n\nTeruskan?`) ? linked : false;
};
