// ============================================================
// hk1.js — helper kongsi utk booking Sesi 1:1 (Hakeema/Hakeem/Dr Session)
// Dipakai oleh sesi-1on1.html (+ Tambah Sesi) & patient-hub.html (+ Tambah per kad).
// Borang Nota/Saranan/WA/follow-up (konsultasi) TIDAK di sini — kekal berasingan
// (plan-week.html versi sendiri keyed ikut type/minggu; patient-hub.html versi
// sendiri keyed ikut record id, sbb boleh ada >1 rekod sejarah per jenis).
// ============================================================

const HK1_TYPES_META = {
  hakeema: { label: 'Hakeema Session', emoji: '🧑‍💼', role: 'manager', nameLike: 'hakeema', exclude: null,      fallback: 'Hakeema' },
  hakeem:  { label: 'Hakeem Session',  emoji: '🧑',          role: 'manager', nameLike: 'hakeem',  exclude: 'hakeema', fallback: 'Hakeem' },
  dr:      { label: 'Dr Session',      emoji: '🩺',          role: 'doctor',  nameLike: null,      exclude: null,      fallback: 'Dr' },
};

async function hk1ResolveTarget(type) {
  const cfg = HK1_TYPES_META[type];
  const { data } = await window.db.from('psy_profiles')
    .select('id, full_name').eq('role', 'staff').eq('staff_role', cfg.role);
  const list = data || [];
  let match = cfg.nameLike ? list.find(p => {
    const nm = (p.full_name || '').toLowerCase();
    if (!nm.includes(cfg.nameLike)) return false;
    if (cfg.exclude && nm.includes(cfg.exclude)) return false;
    return true;
  }) : null;
  if (!match && list.length === 1) match = list[0];
  return { id: match?.id || null, name: match?.full_name || cfg.fallback };
}
window.hk1ResolveTarget = hk1ResolveTarget;

// Slot Sesi 1:1 — baris-per-blok dari `psy_kob_slot_config` (slot_type='sesi_1on1'),
// SAMA model macam Slot KOB/Rawatan (diurus kad "C. Slot Sesi 1:1" di kob-slots.html,
// "+ Tambah Slot" reuse penuh UI/logik sedia ada). BUKAN lagi generator pagi/petang+tempoh
// (jadual psy_hk1_slot_config DIBUANG 24 Ogos — model tu dirasakan mengelirukan staff).
// Setiap blok (cth "9-12 pg") = SATU slot boleh-tempah per hari per target (Hakeema/Hakeem/
// Dr tak boleh 2 sesi serentak dlm tetingkap sama) — bukan dipecah kepada minit diskret.
const HK1_SLOTS_DEFAULT_BLOCKS = {
  3: [{ start: '09:00', end: '12:00', label: '9-12 pg' }, { start: '14:00', end: '17:00', label: '2-5 ptg' }],
  4: [{ start: '09:00', end: '12:00', label: '9-12 pg' }, { start: '14:00', end: '17:00', label: '2-5 ptg' }],
  5: [{ start: '09:00', end: '12:00', label: '9-12 pg' }, { start: '14:00', end: '17:00', label: '2-5 ptg' }],
  6: [{ start: '09:00', end: '12:00', label: '9-12 pg' }, { start: '14:00', end: '17:00', label: '2-5 ptg' }],
  0: [{ start: '09:00', end: '12:00', label: '9-12 pg' }, { start: '14:00', end: '17:00', label: '2-5 ptg' }],
};

