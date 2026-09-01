// Service Worker de Corbella Balance.
// Hace dos cosas: (1) maneja las notificaciones push, y (2) guarda una copia de la app
// en el propio teléfono para que ABRA rápido y funcione aunque no haya señal.
//
// Estrategia: "primero lo guardado" -- SIEMPRE abre al instante con la copia que ya
// tiene guardada (sin esperar nada de la red), y de paso, en segundo plano, baja la
// versión más reciente para la PRÓXIMA vez que se abra. Esto significa que, justo
// después de subir un cambio nuevo, la primera apertura de cada persona puede mostrar
// la versión de "hace un momento" en vez de la última al segundo -- pero a cambio,
// abrir la app siempre es instantáneo, sin importar qué tan grande crezca el archivo
// ni qué tan buena o mala sea la señal en ese momento.
const CACHE_NAME = 'corbella-balance';
const PRECACHE_URLS = ['./', './index.html', './supabase.js', './manifest.json', './corbella-icon-192.png', './corbella-icon-512.png'];

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

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return; // los guardados (POST a Supabase) siguen su curso normal, no se tocan aquí
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return; // llamadas a Supabase van directo a la red, tal cual

  event.respondWith(
    caches.match(req, { ignoreSearch: true }).then(cached => {
      // En paralelo, siempre intentamos traer la versión más reciente y la guardamos
      // para la próxima -- pero esto NUNCA detiene la respuesta si ya hay algo guardado.
      const networkUpdate = fetch(req).then(resp => {
        if (resp && resp.ok) caches.open(CACHE_NAME).then(cache => cache.put(req, resp.clone()));
        return resp;
      }).catch(() => null);

      // Si ya hay copia guardada, respondemos con ella AL INSTANTE, sin esperar a la red.
      // Si no hay nada guardado todavía (primerísima vez), ahí sí esperamos la red.
      return cached || networkUpdate;
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
