-- Registro de cada intento de análisis de foto (no solo las que se guardan
-- como comida) -- sirve nada más para poder contar cuántas lleva cada
-- paciente hoy y frenarlo en 5, ver supabase/functions/analyze-food-photo.

create table if not exists public.food_photo_analyses (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists food_photo_analyses_patient_day_idx
  on public.food_photo_analyses (patient_id, created_at);

alter table public.food_photo_analyses enable row level security;

-- Solo el coach la puede leer desde la app -- la Edge Function usa la
-- service_role key para leer/escribir, que se salta RLS de todos modos.
drop policy if exists "coach reads food_photo_analyses" on public.food_photo_analyses;
create policy "coach reads food_photo_analyses" on public.food_photo_analyses
  for select
  using (auth.uid() = '29e3fed0-eb0d-4912-b6b2-9a9b6879d399');
