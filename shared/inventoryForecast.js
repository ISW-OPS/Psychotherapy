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
    .select('id, plan_id, week_number, patient_id, is_extension, session_date, status, coaching_checks, psy_patients(full_name, mrn)')
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

  // Kit bekalan (kit_id) dikembangkan kepada item individu — sama macam applySupplyStock() di plan-week.html
  const kitIds = new Set();
  (plans || []).forEach(p => (Array.isArray(p.coaching_schedule) ? p.coaching_schedule : []).forEach(w =>
    (Array.isArray(w.supplies) ? w.supplies : []).forEach(s => { if (s?.kit_id) kitIds.add(s.kit_id); })));
  const kitMap = {};
  if (kitIds.size) {
    const { data: kits, error: kitErr } = await window.db.from('psy_procedure_kits')
      .select('id, items').in('id', [...kitIds]);
    if (kitErr) console.error('[inventoryForecast] gagal baca kit:', kitErr);
    (kits || []).forEach(k => { kitMap[k.id] = Array.isArray(k.items) ? k.items : []; });
  }

  upcoming.forEach(r => {
    const schedule = planMap[r.plan_id] || [];
    const weekObj = schedule.find(w => w.week === r.week_number) || schedule[r.week_number - 1];
    if (!weekObj || weekObj.mode === 'online') return;

    const supplies = Array.isArray(weekObj.supplies) ? weekObj.supplies : [];
    supplies.forEach((s, idx) => {
      // Bekalan yang dah DITICK staff = stok dah keluar (lihat deductSessionSupplies / applySupplyStock).
      // Tak perlu dikira sebagai keperluan lagi — elak kiraan berganda. Kunci tick ikut bekalan (idx),
      // jadi untuk kit ia terpakai pada keseluruhan kit tu.
      const ticked = (r.coaching_checks || {})[`M${r.week_number}_supplies_${idx}`] === true;
      if (ticked) return;
      const auto = s?.auto_stock !== false;
      if (!auto) return;

      // Senarai (item, qty) untuk bekalan ni: kit → item dalam kit × bilangan kit; item biasa → terus
      const parts = s?.kit_id
        ? (kitMap[s.kit_id] || []).filter(ki => ki.item_id).map(ki => ({
            itemId: ki.item_id, qty: (Number(ki.qty) || 0) * (Number(s.qty) || 1),
          }))
        : [{ itemId: s?.item_id, qty: Number(s?.qty || s?.quantity || 0) }];

      parts.forEach(({ itemId, qty }) => {
        if (!itemId || qty <= 0 || !forecast[itemId]) return;
        forecast[itemId].required += qty;
        forecast[itemId].breakdown.push({
          patient_name: r.psy_patients?.full_name || r.psy_patients?.mrn || '—',
          week_number:  r.week_number,
          session_date: r.session_date,
          qty,
        });
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
  const esok = Number(item.forecast?.tomorrow ?? item.forecast_required) || 0;
  return esok + (Number(item.min_qty) || 0);
};

// Empat tempoh keperluan (rolling dari hari ini) — barang mesti sedia awal untuk semua tempoh.
window.inventoryHorizonRanges = function () {
  const ymd = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  const today = new Date();
  const add = n => { const d = new Date(today); d.setDate(today.getDate() + n); return ymd(d); };
  const t = ymd(today);
  return {
    today:    { start: t, end: t },
    tomorrow: { start: add(1), end: add(1) },
    week:     { start: t, end: add(6) },
    month:    { start: t, end: add(29) },
  };
};

// Keperluan setiap item untuk 4 tempoh — SATU round-trip DB (julat bulan),
// dibahagi 4 tempoh di client dari breakdown (session_date setiap baris).
// Dulu 4 round-trip berasingan (satu per tempoh) — tukar ni elak beban DB
// berganda setiap kali halaman item/senarai Inventori dibuka.
window.computeForecastHorizons = async function (itemIds) {
  const r = window.inventoryHorizonRanges();
  const full = await window.computeForecastForRange(itemIds, r.month.start, r.month.end);
  const sumInRange = (breakdown, start, end) => breakdown
    .filter(b => b.session_date && b.session_date.slice(0, 10) >= start && b.session_date.slice(0, 10) <= end)
    .reduce((a, b) => a + (Number(b.qty) || 0), 0);
  const out = {};
  (itemIds || []).forEach(id => {
    const bd = full[id]?.breakdown || [];
    out[id] = {
      today:    Math.ceil(sumInRange(bd, r.today.start, r.today.end)),
      tomorrow: Math.ceil(sumInRange(bd, r.tomorrow.start, r.tomorrow.end)),
      week:     Math.ceil(sumInRange(bd, r.week.start, r.week.end)),
      month:    Math.ceil(sumInRange(bd, r.month.start, r.month.end)),
      weekBreakdown: bd.filter(b => b.session_date && b.session_date.slice(0, 10) <= r.week.end),
      monthBreakdown: bd,
    };
  });
  return out;
};

// Lampirkan item.forecast_required + item.forecast_breakdown pada SETIAP item aktif (tiada
// lagi filter consumption_type='package' — semua item cuba dikira, sebab data sebenar yang
// tentukan sama ada ia "package-linked" atau tidak, bukan flag manual staff).
window.attachInventoryForecast = async function (items) {
  (items || []).forEach(i => { i.forecast_required = 0; i.forecast_breakdown = []; i.forecast = { today: 0, tomorrow: 0, week: 0, month: 0 }; });
  if (!items?.length) return items;

  const result = await window.computeForecastHorizons(items.map(i => i.id));
  items.forEach(i => {
    const f = result[i.id] || { today: 0, tomorrow: 0, week: 0, month: 0, weekBreakdown: [] };
    i.forecast = { today: f.today, tomorrow: f.tomorrow, week: f.week, month: f.month };
    i.forecast_required = f.tomorrow;
    // "Permintaan Berdasarkan Pakej" (kad senarai pesakit) tunjuk senarai PENUH bulan ini —
    // lebih berguna utk kad terperinci drpd had minggu sempit.
    i.forecast_breakdown = f.monthBreakdown;
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
