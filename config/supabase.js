const SUPABASE_URL = 'https://ipmemyizigwgivccytcu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlwbWVteWl6aWd3Z2l2Y2N5dGN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxOTYwNzcsImV4cCI6MjA5MTc3MjA3N30.oKyeosX2pHbWXVqpboF6DSgifAuGzUZckA-y5fdkD0Y';

const _supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

window.db = _supabaseClient;

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
  const { data, error } = await window.db.from(table).update(updates).eq('id', id).select().single();
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
