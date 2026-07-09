// Sub-navigasi modul Mesej Automatik (bar tab mendatar dikongsi semua halaman).
// Guna: renderAutoSubnav('dashboard'|'list'|'templates'|'queue'|'logs')
function renderAutoSubnav(active) {
  const tabs = [
    { key: 'dashboard', label: 'Dashboard', url: 'automation-dashboard.html', ready: true },
    { key: 'list',      label: 'Senarai Automasi', url: 'automations.html', ready: true },
    { key: 'templates', label: 'Template Mesej', url: 'auto-mesej.html', ready: true },
    { key: 'queue',     label: 'Queue / Scheduled', url: 'automation-queue.html', ready: false },
    { key: 'logs',      label: 'Log Penghantaran', url: 'automation-logs.html', ready: false },
  ];
  const el = document.getElementById('submodnav');
  if (!el) return;
  el.innerHTML = `<div class="flex gap-1 border-b border-ink/10 overflow-x-auto">${
    tabs.map(t => {
      if (!t.ready) return `<span class="px-4 py-2.5 text-sm font-semibold whitespace-nowrap border-b-2 border-transparent text-ink/25 cursor-not-allowed" title="Akan datang">${t.label}</span>`;
      return `<a href="${t.url}" class="px-4 py-2.5 text-sm font-semibold whitespace-nowrap border-b-2 ${
        t.key === active ? 'border-navy text-navy' : 'border-transparent text-ink/50 hover:text-ink'
      }">${t.label}</a>`;
    }).join('')
  }</div>`;
}
window.renderAutoSubnav = renderAutoSubnav;
