-- DNA Test Step 3 (Activate Kit ATGC) — tambah "Coach Yang Uruskan" (dropdown
-- pilih staf), berasingan dari atgc_activated_by (akaun yang literal klik
-- butang, cth staf Customer Service boleh klik bagi pihak coach).
-- Rujuk: database/schema/26_dna_test.sql, roles/staff/dna-test.html

ALTER TABLE psy_dna_test_process
  ADD COLUMN IF NOT EXISTS atgc_coach_id UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
