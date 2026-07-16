window.ISW_TAILWIND_CONFIG = {
  theme: {
    extend: {
      colors: {
        cream:      '#F5F0E6',
        ink:        '#3C4F5C',
        green:      { light: '#E3F1E5', DEFAULT: '#2E8B3E', dark: '#1F6E2B' },
        navy:       { light: '#DCE6F3', DEFAULT: '#1B4E9C', dark: '#0F2E5F' },
        terracotta: { light: '#FCF6F5', DEFAULT: '#B85042' },
        gold:       { light: '#F7F0DE', DEFAULT: '#C9A86A', dark: '#B8860B' },
        teal:       { DEFAULT: '#50808E' },
        bio:        '#2E8B3E',
        psycho:     '#1B4E9C',
        social:     '#C9A86A',
        spiritual:  '#50808E',
      },
      fontFamily: { sans: ['Inter', 'system-ui', 'sans-serif'] }
    }
  }
};

// ============================================================
// KEUTAMAAN PAPARAN — tema terang/gelap + warna utama (jenama)
// Fail ini dimuat dalam <head> semua halaman, jadi tema di-apply
// SEBELUM paint (tiada kelipan putih). Tetapan disimpan:
//   isw_theme          (localStorage, per-peranti)  light|dark|system
//   isw_primary_color  (cache localStorage; sumber sebenar psy_settings.primary_color)
// ============================================================
(function () {
  var DEFAULT_PRIMARY = '#1B4E9C';

  // ── util warna ────────────────────────────────────────────
  function hexRgb(hex) {
    var m = /^#?([0-9a-f]{6})$/i.exec(hex || '');
    if (!m) return null;
    var n = parseInt(m[1], 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  // w=0 → warna asal; w=1 → penuh ke arah 'to' (0 = hitam, 255 = putih)
  function mix(rgb, to, w) {
    return '#' + rgb.map(function (c) {
      return ('0' + Math.round(c + (to - c) * w).toString(16)).slice(-2);
    }).join('');
  }

  // ── warna utama (Warna Utama dlm Tetapan → Rupa) ─────────
  var primaryStyle = document.createElement('style');
  primaryStyle.id = 'isw-primary-css';
  document.head.appendChild(primaryStyle);

  window.iswApplyPrimary = function (hex) {
    var rgb = hexRgb(hex);
    if (!rgb || hex.toUpperCase() === DEFAULT_PRIMARY) { primaryStyle.textContent = ''; return; }
    var base = '#' + rgb.map(function (c) { return ('0' + c.toString(16)).slice(-2); }).join('');
    var dark = mix(rgb, 0, 0.45);
    var light = mix(rgb, 255, 0.85);
    primaryStyle.textContent =
      ':root{--rp:' + dark + ';--rpm:' + base + ';--rpl:' + light + ';--rptx:' + base + '}' +
      '.bg-navy{background-color:' + base + ' !important}' +
      '.bg-navy-dark{background-color:' + dark + ' !important}' +
      '.bg-navy-light{background-color:' + light + ' !important}' +
      '.hover\\:bg-navy:hover{background-color:' + base + ' !important}' +
      '.hover\\:bg-navy-dark:hover{background-color:' + dark + ' !important}' +
      '.text-navy{color:' + base + ' !important}' +
      '.text-navy-dark{color:' + dark + ' !important}' +
      '.hover\\:text-navy:hover{color:' + base + ' !important}' +
      '.border-navy{border-color:' + base + ' !important}' +
      '.hover\\:border-navy:hover{border-color:' + base + ' !important}' +
      '.focus\\:border-navy:focus{border-color:' + base + ' !important}';
  };

  var savedPrimary = localStorage.getItem('isw_primary_color');
  if (savedPrimary) window.iswApplyPrimary(savedPrimary);

  // ── tema gelap ────────────────────────────────────────────
  // Skin gelap generik atas kelas Tailwind + komponen kongsi.
  // Selector [class^=]/[class*=" "] sengaja elak padan varian "hover:bg-...".
  var D = 'html[data-theme="dark"]';
  var darkStyle = document.createElement('style');
  darkStyle.id = 'isw-dark-css';
  darkStyle.textContent =
    D + '{color-scheme:dark}' +
    D + ' body{background:#0B1220 !important;color:#C9D4E3}' +
    /* permukaan */
    D + ' [class^="bg-white"],' + D + ' [class*=" bg-white"]{background-color:#131E33 !important}' +
    D + ' [class^="bg-cream"],' + D + ' [class*=" bg-cream"]{background-color:#0F1830 !important}' +
    D + ' [class^="bg-gray-1"],' + D + ' [class*=" bg-gray-1"],' +
    D + ' [class^="bg-gray-5"],' + D + ' [class*=" bg-gray-5"]{background-color:#101A2E !important}' +
    D + ' [class^="bg-navy-light"],' + D + ' [class*=" bg-navy-light"]{background-color:#1B2B4B !important}' +
    /* teks */
    D + ' [class^="text-ink"],' + D + ' [class*=" text-ink"]{color:#C9D4E3 !important}' +
    D + ' [class*="text-ink/3"],' + D + ' [class*="text-ink/4"],' +
    D + ' [class*="text-ink/5"],' + D + ' [class*="text-ink/6"]{color:#8A9CB5 !important}' +
    D + ' [class^="text-gray-"],' + D + ' [class*=" text-gray-"],' +
    D + ' [class^="text-slate-"],' + D + ' [class*=" text-slate-"]{color:#93A4BB !important}' +
    /* sempadan */
    D + ' [class*="border-ink"]{border-color:rgba(148,163,184,.16) !important}' +
    D + ' [class*="divide-ink"]>*{border-color:rgba(148,163,184,.12) !important}' +
    /* kawalan borang */
    D + ' input:not([type=checkbox]):not([type=radio]):not([type=color]),' +
    D + ' select,' + D + ' textarea{background-color:#0E1830 !important;color:#DBE4F0 !important;border-color:rgba(148,163,184,.25) !important}' +
    D + ' ::placeholder{color:#5E7290}' +
    /* sidebar staf (putih → gelap) + topbar */
    D + ' body[class*="role-"] #sidebar{background:#0E1728 !important;border-right-color:rgba(148,163,184,.12) !important}' +
    D + ' #sidebar img{filter:brightness(0) invert(1) !important;opacity:.8}' +
    D + ' #sidebar .nav-item.active img{opacity:1}' +
    D + ' #global-topbar{background:#0E1728 !important}' +
    /* komponen kongsi halaman staf */
    D + ' .tab-btn{color:#8A9CB5}' +
    D + ' .tab-btn.active{color:#8FB4F0;border-bottom-color:#8FB4F0}' +
    D + ' .seg button{background:#0E1830;color:#8A9CB5}' +
    D + ' .seg button.on{background:var(--rpm,#1B4E9C);color:#fff}' +
    D + ' .link-row{background:#131E33}' +
    D + ' .link-row:hover{background:#1A2740}' +
    D + ' .set-meta .t{color:#DFE7F2}' +
    D + ' .set-meta .d{color:#8A9CB5}' +
    D + ' .field label{color:#8A9CB5}' +
    D + ' .set-icn{background:#1B2B4B;color:#9EB6E0}' +
    D + ' thead{background:#0F1830}';
  document.head.appendChild(darkStyle);

  function applyTheme() {
    var pref = localStorage.getItem('isw_theme') || 'light';
    var dark = pref === 'dark' ||
      (pref === 'system' && window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
    document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
  }

  window.iswSetTheme = function (v) {
    localStorage.setItem('isw_theme', v);
    applyTheme();
  };

  // Mod 'system': ikut perubahan tema OS secara langsung
  try {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function () {
      if ((localStorage.getItem('isw_theme') || 'light') === 'system') applyTheme();
    });
  } catch (_) { }

  applyTheme();
})();
