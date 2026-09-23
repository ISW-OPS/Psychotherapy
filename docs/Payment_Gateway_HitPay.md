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

## 6) Auto-Caj Ansuran (kad tersimpan) — Recurring Billing on-demand

**Status: kod siap 23 Sept, BELUM migration/deploy/uji.** Sebelum ni HitPay cuma
checkout-link one-time (pesakit kena klik & bayar SETIAP ansuran). Kini pesakit
boleh **lampir kad SEKALI**, lepas tu tiap checkpoint ansuran seterusnya
**di-auto-caj sendiri** oleh cron pada tarikh due (jumlah BERBEZA setiap
checkpoint — bukan subscription/cycle tetap HitPay, guna endpoint on-demand
`POST /v1/charge/recurring-billing/{id}`).

**Fail terlibat:**
- `_shared/payments/types.ts` + `hitpay.ts` — `createCardAuthorization()`,
  `chargeSavedCard()`, `verifyRecurringWebhook()` (kontrak opsyenal baharu)
- `_shared/kob_autocharge.ts` — `createKobCardAttachLink()` (sesi lampir-kad BERDIRI
  SENDIRI, RM1) + `applyInstallmentPayment()` (logik kumulatif kongsi dgn `kob_installment_topup`)
- `_shared/kob_deposit_fulfill.ts` — `fulfillKobDeposit()` / `fulfillKobPackage()` +
  helper (`activatePackageForPatient` dll) diextract dari `payments-webhook` supaya
  BOLEH dipanggil dari DUA webhook (form-encoded biasa DAN JSON recurring)
- `payments-kob-initiate` — mode baharu `'attach_card'` (staff-only) + param
  `saveCard` pada mode `'installment'` (staff/pesakit pilih)
- `payments-webhook-recurring` (**fungsi BAHARU**) — webhook JSON `Hitpay-Signature`
  utk event `method_attached`/`method_detached`/`subscription_updated`
  (BEZA drpd `payments-webhook` form-encoded sedia ada)
- `event-reminders` — langkah baharu `runInstallmentAutoChargeCheck` (8b), jalan
  SEBELUM `installment_overdue`
- `roles/staff/kob-detail.html` — checkbox "Simpan kad" di Langkah 5 (deposit
  installment) + badge status kad & butang "Hantar Pautan Lampir Kad" (status paid)
- `database/schema/09_kob.sql` + `18_notifications_automations.sql` (sumber kebenaran)
- `supabase/migrations/20260923_installment_autocharge.sql` (utk DB sedia ada)

**Reka bentuk akhir (23 Sept, lepas bincang dgn management) — DUA cara lampir kad:**
1. **Serentak dgn deposit** (utama) — di Langkah 5 kob-detail.html, checkbox
   "Simpan kad" (default ON) utk mode Installment. DITANDA → deposit dibayar
   MELALUI recurring-billing (kad SAHAJA ditawar, FPX/e-wallet TIADA — had
   HitPay, tak boleh simpan kad drpd sesi FPX), kad terus tersimpan serentak
   dgn deposit — TIADA RM1 berasingan. NYAHTANDA → deposit macam biasa
   (semua kaedah termasuk FPX), ansuran seterusnya kekal manual.
2. **Berdiri sendiri (fallback)** — `createKobCardAttachLink` (RM1 pengesahan),
   utk pesakit yang deposit-nya sudah dibayar FPX/manual tapi kemudian nak
   join auto-caj. Butang "Hantar Pautan Lampir Kad" di kob-detail.html
   (status partial) guna laluan ni.

**Langkah sebelum live:**
1. Jalankan `supabase/migrations/20260923_installment_autocharge.sql` — TESTING dulu, PROD kemudian.
2. **Sahkan dgn HitPay support akaun aktifkan ciri "Recurring Billing"** (bukan semua akaun on by default).
3. Daftar webhook BAHARU di HitPay Dashboard → Developers → Webhook Endpoints:
   `https://<project>.supabase.co/functions/v1/payments-webhook-recurring`
   (event: `recurring_billing.method_attached`, `method_detached`, `subscription_updated`)
   — ASING drpd webhook `payments-webhook` sedia ada (payment-requests).
4. Deploy: `supabase functions deploy payments-webhook-recurring --no-verify-jwt`,
   `supabase functions deploy payments-kob-initiate`, `supabase functions deploy event-reminders`,
   `supabase functions deploy payments-webhook`.
5. **Uji di SANDBOX dulu — WAJIB sebelum prod**: sahkan checkout "deposit +
   simpan kad" (amount=deposit sebenar, bukan RM1) betul-betul **serah duit**
   tu kat ISW sebagai bayaran sah (bukan sekadar tokenize kad tanpa duit
   bergerak) — ini TAK disahkan dari dokumentasi awam HitPay, kena test
   transaksi sebenar di sandbox. Kalau tak settle sbg bayaran, deposit
   pesakit akan "hilang" (kad tersimpan tapi duit tak sampai).
6. Aktifkan templat WA (`is_active=true`) di UI Automatic Messages bila sedia:
   `card_attach_invite`, `installment_autocharge_success`, `installment_autocharge_failed`.
7. **dashboard-paste/**: fail `payments-webhook.ts`, `payments-initiate.ts` di situ
   ialah bundle flattened (deploy via paste Supabase Studio) — kalau staff pakai
   kaedah ni (bukan CLI), fail bundle BERKAITAN (`payments-webhook`,
   `payments-kob-initiate`, + `payments-webhook-recurring` baharu) perlu
   di-generate semula sebelum paste (tiada skrip build ditemui dlm repo — perlu
   disahkan macam mana bundle asal dijana).

## Nota keselamatan / hardening

- ✅ **Harga disahkan server-side** dalam `payments-initiate` (`verifiedAmount`) —
  pakej & produk disemak semula dari DB, client tak boleh usik amaun.
- ✅ **Webhook HMAC** — tolak panggilan palsu.
- ✅ **Semak silang amaun** dalam webhook (toleransi 1 sen).
- ✅ **Idempotent** — webhook boleh cetus berkali; guard `status='completed'` elak double-fulfill.
- ⚠️ **Jenis `appointment` / `plan_extension` / `kob`** masih guna amaun DB-derived dari client
  (bukan revenue tinggi). Boleh diperketat kemudian.
- 🔒 SST masih 0 — aktifkan bila syarikat daftar SST.
