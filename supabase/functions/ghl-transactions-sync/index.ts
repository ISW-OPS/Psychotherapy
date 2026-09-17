// ============================================================
// Edge Function: ghl-transactions-sync
// PULL SEMUA transaksi GHL (`/payments/transactions`, ledger bersepadu
// rasmi — tangkap Stripe+Manual+Invoice SEKALI GUS) ke jadual RAW
// `psy_ghl_transactions` — Laluan A "Central Payment Module" (guna
// GHL_ISW_TOKEN sahaja, TIADA akses Stripe secret diperlukan).
//
// BERBEZA dari ghl-pull-sync (yang isi psy_payments untuk gate KOB
// sahaja): fungsi ni tarik SEMUA transaksi (bukan ditapis KOB), untuk
// tujuan reconciliation kewangan/accounting masa depan. Jadual
// BERASINGAN sengaja — elak double-count dengan psy_payments (lihat
// nota di database/schema/06_payments.sql).
//
// PENEMUAN (17 Sept 2026, probe_location_transactions dalam
// ghl-pull-sync): `/payments/transactions?altId=<loc>&altType=location`
// (TANPA contactId) pulangkan transaksi merentas SEMUA contact sekali
// gus — pagination guna `limit`+`offset` biasa (BUKAN startAfterId/
// startAfter macam /contacts/ — dah cuba, diabaikan API). Response ada
// `totalCount` (akaun ni ~190 transaksi sahaja — SANGAT kecil, tiada
// risiko timeout/rate-limit macam scan 7,925 contact di ghl-pull-sync,
// jadi fungsi ni buat FULL SYNC setiap run, tiada cursor/checkpoint
// diperlukan).
//
// Untuk transaksi paymentProviderType==='stripe', GHL embed OBJEK
// STRIPE PENUH (payment_intent+charge sebenar) dalam `chargeSnapshot` —
// kita ekstrak payment_method_type + receipt_url dari situ (percuma,
// tiada panggilan Stripe API diperlukan).
//
// Secrets: GHL_ISW_TOKEN, GHL_ISW_LOCATION_ID, GHL_PULL_CRON_SECRET
// (kongsi dgn ghl-pull-sync — sama kategori "GHL pull cron").
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { ghl } from '../_shared/ghl.ts'

const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

const PAGE_LIMIT = 100
const MAX_PAGES_PER_RUN = 20   // ~2000 transaksi/run — jauh lebih dari cukup (akaun ni ~190 sahaja)

// issueDate invois TIADA dalam objek transaksi itu sendiri (hanya
// invoiceNumber via entitySourceMeta) — perlu panggilan /invoices/
// berasingan (ikut contactId, sebab GHL tak sokong fetch 1 invois ikut
// ID terus tanpa contactId). Cache PER-RUN ikut contactId elak panggilan
// berulang untuk contact dgn >1 invois. Disahkan 17 Sept 2026: issueDate
// invois BOLEH beza dari createdAt transaksi (invois diisukan awal,
// dibayar/ditanda paid lambat — cth invois "EOB 260915" issueDate 15
// Sept tapi transaksi/bayaran createdAt 17 Sept).
const invoiceCache = new Map<string, any[]>()
async function getInvoicesForContact(locationId: string, contactId: string): Promise<any[]> {
  if (invoiceCache.has(contactId)) return invoiceCache.get(contactId)!
  const data = await ghl(`/invoices/?altId=${locationId}&altType=location&contactId=${contactId}&limit=50&offset=0`, { method: 'GET' })
    .catch(() => ({ invoices: [] }))
  const invoices = data?.invoices || []
  invoiceCache.set(contactId, invoices)
  return invoices
}

// Derive payment_method_type + receipt_url dari chargeSnapshot — bentuk
// BERBEZA ikut paymentProviderType:
//   'stripe' → chargeSnapshot ialah objek payment_intent Stripe PENUH,
//              charge sebenar di chargeSnapshot.charges.data[0]
//   'manual' → chargeSnapshot ringkas { mode: 'bank_transfer'|'cheque'|..., ... }
function deriveChargeFields(t: any): { paymentMethodType: string | null; receiptUrl: string | null; chargeId: string | null } {
  const snap = t.chargeSnapshot
  if (t.paymentProviderType === 'stripe' && snap) {
    const charge = snap?.charges?.data?.[0] || null
    return {
      paymentMethodType: charge?.payment_method_details?.type || null,
      receiptUrl: charge?.receipt_url || null,
      chargeId: t.chargeId || snap?.id || null,
    }
  }
  return {
    paymentMethodType: snap?.mode || null,
    receiptUrl: null,
    chargeId: null,
  }
}

// Spec penapisan lengkap (keputusan user 17 Sept 2026) — buang rekod
// yang padan MANA-MANA syarat ni (bukan duit sebenar/pesakit sebenar):
//   status           bukan "succeeded" tepat (bukan set PAID_STATUSES
//                    longgar — akaun ni cuma pernah pulang succeeded/
//                    failed/pending, jadi padan tepat cukup & jelas)
//   liveMode         bukan true (test-mode Stripe — 48/123 rekod awal!)
//   contactName      mengandungi "test" (case-insensitive)
//   contactEmail     mengandungi "test" (case-insensitive)
//   entitySourceName mengandungi "test" (case-insensitive)
// (NOTA 17 Sept 2026: exact-match "Najihah Megat Salim" DIBUANG —
// tu cuma utk 1 rekod test lama sekali-guna, BUKAN peraturan kekal.
// Kalau ada pesakit sebenar nama tu akan datang, jangan sekat dia.)
function isTestOrInvalid(t: any): boolean {
  if (String(t.status || '').toLowerCase() !== 'succeeded') return true
  if (t.liveMode !== true) return true
  if (/test/i.test(String(t.contactName || ''))) return true
  if (/test/i.test(String(t.contactEmail || ''))) return true
  if (/test/i.test(String(t.entitySourceName || ''))) return true
  return false
}

