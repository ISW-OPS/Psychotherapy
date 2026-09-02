async function checkAuth(requiredRole) {
  const { data: { session } } = await window.db.auth.getSession();

  if (!session) {
    window.location.href = '../../auth/login.html';
    return null;
  }

  const { data: profile } = await window.db
    .from('psy_profiles')
    .select('*')
    .eq('id', session.user.id)
    .single();

  if (!profile || profile.role !== requiredRole) {
    await window.db.auth.signOut();
    localStorage.removeItem('isw_role');
    localStorage.removeItem('isw_name');
    alert('Akses tidak dibenarkan');
    window.location.href = '../../auth/login.html';
    return null;
  }

  localStorage.setItem('isw_role', profile.role);
  localStorage.setItem('isw_name', profile.full_name);

  await loadPermissions(session.user.id);

  // window.currentUser belum di-set oleh caller pada ketika ini — simpan profil
  // supaya can() boleh kenal super_admin serta-merta.
  if (!window.currentUser) window.currentUser = { ...session.user, ...profile };

  // Auto-hide elemen [data-rbac] tanpa kebenaran (staff sahaja; patient tiada tag)
  if (profile.role === 'staff') {
    if (document.body) startRbacObserver();
    else document.addEventListener('DOMContentLoaded', startRbacObserver);
  }

  return { ...session.user, ...profile };
}

// ── RBAC v2: PAGE → MODULE mapping (untuk page-level access guard) ──
// Setiap nav item mempunyai module tersendiri supaya boleh dikawal berasingan dari RBAC UI.
window.PAGE_MODULE = {
  // UTAMA — setiap navbar item ada modul sendiri
  dashboard:        'dashboard',
  psy_patients:     'patient',   patient_hub: 'patient',
  progres_pesakit:  'patient',   // Progres Pesakit (1 view) — ikut kebenaran modul pesakit
  psy_vitals:       'vitals',    vitals: 'vitals',
  psy_appointments: 'schedule',
  plan_week:        'plan_week',
  kob_list:         'kob',
  kepatuhan:        'kepatuhan',
  emergency:        'emergency',
  reaksi_advice:    'reaksi',  reaksi_item: 'reaksi',
  reaksi_laporan:   'reaksi',  reaksi_preview: 'reaksi',
  rujukan:          'rujukan',
  sesi_1on1:        'rujukan',
  kehadiran:        'kehadiran',
  peristiwa:          'patient_events',
  dna_test:           'dna_test',

  // OPERASI
  pakej:            'package',
  psy_products:     'products',
  promo_codes:      'products',
  point_rewards:    'products',
  inventory:        'inventory', kit_prosedur: 'inventory', suppliers: 'inventory',
  purchase_requests: 'inventory', stock_in: 'inventory', stock_alerts: 'inventory',
  inventory_overview: 'inventory', stock_movement: 'inventory',
  pulangan:         'pulangan',
  psy_orders:       'orders',
  payment_admin:    'payment',
  affiliate:        'affiliate',

  // KOMUNIKASI
  announcements:    'announcements',
  events_admin:     'events',
  auto_messages:    'auto_messages',
  // sub-pages Mesej Automatik — semua ikut modul induk auto_messages
  auto_dashboard:   'auto_messages', auto_list:      'auto_messages',
  auto_templates:   'auto_messages', auto_variables: 'auto_messages',
  auto_audience:    'auto_messages', auto_queue:     'auto_messages',
  auto_logs:        'auto_messages', auto_test:      'auto_messages',
  library:          'library',
  kb:               'kb',
  kb_dashboard:     'kb', kb_resources: 'kb', kb_categories: 'kb',
  kb_notes:         'kb', kb_bookmarks: 'kb', kb_training: 'kb',
  kb_upload:        'kb', kb_admin: 'kb', kb_detail: 'kb', kb_version: 'kb',

  // LAPORAN
  governance:       'governance',
  staff_stats:      'staff_stats',
  pakej_laporan:    'pakej_laporan',
  issue:            'issue',

  // PENTADBIRAN
  surat:            'surat',
  surat_templates:  'surat',
  // surat_request & surat_request_detail SENGAJA tidak didaftar — mohon surat peribadi
  // (RELA/KWSP/dll) & lihat status permohonan sendiri mesti boleh diakses SEMUA staff, bukan
  // setakat yang ada modul 'surat' (HR/admin proses surat pesakit). Tindakan reviewer (Lulus/
  // Tolak/Semakan) dalam surat-request-detail.html masih digate berasingan via can('surat','edit')
  // + RLS psy_letter_requests — page access sahaja yang dibuka. pageAllowed() auto-allow page
  // yang tiada dalam map ni.
  closures:         'closures',
  kob_slots:        'kob_slots',
  staff_mgmt:       'staff',

  // SISTEM
  settings:         'settings',   // super_admin sahaja (tiada role lain diberi modul ini)
  peranan:          'rbac',
  audit_kebenaran:  'audit_kebenaran',
  audit:            'audit',

  // sub-pages — guna modul parent (bukan navbar item sendiri)
  assignments: 'coaching', coaching: 'coaching', consultation: 'coaching',
  coaching_catalog: 'coaching', plans: 'coaching',
  inbox: 'announcements',
  feedback: 'issue', services: 'operations',
  // profile & login sentiasa allow (bukan dalam PAGE_MODULE)
};

