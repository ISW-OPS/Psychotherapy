// ============================================================
// SCHEDULE PERIOD — skema tempoh pakej bertingkat (Minggu → Bulan → Suku Tahun)
// ------------------------------------------------------------
// coaching_schedule (pakej-edit.html) ialah SATU senarai berjujukan, index
// 1-based "period" (= field `week` bila unit='week'). Makna tiap period
// berubah ikut kedudukannya, bukan disimpan sebagai field berasingan:
//   period 1-12  → W1-W12  (mingguan,  jarak 7 hari/period)
//   period 13-15 → M1-M3   (bulanan,   jarak 28 hari/period, ~4 minggu)
//   period 16+   → Q1,Q2…  (suku tahun, jarak 84 hari/period, ~12 minggu)
// Hanya terpakai untuk pakej unit='week'. Pakej unit='day' (D1, D2…) tak
// guna skema ni langsung — setiap "period" di situ ialah 1 hari kalendar.
//
// SEMUA tempat yang kira tarikh sesi dari week_number (plan.html penjana,
// plan-week.html paparan julat, patient-hub.html) MESTI guna fungsi di sini
// supaya offset hari konsisten merentas sistem — jangan re-derive (w-1)*7
// terus lagi.
// ============================================================

const ISW_PERIOD_TIER_END = { week: 12, month: 15 }; // quarter = selepas ni, tiada had atas

function iswPeriodType(period) {
  if (period <= ISW_PERIOD_TIER_END.week) return 'week';
  if (period <= ISW_PERIOD_TIER_END.month) return 'month';
  return 'quarter';
}

function iswPeriodSpanDays(period) {
  const t = iswPeriodType(period);
  return t === 'week' ? 7 : t === 'month' ? 28 : 84;
}

// Jumlah hari dari permulaan period 1 hinggalah PERMULAAN `period` yang diminta
// (period 1 → offset 0). Guna ni gantikan terus (w-1)*7 lama.
function iswPeriodOffsetDays(period) {
  let days = 0;
  for (let p = 1; p < period; p++) days += iswPeriodSpanDays(p);
  return days;
}

// Beza hari antara dua period (boleh negatif) — guna ni gantikan (w - anchorWeek) * 7
// lama bila unjur tarikh dari mana-mana anchor period (bukan semestinya period 1).
function iswPeriodOffsetBetween(fromPeriod, toPeriod) {
  return iswPeriodOffsetDays(toPeriod) - iswPeriodOffsetDays(fromPeriod);
}

// Label papar: W1..W12, M1..M3, Q1, Q2, Q3…
function iswPeriodLabel(period) {
  const t = iswPeriodType(period);
  if (t === 'week') return `W${period}`;
  if (t === 'month') return `M${period - ISW_PERIOD_TIER_END.week}`;
  return `Q${period - ISW_PERIOD_TIER_END.month}`;
}

// Kebalikan iswPeriodOffsetDays — diberi jumlah hari berlalu dari period 1,
// pulangkan period number yang merangkumi hari tersebut (utk reverse-derive
// "ini minggu/bulan/suku keberapa" dari tarikh sebenar, cth patient-hub.html).
function iswPeriodFromOffsetDays(elapsedDays) {
  let period = 1, used = 0;
  while (used + iswPeriodSpanDays(period) <= elapsedDays) {
    used += iswPeriodSpanDays(period);
    period++;
  }
  return period;
}

window.iswPeriodType = iswPeriodType;
window.iswPeriodSpanDays = iswPeriodSpanDays;
window.iswPeriodOffsetDays = iswPeriodOffsetDays;
window.iswPeriodOffsetBetween = iswPeriodOffsetBetween;
window.iswPeriodLabel = iswPeriodLabel;
window.iswPeriodFromOffsetDays = iswPeriodFromOffsetDays;
