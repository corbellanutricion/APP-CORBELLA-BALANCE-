-- Nunca existió esta tabla en producción -- por eso las notificaciones push
-- nunca funcionaron (ni para el coach ni para los pacientes) a pesar de que
-- todo el código del lado de la app (PushBell, enablePushNotifications,
-- send-push, cb_call_send_push) ya estaba listo desde antes. Encontrado el
-- 2026-09-11 al intentar activar las notificaciones y recibir
-- "Could not find the table 'public.push_subscriptions' in the schema cache".

create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now()
);

create index if not exists push_subscriptions_user_id_idx
  on public.push_subscriptions (user_id);

alter table public.push_subscriptions enable row level security;

-- Cada quien administra (inserta/actualiza vía upsert/borra) solo su propia
-- suscripción -- el endpoint es único por dispositivo/navegador, así que un
-- mismo usuario puede tener varias filas (celular, compu, etc.).
drop policy if exists "users manage their own push subscription" on public.push_subscriptions;
create policy "users manage their own push subscription" on public.push_subscriptions
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
