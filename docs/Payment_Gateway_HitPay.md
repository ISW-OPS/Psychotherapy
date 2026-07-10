# Payment Gateway — HitPay (provider-agnostic)

Sistem bayaran ISW kini boleh terima **duit sebenar** melalui gateway, menggantikan
simulasi lama (`setTimeout` + tulis resit terus di client).

Reka bentuk **provider-agnostic** — HitPay hari ini, boleh tukar **Fiuu** nanti dengan
menulis satu adapter baru sahaja. Kod client, DB, dan Edge Function tidak berubah.

---

## Seni bina — 4 lapisan

| Lapisan | Fail | Tahu HitPay? |
|--------|------|:---:|
| 1. UI / Client | `roles/patient/payment.html` → `processPayment()` | ❌ |
| 2. Orkestra | `supabase/functions/payments-initiate` + `payments-webhook` | ❌ |
| 3. **Adapter** ⭐ | `supabase/functions/_shared/payments/hitpay.ts` | ✅ (satu-satunya) |
| 4. Gateway | HitPay (FPX / kad / e-wallet) | — |

**Aliran bayaran:**
1. Pesakit klik *Pay* → `processPayment()` panggil `payments-initiate`
2. `payments-initiate` sahkan harga server-side → cipta baris `psy_payments` **status=`pending`**
   (simpan `intent` = pendingItems) → panggil adapter → dapat URL HitPay → redirect pesakit
3. Pesakit bayar di HitPay → HitPay panggil `payments-webhook` (server-ke-server)
4. `payments-webhook` sahkan HMAC → **fulfillOrder()** (aktif pakej/plan/KOB/order) →
   tanda `psy_payments` **status=`completed`**
5. Pesakit kembali ke `payment.html?ref=…` → poll status → papar resit

> **Prinsip penting:** pakej/plan hanya diaktifkan **selepas** webhook sahkan bayaran —
> bukan di client. Ini elak pesakit dapat pakej tanpa bayar.

---

## 1) Jalankan migration

Di Supabase SQL Editor — **TESTING dulu**, kemudian **PROD (xmvqvq)**:

```
database/step94_payment_gateway.sql
```

Menambah pada `psy_payments`: `gateway_provider`, `gateway_ref`, `gateway_status`,
`intent` (JSONB), `fulfilled_at` + benarkan `payment_method='gateway'` + index `gateway_ref`.

---

## 2) Set secrets (Edge Function)

Dapatkan kunci dari **HitPay Dashboard → Settings → API Keys**
(guna **Sandbox** dulu untuk uji tanpa duit betul).

```bash
supabase secrets set \
  PAYMENT_PROVIDER=hitpay \
  HITPAY_MODE=sandbox \
  HITPAY_API_KEY=xxxxxxxx \
  HITPAY_SALT=xxxxxxxx
```

`SUPABASE_URL` & `SUPABASE_SERVICE_ROLE_KEY` di-inject automatik oleh Supabase.

Bila sedia untuk LIVE: tukar `HITPAY_MODE=live` + kunci akaun live.

---

## 3) Deploy Edge Functions

```bash
# initiate — perlukan JWT (pesakit log masuk)
supabase functions deploy payments-initiate

# webhook — PUBLIC (HitPay panggil tanpa JWT). WAJIB --no-verify-jwt
supabase functions deploy payments-webhook --no-verify-jwt
```

> ⚠️ `payments-webhook` **mesti** `--no-verify-jwt` — kalau tidak HitPay tak boleh panggil.
> Keselamatan datang dari HMAC (`HITPAY_SALT`), bukan JWT.

URL webhook (diberi automatik kepada HitPay oleh `payments-initiate`):
`https://<project>.supabase.co/functions/v1/payments-webhook`

---

## 4) Uji (sandbox)

1. Log masuk sebagai pesakit → ada invois belum bayar → klik **Pay**
2. Diredirect ke halaman HitPay sandbox → guna kad ujian HitPay
3. Selepas bayar → kembali ke `payment.html` → tunggu 1-2 saat →
   banner "Pembayaran berjaya" + resit muncul + pakej/plan aktif
4. Semak `psy_payments`: `status=completed`, `gateway_status=completed`, `fulfilled_at` terisi

**Debug:** `supabase functions logs payments-webhook`

---

## 5) Tukar ke Fiuu nanti — apa yang berubah

Hanya **Lapisan 3**:

1. Tulis `supabase/functions/_shared/payments/fiuu.ts` (patuh `PaymentProvider` di `types.ts`)
2. Daftar dalam `_shared/payments/index.ts`:
   ```ts
   import { fiuu } from './fiuu.ts'
   const PROVIDERS = { hitpay, fiuu }
   ```
3. Tukar secret: `supabase secrets set PAYMENT_PROVIDER=fiuu` (+ kunci Fiuu)
4. Re-deploy kedua-dua function

**TIDAK berubah:** `payment.html`, logik bisnes, skema DB, `payments-initiate`,
`payments-webhook`.

---

## Nota keselamatan / hardening

- ✅ **Harga disahkan server-side** dalam `payments-initiate` (`verifiedAmount`) —
  pakej & produk disemak semula dari DB, client tak boleh usik amaun.
- ✅ **Webhook HMAC** — tolak panggilan palsu.
- ✅ **Semak silang amaun** dalam webhook (toleransi 1 sen).
- ✅ **Idempotent** — webhook boleh cetus berkali; guard `status='completed'` elak double-fulfill.
- ⚠️ **Jenis `appointment` / `plan_extension` / `kob`** masih guna amaun DB-derived dari client
  (bukan revenue tinggi). Boleh diperketat kemudian.
- 🔒 SST masih 0 — aktifkan bila syarikat daftar SST.
