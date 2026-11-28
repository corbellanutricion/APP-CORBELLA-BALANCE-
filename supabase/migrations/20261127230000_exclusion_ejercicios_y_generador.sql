-- Lista de ejercicios excluidos por paciente (lesiones, equipo no
-- disponible, o simplemente que no le gustan) -- la usa el nuevo botón
-- "Generar programa" en Dosificación para no auto-asignar algo
-- contraindicado. El catálogo de ejercicios (public.exercises) usa IDs de
-- texto (ver CBS._newId), no uuid, por eso el arreglo es de texto.
alter table public.patients
  add column if not exists excluded_exercise_ids text[] not null default '{}';
