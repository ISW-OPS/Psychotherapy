-- Kolum harga berasingan untuk "Tambah Sesi" (1 sesi tunggal pada minggu sedia
-- ada, cth patient-hub.html) — sebelum ni dikira secara automatik sebagai
-- extension_price_per_week / 2, tiada tempat staff boleh tetapkan sendiri.
-- Lihat database/schema/05_packages.sql utk versi sumber kebenaran + nota lengkap.

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS extension_price_per_session NUMERIC(10,2) DEFAULT 25;
