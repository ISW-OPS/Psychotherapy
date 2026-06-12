// ============================================================
// referral.js — jana & sahkan kod rujukan (FASA 1)
// Bergantung pada window.db (Supabase client) yang sudah dimuatkan.
// ============================================================

// Normalkan kod: huruf besar, buang ruang & aksara bukan-alfanumerik.
function normalizeReferralCode(code) {
  return String(code || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
}

// Set aksara selamat — buang yang mudah keliru: 0/O, 1/I/L.
const REFERRAL_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const REFERRAL_LEN = 8;   // 8 aksara rawak, tiada awalan (cth N7K23H5P)

// Hasilkan satu kod rawak (belum disemak unik).
function randomReferralCode() {
  let s = '';
  for (let i = 0; i < REFERRAL_LEN; i++) {
    s += REFERRAL_ALPHABET[Math.floor(Math.random() * REFERRAL_ALPHABET.length)];
  }
  return s;
}

// Jana kod RAWAK unik (sukar diteka).
// Arg name/mrn diterima untuk keserasian tetapi tidak digunakan.
async function generateReferralCode(_name, _mrn) {
  let candidate = randomReferralCode();
  for (let i = 0; i < 25; i++) {
    const exists = await referralCodeExists(candidate);
    if (!exists) return candidate;
    candidate = randomReferralCode();
  }
  // Sangat tidak mungkin sampai sini (31^6 kombinasi) — tambah 3 digit rawak.
  return candidate + Math.floor(Math.random() * 900 + 100);
}

// Semak sama ada kod sudah wujud (case-insensitive).
async function referralCodeExists(code) {
  const c = normalizeReferralCode(code);
  if (!c) return false;
  const { data } = await window.db
    .from('psy_patients')
    .select('id')
    .ilike('referral_code', c)
    .limit(1);
  return !!(data && data.length);
}

// Cari pesakit perujuk dari kod yang dimasukkan.
// Pulangkan { id, mrn, referral_code, full_name } atau null jika tiada.
async function resolveReferrer(code) {
  const c = normalizeReferralCode(code);
  if (!c) return null;
  const { data } = await window.db
    .from('psy_patients')
    .select('id, mrn, referral_code, psy_profiles(full_name)')
    .ilike('referral_code', c)
    .limit(1);
  if (!data || !data.length) return null;
  const p = data[0];
  return {
    id: p.id,
    mrn: p.mrn,
    referral_code: p.referral_code,
    full_name: p.psy_profiles?.full_name || null,
  };
}

// Dedah ke global supaya boleh dipanggil dari halaman.
window.normalizeReferralCode = normalizeReferralCode;
window.randomReferralCode    = randomReferralCode;
window.generateReferralCode  = generateReferralCode;
window.referralCodeExists    = referralCodeExists;
window.resolveReferrer       = resolveReferrer;
