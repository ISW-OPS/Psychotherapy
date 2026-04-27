// ============================================================
// STAFF SHARED LOGIC — common code across all staff pages
// ============================================================

window.currentUser = null;

// Pages yang boleh diakses oleh setiap staff_role
const STAFF_ROLE_ACCESS = {
  admin:   ['dashboard','assignments','psy_patients','kyc_forms','psy_appointments','pakej','psy_products','psy_orders','library','services','audit','staff_mgmt','announcements','staff_stats','issue','profile'],
  doctor:  ['dashboard','psy_patients','kyc_forms','plans','psy_appointments','consultation','psy_vitals','risk','library','issue','profile'],
  coach:   ['dashboard','assignments','psy_patients','plans','psy_appointments','consultation','psy_vitals','coaching','risk','issue','profile','patient_hub','plan_week'],
  manager: ['dashboard','assignments','psy_patients','kyc_forms','plans','psy_appointments','psy_orders','audit','announcements','staff_stats','issue','profile'],
};

async function initStaff(pageId, titleSub) {
  window.currentUser = await checkAuth('staff');
  if (!window.currentUser) return null;

  const staffRole = window.currentUser.staff_role;

  // Semak akses — redirect ke dashboard jika tak ada kebenaran
  if (staffRole && pageId !== 'dashboard') {
    const allowed = STAFF_ROLE_ACCESS[staffRole] || [];
    if (!allowed.includes(pageId)) {
      alert('Akses ditolak. Anda tidak mempunyai kebenaran untuk halaman ini.');
      window.location.href = 'dashboard.html';
      return null;
    }
  }

  document.getElementById('app-loading')?.classList.add('hidden');
  document.getElementById('app-shell')?.classList.remove('hidden');

  renderNavbar('staff', window.currentUser, null, pageId);

  const nav = getNavItems('staff', staffRole).find(n => n.id === pageId);
  renderHeader(nav?.label || '', titleSub || '');

  return window.currentUser;
}

// ==================== HELPERS ====================
function statCard(label, value, sub, color = 'navy') {
  return `<div class="bg-white rounded-xl p-4 border-t-4 border-${color}">
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

function statusChip(s) {
  const m = {
    scheduled:'bg-navy-light text-navy', completed:'bg-green-light text-green-dark',
    cancelled:'bg-ink/10 text-ink/60', no_show:'bg-terracotta/20 text-terracotta',
    pending:'bg-gold/30 text-gold-dark', approved:'bg-green-light text-green-dark',
    rejected:'bg-terracotta/20 text-terracotta', open:'bg-terracotta/20 text-terracotta',
    in_progress:'bg-navy-light text-navy', checked_in:'bg-gold/30 text-gold-dark',
    active:'bg-green-light text-green-dark', resulted:'bg-gold/30 text-gold-dark',
    reviewed:'bg-green-light text-green-dark', ordered:'bg-navy-light text-navy',
    draft:'bg-ink/10 text-ink/60', signed:'bg-green-light text-green-dark',
    acknowledged:'bg-navy-light text-navy', resolved:'bg-green-light text-green-dark',
  };
  return `<span class="chip ${m[s] || 'bg-ink/10 text-ink/60'}">${s}</span>`;
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
  setTimeout(() => el.remove(), 2500);
}
