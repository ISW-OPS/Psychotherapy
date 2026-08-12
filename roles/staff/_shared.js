// ============================================================
// STAFF SHARED LOGIC — common code across all staff pages
// ============================================================

window.currentUser = null;

async function initStaff(pageId, titleSub, rbacId) {
  window.currentUser = await checkAuth('staff');
  if (!window.currentUser) return null;

  const staffRole = window.currentUser.staff_role;

  // Akses dikawal sepenuhnya oleh RBAC DB (psy_role_module_actions).
  // super_admin bypass semua; dashboard sentiasa allow.
  // rbacId: bila pageId ialah sub-menu (cth auto_dashboard), semak kebenaran
  // terhadap modul INDUK (cth auto_messages) supaya tak perlu daftar setiap anak.
  const permId = rbacId || pageId;
  if (staffRole !== 'super_admin' && permId !== 'dashboard') {
    if (!window.pageAllowed(permId)) {
      alert('Akses ditolak. Anda tidak mempunyai kebenaran untuk halaman ini.');
      window.location.href = 'dashboard.html';
      return null;
    }
  }

  document.getElementById('app-loading')?.classList.add('hidden');
  document.getElementById('app-shell')?.classList.remove('hidden');

  // Apply role colour theme
  if (staffRole) document.body.classList.add('role-' + staffRole);

  // activeScreen = pageId (highlight sub-menu); navbar akan kembang induknya.
  renderNavbar('staff', window.currentUser, null, pageId);

  // Cari label — cuba item induk, kemudian anak.
  const items = getNavItems('staff', staffRole);
  let nav = items.find(n => n.id === pageId);
  if (!nav) { for (const it of items) { const c = (it.children||[]).find(x => x.id === pageId); if (c) { nav = c; break; } } }
  renderHeader(nav?.label || titleSub || '', titleSub || '');

  return window.currentUser;
}

// ==================== HELPERS ====================
function statCard(label, value, sub, color = 'role') {
  const borderStyle = color === 'role'
    ? 'style="border-top-color: var(--rpm)"'
    : '';
  const borderClass = color === 'role' ? 'border-t-4' : `border-t-4 border-${color}`;
  return `<div class="bg-white rounded-xl p-4 ${borderClass}" ${borderStyle}>
    <div class="text-[10px] uppercase text-ink/60 font-semibold">${label}</div>
    <div class="text-2xl font-bold mt-1">${value}</div>
    <div class="text-[10px] text-ink/60 mt-2">${sub || ''}</div>
  </div>`;
}

function chip(text, color = 'navy') {
  const colors = {
    navy: 'bg-navy-light text-navy',
    green: 'bg-green-light text-green-dark',
    gold: 'bg-gold/30 text-gold-dark',
    terracotta: 'bg-terracotta-light text-terracotta',
    teal: 'bg-teal/10 text-teal',
    grey: 'bg-ink/10 text-ink/60',
  };
  return `<span class="chip ${colors[color] || colors.grey}">${text}</span>`;
}

const STATUS_LABELS = {
  active:       'Aktif',
  pending_kyc:  'Pending Pendaftaran',
  inactive:     'Tidak Aktif',
  rejected:     'Ditolak',
  deleted:      'Dipadam',
  unregistered: 'Belum Aktif',
  archived:     'Diarkibkan',
  deceased:     'Meninggal',
  pending:      'Pending',
  approved:     'Diluluskan',
  scheduled:    'Dijadualkan',
  completed:    'Selesai',
  cancelled:    'Dibatalkan',
  no_show:      'Tidak Hadir',
  in_progress:  'Sedang Berjalan',
  checked_in:   'Daftar Masuk',
  draft:        'Draf',
  signed:       'Ditandatangan',
  open:         'Terbuka',
  acknowledged: 'Diakui',
  resolved:     'Diselesaikan',
  resulted:     'Keputusan Ada',
  reviewed:     'Disemak',
  ordered:      'Dipesan',
};

