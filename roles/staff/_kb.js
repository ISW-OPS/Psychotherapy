// ============================================================
// KNOWLEDGE BASE — shared helpers across kb-*.html pages
// Depends on: config/supabase.js (window.db, dbQuery...), _shared.js
// ============================================================

const KB_BUCKET = 'kb-media';

// ── Resource type → icon + label + accent ────────────────────
const KB_TYPES = {
  pdf:          { icon: '📕', label: 'PDF',          ext: 'PDF',  cls: 'bg-terracotta/15 text-terracotta' },
  document:     { icon: '📘', label: 'Dokumen',      ext: 'DOCX', cls: 'bg-navy-light text-navy' },
  spreadsheet:  { icon: '📗', label: 'Spreadsheet',  ext: 'XLSX', cls: 'bg-green-light text-green-dark' },
  presentation: { icon: '📙', label: 'Persembahan',  ext: 'PPTX', cls: 'bg-gold/30 text-gold-dark' },
  video:        { icon: '🎬', label: 'Video',        ext: 'MP4',  cls: 'bg-teal/15 text-teal' },
  image:        { icon: '🖼️', label: 'Imej',         ext: 'IMG',  cls: 'bg-gold/25 text-gold-dark' },
  link:         { icon: '🔗', label: 'Pautan',       ext: 'Link', cls: 'bg-navy-light text-navy' },
};
function kbType(t) { return KB_TYPES[t] || KB_TYPES.pdf; }

// ── Category colour token → chip classes ─────────────────────
const KB_CAT_CLS = {
  navy:       'bg-navy-light text-navy',
  green:      'bg-green-light text-green-dark',
  gold:       'bg-gold/30 text-gold-dark',
  terracotta: 'bg-terracotta/15 text-terracotta',
  teal:       'bg-teal/10 text-teal',
  grey:       'bg-ink/10 text-ink/60',
  purple:     'bg-[#EDE9FE] text-[#6D28D9]',
  blue:       'bg-[#DBEAFE] text-[#1D4ED8]',
};
function kbCatCls(color) { return KB_CAT_CLS[color] || KB_CAT_CLS.grey; }

const KB_VIS = {
  public:     { label: 'Umum',           icon: '🌐', cls: 'bg-green-light text-green-dark' },
  department: { label: 'Jabatan',        icon: '🏢', cls: 'bg-navy-light text-navy' },
  role:       { label: 'Peranan',        icon: '👥', cls: 'bg-gold/30 text-gold-dark' },
  user:       { label: 'Orang Tertentu', icon: '🙋', cls: 'bg-teal/10 text-teal' },
  private:    { label: 'Peribadi',       icon: '🔒', cls: 'bg-ink/10 text-ink/60' },
};
function kbVis(v) { return KB_VIS[v] || KB_VIS.public; }

// Boleh current user lihat resource ini? (uploader & super_admin sentiasa boleh)
function kbVisibleToMe(r) {
  const u = window.currentUser;
  if (!u) return r.visibility === 'public';
  if (u.staff_role === 'super_admin') return true;
  if (r.uploaded_by === u.id) return true;
  switch (r.visibility) {
    case 'private': return false;
    case 'user':    return (r.allowed_users || []).includes(u.id);
    case 'role':    return (r.allowed_roles || []).includes(u.staff_role);
    case 'department':
    case 'public':
    default:        return true;
  }
}

function kbFileSize(bytes) {
  if (!bytes && bytes !== 0) return '—';
  if (bytes === 0) return '—';
  const kb = bytes / 1024;
  if (kb < 1024) return kb.toFixed(0) + ' KB';
  return (kb / 1024).toFixed(1) + ' MB';
}

// ── Authoring permission (create/edit/delete) ────────────────
function kbCanAuthor() {
  if (window.currentUser?.staff_role === 'super_admin') return true;
  return typeof can === 'function' && can('kb', 'edit');
}
function kbCanDelete() {
  if (window.currentUser?.staff_role === 'super_admin') return true;
  return typeof can === 'function' && can('kb', 'delete');
}

