// ============================================================
// NAVBAR — central nav config & renderer for ALL roles
// ============================================================

// ── Patient nav (flat list) ──────────────────────────────
const NAV_ITEMS_BY_ROLE = {
  patient: [
    { id: 'dashboard', url: 'dashboard.html', icon: '🏠', label: 'Dashboard' },
    { id: 'kob', url: 'kob.html', icon: '🩺', label: 'KOB' },
    { id: 'plan', url: 'plan.html', icon: '💊', label: 'My Treatment Plan' },
    { id: 'routine', url: 'routine.html', icon: '🕐', label: 'Jadual Harian' },
    { id: 'pakej', url: 'pakej.html', icon: '🗂️', label: 'Pakej Rawatan' },
    { id: 'checkin',    url: 'checkin.html',    icon: '✅', label: 'Daily Check-in' },
    { id: 'kepatuhan', url: 'kepatuhan.html', icon: '📊', label: 'Kepatuhan Saya' },
    { id: 'vitals',    url: 'vitals.html',    icon: '📉', label: 'Bacaan Saya' },
    { id: 'library', url: 'library.html', icon: '📚', label: 'Self-Help Library' },
    { id: 'shop', url: 'shop.html', icon: '🛒', label: 'Product' },
    { id: 'payment', url: 'payment.html', icon: '💳', label: 'Payment' },
    { id: 'psy_orders', url: 'orders.html', icon: '📦', label: 'Orders & Tracking' },
    { id: 'issue', url: 'issue.html', icon: '⚠️', label: 'Report Issue' },
    { id: 'pulangan', url: 'pulangan.html', icon: '🍯', label: 'Pulangan Botol' },
    { id: 'surat', url: 'surat.html', icon: '📜', label: 'Surat Rasmi' },
    { id: 'kyc', url: 'kyc.html', icon: '🆔', label: 'KYC Form' },
    { id: 'profile', url: 'profile.html', icon: '👤', label: 'Profile' },
  ],
  staff: [
    { id: 'dashboard', url: 'dashboard.html', icon: '🏥', label: 'Dashboard' },
    { id: 'profile', url: 'profile.html', icon: '👤', label: 'Profile' },
  ],
};

