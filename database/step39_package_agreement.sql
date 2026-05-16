-- ============================================================
-- step39_package_agreement.sql
-- Each package has its own agreement PDF template.
-- Patient signs the agreement matching their recommended package.
-- Fallback to generic 'agreement.pdf' if not set.
-- ============================================================

ALTER TABLE psy_packages
  ADD COLUMN IF NOT EXISTS agreement_pdf TEXT;

COMMENT ON COLUMN psy_packages.agreement_pdf IS
  'Filename of agreement PDF in shared/documents/agreements/ (relative path). NULL = use default agreement.pdf';

-- Seed mapping for known packages (idempotent — only set if column currently null)
UPDATE psy_packages SET agreement_pdf = 'ELIXIR_EOL_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-eol','eol') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR_EOL+_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-eol-plus','pkg-eolplus','eol+','eol-plus') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR__JUMPSTART_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-jumpstart','pkg-js','js','jumpstart') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'ELIXIR__JUMPSTART+_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-jumpstart-plus','pkg-jsplus','js+','jumpstart+') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBD1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obd1','obd1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBDX1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obdx1','obdx1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBDY1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obdy1','obdy1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBG_(NLC)_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obg-nlc','pkg-obg','obg','obg-nlc') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBP1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obp1','obp1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBPX1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obpx1','obpx1') AND agreement_pdf IS NULL;

UPDATE psy_packages SET agreement_pdf = 'OBPY1_-_CONTRACT_[TEMPLATE].pdf'
  WHERE LOWER(package_id) IN ('pkg-obpy1','obpy1') AND agreement_pdf IS NULL;

SELECT 'Step 39 OK — agreement_pdf mapping ready' AS status;
