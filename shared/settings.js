// ============================================================
// SETTINGS — pembaca tetapan sistem global (psy_settings)
// ------------------------------------------------------------
// Guna di mana-mana halaman untuk baca nilai global (cth deadline
// pengesahan sesi, mata wang, nama klinik) tanpa hardcode.
//
//   await iswLoadSettings();                 // muat sekali (cache)
//   iswGetSetting('currency', 'MYR');        // baca dgn fallback
//
// Tulis hanya dibenarkan untuk super_admin (dikuatkuasa RLS).
// ============================================================

window.iswSettings = window.iswSettings || {};
window.__iswSettingsLoaded = false;

async function iswLoadSettings(force = false) {
  if (window.__iswSettingsLoaded && !force) return window.iswSettings;
  try {
    const { data, error } = await window.db.from('psy_settings').select('key, value');
    if (error) throw error;
    window.iswSettings = {};
    (data || []).forEach(r => { window.iswSettings[r.key] = r.value; });
    window.__iswSettingsLoaded = true;
    // Sync warna utama (jenama) dari DB → cache peranti + apply serta-merta
    try {
      const pc = window.iswSettings.primary_color;
      if (typeof pc === 'string' && /^#[0-9A-Fa-f]{6}$/.test(pc)) {
        localStorage.setItem('isw_primary_color', pc);
        window.iswApplyPrimary?.(pc);
      }
    } catch (_) {}
  } catch (e) {
    console.warn('iswLoadSettings gagal:', e.message || e);
  }
  return window.iswSettings;
}

function iswGetSetting(key, fallback = null) {
  return (key in window.iswSettings) ? window.iswSettings[key] : fallback;
}

// Tulis satu tetapan (super_admin sahaja — RLS akan tolak selainnya).
async function iswSetSetting(key, value) {
  const uid = (await window.db.auth.getUser()).data.user?.id || null;
  const { error } = await window.db.from('psy_settings')
    .upsert({ key, value, updated_by: uid, updated_at: new Date().toISOString() }, { onConflict: 'key' });
  if (error) throw error;
  window.iswSettings[key] = value;
  return true;
}

window.iswLoadSettings = iswLoadSettings;
window.iswGetSetting  = iswGetSetting;
window.iswSetSetting  = iswSetSetting;
