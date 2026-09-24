// ../../../../../../../../ISW system/supabase/functions/payments-initiate/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ../../../../../../../../ISW system/supabase/functions/_shared/payments/hitpay.ts
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
  }
};

// ../../../../../../../../ISW system/supabase/functions/_shared/payments/index.ts
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

// ../../../../../../../../ISW system/supabase/functions/payments-initiate/index.ts
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
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const authHeader = req.headers.get("Authorization") || "";
    const authClient = createClient(SUPABASE_URL, SERVICE_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false }
    });
    const { data: userData } = await authClient.auth.getUser();
    const user = userData?.user;
    if (!user) return json({ error: "Tidak dibenarkan (sila log masuk)" }, 401);
    const body = await req.json().catch(() => ({}));
    const items = Array.isArray(body.items) ? body.items : [];
    const patientId = body.patientId || null;
    const promoCode = body.promoCode ? String(body.promoCode).trim() : null;
    const method = "gateway";
    const returnUrl = String(body.returnUrl || "");
    if (!items.length) return json({ error: "Tiada item untuk dibayar" }, 400);
    if (!returnUrl) return json({ error: "returnUrl diperlukan" }, 400);
    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });
    const blockedProduct = await findUnavailableShopProduct(admin, items);
    if (blockedProduct) return json({ error: `"${blockedProduct}" tidak lagi tersedia. Sila buat semula order anda.` }, 400);
    let total = 0;
    for (const it of items) {
      total += await verifiedAmount(admin, it, patientId);
    }
    if (!(total > 0)) return json({ error: "Jumlah bayaran tidak sah" }, 400);
    let voucherId = null;
    let voucherDiscount = 0;
    if (patientId) {
      const { data: voucher } = await admin.from("psy_vouchers").select("id, amount").eq("patient_id", patientId).eq("status", "active").or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`).order("created_at", { ascending: true }).limit(1).maybeSingle();
      if (voucher) {
        voucherId = voucher.id;
        voucherDiscount = Math.min(Number(voucher.amount) || 0, total);
        total = Math.max(1, total - voucherDiscount);
      }
    }
    let promoId = null;
    let promoDiscount = 0;
    if (promoCode && patientId) {
      const { data: promo } = await admin.from("psy_promo_codes").select("id, discount_type, discount_value, min_subtotal, max_uses, used_count, max_uses_per_patient, valid_from, valid_until, is_active, applies_to, applies_to_values, stackable, new_customer_only").eq("code", promoCode.toUpperCase()).maybeSingle();
      if (promo && promo.is_active) {
        const today = (/* @__PURE__ */ new Date()).toISOString().slice(0, 10);
        const dateOk = (!promo.valid_from || promo.valid_from <= today) && (!promo.valid_until || promo.valid_until >= today);
        const usesOk = promo.max_uses == null || promo.used_count < promo.max_uses;
        const minOk = total >= (Number(promo.min_subtotal) || 0);
        const stackOk = promo.stackable !== false || voucherDiscount <= 0;
        let perPatientOk = true;
        if (dateOk && usesOk && minOk && stackOk && promo.max_uses_per_patient != null) {
          const { count } = await admin.from("psy_promo_redemptions").select("id", { count: "exact", head: true }).eq("promo_id", promo.id).eq("patient_id", patientId);
          perPatientOk = (count || 0) < promo.max_uses_per_patient;
        }
        let newCustOk = true;
        if (dateOk && usesOk && minOk && stackOk && perPatientOk && promo.new_customer_only) {
          const { count } = await admin.from("psy_payments").select("id", { count: "exact", head: true }).eq("patient_id", patientId).eq("status", "completed");
          newCustOk = (count || 0) === 0;
        }
        let scopeOk = true;
        if (dateOk && usesOk && minOk && stackOk && perPatientOk && newCustOk && promo.applies_to !== "all") {
          scopeOk = await cartMatchesPromoScope(admin, items, promo.applies_to, promo.applies_to_values || []);
        }
        if (dateOk && usesOk && minOk && stackOk && perPatientOk && newCustOk && scopeOk) {
          promoId = promo.id;
          promoDiscount = promo.discount_type === "percent" ? total * (Number(promo.discount_value) / 100) : Number(promo.discount_value);
          promoDiscount = Math.min(promoDiscount, total);
          total = Math.max(1, total - promoDiscount);
        }
      }
    }
    const receiptRef = "RCP-" + Date.now().toString(36).toUpperCase() + "-" + Math.floor(performance.now()).toString(36).toUpperCase();
    const provider = activeProviderName();
    const kobSessionIdItem = items.find((i) => i.kobSessionId);
    if (kobSessionIdItem) {
      await admin.from("psy_payments").update({ status: "failed", gateway_status: "superseded", notes: "Digantikan oleh percubaan bayaran baharu" }).eq("patient_id", patientId).eq("status", "pending").eq("intent->>kob_session_id", kobSessionIdItem.kobSessionId);
    }
    const { error: insErr } = await admin.from("psy_payments").insert({
      receipt_ref: receiptRef,
      patient_id: patientId,
      user_id: user.id,
      items: items.map((i) => ({ type: i.type, title: i.title, amount: i.amount, reference_id: i.id || i.packageId })),
      subtotal: total,
      total,
      discount: voucherDiscount + promoDiscount,
      payment_method: method,
      status: "pending",
      gateway_provider: provider,
      gateway_status: "pending",
      intent: {
        items,
        patientId,
        userId: user.id,
        method,
        voucherId,
        voucherDiscount,
        promoCodeId: promoId,
        promoCode: promoId && promoCode ? promoCode.toUpperCase() : null,
        promoDiscount,
        ...kobSessionIdItem ? { kob_session_id: kobSessionIdItem.kobSessionId } : {}
      }
    });
    if (insErr) throw new Error("Gagal simpan bayaran pending: " + insErr.message);
    const webhookUrl = `${SUPABASE_URL}/functions/v1/payments-webhook`;
    const redirectUrl = `${returnUrl}${returnUrl.includes("?") ? "&" : "?"}ref=${encodeURIComponent(receiptRef)}`;
    let billEmail = user.email || void 0;
    let billName = user.user_metadata?.full_name || void 0;
    if (patientId) {
      const { data: pt } = await admin.from("psy_patients").select("email, full_name").eq("id", patientId).maybeSingle();
      if (pt?.email) billEmail = pt.email;
      if (pt?.full_name) billName = pt.full_name;
    }
    const created = await getProvider(provider).createPayment({
      reference: receiptRef,
      amount: money(total),
      currency: "MYR",
      email: billEmail,
      name: billName,
      purpose: `ISW \xB7 ${items.length} item`,
      redirectUrl,
      webhookUrl
    });
    await admin.from("psy_payments").update({ gateway_ref: created.gatewayRef, checkout_url: created.checkoutUrl }).eq("receipt_ref", receiptRef);
    return json({ ok: true, checkoutUrl: created.checkoutUrl, receiptRef, voucherDiscount, promoDiscount });
  } catch (err) {
    return json({ error: err.message || "Ralat tidak diketahui" }, 500);
  }
});
var isUuid = (s) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
async function lookupPackage(admin, key) {
  let q = admin.from("psy_packages").select("price, is_active");
  q = isUuid(key) ? q.or(`id.eq.${key},package_id.eq.${key}`) : q.eq("package_id", key);
  const { data } = await q.limit(1);
  return data?.[0];
}
var invInactive = (inv) => !!inv && (inv.status || (inv.is_active === false ? "inactive" : "active")) !== "active";
async function findUnavailableShopProduct(admin, items) {
  const lines = items.filter((it) => it.type === "shop_order" && Array.isArray(it.items)).flatMap((it) => it.items);
  const ids = lines.map((p) => p.id).filter(Boolean);
  if (!ids.length) return null;
  const qtyById = /* @__PURE__ */ new Map();
  for (const l of lines) qtyById.set(l.id, (qtyById.get(l.id) || 0) + Math.max(1, parseInt(l.qty) || 1));
  const [{ data: prods }, { data: inv }] = await Promise.all([
    admin.from("psy_products").select("product_id, name, inventory_item_id").in("product_id", ids),
    admin.from("psy_inventory_items").select("*")
  ]);
  const byId = /* @__PURE__ */ new Map();
  for (const i of inv || []) byId.set(i.id, i);
  for (const p of prods || []) {
    const linked = p.inventory_item_id && byId.get(p.inventory_item_id) || null;
    if (!linked || invInactive(linked)) return p.name || p.product_id;
    if (Number(linked.qty_in_stock ?? 0) < (qtyById.get(p.product_id) || 1)) return p.name || p.product_id;
  }
  return null;
}
async function cartMatchesPromoScope(admin, items, appliesTo, values) {
  if (!values.length) return false;
  if (appliesTo === "package") {
    return items.some((i) => {
      if (!["package", "package_existing", "kob_package"].includes(i.type)) return false;
      const key = i.packageId || i.raw?.package_id;
      return key && values.includes(String(key));
    });
  }
  if (appliesTo === "product") {
    return items.some((i) => i.type === "shop_order" && Array.isArray(i.items) &&
      i.items.some((line) => values.includes(String(line.id))));
  }
  if (appliesTo === "category") {
    const productIds = items
      .filter((i) => i.type === "shop_order" && Array.isArray(i.items))
      .flatMap((i) => i.items.map((line) => line.id)).filter(Boolean);
    if (!productIds.length) return false;
    const { data } = await admin.from("psy_products").select("product_id, category").in("product_id", productIds);
    return (data || []).some((p) => p.category && values.includes(p.category));
  }
  return false;
}

async function verifiedAmount(admin, it, patientId) {
  const clientAmt = Number(it.amount) || 0;
  if (it.type === "kob_installment_topup") {
    if (!it.kobSessionId || !patientId) return 0;
    const { data: rows } = await admin.from("psy_kob_sessions").select("patient_id, package_payment_mode, package_payment_status").eq("id", it.kobSessionId).limit(1);
    const kob = rows?.[0];
    if (!kob || kob.patient_id !== patientId) return 0;
    if (kob.package_payment_mode !== "installment" || kob.package_payment_status !== "partial") return 0;
    const { data: paidRows } = await admin.from("psy_payments").select("total").eq("status", "completed").eq("intent->>kob_session_id", it.kobSessionId);
    const totalPaid = (paidRows || []).reduce((s, p) => s + Number(p.total || 0), 0);
    const { data: cps } = await admin.from("psy_kob_installment_checkpoints").select("target_cumulative").eq("kob_session_id", it.kobSessionId).order("seq", { ascending: true });
    const nextCp = (cps || []).find((c) => Number(c.target_cumulative) > totalPaid + 5e-3);
    const trusted = nextCp ? Math.max(0, Number(nextCp.target_cumulative) - totalPaid) : 0;
    it.amount = trusted;
    return trusted;
  }
  if (it.type === "kob_package") {
    const key = it.packageId || it.raw?.package_id;
    if (!key || !it.kobSessionId) return 0;
    const { data: kobRows } = await admin.from("psy_kob_sessions").select("patient_id, package_payment_status, status").eq("id", it.kobSessionId).limit(1);
    const kob = kobRows?.[0];
    if (!kob || kob.patient_id !== patientId) return 0;
    if (kob.package_payment_status !== "pending" || kob.status === "completed") return 0;
    let pkgQ = admin.from("psy_packages").select("price, today_price, is_active");
    pkgQ = isUuid(String(key)) ? pkgQ.or(`id.eq.${key},package_id.eq.${key}`) : pkgQ.eq("package_id", key);
    const { data: pkgRows } = await pkgQ.limit(1);
    const pkg = pkgRows?.[0];
    if (!pkg || pkg.is_active === false) return 0;
    const price = Number(pkg.today_price ?? pkg.price);
    if (!(price > 0)) return 0;
    it.amount = price;
    return price;
  }
  if (it.type === "package") {
    const key = it.packageId || it.raw?.package_id;
    if (key) {
      const pkg = await lookupPackage(admin, String(key));
      if (pkg && pkg.is_active !== false && Number.isFinite(Number(pkg.price))) {
        it.amount = Number(pkg.price);
        return Number(pkg.price);
      }
    }
    return clientAmt;
  }
  if (it.type === "package_existing") {
    const key = it.raw?.package_id;
    if (key) {
      const pkg = await lookupPackage(admin, String(key));
      if (pkg && pkg.is_active !== false && Number.isFinite(Number(pkg.price))) return Number(pkg.price);
    }
    return clientAmt;
  }
  if (it.type === "shop_order" && Array.isArray(it.items)) {
    const ids = it.items.map((p) => p.id).filter(Boolean);
    if (ids.length) {
      const { data } = await admin.from("psy_products").select("product_id, price, promo_price, promo_until, is_active").in("product_id", ids);
      const map = Object.fromEntries((data || []).map((p) => [p.product_id, p]));
      const today = (/* @__PURE__ */ new Date()).toISOString().slice(0, 10);
      let sub = 0;
      for (const line of it.items) {
        const p = map[line.id];
        if (!p || p.is_active === false) return clientAmt;
        const qty = Math.max(1, parseInt(line.qty) || 1);
        const orig = Number(p.price) || 0;
        const promo = Number(p.promo_price || 0);
        const onPromo = promo > 0 && promo < orig && (!p.promo_until || p.promo_until >= today);
        sub += (onPromo ? promo : orig) * qty;
      }
      const deliveryFee = Number(it.deliveryFee) || (it.deliveryMethod === "pos" ? 8 : 0);
      return sub + deliveryFee;
    }
    return clientAmt;
  }
  return clientAmt;
}
