# ghl-transactions-sync — Ledger RAW semua transaksi GHL (Laluan A)

Tarik **SEMUA** transaksi GHL (`/payments/transactions`, ledger bersepadu
rasmi — Stripe+Manual+Invoice sekali gus) ke jadual raw
`psy_ghl_transactions`, untuk tujuan **reconciliation kewangan/accounting**
— bukan untuk paparan sejarah bayaran pesakit (itu kekal `psy_payments`,
diisi `ghl-pull-sync` untuk yuran KOB sahaja).

**Kenapa jadual berasingan (bukan tokok `psy_payments`):** grain berbeza
— jadual ni SEMUA transaksi lokasi (bukan ditapis KOB sahaja), dan
sebahagian transaksi yang sama boleh dah pun ada di `psy_payments` (dari
sudut pandang gate KOB `ghl-pull-sync`). Gabung jadi satu jadual berisiko
double-count. Nanti bila SQL Accounting nak reconcile, ia baca dari sini
(sumber duit sebenar), rujuk silang `psy_payments`/`psy_patients` bila
perlu konteks pesakit.

## Kenapa TIADA akses Stripe secret diperlukan

Endpoint `/payments/transactions` GHL EMBED objek Stripe PENUH
(payment_intent + charge sebenar) dalam field `chargeSnapshot` untuk
transaksi `paymentProviderType==='stripe'` — termasuk `receipt_url`
rasmi Stripe, `payment_method_details` (fpx/kad), status refund/dispute.
Function ni ekstrak `payment_method_type`+`receipt_url`+`charge_id` dari
situ (percuma, guna `GHL_ISW_TOKEN` sahaja). Kalau nanti perlukan butiran
lebih lanjut (fee/net/payout) yang TAK ada dalam `chargeSnapshot`,
`charge_id` (format `pi_...`) + `raw` (objek penuh, ada `balance_transaction`
di dalam charge) dah cukup untuk panggil Stripe API terus (Laluan B)
bila akses tu ada.

## Penemuan API (17 Sept 2026, via debug action `probe_location_transactions`
di `ghl-pull-sync/index.ts`)

- `/payments/transactions?altId=<locationId>&altType=location&limit=&offset=`
  (**TANPA** `contactId`) pulangkan transaksi merentas SEMUA contact
  sekaligus — TAK PERLU loop per-contact macam semua panggilan sedia ada
  dalam `ghl-pull-sync`.
- Pagination guna `limit`+`offset` biasa. **BUKAN** `startAfterId`/
  `startAfter` (dah cuba — diabaikan API, pulang page pertama semula).
- Response ada `totalCount` — akaun ni **~190 transaksi sahaja** (SANGAT
  kecil). Jadi function ni buat **FULL SYNC setiap run** (bukan cursor/
  checkpoint berperingkat macam `ghl-pull-sync` yang perlu handle
  >2000 contact) — upsert idempotent ikut `ghl_transaction_id`, selamat
  diulang.
- `paymentProviderType` field terus bezakan `'stripe'` vs `'manual'` —
  disahkan dalam sampel sebenar (7 stripe, 13 manual dalam 20 sampel awal).

## Padanan pesakit

Best-effort ikut `contactEmail` sahaja (objek transaksi GHL tak bawa
phone terus) — `patient_id` NULL kalau tak jumpa/tiada email. Tak block
sync, sekadar konteks tambahan untuk query nanti.

## Set secret + deploy

Guna semula `GHL_ISW_TOKEN`/`GHL_ISW_LOCATION_ID`/`GHL_PULL_CRON_SECRET`
sedia ada (kategori sama — "GHL pull cron"), **tiada secret baharu**:

```bash
npx supabase functions deploy ghl-transactions-sync --no-verify-jwt --project-ref ipmemyizigwgivccytcu
```

## Uji manual

```bash
curl -s -X POST "https://ipmemyizigwgivccytcu.supabase.co/functions/v1/ghl-transactions-sync" \
  -H "x-cron-secret: <GHL_PULL_CRON_SECRET>" -H "Content-Type: application/json" -d '{}'
```

Semak response — `totalCount`/`scanned`/`synced`/`errorCount`. Disahkan
17 Sept 2026: `190/190 synced, errorCount:0` run pertama testing.

## Jadualkan (pg_cron + pg_net)

**DAH DIJADUALKAN (17 Sept 2026, testing sahaja)** — `pg_cron` job
`ghl-transactions-sync`, setiap 30 minit (jobid 8, `active:true`).
Bayaran baharu pesakit sekarang masuk sistem SENDIRI, tapisan test/live
automatik terpakai setiap run.

```sql
select cron.schedule('ghl-transactions-sync', '*/30 * * * *', $$
  select net.http_post(
    url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/ghl-transactions-sync',
    headers := jsonb_build_object('Content-Type','application/json','x-cron-secret','<GHL_PULL_CRON_SECRET>'),
    body    := '{}'::jsonb
  );
$$);
```

## Nota & had

- **Bukan realtime** — pull berkala sahaja, sama falsafah dgn
  `ghl-pull-sync` (elak masalah GHL Workflow/webhook yang tak boleh
  dipercayai — lihat nota sejarah `ghl-pull-sync/README.md`).
- **Tiada UI** buat masa ni — data backend sahaja untuk reconciliation/
  accounting masa depan. Jangan tokok dalam `roles/staff/payment-admin.html`
  (grain tak sepadan — lihat komen skema `06_payments.sql`).
- **Belum deploy ke production** — testing sahaja (`ipmemyizigwgivccytcu`).
- Log ringkasan setiap run ke `psy_audit_log`
  (`action='ghl_transactions_sync.run'`).
