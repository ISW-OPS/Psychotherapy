// ============================================================
// _shared/payments/index.ts
// Pemilih provider — "papan suis" gateway.
//
// ⭐ INI SAHAJA yang berubah bila tambah gateway baru:
//    1. import adapter baru (cth: import { fiuu } from './fiuu.ts')
//    2. daftar dalam PROVIDERS
//    3. tukar env PAYMENT_PROVIDER=fiuu
//    Kod initiate + webhook + client TIDAK sentuh.
// ============================================================
import type { PaymentProvider } from './types.ts'
import { hitpay } from './hitpay.ts'
// import { fiuu } from './fiuu.ts'   // ← tambah di sini bila migrasi ke Fiuu

const PROVIDERS: Record<string, PaymentProvider> = {
  hitpay,
  // fiuu,
}

// Nama provider aktif (default hitpay). Set env PAYMENT_PROVIDER untuk tukar.
export function activeProviderName(): string {
  return (Deno.env.get('PAYMENT_PROVIDER') || 'hitpay').toLowerCase()
}

export function getProvider(name?: string): PaymentProvider {
  const key = (name || activeProviderName()).toLowerCase()
  const p = PROVIDERS[key]
  if (!p) throw new Error(`Provider bayaran tidak dikenali: "${key}". Yang ada: ${Object.keys(PROVIDERS).join(', ')}`)
  return p
}
