/* ============================================================
   ISW PWA bootstrap — load on any page (entry pages + via navbar.js)
   - Injects manifest link + theme/apple meta (absolute paths, host-root).
   - Registers the service worker at root scope.
   - Shows a dismissable "Pasang App" install chip when available.
   Idempotent: safe to load more than once.
   ============================================================ */
(function () {
  if (window.__iswPwaInit) return;
  window.__iswPwaInit = true;

  // ── 1. Inject head tags (absolute paths so depth doesn't matter) ──
  function addLink(rel, href, extra) {
    if (document.querySelector(`link[rel="${rel}"][href="${href}"]`)) return;
    const l = document.createElement('link');
    l.rel = rel; l.href = href;
    if (extra) Object.assign(l, extra);
    document.head.appendChild(l);
  }
  function addMeta(name, content) {
    if (document.querySelector(`meta[name="${name}"]`)) return;
    const m = document.createElement('meta');
    m.name = name; m.content = content;
    document.head.appendChild(m);
  }

  addLink('manifest', '/manifest.json');
  addLink('apple-touch-icon', '/image/apple-touch-icon.png');
  addLink('icon', '/image/favicon.ico');
  addMeta('theme-color', '#1a3a5c');
  addMeta('mobile-web-app-capable', 'yes');
  addMeta('apple-mobile-web-app-capable', 'yes');
  addMeta('apple-mobile-web-app-status-bar-style', 'black-translucent');
  addMeta('apple-mobile-web-app-title', 'ISW');

  // ── 2. Register service worker ──
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/sw.js').then((reg) => {
        // When a new SW takes over, activate it without forcing a reload loop.
        reg.addEventListener('updatefound', () => {
          const sw = reg.installing;
          if (!sw) return;
          sw.addEventListener('statechange', () => {
            if (sw.state === 'installed' && navigator.serviceWorker.controller) {
              sw.postMessage('SKIP_WAITING');
            }
          });
        });
      }).catch(() => { /* SW optional — ignore failures (e.g. file:// or http) */ });
    });
  }

  // ── 3. Install prompt ("Add to Home Screen") ──
  let deferredPrompt = null;
  const DISMISS_KEY = 'isw_pwa_install_dismissed';

  function showInstallChip() {
    if (document.getElementById('isw-install-chip')) return;
    if (localStorage.getItem(DISMISS_KEY) === '1') return;
    if (window.matchMedia('(display-mode: standalone)').matches) return; // already installed

    const chip = document.createElement('div');
    chip.id = 'isw-install-chip';
    chip.style.cssText =
      'position:fixed;left:50%;transform:translateX(-50%);bottom:5rem;z-index:60;' +
      'background:#1a3a5c;color:#fff;border-radius:14px;padding:10px 14px;display:flex;' +
      'align-items:center;gap:10px;box-shadow:0 8px 28px rgba(0,0,0,.28);font:600 13px Inter,system-ui,sans-serif;' +
      'max-width:calc(100% - 24px);';
    chip.innerHTML =
      '<img src="/image/icon-192.png" alt="" style="width:30px;height:30px;border-radius:8px;flex-shrink:0">' +
      '<span style="line-height:1.25">Pasang ISW di telefon anda<br><span style="font-weight:400;opacity:.75;font-size:11px">Akses pantas dari skrin utama</span></span>' +
      '<button id="isw-install-yes" style="background:#d4af37;color:#1a3a5c;border:0;padding:7px 13px;border-radius:9px;font:700 12px Inter,system-ui;cursor:pointer;flex-shrink:0">Pasang</button>' +
      '<button id="isw-install-no" aria-label="Tutup" style="background:transparent;color:#fff;border:0;font-size:18px;line-height:1;cursor:pointer;opacity:.7;flex-shrink:0">&times;</button>';
    document.body.appendChild(chip);

    document.getElementById('isw-install-yes').onclick = async () => {
      chip.remove();
      if (!deferredPrompt) return;
      deferredPrompt.prompt();
      await deferredPrompt.userChoice.catch(() => {});
      deferredPrompt = null;
    };
    document.getElementById('isw-install-no').onclick = () => {
      chip.remove();
      localStorage.setItem(DISMISS_KEY, '1');
    };
  }

  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    showInstallChip();
  });

  window.addEventListener('appinstalled', () => {
    document.getElementById('isw-install-chip')?.remove();
    localStorage.setItem(DISMISS_KEY, '1');
  });
})();
