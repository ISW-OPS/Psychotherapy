-- Seller / Platform: tambah medan utk borang penuh Tambah/Edit Seller
-- (Deskripsi/Penerangan berasingan drpd Nota dalaman; Verified By = staff
-- yang sahkan). Idempoten.

ALTER TABLE psy_recommended_sellers ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE psy_recommended_sellers ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES psy_profiles(id) ON DELETE SET NULL;
