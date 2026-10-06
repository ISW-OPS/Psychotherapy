// ============================================================
// NAVBAR — central nav config & renderer for ALL roles
// ============================================================

// ── Patient nav (flat list) ──────────────────────────────
const NAV_ITEMS_BY_ROLE = {
  patient: [
    { id: 'dashboard', url: 'dashboard.html', icon: '🏠', label: 'Dashboard', noTranslate: true },
    { id: 'kob', url: 'kob.html', icon: '🩺', label: 'KOB' },
    { id: 'announcements', url: 'announcements.html', icon: '📢', label: 'Pengumuman' },
    { id: 'events', url: 'events.html', icon: '📅', label: 'Acara & Kelas' },
    { id: 'plan', url: 'plan.html', icon: '💊', label: 'Pelan Rawatan Saya' },
    { id: 'routine', url: 'routine.html', icon: '🕐', label: 'Jadual Harian' },
    { id: 'pakej', url: 'pakej.html', icon: '🗂️', label: 'Pakej Rawatan' },
    { id: 'kepatuhan', url: 'kepatuhan.html', icon: '📝', label: 'Catatan Harian' },
    { id: 'vitals', url: 'vitals.html', icon: '📉', label: 'Bacaan Saya' },
    { id: 'rekod-perubatan', url: 'rekod-perubatan.html', icon: '🩻', label: 'Rekod Perubatan' },
    {
      id: 'library', url: 'library.html', icon: '📚', label: 'Content', noTranslate: true, children: [
        { id: 'video', url: 'library.html?tab=video', icon: '📹', label: 'Video' },
        { id: 'artikel', url: 'library.html?tab=article', icon: '📝', label: 'Artikel' },
        { id: 'faq', url: 'faq.html', icon: '❓', label: 'FAQ' },
      ]
    },
    { id: 'shop', url: 'shop.html', icon: '🛒', label: 'Produk' },
    { id: 'vouchers', url: 'vouchers.html', icon: '🎟️', label: 'Voucher Saya' },
    {
      id: 'payment', url: 'payment-overview.html', icon: '💳', label: 'Pembayaran', children: [
        { id: 'payment_overview', url: 'payment-overview.html', icon: '📊', label: 'Plan Rawatan' },
        { id: 'sejarah_pembayaran', url: 'sejarah-pembayaran.html', icon: '🧾', label: 'Sejarah Pembayaran' },
      ]
      // payment-plan.html sengaja TAK letak dalam nav — dicapai kontekstual sahaja
      // (link "Lihat Jadual Penuh" dari Overview / kad dashboard), bukan destinasi nav.
    },
    { id: 'psy_orders', url: 'orders.html', icon: '📦', label: 'Pesanan & Penjejakan' },
    { id: 'issue', url: 'issue.html', icon: '⚠️', label: 'Lapor Isu' },
    { id: 'pulangan', url: 'pulangan.html', icon: '🍯', label: 'Pulangan Botol' },
    { id: 'surat', url: 'surat.html', icon: '📜', label: 'Surat Rasmi' },
    { id: 'kyc', url: 'pendaftaran.html', icon: '🆔', label: 'Borang Pendaftaran' },
  ],
  staff: [
    { id: 'dashboard', url: 'dashboard.html', icon: '🏥', label: 'Dashboard' },
    { id: 'profile', url: 'profile.html', icon: '👤', label: 'Profile' },
  ],
};

// ── Patient nav PNG icons (folder /icon) ─────────────────
// id nav → nama fail. Item tanpa entri guna emoji fallback.
const PATIENT_NAV_ICONS = {
  dashboard: 'dashboard-home.png',
  kob: 'KOB.png',
  announcements: 'announce.png',
  events: 'event-class.png',
  plan: 'treatment-plan.png',
  routine: 'Jadual-Harian.png',
  pakej: 'Pakej-rawatan.png',
  kepatuhan: 'catatan-harian.png',
  vitals: 'Vital-rekod.png',
  'rekod-perubatan': 'medical-record.png',
  library: 'content-library.png',
  video: 'video.png',
  artikel: 'article.png',
  faq: 'faq.png',
  shop: 'shop.png',
  payment: 'payment.png',
  psy_orders: 'Orders&tracking.png',
  issue: 'report-issue.png',
  pulangan: 'return bottle.png',
  surat: 'surat-rasmi.png',
  kyc: 'kyc.png',
};
function patientNavIconHtml(id, fallbackEmoji, sizeClass = 'w-[18px] h-[18px]') {
  const f = PATIENT_NAV_ICONS[id];
  if (!f) return `<span class="flex-shrink-0">${fallbackEmoji}</span>`;
  const base = window.location.pathname.includes('/roles/') ? '../../icon/' : 'icon/';
  // filter: jadikan ikon PNG putih supaya jelas atas latar navy
  return `<img src="${encodeURI(base + f)}" alt="" class="${sizeClass} object-contain flex-shrink-0" style="filter:brightness(0) invert(1);opacity:.9" onerror="this.outerHTML='<span class=\\'flex-shrink-0\\'>${fallbackEmoji}</span>'">`;
}

// Staff guna ikon PNG yang SAMA dengan patient untuk item yang seakan.
// Item yang tiada padanan kekal emoji (fallback).
const STAFF_NAV_ICONS = {
  dashboard:        'dashboard-home.png',
  psy_patients:     'patient.png',
  psy_appointments: 'calendar.png',
  plan_week:        'treatment-plan.png',
  kob_list:         'KOB.png',
  kepatuhan:        'catatan-harian.png',
  psy_vitals:       'Vital-rekod.png',
  emergency:        'Risk.png',
  pakej:            'Pakej-rawatan.png',
  psy_products:     'shop.png',
  psy_orders:       'Orders&tracking.png',
  pulangan:         'return bottle.png',
  payment_admin:    'payment.png',
  library:          'content-library.png',
  issue:            'report-issue.png',
  surat:            'surat-rasmi.png',
  inventory:        'inventory.png',
  inventory_group:  'inventory.png',
  announcements:    'announce.png',
  events_admin:     'event-class.png',
  auto_messages:    'chatbot.png',
  closures:         'penutupan klinik.png',
  kob_slots:        'slot konsultasi.png',
  staff_mgmt:       'staff-management.png',
  peranan:          'access-control-RBAC.png',
  audit:            'audit-log.png',
  governance:       'governance.png',
  staff_stats:      'statistik.png',
  pakej_laporan:    'laporan-pakej.png',
  audit_kebenaran:  'audit kebenaran.png',
};
// Sidebar staf latar PUTIH: ikon gelap bila tak aktif, putih bila aktif (latar navy).
function staffNavIconHtml(id, fallbackEmoji, isActive) {
  const f = STAFF_NAV_ICONS[id];
  if (!fallbackEmoji) return '';
  if (!f) return `<span class="flex-shrink-0 text-base">${fallbackEmoji}</span>`;
  const base = window.location.pathname.includes('/roles/') ? '../../icon/' : 'icon/';
  const style = isActive
    ? 'filter:brightness(0) invert(1);opacity:1'
    : 'filter:brightness(0);opacity:.55';
  return `<img src="${encodeURI(base + f)}" alt="" class="w-[18px] h-[18px] object-contain flex-shrink-0" style="${style}" onerror="this.outerHTML='<span class=\\'flex-shrink-0 text-base\\'>${fallbackEmoji}</span>'">`;
}

