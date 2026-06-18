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

  return { ...session.user, ...profile };
}

// ── RBAC v2: PAGE → MODULE mapping (untuk page-level access guard) ──
// Setiap nav item mempunyai module tersendiri supaya boleh dikawal berasingan dari RBAC UI.
window.PAGE_MODULE = {
  // UTAMA
  dashboard:        'dashboard',
  psy_patients:     'patient', patient_hub: 'patient', vitals: 'patient',
  kyc_forms:        'kyc',
  psy_appointments: 'schedule',
  plan_week:        'plan_week',
  kob_list:         'kob',
  kepatuhan:        'kepatuhan',

  // OPERASI
  pakej:            'package',
  psy_products:     'products',
  inventory:        'inventory', kit_prosedur: 'inventory',
  pulangan:         'pulangan',
  psy_orders:       'orders',
  payment_admin:    'payment',

  // KOMUNIKASI
  announcements:    'announcements',
  library:          'library',

  // LAPORAN
  governance:       'governance',
  staff_stats:      'staff_stats',
  pakej_laporan:    'pakej_laporan',
  issue:            'issue',

  // PENTADBIRAN
  surat:            'surat',
  closures:         'closures',
  kob_slots:        'kob_slots',
  staff_mgmt:       'staff',

  // SISTEM
  peranan:          'rbac',
  audit_kebenaran:  'audit_kebenaran',
  audit:            'audit',

  // sub-pages (akses via patient-hub, bukan nav terus)
  assignments: 'coaching', coaching: 'coaching', consultation: 'coaching',
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
  plan:              'pat_plan',
  routine:           'pat_routine',
  pakej:             'pat_pakej',
  kepatuhan:         'pat_kepatuhan',
  vitals:            'pat_vitals',
  'rekod-perubatan': 'pat_rekod',
  library:           'pat_library',
  shop:              'pat_shop',
  payment:           'pat_payment',
  psy_orders:        'pat_orders',
  issue:             'pat_issue',
  pulangan:          'pat_pulangan',
  surat:             'pat_surat',
  kyc:               'pat_kyc',
  // profile & checkin: sentiasa allow (bukan item nav utama)
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
