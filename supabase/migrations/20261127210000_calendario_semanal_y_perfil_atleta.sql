-- Calendario semanal (lunes-domingo) para distribuir sesiones de
-- preparación física vs sesiones de deporte (combate), y perfil físico
-- del atleta (fuerza/velocidad/potencia/resistencia/reactividad/pegada)
-- para los arquetipos que el coach ya reconoce en consulta (ej. "fuerte
-- pero lento", "explosivo pero se cansa").

alter table public.program_days
  add column if not exists day_of_week smallint, -- 1=lunes .. 7=domingo, null = sin asignar
  add column if not exists session_type text; -- 'preparacion_fisica' | 'deporte', null = sin asignar

create table if not exists public.athlete_profiles (
  patient_id uuid primary key references public.patients(id) on delete cascade,
  coach_id uuid not null,
  fuerza smallint,
  velocidad smallint,
  potencia smallint,
  resistencia smallint,
  reactividad smallint,
  pegada smallint,
  notes text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.athlete_profiles enable row level security;

create policy "athlete_profiles: el coach administra el perfil de sus pacientes"
on public.athlete_profiles for all
to authenticated
using (coach_id = auth.uid())
with check (coach_id = auth.uid());
