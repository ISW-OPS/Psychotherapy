// ============================================================
// INVENTORY FORECAST — keperluan bekalan ikut tarikh sebenar
// Gantikan computeDynamicDemand() (inventory.html) yang jumlahkan SELURUH
// jadual pakej (semua minggu) dilabel "dynamic_monthly" — bukan betul-betul
// terikat kepada sebarang tempoh/tarikh. Fungsi ni sebaliknya tengok sesi
// SEBENAR yang dijadualkan (psy_plan_weekly_progress) dalam julat tarikh
// dipilih, dan ikut LOGIK SAMA macam deductSessionSupplies() supaya nombor
// forecast benar-benar meramal apa yang akan ditolak dari stok:
//   - skip sesi is_extension (tiada bekalan)
//   - skip minggu mode='online' (tiada bekalan fizikal)
//   - hanya baca weekObj.supplies (bukan supplies_2 — sepadan dgn deduct sebenar)
//   - skip bekalan tanpa item_id / qty<=0 / auto_stock===false
//   - sesi yang statusnya 'hadir' (dah berlaku, stok dah ditolak) atau
//     'cancel' (tak jadi) TIDAK dikira — elak double-count dgn stok sedia ada
// ============================================================

/**
 * @param {string[]} itemIds - senarai psy_inventory_items.id nak dikira
 * @param {string} startDate - 'YYYY-MM-DD'
 * @param {string} endDate   - 'YYYY-MM-DD'
 * @returns {Promise<Record<string, {required:number, breakdown:Array}>>}
 */
window.computeForecastForRange = async function (itemIds, startDate, endDate) {
  const forecast = {};
  (itemIds || []).forEach(id => { forecast[id] = { required: 0, breakdown: [] }; });
  if (!itemIds?.length || !startDate || !endDate) return forecast;

  const { data: rows, error } = await window.db.from('psy_plan_weekly_progress')
    .select('id, plan_id, week_number, patient_id, is_extension, session_date, status, psy_patients(full_name, mrn)')
    .gte('session_date', startDate).lte('session_date', endDate)
    .neq('status', 'hadir').neq('status', 'cancel');
  if (error) { console.error('[inventoryForecast] gagal baca sesi:', error); return forecast; }

  const upcoming = (rows || []).filter(r => !r.is_extension);
  const planIds = [...new Set(upcoming.map(r => r.plan_id).filter(Boolean))];
  if (!planIds.length) return forecast;

  const { data: plans, error: planErr } = await window.db.from('psy_treatment_plans')
    .select('id, coaching_schedule').in('id', planIds);
  if (planErr) { console.error('[inventoryForecast] gagal baca pelan:', planErr); return forecast; }
  const planMap = {};
  (plans || []).forEach(p => { planMap[p.id] = Array.isArray(p.coaching_schedule) ? p.coaching_schedule : []; });

  upcoming.forEach(r => {
    const schedule = planMap[r.plan_id] || [];
    const weekObj = schedule.find(w => w.week === r.week_number) || schedule[r.week_number - 1];
    if (!weekObj || weekObj.mode === 'online') return;

    const supplies = Array.isArray(weekObj.supplies) ? weekObj.supplies : [];
    supplies.forEach(s => {
      const itemId = s?.item_id;
      const qty    = Number(s?.qty || s?.quantity || 0);
      const auto   = s?.auto_stock !== false;
      if (!itemId || qty <= 0 || !auto || !forecast[itemId]) return;

      forecast[itemId].required += qty;
      forecast[itemId].breakdown.push({
        patient_name: r.psy_patients?.full_name || r.psy_patients?.mrn || '—',
        week_number:  r.week_number,
        session_date: r.session_date,
        qty,
      });
    });
  });

  Object.values(forecast).forEach(f => { f.required = Math.ceil(f.required); });
  return forecast;
};

// Julat standard utk Auto-PO / status "Stok Rendah" — rolling N hari dari hari ini (bukan
// minggu/bulan kalendar, supaya sentiasa "N hari ke depan" tak kira bila page dibuka).
// Guna function ni (bukan hardcode nombor) supaya semua page
// (inventory.html, dashboard.html, governance.html, item-form.html) sentiasa sepadan.
window.INVENTORY_REORDER_LOOKAHEAD_DAYS = 14;
window.inventoryReorderRange = function () {
  const now = new Date();
  const ymd = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  const end = new Date(now); end.setDate(now.getDate() + window.INVENTORY_REORDER_LOOKAHEAD_DAYS);
  return { start: ymd(now), end: ymd(end) };
};

