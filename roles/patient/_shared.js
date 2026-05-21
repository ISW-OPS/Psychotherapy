// ============================================================
// PATIENT SHARED LOGIC — common code across all patient pages
// ============================================================

window.currentUser = null;
window.patientRecord = null;

// NAV_ITEMS sekarang dalam shared/navbar.js (NAV_ITEMS_BY_ROLE.patient)

// ==================== KYC GATING ====================
function hasCompletedKyc() {
  if (!window.patientRecord) return false;
  const p = window.patientRecord;
  return !!(
    p.ic_number &&
    p.full_name &&
    p.address &&
    p.phone &&
    p.medical_condition &&
    p.emergency_contact_name &&
    p.emergency_contact_phone
  );
}

// Cached after initPatient — true only when KYC is formally approved
window.kycApproved = false;

async function resolveKycApproved() {
  const p = window.patientRecord;
  if (!p) return false;
  // Active patients (staff-created and claimed, or fully approved) skip KYC
  if (p.status === 'active') return true;
  // Pending patients: must have an approved KYC submission
  const subs = await dbQuery('psy_kyc_submissions', {
    eq: { user_id: window.currentUser.id },
    limit: 1,
  }).catch(() => []);
  return subs[0]?.status === 'approved';
}

async function enforceKyc(currentPageId) {
  // Always-allowed pages (patient can browse packages + pay during KOB flow)
  if (['kyc', 'profile', 'dashboard', 'kob', 'pakej', 'payment', 'routine', 'checkin', 'kepatuhan'].includes(currentPageId)) return true;

  // KOB flow gating: must complete KOB before accessing other features
  const p = window.patientRecord;
  const kobStatus = p?.kob_status || 'na';
  if (kobStatus !== 'na' && kobStatus !== 'completed') {
    // Payment is external (GHL). KYC is Step 1.
    if (kobStatus === 'pending_payment' || kobStatus === 'paid') {
      window.location.href = 'kyc.html';
    } else {
      // kyc_done / booked / hadir → tempah / lihat KOB
      window.location.href = 'kob.html';
    }
    return false;
  }

  // KOB completed → unlock everything (KYC admin approval no longer mandatory)
  if (kobStatus === 'completed') return true;

  if (window.kycApproved) return true;
  window.location.href = 'kyc.html';
  return false;
}

// ==================== PACKAGE GATING ====================
function hasActivePackage() {
  if (!window.patientRecord) return false;
  if (!window.patientRecord.active_package_id) return false;
  if (window.patientRecord.package_expires_at) {
    if (new Date(window.patientRecord.package_expires_at) < new Date()) return false;
  }
  return true;
}

function showLockScreen(container) {
  if (!container) return;
  container.innerHTML = `
    <div class="max-w-xl mx-auto bg-white rounded-2xl border border-ink/10 p-8 md:p-10 text-center mt-10">
      <div class="text-6xl mb-4">🔒</div>
      <h2 class="text-2xl font-bold text-ink mb-2">Pakej Rawatan Diperlukan</h2>
      <p class="text-sm text-ink/70 mb-6">Anda perlu memilih dan membeli pakej rawatan untuk akses ciri ini. Pakej rawatan menentukan tahap akses dan rawatan yang anda layak terima.</p>
      <a href="pakej.html" class="inline-block bg-navy text-white px-6 py-3 rounded-lg font-semibold hover:bg-navy-dark">
        📦 Pilih Pakej Rawatan →
      </a>
    </div>`;
}

async function initPatient(pageId, titleSub) {
  window.currentUser = await checkAuth('patient');
  if (!window.currentUser) return null;

  let patients = await dbQuery('psy_patients', { eq: { user_id: window.currentUser.id } });

  // No linked record — try to claim an existing staff-created record by EMAIL.
  if (patients.length === 0) {
    const userEmail = window.currentUser.email || null;

    let staffPt = null;
    if (userEmail) {
      const { data } = await window.db
        .from('psy_patients')
        .select('*')
        .is('user_id', null)
        .eq('created_by_staff', true)
        .ilike('email', userEmail)
        .limit(1);
      staffPt = data?.[0] || null;
    }

    if (staffPt) {
      // Auto-decide kob_status + status berdasarkan keadaan rekod staff
      const hasActivePackage = !!staffPt.active_package_id;
      const isInactive = staffPt.status === 'inactive';

      const newStatus = isInactive ? 'inactive'
                       : hasActivePackage ? 'active'
                       : 'active';
      const newKobStatus = hasActivePackage ? 'completed'  // Skip KOB, terus ke plan
                          : isInactive ? 'na'              // Pesakit Lama — bypass
                          : 'kyc_done';                    // Belum ada pakej — masih kena book KOB

      const { data: linked } = await window.db
        .from('psy_patients')
        .update({
          user_id: window.currentUser.id,
          status: newStatus,
          kob_status: newKobStatus,
          created_by_staff: false,
        })
        .eq('id', staffPt.id)
        .select()
        .single();
      if (linked) {
        patients = [linked];
        // Notify (tidak silap kalau function tiada)
        try {
          await window.db.from('psy_notifications').insert({
            user_id: window.currentUser.id,
            type: 'system',
            title: hasActivePackage
              ? 'Selamat datang! Rawatan anda telah dikemaskini'
              : 'Selamat datang! Rekod anda telah disiapkan',
            body: hasActivePackage
              ? `Pakej ${staffPt.active_package_name || 'rawatan'} anda aktif. Sila lihat Treatment Plan.`
              : 'Maklumat anda telah diisi oleh staff. Tiada perlu KYC — sila terus tempah KOB.',
            link: hasActivePackage ? 'plan.html' : 'kob.html',
          });
        } catch {}
      }
    }
  }

  // Still no record — fresh signup, create a new patient record (retry on MRN conflict)
  if (patients.length === 0) {
    for (let attempt = 0; attempt < 5; attempt++) {
      try {
        const { data: latest } = await window.db.from('psy_patients')
          .select('mrn').like('mrn', 'P-%').order('mrn', { ascending: false }).limit(1);
        const lastNum = parseInt(latest?.[0]?.mrn?.replace(/\D/g, '')) || 0;
        const mrn = 'P-' + String(lastNum + 1 + attempt).padStart(3, '0');
        const newPatient = await dbInsert('psy_patients', {
          user_id: window.currentUser.id,
          mrn,
          status: 'pending_kyc',
        });
        patients = [newPatient];
        break;
      } catch (e) {
        if (!/duplicate|unique/i.test(e.message || '')) {
          console.warn('Auto-create patient failed:', e.message);
          break;
        }
      }
    }
  }

  window.patientRecord = patients[0] || null;

  // Resolve KYC approval once and cache
  window.kycApproved = await resolveKycApproved();

  document.getElementById('app-loading')?.classList.add('hidden');
  document.getElementById('app-shell')?.classList.remove('hidden');

  // Hide KYC + KOB nav items conditionally
  const kobStatus = window.patientRecord?.kob_status || 'na';
  // Hide nav items conditionally:
  // - kyc: hide after approved
  // - kob: hide for grandfathered patients only
  // Pakej Rawatan kekal visible — patient boleh browse continuity / pakej seterusnya
  const navItems = getNavItems('patient').filter(item => {
    if (item.id === 'kyc' && window.kycApproved) return false;
    if (item.id === 'kob' && kobStatus === 'na') return false;
    return true;
  });
  renderNavbar('patient', window.currentUser, navItems, pageId);

  const nav = getNavItems('patient').find(n => n.id === pageId);
  renderHeader(nav?.label || '', titleSub || '');

  updateCartBadge();

  // KYC gate — redirect new patients to complete KYC before accessing other pages
  const allowed = await enforceKyc(pageId);
  if (!allowed) return null;

  return window.currentUser;
}

