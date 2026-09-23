// ============================================================
// Edge Function: payments-webhook-recurring
// LAPISAN 2 (Orkestra) — webhook KHUSUS event "Recurring Billing" HitPay
// (JSON + header Hitpay-Signature), BERBEZA drpd payments-webhook biasa
// (form-encoded + medan `hmac`, khusus payment-requests/checkout-link).
//
// Kenapa fungsi BERASINGAN (bukan cabang dlm payments-webhook sedia ada):
// bentuk payload + skema HMAC provider utk dua jenis webhook HitPay ni
// 100% berbeza (lihat verifyWebhook vs verifyRecurringWebhook di
// _shared/payments/hitpay.ts) — gabung dlm satu fungsi akan kelirukan
// content-type sniffing & risiko pepijat silang.
//
// Event yang dilayan:
//   - recurring_billing.method_attached — pesakit SIAP lampir kad (hosted
//     page async) → psy_kob_card_authorizations status='attached'. DUA senario
//     psy_payments berkaitan:
//       (a) placeholder kob_card_attach (RM1, sesi lampir-kad BERDIRI SENDIRI,
//           lihat kob_autocharge.ts) — cukup tanda 'completed'.
//       (b) DEPOSIT ANSURAN SEBENAR (pesakit pilih 'Kad' semasa deposit, lihat
//           kob_retry_link.ts createKobDepositLink saveCard=true) — perlu
//           fulfillment PENUH (fulfillKobDeposit: cipta checkpoint, aktifkan
//           pakej) sama macam payments-webhook, guard atomik fulfilled_at.
//   - recurring_billing.method_detached — kad dibuang/luput → status='detached'
//     (auto-caj seterusnya jatuh balik ke aliran pautan manual sedia ada).
//   - recurring_billing.subscription_updated (status cancelled/expired) —
//     sama layanan macam method_detached (auto-caj berhenti, fallback manual).
//
// Auto-caj SENDIRI (charge/recurring-billing) TIDAK lalu sini — respons
// SEGERA (bukan async redirect+webhook), fulfillment terus di
// event-reminders runInstallmentAutoChargeCheck() lepas respons chargeSavedCard().
//
// PUBLIC (verify-JWT OFF) — HitPay panggil tanpa JWT. Dilindungi HMAC
// (HITPAY_SALT, Hitpay-Signature) oleh adapter, bukan JWT.
//
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, PAYMENT_PROVIDER, HITPAY_SALT
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getProvider } from '../_shared/payments/index.ts'
import { fulfillKobDeposit } from '../_shared/kob_deposit_fulfill.ts'
import { sendPaymentReceiptWhatsApp } from '../_shared/receipt_pdf.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'POST sahaja' }, 405)

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  )

  try {
    const provider = getProvider()
    if (!provider.verifyRecurringWebhook) return json({ error: 'Provider tidak sokong recurring webhook' }, 400)

    const result = await provider.verifyRecurringWebhook(req)
    if (!result.ok) return json({ error: 'Tandatangan tidak sah' }, 401)
    if (!result.authRef) return json({ ok: true, note: 'tiada authRef' })

    // Cari rekod kad tersimpan ikut gateway_auth_ref (bukan reference — reference
    // cuma wujud kalau HitPay gema balik field tu; authRef sentiasa ada).
    const { data: authRows } = await admin.from('psy_kob_card_authorizations')
      .select('*').eq('gateway_auth_ref', result.authRef).limit(1)
    const authRow = authRows?.[0]
    if (!authRow) {
      console.warn('payments-webhook-recurring: authRef tak jumpa', result.authRef)
      return json({ ok: true, note: 'authRef tak jumpa' })
    }

    if (result.eventType === 'method_attached') {
      // Idempotent — webhook boleh cetus berkali.
      if (authRow.status !== 'attached') {
        await admin.from('psy_kob_card_authorizations').update({
          status: 'attached',
          card_last4: result.cardLast4 || authRow.card_last4,
          card_brand: result.cardBrand || authRow.card_brand,
          attached_at: new Date().toISOString(),
        }).eq('id', authRow.id)
      }

      // Cari baris psy_payments (placeholder kob_card_attach RM1, ATAU deposit
      // ansuran SEBENAR bila mode="lampir kad serentak dgn deposit" — lihat
      // kob_retry_link.ts createKobDepositLink saveCard=true). reference dari
      // webhook kalau ada, kalau tiada padan ikut kob_session_id + status pending
      // (ambil baris TERKINI, dua jenis tak wujud serentak utk sesi yg sama).
      const ref = result.reference
      let paymentRow: any = null
      if (ref) {
        const { data } = await admin.from('psy_payments').select('*').eq('receipt_ref', ref).limit(1)
        paymentRow = data?.[0]
      }
      if (!paymentRow) {
        const { data } = await admin.from('psy_payments').select('*')
          .eq('status', 'pending').eq('intent->>kob_session_id', authRow.kob_session_id)
          .order('created_at', { ascending: false }).limit(5)
        paymentRow = (data || []).find((r: any) => ['kob_card_attach', 'kob_deposit'].includes(r.items?.[0]?.type))
      }

      if (paymentRow && paymentRow.status !== 'completed') {
        const itemType = paymentRow.items?.[0]?.type
        if (itemType === 'kob_deposit') {
          // Deposit SEBENAR (bukan placeholder RM1) — perlu fulfillment PENUH
          // (cipta checkpoint ansuran, aktifkan pakej), sama logik dgn
          // payments-webhook. Tuntut baris SECARA ATOM dulu (webhook boleh
          // cetus berkali) — cegah fulfillment berganda, sama pattern
          // payments-webhook (lihat notanya di situ, punca bug pakej x4 baris 7 Ogos).
          const { data: claimed } = await admin.from('psy_payments')
            .update({ fulfilled_at: new Date().toISOString(), status: 'completed', paid_at: new Date().toISOString() })
            .eq('id', paymentRow.id).is('fulfilled_at', null).select('id')
          if (claimed?.length) {
            try {
              await fulfillKobDeposit(admin, paymentRow.items[0], authRow.patient_id, paymentRow.receipt_ref)
              try { await sendPaymentReceiptWhatsApp(admin, paymentRow) }
              catch (waErr) { console.warn('payments-webhook-recurring: resit WhatsApp gagal —', (waErr as Error).message) }
            } catch (fulfillErr) {
              // Lepaskan claim + rollback status supaya webhook retry akan datang boleh cuba semula.
              await admin.from('psy_payments').update({ fulfilled_at: null, status: 'pending' }).eq('id', paymentRow.id).catch(() => {})
              throw fulfillErr
            }
          }
        } else {
          // kob_card_attach — placeholder RM1 berdiri sendiri, cukup tanda completed.
          await admin.from('psy_payments').update({ status: 'completed', paid_at: new Date().toISOString() }).eq('id', paymentRow.id)
        }
      }

      // Notifikasi staff (coach + admin/manager) — kad berjaya dilampir.
      try {
        const { data: pt } = await admin.from('psy_patients').select('coach_id, full_name').eq('id', authRow.patient_id).limit(1)
        const p = pt?.[0]
        const targets = new Set<string>()
        if (p?.coach_id) targets.add(p.coach_id)
        const { data: staff } = await admin.from('psy_profiles').select('id').eq('role', 'staff').in('staff_role', ['admin', 'manager'])
        ;(staff || []).forEach((s: any) => targets.add(s.id))
        for (const uid of targets) {
          await admin.from('psy_notifications').insert({
            user_id: uid, type: 'payment', title: 'Kad Ansuran Dilampirkan ✅',
            body: `${p?.full_name || 'Pesakit'} telah berjaya lampir kad — ansuran seterusnya akan di-auto-caj.`,
            link: `../staff/patient-hub.html?id=${authRow.patient_id}`,
          }).catch(() => {})
        }
      } catch (_) { /* notifikasi gagal tidak halang webhook */ }

      return json({ ok: true })
    }

    if (result.eventType === 'method_detached' || (result.eventType === 'subscription_updated' && ['cancelled', 'canceled', 'expired'].includes(String(result.status || '').toLowerCase()))) {
      if (authRow.status !== 'detached') {
        await admin.from('psy_kob_card_authorizations').update({
          status: 'detached', detached_at: new Date().toISOString(),
        }).eq('id', authRow.id)
      }
      return json({ ok: true })
    }

    return json({ ok: true, note: `event ${result.eventType} diabaikan` })
  } catch (err) {
    console.error('payments-webhook-recurring error:', (err as Error).message)
    return json({ error: (err as Error).message }, 500)
  }
})
