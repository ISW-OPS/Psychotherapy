-- Jualan Walk-in — jualan produk kepada pembeli bukan pesakit (datang terus ke
-- HQ). psy_payments.patient_id KEKAL NULL utk baris ni; nama/telefon pembeli
-- disimpan di lajur baharu ni (bukan psy_patients, sbb pembeli tiada akaun
-- pesakit). Lihat roles/staff/jualan-walkin.html + database/schema/06_payments.sql.
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS buyer_name TEXT;
ALTER TABLE psy_payments ADD COLUMN IF NOT EXISTS buyer_phone TEXT;

COMMENT ON COLUMN psy_payments.buyer_name IS
  'Nama pembeli walk-in (bukan pesakit) — NULL utk bayaran pesakit biasa (patient_id ada).';
COMMENT ON COLUMN psy_payments.buyer_phone IS
  'No. telefon pembeli walk-in (optional) — NULL utk bayaran pesakit biasa.';

-- vw_payment_ledger — papar nama pembeli walk-in (bukan "Pesakit") di Payment
-- Management. Sama definisi dgn 06_payments.sql, cuma contact_name diubah.
CREATE OR REPLACE VIEW vw_payment_ledger WITH (security_invoker = true) AS
SELECT
  p.id::text                       AS id,
  'ISW'                             AS source,
  COALESCE(p.paid_at, p.created_at) AS tx_date,
  p.patient_id,
  COALESCE(pt.full_name, p.buyer_name, CASE WHEN p.patient_id IS NULL THEN 'Walk-in' ELSE 'Pesakit' END) AS contact_name,
  p.total                          AS amount,
  p.payment_method                 AS method,
  COALESCE(p.gateway_provider, p.payment_method) AS provider,
  p.status,
  p.receipt_ref                    AS reference,
  p.ghl_transaction_id,
  p.invoice_number,
  NULL::TIMESTAMPTZ                AS issue_date,
  p.notes
FROM psy_payments p
LEFT JOIN psy_patients pt ON pt.id = p.patient_id

UNION ALL

SELECT
  g.id::text                       AS id,
  'GHL'                             AS source,
  g.ghl_created_at                 AS tx_date,
  g.patient_id,
  g.contact_name,
  g.amount,
  g.payment_provider_type          AS method,
  g.payment_provider_type          AS provider,
  g.status,
  COALESCE(g.invoice_number, g.ghl_transaction_id) AS reference,
  g.ghl_transaction_id,
  g.invoice_number,
  g.issue_date,
  g.entity_source_name             AS notes
FROM psy_ghl_transactions g
WHERE g.ghl_transaction_id IS NULL
   OR g.ghl_transaction_id NOT IN (SELECT ghl_transaction_id FROM psy_payments WHERE ghl_transaction_id IS NOT NULL);