// ── Staff nav (grouped) ──────────────────────────────────
const NAV_GROUPS_BY_ROLE = {

  staff_admin: [
    { group: 'UTAMA', collapsible: false, items: [
      { id: 'dashboard',        url: 'dashboard.html',    icon: '🏠', label: 'Dashboard' },
      { id: 'psy_patients',     url: 'patients.html',     icon: '👥', label: 'Pesakit' },
      { id: 'kyc_forms',        url: 'kyc-list.html',     icon: '🆔', label: 'KYC & Onboarding' },
      { id: 'psy_appointments', url: 'appointments.html', icon: '📅', label: 'Kalendar & Jadual' },
      { id: 'kob_slots',        url: 'kob-slots.html',    icon: '⏰', label: 'Slot Klinik' },
      { id: 'kepatuhan',        url: 'kepatuhan.html',    icon: '📊', label: 'Kepatuhan' },
    ]},
    { group: 'OPERASI', collapsible: true, items: [
      { id: 'pakej',         url: 'pakej.html',         icon: '🗂️', label: 'Pakej Rawatan' },
      { id: 'psy_products',  url: 'products.html',      icon: '🛍️', label: 'Produk' },
      { id: 'inventory',     url: 'inventory.html',     icon: '🏭', label: 'Inventori' },
      { id: 'psy_orders',    url: 'orders.html',        icon: '📦', label: 'Orders & Tracking' },
      { id: 'surat',         url: 'surat.html',         icon: '📜', label: 'Surat Rasmi' },
    ]},
    { group: 'KOMUNIKASI', collapsible: true, items: [
      { id: 'announcements', url: 'announcements.html', icon: '📢', label: 'Pengumuman' },
      { id: 'library',       url: 'library.html',       icon: '📚', label: 'Self-Help Library' },
    ]},
    { group: 'KEWANGAN', collapsible: true, items: [
      { id: 'payment_admin', url: 'payment-admin.html', icon: '💳', label: 'Pembayaran' },
    ]},
    { group: 'LAPORAN', collapsible: true, items: [
      { id: 'governance',    url: 'governance.html',    icon: '📈', label: 'Governance' },
      { id: 'staff_stats',   url: 'staff-stats.html',   icon: '📊', label: 'Statistik & Analitik' },
      { id: 'pakej_laporan', url: 'pakej-laporan.html', icon: '📦', label: 'Laporan Pakej' },
      { id: 'audit',         url: 'audit.html',         icon: '🔒', label: 'Audit Log' },
    ]},
    { group: 'SISTEM', collapsible: true, items: [
      { id: 'staff_mgmt', url: 'staff_management.html', icon: '👨‍⚕️', label: 'Manage Staff' },
      { id: 'issue',      url: 'issue.html',            icon: '⚠️', label: 'Report Issue' },
      { id: 'profile',    url: 'profile.html',          icon: '👤', label: 'Profile' },
    ]},
  ],

  staff_manager: [
    { group: 'UTAMA', collapsible: false, items: [
      { id: 'dashboard',        url: 'dashboard.html',    icon: '🏠', label: 'Dashboard' },
      { id: 'psy_appointments', url: 'appointments.html', icon: '📅', label: 'Jadual Sesi' },
      { id: 'staff_stats',      url: 'staff-stats.html',  icon: '📈', label: 'Laporan Ringkas' },
    ]},
    { group: 'OPERASI KLINIK', collapsible: true, items: [
      { id: 'psy_patients', url: 'patients.html', icon: '👥', label: 'Pesakit' },
    ]},
    { group: 'INVENTORI & BEKALAN', collapsible: true, items: [
      { id: 'inventory',    url: 'inventory.html',    icon: '🏭', label: 'Inventori' },
      { id: 'psy_orders',   url: 'orders.html',       icon: '📦', label: 'Pesanan & Bekalan' },
      { id: 'pulangan',     url: 'pulangan.html',     icon: '🍯', label: 'Pulangan Botol' },
    ]},
    { group: 'KANDUNGAN', collapsible: true, items: [
      { id: 'announcements', url: 'announcements.html', icon: '📢', label: 'Pengumuman' },
      { id: 'surat',         url: 'surat.html',         icon: '📜', label: 'Surat Rasmi' },
    ]},
    { group: 'SISTEM', collapsible: true, items: [
      { id: 'issue',   url: 'issue.html',   icon: '⚠️', label: 'Report Issue' },
      { id: 'profile', url: 'profile.html', icon: '👤', label: 'Profile' },
    ]},
  ],

  staff_coach: [
    { group: 'UTAMA', collapsible: false, items: [
      { id: 'dashboard',        url: 'dashboard.html',    icon: '🏠', label: 'Dashboard' },
      { id: 'psy_appointments', url: 'appointments.html', icon: '📅', label: 'Jadual Sesi' },
      { id: 'plan_week',        url: 'weekly-plan.html',  icon: '📋', label: 'Weekly Plan' },
    ]},
    { group: 'OPERASI KLINIK', collapsible: true, items: [
      { id: 'assignments', url: 'assignments.html', icon: '👥', label: 'Patients' },
    ]},
    { group: 'INVENTORI & BEKALAN', collapsible: true, items: [
      { id: 'inventory',    url: 'inventory.html',    icon: '🏭', label: 'Inventori' },
      { id: 'pulangan',     url: 'pulangan.html',     icon: '🍯', label: 'Pulangan Botol' },
    ]},
    { group: 'KANDUNGAN', collapsible: true, items: [
      { id: 'surat', url: 'surat.html', icon: '📜', label: 'Surat Rasmi' },
    ]},
    { group: 'SISTEM', collapsible: true, items: [
      { id: 'issue',   url: 'issue.html',   icon: '⚠️', label: 'Report Issue' },
      { id: 'profile', url: 'profile.html', icon: '👤', label: 'Profile' },
    ]},
  ],

  staff_doctor: [
    { group: 'UTAMA', collapsible: false, items: [
      { id: 'dashboard',        url: 'dashboard.html',    icon: '🏠', label: 'Dashboard' },
      { id: 'psy_appointments', url: 'appointments.html', icon: '📅', label: 'Jadual Sesi' },
      { id: 'plan_week',        url: 'weekly-plan.html',  icon: '📋', label: 'Weekly Plan' },
    ]},
    { group: 'OPERASI KLINIK', collapsible: true, items: [
      { id: 'psy_patients', url: 'patients.html',  icon: '👥', label: 'Pesakit' },
      { id: 'kyc_forms',    url: 'kyc-list.html',  icon: '🆔', label: 'KYC Form' },
      { id: 'kob_list',     url: 'kob-list.html',  icon: '🩺', label: 'Rawatan & Sesi' },
      { id: 'kob_slots',    url: 'kob-slots.html', icon: '⏰', label: 'Slot Klinik' },
    ]},
    { group: 'INVENTORI & BEKALAN', collapsible: true, items: [
      { id: 'inventory',    url: 'inventory.html',    icon: '🏭', label: 'Inventori' },
    ]},
    { group: 'KANDUNGAN', collapsible: true, items: [
      { id: 'library',       url: 'library.html',       icon: '📖', label: 'Self-Help Library' },
      { id: 'announcements', url: 'announcements.html', icon: '📢', label: 'Pengumuman' },
      { id: 'surat',         url: 'surat.html',         icon: '📜', label: 'Surat Rasmi' },
    ]},
    { group: 'SISTEM', collapsible: true, items: [
      { id: 'issue',   url: 'issue.html',   icon: '⚠️', label: 'Report Issue' },
      { id: 'profile', url: 'profile.html', icon: '👤', label: 'Profile' },
    ]},
  ],
};

