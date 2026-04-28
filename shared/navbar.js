// ============================================================
// NAVBAR — central nav config & renderer for ALL roles
// Edit NAV_ITEMS_BY_ROLE untuk tukar/tambah menu items
// ============================================================

const NAV_ITEMS_BY_ROLE = {
  patient: [
    { id: 'dashboard', url: 'dashboard.html', icon: '🏠', label: 'Dashboard' },
    { id: 'plan', url: 'plan.html', icon: '💊', label: 'My Treatment Plan' },
    { id: 'checkin', url: 'checkin.html', icon: '✅', label: 'Daily Check-in' },
    { id: 'library', url: 'library.html', icon: '📚', label: 'Self-Help Library' },
    { id: 'pakej', url: 'pakej.html', icon: '🗂️', label: 'Pakej Rawatan' },
    { id: 'shop', url: 'shop.html', icon: '🛒', label: 'Product' },
    { id: 'payment', url: 'payment.html', icon: '💳', label: 'Payment' },
    { id: 'psy_orders', url: 'orders.html', icon: '📦', label: 'Orders & Tracking' },
    { id: 'issue', url: 'issue.html', icon: '⚠️', label: 'Report Issue' },
    { id: 'kyc', url: 'kyc.html', icon: '🆔', label: 'KYC Form' },
    { id: 'profile', url: 'profile.html', icon: '👤', label: 'Profile' },
  ],

  // Staff: Admin — system management focus
  staff_admin: [
    { id: 'dashboard',    url: 'dashboard.html',        icon: '🏥', label: 'Dashboard' },
    { id: 'psy_patients', url: 'patients.html',         icon: '👥', label: 'Patients' },
    { id: 'kyc_forms',    url: 'kyc-list.html',         icon: '🆔', label: 'KYC Form' },
    { id: 'psy_appointments', url: 'appointments.html', icon: '📅', label: 'Jadual Sesi' },
    { id: 'pakej',        url: 'pakej.html',            icon: '🗂️', label: 'Pakej Rawatan' },
    { id: 'psy_products', url: 'products.html',         icon: '🛒', label: 'Products' },
    { id: 'psy_orders',   url: 'orders.html',           icon: '📦', label: 'Orders & Tracking' },
    { id: 'library',      url: 'library.html',          icon: '📚', label: 'Self-Help Library' },
    { id: 'staff_mgmt',     url: 'staff_management.html', icon: '👨‍⚕️', label: 'Manage Staff' },
    { id: 'announcements', url: 'announcements.html',   icon: '📢', label: 'Pengumuman' },
    { id: 'inventory',     url: 'inventory.html',       icon: '🏭', label: 'Inventori' },
    { id: 'issue',         url: 'issue.html',           icon: '⚠️', label: 'Report Issue' },
    { id: 'profile',       url: 'profile.html',         icon: '👤', label: 'Profile' },
  ],

  // Staff: Coach — patient-centric nav (clinical details via Patient Hub)
  staff_coach: [
    { id: 'dashboard',       url: 'dashboard.html',    icon: '🏥', label: 'Dashboard' },
    { id: 'assignments',     url: 'assignments.html',  icon: '👥', label: 'Patients' },
    { id: 'psy_appointments',url: 'appointments.html', icon: '📅', label: 'Jadual Sesi' },
    { id: 'coaching',        url: 'coaching.html',     icon: '🎯', label: 'Sesi Coaching' },
    { id: 'plan_week',       url: 'plan-week.html',    icon: '📋', label: 'Weekly Plan' },
    { id: 'issue',           url: 'issue.html',        icon: '⚠️', label: 'Report Issue' },
    { id: 'profile',         url: 'profile.html',      icon: '👤', label: 'Profile' },
  ],

  // Staff: Doctor — clinical + KYC review
  staff_doctor: [
    { id: 'dashboard',       url: 'dashboard.html',    icon: '🏥', label: 'Dashboard' },
    { id: 'psy_patients',    url: 'patients.html',     icon: '👥', label: 'Patients' },
    { id: 'kyc_forms',       url: 'kyc-list.html',     icon: '🆔', label: 'KYC Form' },
    { id: 'plans',           url: 'plans.html',        icon: '📋', label: 'Treatment Plans' },
    { id: 'psy_appointments',url: 'appointments.html', icon: '📅', label: 'Jadual Sesi' },
    { id: 'consultation',    url: 'consultation.html', icon: '🩺', label: 'Consultation' },
    { id: 'psy_vitals',      url: 'vitals.html',       icon: '📊', label: 'Vitals Capture' },
    { id: 'risk',            url: 'risk.html',         icon: '🚨', label: 'Risk Management' },
    { id: 'issue',           url: 'issue.html',        icon: '⚠️', label: 'Report Issue' },
    { id: 'profile',         url: 'profile.html',      icon: '👤', label: 'Profile' },
  ],

  // Staff: Manager — oversight & reports only
  staff_manager: [
    { id: 'dashboard',    url: 'dashboard.html',        icon: '🏥', label: 'Dashboard' },
    { id: 'assignments',  url: 'assignments.html',       icon: '🤝', label: 'Penugasan Pesakit' },
    { id: 'psy_patients', url: 'patients.html',         icon: '👥', label: 'Patients' },
    { id: 'kyc_forms',    url: 'kyc-list.html',         icon: '🆔', label: 'KYC Form' },
    { id: 'plans',        url: 'plans.html',            icon: '📋', label: 'Treatment Plans' },
    { id: 'psy_appointments', url: 'appointments.html', icon: '📅', label: 'Jadual Sesi' },
    { id: 'psy_orders',    url: 'orders.html',            icon: '📦', label: 'Orders & Tracking' },
    { id: 'announcements', url: 'announcements.html',   icon: '📢', label: 'Pengumuman' },
    { id: 'staff_stats',   url: 'staff-stats.html',     icon: '📈', label: 'Statistik Staff' },
    { id: 'inventory',     url: 'inventory.html',       icon: '🏭', label: 'Inventori' },
    { id: 'issue',         url: 'issue.html',           icon: '⚠️', label: 'Report Issue' },
    { id: 'profile',       url: 'profile.html',         icon: '👤', label: 'Profile' },
  ],

  // Fallback jika staff_role tidak diset
  staff: [
    { id: 'dashboard', url: 'dashboard.html', icon: '🏥', label: 'Dashboard' },
    { id: 'profile', url: 'profile.html', icon: '👤', label: 'Profile' },
  ],
};