// ==================== CART (localStorage) ====================
let cart = JSON.parse(localStorage.getItem('isw_cart') || '[]');

function addToCart(product) {
  if (typeof product === 'string') {
    product = window.PRODUCTS?.find(p => p.id === product);
    if (!product) return;
  }
  const existing = cart.find(i => i.id === product.id);
  const currentQty = existing ? existing.qty : 0;
  if (product.stock != null && currentQty + 1 > product.stock) {
    banner(`Stok ${product.name} tinggal ${product.stock} sahaja`, 'error');
    return;
  }
  if (existing) existing.qty += 1;
  else cart.push({ ...product, qty: 1 });
  localStorage.setItem('isw_cart', JSON.stringify(cart));
  updateCartBadge();
  banner(`${product.name} ditambah ke cart`);
}

function removeFromCart(id) {
  cart = cart.filter(i => i.id !== id);
  localStorage.setItem('isw_cart', JSON.stringify(cart));
  updateCartBadge();
  if (typeof renderCart === 'function') renderCart();
}

function updateQty(id, delta) {
  const item = cart.find(i => i.id === id);
  if (!item) return;
  if (delta > 0) {
    const product = window.PRODUCTS?.find(p => p.id === id);
    if (product?.stock != null && item.qty + delta > product.stock) {
      banner(`Stok ${item.name} tinggal ${product.stock} sahaja`, 'error');
      return;
    }
  }
  item.qty += delta;
  if (item.qty <= 0) { removeFromCart(id); return; }
  localStorage.setItem('isw_cart', JSON.stringify(cart));
  updateCartBadge();
  if (typeof renderCart === 'function') renderCart();
}

function updateCartBadge() {
  const fab = document.getElementById('cart-fab');
  if (!fab) return;
  const count = cart.reduce((s, i) => s + i.qty, 0);
  const total = cart.reduce((s, i) => s + i.qty * i.price, 0);
  if (count > 0) {
    fab.classList.remove('hidden');
    document.getElementById('cart-count').textContent = count;
    document.getElementById('cart-total-mini').textContent = 'RM ' + total.toFixed(2);
  } else {
    fab.classList.add('hidden');
  }
}

function getCart() { return cart; }
function clearCart() {
  cart = [];
  localStorage.setItem('isw_cart', JSON.stringify(cart));
  updateCartBadge();
}

// ==================== HELPERS ====================
function statCard(label, value, sub) {
  return `<div class="bg-white rounded-xl p-4 border border-ink/10">
    <div class="text-xs text-ink/60">${label}</div>
    <div class="text-lg font-bold mt-1">${value}</div>
    <div class="text-xs text-ink/60 mt-1">${sub || ''}</div>
  </div>`;
}

function vitalBox(l, v) {
  return `<div class="p-3 bg-cream rounded-lg text-center"><div class="text-[10px] text-ink/50">${l}</div><div class="text-lg font-bold">${v}</div></div>`;
}

function formatDate(d) { return new Date(d).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' }); }
function formatTime(d) { return new Date(d).toLocaleTimeString('en-GB', { hour:'2-digit', minute:'2-digit' }); }

function banner(msg, type = 'ok') {
  const el = document.createElement('div');
  const color = type === 'error' ? 'bg-terracotta' : 'bg-green';
  el.className = `fixed top-4 left-1/2 -translate-x-1/2 ${color} text-white px-5 py-2.5 rounded-xl text-sm font-semibold z-50 shadow-lg`;
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 2500);
}