const ROLE_CONFIG = {
  patient:      { label: 'My Health',      icon: '🏥' },
  staff_admin:  { label: 'Admin Portal',   icon: '⚕' },
  staff_coach:  { label: 'Coach Portal',   icon: '⚕' },
  staff_doctor: { label: 'Doctor Portal',  icon: '⚕' },
  staff_manager:{ label: 'Manager Portal', icon: '⚕' },
  staff:        { label: 'Staff Portal',   icon: '⚕' },
};

const STAFF_ROLE_BADGE = {
  admin:   { label: 'Admin',   cls: 'role-accent-bg' },
  coach:   { label: 'Coach',   cls: 'role-accent-bg' },
  doctor:  { label: 'Doctor',  cls: 'role-accent-bg' },
  manager: { label: 'Manager', cls: 'role-accent-bg' },
};

// Get flat nav items for a role (for goTo, staffCanAccess, badge counts)
function getNavItems(role, staffRole) {
  if (role === 'staff' && staffRole) {
    const groups = NAV_GROUPS_BY_ROLE[`staff_${staffRole}`];
    if (groups) return groups.flatMap(g => g.items);
  }
  return NAV_ITEMS_BY_ROLE[role === 'staff' ? 'staff' : role] || [];
}

function staffCanAccess(staffRole, pageId) {
  return getNavItems('staff', staffRole).some(n => n.id === pageId);
}

// ── Render one nav group (staff sidebar) ─────────────────
function renderNavGroup(group, roleKey, activeScreen) {
  const safeId    = `${roleKey}_${group.group.replace(/[^a-zA-Z0-9]/g, '_')}`;
  const lsKey     = `isw_nav_${safeId}`;
  const hasActive = group.items.some(i => i.id === activeScreen);
  const collapsed = group.collapsible && !hasActive && localStorage.getItem(lsKey) === '1';

  const header = group.collapsible
    ? `<button onclick="toggleNavGroup('${safeId}')"
         class="w-full flex items-center justify-between px-3 py-1.5 rounded-lg hover:bg-ink/5 transition-colors">
         <span class="nav-label text-[9px] font-bold text-ink/30 uppercase tracking-widest">${group.group}</span>
         <svg id="ngc-${safeId}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"
           class="nav-label w-3 h-3 text-ink/25 transition-transform duration-200 flex-shrink-0 ${collapsed ? '-rotate-90' : ''}">
           <polyline points="6 9 12 15 18 9"/>
         </svg>
       </button>`
    : `<div class="px-3 py-1.5">
         <span class="nav-label text-[9px] font-bold text-ink/30 uppercase tracking-widest">${group.group}</span>
       </div>`;

  const items = group.items.map(item => `
    <button onclick="goTo('${item.id}')" title="${item.label}"
      class="nav-item ${item.id === activeScreen ? 'active' : ''} w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-ink/60 hover:bg-ink/5 transition-colors">
      <span class="flex-shrink-0 text-base">${item.icon}</span>
      <span class="nav-label font-medium">${item.label}</span>
      <span id="nav-badge-${item.id}" class="hidden ml-auto nav-label min-w-[18px] h-[18px] px-1 rounded-full text-[10px] font-bold bg-terracotta text-white flex items-center justify-center"></span>
    </button>`).join('');

  return `
    <div class="mb-1">
      ${header}
      <div id="ngi-${safeId}" class="${collapsed ? 'hidden' : ''} space-y-0.5 mt-0.5">
        ${items}
      </div>
    </div>`;
}

