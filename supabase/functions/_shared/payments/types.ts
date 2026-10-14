// ============================================================
// _shared/payments/types.ts
// Kontrak NEUTRAL untuk semua gateway bayaran (HitPay, Fiuu, dll).
//
// Kod ISW (initiate + webhook) hanya kenal interface ini.
// Ia TAK pernah tahu apa gateway sebenar di sebalik tabir.
// Nak tukar gateway = tulis satu adapter baru yang patuh kontrak ni.
// ============================================================

// Niat bayaran — apa yang kita mahu gateway buat.
export interface PaymentIntent {
  reference: string      // rujukan KITA (receipt_ref) — gateway pulang balik nilai ini
  amount: string         // amaun MYR sebagai string, cth "150.00"
  currency: string       // "MYR"
  email?: string
  name?: string
  purpose?: string       // penerangan ringkas (tunjuk di halaman gateway)
  redirectUrl: string    // pesakit dibawa ke sini SELEPAS bayar
  webhookUrl: string     // gateway PANGGIL sini untuk sahkan bayaran (server-ke-server)
}

// Hasil selepas gateway cipta bayaran.
export interface CreatedPayment {
  gatewayRef: string     // id bayaran di pihak gateway (untuk padan webhook nanti)
  checkoutUrl: string    // redirect pesakit ke URL ini
  raw: unknown           // respons mentah (untuk log/debug)
}

// Hasil selepas kita sahkan webhook dari gateway.
export type PaymentStatus = 'completed' | 'failed' | 'pending' | 'unknown';
export interface WebhookResult {
  ok: boolean            // tandatangan (HMAC) sah?
  reference: string      // rujukan KITA (receipt_ref)
  gatewayRef: string     // id bayaran di pihak gateway
  status: PaymentStatus  // status ternormal
  amount?: string        // amaun yang gateway sahkan (untuk semak silang)
  raw: Record<string, string>
}

// Setiap adapter gateway MESTI eksport dua fungsi ini.
// createCardAuthorization/chargeSavedCard/verifyRecurringWebhook OPSYENAL —
// hanya provider yang sokong caj kad tersimpan (recurring billing on-demand,
// cth HitPay) perlu implement. Lihat _shared/kob_autocharge.ts (pemanggil).
export interface PaymentProvider {
  name: string;
  createPayment(intent: PaymentIntent): Promise<CreatedPayment>;
  verifyWebhook(req: Request): Promise<WebhookResult>;
  createCardAuthorization?(intent: CardAuthIntent): Promise<CardAuthResult>;
  chargeSavedCard?(authRef: string, amount: string, currency: string): Promise<ChargeResult>;
  verifyRecurringWebhook?(req: Request): Promise<RecurringWebhookResult>;
  // Channel SEBENAR pesakit guna (fpx/card/paynow_online/dll) — webhook form-encoded
  // lama (verifyWebhook) TAK bawa medan ni, kena panggil API berasingan selepas
  // webhook sah. Opsyenal — provider yang tak sokong/tak perlu boleh tinggalkan.
  getPaymentChannel?(gatewayRef: string): Promise<{ channel: string | null; raw: unknown }>;
}

// ── Kad Tersimpan (Recurring Billing on-demand) — HitPay sahaja buat masa ini ──
// Aliran: 1x "lampir kad" (hosted page, cth deposit RM1 pengesahan) → simpan
// authRef → kemudian caj ON-DEMAND amaun BERBEZA setiap checkpoint ansuran
// (bukan cycle/subscription tetap HitPay — checkpoint ISW amaunnya custom).
export interface CardAuthIntent {
  reference: string      // rujukan KITA (receipt_ref psy_payments)
  amount: string         // amaun sesi (MYR string) — BOLEH jumlah SEBENAR (cth deposit
                          // ansuran) supaya lampir-kad berlaku SEKALI GUS dgn bayaran
                          // sebenar (bukan RM1 berasingan), ATAU '1.00' utk sesi
                          // lampir-kad berdiri sendiri (createKobCardAttachLink)
  purpose?: string       // nama/penerangan dipapar di hosted page HitPay
  customerEmail?: string
  customerName?: string
  currency: string
  redirectUrl: string
  paymentMethods?: string[]   // default ['card'] di adapter jika tiada
}
export interface CardAuthResult {
  authRef: string        // id 'recurring-billing' HitPay — simpan, guna semula utk caj
  checkoutUrl: string    // redirect pesakit ke sini utk isi kad SEKALI sahaja
  raw: unknown
}

// Hasil caj on-demand terus (respons SEGERA — bukan tunggu webhook, tak macam
// createPayment/checkout link yang perlu redirect+webhook async).
export interface ChargeResult {
  ok: boolean
  chargeRef: string      // payment_id HitPay bagi caj ni
  status: PaymentStatus
  raw: unknown
}

// Webhook JSON (Hitpay-Signature header) — BEZA bentuk drpd WebhookResult
// (form-encoded + medan hmac) utk payment-requests biasa. Guna event ini
// untuk tahu bila pesakit SIAP lampir kad (hosted page async, redirect).
export type RecurringEventType = 'method_attached' | 'method_detached' | 'subscription_updated' | 'charge_created' | 'unknown'
export interface RecurringWebhookResult {
  ok: boolean
  eventType: RecurringEventType
  authRef: string         // recurring_billing id
  reference?: string      // rujukan KITA (receipt_ref) — jika HitPay gema balik `reference`
  status?: string          // status mentah (active/cancelled/paused/expired dll)
  cardLast4?: string
  cardBrand?: string
  raw: unknown
}