window.pageAllowed = function(pageId) {
  if (!(pageId in window.PAGE_MODULE)) return true;
  return can(window.PAGE_MODULE[pageId], 'view');
};

// ── RBAC v2: cache effective permissions (module × action) ──
window.__iswPerms = null;

async function loadPermissions(userId) {
  const { data, error } = await window.db
    .from('psy_user_effective_permissions')
    .select('module_code, action_code')
    .eq('user_id', userId);
  if (error) { window.__iswPerms = new Set(); return; }
  window.__iswPerms = new Set((data || []).map(r => r.module_code + '.' + r.action_code));
}

// Boleh dipanggil dengan:
//   can('inventory', 'edit')   ATAU
//   can('inventory.edit')
function can(moduleOrCode, action) {
  if (window.currentUser?.staff_role === 'super_admin') return true;
  if (!window.__iswPerms) return false;
  const key = action ? (moduleOrCode + '.' + action) : moduleOrCode;
  return window.__iswPerms.has(key);
}

// ── RBAC UI: butang/elemen bertag data-rbac="module.action" ──
// Mana-mana elemen dengan atribut data-rbac akan DISEMBUNYIKAN secara automatik
// jika pengguna tiada kebenaran tersebut (super_admin sentiasa nampak semua).
// Berfungsi untuk elemen statik DAN yang di-render dinamik (MutationObserver).
window.applyRbacUI = function (root) {
  const scope = root && root.querySelectorAll ? root : document;
  scope.querySelectorAll('[data-rbac]').forEach(el => {
    const code = el.getAttribute('data-rbac');
    if (!code) return;
    if (can(code)) {
      // Buang DUA-DUA punca tersembunyi: class "hidden" statik dlm HTML (corak lazim
      // <button class="hidden ..." data-rbac="...">) DAN style.display yg dipasang
      // sebelum ni oleh cabang else di bawah. Sebelum ni fungsi ni cuma urus
      // style.display — elemen yg mula hidden via class tak pernah didedahkan.
      el.classList.remove('hidden');
      if (el.dataset.rbacHidden) { el.style.display = ''; delete el.dataset.rbacHidden; }
    } else {
      el.style.display = 'none';
      el.dataset.rbacHidden = '1';
    }
  });
};

function startRbacObserver() {
  if (window.__rbacObs || !document.body) return;
  window.applyRbacUI(document);
  window.__rbacObs = new MutationObserver(() => window.applyRbacUI(document));
  window.__rbacObs.observe(document.body, { childList: true, subtree: true });
}

// Backward-compat alias
function hasPermission(moduleOrCode, action) { return can(moduleOrCode, action); }
function hasAnyPermission(...codes) { return codes.some(c => can(c)); }

async function requirePermission(moduleOrCode, action, redirectTo) {
  // requirePermission('inventory','edit') OR requirePermission('inventory.edit')
  if (typeof action === 'string' && action.endsWith('.html')) { redirectTo = action; action = undefined; }
  redirectTo = redirectTo || 'dashboard.html';
  if (can(moduleOrCode, action)) return true;
  alert('Akses ditolak. Anda tidak mempunyai kebenaran untuk: ' + moduleOrCode + (action ? '.' + action : ''));
  window.location.href = redirectTo;
  return false;
}

function getBasePath() {
  return '../../';
}

// ── Patient features (global on/off, dikawal dari RBAC UI) ──
window.__patientFeats = null;

window.PAGE_PATIENT_MODULE = {
  dashboard:         'pat_dashboard',
  kob:               'pat_kob',
  announcements:     'pat_announcements',
  events:            'pat_events',
  plan:              'pat_plan',
  routine:           'pat_routine',
  pakej:             'pat_pakej',
  kepatuhan:         'pat_kepatuhan',
  vitals:            'pat_vitals',
  'rekod-perubatan': 'pat_rekod',
  library:           'pat_library',
  shop:              'pat_shop',
  payment:           'pat_payment',
  payment_overview:  'pat_payment',   // payment-overview.html = anak nav Pembayaran
  payment_plan:      'pat_payment',   // payment-plan.html = anak nav Pembayaran
  sejarah_pembayaran:'pat_sejarah',   // sejarah-pembayaran.html + resit.html
  psy_orders:        'pat_orders',
  orders:            'pat_orders',    // orders.html hantar pageId 'orders'
  issue:             'pat_issue',
  faq:               'pat_library',   // FAQ = anak nav Library
  feedback:          'pat_issue',
  checkin:           'pat_kepatuhan', // Daily Check-in = sebahagian Catatan Harian
  pulangan:          'pat_pulangan',
  surat:             'pat_surat',
  kyc:               'pat_kyc',
  // profile: sentiasa allow (bukan item nav utama)
};

async function loadPatientFeatures() {
  try {
    const { data } = await window.db
      .from('psy_role_module_actions')
      .select('module_code')
      .eq('role_code', 'patient')
      .eq('action_code', 'view');
    window.__patientFeats = new Set((data || []).map(r => r.module_code));
  } catch (_) {
    window.__patientFeats = new Set(Object.values(window.PAGE_PATIENT_MODULE));
  }
}

function canPatient(pageId) {
  const mod = window.PAGE_PATIENT_MODULE[pageId];
  if (!mod) return true;
  if (!window.__patientFeats) return true;
  return window.__patientFeats.has(mod);
}
