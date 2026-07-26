// Service Worker de Corbella Balance.
// Hace dos cosas: (1) maneja las notificaciones push, y (2) guarda una copia de la app
// en el propio teléfono para que ABRA aunque el paciente no tenga señal en ese momento
// (útil en el gym, con datos móviles limitados, etc.).
//
// No hace falta tocar este archivo cuando subas una versión nueva de index.html: cada
// vez que el teléfono SÍ tiene señal, trae la versión más reciente sola (ver estrategia
// abajo) y actualiza lo guardado. Solo usa la copia vieja cuando la red tarda demasiado
// o no hay señal en absoluto.
const CACHE_NAME = 'corbella-balance';
const PRECACHE_URLS = ['./', './index.html', './supabase.js'];
const NETWORK_TIMEOUT_MS = 2500; // si la red tarda más que esto, usamos lo guardado mientras tanto

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(PRECACHE_URLS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Estrategia "carrera con límite de tiempo": intenta traer la versión más reciente de
// internet; si responde antes de NETWORK_TIMEOUT_MS, usa esa (y de paso la guarda para
// la próxima). Si tarda más que eso (señal mala) o falla (sin señal), usa al instante lo
// que ya estaba guardado — así el paciente nunca se queda esperando mucho tiempo.
self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return; // los guardados (POST a Supabase) siguen su curso normal, no se tocan aquí
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return; // llamadas a Supabase van directo a la red, tal cual

  event.respondWith(
    new Promise(resolve => {
      let done = false;
      const useCache = () => caches.match(req, { ignoreSearch: true }).then(cached => {
        if (done) return;
        done = true;
        resolve(cached || new Response('Sin conexión y sin copia guardada todavía.', { status: 503, statusText: 'Offline' }));
      });
      const fallbackTimer = setTimeout(useCache, NETWORK_TIMEOUT_MS);

      fetch(req).then(resp => {
        clearTimeout(fallbackTimer);
        if (resp && resp.ok) caches.open(CACHE_NAME).then(cache => cache.put(req, resp.clone()));
        if (!done) { done = true; resolve(resp); }
      }).catch(() => {
        clearTimeout(fallbackTimer);
        useCache();
      });
    })
  );
});

self.addEventListener('push', event => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = { title: 'Corbella Balance', body: event.data ? event.data.text() : '' };
  }

  const title = data.title || 'Corbella Balance';
  const options = {
    body: data.body || '',
    icon: data.icon || '/icon-192.png',
    badge: data.badge || '/icon-192.png',
    data: { url: data.url || '/' },
    tag: data.tag || undefined, // mismo tag = agrupa/reemplaza notificaciones repetidas (ej. varios mensajes seguidos)
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// Al hacer clic en la notificación: si ya hay una pestaña abierta de la app, la enfoca;
// si no, abre una nueva en la URL indicada (ej. directo al chat o al plan actualizado).
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const targetUrl = (event.notification.data && event.notification.data.url) || '/';

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clientList => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
    })
  );
});
