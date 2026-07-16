/* Corbella Balance · Service Worker
   Estrategia: network-first con timeout corto.
   - Con buena señal: siempre baja la versión más reciente (las actualizaciones de Azael llegan igual que hoy).
   - Con mala señal o sin red: abre al instante desde el caché en vez de ERR_TIMED_OUT. */
const CACHE = 'cb-cache-v1';
const APP = './index.html';

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then(c => c.add(APP)).catch(() => {}));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))));
  self.clients.claim();
});

function networkFirst(req, timeoutMs) {
  return new Promise((resolve) => {
    let done = false;
    const timer = setTimeout(async () => {
      if (done) return;
      const cached = await caches.match(APP);
      if (cached) { done = true; resolve(cached); }
    }, timeoutMs);
    fetch(req).then(async (res) => {
      clearTimeout(timer);
      if (res && res.ok) {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(APP, copy)).catch(() => {});
        if (!done) { done = true; resolve(res); }
      } else if (!done) {
        const cached = await caches.match(APP);
        done = true; resolve(cached || res);
      }
    }).catch(async () => {
      clearTimeout(timer);
      if (!done) {
        const cached = await caches.match(APP);
        done = true; resolve(cached || Response.error());
      }
    });
  });
}

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  // Solo interceptar la carga de la propia app (navegación / index.html).
  // Supabase, fotos y todo lo demás pasa directo, sin tocar.
  if (e.request.mode === 'navigate' || url.pathname.endsWith('/index.html') || url.pathname.endsWith('/APP-CORBELLA-BALANCE-/')) {
    e.respondWith(networkFirst(e.request, 4000));
  }
});
