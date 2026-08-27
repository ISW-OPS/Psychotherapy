function LCALE() { try { return (window.iswGetLang && window.iswGetLang() === 'ms') ? 'ms-MY' : 'en-GB'; } catch (e) { return 'en-GB'; } }
// ============================================================
// PERISTIWA PESAKIT — pemalar & helper kongsi (semua halaman peristiwa*)
// ============================================================

const PE_TYPES = {
  warded:           { lbl: 'Masuk Wad (Warded)',  icon: '🏥', cls: 'bg-terracotta/15 text-terracotta' },
  icu:              { lbl: 'ICU',                 icon: '🚨', cls: 'bg-purple-100 text-purple-700' },
  temujanji_doktor: { lbl: 'Temujanji Doktor',    icon: '🩺', cls: 'bg-amber-100 text-amber-700' },
  pembedahan:       { lbl: 'Pembedahan',          icon: '⚕️', cls: 'bg-blue-100 text-blue-700' },
  kecemasan:        { lbl: 'Kecemasan',           icon: '🆘', cls: 'bg-red-100 text-red-700' },
  kematian:         { lbl: 'Meninggal Dunia',     icon: '🕊️', cls: 'bg-ink/10 text-ink/70' },
  discaj:           { lbl: 'Discaj',              icon: '✅', cls: 'bg-green-100 text-green-700' },
  rehat_rumah:      { lbl: 'Rehat di Rumah',      icon: '🏠', cls: 'bg-teal/10 text-teal' },
};

// Prioriti auto ikut jenis (boleh di-override melalui Tetapan Sistem)
const PE_TYPE_PRIO = {
  kematian: 'critical', icu: 'critical', kecemasan: 'critical',
  warded: 'high', pembedahan: 'high',
  temujanji_doktor: 'medium',
  discaj: 'low', rehat_rumah: 'low',
};

const PE_PRIO_CLS = {
  critical: 'bg-red-100 text-red-700',
  high:     'bg-terracotta/15 text-terracotta',
  medium:   'bg-amber-100 text-amber-700',
  low:      'bg-green-100 text-green-700',
};

// Muat jenis peristiwa dari Tetapan Sistem (psy_settings.patient_event_types).
// Panggil SEBELUM render dropdown/chip. Tiada tetapan → guna lalai di atas.
async function peLoadTypes() {
  try {
    if (typeof iswLoadSettings === 'function') await iswLoadSettings();
    const list = (typeof iswGetSetting === 'function') ? iswGetSetting('patient_event_types', null) : null;
    if (!Array.isArray(list) || !list.length) return;
    const defaults = { ...PE_TYPES };
    Object.keys(PE_TYPES).forEach(k => delete PE_TYPES[k]);
    list.forEach(t => {
      if (!t || !t.key || !t.lbl) return;
      PE_TYPES[t.key] = {
        lbl: t.lbl,
        icon: t.icon || defaults[t.key]?.icon || '📌',
        cls: defaults[t.key]?.cls || PE_PRIO_CLS[t.prio] || 'bg-ink/10 text-ink/60',
        inactive: t.active === false,
      };
      PE_TYPE_PRIO[t.key] = t.prio || PE_TYPE_PRIO[t.key] || 'medium';
      if (t.date_lbl) PE_DATE_LBL[t.key] = t.date_lbl;
    });
  } catch (e) { console.warn('peLoadTypes:', e.message || e); }
}

// Jenis aktif sahaja (untuk dropdown borang cipta)
function peActiveTypes() {
  return Object.entries(PE_TYPES).filter(([, v]) => !v.inactive);
}

// Label tarikh kejadian ikut jenis peristiwa (borang + detail)
const PE_DATE_LBL = {
  warded:           'Tarikh Masuk Wad',
  icu:              'Tarikh Masuk ICU',
  temujanji_doktor: 'Tarikh Temujanji',
  pembedahan:       'Tarikh Pembedahan',
  kecemasan:        'Tarikh Kecemasan',
  kematian:         'Tarikh Kematian',
  discaj:           'Tarikh Discaj',
  rehat_rumah:      'Tarikh Mula Rehat',
};

const PE_PRIORITY = {
  critical: { lbl: 'Kritikal',  cls: 'bg-terracotta/15 text-terracotta' },
  high:     { lbl: 'Tinggi',    cls: 'bg-amber-100 text-amber-700' },
  medium:   { lbl: 'Sederhana', cls: 'bg-gold/20 text-gold-dark' },
  low:      { lbl: 'Rendah',    cls: 'bg-green-100 text-green-700' },
};

const PE_STATUS = {
  open:   { lbl: 'Terbuka', cls: 'bg-terracotta/15 text-terracotta' },
  closed: { lbl: 'Selesai', cls: 'bg-ink/10 text-ink/60' },
};

const PE_VISIT_STATUS = {
  pending:     { lbl: 'Pending',        cls: 'bg-amber-100 text-amber-700' },
  in_progress: { lbl: 'Sedang Dibuat',  cls: 'bg-navy-light text-navy' },
  completed:   { lbl: 'Selesai',        cls: 'bg-green-light text-green-dark' },
  cancelled:   { lbl: 'Dibatalkan',     cls: 'bg-ink/10 text-ink/50' },
  overdue:     { lbl: 'Lewat',          cls: 'bg-red-100 text-red-700' }, // derive sahaja
};