// Threshold "Stok Rendah" bersama — SATU fungsi dipakai di inventory.html, dashboard.html
// & governance.html supaya senarai Stok Rendah sentiasa sepadan merentasi page. Perlu
// item.forecast_required dah dilekatkan (attachInventoryForecast()) sebelum panggil ni.
//
// TIADA lagi toggle manual "Cara Kira Keperluan" — sistem auto-detect: kalau item ADA
// sesi pesakit sebenar dijadualkan (forecast_required > 0), guna nombor tu; kalau TIADA
// (sama ada item memang tak pernah dikaitkan mana-mana pakej, ATAU dikaitkan tapi kebetulan
// tiada sesi dlm julat sekarang), fallback ke Stok Minimum. Elak staff perlu declare/ingat
// jenis item — data sebenar (ada dlm jadual bekalan pakej ke tidak) yang tentukan.
window.getInventoryReorderThreshold = function (item) {
  const req = Number(item.forecast_required) || 0;
  if (req > 0) return req;
  return Number(item.min_qty) || 0;
};

// Lampirkan item.forecast_required + item.forecast_breakdown pada SETIAP item aktif (tiada
// lagi filter consumption_type='package' — semua item cuba dikira, sebab data sebenar yang
// tentukan sama ada ia "package-linked" atau tidak, bukan flag manual staff).
window.attachInventoryForecast = async function (items) {
  (items || []).forEach(i => { i.forecast_required = 0; i.forecast_breakdown = []; });
  if (!items?.length) return items;

  const { start, end } = window.inventoryReorderRange();
  const result = await window.computeForecastForRange(items.map(i => i.id), start, end);
  items.forEach(i => {
    const f = result[i.id] || { required: 0, breakdown: [] };
    i.forecast_required = f.required;
    i.forecast_breakdown = f.breakdown;
  });
  return items;
};

// Audit #E-21 (Tier 4) — bezakan "item tak pernah dikaitkan ke mana-mana pakej
// langsung" drpd "dikaitkan tapi kebetulan tiada sesi dijadualkan dlm tempoh
// forecast sekarang" (forecast_required=0 diam-diam sebelum ni, dua kes nampak
// sama). Imbas SEMUA psy_packages.coaching_schedule (bukan date-scoped macam
// computeForecastForRange) → satu Set item_id yg PERNAH disebut dlm mana-mana
// pakej, tak kira ada sesi aktif ke tidak sekarang.
window.computeMappedItemIds = async function () {
  const { data: pkgs, error } = await window.db.from('psy_packages').select('coaching_schedule');
  if (error) { console.error('[inventoryForecast] gagal baca pakej:', error); return new Set(); }
  const ids = new Set();
  (pkgs || []).forEach(pk => {
    (Array.isArray(pk.coaching_schedule) ? pk.coaching_schedule : []).forEach(w => {
      (Array.isArray(w?.supplies) ? w.supplies : []).forEach(s => { if (s?.item_id) ids.add(s.item_id); });
    });
  });
  return ids;
};

// Lampirkan item.is_pkg_mapped (boolean, statik — bukan date-scoped) pada setiap item.
window.attachPackageMappingFlag = async function (items) {
  if (!items?.length) return items;
  const mapped = await window.computeMappedItemIds();
  items.forEach(i => { i.is_pkg_mapped = mapped.has(i.id); });
  return items;
};

// Helper: julat tarikh ISO (YYYY-MM-DD) untuk "minggu ini" (Isnin-Ahad) / "bulan ini".
window.inventoryForecastRange = function (period) {
  const now = new Date();
  const ymd = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  if (period === 'month') {
    const start = new Date(now.getFullYear(), now.getMonth(), 1);
    const end   = new Date(now.getFullYear(), now.getMonth() + 1, 0);
    return { start: ymd(start), end: ymd(end) };
  }
  // default: minggu ini (Isnin–Ahad)
  const dow = now.getDay(); // 0=Ahad
  const diffToMon = dow === 0 ? -6 : 1 - dow;
  const start = new Date(now); start.setDate(now.getDate() + diffToMon);
  const end = new Date(start); end.setDate(start.getDate() + 6);
  return { start: ymd(start), end: ymd(end) };
};
