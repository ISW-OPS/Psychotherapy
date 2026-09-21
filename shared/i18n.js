/* ============================================================
   ISW i18n — bilingual (BM ⇄ EN) engine + shared glossary.
   ─ Approach: most source text in HTML is Malay (BM) — picking
     English swaps it via the EN glossary below. Some UI text was
     authored directly in English instead; picking BM swaps THAT
     via the MS glossary (shared/i18n-dict-ms.js). Either way,
     whatever isn't in the matching dict simply stays as-authored.
   ─ Persistence: choice saved in localStorage('isw_lang').
   ─ Coverage: text nodes + placeholder/title/aria-label attrs,
     plus dynamically-added content (navbar, topbar, lists…) via
     a MutationObserver.
   ─ Default language: EN (per product decision).
   Idempotent & safe to load on every page.
   ============================================================ */
(function () {
  if (window.__iswI18n) return;
  window.__iswI18n = true;

  var DEFAULT_LANG = 'en';
  var STORE = 'isw_lang';

  function getLang() { return localStorage.getItem(STORE) || DEFAULT_LANG; }

  // ── Glossary: Malay source (trimmed) → English ──────────────
  // Grows incrementally. Common UI terms translate everywhere once added.
  var EN = {
    // — Bayaran manual / invois / waris — added 21 Sept —
    "🧾 Sejarah Transaksi": "🧾 Transaction History",
    "📄 Lihat Invois": "📄 View Invoice",
    "🧾 Resit": "🧾 Receipt",
    "📎 Bukti": "📎 Proof",
    "📋 Link Payment": "📋 Payment Link",
    "📄 Invois": "📄 Invoice",
    "Cari no. resit (REC) / no. invois (INV) / rujukan / nama pesakit...": "Search receipt no. (REC) / invoice no. (INV) / reference / patient name...",
    "📎 Lihat Bukti": "📎 View Proof",
    "📄 Invois Ansuran": "📄 Installment Invoice",
    "📑 Invois Penuh": "📑 Full Plan Invoice",
    "Sejarah Transaksi": "Transaction History",
    "Tiada transaksi.": "No transactions.",
    "Tunai": "Cash",
    "Kaedah Bayaran": "Payment Method",
    "No. Rujukan (pilihan)": "Reference No. (optional)",
    "Upload Bukti Bayaran": "Upload Proof of Payment",
    "(wajib kecuali tunai)": "(required unless cash)",
    "💵 Bayar Manual": "💵 Pay Manually",
    "🧾 Lihat Invois": "🧾 View Invoice",
    "Diskaun (RM, pilihan)": "Discount (RM, optional)",
    "Dipaparkan di invois/resit. Harga pakej di atas sudah harga selepas diskaun.": "Shown on the invoice/receipt. The package price above is already the price after discount.",
    "Bayaran di KOB direkod sekali sahaja. Baki direkod di": "Payment at KOB is recorded once only. The balance is recorded in",
    "(tab Bayaran).": "(Payments tab).",
    "Tiada waris / penjamin — pesakit hadir seorang diri (nama, IC & tandatangan waris tidak diperlukan).": "No guardian / surety — patient attends alone (guardian name, IC & signature not required).",
    "Tiada waris / penjamin — saya hadir seorang diri.": "No guardian / surety — I am attending alone.",
    "Anda tidak mempunyai kebenaran edit bayaran.": "You do not have permission to edit payments.",
    "Anda tidak mempunyai kebenaran batalkan bayaran.": "You do not have permission to cancel payments.",
    "Anda tidak mempunyai kebenaran untuk buang tandatangan.": "You do not have permission to remove the signature.",
    "Bayaran dikemaskini ✅": "Payment updated ✅",
    "Bayaran dibatalkan ✅": "Payment cancelled ✅",
    "Diskaun tidak sah": "Invalid discount",
    "Tiada baki untuk direkod.": "No balance to record.",
    "Sila upload bukti bayaran (wajib kecuali tunai)": "Please upload proof of payment (required unless cash)",
    "Jumlah yang sah diperlukan.": "A valid amount is required.",
    "Sebab edit wajib diisi.": "An edit reason is required.",
    "Sebab batal wajib diisi.": "A cancellation reason is required.",
    // — Auth: mobile intro —
    'Mari kita mula!': "Let's get started!",
    'Log masuk untuk kekal sihat & cergas.': 'Login to stay healthy and fit.',
    'PDPA compliant · Data dilindungi': 'PDPA compliant · Data protected',

    // — Auth: desktop hero / support bar —
    'Selamat Datang': 'Welcome',
    'Platform digital anda untuk perjalanan pemulihan yang lebih tersusun dan efektif.': 'Your digital platform for a more organised and effective recovery journey.',
    'Selamat & Terjamin': 'Safe & Secure',
    'Data anda dilindungi dengan keselamatan tahap tinggi.': 'Your data is protected with high-level security.',
    'Pemantauan Perkembangan': 'Progress Monitoring',
    'Pantau kemajuan rawatan anda dengan mudah.': 'Track your treatment progress with ease.',
    'Sokongan Berterusan': 'Continuous Support',
    'Kami bersama anda sepanjang perjalanan pemulihan.': 'We are with you throughout your recovery journey.',
    'Kesihatan adalah harta yang paling berharga.': 'Health is the most precious treasure.',
    'Jaga minda, pulihkan jiwa, capai kehidupan yang lebih baik.': 'Care for the mind, heal the soul, achieve a better life.',
    'Sila masukkan email dan kata laluan anda.': 'Please enter your email and password.',
    'Sila lengkapkan maklumat di bawah.': 'Please complete the details below.',
    'atau': 'or',
    'PDPA Compliant · Data dilindungi · Ibnu Sina Wellness': 'PDPA Compliant · Data protected · Ibnu Sina Wellness',
    'Perlukan bantuan?': 'Need help?',
    'Hubungi kami': 'Contact us',

    // — Auth: login —
    'Log Masuk': 'Login',
    'Log masuk': 'Login',
    'Kata Laluan': 'Password',
    'Masukkan kata laluan': 'Enter your password',
    'Lupa kata laluan?': 'Forgot password?',
    'Belum ada akaun?': "Don't have an account?",
    'Daftar di sini': 'Sign up here',
    'Sedang log masuk...': 'Signing in...',
    'Email atau kata laluan salah': 'Wrong email or password',
    'Email dan kata laluan wajib diisi': 'Email and password are required',
    'Profil tidak dijumpai. Sila hubungi admin atau daftar semula.': 'Profile not found. Please contact admin or sign up again.',

    // — Auth: forgot password —
    'Reset Kata Laluan': 'Reset Password',
    'Masukkan email anda. Link reset akan dihantar ke email tersebut.': 'Enter your email. A reset link will be sent to it.',
    'Hantar Link Reset': 'Send Reset Link',
    'Menghantar...': 'Sending...',
    'Kembali ke Log Masuk': 'Back to Login',
    'Sila masukkan email': 'Please enter your email',

    // — Auth: signup —
    'Daftar': 'Sign Up',
    'Daftar Akaun Baru': 'Create New Account',
    'Nama Penuh': 'Full Name',
    'Nama penuh anda': 'Your full name',
    'Minimum 6 aksara': 'Minimum 6 characters',
    'Saya bersetuju dengan': 'I agree to the',
    'Terma Perkhidmatan': 'Terms of Service',
    'dan': 'and',
    'Dasar Privasi': 'Privacy Policy',
    'Daftar Akaun': 'Create Account',
    'Mendaftar...': 'Creating account...',
    'Sudah ada akaun?': 'Already have an account?',
    'Semua ruangan wajib diisi': 'All fields are required',
    'Kata laluan mestilah sekurang-kurangnya 6 aksara': 'Password must be at least 6 characters',
    'Email ini sudah didaftarkan. Sila log masuk atau guna email lain.': 'This email is already registered. Please log in or use another email.',
    'Format email tidak sah': 'Invalid email format',

    // — Auth: success —
    'Pendaftaran Berjaya!': 'Registration Successful!',
    'Sila semak email untuk pengesahan akaun.': 'Please check your email to confirm your account.',
    'PDPA compliant · Data dilindungi · Ibnu Sina Wellness': 'PDPA compliant · Data protected · Ibnu Sina Wellness',

    // — Chrome: topbar / user menu —
    'Profil': 'Profile',
    'Log Keluar': 'Log Out',
    'Notifikasi': 'Notifications',
    'Baca semua': 'Read all',
    'Tiada notifikasi': 'No notifications',
    'Memuatkan...': 'Loading...',
    'Kembali': 'Back',
    'Kecilkan': 'Collapse',
    'Pesakit': 'Patient',

    // — Chrome: patient sidebar nav —
    'Papan Pemuka': 'Dashboard',
    'Pelan Rawatan Saya': 'My Treatment Plan',
    'Pustaka Bantuan Diri': 'Self-Help Library',
    'Pembayaran': 'Payment',
    'Pesanan & Penjejakan': 'Orders & Tracking',
    'Lapor Isu': 'Report Issue',
    'Borang Pendaftaran': 'Registration Form',
    'Jadual Harian': 'Daily Schedule',
    'Pakej Rawatan': 'Treatment Package',
    'Catatan Harian': 'Daily Log',
    'Bacaan Saya': 'My Readings',
    'Rekod Perubatan': 'Medical Records',
    'Pulangan Botol': 'Bottle Return',
    'Surat Rasmi': 'Official Letter',
    'Artikel': 'Article',
    'Pengumuman': 'Announcement',
    'Produk': 'Product',
    'Catatan': 'Log',

    // — Patient dashboard —
    'Semoga hari ini lebih baik dari semalam.': 'May today be better than yesterday.',
    '📢 Pengumuman & Makluman': '📢 Announcements & Info',
    'Tiada pengumuman buat masa ini': 'No announcements at the moment',
    'Penting': 'Important',
    'Komuniti': 'Community',
    'Pakej Rawatan Semasa': 'Current Treatment Package',
    'Kemajuan Rawatan': 'Treatment Progress',
    '📅 Jumlah Minggu': '📅 Total Weeks',
    '🗓️ Sesi Minggu Ini': '🗓️ Sessions This Week',
    '⏭️ Sesi Seterusnya': '⏭️ Next Session',
    'Lihat Pelan Rawatan': 'View Treatment Plan',
    'Catatan Harian Hari Ini': "Today's Daily Log",
    'Kemaskini setiap hari untuk pemantauan tepat.': 'Update daily for accurate monitoring.',
    'Perasaan Hari Ini': "Today's Mood",
    'Belum diisi': 'Not filled yet',
    'Belum diisi hari ini': 'Not filled in today',
    'Sudah diisi': 'Filled in',
    '✍️ Isi Sekarang': '✍️ Fill Now',
    'Checklist Hari Ini': "Today's Checklist",
    'tugasan selesai': 'tasks completed',
    '✏️ Kemas Kini': '✏️ Update',
    'Sesi Minggu': 'Week',
    'Anda': 'You',
    'belum isi': "haven't filled in",
    'Catatan Harian hari ini. Konsistensi setiap hari membantu pemulihan anda lebih cepat — jangan lepaskan hari ini ya!': "today's Daily Log. Consistency every day helps you recover faster — don't skip today!",
    'Hari ini': 'Today',
    'Tiada': 'None',
    'Tiada sesi akan datang': 'No upcoming sessions',
    '🔄 Tukar': '🔄 Reschedule',
    '🔄 Perlu tukar': '🔄 Needs reschedule',
    'Disahkan': 'Confirmed',
    '❤️ Kesihatan Terkini': '❤️ Latest Health',
    'Kadar Jantung & Oksigen': 'Heart Rate & Oxygen',
    'Paras Gula': 'Sugar Level',
    'Tekanan Darah': 'Blood Pressure',
    'Rendah': 'Low',
    'Kurang': 'Low',
    'Berlebihan': 'High',
    '❤️ Tek. Darah': '❤️ Blood Pressure',
    '⚖️ Berat': '⚖️ Weight',
    'Tinggi (cm)': 'Height (cm)',
    'BMI (auto)': 'BMI (auto)',
    'Untuk kiraan BMI automatik.': 'For automatic BMI calculation.',
    '📋 Peringatan Rawatan': '📋 Treatment Reminders',
    'A. Sebelum Rawatan': 'A. Before Treatment',
    'B. Reaksi & Pemulihan': 'B. Reaction & Recovery',
    'C. Penjagaan Harian': 'C. Daily Care',

    // — Patient plan-week: daily-plan section headers (unit "Hari") —
    '✅ Bimbingan & Bekalan Hari Ini': '✅ Guidance & Supplies Today',
    '🎯 Goals Hari Ini': '🎯 Goals Today',
    '📚 Homework Hari Ini': '📚 Homework Today',
    '📎 Dokumen Hari Ini': "📎 Today's Documents",
    '⭐ Feedback Hari Ini': "⭐ Today's Feedback",

    // — PWA install chip —
    'Pasang': 'Install'
  };

  // Merge the auto-generated full-site glossary. Curated seed above WINS,
  // so we only fill in keys the seed doesn't already define.
  if (window.ISW_I18N_EXTRA) { for (var k in window.ISW_I18N_EXTRA) if (!(k in EN)) EN[k] = window.ISW_I18N_EXTRA[k]; }
  window.ISW_I18N_EN = EN;

  // ── Reverse glossary: English (source) → Malay ──────────────
  // Some UI text was authored directly in English (not translated from a BM
  // source). This dict lets BM mode translate that text too, instead of just
  // leaving it in English. Populated entirely from shared/i18n-dict-ms.js.
  var MS = {};
  if (window.ISW_I18N_EXTRA_MS) { for (var k3 in window.ISW_I18N_EXTRA_MS) MS[k3] = window.ISW_I18N_EXTRA_MS[k3]; }
  window.ISW_I18N_MS = MS;

  var SKIP_TAGS = { SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, TEXTAREA: 1, CODE: 1, PRE: 1, SVG: 1 };
  var ATTRS = ['placeholder', 'title', 'aria-label'];
  // Elements marked data-i18n-skip (or inside one) keep their as-authored text
  // in both languages — used for labels that must never switch (e.g. a nav
  // item deliberately fixed to "Dashboard" regardless of BM/EN).
  var SKIP_ATTR = 'data-i18n-skip';
  function isSkipped(el) { return !!(el && el.closest && el.closest('[' + SKIP_ATTR + ']')); }

  // Normalize internal whitespace runs (incl. newlines from wrapped HTML source)
  // to a single space, so dict keys don't need to replicate source indentation.
  function normKey(s) { return s.replace(/\s+/g, ' ').trim(); }

  function translate(s) {
    if (s == null) return null;
    var key = normKey(s);
    if (!key) return null;
    var t = EN[key];
    if (t == null) return null;
    var lead = s.match(/^\s*/)[0];
    var trail = s.match(/\s*$/)[0];
    return lead + t + trail;
  }

  function translateToMs(s) {
    if (s == null) return null;
    var key = normKey(s);
    if (!key) return null;
    var t = MS[key];
    if (t == null) return null;
    var lead = s.match(/^\s*/)[0];
    var trail = s.match(/\s*$/)[0];
    return lead + t + trail;
  }

  // Resolves the text to show for the given original (as-authored) string:
  // BM source → EN dict when lang is 'en'; English-authored source → MS dict
  // when lang is 'ms'. Falls back to the original when no entry matches.
  function resolve(orig, lang) {
    var t = lang === 'en' ? translate(orig) : translateToMs(orig);
    return t != null ? t : orig;
  }

  function handleTextNode(node, lang) {
    if (!node.nodeValue || !node.nodeValue.trim()) return;
    var p = node.parentNode;
    if (p && SKIP_TAGS[p.nodeName]) return;
    if (isSkipped(p)) return;
    if (node.__iswOrig == null) node.__iswOrig = node.nodeValue;
    var next = resolve(node.__iswOrig, lang);
    if (node.nodeValue !== next) node.nodeValue = next;
  }

  function handleAttrs(el, lang) {
    if (isSkipped(el)) return;
    for (var i = 0; i < ATTRS.length; i++) {
      var a = ATTRS[i];
      if (!el.hasAttribute || !el.hasAttribute(a)) continue;
      var ck = '__iswOrig_' + a;
      if (el[ck] == null) el[ck] = el.getAttribute(a);
      var next = resolve(el[ck], lang);
      if (el.getAttribute(a) !== next) el.setAttribute(a, next);
    }
  }

  function walk(root, lang) {
    if (!root) return;
    if (root.nodeType === 3) { handleTextNode(root, lang); return; }
    if (root.nodeType !== 1) return;
    if (SKIP_TAGS[root.nodeName]) return;

    var tw = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null);
    var n, batch = [];
    while ((n = tw.nextNode())) batch.push(n);
    for (var i = 0; i < batch.length; i++) handleTextNode(batch[i], lang);

    if (root.hasAttribute) handleAttrs(root, lang);
    var withAttr = root.querySelectorAll('[placeholder],[title],[aria-label]');
    for (var j = 0; j < withAttr.length; j++) handleAttrs(withAttr[j], lang);
  }

  function updateToggle() {
    var label = getLang() === 'en' ? 'EN' : 'BM';
    var btns = document.querySelectorAll('[data-isw-lang-btn]');
    // Guard: only write when changed. Unconditional textContent writes would
    // create childList mutations that re-trigger the observer -> infinite loop.
    for (var i = 0; i < btns.length; i++) {
      if (btns[i].textContent !== label) btns[i].textContent = label;
    }
  }

  function apply() {
    var lang = getLang();
    walk(document.body, lang);
    document.documentElement.lang = lang === 'en' ? 'en' : 'ms';
    updateToggle();
  }

  function setLang(l) {
    localStorage.setItem(STORE, l === 'en' ? 'en' : 'ms');
    apply();
    try { document.dispatchEvent(new CustomEvent('isw:langchange', { detail: { lang: getLang() } })); } catch (e) {}
  }

  window.iswGetLang = getLang;
  // Teks dinamik / prompt() / confirm() — enjin padanan-tepat tak boleh terjemah rentetan
  // berinterpolasi atau dialog asli. Guna iswL('Bahasa Melayu', 'English') dan bina KEDUA-DUA
  // versi di tapak panggilan (bahasa semasa dipilih pada masa panggilan).
  window.iswL = function (ms, en) { return getLang() === 'en' ? en : ms; };
  window.iswSetLang = setLang;
  window.iswApplyI18n = apply;
  window.iswToggleLang = function () { setLang(getLang() === 'en' ? 'ms' : 'en'); };

  // ── Observe dynamically-added content (navbar/topbar/lists) ──
  var mo = new MutationObserver(function (muts) {
    var lang = getLang();
    for (var i = 0; i < muts.length; i++) {
      var added = muts[i].addedNodes;
      for (var j = 0; j < added.length; j++) walk(added[j], lang);
    }
    updateToggle();
  });

  function init() {
    apply();
    if (document.body) mo.observe(document.body, { childList: true, subtree: true });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
