// ============================================================
// NAVBAR — central nav config & renderer for ALL roles
// Edit NAV_ITEMS_BY_ROLE untuk tukar/tambah menu items
// ============================================================

const NAV_ITEMS_BY_ROLE = {
  patient: [
    { id: 'dashboard', url: 'dashboard.html', icon: '🏠', label: 'Dashboard' },
    { id: 'pakej', url: 'pakej.html', icon: '📦', label: 'Pakej Rawatan' },
    { id: 'shop', url: 'shop.html', icon: '🛒', label: 'Shop' },
    { id: 'appointments', url: 'appointments.html', icon: '📅', label: 'Appointments' },
    { id: 'payment', url: 'payment.html', icon: '💳', label: 'Payment & Receipt' },
    { id: 'checkin', url: 'checkin.html', icon: '✅', label: 'Daily Check-in' },
    { id: 'plan', url: 'plan.html', icon: '💊', label: 'Treatment Plan' },  
    { id: 'sessions', url: 'sessions.html', icon: '📝', label: 'Session History' },
    { id: 'library', url: 'library.html', icon: '📚', label: 'Self-Help Library' },
    { id: 'feedback', url: 'feedback.html', icon: '⭐', label: 'Feedback' },
    { id: 'issue', url: 'issue.html', icon: '⚠️', label: 'Report Issue' },
    { id: 'profile', url: 'profile.html', icon: '👤', label: 'Profile & Consent' },
  ],
  staff: [
    { id: 'dashboard', url: 'dashboard.html', icon: '🏥', label: 'Dashboard' },
    { id: 'patients', url: 'patients.html', icon: '👥', label: 'Patients & KYC' },
    { id: 'appointments', url: 'appointments.html', icon: '📅', label: 'Appointments' },
    { id: 'consultation', url: 'consultation.html', icon: '🩺', label: 'Consultation' },
    { id: 'vitals', url: 'vitals.html', icon: '📊', label: 'Vitals Capture' },
    { id: 'coaching', url: 'coaching.html', icon: '🎯', label: 'Coaching Sessions' },
    { id: 'plans', url: 'plans.html', icon: '📋', label: 'Treatment Plans' },
    { id: 'risk', url: 'risk.html', icon: '⚠️', label: 'Risk Alerts' },
    { id: 'audit', url: 'audit.html', icon: '🔒', label: 'Audit Log' },
    { id: 'staff_mgmt', url: 'staff_management.html', icon: '👨‍⚕️', label: 'Manage Staff' },
    { id: 'profile', url: 'profile.html', icon: '👤', label: 'Profile' },
  ],
};

const ROLE_CONFIG = {
  patient: { label: 'My Health', icon: '🏥' },
  staff: { label: 'Staff Portal', icon: '⚕' },
};

// Get nav items for a role (used by _shared.js for backwards compat)
function getNavItems(role) {
  return NAV_ITEMS_BY_ROLE[role] || [];
}

function renderNavbar(role, user, navItems, activeScreen) {
  // If navItems not passed, look up from central config
  if (!navItems) navItems = NAV_ITEMS_BY_ROLE[role] || [];

  const cfg = ROLE_CONFIG[role] || ROLE_CONFIG.patient;
  const initials = (user.full_name || 'U').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase();

  const sidebar = document.getElementById('sidebar');
  if (!sidebar) return;

  // Auto-detect base path for logo (works from /roles/patient/ or /roles/staff/)
  const logoPath = window.location.pathname.includes('/roles/') ? '../../image/Logo_ISW.png' : 'image/Logo_ISW.png';

  sidebar.innerHTML = `
    <div class="nav-brand p-4 border-b border-white/10 flex items-center gap-3">
      <div class="w-10 h-10 bg-white rounded-xl flex items-center justify-center flex-shrink-0 p-1">
        <img src="${logoPath}" alt="ISW" class="w-full h-full object-contain" onerror="this.outerHTML='<span class=\\'text-white text-lg\\'>${cfg.icon}</span>'">
      </div>
      <div class="nav-text-block">
        <div class="font-bold text-sm text-white">Ibnu Sina Wellness</div>
        <div class="text-[10px] text-white/60">${cfg.label} · v1.0</div>
      </div>
    </div>
    <div class="nav-user p-3 border-b border-white/10">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center font-bold text-white flex-shrink-0" title="${user.full_name || 'User'}">${initials}</div>
        <div class="flex-1 min-w-0 nav-text-block">
          <div class="text-sm font-semibold text-white truncate">${user.full_name || 'User'}</div>
          <div class="text-[11px] text-white/60">${user.specialization || user.role}</div>
        </div>
      </div>
    </div>
    <nav class="flex-1 overflow-y-auto p-2 space-y-0.5">
      ${navItems.map(item => `
        <button onclick="goTo('${item.id}')" title="${item.label}"
          class="nav-item ${item.id === activeScreen ? 'active' : ''} w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-white/80 hover:bg-white/10">
          <span class="flex-shrink-0">${item.icon}</span><span class="nav-label">${item.label}</span>
          ${item.badge ? `<span class="ml-auto nav-label inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold ${item.badgeClass || 'bg-white/20 text-white'}">${item.badge}</span>` : ''}
        </button>
      `).join('')}
    </nav>
    <div class="nav-footer p-3 border-t border-white/10">
      <button onclick="logout()" class="w-full text-xs text-white/70 py-2 hover:bg-white/5 rounded-lg" title="Log Keluar">
        <span class="nav-label">Log Keluar</span>
        <span class="nav-icon-only hidden">⎋</span>
      </button>
    </div>
  `;
}

function renderHeader(title, subtitle) {
  const header = document.getElementById('page-header');
  if (!header) return;
  header.innerHTML = `
    <div>
      <h2 id="page-title" class="font-bold text-base lg:text-lg">${title}</h2>
      <p id="page-sub" class="text-[11px] text-ink/60">${subtitle}</p>
    </div>
    <div class="flex items-center gap-3">
      <button class="relative p-2 hover:bg-gray-100 rounded-lg">
        <span class="text-lg">🔔</span>
      </button>
    </div>
  `;
}

function goTo(screen) {
  // Multi-page mode: look up URL from central nav config
  for (const role of Object.keys(NAV_ITEMS_BY_ROLE)) {
    const item = NAV_ITEMS_BY_ROLE[role].find(n => n.id === screen);
    if (item && item.url) {
      window.location.href = item.url;
      return;
    }
  }

  // SPA fallback: switch sections within same page
  document.querySelectorAll('main .screen').forEach(s => s.classList.remove('active'));
  const target = document.getElementById(screen);
  if (target) target.classList.add('active');
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  const activeNav = document.querySelector(`.nav-item[onclick*="'${screen}'"]`);
  if (activeNav) activeNav.classList.add('active');
  if (typeof onScreenChange === 'function') onScreenChange(screen);
  window.scrollTo({ top: 0, behavior: 'smooth' });
}