const ROLE_CONFIG = {
  patient: { label: 'My Health', icon: '🏥' },
  staff_admin: { label: 'Admin Portal', icon: '⚕' },
  staff_coach: { label: 'Coach Portal', icon: '⚕' },
  staff_doctor: { label: 'Doctor Portal', icon: '⚕' },
  staff_manager: { label: 'Manager Portal', icon: '⚕' },
  staff: { label: 'Staff Portal', icon: '⚕' },
};

const STAFF_ROLE_BADGE = {
  admin:   { label: 'Admin',   cls: 'role-accent-bg' },
  coach:   { label: 'Coach',   cls: 'role-accent-bg' },
  doctor:  { label: 'Doctor',  cls: 'role-accent-bg' },
  manager: { label: 'Manager', cls: 'role-accent-bg' },
};

// Get nav items for a role — pass staffRole for staff sub-roles
function getNavItems(role, staffRole) {
  if (role === 'staff' && staffRole) {
    return NAV_ITEMS_BY_ROLE[`staff_${staffRole}`] || NAV_ITEMS_BY_ROLE.staff;
  }
  return NAV_ITEMS_BY_ROLE[role] || [];
}

// Check if staff has access to a page
function staffCanAccess(staffRole, pageId) {
  const items = getNavItems('staff', staffRole);
  return items.some(n => n.id === pageId);
}