async function upsertTransaction(svc: any, locationId: string, t: any): Promise<{ inserted: boolean; skipped?: boolean; error?: string }> {
  if (isTestOrInvalid(t)) {
    return { inserted: false, skipped: true }
  }

  const { paymentMethodType, receiptUrl, chargeId } = deriveChargeFields(t)

  // Padanan pesakit — BEST-EFFORT ikut email sahaja buat masa ni (objek
  // transaksi GHL tak bawa phone terus, hanya contactEmail/contactName).
  // NULL kalau tak jumpa — tak block sync, sekadar konteks tambahan.
  let patientId: string | null = null
  if (t.contactEmail) {
    const { data: pt } = await svc.from('psy_patients')
      .select('id').ilike('email', t.contactEmail).limit(1).maybeSingle()
    patientId = pt?.id || null
  }

  // invoice_number — terus dari entitySourceMeta (tiada panggilan tambahan).
  // issue_date — PERLU panggilan /invoices/ (entityType='invoice' sahaja).
  let invoiceNumber: string | null = null
  let issueDate: string | null = null
  if (t.entityType === 'invoice' && t.entitySourceMeta) {
    const { invoiceNumber: num, invoiceNumberPrefix: prefix } = t.entitySourceMeta
    if (num) invoiceNumber = `${prefix || ''}${num}`
    if (t.contactId) {
      const invoices = await getInvoicesForContact(locationId, t.contactId)
      const inv = invoices.find((i: any) => i._id === t.entityId)
      if (inv?.issueDate) issueDate = inv.issueDate
    }
  }

  const row = {
    ghl_transaction_id: t._id || t.id,
    contact_id: t.contactId || null,
    contact_name: t.contactName || null,
    contact_email: t.contactEmail || null,
    patient_id: patientId,
    amount: Number(t.amount) || 0,
    amount_refunded: Number(t.amountRefunded) || 0,
    currency: String(t.currency || 'MYR').toUpperCase(),
    status: t.status || null,
    payment_provider_type: t.paymentProviderType || null,
    entity_type: t.entityType || null,
    entity_source_type: t.entitySourceType || null,
    entity_source_name: t.entitySourceName || null,
    entity_id: t.entityId || null,
    charge_id: chargeId,
    payment_method_type: paymentMethodType,
    receipt_url: receiptUrl,
    invoice_number: invoiceNumber,
    issue_date: issueDate,
    live_mode: t.liveMode ?? null,
    ghl_created_at: t.createdAt || null,
    ghl_updated_at: t.updatedAt || null,
    fulfilled_at: t.fulfilledAt || null,
    raw: t,
    synced_at: new Date().toISOString(),
  }

  if (!row.ghl_transaction_id) return { inserted: false, error: 'tiada _id' }

  const { error } = await svc.from('psy_ghl_transactions')
    .upsert(row, { onConflict: 'ghl_transaction_id' })
  if (error) return { inserted: false, error: error.message }
  return { inserted: true }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    if (req.headers.get('x-cron-secret') !== Deno.env.get('GHL_PULL_CRON_SECRET')) {
      return json({ error: 'forbidden' }, 403)
    }

    const locationId = Deno.env.get('GHL_ISW_LOCATION_ID')!
    const svc = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

    let offset = 0
    let totalCount = 0
    let scanned = 0
    let synced = 0
    let skippedNotPaid = 0
    const errors: string[] = []

    for (let page = 0; page < MAX_PAGES_PER_RUN; page++) {
      const data = await ghl(
        `/payments/transactions?altId=${locationId}&altType=location&limit=${PAGE_LIMIT}&offset=${offset}`,
        { method: 'GET' },
      ).catch((e: Error) => { errors.push(`page @offset=${offset}: ${e.message}`); return null })
      if (!data) break

      totalCount = Number(data.totalCount) || totalCount
      const txs = data.data || []
      scanned += txs.length

      for (const t of txs) {
        const r = await upsertTransaction(svc, locationId, t)
        if (r.inserted) synced++
        else if (r.skipped) skippedNotPaid++
        else if (r.error) errors.push(`${t._id || '?'}: ${r.error}`)
      }

      offset += txs.length
      if (txs.length < PAGE_LIMIT || offset >= totalCount) break
    }

    const summary = { totalCount, scanned, synced, skippedNotPaid, errorCount: errors.length, errors: errors.slice(0, 20) }

    try {
      await svc.from('psy_audit_log').insert({
        actor_name: 'GHL', actor_role: 'system', action: 'ghl_transactions_sync.run', target: 'system', meta: summary,
      })
    } catch (_) { /* audit log gagal tak patut gagalkan run */ }

    return json({ success: true, ...summary })
  } catch (err) {
    console.error('ghl-transactions-sync error:', err)
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