function toggleNavGroup(safeId) {
  const lsKey   = `isw_nav_${safeId}`;
  const items   = document.getElementById('ngi-' + safeId);
  const chevron = document.getElementById('ngc-' + safeId);
  if (!items) return;
  const isNowCollapsed = items.classList.toggle('hidden');
  if (chevron) chevron.classList.toggle('-rotate-90', isNowCollapsed);
  localStorage.setItem(lsKey, isNowCollapsed ? '1' : '0');
}

// ── Main navbar renderer ──────────────────────────────────
function renderNavbar(role, user, navItems, activeScreen) {
  const staffRole = user.staff_role || null;
  const roleKey   = (role === 'staff' && staffRole) ? `staff_${staffRole}` : role;

  if (!navItems) navItems = getNavItems(role, staffRole);

  const cfg      = ROLE_CONFIG[roleKey] || ROLE_CONFIG[role] || ROLE_CONFIG.patient;
  const initials = (user.full_name || 'U').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase();
  const badge    = role === 'staff' && staffRole ? STAFF_ROLE_BADGE[staffRole] : null;

  const sidebar = document.getElementById('sidebar');
  if (!sidebar) return;

  if (!document.getElementById('mob-sidebar-overlay')) {
    const ol = document.createElement('div');
    ol.id = 'mob-sidebar-overlay';
    ol.onclick = closeMobileSidebar;
    document.body.appendChild(ol);
  }

  // Patient: persistent bottom nav bar
  if (role === 'patient' && !document.getElementById('pat-bottom-nav')) {
    const BOT_ITEMS = [
      { href: 'dashboard.html', icon: '🏠', label: 'Home',     id: 'dashboard' },
      { href: 'plan.html',      icon: '💊', label: 'Plan',     id: 'plan' },
      { href: 'checkin.html',   icon: '✅', label: 'Check-in', id: 'checkin' },
      { href: 'shop.html',      icon: '🛒', label: 'Shop',     id: 'shop' },
      { href: 'profile.html',   icon: '👤', label: 'Profil',   id: 'profile' },
    ];
    if (!document.getElementById('pat-bottom-nav-style')) {
      const s = document.createElement('style');
      s.id = 'pat-bottom-nav-style';
      s.textContent = '#pat-bottom-nav { display:flex; } @media(min-width:768px){ #pat-bottom-nav { display:none !important; } }';
      document.head.appendChild(s);
    }
    const nav = document.createElement('nav');
    nav.id = 'pat-bottom-nav';
    nav.className = 'fixed bottom-0 left-0 right-0 bg-navy-dark border-t border-white/10 text-white flex justify-around z-20';
    nav.innerHTML = BOT_ITEMS.map(it =>
      `<a href="${it.href}" class="flex flex-col items-center justify-center gap-0.5 py-2 px-1 flex-1 text-[10px] ${it.id === activeScreen ? 'text-gold font-semibold' : 'text-white/65'}">
        <span class="text-lg leading-none">${it.icon}</span>${it.label}
      </a>`
    ).join('');
    document.body.appendChild(nav);
  }

  const logoPath = window.location.pathname.includes('/roles/') ? '../../image/Logo_ISW.png' : 'image/Logo_ISW.png';
  const isStaff  = role === 'staff';

  if (isStaff) {
    const groups   = NAV_GROUPS_BY_ROLE[roleKey] || [];
    const navHtml  = groups.length
      ? groups.map(g => renderNavGroup(g, roleKey, activeScreen)).join('')
      : navItems.map(item => `
          <button onclick="goTo('${item.id}')" title="${item.label}"
            class="nav-item ${item.id === activeScreen ? 'active' : ''} w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-ink/60 hover:bg-ink/5 transition-colors">
            <span class="flex-shrink-0 text-base">${item.icon}</span>
            <span class="nav-label font-medium">${item.label}</span>
            <span id="nav-badge-${item.id}" class="hidden ml-auto nav-label min-w-[18px] h-[18px] px-1 rounded-full text-[10px] font-bold bg-terracotta text-white flex items-center justify-center"></span>
          </button>`).join('');

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
      <nav class="flex-1 overflow-y-auto p-2 pt-3">
        ${navHtml}
      </nav>
      <div class="hidden md:flex flex-shrink-0 border-t border-ink/8 p-2">
        <button onclick="toggleSidebar()" title="Kecilkan/Besarkan"
          class="sidebar-collapse-btn w-full flex items-center justify-center gap-2 py-2 rounded-lg text-ink/40 hover:bg-ink/5 hover:text-ink/70 transition-all text-sm">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
            <polyline points="15 18 9 12 15 6"/>
          </svg>
          <span class="nav-label text-xs font-medium">Kecilkan</span>
        </button>
      </div>
    `;

    if (localStorage.getItem('isw_sidebar_collapsed') === '1') {
      sidebar.classList.add('collapsed');
    }

  } else {
    // Dark sidebar for patient
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
            <span class="flex-shrink-0">${item.icon}</span>
            <span class="nav-label">${item.label}</span>
            <span id="nav-badge-${item.id}" class="hidden ml-auto min-w-[18px] h-[18px] px-1 rounded-full text-[10px] font-bold bg-terracotta text-white flex items-center justify-center"></span>
          </button>
        `).join('')}
      </nav>
    `;
  }

  window.db?.auth.getUser().then(({ data }) => {
    const uid = data?.user?.id;
    if (uid) loadNavBadges(role, staffRole, uid);
  });
}

// ── Nav Badge Counts ─────────────────────────────────────
function setNavBadge(id, count) {
  const el = document.getElementById('nav-badge-' + id);
  if (!el) return;
  if (count > 0) {
    el.textContent = count > 99 ? '99+' : String(count);
    el.classList.remove('hidden');
  } else {
    el.classList.add('hidden');
  }
}

async function loadNavBadges(role, _staffRole, userId) {
  if (!window.db || !userId) return;
  try {
    if (role === 'staff') {
      const [ordersRes, kycRes, issuesRes, closedRes, invRes, kobRes, patientsRes] = await Promise.all([
        window.db.from('psy_orders').select('id', { count: 'exact', head: true }).in('status', ['paid', 'packed']),
        window.db.from('psy_kyc_submissions').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
        window.db.from('psy_audit_log').select('id').eq('action', 'issue.reported'),
        window.db.from('psy_audit_log').select('meta').eq('action', 'issue.closed'),
        window.db.from('psy_inventory_requests').select('id', { count: 'exact', head: true }).eq('status', 'pending_approval'),
        window.db.from('psy_kob_sessions').select('id', { count: 'exact', head: true }).eq('status', 'booked'),
        window.db.from('psy_patients').select('id', { count: 'exact', head: true }).eq('status', 'pending_kyc'),
      ]);

      setNavBadge('psy_orders', ordersRes.count || 0);
      setNavBadge('kyc_forms', kycRes.count || 0);
      setNavBadge('inventory', invRes.count || 0);
      setNavBadge('kob_list', kobRes.count || 0);
      setNavBadge('psy_patients', patientsRes.count || 0);

      const closedIds = new Set((closedRes.data || []).map(r => r.meta?.issue_id).filter(Boolean));
      const openCount = (issuesRes.data || []).filter(i => !closedIds.has(i.id)).length;
      setNavBadge('issue', openCount);

    } else if (role === 'patient') {
      const [ordersRes, issuesRes, closedRes, patRes] = await Promise.all([
        window.db.from('psy_orders').select('id', { count: 'exact', head: true }).eq('patient_id', userId).in('status', ['pending', 'paid', 'packed', 'shipped']),
        window.db.from('psy_audit_log').select('id, meta').eq('action', 'issue.reported').eq('user_id', userId),
        window.db.from('psy_audit_log').select('meta').eq('action', 'issue.closed'),
        window.db.from('psy_patients').select('kob_status, status').eq('user_id', userId).maybeSingle(),
      ]);

      setNavBadge('psy_orders', ordersRes.count || 0);

      const kobStatus = patRes.data?.kob_status;
      if (kobStatus && kobStatus !== 'na' && kobStatus !== 'completed') setNavBadge('kob', 1);
      if (patRes.data?.status === 'pending_kyc') setNavBadge('kyc', 1);

      const closedIds = new Set((closedRes.data || []).map(r => r.meta?.issue_id).filter(Boolean));
      const openCount = (issuesRes.data || []).filter(i => !closedIds.has(i.id)).length;
      setNavBadge('issue', openCount);
    }
  } catch (e) {}
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

function setPageTitle(title, subtitle) {
  const t = document.getElementById('page-title');
  const s = document.getElementById('page-sub');
  if (t && title) t.textContent = title;
  if (s && subtitle !== undefined) s.textContent = subtitle;
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
    <div class="flex items-center gap-2 flex-shrink-0">
      <button id="notif-btn" onclick="toggleNotifPanel()" class="relative p-2 hover:bg-gray-100 rounded-lg" title="Notifikasi">
        <span class="text-lg">🔔</span>
        <span id="notif-badge" class="hidden absolute -top-0.5 -right-0.5 min-w-[16px] h-4 bg-terracotta text-white text-[9px] font-bold rounded-full flex items-center justify-center px-0.5"></span>
      </button>
      <button onclick="logout()" title="Log Keluar"
        class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold text-ink/60 hover:text-terracotta hover:bg-terracotta/10 border border-ink/10 hover:border-terracotta/30 transition-colors">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>
        </svg>
        <span class="hidden sm:inline">Log Keluar</span>
      </button>
    </div>
  `;
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
  const panel  = document.getElementById('notif-panel');
  const drawer = document.getElementById('notif-drawer');
  if (!panel || !drawer) return;
  const isHidden = panel.classList.contains('hidden');
  panel.classList.toggle('hidden', !isHidden);
  requestAnimationFrame(() => { drawer.style.transform = isHidden ? 'translateX(0)' : 'translateX(100%)'; });
  if (isHidden) loadNotifPanel();
}