// ── Staff nav (grouped) ──────────────────────────────────
// Master staff nav — ikut matrix yang user define.
// Semua role guna struktur sama; RBAC `pageAllowed()` filter mana item nampak.
const STAFF_NAV_MASTER = [
  {
    group: 'UTAMA', collapsible: false, items: [
      { id: 'dashboard', url: 'dashboard.html', icon: '🏠', label: 'Dashboard' },
      { id: 'psy_patients', url: 'patients.html', icon: '👥', label: 'Pesakit' },
      { id: 'psy_appointments', url: 'appointments.html', icon: '📅', label: 'Kalendar & Jadual' },
      { id: 'plan_week', url: 'weekly-plan.html', icon: '📋', label: 'Weekly Plan' },
      { id: 'psy_vitals', url: 'vitals-history.html', icon: '💉', label: 'Vitals' },
      { id: 'kob_list', url: 'kob-list.html', icon: '🩺', label: 'Sesi KOB' },
      { id: 'sesi_1on1', url: 'sesi-1on1.html', icon: '🧑‍💼', label: 'Sesi 1:1' },
      { id: 'kepatuhan', url: 'kepatuhan.html', icon: '📊', label: 'Kepatuhan Pesakit' },
      { id: 'reaksi_advice', url: 'reaksi-item.html', icon: '🩹', label: 'Reaksi & Tindakan' },
      { id: 'emergency', url: 'emergency.html', icon: '🚨', label: 'Red Emergency Protocol' },
      { id: 'peristiwa', url: 'peristiwa.html', icon: '🏥', label: 'Rekod Klinikal Pesakit' },
      { id: 'dna_test', url: 'dna-test-list.html', icon: '🧬', label: 'DNA Test' },
    ]
  },
  {
    group: 'OPERASI', collapsible: true, items: [
      { id: 'pakej', url: 'pakej.html', icon: '🗂️', label: 'Pakej Rawatan' },
      { id: 'psy_products', url: 'products.html', icon: '🛍️', label: 'Produk' },
      { id: 'produk_bahan', url: 'produk-bahan.html', icon: '🧴', label: 'Produk & Bahan Luar' },
      { id: 'direktori_cadangan', url: 'direktori-cadangan.html', icon: '📇', label: 'Direktori Cadangan' },
      { id: 'ganjaran', url: 'promo-codes.html', icon: '🎁', label: 'Ganjaran', children: [
        { id: 'promo_codes',   url: 'promo-codes.html',   icon: '🏷️', label: 'Kod Promo' },
        { id: 'point_rewards', url: 'point-rewards.html', icon: '🏆', label: 'Ganjaran Mata' },
        { id: 'affiliate',     url: 'affiliate.html',     icon: '🤝', label: 'Affiliate' },
      ] },
      { id: 'inventory_group', url: 'inventory.html', icon: '🏭', label: 'Inventori', children: [
        { id: 'inventory',          url: 'inventory.html',          label: 'Products' },
        { id: 'stock_movement',     url: 'stock-movement.html',     label: 'Stock Movement' },
        { id: 'pemberian_stok',     url: 'pemberian-stok.html',     label: 'Pemberian Stok' },
        { id: 'stock_alerts',       url: 'stock-alerts.html',       label: 'Stock Alerts' },
        { id: 'suppliers',          url: 'suppliers.html',          label: 'Suppliers' },
        { id: 'equipment',          url: 'equipment-list.html',     label: 'Senarai Peralatan' },
      ] },
      { id: 'psy_orders', url: 'orders.html', icon: '📦', label: 'Orders & Tracking' },
      { id: 'pulangan', url: 'pulangan.html', icon: '🍯', label: 'Pulangan Botol' },
      { id: 'payment_group', url: 'payment-admin.html', icon: '💳', label: 'Pembayaran', children: [
        { id: 'payment_admin',  url: 'payment-admin.html',  label: 'Patient Payment' },
        { id: 'payment_ledger', url: 'payment-ledger.html', label: 'Payment Management' },
      ] },
    ]
  },
  {
    group: 'KOMUNIKASI', collapsible: true, items: [
      { id: 'announcements', url: 'announcements.html', icon: '📢', label: 'Pengumuman' },
      { id: 'events_admin', url: 'events.html', icon: '📅', label: 'Acara & Kelas' },
      { id: 'auto_messages', url: 'automation-dashboard.html', icon: '🤖', label: 'Mesej Automatik', children: [
        { id: 'auto_dashboard', url: 'automation-dashboard.html', label: 'Dashboard' },
        { id: 'auto_list',      url: 'automations.html', label: 'Senarai Automasi' },
        { id: 'auto_templates', url: 'auto-mesej.html', label: 'Template Mesej' },
        { id: 'auto_variables', url: 'variables-library.html', label: 'Variables Library' },
        { id: 'auto_audience',  url: 'automation-audience.html', label: 'Audience' },
        { id: 'auto_queue',     url: 'automation-queue.html', label: 'Queue / Scheduled' },
        { id: 'auto_logs',      url: 'automation-logs.html', label: 'Log Penghantaran' },
        { id: 'auto_test',      url: 'test-automation.html', label: 'Test Automation' },
      ] },
      { id: 'library', url: 'library.html', icon: '📚', label: 'Content', noTranslate: true },
    ]
  },
  {
    group: 'PENGETAHUAN', collapsible: true, items: [
      { id: 'kb', url: 'kb-categories.html', icon: '📖', label: 'Knowledge Base' },
      { id: 'kb_admin', url: 'kb-admin.html', icon: '⚙️', label: 'Pengurusan KB', saOnly: true },
    ]
  },
  {
    group: 'LAPORAN', collapsible: true, items: [
      { id: 'laporan_group', url: 'governance.html', icon: '📈', label: 'Laporan', children: [
        { id: 'governance',   url: 'governance.html',    label: 'Governance' },
        { id: 'staff_stats',  url: 'staff-stats.html',   label: 'Statistik' },
        { id: 'kehadiran',    url: 'kehadiran.html',     label: 'Laporan Kehadiran' },
        { id: 'pakej_laporan',url: 'pakej-laporan.html', label: 'Laporan Pakej' },
        { id: 'kob_report',   url: 'kob-report.html',    label: 'KOB Report' },
        { id: 'issue',        url: 'issue.html',         label: 'Report Issue' },
      ] },
    ]
  },
  {
    group: 'PENTADBIRAN', collapsible: true, items: [
      { id: 'surat_group', url: 'surat.html', icon: '📜', label: 'Surat Rasmi', children: [
        { id: 'surat',           url: 'surat.html',           label: 'Letter Request List' },
        { id: 'surat_templates', url: 'surat-templates.html', label: 'Letter Templates' },
        { id: 'surat_request',   url: 'surat-request.html',   label: 'My Letters' },
      ] },
      { id: 'kob_slots', url: 'kob-slots.html', icon: '⏰', label: 'Slot Konsultasi' },
      { id: 'staff_mgmt', url: 'staff_management.html', icon: '👨‍⚕️', label: 'Manage Staff' },
    ]
  },
  {
    group: 'SISTEM', collapsible: true, items: [
      { id: 'settings', url: 'tetapan.html', icon: '⚙️', label: 'Tetapan Sistem', saOnly: true },
      // Peranan & Kebenaran, Audit Kebenaran, Audit Log dipindah ke DALAM Tetapan Sistem
      // (tab Peranan / Keselamatan). Dibuang dari nav untuk elak bertindih.
    ]
  },
];

