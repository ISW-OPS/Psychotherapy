// ============================================================
// SHARED UTILITIES — load via <script src="../../shared/utils.js">
// ============================================================

// Escape user-supplied strings before interpolating into HTML.
// Use for any value that may contain user input (names, notes, messages, etc.)
window.escapeHtml = function (s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
};

// Escape for use inside a JS single-quoted string interpolated into an HTML attribute.
// Example: <button onclick="doX('${escapeJsAttr(name)}')"
window.escapeJsAttr = function (s) {
  const jsEscaped = String(s ?? '')
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/"/g, '\\"')
    .replace(/\r?\n/g, '\\n');
  return window.escapeHtml(jsEscaped);
};

// Local-date string in Malaysia time (no UTC drift): 'YYYY-MM-DD'
window.localDateStr = function (d = new Date()) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

// Kekalkan posisi scroll bila page reload (F5 / location.reload()) — halaman yang
// bina seluruh DOM secara async lepas fetch data (loadX() awal kosong, baru tinggi
// penuh lepas render()) buat browser punya auto scroll-restoration cuba pulih
// terlalu awal (page masih pendek), jadi selalu jatuh balik ke atas. Panggil
// initScrollPreserve() sekali di awal <script> (sebelum render pertama), lepas tu
// restoreScrollPreserve() lepas render pertama siap (hujung IIFE async utama).
window.initScrollPreserve = function () {
  try { if ('scrollRestoration' in history) history.scrollRestoration = 'manual'; } catch (_) {}
  let ticking = false;
  window.addEventListener('scroll', () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => {
      try { sessionStorage.setItem('isw_scroll:' + location.pathname + location.search, String(window.scrollY)); } catch (_) {}
      ticking = false;
    });
  }, { passive: true });
};

window.restoreScrollPreserve = function () {
  let saved;
  try { saved = sessionStorage.getItem('isw_scroll:' + location.pathname + location.search); } catch (_) { return; }
  if (!saved) return;
  const y = parseInt(saved, 10);
  if (!y) return;
  // Double rAF — tunggu satu frame lepas render selesai sebelum scroll, elak
  // layout masih "settling" (fonts/images) tolak posisi balik ke atas.
  requestAnimationFrame(() => requestAnimationFrame(() => window.scrollTo(0, y)));
};
