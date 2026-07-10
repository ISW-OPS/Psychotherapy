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
export interface PaymentProvider {
  name: string;
  createPayment(intent: PaymentIntent): Promise<CreatedPayment>;
  verifyWebhook(req: Request): Promise<WebhookResult>;
}
