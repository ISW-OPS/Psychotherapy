-- Phase 1: Harga tambah minggu rawatan (extension) — admin tetapkan per pakej.

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS extension_price_per_week NUMERIC(10,2) DEFAULT 50;

COMMENT ON COLUMN psy_packages.extension_price_per_week IS
  'Harga (RM) untuk tambah satu minggu rawatan bila patient miss sesi. Default RM 50.';
