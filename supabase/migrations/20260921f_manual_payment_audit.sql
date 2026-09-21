-- Bayaran manual yang boleh diaudit: rujukan bank, staf perekod, sasaran bayaran, bendera separa.
-- paid_at = tarikh & masa bayaran SEBENAR (bukan masa staf key-in); created_at = masa direkod.
alter table psy_payments add column if not exists bank_reference text;
alter table psy_payments add column if not exists recorded_by uuid references psy_profiles(id) on delete set null;
alter table psy_payments add column if not exists paid_for_type text;
alter table psy_payments add column if not exists paid_for_seq int;
alter table psy_payments add column if not exists paid_for_ref text;
alter table psy_payments add column if not exists is_partial boolean not null default false;

alter table psy_payments drop constraint if exists psy_payments_paid_for_type_check;
alter table psy_payments add constraint psy_payments_paid_for_type_check
  check (paid_for_type is null or paid_for_type in ('package','installment','invoice','consultation','product','other'));

-- Bayaran manual lama: no. rujukan yang ditaip staf (invoice_number) ialah rujukan bank/transfer.
alter table psy_payments disable trigger user;
update psy_payments set bank_reference = invoice_number
  where payment_method = 'manual' and bank_reference is null and invoice_number is not null;
alter table psy_payments enable trigger user;

notify pgrst, 'reload schema';
