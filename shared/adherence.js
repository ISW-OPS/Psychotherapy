// ============================================================
// ADHERENCE HELPER — check patient madu compliance
// Spec: kurang madu 5x/hari selama 4+ hari → trigger alert ke coach
// ============================================================

const MADU_DAILY_TARGET_FALLBACK = 5;      // kalau pakej tak set
const MADU_LOW_DAYS_THRESHOLD = 4;          // 4+ hari berturut = trigger
const ADHERENCE_LOOKBACK_DAYS = 5;          // tengok 5 hari kebelakang
const MADU_KEYWORD = /madu/i;

// Helper: get list of last N dates (YYYY-MM-DD) including today
function lastNDates(n) {
  const out = [];
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  for (let i = 0; i < n; i++) {
    out.push(d.toISOString().slice(0, 10));
    d.setDate(d.getDate() - 1);
  }
  return out;
}

// Kira madu adherence patient dalam tempoh lookback days
// Returns: { target, perDay: [{date, count, isBelow}], daysBelow, isLowAdherence }
async function checkMaduAdherence(patientId, packageId) {
  if (!patientId || !window.db) return null;

  // 1. Get target dari pakej
  let target = MADU_DAILY_TARGET_FALLBACK;
  if (packageId) {
    try {
      const { data } = await window.db.from('psy_packages')
        .select('madu_frequency_per_day').eq('package_id', packageId).limit(1);
      if (data?.[0]?.madu_frequency_per_day) target = Number(data[0].madu_frequency_per_day);
    } catch (e) { /* fallback */ }
  }

  // 2. Get last 5 days daily_completions
  const since = new Date(); since.setDate(since.getDate() - ADHERENCE_LOOKBACK_DAYS);
  const sinceStr = since.toISOString().slice(0, 10);
  const { data: completions } = await window.db.from('psy_daily_completions')
    .select('log_date, activity')
    .eq('patient_id', patientId)
    .gte('log_date', sinceStr);

  // 3. Count madu per day
  const dates = lastNDates(ADHERENCE_LOOKBACK_DAYS);
  const perDay = dates.map(date => {
    const count = (completions || []).filter(c =>
      c.log_date === date && MADU_KEYWORD.test(c.activity || '')
    ).length;
    return { date, count, isBelow: count < target };
  });

  // 4. Count days below target (lookback period)
  const daysBelow = perDay.filter(d => d.isBelow).length;
  const isLowAdherence = daysBelow >= MADU_LOW_DAYS_THRESHOLD;

  return { target, perDay, daysBelow, isLowAdherence };
}

// Trigger alert kalau low adherence. Auto-dedup via UNIQUE constraint.
async function triggerMaduAlert(patientRecord, adherenceResult) {
  if (!adherenceResult?.isLowAdherence) return null;
  const today = new Date().toISOString().slice(0, 10);
  const alertType = `madu_low_${adherenceResult.daysBelow}days`;

  try {
    const { data, error } = await window.db.from('psy_adherence_alerts').insert({
      patient_id:   patientRecord.id,
      alert_type:   alertType,
      trigger_date: today,
      details: {
        target: adherenceResult.target,
        days_below: adherenceResult.daysBelow,
        per_day: adherenceResult.perDay,
      },
      notified_coach_id: patientRecord.coach_id || null,
    }).select().single();

    if (error) {
      // UNIQUE constraint hit — alert dah ada hari ini
      if (error.code === '23505') return null;
      throw error;
    }

    // Notify coach
    if (patientRecord.coach_id) {
      await notify(patientRecord.coach_id, 'plan',
        `⚠️ ${patientRecord.full_name || 'Patient'} — Kurang Madu`,
        `Kurang madu ${adherenceResult.daysBelow} hari berturut (target ${adherenceResult.target}/hari). Sila tindak.`,
        'assignments.html');
    }

    return data;
  } catch (e) { console.error('Adherence alert failed:', e); return null; }
}

if (typeof window !== 'undefined') {
  window.checkMaduAdherence = checkMaduAdherence;
  window.triggerMaduAlert = triggerMaduAlert;
  window.MADU_LOW_DAYS_THRESHOLD = MADU_LOW_DAYS_THRESHOLD;
  window.ADHERENCE_LOOKBACK_DAYS = ADHERENCE_LOOKBACK_DAYS;
}