// Panggil sekali di init page (await) sebelum hk1GetSlotsForDay()/hk1GetAllowedDays() dipakai.
let _hk1SlotBlocksCache = null;
async function hk1LoadSlotConfig(force = false) {
  if (_hk1SlotBlocksCache && !force) return _hk1SlotBlocksCache;
  const { data, error } = await window.db.from('psy_kob_slot_config')
    .select('day_of_week, slot_start, slot_end, label')
    .eq('slot_type', 'sesi_1on1').eq('is_active', true);
  if (error) {
    console.error('[hk1] hk1LoadSlotConfig gagal, guna fallback:', error);
    _hk1SlotBlocksCache = HK1_SLOTS_DEFAULT_BLOCKS;
    return _hk1SlotBlocksCache;
  }
  const byDay = {};
  (data || []).forEach(r => {
    (byDay[r.day_of_week] = byDay[r.day_of_week] || []).push({
      start: (r.slot_start || '').slice(0, 5), end: (r.slot_end || '').slice(0, 5), label: r.label,
    });
  });
  Object.values(byDay).forEach(list => list.sort((a, b) => a.start.localeCompare(b.start)));
  _hk1SlotBlocksCache = Object.keys(byDay).length ? byDay : HK1_SLOTS_DEFAULT_BLOCKS;
  return _hk1SlotBlocksCache;
}
window.hk1LoadSlotConfig = hk1LoadSlotConfig;

function hk1GetSlotsForDay(dayOfWeek) {
  const byDay = _hk1SlotBlocksCache || HK1_SLOTS_DEFAULT_BLOCKS;
  return byDay[dayOfWeek] || [];
}
window.hk1GetSlotsForDay = hk1GetSlotsForDay;

function hk1GetAllowedDays() {
  const byDay = _hk1SlotBlocksCache || HK1_SLOTS_DEFAULT_BLOCKS;
  return Object.keys(byDay).filter(d => byDay[d].length).map(Number);
}
window.hk1GetAllowedDays = hk1GetAllowedDays;

// Cipta tempahan Sesi 1:1 (booking sahaja — Nota/Saranan diisi kemudian di patient-hub.html
// atau plan-week.html kalau pesakit ada plan aktif). plan_id/week_number NULL = tempahan
// berdiri sendiri (bukan auto-jana dari minggu plan). scheduledTime/durationMinutes/purpose
// disimpan dalam consultation JSONB (field sedia ada, tiada migration perlu).
async function hk1CreateBooking(type, { patientId, meetDate, reason, priority = 'sederhana', referredBy, referredByName, planId = null, weekNumber = null, scheduledTime = null, durationMinutes = null, purpose = null, targetId = null, targetName = null }) {
  const cfg = HK1_TYPES_META[type];
  const target = (targetId !== null) ? { id: targetId, name: targetName } : await hk1ResolveTarget(type);
  const consultation = {};
  if (scheduledTime) consultation.scheduled_time = scheduledTime;
  if (durationMinutes) consultation.duration_minutes = durationMinutes;
  if (purpose) consultation.purpose = purpose;
  return window.db.from('psy_clinical_referrals').insert({
    patient_id: patientId, plan_id: planId, week_number: weekNumber, source: 'plan_1on1', session_type: type,
    referred_by: referredBy, referred_by_name: referredByName,
    target_role: cfg.role, target_id: target.id, target_name: target.name,
    reason: reason || `Sesi 1:1 ${cfg.label}`, meet_date: meetDate, priority: priority || 'sederhana',
    consultation,
  }).select('*').single();
}
window.hk1CreateBooking = hk1CreateBooking;

// Semak konflik slot SEBENAR — query terus psy_clinical_referrals (bukan cache tempatan)
// supaya elak race condition antara buka borang & hantar. Panggil sekali lagi sejurus
// sebelum insert.
async function hk1CheckSlotConflict(targetId, meetDate, scheduledTime) {
  if (!targetId || !scheduledTime) return false;
  const { data, error } = await window.db.from('psy_clinical_referrals')
    .select('id, consultation')
    .eq('source', 'plan_1on1').eq('target_id', targetId).eq('meet_date', meetDate)
    .neq('status', 'declined');
  if (error) {
    // Safety-critical (cegah double-booking) — jangan senyap-senyap anggap "tiada konflik"
    // bila query sendiri gagal. Biar caller anggap konflik & block submit.
    console.error('[hk1] hk1CheckSlotConflict gagal:', error);
    return true;
  }
  return (data || []).some(r => r.consultation?.scheduled_time === scheduledTime);
}
window.hk1CheckSlotConflict = hk1CheckSlotConflict;
