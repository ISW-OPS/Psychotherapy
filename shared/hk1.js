// ============================================================
// hk1.js — helper kongsi utk booking Sesi 1:1 (Hakeema/Hakeem/Dr Session)
// Dipakai oleh sesi-1on1.html (+ Tambah Sesi) & patient-hub.html (+ Tambah per kad).
// Borang Nota/Saranan/WA/follow-up (konsultasi) TIDAK di sini — kekal berasingan
// (plan-week.html versi sendiri keyed ikut type/minggu; patient-hub.html versi
// sendiri keyed ikut record id, sbb boleh ada >1 rekod sejarah per jenis).
// ============================================================

// fisioterapi/kaunselor/bekam/masseur: boleh ada LEBIH DARIPADA SATU staff per role (tak
// macam hakeema/hakeem/dr yang auto-resolve seorang sahaja ikut nama/role unik) — multiTarget:
// true tandakan UI perlu papar dropdown "pilih coach" supaya staff pilih sendiri yang mana
// handle, bukan auto-resolve senyap. Role code 'coach' — semua 4 jenis sesi ni dikendalikan
// oleh staff role Coach sedia ada (tiada role RBAC berasingan fisioterapi/kaunselor/bekam/
// masseur), target_role simpan sbg label jenis sesi sahaja (write-only, tak difilter di mana-mana).
const HK1_TYPES_META = {
  hakeema:     { label: 'Hakeema Session',     emoji: '🧑‍💼', role: 'manager', nameLike: 'hakeema', exclude: null,      fallback: 'Hakeema', multiTarget: false },
  hakeem:      { label: 'Hakeem Session',      emoji: '🧑',   role: 'manager', nameLike: 'hakeem',  exclude: 'hakeema', fallback: 'Hakeem', multiTarget: false },
  dr:          { label: 'Dr Session',          emoji: '🩺',   role: 'doctor',  nameLike: null,      exclude: null,      fallback: 'Dr', multiTarget: false },
  fisioterapi: { label: 'Fisioterapi Session', emoji: '🏃',   role: 'coach',   nameLike: null,      exclude: null,      fallback: 'Fisioterapi', multiTarget: true },
  kaunselor:   { label: 'Kaunselor Session',   emoji: '🗣️',   role: 'coach',   nameLike: null,      exclude: null,      fallback: 'Kaunselor', multiTarget: true },
  bekam:       { label: 'Bekam Session',       emoji: '🩸',   role: 'coach',   nameLike: null,      exclude: null,      fallback: 'Bekam', multiTarget: true },
  masseur:     { label: 'Masseur Session',     emoji: '💆',   role: 'coach',   nameLike: null,      exclude: null,      fallback: 'Tukang Urut', multiTarget: true },
};
window.HK1_TYPES_META = HK1_TYPES_META;

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

// Pecahkan SATU baris blok kepada slot diskret (2:00-2:30, 2:30-3:00, ...) bila
// slot_duration_minutes + max_bookings dikonfigur (Jadual Slot Konsultasi redesign, 7 Okt 2026).
// Tiada duration/kapasiti = mod lama, blok kekal utuh (1 entry = 1 blok, macam KOB/Rawatan).
function hk1ExpandBlock(r) {
  const start = (r.slot_start || '').slice(0, 5), end = (r.slot_end || '').slice(0, 5);
  if (!r.slot_duration_minutes || !r.max_bookings) return [{ start, end, label: r.label }];
  const [h0, m0] = start.split(':').map(Number);
  const pad2 = n => String(n).padStart(2, '0');
  const fmt = mins => `${pad2(Math.floor(mins / 60) % 24)}:${pad2(mins % 60)}`;
  const out = [];
  for (let i = 0; i < r.max_bookings; i++) {
    const sMin = h0 * 60 + m0 + i * r.slot_duration_minutes;
    const s = fmt(sMin), e = fmt(sMin + r.slot_duration_minutes);
    out.push({ start: s, end: e, label: `${s}-${e}` });
  }
  return out;
}

