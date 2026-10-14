// supabase/functions/payments-initiate-walkin/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// supabase/functions/_shared/payments/hitpay.ts
var BASE = () => (Deno.env.get("HITPAY_MODE") || "sandbox") === "live" ? "https://api.hit-pay.com/v1" : "https://api.sandbox.hit-pay.com/v1";
async function hmacHex(secret, message) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
function safeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
function normalizeStatus(s) {
  const v = (s || "").toLowerCase();
  if (v === "completed" || v === "succeeded" || v === "paid") return "completed";
  if (v === "failed" || v === "cancelled" || v === "canceled" || v === "expired") return "failed";
  if (v === "pending") return "pending";
  return "unknown";
}
var hitpay = {
  name: "hitpay",
  // Cipta payment request → pulang URL checkout untuk redirect pesakit.
  async createPayment(intent) {
    const apiKey = Deno.env.get("HITPAY_API_KEY");
    if (!apiKey) throw new Error("HITPAY_API_KEY tidak diset");
    const body = new URLSearchParams({
      amount: intent.amount,
      currency: intent.currency || "MYR",
      reference_number: intent.reference,
      redirect_url: intent.redirectUrl,
      webhook: intent.webhookUrl,
      ...intent.email ? { email: intent.email } : {},
      ...intent.name ? { name: intent.name } : {},
      ...intent.purpose ? { purpose: intent.purpose } : {}
    });
    const res = await fetch(`${BASE()}/payment-requests`, {
      method: "POST",
      headers: {
        "X-BUSINESS-API-KEY": apiKey,
        "Content-Type": "application/x-www-form-urlencoded",
        "X-Requested-With": "XMLHttpRequest"
      },
      body
    });
    const text = await res.text();
    let data = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      data = text;
    }
    if (!res.ok) throw new Error(`HitPay create ${res.status}: ${typeof data === "string" ? data : JSON.stringify(data)}`);
    if (!data?.url || !data?.id) throw new Error("HitPay: respons tiada url/id");
    return { gatewayRef: String(data.id), checkoutUrl: String(data.url), raw: data };
  },
  // Sahkan webhook HitPay (form-encoded + medan hmac).
  async verifyWebhook(req) {
    const salt = Deno.env.get("HITPAY_SALT");
    if (!salt) throw new Error("HITPAY_SALT tidak diset");
    const form = await req.formData();
    const fields = {};
    for (const [k, v] of form.entries()) fields[k] = String(v);
    const providedHmac = fields.hmac || "";
    delete fields.hmac;
    const message = Object.keys(fields).sort().map((k) => `${k}${fields[k]}`).join("");
    const expected = await hmacHex(salt, message);
    const ok = safeEqual(expected, providedHmac.toLowerCase());
    return {
      ok,
      reference: fields.reference_number || "",
      gatewayRef: fields.payment_request_id || fields.payment_id || "",
      status: normalizeStatus(fields.status || ""),
      amount: fields.amount,
      raw: fields
    };
  },
  // Channel sebenar (fpx/card/paynow_online/dll) — webhook form-encoded lama
  // (verifyWebhook di atas) TAK bawa medan ni, cuma status/amount/reference.
  // Panggilan BERASINGAN ke GET /payment-requests/{id} (respons JSON penuh,
  // ada array `payments[]`, setiap satu ada `payment_type`). Dipanggil SELEPAS
  // webhook disahkan — best-effort, kegagalan di sini TAK patut gagalkan
  // fulfillment bayaran (lihat pemanggil, payments-webhook/index.ts).
  async getPaymentChannel(gatewayRef) {
    const apiKey = Deno.env.get("HITPAY_API_KEY");
    if (!apiKey || !gatewayRef) return { channel: null, raw: null };
    const res = await fetch(`${BASE()}/payment-requests/${encodeURIComponent(gatewayRef)}`, {
      method: "GET",
      headers: { "X-BUSINESS-API-KEY": apiKey, "X-Requested-With": "XMLHttpRequest" }
    });
    if (!res.ok) return { channel: null, raw: { status: res.status } };
    const data = await res.json().catch(() => null);
    const payments = Array.isArray(data?.payments) ? data.payments : [];
    const chosen = payments.find((p) => String(p?.status || "").toLowerCase() === "succeeded") || payments[0];
    return { channel: chosen?.payment_type ? String(chosen.payment_type) : null, raw: data };
  },
  // Cipta sesi "lampir kad" (recurring-billing, save_payment_method=true) —
  // pesakit isi kad SEKALI di hosted page HitPay, tiada cycle/subscription
  // (kita caj ON-DEMAND kemudian ikut checkpoint, bukan HitPay punya jadual).
  // amount BOLEH jumlah SEBENAR (cth deposit ansuran, guna dari kob_retry_link.ts
  // bila HITPAY_INSTALLMENT_SAVE_CARD=true) — lampir kad berlaku SERENTAK dgn
  // bayaran sebenar, bukan sesi RM1 berasingan. Untuk sesi lampir-kad BERDIRI
  // SENDIRI (kob_autocharge.ts createKobCardAttachLink), amount='1.00' (had
  // minimum API HitPay bila tiada bayaran sebenar utk "tumpang").
  async createCardAuthorization(intent) {
    const apiKey = Deno.env.get("HITPAY_API_KEY");
    if (!apiKey) throw new Error("HITPAY_API_KEY tidak diset");
    const body = new URLSearchParams({
      name: intent.purpose || "Pengesahan Kad \u2014 Ansuran Automatik ISW",
      amount: intent.amount,
      currency: intent.currency || "MYR",
      reference: intent.reference,
      redirect_url: intent.redirectUrl,
      save_payment_method: "true",
      ...intent.customerEmail ? { customer_email: intent.customerEmail } : {},
      ...intent.customerName ? { customer_name: intent.customerName } : {}
    });
    for (const m of intent.paymentMethods?.length ? intent.paymentMethods : ["card"]) {
      body.append("payment_methods[]", m);
    }
    const res = await fetch(`${BASE()}/recurring-billing`, {
      method: "POST",
      headers: {
        "X-BUSINESS-API-KEY": apiKey,
        "Content-Type": "application/x-www-form-urlencoded",
        "X-Requested-With": "XMLHttpRequest"
      },
      body
    });
    const text = await res.text();
    let data = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      data = text;
    }
    if (!res.ok) throw new Error(`HitPay recurring-billing ${res.status}: ${typeof data === "string" ? data : JSON.stringify(data)}`);
    if (!data?.url || !data?.id) throw new Error("HitPay: respons recurring-billing tiada url/id");
    return { authRef: String(data.id), checkoutUrl: String(data.url), raw: data };
  },
  // Caj ON-DEMAND kad tersimpan (bukan cycle automatik HitPay) — respons
  // SEGERA (bukan redirect+webhook macam createPayment), jadi pemanggil
  // (cron event-reminders) boleh fulfill terus dari status respons ini.
  async chargeSavedCard(authRef, amount, currency) {
    const apiKey = Deno.env.get("HITPAY_API_KEY");
    if (!apiKey) throw new Error("HITPAY_API_KEY tidak diset");
    const body = new URLSearchParams({ amount, currency: currency || "MYR" });
    const res = await fetch(`${BASE()}/charge/recurring-billing/${encodeURIComponent(authRef)}`, {
      method: "POST",
      headers: {
        "X-BUSINESS-API-KEY": apiKey,
        "Content-Type": "application/x-www-form-urlencoded",
        "X-Requested-With": "XMLHttpRequest"
      },
      body
    });
    const text = await res.text();
    let data = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      data = text;
    }
    if (!res.ok) {
      return { ok: false, chargeRef: "", status: "failed", raw: data ?? text };
    }
    const status = normalizeStatus(data?.status || "");
    return { ok: status === "completed", chargeRef: String(data?.payment_id || ""), status, raw: data };
  },
  // Sahkan webhook JSON "recurring billing" (Hitpay-Signature = HMAC-SHA256
  // guna salt atas RAW body JSON) — bentuk BEZA drpd verifyWebhook() atas
  // (form-encoded + medan `hmac`, khusus payment-requests biasa).
  async verifyRecurringWebhook(req) {
    const salt = Deno.env.get("HITPAY_SALT");
    if (!salt) throw new Error("HITPAY_SALT tidak diset");
    const raw = await req.text();
    const providedSig = req.headers.get("Hitpay-Signature") || "";
    const expected = await hmacHex(salt, raw);
    const ok = safeEqual(expected, providedSig.toLowerCase());
    let data = {};
    try {
      data = raw ? JSON.parse(raw) : {};
    } catch {
      data = {};
    }
    const eventTypeHeader = req.headers.get("Hitpay-Event-Type") || "";
    const objectType = data?.object || data?.type || eventTypeHeader;
    let eventType = "unknown";
    if (String(objectType).includes("method_attached")) eventType = "method_attached";
    else if (String(objectType).includes("method_detached")) eventType = "method_detached";
    else if (String(objectType).includes("subscription_updated")) eventType = "subscription_updated";
    else if (String(objectType).includes("charge")) eventType = "charge_created";
    const authRef = String(data?.recurring_billing_id || data?.id || data?.data?.id || "");
    const reference = data?.reference || data?.data?.reference ? String(data.reference || data.data.reference) : void 0;
    const card = data?.payment_method?.card || data?.card || {};
    return {
      ok,
      eventType,
      authRef,
      reference,
      status: data?.status ? String(data.status) : void 0,
      cardLast4: card?.last4 ? String(card.last4) : void 0,
      cardBrand: card?.brand ? String(card.brand) : void 0,
      raw: data
    };
  }
};