// GHL-style: bila di dalam Tetapan Sistem (pageId 'settings'), sidebar utama bertukar
// jadi senarai vertikal seksyen tetapan (dgn "Kembali") — bukan nav biasa. Klik item
// panggil setTab(id) yang didefinisikan dalam tetapan.html sendiri.
const SETTINGS_SUBNAV = [
  { id: 'umum', icon: '⚙️', label: 'Umum' },
  { id: 'rupa', icon: '🎨', label: 'Rupa' },
  { id: 'klinik', icon: '🏥', label: 'Klinik' },
  { id: 'peristiwa', icon: '📋', label: 'Rekod Klinikal' },
  { id: 'notifikasi', icon: '🔔', label: 'Notifikasi' },
  { id: 'integrasi', icon: '🧩', label: 'Integrasi' },
  { id: 'keselamatan', icon: '🛡️', label: 'Keselamatan' },
  { id: 'affiliate', icon: '🤝', label: 'Affiliate' },
  { id: 'vitals', icon: '🩺', label: 'Ambang Vitals' },
];
// Halaman lain yang tergolong dlm keluarga Tetapan (dibuka dari senarai Tetapan) —
// bila dibuka terus (bukan dari tab), sidebar kekal dalam mod Tetapan jugak.
const SETTINGS_SCREENS = new Set(['settings', 'peranan', 'staff_mgmt', 'audit', 'audit_kebenaran']);

const NAV_GROUPS_BY_ROLE = {
  staff_admin: STAFF_NAV_MASTER,
  staff_manager: STAFF_NAV_MASTER,
  staff_coach: STAFF_NAV_MASTER,
  staff_doctor: STAFF_NAV_MASTER,
  staff_super_admin: STAFF_NAV_MASTER,
  staff_telesale: STAFF_NAV_MASTER,
  staff_telesales: STAFF_NAV_MASTER,
  staff_kob: STAFF_NAV_MASTER,
};

const ROLE_CONFIG = {
  patient: { label: 'My Health', icon: '🏥' },
  staff_admin: { label: 'Admin Portal', icon: '⚕' },
  staff_coach: { label: 'Coach Portal', icon: '⚕' },
  staff_doctor: { label: 'Doctor Portal', icon: '⚕' },
  staff_manager: { label: 'Manager Portal', icon: '⚕' },
  staff_super_admin: { label: 'Super Admin Portal', icon: '⚕' },
  staff_telesale: { label: 'Telesale Portal', icon: '📞' },
  staff_telesales: { label: 'KOB Portal', icon: '📞' },
  staff_kob: { label: 'KOB Portal', icon: '📞' },
  staff: { label: 'Staff Portal', icon: '⚕' },
};

const STAFF_ROLE_BADGE = {
  admin: { label: 'Admin', cls: 'role-accent-bg' },
  coach: { label: 'Coach', cls: 'role-accent-bg' },
  doctor: { label: 'Doctor', cls: 'role-accent-bg' },
  manager: { label: 'Manager', cls: 'role-accent-bg' },
  super_admin: { label: 'Super Admin', cls: 'role-accent-bg' },
  telesale: { label: 'Telesale', cls: 'role-accent-bg' },
  telesales: { label: 'KOB', cls: 'role-accent-bg' },
  kob: { label: 'KOB', cls: 'role-accent-bg' },
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
  const safeId = `${roleKey}_${group.group.replace(/[^a-zA-Z0-9]/g, '_')}`;
  const lsKey = `isw_nav_${safeId}`;
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

  const flatLink = (item) => `
    <a href="${item.url}" title="${item.label}"
      class="nav-item no-underline ${item.id === activeScreen ? 'active' : ''} w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-ink/60 hover:bg-ink/5 transition-colors">
      ${staffNavIconHtml(item.id, item.icon, item.id === activeScreen)}
      <span class="nav-label font-medium">${item.label}</span>
      <span id="nav-badge-${item.id}" class="hidden ml-auto nav-label min-w-[18px] h-[18px] px-1 rounded-full text-[10px] font-bold bg-terracotta text-white flex items-center justify-center"></span>
    </a>`;
  const isSA = roleKey === 'staff_super_admin' || window.currentUser?.staff_role === 'super_admin';
  const items = group.items.map(item => {
    if (!(item.children && item.children.length)) return flatLink(item);
    // Tapis anak: saOnly (super_admin sahaja) + RBAC pageAllowed
    const kids = item.children.filter(c =>
      (!c.saOnly || isSA) && (isSA || typeof window.pageAllowed !== 'function' || window.pageAllowed(c.id)));
    if (!kids.length) return flatLink(item);
    const childActive = item.id === activeScreen || kids.some(c => c.id === activeScreen);
    const expanded = childActive || localStorage.getItem('isw_pnav_' + item.id) === '1';
    return `
      <div>
        <div class="flex items-center gap-0.5">
          <a href="${item.url}" title="${item.label}"
            class="nav-item no-underline ${item.id === activeScreen ? 'active' : ''} flex-1 min-w-0 flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-ink/60 hover:bg-ink/5 transition-colors">
            ${staffNavIconHtml(item.id, item.icon, item.id === activeScreen)}
            <span class="nav-label font-medium">${item.label}</span>
          </a>
          <button onclick="togglePNav('${item.id}')" title="Buka/tutup" class="nav-label p-2 rounded-lg text-ink/35 hover:text-ink hover:bg-ink/5 flex-shrink-0">
            <svg id="pnv-${item.id}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" class="w-3.5 h-3.5 transition-transform duration-200 ${expanded ? '' : '-rotate-90'}"><polyline points="6 9 12 15 18 9"/></svg>
          </button>
        </div>
        <div id="pni-${item.id}" class="${expanded ? '' : 'hidden'} space-y-0.5 mt-0.5">
          ${kids.map(c => `
            <a href="${c.url}" title="${c.label}"
              class="nav-item no-underline ${c.id === activeScreen ? 'active' : ''} w-full flex items-center gap-2.5 pl-9 pr-3 py-1.5 rounded-lg text-[13px] text-ink/55 hover:bg-ink/5 transition-colors">
              <span class="nav-label">${c.label}</span>
              <span id="nav-badge-${c.id}" class="hidden ml-auto nav-label min-w-[16px] h-[16px] px-1 rounded-full text-[9px] font-bold bg-terracotta text-white flex items-center justify-center"></span>
            </a>`).join('')}
        </div>
      </div>`;
  }).join('');

  return `
    <div class="mb-1">
      ${header}
      <div id="ngi-${safeId}" class="${collapsed ? 'hidden' : ''} space-y-0.5 mt-0.5">
        ${items}
      </div>
    </div>`;
}

