// ============================================================
// VITALS THRESHOLDS — ambang Normal/Tidak Normal/Kritikal per-vital
// ------------------------------------------------------------
// Sumber tunggal ambang bacaan vitals — dulu bertabur (hardcode) di
// vitals-detail.html/vitals.html/patient/vitals.html. Kini baca dari
// psy_settings key 'vitals_thresholds' (diedit di tetapan.html oleh
// super_admin/doktor). DEFAULTS di bawah cuma fallback selamat kalau
// settings gagal muat — bukan sumber sebenar.
//
//   await iswLoadSettings();               // (dari shared/settings.js — panggil dulu)
//   iswClassifyVital('heart_rate', 105);   // → {status:'high', label:'Tinggi'}
//   iswAbnormalReason(vitalsRow);          // → 'Tekanan darah tinggi' | null
// ============================================================

const ISW_VITALS_DEFAULTS = {
  bp_systolic:      { normal_min: 90,   normal_max: 129,  critical_min: null, critical_max: null },
  bp_diastolic:     { normal_min: 60,   normal_max: 84,   critical_min: null, critical_max: null },
  heart_rate:       { normal_min: 60,   normal_max: 100,  critical_min: null, critical_max: null },
  temperature:      { normal_min: 36.1, normal_max: 37.2, critical_min: null, critical_max: null },
  spo2:             { normal_min: 95,   normal_max: null, critical_min: null, critical_max: null },
  respiratory_rate: { normal_min: 12,   normal_max: 20,   critical_min: null, critical_max: null },
};

const ISW_VITALS_META = {
  bp_systolic:      { label: 'Tekanan darah (sistolik)', short: 'Tekanan darah', unit: 'mmHg' },
  bp_diastolic:     { label: 'Tekanan darah (diastolik)', short: 'Tekanan darah', unit: 'mmHg' },
  heart_rate:       { label: 'Nadi', short: 'Nadi', unit: 'bpm' },
  temperature:      { label: 'Suhu badan', short: 'Suhu badan', unit: '°C' },
  spo2:             { label: 'SpO2', short: 'SpO2', unit: '%' },
  respiratory_rate: { label: 'Kadar pernafasan', short: 'Kadar pernafasan', unit: '/min' },
};

function iswVitalsThresholds() {
  const cfg = (typeof iswGetSetting === 'function') ? iswGetSetting('vitals_thresholds', null) : null;
  const merged = {};
  Object.keys(ISW_VITALS_DEFAULTS).forEach(k => {
    merged[k] = { ...ISW_VITALS_DEFAULTS[k], ...(cfg && cfg[k] ? cfg[k] : {}) };
  });
  return merged;
}

// value boleh null/undefined (bacaan tak diisi) → status 'na'.
function iswClassifyVital(vitalKey, value) {
  const t = iswVitalsThresholds()[vitalKey];
  if (!t || value === null || value === undefined || value === '') return { status: 'na', label: '' };
  const v = Number(value);
  if (Number.isNaN(v)) return { status: 'na', label: '' };

  if (t.critical_min !== null && t.critical_min !== undefined && v < Number(t.critical_min)) return { status: 'critical_low', label: 'Kritikal' };
  if (t.critical_max !== null && t.critical_max !== undefined && v >= Number(t.critical_max)) return { status: 'critical_high', label: 'Kritikal' };
  if (t.normal_min !== null && t.normal_min !== undefined && v < Number(t.normal_min)) return { status: 'low', label: 'Rendah' };
  if (t.normal_max !== null && t.normal_max !== undefined && v >= Number(t.normal_max)) return { status: 'high', label: 'Tinggi' };
  return { status: 'ok', label: 'Normal' };
}

// Sebab ringkas (Malay) — ambil vital PERTAMA yang tak 'ok'/'na'. NULL kalau semua OK.
function iswAbnormalReason(row) {
  if (!row) return null;
  for (const key of Object.keys(ISW_VITALS_META)) {
    const c = iswClassifyVital(key, row[key]);
    if (c.status !== 'ok' && c.status !== 'na') {
      const dir = (c.status === 'high' || c.status === 'critical_high') ? 'tinggi' : 'rendah';
      return `${ISW_VITALS_META[key].short} ${dir}`;
    }
  }
  return null;
}

// Semua vital tak-normal pada satu rekod — utk highlight sel jadual (vitals-history.html).
// → [{key, status, label, meta}]
function iswAbnormalFields(row) {
  if (!row) return [];
  const out = [];
  Object.keys(ISW_VITALS_META).forEach(key => {
    const c = iswClassifyVital(key, row[key]);
    if (c.status !== 'ok' && c.status !== 'na') out.push({ key, ...c, meta: ISW_VITALS_META[key] });
  });
  return out;
}

// Nota ambang ringkas utk tooltip, cth "≥130 mmHg" / "<90 mmHg". '' kalau status 'ok'/'na'.
function iswThresholdDescribe(vitalKey, status) {
  const t = iswVitalsThresholds()[vitalKey];
  const meta = ISW_VITALS_META[vitalKey];
  if (!t || !meta) return '';
  const unit = meta.unit;
  if (status === 'critical_high') return `≥${t.critical_max} ${unit}`;
  if (status === 'critical_low') return `<${t.critical_min} ${unit}`;
  if (status === 'high') return `≥${t.normal_max} ${unit}`;
  if (status === 'low') return `<${t.normal_min} ${unit}`;
  return '';
}

window.ISW_VITALS_DEFAULTS = ISW_VITALS_DEFAULTS;
window.ISW_VITALS_META = ISW_VITALS_META;
window.iswVitalsThresholds = iswVitalsThresholds;
window.iswClassifyVital = iswClassifyVital;
window.iswAbnormalReason = iswAbnormalReason;
window.iswAbnormalFields = iswAbnormalFields;
window.iswThresholdDescribe = iswThresholdDescribe;
