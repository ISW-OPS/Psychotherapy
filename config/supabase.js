const _ENV = {
  production: {
    url: 'https://xmvqvqrifhwoehdfsoau.supabase.co',
    key: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhtdnF2cXJpZmh3b2VoZGZzb2F1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyMTMxODYsImV4cCI6MjA5Njc4OTE4Nn0.haICSutl-2vdxiazohuRYgxHK36IDFOsqLf9nX7wLP8',
    label: 'PRODUCTION', color: '#dc2626'
  },
  testing: {
    url: 'https://ipmemyizigwgivccytcu.supabase.co',
    key: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlwbWVteWl6aWd3Z2l2Y2N5dGN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxOTYwNzcsImV4cCI6MjA5MTc3MjA3N30.oKyeosX2pHbWXVqpboF6DSgifAuGzUZckA-y5fdkD0Y',
    label: 'TESTING', color: '#d97706'
  }
};

const _isLocal = location.hostname === 'localhost' || location.hostname === '127.0.0.1';
const _defaultEnv = _isLocal ? 'testing' : 'production';
const _activeEnv = localStorage.getItem('isw_env') || _defaultEnv;
const _cfg = _ENV[_activeEnv];

const SUPABASE_URL = _cfg.url;
const SUPABASE_ANON_KEY = _cfg.key;

const _supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

window.db = _supabaseClient;
window.ISW_ENV = _activeEnv;

// Badge — tunjuk environment di sudut bawah kanan
(function () {
  const badge = document.createElement('div');
  badge.id = 'isw-env-badge';
  badge.textContent = _cfg.label;
  badge.title = 'Klik untuk tukar environment (developer only)';
  Object.assign(badge.style, {
    position: 'fixed', bottom: '8px', right: '8px', zIndex: 99999,
    background: _cfg.color, color: '#fff', fontSize: '10px',
    fontWeight: '700', padding: '2px 8px', borderRadius: '4px',
    cursor: 'pointer', letterSpacing: '0.05em', opacity: '0.85'
  });
  badge.onclick = function () {
    const next = _activeEnv === 'production' ? 'testing' : 'production';
    if (confirm('Tukar ke ' + _ENV[next].label + '?\nPage akan reload.')) {
      localStorage.setItem('isw_env', next);
      location.reload();
    }
  };
  document.addEventListener('DOMContentLoaded', function () {
    document.body.appendChild(badge);
  });
})();

async function dbQuery(table, { select = '*', eq, order, limit, single } = {}) {
  let q = window.db.from(table).select(select);
  if (eq) Object.entries(eq).forEach(([k, v]) => { q = q.eq(k, v); });
  if (order) q = q.order(order.col, { ascending: order.asc ?? false });
  if (limit) q = q.limit(limit);
  if (single) q = q.single();
  const { data, error } = await q;
  if (error) throw error;
  return data;
}

async function dbInsert(table, row) {
  const { data, error } = await window.db.from(table).insert(row).select().single();
  if (error) throw error;
  return data;
}

async function dbUpdate(table, id, updates) {
  // maybeSingle (bukan single) — RLS kadang block SELECT-after-UPDATE walaupun UPDATE berjaya;
  // single() akan throw "Cannot coerce" kalau 0 row, padahal data dah disimpan.
  const { data, error } = await window.db.from(table).update(updates).eq('id', id).select().maybeSingle();
  if (error) throw error;
  return data;
}

async function dbDelete(table, id) {
  const { error } = await window.db.from(table).delete().eq('id', id);
  if (error) throw error;
}

async function getCurrentUser() {
  const { data: { user } } = await window.db.auth.getUser();
  if (!user) return null;
  const profile = await dbQuery('psy_profiles', { eq: { id: user.id }, single: true });
  return { ...user, ...profile };
}

async function auditLog(action, target, meta = {}) {
  try {
    const user = await getCurrentUser();
    if (!user) return;
    await window.db.from('psy_audit_log').insert({
      actor_id: user.id,
      actor_name: user.full_name,
      actor_role: user.role,
      action,
      target,
      meta
    });
  } catch (_) {}
}