function toggleNavGroup(safeId) {
  const lsKey = `isw_nav_${safeId}`;
  const items = document.getElementById('ngi-' + safeId);
  const chevron = document.getElementById('ngc-' + safeId);
  if (!items) return;
  const isNowCollapsed = items.classList.toggle('hidden');
  if (chevron) chevron.classList.toggle('-rotate-90', isNowCollapsed);
  localStorage.setItem(lsKey, isNowCollapsed ? '1' : '0');
}

// Toggle nav parent (patient) — buka/tutup anak
function togglePNav(id) {
  const items = document.getElementById('pni-' + id);
  const chev = document.getElementById('pnv-' + id);
  if (!items) return;
  const collapsed = items.classList.toggle('hidden');
  if (chev) chev.classList.toggle('-rotate-90', collapsed);
  localStorage.setItem('isw_pnav_' + id, collapsed ? '0' : '1');
}

// ── Main navbar renderer ──────────────────────────────────
function renderNavbar(role, user, navItems, activeScreen) {
  const staffRole = user.staff_role || null;
  const roleKey = (role === 'staff' && staffRole) ? `staff_${staffRole}` : role;

  if (!navItems) navItems = getNavItems(role, staffRole);

  const cfg = ROLE_CONFIG[roleKey] || ROLE_CONFIG[role] || ROLE_CONFIG.patient;
  const initials = (user.full_name || 'U').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase();
  const badge = role === 'staff' && staffRole ? STAFF_ROLE_BADGE[staffRole] : null;

  const sidebar = document.getElementById('sidebar');
  if (!sidebar) return;

  if (!document.getElementById('mob-sidebar-overlay')) {
    const ol = document.createElement('div');
    ol.id = 'mob-sidebar-overlay';
    ol.onclick = closeMobileSidebar;
    document.body.appendChild(ol);
  }

  if (!document.getElementById('sidebar-toggle-fab')) {
    const fab = document.createElement('button');
    fab.id = 'sidebar-toggle-fab';
    fab.className = 'sidebar-toggle-fab';
    fab.title = 'Kecilkan/Besarkan';
    fab.setAttribute('aria-label', 'Kecilkan/Besarkan menu');
    fab.onclick = toggleSidebar;
    fab.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><polyline points="15 18 9 12 15 6"/></svg>';
    if (localStorage.getItem('isw_sidebar_collapsed') === '1') fab.classList.add('collapsed');
    document.body.appendChild(fab);
  }

  // Patient: persistent bottom nav bar
  if (role === 'patient' && !document.getElementById('pat-bottom-nav')) {
    const BOT_ITEMS = [
      { href: 'dashboard.html', icon: '🏠', label: 'Home', id: 'dashboard' },
      { href: 'plan.html', icon: '💊', label: 'Plan', id: 'plan' },
      { href: 'kepatuhan.html', icon: '📝', label: 'Catatan', id: 'kepatuhan' },
      { href: 'library.html', icon: '📚', label: 'Content', id: 'library' },
      { href: 'profile.html', icon: '👤', label: 'Profil', id: 'profile' },
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
  const isStaff = role === 'staff';

  if (isStaff) {
    const rawGroups = NAV_GROUPS_BY_ROLE[roleKey] || [];
    // Filter items by RBAC permission (super_admin nampak semua)
    const isSA = staffRole === 'super_admin';
    const groups = rawGroups
      .map(g => ({
        ...g,
        items: g.items.filter(item =>
          (!item.saOnly || isSA) &&
          (isSA || typeof window.pageAllowed !== 'function' || window.pageAllowed(item.id))
        ),
      }))
      .filter(g => g.items.length > 0);
    const settingsLinkActive = (id) => activeScreen === id ? ' active' : '';
    const navHtml = SETTINGS_SCREENS.has(activeScreen)
      ? `
        <a href="dashboard.html" title="Kembali"
          class="no-underline flex items-center gap-1.5 px-3 py-2 mb-1 rounded-lg text-xs font-semibold text-ink/45 hover:bg-ink/5 hover:text-ink transition-colors">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><polyline points="15 18 9 12 15 6"/></svg>
          Kembali
        </a>
        <div class="px-3 pb-1.5 nav-label text-sm font-bold text-ink">Tetapan Sistem</div>
        ${SETTINGS_SUBNAV.map(it => `
          <div data-tab="${it.id}" onclick="if (typeof setTab === 'function') setTab('${it.id}')"
            class="nav-item ${(activeScreen === 'settings' && it.id === 'umum') ? 'active' : ''} w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-ink/60 hover:bg-ink/5 transition-colors cursor-pointer">
            <span class="flex-shrink-0 text-base">${it.icon}</span>
            <span class="nav-label font-medium">${it.label}</span>
          </div>`).join('')}
        <div class="my-2 border-t border-ink/8"></div>
        <a href="peranan.html" title="Peranan & Kebenaran" class="nav-item no-underline w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-ink/60 hover:bg-ink/5 transition-colors${settingsLinkActive('peranan')}">
          <span class="flex-shrink-0 text-base">🔐</span><span class="nav-label font-medium">Peranan & Kebenaran</span>
        </a>
        <a href="staff_management.html" title="Pengguna" class="nav-item no-underline w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-ink/60 hover:bg-ink/5 transition-colors${settingsLinkActive('staff_mgmt')}">
          <span class="flex-shrink-0 text-base">👥</span><span class="nav-label font-medium">Pengguna</span>
        </a>
        <a href="audit.html" title="Log Aktiviti" class="nav-item no-underline w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-ink/60 hover:bg-ink/5 transition-colors${settingsLinkActive('audit')}">
          <span class="flex-shrink-0 text-base">📜</span><span class="nav-label font-medium">Log Aktiviti</span>
        </a>
        <a href="audit-kebenaran.html" title="Audit Kebenaran (RBAC)" class="nav-item no-underline w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-ink/60 hover:bg-ink/5 transition-colors${settingsLinkActive('audit_kebenaran')}">
          <span class="flex-shrink-0 text-base">🛡️</span><span class="nav-label font-medium">Audit Kebenaran (RBAC)</span>
        </a>`
      : groups.length
      ? groups.map(g => renderNavGroup(g, roleKey, activeScreen)).join('')
      : navItems.map(item => `
          <a href="${item.url}" title="${item.label}"
            class="nav-item no-underline ${item.id === activeScreen ? 'active' : ''} w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-ink/60 hover:bg-ink/5 transition-colors">
            <span class="flex-shrink-0 text-base">${item.icon}</span>
            <span class="nav-label font-medium">${item.label}</span>
            <span id="nav-badge-${item.id}" class="hidden ml-auto nav-label min-w-[18px] h-[18px] px-1 rounded-full text-[10px] font-bold bg-terracotta text-white flex items-center justify-center"></span>
          </a>`).join('');

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
    `;

    if (localStorage.getItem('isw_sidebar_collapsed') === '1') {
      sidebar.classList.add('collapsed');
    }

  } else {
    // Dark (navy) sidebar for patient — kekal ikon PNG
    sidebar.classList.remove('patient-white');
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
        ${(() => {
        const badge = (id) => `<span id="nav-badge-${id}" class="hidden ml-auto min-w-[18px] h-[18px] px-1 rounded-full text-[10px] font-bold bg-terracotta text-white flex items-center justify-center"></span>`;
        const topLink = (it, extra = '') => `
            <a href="${it.url}" title="${it.label}" ${it.noTranslate ? 'data-i18n-skip' : ''}
              class="nav-item no-underline ${it.id === activeScreen ? 'active' : ''} ${extra} flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-white/80 hover:bg-white/10">
              ${patientNavIconHtml(it.id, it.icon)}<span class="nav-label">${it.label}</span>${badge(it.id)}
            </a>`;
        const childLink = (it) => `
            <a href="${it.url}" title="${it.label}"
              class="nav-item no-underline ${it.id === activeScreen ? 'active' : ''} w-full flex items-center gap-3 pl-9 pr-3 py-1.5 rounded-lg text-[13px] text-white/65 hover:bg-white/10">
              ${patientNavIconHtml(it.id, it.icon, 'w-4 h-4')}<span class="nav-label">${it.label}</span>${badge(it.id)}
            </a>`;
        return navItems.map(item => {
          if (!(item.children && item.children.length)) return topLink(item, 'w-full');
          const childActive = item.id === activeScreen || item.children.some(c => c.id === activeScreen);
          const expanded = childActive || localStorage.getItem('isw_pnav_' + item.id) === '1';
          return `
              <div>
                <div class="flex items-center gap-0.5">
                  ${topLink(item, 'flex-1 min-w-0')}
                  <button onclick="togglePNav('${item.id}')" title="Buka/tutup" class="p-2 rounded-lg text-white/45 hover:text-white hover:bg-white/10 flex-shrink-0">
                    <svg id="pnv-${item.id}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" class="w-3.5 h-3.5 transition-transform duration-200 ${expanded ? '' : '-rotate-90'}"><polyline points="6 9 12 15 18 9"/></svg>
                  </button>
                </div>
                <div id="pni-${item.id}" class="${expanded ? '' : 'hidden'} space-y-0.5 mt-0.5">
                  ${item.children.map(childLink).join('')}
                </div>
              </div>`;
        }).join('');
      })()}
      </nav>
    `;

    if (localStorage.getItem('isw_sidebar_collapsed') === '1') {
      sidebar.classList.add('collapsed');
    }
  }

  // Top bar global (logo + carian + notif + user) — ganti per-page header
  buildTopbar(user, cfg, role, staffRole);

  window.db?.auth.getUser().then(({ data }) => {
    const uid = data?.user?.id;
    if (uid) loadNavBadges(role, staffRole, uid);
  });

  // Auto-scroll sidebar supaya active nav item visible (tak perlu user scroll cari)
  requestAnimationFrame(() => {
    const activeBtn = sidebar.querySelector('.nav-item.active');
    if (activeBtn) {
      const navScroll = activeBtn.closest('nav');
      if (navScroll) {
        const btnTop = activeBtn.offsetTop;
        const btnHeight = activeBtn.offsetHeight;
        const navHeight = navScroll.clientHeight;
        // Scroll supaya active item di tengah viewport nav
        navScroll.scrollTop = Math.max(0, btnTop - (navHeight / 2) + (btnHeight / 2));
      }
    }
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
      const absentSince = new Date(Date.now() - 7 * 86400000).toISOString();
      const nowIso = new Date().toISOString();
      const [ordersRes, issuesRes, closedRes, invRes, kobRes, patientsRes, peRes, plansRes, activePatRes, recentHadirRes] = await Promise.all([
        window.db.from('psy_orders').select('id', { count: 'exact', head: true }).in('status', ['paid', 'packed']),
        window.db.from('psy_audit_log').select('id').eq('action', 'issue.reported'),
        window.db.from('psy_audit_log').select('meta').eq('action', 'issue.closed'),
        window.db.from('psy_inventory_requests').select('id', { count: 'exact', head: true }).eq('status', 'pending_approval'),
        // Today + upcoming sahaja — sesi 'booked' yang dah lepas masa (Missed) tak dikira
        window.db.from('psy_kob_sessions').select('id', { count: 'exact', head: true }).eq('status', 'booked').gte('scheduled_at', nowIso),
        window.db.from('psy_patients').select('id', { count: 'exact', head: true }).eq('status', 'pending_kyc'),
        window.db.from('psy_patient_events').select('id', { count: 'exact', head: true }).eq('status', 'open'),
        // Tidak hadir > 7 hari (badge Kalendar): pesakit aktif + pelan aktif tolak yang ada sesi 'hadir' dlm 7 hari lepas
        window.db.from('psy_treatment_plans').select('patient_id').eq('status', 'active'),
        window.db.from('psy_patients').select('id').eq('status', 'active'),
        window.db.from('psy_plan_weekly_progress').select('patient_id').eq('status', 'hadir').gt('session_date', absentSince),
      ]);

      setNavBadge('psy_orders', ordersRes.count || 0);
      setNavBadge('purchase_requests', invRes.count || 0);
      setNavBadge('kob_list', kobRes.count || 0);
      setNavBadge('psy_patients', patientsRes.count || 0);
      setNavBadge('peristiwa', peRes?.count || 0); // peristiwa pesakit terbuka

      // Sama definisi dgn senarai "Tidak Hadir Lebih 7 Hari" (appointments.html) & seksyen dashboard
      const activePatientIds = new Set((activePatRes?.data || []).map(r => r.id));
      const recentHadir = new Set((recentHadirRes?.data || []).map(r => r.patient_id));
      const absentIds = new Set((plansRes?.data || []).map(r => r.patient_id)
        .filter(id => activePatientIds.has(id) && !recentHadir.has(id)));
      setNavBadge('psy_appointments', absentIds.size);

      const closedIds = new Set((closedRes.data || []).map(r => r.meta?.issue_id).filter(Boolean));
      const openCount = (issuesRes.data || []).filter(i => !closedIds.has(i.id)).length;
      setNavBadge('issue', openCount);

    } else if (role === 'patient') {
      const [ordersRes, issuesRes, closedRes, patRes] = await Promise.all([
        window.db.from('psy_orders').select('id', { count: 'exact', head: true }).eq('patient_id', userId).in('status', ['pending', 'paid', 'packed', 'shipped']),
        window.db.from('psy_audit_log').select('id, meta').eq('action', 'issue.reported').eq('actor_id', userId),
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
  } catch (e) { }
}

function setHeaderBack(url, label) {
  const rightDiv = document.querySelector('#page-header > div:last-child');
  if (!rightDiv) return;
  const existing = document.getElementById('header-back-btn');
  if (existing) existing.remove();
  const a = document.createElement('button');
  a.id = 'header-back-btn';
  a.type = 'button';
  a.onclick = () => history.back();
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

// ── Global top bar (logo + carian + notifikasi + user) — penuh lebar, atas sidebar ──
function buildTopbar(user, cfg, role, staffRole) {
  const initials = (user.full_name || 'U').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase();
  const logoPath = window.location.pathname.includes('/roles/') ? '../../image/Logo_ISW.png' : 'image/Logo_ISW.png';
  const roleLabel = (role === 'staff' && staffRole) ? (STAFF_ROLE_BADGE[staffRole]?.label || 'Staff') : 'Pesakit';
  let bar = document.getElementById('global-topbar');
  if (!bar) { bar = document.createElement('header'); bar.id = 'global-topbar'; document.body.appendChild(bar); }
  bar.className = 'fixed top-0 left-0 right-0 h-14 bg-white border-b border-ink/10 z-30 flex items-stretch';
  bar.innerHTML = `
    <div class="w-auto lg:w-64 flex-shrink-0 flex items-center gap-2 px-3 md:px-4 lg:border-r border-ink/8">
      <button onclick="toggleMobileSidebar()" aria-label="Menu" class="lg:hidden w-9 h-9 flex items-center justify-center rounded-lg hover:bg-ink/8 text-ink/60">
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M2 4h14M2 9h14M2 14h14"/></svg>
      </button>
      <div class="w-9 h-9 bg-white rounded-lg border border-ink/10 flex items-center justify-center p-1 flex-shrink-0"><img src="${logoPath}" class="w-full h-full object-contain" onerror="this.outerHTML='⚕'"></div>
      <div class="leading-tight min-w-0 hidden lg:block"><div class="font-bold text-sm text-ink truncate">Ibnu Sina Wellness</div><div class="text-[10px] text-ink/50 truncate">${cfg.label}</div></div>
    </div>
    <div class="flex-1 min-w-0"></div>
    <div class="flex items-center gap-1.5 md:gap-2 px-2 md:px-4 flex-shrink-0">
      <button onclick="iswToggleLang && iswToggleLang()" data-isw-lang-btn
        class="px-2.5 h-9 min-w-[40px] rounded-lg hover:bg-ink/5 text-xs font-bold text-ink/60 border border-ink/15 transition-colors"
        title="Bahasa / Language">EN</button>
      ${role === 'staff' ? `<a href="inbox.html" id="wa-inbox-btn" class="relative p-2 hover:bg-ink/5 rounded-lg" title="WhatsApp Inbox">
        <span class="text-lg">💬</span>
        <span id="wa-inbox-badge" class="hidden absolute top-0.5 right-1 min-w-[16px] h-4 bg-green text-white text-[9px] font-bold rounded-full flex items-center justify-center px-0.5"></span>
      </a>` : ''}
      <button id="notif-btn" onclick="toggleNotifPanel()" class="relative p-2 hover:bg-ink/5 rounded-lg" title="Notifikasi">
        <span class="text-lg">🔔</span>
        <span id="notif-badge" class="hidden absolute top-0.5 right-1 min-w-[16px] h-4 bg-terracotta text-white text-[9px] font-bold rounded-full flex items-center justify-center px-0.5"></span>
      </button>
      <div class="relative">
        <button onclick="toggleUserMenu(event)" class="flex items-center gap-2 px-1.5 py-1 rounded-lg hover:bg-ink/5">
          <div class="w-9 h-9 rounded-full bg-navy text-white text-xs font-bold flex items-center justify-center flex-shrink-0">${initials}</div>
          <div class="hidden sm:block leading-tight min-w-0 text-left"><div class="text-sm font-semibold text-ink truncate max-w-[130px]">${user.full_name || 'User'}</div><div class="text-[10px] text-ink/50 truncate">${roleLabel}</div></div>
          <svg class="w-3.5 h-3.5 text-ink/40 flex-shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><polyline points="6 9 12 15 18 9"/></svg>
        </button>
        <div id="user-menu" class="hidden absolute right-0 top-12 z-40 bg-white border border-ink/10 rounded-xl shadow-lg py-1 w-44">
          <a href="profile.html" class="flex items-center gap-2.5 px-4 py-2.5 text-sm text-ink hover:bg-ink/5">👤 <span>Profil</span></a>
          <button onclick="logout()" class="w-full text-left flex items-center gap-2.5 px-4 py-2.5 text-sm text-terracotta hover:bg-terracotta/5">⎋ <span>Log Keluar</span></button>
        </div>
      </div>
    </div>`;
  // Layout: tolak kandungan ke bawah top bar + sidebar mula bawah top bar
  document.body.style.paddingTop = '3.5rem';
  const sb = document.getElementById('sidebar');
  if (sb) {
    // Kalau sidebar berada dalam shell 'overflow-hidden' (cth plan.html: flex h-screen overflow-hidden),
    // body padding-top dah offset shell di bawah top bar — jadi JANGAN tambah top:3.5rem lagi,
    // kalau tidak ada ruang kosong di atas sidebar (double offset).
    const wrapperEl = sb.parentElement;
    let inFixedShell = false, el = wrapperEl;
    while (el && el !== document.body) {
      const cs = getComputedStyle(el);
      if (cs.overflow === 'hidden' || cs.overflowY === 'hidden') { inFixedShell = true; break; }
      el = el.parentElement;
    }
    sb.style.top = inFixedShell ? '0' : '3.5rem';
    sb.style.height = 'calc(100vh - 3.5rem)';
    // Wrapper row (sidebar punya parent) selalunya bawa class Tailwind min-h-screen (100vh)
    // dari markup — nilai tu TAK kira padding-top 56px yang kita baru tambah kat <body> untuk
    // topbar tetap. Dua-dua min-height 100vh (wrapper) + padding-top 56px (body) bertindih,
    // jadi page pendek pun terpaksa scroll lebih 56px yang tak perlu. Betulkan supaya wrapper
    // guna baki ruang sebenar sahaja (bukan overflow:hidden — sekadar min-height yang tepat).
    if (!inFixedShell && wrapperEl) {
      wrapperEl.style.minHeight = 'calc(100vh - 3.5rem)';
    }
  }
  document.querySelectorAll('#sidebar .nav-brand, #sidebar .nav-user').forEach(el => { el.style.display = 'none'; });
  const ph = document.getElementById('page-header'); if (ph) ph.style.display = 'none';
  // Notif panel (sekali sahaja)
  if (!document.getElementById('notif-panel')) {
    const panel = document.createElement('div');
    panel.id = 'notif-panel'; panel.className = 'hidden fixed inset-0 z-50';
    panel.innerHTML = `
      <div class="absolute inset-0" onclick="closeNotifPanel()"></div>
      <div id="notif-drawer" class="absolute top-0 right-0 bottom-0 w-full max-w-sm bg-white shadow-2xl flex flex-col translate-x-full transition-transform duration-300">
        <div class="px-5 py-4 border-b border-ink/10 flex items-center justify-between">
          <h3 class="font-bold">Notifikasi</h3>
          <div class="flex items-center gap-2">
            <button onclick="testNotif()" class="text-xs text-green-dark hover:underline px-1" title="Uji toast + bunyi">🔔 Uji</button>
            <button onclick="markAllRead()" class="text-xs text-navy hover:underline px-1">Baca semua</button>
            <button onclick="deleteAllNotif()" class="text-xs text-terracotta hover:underline px-1">Padam semua</button>
            <button onclick="closeNotifPanel()" class="text-ink/40 hover:text-ink text-xl leading-none ml-1">×</button>
          </div>
        </div>
        <div id="notif-list" class="flex-1 overflow-y-auto divide-y divide-ink/5"></div>
      </div>`;
    document.body.appendChild(panel);
  }
  loadNotifBadge();
  subscribeNotifBadge();
  if (role === 'staff') { loadWaBadge(); subscribeWaBadge(); }
}

// ── WhatsApp unread badge (ikon 💬 top bar) ──────────────
function setWaBadge(count) {
  const el = document.getElementById('wa-inbox-badge');
  if (!el) return;
  if (count > 0) { el.textContent = count > 99 ? '99+' : String(count); el.classList.remove('hidden'); }
  else el.classList.add('hidden');
}
async function loadWaBadge() {
  if (!window.db) return;
  try {
    // Lead telesale (kod "Eob...") bukan pesakit — sembunyi dari Inbox, jadi jangan kira di badge pun.
    const { count } = await window.db.from('psy_wa_conversations')
      .select('id', { count: 'exact', head: true }).gt('unread', 0).not('contact_name', 'ilike', 'eob%');
    setWaBadge(count || 0);
  } catch (_) { }
}
async function subscribeNotifBadge() {
  if (!window.db || window._notifBadgeSub) return;
  window._notifBadgeSub = true;
  const uid = (await window.db.auth.getUser()).data.user?.id;
  if (!uid) return;
  ensureNotifPermission();
  primeNotifAudio();
  window.db.channel('notif-badge-' + uid)
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'psy_notifications', filter: `user_id=eq.${uid}` }, (payload) => { loadNotifBadge(); playNotifSound(); showDesktopToast(payload.new); })
    .subscribe();
}

// Audio notifikasi (Web Audio — tiada fail perlu). Browser sekat autoplay
// sebelum interaksi, jadi kita "prime" AudioContext pada klik pertama.
let _notifAudioCtx = null;
function _getAudioCtx() {
  try {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return null;
    if (!_notifAudioCtx) _notifAudioCtx = new Ctx();
    if (_notifAudioCtx.state === 'suspended') _notifAudioCtx.resume().catch(() => {});
    return _notifAudioCtx;
  } catch (_) { return null; }
}
function primeNotifAudio() {
  if (window._notifAudioPrimed) return;
  window._notifAudioPrimed = true;
  const prime = () => { _getAudioCtx(); document.removeEventListener('click', prime); };
  document.addEventListener('click', prime, { once: true });
}
// Uji notifikasi terus dari UI (butang 🔔 Uji dlm panel loceng) — tak perlu console.
function testNotif() {
  _getAudioCtx();          // prime dalam gesture klik
  playNotifSound();
  if (!('Notification' in window)) { alert('Browser ini tak sokong notifikasi desktop. Bunyi tetap berfungsi.'); return; }
  const afterPerm = () => {
    if (Notification.permission === 'granted') {
      try {
        const t = new Notification('🔔 Notifikasi Ujian', { body: 'Ini ujian toast + bunyi.', tag: 'isw-test-' + Date.now() });
        t.onclick = () => { window.focus(); t.close(); };
        setTimeout(() => { try { t.close(); } catch (_) {} }, 8000);
      } catch (e) {
        alert('Kebenaran OK tapi gagal cipta toast: ' + e.message);
      }
    } else if (Notification.permission === 'denied') {
      alert('❌ Notifikasi desktop DISEKAT untuk laman ni.\n\nBenarkan: klik ikon 🔒 (kiri address bar) → Notifications → Allow → cuba semula.\n\n(Bunyi tetap main.)');
    } else {
      alert('Kebenaran belum diberi. Klik "🔔 Uji" sekali lagi & tekan Allow.');
    }
  };
  if (Notification.permission === 'default') Notification.requestPermission().then(afterPerm).catch(afterPerm);
  else afterPerm();
}
window.testNotif = testNotif;

function playNotifSound() {
  const ctx = _getAudioCtx();
  if (!ctx) return;
  try {
    const now = ctx.currentTime;
    // Ding-dong pendek (dua nada)
    [[880, 0], [1174.66, 0.13]].forEach(([freq, t]) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.0001, now + t);
      gain.gain.exponentialRampToValueAtTime(0.22, now + t + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + t + 0.28);
      osc.connect(gain); gain.connect(ctx.destination);
      osc.start(now + t); osc.stop(now + t + 0.3);
    });
  } catch (_) {}
}

// Minta kebenaran notifikasi desktop (sekali sahaja).
function ensureNotifPermission() {
  try {
    if (!('Notification' in window) || Notification.permission !== 'default') return;
    Notification.requestPermission().catch(() => {});
  } catch (_) {}
}

// Toast desktop OS (macam Telegram Web) bila ada notifikasi baru — semasa browser terbuka.
function showDesktopToast(n) {
  try {
    if (!n || !('Notification' in window) || Notification.permission !== 'granted') return;
    const emoji = NOTIF_ICONS[n.type] || NOTIF_ICONS.default;
    const toast = new Notification(`${emoji} ${n.title || 'Ibnu Sina Wellness'}`, {
      body: n.body || '',
      tag: 'isw-notif-' + (n.id || Math.random()),
    });
    toast.onclick = () => { window.focus(); if (n.link) location.href = n.link; toast.close(); };
    setTimeout(() => { try { toast.close(); } catch (_) {} }, 8000);
  } catch (_) {}
}

function subscribeWaBadge() {
  if (!window.db || window._waBadgeSub) return;
  window._waBadgeSub = true;
  window.db.channel('wa-badge')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'psy_wa_conversations' }, () => loadWaBadge())
    .subscribe();
}

