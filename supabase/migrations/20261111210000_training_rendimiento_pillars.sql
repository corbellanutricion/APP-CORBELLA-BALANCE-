-- Fase 1 del módulo de "Alto Rendimiento" (prep física integral).
--
-- Agrega una dimensión nueva, "pillar", ortogonal al muscle_group que ya existe
-- (que sigue siendo el eje de hipertrofia/volumen). Nada de esto cambia el
-- comportamiento de programas de hipertrofia existentes:
--   - goal se respalda a 'hipertrofia' para los programas ya activos
--   - pillar es metadata nueva, nullable salvo el backfill de abajo
--   - ninguna columna/constraint existente se toca
--
-- Pilares: movilidad, activacion, pliometria, balisticos, potencia, fuerza,
-- hipertrofia, accesorios, sistemas_energeticos, estiramientos.

-- 1) programs.goal ya existía (columna sin default/constraint, las 53 filas
--    actuales están en NULL). Se respaldan como 'hipertrofia' -- su
--    comportamiento real hasta hoy -- y se fija default + constraint.
update public.programs set goal = 'hipertrofia' where goal is null;

alter table public.programs
  alter column goal set default 'hipertrofia',
  alter column goal set not null;

alter table public.programs
  add constraint programs_goal_check
  check (goal in ('hipertrofia', 'rendimiento'));

-- 2) pilar en el catálogo de ejercicios.
alter table public.exercises
  add column if not exists pillar text;

alter table public.exercises
  add constraint exercises_pillar_check
  check (pillar is null or pillar in (
    'movilidad', 'activacion', 'pliometria', 'balisticos', 'potencia',
    'fuerza', 'hipertrofia', 'accesorios', 'sistemas_energeticos', 'estiramientos'
  ));

-- 3) mismo pilar copiado al ejercicio dentro de un día de programa (igual que
--    ya pasa con section/load). duration_min es para el registro simple de
--    sistemas energéticos ("20 min bici Z2" -- la descripción va en notes,
--    que ya existe).
alter table public.program_exercises
  add column if not exists pillar text,
  add column if not exists duration_min numeric;

alter table public.program_exercises
  add constraint program_exercises_pillar_check
  check (pillar is null or pillar in (
    'movilidad', 'activacion', 'pliometria', 'balisticos', 'potencia',
    'fuerza', 'hipertrofia', 'accesorios', 'sistemas_energeticos', 'estiramientos'
  ));

-- 4) backfill de pilar en los 314 ejercicios existentes a partir de su
--    muscle_group/load actuales -- heurística razonable confirmada con un
--    dry-run (173 hipertrofia / 36 activación / 30 fuerza / 20 movilidad /
--    19 pliometría / 16 estiramientos / 11 accesorios / 7 balísticos /
--    2 potencia). 100% editable después desde el catálogo del panel admin,
--    ejercicio por ejercicio, si el coach quiere afinar alguno.
update public.exercises set pillar = 'movilidad'     where pillar is null and muscle_group = 'Movilidad';
update public.exercises set pillar = 'estiramientos' where pillar is null and muscle_group = 'Estiramiento';
update public.exercises set pillar = 'pliometria'    where pillar is null and muscle_group = 'Pliometría';
update public.exercises set pillar = 'activacion'    where pillar is null and muscle_group = 'Balance';
update public.exercises set pillar = 'balisticos'    where pillar is null and muscle_group = 'Core'
  and (name ilike '%lanzamiento%' or name ilike '%balón%' or name ilike '%balon%' or name ilike '%pase de pecho%');
update public.exercises set pillar = 'activacion'    where pillar is null and muscle_group = 'Core';
update public.exercises set pillar = 'potencia'      where pillar is null and muscle_group = 'Cuerpo completo'
  and (name ilike '%arranque%' or name ilike '%trap bar%' or name ilike '%potenc%' or name ilike '%clean%' or name ilike '%snatch%');
update public.exercises set pillar = 'fuerza'        where pillar is null and (name ilike '%peso muerto%' or load = 'pesada');
update public.exercises set pillar = 'accesorios'    where pillar is null and muscle_group = 'Cuerpo completo';
update public.exercises set pillar = 'hipertrofia'   where pillar is null;

-- 5) sistemas_energeticos no tenía NINGÚN ejercicio en el catálogo (es puro
--    trabajo de fuerza/hipertrofia hoy) -- se agregan los básicos para que el
--    pilar no quede vacío en el selector del coach. Se pueden sumar más
--    después desde el catálogo, igual que cualquier otro ejercicio.
insert into public.exercises (id, name, muscle_group, pillar, load, video_url) values
  ('e_se1', 'Bicicleta estática (continuo)',   'Cuerpo completo', 'sistemas_energeticos', null, null),
  ('e_se2', 'Trote continuo',                  'Cuerpo completo', 'sistemas_energeticos', null, null),
  ('e_se3', 'Remo (máquina)',                  'Cuerpo completo', 'sistemas_energeticos', null, null),
  ('e_se4', 'Elíptica',                        'Cuerpo completo', 'sistemas_energeticos', null, null),
  ('e_se5', 'Circuito metabólico (intervalos)','Cuerpo completo', 'sistemas_energeticos', null, null),
  ('e_se6', 'Battle ropes (intervalos)',       'Cuerpo completo', 'sistemas_energeticos', null, null),
  ('e_se7', 'Sprint en banda / cancha',        'Cuerpo completo', 'sistemas_energeticos', null, null)
on conflict (id) do nothing;