// Panggil sekali di init page (await) sebelum hk1GetSlotsForDay()/hk1GetAllowedDays() dipakai.
let _hk1SlotBlocksCache = null;
async function hk1LoadSlotConfig(force = false) {
  if (_hk1SlotBlocksCache && !force) return _hk1SlotBlocksCache;
  const { data, error } = await window.db.from('psy_kob_slot_config')
    .select('day_of_week, slot_start, slot_end, label, max_bookings, slot_duration_minutes')
    .eq('slot_type', 'sesi_1on1').eq('is_active', true);
  if (error) {
    console.error('[hk1] hk1LoadSlotConfig gagal, guna fallback:', error);
    _hk1SlotBlocksCache = HK1_SLOTS_DEFAULT_BLOCKS;
    return _hk1SlotBlocksCache;
  }
  const byDay = {};
  (data || []).forEach(r => {
    (byDay[r.day_of_week] = byDay[r.day_of_week] || []).push(...hk1ExpandBlock(r));
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
// Audit #B1-30 (Tier 4) — dulu cuma semak sesama Sesi 1:1, TAK semak psy_appointments
// (Kalendar & Jadual). Kini semak DUA-DUA supaya Hakeema/Hakeem/Dr tak overlap dengan
// appointment biasa (KOB, DNA consultation dll) pada masa sama.
async function hk1CheckSlotConflict(targetId, meetDate, scheduledTime) {
  if (!targetId || !scheduledTime) return false;
  const [hk1Res, apptRes] = await Promise.all([
    window.db.from('psy_clinical_referrals')
      .select('id, consultation')
      .eq('source', 'plan_1on1').eq('target_id', targetId).eq('meet_date', meetDate)
      .neq('status', 'declined'),
    window.db.from('psy_appointments')
      .select('id')
      .eq('staff_id', targetId)
      .gte('appointment_time', `${meetDate}T${scheduledTime}:00`)
      .lt('appointment_time', `${meetDate}T${scheduledTime}:59`)
      .not('status', 'in', '("cancelled","no_show")'),
  ]);
  if (hk1Res.error || apptRes.error) {
    // Safety-critical (cegah double-booking) — jangan senyap-senyap anggap "tiada konflik"
    // bila query sendiri gagal. Biar caller anggap konflik & block submit.
    console.error('[hk1] hk1CheckSlotConflict gagal:', hk1Res.error || apptRes.error);
    return true;
  }
  const hk1Conflict = (hk1Res.data || []).some(r => r.consultation?.scheduled_time === scheduledTime);
  const apptConflict = (apptRes.data || []).length > 0;
  return hk1Conflict || apptConflict;
}
window.hk1CheckSlotConflict = hk1CheckSlotConflict;

// Auto-cipta SEMUA rekod Sesi 1:1 (psy_clinical_referrals, source='plan_1on1') untuk SETIAP
// minggu dalam coaching_schedule yang ada hk1_types, SERTA-MERTA bila treatment plan pesakit
// dicipta — bukan tunggu staf buka plan-week.html minggu tu (lazy-on-open lama). Dipanggil oleh
// mana-mana laluan yang insert psy_treatment_plans baharu (kob-detail.html markSelesai/
// activateKobPackage, patients.html/patient-form.html seedStaffTreatmentPlan).
// Unique index uq_psy_clinical_referrals_plan_1on1 (plan_id, week_number, session_type) jadi
// benteng kedua kalau fungsi ni terpanggil dua kali / race — ralat kod 23505 diabaikan senyap.
// loadHk1() di plan-week.html (per-minggu, bila dibuka) KEKAL sebagai safety net — kalau-kalau
// ada minggu yang terlepas (cth pakej diubah lepas plan dicipta).
async function hk1SeedForPlan(planId, patientId, coachingSchedule, referredBy = null, referredByName = null) {
  const sched = Array.isArray(coachingSchedule) ? coachingSchedule : [];
  for (const entry of sched) {
    const weekNum = Number(entry?.week ?? entry?.day);
    if (!weekNum) continue;
    const types = Array.isArray(entry?.hk1_types) ? entry.hk1_types.filter(t => HK1_TYPES_META[t]) : [];
    for (const type of types) {
      const cfg = HK1_TYPES_META[type];
      const target = await hk1ResolveTarget(type);
      const { error } = await window.db.from('psy_clinical_referrals').insert({
        patient_id: patientId, plan_id: planId, week_number: weekNum, source: 'plan_1on1', session_type: type,
        referred_by: referredBy, referred_by_name: referredByName,
        target_role: cfg.role, target_id: target.id, target_name: target.name,
        reason: `Sesi 1:1 ${cfg.label} — ${entry?.period === 'day' ? `D${weekNum}` : window.iswPeriodLabel(weekNum)} (Wajib ikut Pakej)`, meet_date: null, priority: 'sederhana',
      });
      if (error && error.code !== '23505') console.error('[hk1] hk1SeedForPlan gagal:', weekNum, type, error);
    }
  }
}
window.hk1SeedForPlan = hk1SeedForPlan;
