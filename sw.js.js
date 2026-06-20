// Corbella Balance — Service Worker
// Versión: incrementar este número al actualizar el HTML para limpiar caché
const CACHE_NAME = 'corbella-balance-v1';
const APP_SHELL = ['/APP-CORBELLA-BALANCE-/'];

// Instalación: guarda el HTML en caché
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

// Activación: limpia cachés viejas
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

// Fetch: red primero, caché como respaldo (para datos de Supabase siempre va a red)
self.addEventListener('fetch', event => {
  const url = event.request.url;
  // Supabase, Unpkg y APIs externas: siempre red (nunca caché)
  if (url.includes('supabase.co') || url.includes('unpkg.com') || url.includes('api.')) {
    event.respondWith(fetch(event.request));
    return;
  }
  // App shell: caché primero, red como respaldo
  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;
      return fetch(event.request).then(response => {
        if (response.ok && event.request.method === 'GET') {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
        }
        return response;
      });
    })
  );
});
