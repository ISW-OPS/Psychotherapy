// supabase/functions/payments-kob-initiate/index.ts
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

// supabase/functions/_shared/kob_topup.ts
var money = (n) => (Math.round(n * 100) / 100).toFixed(2);
async function createKobInstallmentTopupLink(admin, kobSessionId, returnUrl, saveCard = false) {
  const { data: kobRows } = await admin.from("psy_kob_sessions").select("id, patient_id, recommended_package_name, package_payment_mode, package_payment_status").eq("id", kobSessionId).limit(1);
  const kob = kobRows?.[0];
  if (!kob) throw new Error("Sesi KOB tidak dijumpai");
  if (kob.package_payment_mode !== "installment" || kob.package_payment_status !== "partial") {
    throw new Error("Sesi ini bukan ansuran aktif");
  }
  const { data: paidRows } = await admin.from("psy_payments").select("total").eq("status", "completed").eq("intent->>kob_session_id", kobSessionId);
  const totalPaid = (paidRows || []).reduce((s, p) => s + Number(p.total || 0), 0);
  const { data: cps } = await admin.from("psy_kob_installment_checkpoints").select("seq, due_date, target_cumulative").eq("kob_session_id", kobSessionId).order("seq", { ascending: true });
  const nextCp = (cps || []).find((c) => Number(c.target_cumulative) > totalPaid + 5e-3);
  if (!nextCp) throw new Error("Tiada ansuran tertunggak");
  const amount = Math.max(0, Number(nextCp.target_cumulative) - totalPaid);
  if (!(amount > 0)) throw new Error("Tiada ansuran tertunggak");
  const checkpointLabel = nextCp.seq === 0 ? "Deposit" : `Ansuran ${nextCp.seq}`;
  const itemTitle = `${checkpointLabel} \u2014 ${kob.recommended_package_name || ""}`.trim();
  const { data: ptRows } = await admin.from("psy_patients").select("user_id, full_name, phone, email").eq("id", kob.patient_id).limit(1);
  const patient = ptRows?.[0];
  let patientEmail = patient?.email || void 0;
  if (!patientEmail && patient?.user_id) {
    const { data: au } = await admin.auth.admin.getUserById(patient.user_id).catch(() => ({ data: null }));
    patientEmail = au?.user?.email || void 0;
  }
  await admin.from("psy_payments").update({ status: "failed", gateway_status: "superseded", notes: "Digantikan oleh pautan HitPay baharu" }).eq("patient_id", kob.patient_id).eq("status", "pending").eq("intent->>kob_session_id", kobSessionId);
  const receiptRef = "RCP-" + Date.now().toString(36).toUpperCase() + "-" + Math.floor(performance.now()).toString(36).toUpperCase();
  const provider = activeProviderName();
  const { error: insErr } = await admin.from("psy_payments").insert({
    receipt_ref: receiptRef,
    patient_id: kob.patient_id,
    user_id: patient?.user_id || null,
    items: [{ type: "kob_installment_topup", title: itemTitle, amount, kobSessionId, checkpointSeq: nextCp.seq }],
    subtotal: amount,
    total: amount,
    payment_method: "gateway",
    status: "pending",
    gateway_provider: provider,
    gateway_status: "pending",
    intent: {
      items: [{ type: "kob_installment_topup", title: itemTitle, amount, kobSessionId, checkpointSeq: nextCp.seq }],
      patientId: kob.patient_id,
      userId: patient?.user_id || null,
      kob_session_id: kobSessionId
    }
  });
  if (insErr) throw new Error("Gagal simpan bayaran pending: " + insErr.message);
  const redirectUrl = `${returnUrl}${returnUrl.includes("?") ? "&" : "?"}ref=${encodeURIComponent(receiptRef)}`;
  const providerImpl = getProvider(provider);
  let gatewayRef, checkoutUrl;
  if (saveCard) {
    if (!providerImpl.createCardAuthorization) throw new Error(`Provider "${provider}" tidak sokong simpan kad`);
    if (!patientEmail) {
      throw new Error('Pesakit ini tiada alamat emel dalam rekod \u2014 wajib untuk simpan kad (auto-caj ansuran). Kemaskini emel pesakit dulu, atau tanggalkan tanda "Simpan kad" dan hantar pautan biasa.');
    }
    const created = await providerImpl.createCardAuthorization({
      reference: receiptRef,
      amount: money(amount),
      purpose: itemTitle,
      currency: "MYR",
      customerEmail: patientEmail,
      customerName: patient?.full_name || void 0,
      redirectUrl
    });
    gatewayRef = created.authRef;
    checkoutUrl = created.checkoutUrl;
    await admin.from("psy_kob_card_authorizations").upsert({
      kob_session_id: kobSessionId,
      patient_id: kob.patient_id,
      gateway_provider: provider,
      gateway_auth_ref: gatewayRef,
      status: "pending"
    }, { onConflict: "kob_session_id" });
  } else {
    const webhookUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/payments-webhook`;
    const created = await providerImpl.createPayment({
      reference: receiptRef,
      amount: money(amount),
      currency: "MYR",
      email: patientEmail,
      name: patient?.full_name || void 0,
      purpose: itemTitle,
      redirectUrl,
      webhookUrl
    });
    gatewayRef = created.gatewayRef;
    checkoutUrl = created.checkoutUrl;
  }
  await admin.from("psy_payments").update({ gateway_ref: gatewayRef, checkout_url: checkoutUrl }).eq("receipt_ref", receiptRef);
  return {
    checkoutUrl,
    receiptRef,
    amount,
    checkpointSeq: nextCp.seq,
    checkpointLabel,
    dueDate: nextCp.due_date
  };
}

// supabase/functions/_shared/kob_retry_link.ts
var money2 = (n) => (Math.round(n * 100) / 100).toFixed(2);
var isUuid = (s) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
async function createKobDepositLink(admin, opts) {
  const { kobSessionId, mode, returnUrl, initiatedBy = "staff" } = opts;
  const useSaveCard = !!opts.saveCard && mode === "installment";
  const { data: kobRows } = await admin.from("psy_kob_sessions").select("id, patient_id, recommended_package_id, recommended_package_name, recommended_package_price, package_payment_status").eq("id", kobSessionId).limit(1);
  const kob = kobRows?.[0];
  if (!kob) throw new Error("Sesi KOB tidak dijumpai");
  if (!kob.recommended_package_id) throw new Error("Sesi KOB ini tiada pakej dicadangkan");
  if (kob.package_payment_status !== "pending" && kob.package_payment_status !== "declined") {
    throw new Error("Bayaran pakej sesi ini bukan lagi berstatus pending/declined");
  }
  const tier = opts.tier === "today" || opts.tier === "now" ? opts.tier : kob.package_payment_status === "pending" ? "today" : "now";
  let pkgQ = admin.from("psy_packages").select("price, today_price, installment_allowed, installment_deposit_amount, installment_duration_months, installment_monthly_amount, today_installment_deposit_amount, today_installment_duration_months, today_installment_monthly_amount");
  pkgQ = isUuid(kob.recommended_package_id) ? pkgQ.or(`id.eq.${kob.recommended_package_id},package_id.eq.${kob.recommended_package_id}`) : pkgQ.eq("package_id", kob.recommended_package_id);
  const { data: pkgRows } = await pkgQ.limit(1);
  const pkgMeta = pkgRows?.[0];
  const packagePrice = tier === "today" ? Number(kob.recommended_package_price || 0) : Number(pkgMeta?.price || 0);
  if (!(packagePrice > 0)) throw new Error("Harga pakej tidak sah");
  const tierDepositAmount = tier === "today" ? pkgMeta?.today_installment_deposit_amount ?? pkgMeta?.installment_deposit_amount : pkgMeta?.installment_deposit_amount;
  const tierDurationMonths = tier === "today" ? pkgMeta?.today_installment_duration_months ?? pkgMeta?.installment_duration_months : pkgMeta?.installment_duration_months;
  const tierMonthlyAmount = tier === "today" ? pkgMeta?.today_installment_monthly_amount ?? pkgMeta?.installment_monthly_amount : pkgMeta?.installment_monthly_amount;
  let amount;
  if (mode === "installment") {
    const installmentAllowed = !!pkgMeta?.installment_allowed && Number(tierDepositAmount) > 0 && Number(tierDurationMonths) > 1 && Number(tierMonthlyAmount) > 0;
    if (!installmentAllowed) throw new Error("Pakej ini tidak membenarkan ansuran");
    amount = Number(tierDepositAmount);
  } else if (mode === "manual_installment") {
    const { data: cpRows } = await admin.from("psy_kob_installment_checkpoints").select("target_cumulative, status").eq("kob_session_id", kobSessionId).eq("seq", 0).limit(1);
    const cp = cpRows?.[0];
    if (!cp || cp.status !== "pending") throw new Error("Jadual Ansuran Manual belum disediakan");
    amount = Number(cp.target_cumulative);
  } else {
    amount = packagePrice;
  }
  const { data: ptRows } = await admin.from("psy_patients").select("user_id, full_name, phone, email").eq("id", kob.patient_id).limit(1);
  const patient = ptRows?.[0];
  let patientEmail = patient?.email || void 0;
  if (!patientEmail && patient?.user_id) {
    const { data: au } = await admin.auth.admin.getUserById(patient.user_id).catch(() => ({ data: null }));
    patientEmail = au?.user?.email || void 0;
  }
  if (useSaveCard && !patientEmail) {
    throw new Error('Pesakit ini tiada alamat emel dalam rekod \u2014 wajib untuk simpan kad (auto-caj ansuran). Kemaskini emel pesakit dulu (Pesakit \u2192 Kemaskini Pesakit), atau tanggalkan tanda "Simpan kad" dan hantar pautan biasa.');
  }
  const receiptRef = "RCP-" + Date.now().toString(36).toUpperCase() + "-" + Math.floor(performance.now()).toString(36).toUpperCase();
  const provider = activeProviderName();
  const itemTitle = `${mode === "full" ? "Bayaran Penuh" : mode === "manual_installment" ? "Deposit Ansuran Manual" : "Deposit Ansuran"} \u2014 ${kob.recommended_package_name || ""}`.trim();
  await admin.from("psy_payments").update({ status: "failed", gateway_status: "superseded", notes: "Digantikan oleh pautan HitPay baharu" }).eq("patient_id", kob.patient_id).eq("status", "pending").eq("intent->>kob_session_id", kobSessionId);
  const { error: insErr } = await admin.from("psy_payments").insert({
    receipt_ref: receiptRef,
    patient_id: kob.patient_id,
    user_id: patient?.user_id || null,
    items: [{ type: "kob_deposit", title: itemTitle, amount, kobSessionId, mode, tier }],
    subtotal: amount,
    total: amount,
    payment_method: "gateway",
    status: "pending",
    gateway_provider: provider,
    gateway_status: "pending",
    intent: {
      items: [{ type: "kob_deposit", title: itemTitle, amount, kobSessionId, mode, tier }],
      patientId: kob.patient_id,
      userId: patient?.user_id || null,
      kob_session_id: kobSessionId,
      // Pesakit sendiri boleh cetus laluan ni sekarang (self-checkout installment,
      // payments-kob-initiate) — bukan staff sahaja macam asal. kob-detail.html
      // baca field ni utk elak silap anggap SETIAP pending gateway payment
      // bermaksud "staff dah hantar pautan WhatsApp" (lihat hitpayStateChecked).
      initiated_by: initiatedBy
    }
  });
  if (insErr) throw new Error("Gagal simpan bayaran pending: " + insErr.message);
  const redirectUrl = `${returnUrl}${returnUrl.includes("?") ? "&" : "?"}ref=${encodeURIComponent(receiptRef)}`;
  const providerImpl = getProvider(provider);
  let gatewayRef, checkoutUrl;
  if (useSaveCard) {
    if (!providerImpl.createCardAuthorization) throw new Error(`Provider "${provider}" tidak sokong simpan kad`);
    const created = await providerImpl.createCardAuthorization({
      reference: receiptRef,
      amount: money2(amount),
      purpose: itemTitle,
      currency: "MYR",
      customerEmail: patientEmail,
      customerName: patient?.full_name || void 0,
      redirectUrl
    });
    gatewayRef = created.authRef;
    checkoutUrl = created.checkoutUrl;
    await admin.from("psy_kob_card_authorizations").upsert({
      kob_session_id: kobSessionId,
      patient_id: kob.patient_id,
      gateway_provider: provider,
      gateway_auth_ref: gatewayRef,
      status: "pending"
    }, { onConflict: "kob_session_id" });
  } else {
    const webhookUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/payments-webhook`;
    const created = await providerImpl.createPayment({
      reference: receiptRef,
      amount: money2(amount),
      currency: "MYR",
      email: patientEmail,
      name: patient?.full_name || void 0,
      purpose: itemTitle,
      redirectUrl,
      webhookUrl
    });
    gatewayRef = created.gatewayRef;
    checkoutUrl = created.checkoutUrl;
  }
  await admin.from("psy_payments").update({ gateway_ref: gatewayRef, checkout_url: checkoutUrl }).eq("receipt_ref", receiptRef);
  return { checkoutUrl, receiptRef, amount, itemTitle };
}

