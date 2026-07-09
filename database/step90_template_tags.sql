-- STEP 90 — Tag + pencipta pada psy_auto_messages (Template Builder sebijik)
-- ─────────────────────────────────────────────────────────────────────────
-- Untuk medan Tag + metadata "Dicipta Oleh". Idempotent. WAJIB run TESTING & PROD.

alter table psy_auto_messages add column if not exists tags jsonb default '[]'::jsonb;
alter table psy_auto_messages add column if not exists created_by uuid references psy_profiles(id) on delete set null;

select 'Step 90 OK — psy_auto_messages.tags/created_by sedia' as status;
