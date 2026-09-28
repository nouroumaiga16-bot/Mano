// Service worker de Mano : garde l'application en mémoire sur le téléphone
// pour qu'elle s'ouvre même sans Internet.
//
// Stratégie : on répond tout de suite avec la copie en mémoire, puis on
// télécharge la nouvelle version en arrière-plan quand Internet est là.
// La mise à jour est donc visible à l'ouverture suivante.
//
// PRECACHE et CACHE_VERSION sont remplis par tool/build_web.sh.
const CACHE_VERSION = '__CACHE_VERSION__';
const PRECACHE = __PRECACHE__;
const CACHE = `mano-${CACHE_VERSION}`;

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(PRECACHE)).then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) {
        if (key.startsWith('mano-') && key !== CACHE) await caches.delete(key);
      }
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (!url.protocol.startsWith('http')) return;

  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE);
      // Les pages (navigation) retombent sur index.html.
      const key = request.mode === 'navigate' ? 'index.html' : request;
      const cached = await cache.match(key, { ignoreSearch: true });
      const network = fetch(request)
        .then((response) => {
          if (response.ok || response.type === 'opaque') {
            cache.put(key, response.clone());
          }
          return response;
        })
        .catch(() => undefined);
      if (cached) {
        event.waitUntil(network);
        return cached;
      }
      return (await network) ?? Response.error();
    })(),
  );
});