// supabase/functions/_shared/kob_autocharge.ts
async function createKobCardAttachLink(admin, kobSessionId, returnUrl) {
  const { data: kobRows } = await admin.from("psy_kob_sessions").select("id, patient_id, recommended_package_name, package_payment_mode").eq("id", kobSessionId).limit(1);
  const kob = kobRows?.[0];
  if (!kob) throw new Error("Sesi KOB tidak dijumpai");
  if (kob.package_payment_mode !== "installment") throw new Error("Sesi ini bukan ansuran");
  const { data: ptRows } = await admin.from("psy_patients").select("user_id, full_name, phone, email").eq("id", kob.patient_id).limit(1);
  const patient = ptRows?.[0];
  let patientEmail = patient?.email || void 0;
  if (!patientEmail && patient?.user_id) {
    const { data: au } = await admin.auth.admin.getUserById(patient.user_id).catch(() => ({ data: null }));
    patientEmail = au?.user?.email || void 0;
  }
  if (!patientEmail) {
    throw new Error("Pesakit ini tiada alamat emel dalam rekod \u2014 wajib untuk lampir kad (auto-caj ansuran). Kemaskini emel pesakit dulu (Pesakit \u2192 Kemaskini Pesakit).");
  }
  const providerName = activeProviderName();
  const provider = getProvider(providerName);
  if (!provider.createCardAuthorization) throw new Error(`Provider "${providerName}" tidak sokong lampiran kad`);
  const receiptRef = "CARD-" + Date.now().toString(36).toUpperCase() + "-" + Math.floor(performance.now()).toString(36).toUpperCase();
  const itemTitle = `Pengesahan Kad \u2014 Ansuran Automatik (${kob.recommended_package_name || ""})`.trim();
  const { data: oldPending } = await admin.from("psy_payments").select("id, items").eq("patient_id", kob.patient_id).eq("status", "pending").eq("intent->>kob_session_id", kobSessionId);
  for (const row of oldPending || []) {
    if (row.items?.[0]?.type === "kob_card_attach") {
      await admin.from("psy_payments").update({ status: "failed", gateway_status: "superseded", notes: "Digantikan oleh pautan lampir kad baharu" }).eq("id", row.id);
    }
  }
  const { error: insErr } = await admin.from("psy_payments").insert({
    receipt_ref: receiptRef,
    patient_id: kob.patient_id,
    user_id: patient?.user_id || null,
    items: [{ type: "kob_card_attach", title: itemTitle, kobSessionId }],
    subtotal: 1,
    total: 1,
    payment_method: "gateway",
    status: "pending",
    gateway_provider: providerName,
    gateway_status: "pending",
    intent: {
      items: [{ type: "kob_card_attach", title: itemTitle, kobSessionId }],
      patientId: kob.patient_id,
      userId: patient?.user_id || null,
      kob_session_id: kobSessionId
    }
  });
  if (insErr) throw new Error("Gagal simpan rekod pengesahan kad: " + insErr.message);
  const redirectUrl = `${returnUrl}${returnUrl.includes("?") ? "&" : "?"}ref=${encodeURIComponent(receiptRef)}`;
  const created = await provider.createCardAuthorization({
    reference: receiptRef,
    amount: "1.00",
    // sesi lampir-kad BERDIRI SENDIRI (tiada bayaran sebenar utk ditumpang) — had minimum API
    purpose: "Pengesahan Kad \u2014 Ansuran Automatik ISW",
    currency: "MYR",
    customerEmail: patientEmail,
    customerName: patient?.full_name || void 0,
    redirectUrl
  });
  await admin.from("psy_payments").update({ gateway_ref: created.authRef, checkout_url: created.checkoutUrl }).eq("receipt_ref", receiptRef);
  await admin.from("psy_kob_card_authorizations").upsert({
    kob_session_id: kobSessionId,
    patient_id: kob.patient_id,
    gateway_provider: providerName,
    gateway_auth_ref: created.authRef,
    status: "pending"
  }, { onConflict: "kob_session_id" });
  return { checkoutUrl: created.checkoutUrl, receiptRef };
}

