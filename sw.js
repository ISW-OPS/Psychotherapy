/* ============================================================
   ISW Service Worker — lightweight PWA shell
   Strategy:
   - Navigation (HTML)  → network-first, fallback cache, then offline.html
   - Same-origin static → stale-while-revalidate (css/js/png/woff/json)
   - Cross-origin (Supabase API, CDN auth) → network only (never cached)
   Bump CACHE_VERSION on each deploy to invalidate old assets.
   ============================================================ */
const CACHE_VERSION = 'isw-v2';
const STATIC_CACHE = `${CACHE_VERSION}-static`;
const PAGE_CACHE = `${CACHE_VERSION}-pages`;

// Minimal precache — never let install fail on a missing entry.
const PRECACHE = [
  '/offline.html',
  '/manifest.json',
  '/image/icon-192.png',
  '/image/icon-512.png',
  '/image/apple-touch-icon.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then((cache) => Promise.allSettled(PRECACHE.map((u) => cache.add(u))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.filter((k) => !k.startsWith(CACHE_VERSION)).map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

// Let the page trigger an immediate activation after an update.
self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
});

const STATIC_RE = /\.(?:css|js|png|jpg|jpeg|svg|webp|ico|woff2?|ttf|json)$/i;

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  // Only handle same-origin. Supabase / CDN / fonts pass straight through.
  if (url.origin !== self.location.origin) return;

  // HTML navigations → network-first (always try fresh, fall back to cache/offline)
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((res) => {
          const copy = res.clone();
          caches.open(PAGE_CACHE).then((c) => c.put(request, copy));
          return res;
        })
        .catch(() =>
          caches.match(request).then((cached) => cached || caches.match('/offline.html'))
        )
    );
    return;
  }

  // Static same-origin assets → stale-while-revalidate
  if (STATIC_RE.test(url.pathname)) {
    event.respondWith(
      caches.open(STATIC_CACHE).then((cache) =>
        cache.match(request).then((cached) => {
          const network = fetch(request)
            .then((res) => {
              if (res && res.status === 200) cache.put(request, res.clone());
              return res;
            })
            .catch(() => cached);
          return cached || network;
        })
      )
    );
  }
});