const PE_CONDITION = {
  sangat_lemah:  { lbl: 'Sangat Lemah',  icon: '😟', cls: 'border-terracotta text-terracotta' },
  lemah:         { lbl: 'Lemah',         icon: '🙁', cls: 'border-amber-400 text-amber-600' },
  stabil:        { lbl: 'Stabil',        icon: '😐', cls: 'border-gold text-gold-dark' },
  beransur_baik: { lbl: 'Beransur Baik', icon: '🙂', cls: 'border-green text-green-dark' },
  sangat_baik:   { lbl: 'Sangat Baik',   icon: '😄', cls: 'border-green-dark text-green-dark' },
};

const PE_VISIT_TYPES = {
  hospital:  'Lawatan Hospital',
  rumah:     'Lawatan Rumah',
  klinik:    'Lawatan Klinik',
  panggilan: 'Panggilan Telefon',
};

// Peranan staff yang boleh dinotifikasi (checkbox borang)
const PE_NOTIFY_ROLES = [
  { code: 'manager',     lbl: 'Manager' },
  { code: 'coach',       lbl: 'Coach (coach pesakit)' },
  { code: 'admin',       lbl: 'Admin / Operasi' },
  { code: 'doctor',      lbl: 'Doctor' },
  { code: 'super_admin', lbl: 'Super Admin' },
];

function peEsc(s) { return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

function peTypeChip(t) {
  const v = PE_TYPES[t] || { lbl: t, icon: '📌', cls: 'bg-ink/10 text-ink/60' };
  return `<span class="inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full ${v.cls}">${v.icon} ${v.lbl}</span>`;
}
function pePrioChip(p) {
  const v = PE_PRIORITY[p] || PE_PRIORITY.medium;
  return `<span class="text-[10px] font-bold px-2 py-0.5 rounded-full ${v.cls}">${v.lbl}</span>`;
}
function peStatusChip(s) {
  const v = PE_STATUS[s] || PE_STATUS.open;
  return `<span class="text-[10px] font-bold px-2 py-0.5 rounded-full ${v.cls}">${v.lbl}</span>`;
}
function peVisitStatusChip(s) {
  const v = PE_VISIT_STATUS[s] || PE_VISIT_STATUS.pending;
  return `<span class="text-[10px] font-bold px-2 py-0.5 rounded-full ${v.cls}">${v.lbl}</span>`;
}

function peFmtDate(d) {
  if (!d) return '—';
  return new Date(d + (String(d).length === 10 ? 'T00:00:00' : '')).toLocaleDateString(LCALE(), { day: '2-digit', month: 'short', year: 'numeric' });
}
function peFmtTime(t) {
  if (!t) return '';
  const [h, m] = String(t).split(':');
  const d = new Date(); d.setHours(+h, +m || 0);
  return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
}
function peFmtDT(ts) {
  if (!ts) return '—';
  return new Date(ts).toLocaleString(LCALE(), { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

// Nama pesakit dari row event dengan join psy_patients(+psy_profiles)
function pePatientName(ev) {
  const pt = ev?.psy_patients || {};
  return (typeof iswPatientName === 'function' && iswPatientName(pt)) || pt.full_name || pt.mrn || 'Pesakit';
}

// Lawatan dikira LEWAT bila masih pending/in_progress & tarikh dah lepas
function peVisitEffectiveStatus(v) {
  if (v.status === 'pending' || v.status === 'in_progress') {
    const today = new Date(); today.setHours(0, 0, 0, 0);
    if (new Date(v.visit_date + 'T00:00:00') < today) return 'overdue';
  }
  return v.status;
}

// Tulis satu entri timeline peristiwa
async function peLog(eventId, action, detail, visitId) {
  try {
    await window.db.from('psy_patient_event_logs').insert({
      event_id: eventId,
      visit_id: visitId || null,
      actor_id: window.currentUser?.id || null,
      actor_name: window.currentUser?.full_name || null,
      action, detail: detail || null,
    });
  } catch (e) { console.warn('peLog:', e.message); }
}

// Query asas event + join pesakit + profil staff assigned
const PE_SELECT = `*,
  psy_patients(id, full_name, mrn, phone, gender, date_of_birth, status, coach_id, user_id,
    psy_profiles!psy_patients_user_id_fkey(full_name, phone, email)),
  assigned:psy_profiles!psy_patient_events_assigned_to_fkey(id, full_name, staff_role),
  reporter:psy_profiles!psy_patient_events_reported_by_fkey(id, full_name, staff_role)`;

const PEV_SELECT = `*,
  psy_patient_events(id, event_type, priority, status, hospital_name, ward_room, need_visit,
    patient_id, psy_patients(id, full_name, mrn, user_id,
      psy_profiles!psy_patients_user_id_fkey(full_name))),
  visitor:psy_profiles!psy_patient_event_visits_visited_by_fkey(id, full_name, staff_role)`;

function peAge(dob) {
  if (!dob) return '';
  const diff = Date.now() - new Date(dob).getTime();
  return Math.floor(diff / (365.25 * 24 * 3600 * 1000)) + ' Tahun';
}
