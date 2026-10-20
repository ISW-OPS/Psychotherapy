// ============================================================
// EVENT PREP SECTION — "Persediaan & Peralatan" embeddable widget
// dipakai oleh acara-baru.html (mod buffer, event belum wujud) dan
// acara-edit.html (mod live, event dah wujud) supaya staff terus
// senaraikan barang semasa cipta/kemaskini acara (bukan page berasingan).
//
// Guna: window.EventPrep.init({ eventId, containerId })
//       window.EventPrep.getItems()        -> array (mod buffer)
//       window.EventPrep.flushToEvent(id)  -> insert semua item buffer ke DB
// ============================================================
(function () {
  const S = {
    eventId: null,
    containerId: null,
    items: [],
    inventoryItems: [],
    equipmentItems: [],
  };

  function escHtml(s) { return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
  function uid() { return 'tmp_' + Math.random().toString(36).slice(2) + Date.now(); }

  const EQUIP_STATUS_META = {
    available:         { label: '🟢 Available',         key: 'cukup' },
    in_use:            { label: '🔵 In Use',             key: 'kurang' },
    under_maintenance: { label: '🔧 Under Maintenance',  key: 'kurang' },
    damaged:           { label: '🔴 Damaged',            key: 'kurang' },
    lost:              { label: '🔴 Lost',               key: 'kurang' },
    retired:           { label: '⚪ Retired',             key: 'kurang' },
  };

  function invStock(inventoryItemId) {
    const it = S.inventoryItems.find(i => i.id === inventoryItemId);
    return it ? Number(it.qty_in_stock || 0) : null;
  }
  function computedStatus(it) {
    if (it.source === 'equipment' && it.equipment_id) {
      const eq = S.equipmentItems.find(e => e.id === it.equipment_id);
      if (!eq) return { key: 'manual', label: '—', cls: 'text-ink/35' };
      const m = EQUIP_STATUS_META[eq.status] || { label: eq.status, key: 'kurang' };
      return { key: m.key, label: m.label, cls: m.key === 'cukup' ? 'text-green-700 bg-green-100' : 'text-red-600 bg-red-100' };
    }
    if (it.source !== 'inventory' || !it.inventory_item_id) return { key: 'manual', label: '—', cls: 'text-ink/35' };
    const stock = invStock(it.inventory_item_id);
    if (stock === null) return { key: 'manual', label: '—', cls: 'text-ink/35' };
    return stock >= Number(it.qty_needed)
      ? { key: 'cukup', label: '🟢 Mencukupi', cls: 'text-green-700 bg-green-100' }
      : { key: 'kurang', label: '🔴 Tidak Cukup', cls: 'text-red-600 bg-red-100' };
  }

  function sectionHtml() {
    return `
    <div class="bg-white rounded-2xl border border-ink/10 shadow-sm overflow-hidden">
      <div class="bg-navy/5 border-b border-ink/10 px-5 py-4 flex items-start justify-between gap-4 flex-wrap">
        <div>
          <h2 class="font-bold text-ink flex items-center gap-2">📋 Persediaan &amp; Peralatan <span class="text-[11px] font-normal text-ink/40">(Sebelum Event)</span></h2>
          <p class="text-[12px] text-ink/50 mt-0.5">Tambahkan semua barang, bahan atau keperluan untuk acara ini.</p>
        </div>
        <button type="button" onclick="EventPrep.addBlankRow()" class="bg-navy text-white px-3 py-2 rounded-lg text-xs font-semibold hover:bg-navy-dark flex-shrink-0">+ Tambah Item</button>
      </div>

      <div class="px-5 py-2 border-b border-ink/5 grid gap-2 items-center text-[10px] font-bold text-ink/40 uppercase tracking-wider" style="grid-template-columns:2fr 1fr 85px 110px 70px 130px 70px">
        <span>Item</span><span>Kategori</span><span class="text-right">Stok</span><span class="text-right">Perlu</span><span>Unit</span><span>Status</span><span></span>
      </div>
      <div id="ep-table" class="divide-y divide-ink/5"></div>
      <div id="ep-empty" class="hidden px-5 py-10 text-center text-sm text-ink/35">Tiada barang lagi — tekan "+ Tambah Item" untuk mula.</div>
    </div>`;
  }

  async function loadLookups() {
    const [invRes, eqRes] = await Promise.all([
      window.db.from('psy_inventory_items').select('id, name, category, unit, qty_in_stock').eq('is_active', true).order('name'),
      window.db.from('psy_equipment').select('id, name, code, category, status').neq('status', 'retired').order('name'),
    ]);
    S.inventoryItems = invRes.data || [];
    S.equipmentItems = eqRes.data || [];
  }

  function render() {
    const filtered = S.items;

    const tbody = document.getElementById('ep-table');
    const empty = document.getElementById('ep-empty');
    if (!tbody) return;
    if (!filtered.length) { tbody.innerHTML = ''; empty.classList.remove('hidden'); return; }
    empty.classList.add('hidden');

    const itemPickOpts = it => {
      const eqByCat = {};
      S.equipmentItems.forEach(eq => { (eqByCat[eq.category || 'Lain-lain'] = eqByCat[eq.category || 'Lain-lain'] || []).push(eq); });
      const eqGroups = Object.keys(eqByCat).sort().map(cat => `<optgroup label="🔧 ${escHtml(cat)}">${
        eqByCat[cat].map(eq => `<option value="eq:${eq.id}" ${it.equipment_id === eq.id ? 'selected' : ''}>${escHtml(eq.name)} (${escHtml(eq.code)}) — ${(EQUIP_STATUS_META[eq.status]||{label:eq.status}).label}</option>`).join('')
      }</optgroup>`).join('');

      const invByCat = {};
      S.inventoryItems.forEach(inv => { (invByCat[inv.category || 'Lain-lain'] = invByCat[inv.category || 'Lain-lain'] || []).push(inv); });
      const invGroups = Object.keys(invByCat).sort().map(cat => `<optgroup label="📦 ${escHtml(cat)}">${
        invByCat[cat].map(inv => `<option value="${inv.id}" ${it.source === 'inventory' && it.inventory_item_id === inv.id ? 'selected' : ''}>${escHtml(inv.name)}</option>`).join('')
      }</optgroup>`).join('');

      return '<option value="">— Pilih barang —</option>'
        + `<option value="__manual__" ${it.source === 'manual' ? 'selected' : ''}>✏️ Barang Manual (taip nama)</option>`
        + eqGroups + invGroups;
    };

    tbody.innerHTML = filtered.map(it => {
      const stock = it.source === 'inventory' ? invStock(it.inventory_item_id) : null;
      const st = computedStatus(it);
      const stockCell = it.source === 'equipment' ? '' : (stock === null ? '—' : stock);
      return `<div class="grid gap-2 items-center px-5 py-2.5 hover:bg-ink/[0.015]" style="grid-template-columns:2fr 1fr 85px 110px 70px 130px 70px">
        <div class="min-w-0">
          <select onchange="EventPrep.onItemPicked('${it._key}', this.value)" class="w-full px-1.5 py-1 border border-ink/15 rounded-lg text-sm bg-white">${itemPickOpts(it)}</select>
          ${it.source === 'manual' ? `<input type="text" placeholder="Nama barang" value="${escHtml(it.item_name)}" onchange="EventPrep.updateField('${it._key}','item_name', this.value)" class="w-full mt-1 px-1.5 py-1 border border-ink/15 rounded-lg text-sm">` : ''}
        </div>
        <div class="text-xs text-ink/60 truncate">${escHtml(it.category || '—')}</div>
        <div class="text-sm text-right ${st.key === 'kurang' ? 'font-bold text-red-600' : 'text-ink/60'}">${stockCell}</div>
        <div class="text-right"><input type="number" min="0.01" step="0.01" value="${Number(it.qty_needed)}" onchange="EventPrep.updateField('${it._key}','qty_needed', this.value)" class="w-20 text-right px-1.5 py-1 border border-ink/15 rounded-lg text-sm"></div>
        <div class="text-[11px] text-ink/50">${escHtml(it.unit || '—')}</div>
        <div>
          <span class="text-[11px] font-semibold px-2 py-1 rounded-full ${st.cls}">${st.label}</span>
          ${st.key === 'kurang' && it.source === 'inventory' ? `<a href="purchase-request-form.html?item=${it.inventory_item_id}&qty=${Math.max(0, Number(it.qty_needed) - (stock || 0))}" target="_blank" class="block mt-1 text-[10px] font-bold text-amber-700 bg-amber-100 px-2 py-0.5 rounded-full text-center hover:bg-amber-200">Buat Purchase Request</a>` : ''}
          ${st.key === 'kurang' && it.source === 'equipment' ? `<a href="equipment-list.html" target="_blank" class="block mt-1 text-[10px] font-bold text-amber-700 bg-amber-100 px-2 py-0.5 rounded-full text-center hover:bg-amber-200">Lihat Equipment List</a>` : ''}
        </div>
        <div class="text-right"><button onclick="EventPrep.deleteItem('${it._key}')" class="text-ink/30 hover:text-terracotta text-sm">✕</button></div>
      </div>`;
    }).join('');
  }

  async function updateField(key, field, value) {
    const row = S.items.find(i => i._key === key);
    if (!row) return;
    row[field] = value;
    await persistRow(row);
    render();
  }

  async function deleteItem(key) {
    const row = S.items.find(i => i._key === key);
    if (!row) return;
    if (!confirm('Padam barang ni?')) return;
    if (S.eventId && row.id) {
      const { error } = await window.db.from('psy_event_prep_items').delete().eq('id', row.id);
      if (error) { banner('Ralat padam: ' + error.message, 'error'); return; }
    }
    S.items = S.items.filter(i => i._key !== key);
    render();
  }

  // ── Tambah item (baris kosong + pilih dari dropdown — gaya Purchase Request) ──
  function addBlankRow() {
    S.items.push({
      _key: uid(), id: null, source: null, inventory_item_id: null, equipment_id: null,
      item_name: '', category: null, unit: null, qty_needed: 1,
      deadline_date: null,
    });
    render();
  }

  async function onItemPicked(key, value) {
    const row = S.items.find(i => i._key === key);
    if (!row) return;
    if (!value) { row.source = null; row.inventory_item_id = null; row.equipment_id = null; row.item_name = ''; row.category = null; row.unit = null; }
    else if (value === '__manual__') { row.source = 'manual'; row.inventory_item_id = null; row.equipment_id = null; row.item_name = ''; row.category = null; row.unit = null; }
    else if (value.startsWith('eq:')) {
      const eq = S.equipmentItems.find(e => e.id === value.slice(3));
      row.source = 'equipment'; row.inventory_item_id = null; row.equipment_id = eq?.id || null;
      row.item_name = eq?.name || ''; row.category = eq?.category || null; row.unit = null;
    } else {
      const it = S.inventoryItems.find(i => i.id === value);
      row.source = 'inventory'; row.inventory_item_id = value; row.equipment_id = null;
      row.item_name = it?.name || ''; row.category = it?.category || null; row.unit = it?.unit || null;
    }
    await persistRow(row);
    render();
  }

  async function persistRow(row) {
    if (!S.eventId || !row.source) return;   // belum siap (mod buffer, atau belum pilih barang lagi)
    const payload = {
      source: row.source, inventory_item_id: row.inventory_item_id, equipment_id: row.equipment_id, item_name: row.item_name,
      category: row.category, unit: row.unit, qty_needed: row.qty_needed,
      deadline_date: row.deadline_date,
    };
    if (row.id) {
      await window.db.from('psy_event_prep_items').update({ ...payload, updated_at: new Date().toISOString() }).eq('id', row.id);
    } else if (row.source === 'inventory' || row.item_name) {
      const { data, error } = await window.db.from('psy_event_prep_items').insert({ event_id: S.eventId, ...payload }).select().single();
      if (!error) row.id = data.id;
    }
  }

  // ── Public API ───────────────────────────────────────────────
  async function init(opts) {
    S.eventId = opts.eventId || null;
    S.containerId = opts.containerId;
    S.items = [];
    document.getElementById(S.containerId).innerHTML = sectionHtml();
    await loadLookups();
    if (S.eventId) {
      const { data } = await window.db.from('psy_event_prep_items').select('*').eq('event_id', S.eventId).order('created_at');
      S.items = (data || []).map(r => ({ ...r, _key: r.id }));
    }
    render();
  }

  function getItems() { return S.items; }

  async function flushToEvent(eventId) {
    const valid = S.items.filter(it => it.source && (it.source === 'inventory' || it.item_name));
    if (!valid.length) return;
    const rows = valid.map(it => ({
      event_id: eventId, source: it.source, inventory_item_id: it.inventory_item_id, equipment_id: it.equipment_id || null,
      item_name: it.item_name, category: it.category, unit: it.unit, qty_needed: it.qty_needed,
      deadline_date: it.deadline_date || null,
    }));
    const { error } = await window.db.from('psy_event_prep_items').insert(rows);
    if (error) console.warn('[EventPrep] gagal simpan barang persediaan:', error.message);
  }

  window.EventPrep = {
    init, getItems, flushToEvent, render,
    addBlankRow, onItemPicked,
    updateField, deleteItem,
  };
})();