function toggleUserMenu(e) {
  if (e) e.stopPropagation();
  document.getElementById('user-menu')?.classList.toggle('hidden');
}
if (!window._userMenuListener) {
  window._userMenuListener = true;
  document.addEventListener('click', (e) => {
    const m = document.getElementById('user-menu');
    if (m && !m.classList.contains('hidden') && !e.target.closest('#user-menu') && !e.target.closest('button[onclick*="toggleUserMenu"]')) m.classList.add('hidden');
  });
}

// Per-page header tak diperlukan lagi (top bar global ambil alih) — sembunyi sahaja.
function renderHeader(title, subtitle) {
  const header = document.getElementById('page-header');
  if (header) header.style.display = 'none';
}

const NOTIF_ICONS = { appointment: '📅', order: '📦', plan: '💊', system: '📢', reaksi: 'Reaksi', kyc: '🆔', referral: '🔀', event: '🏥', payment: '💳', default: '🔔' };

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
    <div id="notif-item-${n.id}" class="group px-5 py-3.5 hover:bg-cream/60 transition-colors ${n.is_read ? 'opacity-55' : 'bg-navy-light/20'}">
      <div class="flex items-start gap-3">
        <span class="text-xl flex-shrink-0 mt-0.5 cursor-pointer" onclick="readNotif('${n.id}','${n.link || ''}')">${NOTIF_ICONS[n.type] || NOTIF_ICONS.default}</span>
        <div class="flex-1 min-w-0 cursor-pointer" onclick="readNotif('${n.id}','${n.link || ''}')">
          <div class="flex items-start justify-between gap-1">
            <div class="text-sm font-semibold leading-snug">${n.title}</div>
            ${!n.is_read ? '<span class="w-1.5 h-1.5 bg-navy rounded-full flex-shrink-0 mt-1.5"></span>' : ''}
          </div>
          ${n.body ? `<div class="text-xs text-ink/60 mt-0.5 leading-relaxed">${n.body}</div>` : ''}
          <div class="text-[10px] text-ink/35 mt-1">${new Date(n.created_at).toLocaleString((window.iswGetLang && window.iswGetLang() === 'ms') ? 'ms-MY' : 'en-GB', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })}</div>
        </div>
        <button onclick="deleteNotif('${n.id}')" title="Padam"
          class="flex-shrink-0 w-5 h-5 flex items-center justify-center rounded-full text-ink/25 hover:bg-terracotta/15 hover:text-terracotta transition-colors opacity-0 group-hover:opacity-100 text-xs leading-none mt-0.5">✕</button>
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

