# 💳 Payment — Hub Index

Peta **semua fail sistem bayaran ISW**, disusun ikut **4 lapisan**.

> ⚠️ Fail sebenar **tidak** disimpan dalam folder ini — ia kekal di lokasi asal kerana
> Supabase (Edge Function mesti folder terus di `functions/<nama>/`) dan routing halaman
> memerlukan begitu. Folder `payment/` ini hanya **peta rujukan** supaya senang cari semua
> bahagian bayaran dari satu tempat.

Reka bentuk **provider-agnostic**: HitPay hari ini, tukar **Fiuu** nanti = tulis satu adapter
baru (Layer 3) sahaja. Layer 1, 2, 4 tidak berubah.

---

## 🔁 Aliran bayaran (ringkas)

```
Pesakit klik Pay
  → [L1] processPayment()  ──POST──▶  [L2] payments-initiate
                                         · sahkan harga server-side
                                         · cipta psy_payments status=pending (+intent)
                                         · [L3] adapter → [L4] HitPay
  ◀──── redirect ke URL checkout HitPay ────
Pesakit bayar di HitPay
  → [L4] HitPay ──webhook──▶ [L2] payments-webhook
                                · [L3] adapter sahkan HMAC
                                · fulfillOrder() → aktif pakej/plan/KOB/order
                                · psy_payments status=completed
  → [L1] handlePaymentReturn() poll status → papar resit
```

**Prinsip:** pakej/plan diaktifkan **hanya selepas** webhook sahkan bayaran — bukan di client.

---

## 🧱 Layer 1 — UI / Client
Kumpul niat bayaran, redirect ke gateway, papar status. *Tak tahu apa itu HitPay.*

- [../roles/patient/payment.html](../roles/patient/payment.html)
  - `processPayment()` — initiate + redirect
  - `handlePaymentReturn()` — poll status bila pesakit balik (`?ref=…`)

## 🧠 Layer 2 — Orkestra (Edge Functions)
Sahkan harga, simpan pending, fulfillment selepas bayaran sah. *Tak tahu apa itu HitPay.*

- [../supabase/functions/payments-initiate/index.ts](../supabase/functions/payments-initiate/index.ts) — mula bayaran + sahkan harga
- [../supabase/functions/payments-webhook/index.ts](../supabase/functions/payments-webhook/index.ts) — sahkan HMAC + `fulfillOrder()` idempotent

## 🔌 Layer 3 — Adapter (soket tukar-ganti) ⭐
Satu-satunya tempat yang tahu HitPay. Tukar gateway = tambah fail di sini sahaja.

- [../supabase/functions/_shared/payments/types.ts](../supabase/functions/_shared/payments/types.ts) — kontrak neutral (`PaymentProvider`)
- [../supabase/functions/_shared/payments/hitpay.ts](../supabase/functions/_shared/payments/hitpay.ts) — adapter HitPay (createPayment + verifyWebhook)
- [../supabase/functions/_shared/payments/index.ts](../supabase/functions/_shared/payments/index.ts) — pemilih provider (`PAYMENT_PROVIDER`)
- `fiuu.ts` — *(belum ada — tambah di sini bila migrasi ke Fiuu)*

## 🏦 Layer 4 — Gateway (luar sistem)
HitPay → FPX / kad / e-wallet → duit masuk. Nanti boleh tukar Fiuu.

---

## 🗄️ Sokongan (bukan layer)

- **DB migration:** [../database/step94_payment_gateway.sql](../database/step94_payment_gateway.sql)
  — kolum gateway pada `psy_payments` (gateway_provider, gateway_ref, gateway_status, intent, fulfilled_at)
- **Panduan deploy penuh:** [../docs/Payment_Gateway_HitPay.md](../docs/Payment_Gateway_HitPay.md)
  — migration, secrets, deploy, uji sandbox, cara tukar Fiuu

---

## ✅ Status & langkah seterusnya

**Siap (kod):** semua 4 layer + migration + docs.

**Pending (anda):**
1. Daftar HitPay sandbox → dapatkan `HITPAY_API_KEY` + `HITPAY_SALT`
2. Run `step94` (testing+prod) → `supabase secrets set …` → deploy 2 function
   (webhook **wajib** `--no-verify-jwt`)
3. Uji end-to-end sandbox

Lihat [../docs/Payment_Gateway_HitPay.md](../docs/Payment_Gateway_HitPay.md) untuk arahan penuh.
