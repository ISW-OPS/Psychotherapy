-- Produk & Bahan: sokong gallery multi-gambar (sebelum ni hanya 1 image_url),
-- sama corak dgn psy_products (image_url = utama/image_urls[0], image_urls = gallery).
-- Idempoten.

ALTER TABLE psy_recommended_products ADD COLUMN IF NOT EXISTS image_urls JSONB DEFAULT '[]';

-- Produk sedia ada yang dah ada image_url tunggal — isi image_urls supaya gallery
-- terus papar gambar lama tu sebagai gambar pertama (bukan kosong senyap).
UPDATE psy_recommended_products
SET image_urls = jsonb_build_array(image_url)
WHERE image_url IS NOT NULL AND (image_urls IS NULL OR image_urls = '[]'::jsonb);
