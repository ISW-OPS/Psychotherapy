-- ═══════════════════════════════════════════════════════════════════
-- 20261028 — psy_external_affiliates: tambah IC + alamat affiliate
-- Borang pendaftaran "Duta Sihat Sefitrahnya" kumpul No Kad Pengenalan +
-- Alamat affiliate (query key GHL disahkan: no_ic_agent, alamat_agent),
-- tak ada tempat disimpan lagi — tambah sebelum data ni hilang/dibuang.
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE psy_external_affiliates ADD COLUMN IF NOT EXISTS ic_number TEXT;
ALTER TABLE psy_external_affiliates ADD COLUMN IF NOT EXISTS address TEXT;
