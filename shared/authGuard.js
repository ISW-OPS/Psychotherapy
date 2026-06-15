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
window.PAGE_MODULE = {
  dashboard: 'dashboard',
  psy_patients: 'patient', patient_hub: 'patient', vitals: 'patient',
  kyc_forms: 'kyc',
  assignments: 'coaching', coaching: 'coaching', consultation: 'coaching',
  plan_week: 'schedule', psy_appointments: 'schedule', closures: 'schedule',
  kob_list: 'kob', kob_slots: 'kob',
  inventory: 'inventory', kit_prosedur: 'inventory', pulangan: 'inventory',
  psy_products: 'products',
  psy_orders: 'orders',
  pakej: 'package',
  payment_admin: 'payment',
  surat: 'communication', library: 'communication', announcements: 'communication',
  kepatuhan: 'operations', issue: 'operations',
  audit: 'reports', governance: 'reports', staff_stats: 'reports', pakej_laporan: 'reports',
  staff_mgmt: 'staff',
  peranan: 'rbac', audit_kebenaran: 'rbac',
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
  kob:               'pat_kob',
  plan:              'pat_plan',
  routine:           'pat_routine',
  kepatuhan:         'pat_kepatuhan',
  vitals:            'pat_vitals',
  'rekod-perubatan': 'pat_rekod',
  library:           'pat_library',
  shop:              'pat_shop',
  psy_orders:        'pat_orders',
  issue:             'pat_issue',
  pulangan:          'pat_pulangan',
  surat:             'pat_surat',
  // sentiasa allow: dashboard, pakej, payment, kyc, profile, checkin
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
