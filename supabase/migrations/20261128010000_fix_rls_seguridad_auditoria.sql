-- Hallazgos de la auditoría de seguridad (2026-11-28):

-- 1) CRÍTICO: el flujo de "paciente llena su expediente" (coached signup,
-- construido hoy) estaba roto a nivel de base de datos. La única política
-- de INSERT en patients para auto-registro solo permitía
-- account_mode='self_managed' -- un paciente 'coached' nunca podía crear su
-- propia fila (RLS lo rechazaba con un error de permisos, en silencio para
-- el paciente). Se amplía para aceptar ambos modos de autoservicio.
drop policy if exists "patients_self_signup" on public.patients;
create policy "patients_self_signup"
on public.patients for insert
to public
with check (id = auth.uid() and account_mode in ('self_managed', 'coached'));

-- 2) La política de UPDATE agregada hoy para "marcar expediente llenado" no
-- restringía columnas -- en RLS (a nivel de FILA, no de columna) un
-- paciente con esa política podría, en teoría, actualizar CUALQUIER columna
-- de su propia fila (coach_id, approval_status, excluded_exercise_ids,
-- modality...), no solo clinical_record_submitted_at. Se reemplaza por una
-- función que SOLO toca esa columna.
drop policy if exists "patients: el paciente marca su propio expediente como llenado" on public.patients;

create or replace function public.mark_expediente_submitted()
returns void
language sql
security definer
set search_path = public
as $$
  update public.patients set clinical_record_submitted_at = now() where id = auth.uid();
$$;
grant execute on function public.mark_expediente_submitted() to authenticated;

-- 3) velocity_zones (catálogo de zonas de velocidad VBT) no tenía RLS
-- activado -- cualquiera con la llave pública (visible en el código del
-- navegador, sin necesidad de iniciar sesión) podía leer Y ESCRIBIR esta
-- tabla libremente. Se iguala al patrón de los demás catálogos (exercises,
-- foods, muscle_groups): lectura para cualquier usuario autenticado,
-- escritura solo para el coach.
alter table public.velocity_zones enable row level security;
create policy "p_vz_read" on public.velocity_zones for select to public using (auth.uid() is not null);
create policy "p_vz_write" on public.velocity_zones for all to public using (is_coach()) with check (is_coach());
