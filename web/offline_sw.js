// Service worker de Mano : garde l'application en mémoire sur le téléphone
// pour qu'elle s'ouvre même sans Internet.
//
// Stratégie : voir plus bas (Internet d'abord pour le code de l'app,
// copie en mémoire d'abord pour le reste).
//
// PRECACHE et CACHE_VERSION sont remplis par tool/build_web.sh.
const CACHE_VERSION = '__CACHE_VERSION__';
const PRECACHE = __PRECACHE__;
const CACHE = `mano-${CACHE_VERSION}`;

self.addEventListener('install', (event) => {
  // Chaque fichier séparément : une connexion qui coupe au milieu ne bloque
  // pas la nouvelle version (les fichiers manquants viendront plus tard).
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => Promise.allSettled(PRECACHE.map((file) => cache.add(file))))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const current = await caches.open(CACHE);
      let replacedOldVersion = false;
      for (const key of await caches.keys()) {
        if (!key.startsWith('mano-') || key === CACHE) continue;
        replacedOldVersion = true;
        // Reprend de l'ancienne copie ce qui n'a pas pu être téléchargé.
        const old = await caches.open(key);
        for (const request of await old.keys()) {
          if (!(await current.match(request))) {
            await current.put(request, await old.match(request));
          }
        }
        await caches.delete(key);
      }
      await self.clients.claim();
      // Recharge l'app ouverte pour passer tout de suite à la nouvelle
      // version (une seule fois, à l'arrivée de la version).
      if (!replacedOldVersion) return;
      for (const client of await self.clients.matchAll({ type: 'window' })) {
        if ('navigate' in client) client.navigate(client.url).catch(() => {});
      }
    })(),
  );
});

// Fichiers qui changent à chaque version : on essaie d'abord Internet
// (5 secondes maximum), sinon la copie en mémoire. Ainsi une mise à jour
// arrive dès la première ouverture avec Internet.
const NETWORK_FIRST = [
  /\/$/,
  /index\.html$/,
  /flutter_bootstrap\.js$/,
  /main\.dart\.js$/,
  /manifest\.json$/,
  /version\.json$/,
];

function fromNetwork(request, cache, key) {
  return fetch(request, { cache: 'no-cache' }).then((response) => {
    if (response.ok || response.type === 'opaque') {
      cache.put(key, response.clone());
    }
    return response;
  });
}

function timeout(ms) {
  return new Promise((_, reject) => setTimeout(() => reject(new Error('lent')), ms));
}

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

      const networkFirst =
        request.mode === 'navigate' ||
        (url.origin === self.location.origin &&
          NETWORK_FIRST.some((pattern) => pattern.test(url.pathname)));
      if (networkFirst) {
        try {
          return await Promise.race([fromNetwork(request, cache, key), timeout(5000)]);
        } catch (_) {
          if (cached) return cached;
          return (await fromNetwork(request, cache, key).catch(() => undefined)) ??
            Response.error();
        }
      }

      // Autres fichiers (moteur, polices, images) : la copie en mémoire tout
      // de suite, mise à jour en arrière-plan.
      const network = fromNetwork(request, cache, key).catch(() => undefined);
      if (cached) {
        event.waitUntil(network);
        return cached;
      }
      return (await network) ?? Response.error();
    })(),
  );
});
