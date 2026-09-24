-- Audit management 23 Sept 2026, Tier 4 (#B1-7, #B1-8): DNA Test auto-create dari
-- entitlement pakej + config Package Master (Required/bilangan/timing), pola sama
-- macam hk1_types Sesi 1:1.
-- Rujuk: database/schema/05_packages.sql, database/schema/26_dna_test.sql

ALTER TABLE psy_packages ADD COLUMN IF NOT EXISTS dna_test_required BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE psy_packages ADD COLUMN IF NOT EXISTS dna_test_count INT DEFAULT 1;
ALTER TABLE psy_packages ADD COLUMN IF NOT EXISTS dna_test_week INT DEFAULT 1;

ALTER TABLE psy_dna_test_process ADD COLUMN IF NOT EXISTS plan_id UUID REFERENCES psy_treatment_plans(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_dna_test_plan ON psy_dna_test_process(plan_id) WHERE plan_id IS NOT NULL;
