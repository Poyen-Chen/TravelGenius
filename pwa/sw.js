// 離線快取：安裝時預先快取整個 App（清單由 scripts/build_pwa_assets.sh 產生）。
// 雲端（Supabase）與天氣（Open-Meteo）是其他網域，一律直接走網路，不快取。
const CACHE = 'packsmart-pwa-v4';
self.addEventListener('install', event => event.waitUntil((async () => {
  const cache = await caches.open(CACHE);
  const files = await (await fetch('precache.json', { cache: 'no-store' })).json();
  await cache.addAll(files);
  await self.skipWaiting();
})()));
self.addEventListener('activate', event => event.waitUntil((async () => {
  for (const key of await caches.keys()) if (key.startsWith('packsmart-pwa-') && key !== CACHE) await caches.delete(key);
  await self.clients.claim();
})()));
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) return;
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request).catch(() => caches.match('index.html')));
    return;
  }
  // 版本化的網址（?v=）完全比對才用快取，避免舊版樣式蓋過新版；沒網路時才退回同檔名的快取。
  event.respondWith(caches.open(CACHE).then(async cache => {
    const cached = await cache.match(event.request);
    if (cached) return cached;
    try {
      const response = await fetch(event.request);
      if (response.ok) cache.put(event.request, response.clone());
      return response;
    } catch {
      return (await cache.match(event.request, { ignoreSearch: true })) || Response.error();
    }
  }));
});
