/* ============================================================
   ISW i18n — bilingual (BM ⇄ EN) engine + shared glossary.
   ─ Approach: source text in HTML is Malay (BM). When the user
     picks English, we swap matching text using the EN glossary
     below. Untranslated strings stay BM until added here.
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
    'My Treatment Plan': 'My Treatment Plan',
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

    // — PWA install chip —
    'Pasang': 'Install'
  };

  // Merge the auto-generated full-site glossary. Curated seed above WINS,
  // so we only fill in keys the seed doesn't already define.
  if (window.ISW_I18N_EXTRA) { for (var k in window.ISW_I18N_EXTRA) if (!(k in EN)) EN[k] = window.ISW_I18N_EXTRA[k]; }
  window.ISW_I18N_EN = EN;

  var SKIP_TAGS = { SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, TEXTAREA: 1, CODE: 1, PRE: 1, SVG: 1 };
  var ATTRS = ['placeholder', 'title', 'aria-label'];

  function translate(s) {
    if (s == null) return null;
    var key = s.trim();
    if (!key) return null;
    var t = EN[key];
    if (t == null) return null;
    var lead = s.match(/^\s*/)[0];
    var trail = s.match(/\s*$/)[0];
    return lead + t + trail;
  }

  function handleTextNode(node, lang) {
    if (!node.nodeValue || !node.nodeValue.trim()) return;
    var p = node.parentNode;
    if (p && SKIP_TAGS[p.nodeName]) return;
    if (node.__iswOrig == null) node.__iswOrig = node.nodeValue;
    if (lang === 'en') {
      var t = translate(node.__iswOrig);
      if (t != null) node.nodeValue = t;
    } else if (node.nodeValue !== node.__iswOrig) {
      node.nodeValue = node.__iswOrig;
    }
  }

  function handleAttrs(el, lang) {
    for (var i = 0; i < ATTRS.length; i++) {
      var a = ATTRS[i];
      if (!el.hasAttribute || !el.hasAttribute(a)) continue;
      var ck = '__iswOrig_' + a;
      if (el[ck] == null) el[ck] = el.getAttribute(a);
      if (lang === 'en') {
        var t = translate(el[ck]);
        if (t != null) el.setAttribute(a, t);
      } else {
        el.setAttribute(a, el[ck]);
      }
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
