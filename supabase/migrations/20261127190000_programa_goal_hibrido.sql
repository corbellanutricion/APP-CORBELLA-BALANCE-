-- Nueva modalidad de programa "híbrido" (goal='hibrido'): el coach puede
-- mezclar días de hipertrofia y de preparación física dentro del MISMO
-- programa -- cada ejercicio ya guarda su propio pilar/grupo muscular
-- (program_exercises.pillar / .exercise_id→muscle_group), así que no hace
-- falta ningún cambio de esquema más allá de permitir este nuevo valor.
--
-- Por si 'goal' tuviera un check constraint fijo a ('hipertrofia',
-- 'rendimiento') -- se busca y elimina sin necesidad de saber su nombre
-- exacto de antemano. Si no existe ninguno (columna text libre), esto no
-- hace nada.
do $$
declare
  con record;
begin
  for con in
    select conname
    from pg_constraint
    where conrelid = 'public.programs'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%goal%'
  loop
    execute format('alter table public.programs drop constraint %I', con.conname);
  end loop;
end $$;
