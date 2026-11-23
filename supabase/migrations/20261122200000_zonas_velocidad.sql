-- Zonas de entrenamiento por velocidad (VBT), del curso "Levantamientos
-- Olímpicos - un enfoque mecánico" (Jay Ehrenstein / Apeks Performance).
-- Números tomados literalmente del material, sin modificar.
--
-- total_volume es jsonb {"general":[min,tipico,max], "especifico":[...],
-- "rendimiento":[...]} -- rango de volumen total recomendado para UNA sesión
-- de esa zona+nivel (confirmado con el usuario: NO es progresión semanal).
--
-- rir_min = null significa "N/A" en el material (zona Velocidad: a cargas tan
-- bajas el RIR no es un proxy útil, es una limitación real del dato fuente).

create table if not exists public.velocity_zones (
  id text primary key,
  name text not null,
  sort int not null,
  objective text not null,
  vmp_push_min numeric, vmp_push_max numeric,
  vmp_lower_min numeric, vmp_lower_max numeric,
  vmp_pull_min numeric, vmp_pull_max numeric,
  load_pct_min numeric, load_pct_max numeric,
  reps_min int, reps_max int,
  vloss_general_min numeric, vloss_general_max numeric,
  vloss_specific_min numeric, vloss_specific_max numeric,
  vloss_performance_min numeric, vloss_performance_max numeric,
  rir_min int,
  total_volume jsonb not null,
  training_means text not null
);

insert into public.velocity_zones (
  id, name, sort, objective,
  vmp_push_min, vmp_push_max, vmp_lower_min, vmp_lower_max, vmp_pull_min, vmp_pull_max,
  load_pct_min, load_pct_max, reps_min, reps_max,
  vloss_general_min, vloss_general_max, vloss_specific_min, vloss_specific_max,
  vloss_performance_min, vloss_performance_max, rir_min, total_volume, training_means
) values
('velocidad', 'Velocidad', 1,
 'Incremento máximo de la tasa de producción de fuerza, velocidad de ejecución y capacidad de utilización del ciclo estiramiento-acortamiento',
 1.1, null, 1.3, null, 1.5, null,
 null, 20, 5, 10,
 10, 15, 7.5, 12.5, 5, 10,
 null,
 '{"general": [40,45,50], "especifico": [35,40,45], "rendimiento": [30,35,40]}'::jsonb,
 'Semibalísticos (excluyendo el clean*) y balísticos con cargas reducidas; incluyendo y enfatizando medios sin carga externa o mínima'),
('potencia_velocidad', 'Potencia-Velocidad', 2,
 'Incremento de la tasa de producción de fuerza y potencia ante cargas externas ligeras; sesgando la velocidad de ejecución frente a la expresión de la fuerza',
 0.95, 1.1, 1, 1.3, 1.25, 1.5,
 20, 40, 4, 6,
 15, 20, 10, 15, 5, 10,
 6,
 '{"general": [35,40,45], "especifico": [30,35,40], "rendimiento": [25,30,35]}'::jsonb,
 'Semibalísticos y balísticos con cargas reducidas, incluyendo el clean y el snatch'),
('potencia', 'Potencia', 3,
 'Incremento de la tasa de producción de fuerza y potencia ante cargas externas moderadas; sesgando la expresión de la fuerza frente a la velocidad de ejecución',
 0.65, 0.95, 0.75, 1, 0.95, 1.25,
 40, 60, 3, 5,
 20, 25, 15, 20, 10, 15,
 4,
 '{"general": [30,35,40], "especifico": [25,30,35], "rendimiento": [20,25,30]}'::jsonb,
 'Medios compuestos en ambientes estables que facilitan la máxima expresión de la fuerza contráctil, con resistencia variable; así como semibalísticos (excluyendo el snatch*) y balísticos con cargas moderadas')
on conflict (id) do nothing;

-- Categoría de movimiento por ejercicio, para saber qué columna VMP mostrar.
alter table public.exercises
  add column if not exists velocity_category text;

alter table public.exercises
  add constraint exercises_velocity_category_check
  check (velocity_category is null or velocity_category in ('empuje', 'inferior', 'traccion'));

-- Backfill de los 84 oly lifts: jalón/muscle (sin recepción con piernas) =
-- tracción; power/potencia+sentadilla/completo (sí reciben con piernas) =
-- inferior. Usa progression_step, agregado en la migración anterior.
update public.exercises
  set velocity_category = 'traccion'
  where (id like 'eclean%' or id like 'esnatch%') and progression_step in (1, 2, 3);

update public.exercises
  set velocity_category = 'inferior'
  where (id like 'eclean%' or id like 'esnatch%') and progression_step in (4, 5, 6);

-- Zona de velocidad asignable por ejercicio dentro de un programa.
alter table public.program_exercises
  add column if not exists velocity_zone text references public.velocity_zones(id),
  add column if not exists zone_level text;

alter table public.program_exercises
  add constraint program_exercises_zone_level_check
  check (zone_level is null or zone_level in ('general', 'especifico', 'rendimiento'));

-- Velocidad medida de la serie (opcional -- no todos los atletas tienen con
-- qué medirla; nullable a propósito, no bloquea el registro normal).
alter table public.set_logs
  add column if not exists velocity_ms numeric;
