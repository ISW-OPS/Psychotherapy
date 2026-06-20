-- Add height_cm to patient record.
-- Single source of truth for height → used to auto-compute BMI on the
-- patient dashboard and Bacaan Saya (vitals) page. Editable in Profil and
-- the "+ Catat Bacaan Sendiri" modal.
alter table psy_patients add column if not exists height_cm numeric;
