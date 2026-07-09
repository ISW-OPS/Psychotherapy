-- STEP 89 — Meta template: category + language pada psy_auto_messages
-- ─────────────────────────────────────────────────────────────────────────
-- Untuk Template Builder (galeri berkategori + bahasa). Idempotent.
-- WAJIB run TESTING & PROD.

alter table psy_auto_messages add column if not exists category text;
alter table psy_auto_messages add column if not exists language text default 'ms';

select 'Step 89 OK — psy_auto_messages.category/language sedia' as status;
