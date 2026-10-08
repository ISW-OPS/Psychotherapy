-- Audit management #B2-111 (7 Okt 2026) — lanjutkan status semakan
-- Draft→Reviewed→Approved→Active (dah wujud pada psy_reaksi_actions sejak
-- 23 Sept 2026) kepada Kategori & Reaksi juga. DEFAULT 'active' supaya rekod
-- sedia ada TIDAK terjejas (kekal papar kpd pesakit macam biasa); hanya
-- kategori/reaksi BAHARU yang dicipta dari borang akan set 'draft' secara
-- eksplisit (roles/staff/reaksi-item.html) sehingga staf semak.
-- Idempoten — selamat dijalankan berulang kali.

ALTER TABLE psy_reaksi_kategori ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE psy_reaksi_item     ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_reaksi_kategori_status') THEN
    ALTER TABLE psy_reaksi_kategori ADD CONSTRAINT chk_reaksi_kategori_status
      CHECK (status IN ('draft','reviewed','approved','active'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_reaksi_item_status') THEN
    ALTER TABLE psy_reaksi_item ADD CONSTRAINT chk_reaksi_item_status
      CHECK (status IN ('draft','reviewed','approved','active'));
  END IF;
END $$;