async function notify(userId, type, title, body, link) {
  if (!window.db || !userId) return;
  try { await window.db.from('psy_notifications').insert({ user_id: userId, type, title, body: body || null, link: link || null }); }
  catch (e) { console.warn('notify failed:', e.message); }
}

function closeNotifPanel() {
  const panel  = document.getElementById('notif-panel');
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

function toggleSidebar() {
  const sidebar = document.getElementById('sidebar');
  if (!sidebar) return;
  const collapsed = sidebar.classList.toggle('collapsed');
  localStorage.setItem('isw_sidebar_collapsed', collapsed ? '1' : '0');
}

function goTo(screen) {
  // Search in grouped staff nav
  for (const groups of Object.values(NAV_GROUPS_BY_ROLE)) {
    for (const g of groups) {
      const found = g.items.find(n => n.id === screen);
      if (found?.url) { window.location.href = found.url; return; }
    }
  }
  // Patient flat nav
  const patItem = (NAV_ITEMS_BY_ROLE.patient || []).find(n => n.id === screen);
  if (patItem?.url) { window.location.href = patItem.url; return; }

  // SPA fallback
  document.querySelectorAll('main .screen').forEach(s => s.classList.remove('active'));
  const target = document.getElementById(screen);
  if (target) target.classList.add('active');
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  const activeNav = document.querySelector(`.nav-item[onclick*="'${screen}'"]`);
  if (activeNav) activeNav.classList.add('active');
  if (typeof onScreenChange === 'function') onScreenChange(screen);
  window.scrollTo({ top: 0, behavior: 'smooth' });
}