// ── Data loaders (shared) ────────────────────────────────────
async function kbCategories() {
  return dbQuery('psy_kb_categories', { eq: { is_active: true }, order: { col: 'sort_order', asc: true } });
}
async function kbSubcategories(categoryId) {
  const opts = { eq: { is_active: true }, order: { col: 'sort_order', asc: true } };
  if (categoryId) opts.eq.category_id = categoryId;
  return dbQuery('psy_kb_subcategories', opts);
}
async function kbSubcategoryCounts() {
  const { data } = await window.db.from('psy_kb_resources').select('subcategory_id').eq('is_archived', false);
  const map = {};
  (data || []).forEach(r => { if (r.subcategory_id) map[r.subcategory_id] = (map[r.subcategory_id] || 0) + 1; });
  return map;
}
// Resources with category joined, non-archived by default.
// Visibiliti dikuatkuasa client-side (respectVis); `all:true` (halaman admin) langkau.
async function kbResources({ includeArchived = false, all = false } = {}) {
  let q = window.db.from('psy_kb_resources')
    .select('*, category:psy_kb_categories(id,name,slug,color,icon), subcategory:psy_kb_subcategories(id,name,slug,icon), uploader:uploaded_by(id,full_name)')
    .order('updated_at', { ascending: false });
  if (!includeArchived) q = q.eq('is_archived', false);
  const { data, error } = await q;
  if (error) throw error;
  const rows = data || [];
  return all ? rows : rows.filter(kbVisibleToMe);
}
async function kbCategoryCounts() {
  const { data } = await window.db.from('psy_kb_resources').select('category_id').eq('is_archived', false);
  const map = {};
  (data || []).forEach(r => { if (r.category_id) map[r.category_id] = (map[r.category_id] || 0) + 1; });
  return map;
}

// ── Per-user: bookmarks & recently viewed ────────────────────
async function kbMyBookmarkIds() {
  const uid = window.currentUser?.id;
  if (!uid) return { set: new Set(), pinned: new Set() };
  const { data } = await window.db.from('psy_kb_bookmarks').select('resource_id,is_pinned').eq('user_id', uid);
  const set = new Set(), pinned = new Set();
  (data || []).forEach(b => { set.add(b.resource_id); if (b.is_pinned) pinned.add(b.resource_id); });
  return { set, pinned };
}
async function kbToggleBookmark(resourceId, on) {
  const uid = window.currentUser?.id;
  if (!uid) return;
  if (on) {
    await window.db.from('psy_kb_bookmarks').upsert(
      { user_id: uid, resource_id: resourceId }, { onConflict: 'user_id,resource_id' });
  } else {
    await window.db.from('psy_kb_bookmarks').delete().eq('user_id', uid).eq('resource_id', resourceId);
  }
}
async function kbTogglePin(resourceId, pinned) {
  const uid = window.currentUser?.id;
  if (!uid) return;
  await window.db.from('psy_kb_bookmarks').upsert(
    { user_id: uid, resource_id: resourceId, is_pinned: pinned }, { onConflict: 'user_id,resource_id' });
}
// Record a view (upsert timestamp) + bump global counter.
async function kbRecordView(resourceId) {
  const uid = window.currentUser?.id;
  if (!uid) return;
  try {
    await window.db.from('psy_kb_views').upsert(
      { user_id: uid, resource_id: resourceId, viewed_at: new Date().toISOString() },
      { onConflict: 'user_id,resource_id' });
    await window.db.rpc('kb_bump_view', { res: resourceId });
  } catch (_) {}
}

// ── File upload → returns { url, size, ext } ─────────────────
async function kbUploadFile(file) {
  const safe = file.name.replace(/[^\w.\-]+/g, '_');
  const path = `${window.currentUser.id}/${Date.now()}_${safe}`;
  const { error } = await window.db.storage.from(KB_BUCKET).upload(path, file, { upsert: false });
  if (error) throw error;
  const url = window.db.storage.from(KB_BUCKET).getPublicUrl(path).data.publicUrl;
  const ext = (file.name.split('.').pop() || '').toUpperCase();
  return { url, size: file.size, ext };
}

// Infer res_type from a file extension.
function kbTypeFromExt(ext) {
  const e = (ext || '').toLowerCase();
  if (e === 'pdf') return 'pdf';
  if (['doc', 'docx', 'txt', 'rtf', 'odt'].includes(e)) return 'document';
  if (['xls', 'xlsx', 'csv', 'ods'].includes(e)) return 'spreadsheet';
  if (['ppt', 'pptx', 'odp'].includes(e)) return 'presentation';
  if (['mp4', 'mov', 'avi', 'webm', 'mkv'].includes(e)) return 'video';
  if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'].includes(e)) return 'image';
  return 'document';
}

// Infer res_type from an external URL (link/video/image).
function kbTypeFromUrl(url) {
  const u = (url || '').toLowerCase();
  if (!u) return 'link';
  if (/youtube\.com|youtu\.be|vimeo\.com|\.mp4|\.mov|\.webm/.test(u)) return 'video';
  if (/\.(png|jpg|jpeg|gif|webp|svg)(\?|$)/.test(u)) return 'image';
  if (/\.pdf(\?|$)/.test(u)) return 'pdf';
  return 'link';
}

// Small utility: escape text for HTML.
function kbEsc(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
