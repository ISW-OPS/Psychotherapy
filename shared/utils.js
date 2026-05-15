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
