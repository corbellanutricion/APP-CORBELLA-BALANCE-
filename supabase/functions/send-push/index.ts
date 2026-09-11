// Supabase Edge Function: send-push
//
// Recibe { user_id, title, body, url } y manda una notificación push a TODOS
// los dispositivos suscritos de ese usuario (push_subscriptions.user_id).
// La llama un Database Webhook cada vez que se inserta un mensaje nuevo o se
// actualiza/crea un plan de nutrición activo (ver 02_triggers.sql).
//
// Deploy:
//   supabase functions deploy send-push
//   supabase secrets set VAPID_PUBLIC_KEY=BKwMks... VAPID_PRIVATE_KEY=CmaAvK... VAPID_SUBJECT=mailto:tucorreo@ejemplo.com

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import webpush from 'https://esm.sh/web-push@3.6.7';

const VAPID_PUBLIC_KEY = Deno.env.get('VAPID_PUBLIC_KEY')!;
const VAPID_PRIVATE_KEY = Deno.env.get('VAPID_PRIVATE_KEY')!;
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') || 'mailto:soporte@corbellabalance.com';
const WEBHOOK_SECRET = Deno.env.get('WEBHOOK_SECRET')!; // secreto compartido con los triggers de la base de datos

webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')! // service_role -> se salta RLS, necesario para leer las suscripciones de cualquier usuario
);

Deno.serve(async (req) => {
  if (req.headers.get('x-webhook-secret') !== WEBHOOK_SECRET) {
    return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 401 });
  }
  try {
    const { user_id, title, body, url, tag } = await req.json();
    if (!user_id || !title) {
      return new Response(JSON.stringify({ error: 'Falta user_id o title' }), { status: 400 });
    }

    const { data: subs, error } = await supabase
      .from('push_subscriptions')
      .select('id, endpoint, p256dh, auth')
      .eq('user_id', user_id);

    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    if (!subs || subs.length === 0) {
      return new Response(JSON.stringify({ sent: 0, note: 'El usuario no tiene dispositivos suscritos.' }), { status: 200 });
    }

    const payload = JSON.stringify({ title, body: body || '', url: url || '/', tag: tag || undefined });

    const results = await Promise.allSettled(
      subs.map((sub) =>
        webpush.sendNotification(
          { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
          payload
        )
      )
    );

    // Si una suscripción ya no existe (el usuario desinstaló, borró permisos, etc.),
    // el navegador la reporta como 404/410 — la borramos para no seguir intentando en vano.
    const toDelete: string[] = [];
    results.forEach((r, i) => {
      if (r.status === 'rejected') {
        const statusCode = (r.reason && r.reason.statusCode) || null;
        if (statusCode === 404 || statusCode === 410) toDelete.push(subs[i].id);
      }
    });
    if (toDelete.length) {
      await supabase.from('push_subscriptions').delete().in('id', toDelete);
    }

    const sent = results.filter((r) => r.status === 'fulfilled').length;
    return new Response(JSON.stringify({ sent, total: subs.length, cleaned: toDelete.length }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});