-- Pilihan eksplisit per mesej automasi: "Lampirkan invois PDF" (trigger ansuran).
alter table psy_automation_messages add column if not exists attach_invoice boolean not null default false;

-- Mesej automasi seed "Peringatan Ansuran Pakej" (20260921d) melampirkan invois.
update psy_automation_messages set attach_invoice = true
where automation_id in (select id from psy_automations where name = 'Peringatan Ansuran Pakej');

notify pgrst, 'reload schema';
