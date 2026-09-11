-- Bitácora de errores de las Edge Functions, para avisarle al coach (push +
-- correo) apenas algo truena de verdad, en vez de enterarse porque un
-- paciente se queja. Ver supabase/functions/_shared/reportError.ts.

create table if not exists public.error_logs (
  id uuid primary key default gen_random_uuid(),
  source text not null,
  message text not null,
  context jsonb,
  created_at timestamptz not null default now()
);

alter table public.error_logs enable row level security;

-- Solo el coach puede leerla desde la app (las Edge Functions insertan con
-- la service_role key, que se salta RLS de todos modos).
drop policy if exists "coach reads error_logs" on public.error_logs;
create policy "coach reads error_logs" on public.error_logs
  for select
  using (auth.uid() = '29e3fed0-eb0d-4912-b6b2-9a9b6879d399');

create index if not exists error_logs_created_at_idx on public.error_logs (created_at desc);