// supabase/functions/_shared/payments/index.ts
var PROVIDERS = {
  hitpay
  // fiuu,
};
function activeProviderName() {
  return (Deno.env.get("PAYMENT_PROVIDER") || "hitpay").toLowerCase();
}
function getProvider(name) {
  const key = (name || activeProviderName()).toLowerCase();
  const p = PROVIDERS[key];
  if (!p) throw new Error(`Provider bayaran tidak dikenali: "${key}". Yang ada: ${Object.keys(PROVIDERS).join(", ")}`);
  return p;
}

// supabase/functions/payments-initiate-walkin/index.ts
var corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
var json = (b, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });
var money = (n) => (Math.round(n * 100) / 100).toFixed(2);
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "POST sahaja" }, 405);
  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const authHeader = req.headers.get("Authorization") || "";
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "Tidak dibenarkan (sila log masuk)" }, 401);
    const { data: profile } = await userClient.from("psy_profiles").select("role").eq("id", user.id).single();
    if (profile?.role !== "staff") return json({ error: "forbidden \u2014 staff sahaja" }, 403);
    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });
    const body = await req.json().catch(() => ({}));
    const items = Array.isArray(body.items) ? body.items : [];
    const buyerName = body.buyerName ? String(body.buyerName).trim() : null;
    const buyerPhone = body.buyerPhone ? String(body.buyerPhone).trim() : null;
    const noteInput = body.notes ? String(body.notes).trim() : null;
    const returnUrl = String(body.returnUrl || "");
    if (!items.length) return json({ error: "Tiada produk untuk dibayar" }, 400);
    if (!returnUrl) return json({ error: "returnUrl diperlukan" }, 400);
    const productIds = items.map((it) => it.productId).filter(Boolean);
    if (!productIds.length) return json({ error: "Produk tidak sah" }, 400);
    const { data: prods } = await admin.from("psy_products").select("id, product_id, name, inventory_item_id, psy_inventory_items(status, is_active)").in("id", productIds);
    const prodById = new Map((prods || []).map((p) => [p.id, p]));
    const lines = [];
    let total = 0;
    for (const it of items) {
      const prod = prodById.get(it.productId);
      if (!prod) return json({ error: `Produk tidak dijumpai: ${it.name || it.productId}` }, 400);
      if (!prod.inventory_item_id) return json({ error: `"${prod.name}" tidak boleh dijual (tiada pautan Inventori)` }, 400);
      const inv = prod.psy_inventory_items;
      if (!inv || inv.is_active === false || inv.status && inv.status !== "active") {
        return json({ error: `"${prod.name}" tidak lagi tersedia` }, 400);
      }
      const qty = Math.max(0, Number(it.qty) || 0);
      const price = Math.max(0, Number(it.price) || 0);
      if (!qty) return json({ error: `Kuantiti tidak sah utk "${prod.name}"` }, 400);
      total += price * qty;
      lines.push({ id: prod.id, product_id: prod.product_id, name: prod.name, price, qty, subtotal: price * qty });
    }
    if (!(total > 0)) return json({ error: "Jumlah bayaran tidak sah" }, 400);
    const receiptRef = "WALKIN-" + Date.now().toString(36).toUpperCase() + "-" + Math.floor(performance.now()).toString(36).toUpperCase();
    const provider = activeProviderName();
    const fullNotes = `Jualan Walk-in${buyerName ? " \u2014 " + buyerName : ""}${noteInput ? " \xB7 " + noteInput : ""}`;
    const { error: insErr } = await admin.from("psy_payments").insert({
      receipt_ref: receiptRef,
      patient_id: null,
      buyer_name: buyerName,
      buyer_phone: buyerPhone,
      items: lines,
      subtotal: total,
      total,
      payment_method: "gateway",
      status: "pending",
      paid_for_type: "product",
      gateway_provider: provider,
      gateway_status: "pending",
      recorded_by: user.id,
      notes: fullNotes,
      intent: {
        items: [{ type: "walkin_sale", items: lines, amount: total, buyerName, buyerPhone }],
        buyerName,
        buyerPhone,
        initiatedBy: "staff",
        recordedBy: user.id
      }
    });
    if (insErr) throw new Error("Gagal simpan bayaran pending: " + insErr.message);
    const webhookUrl = `${SUPABASE_URL}/functions/v1/payments-webhook`;
    const redirectUrl = `${returnUrl}${returnUrl.includes("?") ? "&" : "?"}ref=${encodeURIComponent(receiptRef)}`;
    const created = await getProvider(provider).createPayment({
      reference: receiptRef,
      amount: money(total),
      currency: "MYR",
      name: buyerName || void 0,
      purpose: `ISW Walk-in \xB7 ${items.length} item`,
      redirectUrl,
      webhookUrl
    });
    await admin.from("psy_payments").update({ gateway_ref: created.gatewayRef, checkout_url: created.checkoutUrl }).eq("receipt_ref", receiptRef);
    return json({ ok: true, checkoutUrl: created.checkoutUrl, receiptRef });
  } catch (err) {
    return json({ error: err.message || "Ralat tidak diketahui" }, 500);
  }
});