async function deleteNotif(id) {
  document.getElementById('notif-item-' + id)?.remove();
  await window.db.from('psy_notifications').delete().eq('id', id);
  loadNotifBadge();
  const list = document.getElementById('notif-list');
  if (list && !list.children.length) list.innerHTML = '<div class="text-sm text-ink/40 text-center py-16">Tiada notifikasi</div>';
}

async function deleteAllNotif() {
  const uid = (await window.db.auth.getUser()).data.user?.id;
  await window.db.from('psy_notifications').delete().eq('user_id', uid);
  loadNotifBadge();
  const list = document.getElementById('notif-list');
  if (list) list.innerHTML = '<div class="text-sm text-ink/40 text-center py-16">Tiada notifikasi</div>';
}

function toggleNotifPanel() {
  const panel = document.getElementById('notif-panel');
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

function toggleSidebar() {
  const sidebar = document.getElementById('sidebar');
  if (!sidebar) return;
  const collapsed = sidebar.classList.toggle('collapsed');
  document.getElementById('sidebar-toggle-fab')?.classList.toggle('collapsed', collapsed);
  localStorage.setItem('isw_sidebar_collapsed', collapsed ? '1' : '0');
}

// ── PWA bootstrap — pull in /shared/pwa.js on every role page ──
if (!window.__iswPwaInit && !document.getElementById('isw-pwa-loader')) {
  const s = document.createElement('script');
  s.id = 'isw-pwa-loader';
  s.src = '/shared/pwa.js';
  document.head.appendChild(s);
}

// ── i18n bootstrap — glossary dict + engine on every role page (BM ⇄ EN) ──
// async=false preserves execution order so the dict is ready before the engine.
if (!window.__iswI18n && !document.getElementById('isw-i18n-loader')) {
  const d = document.createElement('script');
  d.id = 'isw-i18n-dict-loader';
  d.src = '/shared/i18n-dict.js';
  d.async = false;
  document.head.appendChild(d);
  const dMs = document.createElement('script');
  dMs.id = 'isw-i18n-dict-ms-loader';
  dMs.src = '/shared/i18n-dict-ms.js';
  dMs.async = false;
  document.head.appendChild(dMs);
  const s = document.createElement('script');
  s.id = 'isw-i18n-loader';
  s.src = '/shared/i18n.js';
  s.async = false;
  document.head.appendChild(s);
}

function goTo(screen) {
  // Search in grouped staff nav
  for (const groups of Object.values(NAV_GROUPS_BY_ROLE)) {
    for (const g of groups) {
      const found = g.items.find(n => n.id === screen);
      if (found?.url) { window.location.href = found.url; return; }
    }
  }
  // Patient nav (termasuk anak/children)
  const patFlat = (NAV_ITEMS_BY_ROLE.patient || []).flatMap(n => n.children ? [n, ...n.children] : [n]);
  const patItem = patFlat.find(n => n.id === screen);
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
