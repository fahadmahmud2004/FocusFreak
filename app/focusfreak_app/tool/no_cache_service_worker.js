// Replaces Flutter's caching service worker in local web builds.
//
// The default one serves the last build from cache, so a browser that
// opened the app once keeps showing that build after every rebuild. This
// one clears every cache, unregisters itself and reloads open tabs, so the
// next load always comes from the server.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) await caches.delete(key);
    await self.registration.unregister();
    for (const client of await self.clients.matchAll({ type: 'window' })) {
      client.navigate(client.url);
    }
  })());
});