function renderNavbar(role, user, navItems, activeScreen) {
  // Determine effective role key for staff sub-roles
  const staffRole = user.staff_role || null;
  const roleKey = (role === 'staff' && staffRole) ? `staff_${staffRole}` : role;

  // If navItems not passed, look up from central config
  if (!navItems) navItems = getNavItems(role, staffRole);

  const cfg = ROLE_CONFIG[roleKey] || ROLE_CONFIG[role] || ROLE_CONFIG.patient;
  const initials = (user.full_name || 'U').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase();
  const badge = role === 'staff' && staffRole ? STAFF_ROLE_BADGE[staffRole] : null;

  const sidebar = document.getElementById('sidebar');
  if (!sidebar) return;

  // Inject mobile sidebar overlay (once per page)
  if (!document.getElementById('mob-sidebar-overlay')) {
    const ol = document.createElement('div');
    ol.id = 'mob-sidebar-overlay';
    ol.onclick = closeMobileSidebar;
    document.body.appendChild(ol);
  }

  // Patient: inject persistent bottom nav bar (once per page)
  if (role === 'patient' && !document.getElementById('pat-bottom-nav')) {
    const BOT_ITEMS = [
      { href: 'dashboard.html', icon: '🏠', label: 'Home',     id: 'dashboard' },
      { href: 'plan.html',      icon: '💊', label: 'Plan',     id: 'plan' },
      { href: 'checkin.html',   icon: '✅', label: 'Check-in', id: 'checkin' },
      { href: 'shop.html',      icon: '🛒', label: 'Shop',     id: 'shop' },
      { href: 'profile.html',   icon: '👤', label: 'Profil',   id: 'profile' },
    ];
    const nav = document.createElement('nav');
    nav.id = 'pat-bottom-nav';
    nav.className = 'mobile-nav fixed bottom-0 left-0 right-0 bg-navy-dark border-t border-white/10 text-white flex justify-around z-20';
    nav.innerHTML = BOT_ITEMS.map(it =>
      `<a href="${it.href}" class="flex flex-col items-center justify-center gap-0.5 py-2 px-1 flex-1 text-[10px] ${it.id === activeScreen ? 'text-gold font-semibold' : 'text-white/65'}">
        <span class="text-lg leading-none">${it.icon}</span>${it.label}
      </a>`
    ).join('');
    document.body.appendChild(nav);
  }

  // Auto-detect base path for logo (works from /roles/patient/ or /roles/staff/)
  const logoPath = window.location.pathname.includes('/roles/') ? '../../image/Logo_ISW.png' : 'image/Logo_ISW.png';

  const isStaff = role === 'staff';

  if (isStaff) {
    // ── WHITE sidebar for staff — role colour only on active item ──
    sidebar.innerHTML = `
      <div class="nav-brand px-4 py-3 border-b border-ink/8 flex items-center gap-3">
        <div class="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 p-1 overflow-hidden" style="background:var(--rpl)">
          <img src="${logoPath}" alt="ISW" class="w-full h-full object-contain" onerror="this.outerHTML='<span style=\\'color:var(--rpm)\\' class=\\'text-lg font-bold\\'>${cfg.icon}</span>'">
        </div>
        <div class="nav-text-block">
          <div class="font-bold text-sm text-ink">Ibnu Sina Wellness</div>
          <div class="text-[10px] text-ink/40">${cfg.label}</div>
        </div>
      </div>
      <div class="nav-user px-3 py-3 border-b border-ink/8">
        <div class="flex items-center gap-3">
          <div class="w-9 h-9 rounded-full flex items-center justify-center font-bold text-white text-sm flex-shrink-0"
               style="background:var(--rpm)" title="${user.full_name || 'User'}">${initials}</div>
          <div class="flex-1 min-w-0 nav-text-block">
            <div class="flex items-center gap-1.5 flex-wrap">
              <span class="text-sm font-semibold text-ink truncate">${user.full_name || 'User'}</span>
              ${badge ? `<span class="text-[9px] font-bold px-1.5 py-0.5 rounded-full flex-shrink-0 role-accent-bg">${badge.label}</span>` : ''}
            </div>
            <div class="text-[11px] text-ink/40">${user.specialization || ''}</div>
          </div>
        </div>
      </div>
      <nav class="flex-1 overflow-y-auto p-2 space-y-0.5">
        ${navItems.map(item => `
          <button onclick="goTo('${item.id}')" title="${item.label}"
            class="nav-item ${item.id === activeScreen ? 'active' : ''} w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-ink/60 hover:bg-ink/5 transition-colors">
            <span class="flex-shrink-0 text-base">${item.icon}</span>
            <span class="nav-label font-medium">${item.label}</span>
            ${item.badge ? `<span class="ml-auto nav-label inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold bg-ink/10 text-ink/60">${item.badge}</span>` : ''}
          </button>
        `).join('')}
      </nav>
      <div class="nav-footer p-3 border-t border-ink/8">
        <button onclick="logout()" class="w-full text-xs text-ink/40 hover:text-ink/70 py-2 hover:bg-ink/5 rounded-lg transition-colors" title="Log Keluar">
          <span class="nav-label">Log Keluar</span>
          <span class="nav-icon-only hidden">⎋</span>
        </button>
      </div>
    `;
  } else {
    // ── DARK sidebar for patient (original) ──
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
}

function setHeaderBack(url, label) {
  const rightDiv = document.querySelector('#page-header > div:last-child');
  if (!rightDiv) return;
  const existing = document.getElementById('header-back-btn');
  if (existing) existing.remove();
  const a = document.createElement('a');
  a.id = 'header-back-btn';
  a.href = url;
  a.className = 'flex items-center gap-1.5 text-xs font-medium text-ink/60 hover:text-navy border border-ink/20 hover:border-navy px-3 py-1.5 rounded-lg transition-colors whitespace-nowrap';
  a.innerHTML = '← ' + (label || 'Kembali');
  rightDiv.prepend(a);
}

function renderHeader(title, subtitle) {
  const header = document.getElementById('page-header');
  if (!header) return;
  header.innerHTML = `
    <div class="flex items-center gap-3 min-w-0">
      <button onclick="toggleMobileSidebar()" aria-label="Menu"
        class="flex-shrink-0 md:hidden w-9 h-9 flex items-center justify-center rounded-lg hover:bg-ink/8 text-ink/60">
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
          <path d="M2 4h14M2 9h14M2 14h14"/>
        </svg>
      </button>
      <div class="min-w-0">
        <h2 id="page-title" class="font-bold text-base lg:text-lg truncate">${title}</h2>
        <p id="page-sub" class="text-[11px] text-ink/60 truncate">${subtitle}</p>
      </div>
    </div>
    <div class="flex items-center gap-3 flex-shrink-0">
      <button id="notif-btn" onclick="toggleNotifPanel()" class="relative p-2 hover:bg-gray-100 rounded-lg">
        <span class="text-lg">🔔</span>
        <span id="notif-badge" class="hidden absolute -top-0.5 -right-0.5 min-w-[16px] h-4 bg-terracotta text-white text-[9px] font-bold rounded-full flex items-center justify-center px-0.5"></span>
      </button>
    </div>
  `;
  // Inject panel into body once
  if (!document.getElementById('notif-panel')) {
    const panel = document.createElement('div');
    panel.id = 'notif-panel';
    panel.className = 'hidden fixed inset-0 z-50';
    panel.innerHTML = `
      <div class="absolute inset-0" onclick="closeNotifPanel()"></div>
      <div id="notif-drawer" class="absolute top-0 right-0 bottom-0 w-full max-w-sm bg-white shadow-2xl flex flex-col translate-x-full transition-transform duration-300">
        <div class="px-5 py-4 border-b border-ink/10 flex items-center justify-between">
          <h3 class="font-bold">Notifikasi</h3>
          <div class="flex items-center gap-3">
            <button onclick="markAllRead()" class="text-xs text-navy hover:underline">Baca semua</button>
            <button onclick="closeNotifPanel()" class="text-ink/50 text-xl leading-none">×</button>
          </div>
        </div>
        <div id="notif-list" class="flex-1 overflow-y-auto divide-y divide-ink/5"></div>
      </div>`;
    document.body.appendChild(panel);
  }
  loadNotifBadge();
}

const NOTIF_ICONS = { appointment: '📅', order: '📦', plan: '💊', system: '📢', default: '🔔' };

async function loadNotifBadge() {
  if (!window.db) return;
  const { data } = await window.db.from('psy_notifications')
    .select('id', { count: 'exact' }).eq('user_id', (await window.db.auth.getUser()).data.user?.id).eq('is_read', false);
  const count = data?.length || 0;
  const badge = document.getElementById('notif-badge');
  if (!badge) return;
  if (count > 0) { badge.textContent = count > 9 ? '9+' : count; badge.classList.remove('hidden'); }
  else badge.classList.add('hidden');
}

async function loadNotifPanel() {
  const list = document.getElementById('notif-list');
  if (!list) return;
  list.innerHTML = '<div class="p-4 text-sm text-ink/40 text-center py-10">Memuatkan...</div>';
  const uid = (await window.db.auth.getUser()).data.user?.id;
  const { data: notifs } = await window.db.from('psy_notifications')
    .select('*').eq('user_id', uid).order('created_at', { ascending: false }).limit(30);
  const items = notifs || [];
  list.innerHTML = items.length ? items.map(n => `
    <div onclick="readNotif('${n.id}','${n.link || ''}')"
      class="px-5 py-4 cursor-pointer hover:bg-cream transition-colors ${n.is_read ? 'opacity-60' : 'bg-navy-light/30'}">
      <div class="flex items-start gap-3">
        <span class="text-xl flex-shrink-0 mt-0.5">${NOTIF_ICONS[n.type] || NOTIF_ICONS.default}</span>
        <div class="flex-1 min-w-0">
          <div class="text-sm font-semibold leading-snug">${n.title}</div>
          ${n.body ? `<div class="text-xs text-ink/60 mt-0.5">${n.body}</div>` : ''}
          <div class="text-[10px] text-ink/40 mt-1">${new Date(n.created_at).toLocaleString('ms-MY',{day:'2-digit',month:'short',hour:'2-digit',minute:'2-digit'})}</div>
        </div>
        ${!n.is_read ? '<span class="w-2 h-2 bg-navy rounded-full flex-shrink-0 mt-2"></span>' : ''}
      </div>
    </div>`).join('')
    : '<div class="text-sm text-ink/40 text-center py-16">Tiada notifikasi</div>';
}

async function readNotif(id, link) {
  await window.db.from('psy_notifications').update({ is_read: true }).eq('id', id);
  loadNotifBadge();
  if (link) { closeNotifPanel(); window.location.href = link; }
  else loadNotifPanel();
}

async function markAllRead() {
  const uid = (await window.db.auth.getUser()).data.user?.id;
  await window.db.from('psy_notifications').update({ is_read: true }).eq('user_id', uid).eq('is_read', false);
  loadNotifBadge();
  loadNotifPanel();
}

function toggleNotifPanel() {
  const panel = document.getElementById('notif-panel');
  const drawer = document.getElementById('notif-drawer');
  if (!panel || !drawer) return;
  const isHidden = panel.classList.contains('hidden');
  panel.classList.toggle('hidden', !isHidden);
  requestAnimationFrame(() => {
    drawer.style.transform = isHidden ? 'translateX(0)' : 'translateX(100%)';
  });
  if (isHidden) loadNotifPanel();
}

// Helper — insert a notification row (fire-and-forget)
async function notify(userId, type, title, body, link) {
  if (!window.db || !userId) return;
  try { await window.db.from('psy_notifications').insert({ user_id: userId, type, title, body: body || null, link: link || null }); }
  catch (e) { console.warn('notify failed:', e.message); }
}

function closeNotifPanel() {
  const panel = document.getElementById('notif-panel');
  const drawer = document.getElementById('notif-drawer');
  if (!panel || !drawer) return;
  drawer.style.transform = 'translateX(100%)';
  setTimeout(() => panel.classList.add('hidden'), 300);
}

function toggleMobileSidebar() {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('mob-sidebar-overlay');
  if (!sidebar || !overlay) return;
  const opening = !sidebar.classList.contains('mob-open');
  sidebar.classList.toggle('mob-open', opening);
  overlay.classList.toggle('visible', opening);
}

function closeMobileSidebar() {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('mob-sidebar-overlay');
  if (!sidebar || !overlay) return;
  sidebar.classList.remove('mob-open');
  overlay.classList.remove('visible');
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