// supabase/functions/payments-kob-initiate/index.ts
var corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
var json = (b, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });
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
    const isStaff = profile?.role === "staff";
    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });
    const body = await req.json().catch(() => ({}));
    const kobSessionId = String(body.kobSessionId || "");
    const mode = String(body.mode || "");
    const returnUrl = String(body.returnUrl || "");
    if (!kobSessionId) return json({ error: "kobSessionId diperlukan" }, 400);
    if (mode !== "full" && mode !== "installment" && mode !== "manual_installment" && mode !== "topup" && mode !== "attach_card") {
      return json({ error: "mode mesti 'full', 'installment', 'manual_installment', 'topup' atau 'attach_card'" }, 400);
    }
    if (!returnUrl) return json({ error: "returnUrl diperlukan" }, 400);
    if (!isStaff) {
      if (mode !== "installment") return json({ error: "forbidden \u2014 staff sahaja" }, 403);
      const { data: kobRows } = await admin.from("psy_kob_sessions").select("patient_id, intended_payment_mode").eq("id", kobSessionId).limit(1);
      const kobRow = kobRows?.[0];
      if (!kobRow) return json({ error: "Sesi KOB tidak dijumpai" }, 404);
      if (kobRow.intended_payment_mode !== "installment") return json({ error: "forbidden \u2014 staff belum tetapkan plan installment" }, 403);
      const { data: ptRows } = await admin.from("psy_patients").select("user_id").eq("id", kobRow.patient_id).limit(1);
      if (ptRows?.[0]?.user_id !== user.id) return json({ error: "forbidden \u2014 bukan sesi anda" }, 403);
    }
    if (mode === "topup") {
      try {
        const link = await createKobInstallmentTopupLink(admin, kobSessionId, returnUrl, body.saveCard === true);
        return json({ ok: true, checkoutUrl: link.checkoutUrl, receiptRef: link.receiptRef, amount: link.amount });
      } catch (err) {
        return json({ error: err.message || "Ralat tidak diketahui" }, 400);
      }
    }
    if (mode === "attach_card") {
      try {
        const link = await createKobCardAttachLink(admin, kobSessionId, returnUrl);
        return json({ ok: true, checkoutUrl: link.checkoutUrl, receiptRef: link.receiptRef });
      } catch (err) {
        return json({ error: err.message || "Ralat tidak diketahui" }, 400);
      }
    }
    const requestedTier = body.tier === "today" || body.tier === "now" ? body.tier : void 0;
    const saveCard = body.saveCard === true;
    try {
      const link = await createKobDepositLink(admin, {
        kobSessionId,
        mode,
        tier: requestedTier,
        returnUrl,
        initiatedBy: isStaff ? "staff" : "patient",
        saveCard
      });
      return json({ ok: true, checkoutUrl: link.checkoutUrl, receiptRef: link.receiptRef, amount: link.amount });
    } catch (err) {
      return json({ error: err.message || "Ralat tidak diketahui" }, 400);
    }
  } catch (err) {
    return json({ error: err.message || "Ralat tidak diketahui" }, 500);
  }
});
