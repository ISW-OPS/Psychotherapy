-- ============================================================
-- PLAN CHECK-INS — scope goals per week
-- Run once in Supabase SQL editor (idempotent)
-- ============================================================

ALTER TABLE plan_check_ins
  ADD COLUMN IF NOT EXISTS week_number INT;

-- Drop old uniqueness if exists, re-add with week scope
-- (optional — only if app ever enforced uniqueness at DB)