// ── Paparan identiti pesakit — SATU sumber kebenaran ──────────────────────
// psy_profiles (akaun) vs psy_patients (rekod klinikal) menyimpan nama/telefon/
// emel yang bertindih. Untuk elak "silap panggil", SEMUA halaman baca melalui
// helper ini dengan keutamaan SAMA: profil (akaun) dulu → psy_patients → kyc.
// Terima `patient` (mungkin ada join .psy_profiles / .profile), dan `profile`/`kyc`
// pilihan bila diberi berasingan (cth patient-hub).
function _iswProf(patient, profile) {
  return profile || patient?.psy_profiles || patient?.profile || null;
}
window.iswPatientName = function (patient, profile, kyc) {
  const pr = _iswProf(patient, profile);
  return pr?.full_name || patient?.full_name || kyc?.patient_name || kyc?.full_name || '';
};
window.iswPatientPhone = function (patient, profile, kyc) {
  const pr = _iswProf(patient, profile);
  return pr?.phone || patient?.phone || kyc?.phone || patient?.emergency_contact_phone || '';
};
window.iswPatientEmail = function (patient, profile, kyc) {
  const pr = _iswProf(patient, profile);
  return pr?.email || patient?.email || '';
};

function statusChip(s) {
  const m = {
    scheduled:    'bg-navy-light text-navy',
    completed:    'bg-green-light text-green-dark',
    cancelled:    'bg-ink/10 text-ink/60',
    no_show:      'bg-terracotta/20 text-terracotta',
    pending:      'bg-gold/30 text-gold-dark',
    approved:     'bg-green-light text-green-dark',
    rejected:     'bg-terracotta/20 text-terracotta',
    open:         'bg-terracotta/20 text-terracotta',
    in_progress:  'bg-navy-light text-navy',
    checked_in:   'bg-gold/30 text-gold-dark',
    active:       'bg-green-light text-green-dark',
    resulted:     'bg-gold/30 text-gold-dark',
    reviewed:     'bg-green-light text-green-dark',
    ordered:      'bg-navy-light text-navy',
    draft:        'bg-ink/10 text-ink/60',
    signed:       'bg-green-light text-green-dark',
    acknowledged: 'bg-navy-light text-navy',
    resolved:     'bg-green-light text-green-dark',
    unregistered: 'bg-amber-100 text-amber-800',
    inactive:     'bg-ink/10 text-ink/50',
  };
  const label = STATUS_LABELS[s] || s;
  return `<span class="chip ${m[s] || 'bg-ink/10 text-ink/60'}">${label}</span>`;
}

function outcomeChip(o) {
  if (!o) return '';
  const map = {
    otw:       { label: 'Sedang Berjalan', cls: 'bg-navy-light text-navy' },
    completed: { label: 'Selesai',       cls: 'bg-green-light text-green-dark' },
    berhenti:  { label: 'Berhenti',      cls: 'bg-gold/30 text-gold-dark' },
    meninggal: { label: 'Meninggal',     cls: 'bg-ink/15 text-ink/70' },
  };
  const v = map[o];
  if (!v) return '';
  return `<span class="chip ${v.cls}" title="Outcome rawatan">${v.label}</span>`;
}

function formatDate(d) { return new Date(d).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' }); }
function formatTime(d) { return new Date(d).toLocaleTimeString('en-GB', { hour:'2-digit', minute:'2-digit' }); }
function formatDateTime(d) { return new Date(d).toLocaleString('en-GB', { day:'2-digit', month:'short', hour:'2-digit', minute:'2-digit' }); }

function timeAgo(d) {
  const diff = Date.now() - new Date(d).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 60) return `${m} min lalu`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h} jam lalu`;
  return `${Math.floor(h / 24)} hari lalu`;
}

function banner(msg, type = 'ok') {
  const el = document.createElement('div');
  const color = type === 'error' ? 'bg-terracotta' : 'bg-green';
  el.className = `fixed top-4 left-1/2 -translate-x-1/2 ${color} text-white px-5 py-2.5 rounded-xl text-sm font-semibold z-50 shadow-lg`;
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), type === 'error' ? 6000 : 2500);
}
