-- Jaring keselamatan DB terhadap bug dedup pesakit GHL (syncContactToPatient
-- gagal senyap cari padanan phone sedia ada, cipta pesakit BAHARU setiap
-- kali dipanggil semula utk contact yg sama — punca sebenar dalam kod masih
-- disiasat 28-29 Sept 2026). Constraint ni tak fix punca, tapi tukar tingkah
-- laku dari "senyap cipta pendua" ke "INSERT gagal terus" — nampak jelas
-- dalam psy_audit_log/errors, bukan senyap corrupt data lagi.
--
-- Skop HANYA referral_source='GHL' (bukan semua psy_patients) — rekod
-- staff-created/self-signup masih boleh kongsi phone (cth ahli keluarga
-- guna nombor sama), cuma pesakit auto-sync GHL yang patut 1 phone = 1 rekod.
CREATE UNIQUE INDEX IF NOT EXISTS idx_psy_patients_ghl_phone_unique
  ON psy_patients (phone) WHERE referral_source = 'GHL' AND phone IS NOT NULL;
