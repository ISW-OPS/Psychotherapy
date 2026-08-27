-- Model ansuran RATA (deposit + tempoh(bulan) + bayaran bulanan tetap) & harga
-- 4-tier KOB (Now/Today) — lihat database/schema/05_packages.sql utk versi
-- sumber kebenaran + nota lengkap.
--
-- Kolum ni dah lama wujud dalam CREATE TABLE psy_packages di schema/, tapi
-- CREATE TABLE IF NOT EXISTS tak buat apa-apa bila jadual dah wujud — sebab
-- tu tak pernah "sampai" ke PRODUCTION walaupun testing dah jalan lama
-- (sama corak dgn gotcha status/internal_notes/automation_flags/access_flags/
-- supplies/addons 14 Ogos). Ni yang buat dropdown "Cadangan Pakej Rawatan" di
-- kob-detail.html kosong di prod — SELECT eksplisit kolum ni gagal (PostgREST
-- 400 kolum tak wujud), data jadi null → cache pakej kosong, senyap tanpa error
-- dipaparkan.

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS installment_duration_months INT,
  ADD COLUMN IF NOT EXISTS installment_monthly_amount NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS nilai_program NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS harga_asal NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS today_price NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS today_installment_deposit_amount NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS today_installment_duration_months INT,
  ADD COLUMN IF NOT EXISTS today_installment_monthly_amount NUMERIC(10,2);
