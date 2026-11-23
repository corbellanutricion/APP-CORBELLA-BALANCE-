-- Progresiones/regresiones de Clean y Snatch (marco mecánico de Jay Ehrenstein
-- / Apeks Performance: "Levantamientos Olímpicos - un enfoque mecánico").
-- 7 posiciones x 6 ejercicios x 2 levantamientos = 84 ejercicios, pensados
-- para que el coach pueda prescribir una variante acorde al nivel técnico
-- del atleta en vez de mandar siempre el levantamiento completo.
--
-- progression_level (1-7): posición/iniciación, de menos a más exigente
--   1 colgado alto, 2 colgado sobre la rodilla, 3 bloques a la altura de la
--   rodilla, 4 colgado bajo la rodilla, 5 pausa bajo la rodilla, 6 desde el
--   suelo, 7 déficit.
-- progression_step (1-6): tipo de ejercicio dentro de esa posición, de menos
--   a más completo -- 1 jalón brazos extendidos, 2 jalón brazos flexionados,
--   3 cargada/arranque de fuerza, 4 cargada/arranque de potencia,
--   5 cargada/arranque de potencia + sentadilla, 6 levantamiento completo.
-- El nombre ("Clean X.Y" / "Snatch X.Y") ya codifica lo mismo en texto; estas
-- columnas son para poder filtrar/ordenar por nivel sin parsear el nombre.

alter table public.exercises
  add column if not exists progression_level smallint,
  add column if not exists progression_step smallint;

alter table public.exercises
  add constraint exercises_progression_level_check
  check (progression_level is null or progression_level between 1 and 7);

alter table public.exercises
  add constraint exercises_progression_step_check
  check (progression_step is null or progression_step between 1 and 6);

insert into public.exercises (id, name, muscle_group, pillar, default_role, load, video_url, progression_level, progression_step)
select v.id, v.name, 'Cuerpo completo', 'potencia', null, v.load, null, v.level, v.step
from (values
  ('eclean11', 'Clean 1.1 · Jalón de cargada brazos extendidos (colgado alto)', 'pesada', 1, 1),
  ('eclean12', 'Clean 1.2 · Jalón de cargada brazos flexionados (colgado alto)', 'pesada', 1, 2),
  ('eclean13', 'Clean 1.3 · Cargada de fuerza (colgado alto)', 'moderada', 1, 3),
  ('eclean14', 'Clean 1.4 · Cargada de potencia (colgado alto)', 'moderada', 1, 4),
  ('eclean15', 'Clean 1.5 · Cargada de potencia + sentadilla frontal (colgado alto)', 'moderada', 1, 5),
  ('eclean16', 'Clean 1.6 · Cargada completa (colgado alto)', 'moderada', 1, 6),
  ('eclean21', 'Clean 2.1 · Jalón de cargada brazos extendidos (colgado sobre la rodilla)', 'pesada', 2, 1),
  ('eclean22', 'Clean 2.2 · Jalón de cargada brazos flexionados (colgado sobre la rodilla)', 'pesada', 2, 2),
  ('eclean23', 'Clean 2.3 · Cargada de fuerza (colgado sobre la rodilla)', 'moderada', 2, 3),
  ('eclean24', 'Clean 2.4 · Cargada de potencia (colgado sobre la rodilla)', 'moderada', 2, 4),
  ('eclean25', 'Clean 2.5 · Cargada de potencia + sentadilla frontal (colgado sobre la rodilla)', 'moderada', 2, 5),
  ('eclean26', 'Clean 2.6 · Cargada completa (colgado sobre la rodilla)', 'moderada', 2, 6),
  ('eclean31', 'Clean 3.1 · Jalón de cargada brazos extendidos (desde bloques a la altura de la rodilla)', 'pesada', 3, 1),
  ('eclean32', 'Clean 3.2 · Jalón de cargada brazos flexionados (desde bloques a la altura de la rodilla)', 'pesada', 3, 2),
  ('eclean33', 'Clean 3.3 · Cargada de fuerza (desde bloques a la altura de la rodilla)', 'moderada', 3, 3),
  ('eclean34', 'Clean 3.4 · Cargada de potencia (desde bloques a la altura de la rodilla)', 'moderada', 3, 4),
  ('eclean35', 'Clean 3.5 · Cargada de potencia + sentadilla frontal (desde bloques a la altura de la rodilla)', 'moderada', 3, 5),
  ('eclean36', 'Clean 3.6 · Cargada completa (desde bloques a la altura de la rodilla)', 'moderada', 3, 6),
  ('eclean41', 'Clean 4.1 · Jalón de cargada brazos extendidos (colgado bajo la rodilla)', 'pesada', 4, 1),
  ('eclean42', 'Clean 4.2 · Jalón de cargada brazos flexionados (colgado bajo la rodilla)', 'pesada', 4, 2),
  ('eclean43', 'Clean 4.3 · Cargada de fuerza (colgado bajo la rodilla)', 'moderada', 4, 3),
  ('eclean44', 'Clean 4.4 · Cargada de potencia (colgado bajo la rodilla)', 'moderada', 4, 4),
  ('eclean45', 'Clean 4.5 · Cargada de potencia + sentadilla frontal (colgado bajo la rodilla)', 'moderada', 4, 5),
  ('eclean46', 'Clean 4.6 · Cargada completa (colgado bajo la rodilla)', 'moderada', 4, 6),
  ('eclean51', 'Clean 5.1 · Jalón de cargada brazos extendidos (con pausa bajo la rodilla)', 'pesada', 5, 1),
  ('eclean52', 'Clean 5.2 · Jalón de cargada brazos flexionados (con pausa bajo la rodilla)', 'pesada', 5, 2),
  ('eclean53', 'Clean 5.3 · Cargada de fuerza (con pausa bajo la rodilla)', 'moderada', 5, 3),
  ('eclean54', 'Clean 5.4 · Cargada de potencia (con pausa bajo la rodilla)', 'moderada', 5, 4),
  ('eclean55', 'Clean 5.5 · Cargada de potencia + sentadilla frontal (con pausa bajo la rodilla)', 'moderada', 5, 5),
  ('eclean56', 'Clean 5.6 · Cargada completa (con pausa bajo la rodilla)', 'moderada', 5, 6),
  ('eclean61', 'Clean 6.1 · Jalón de cargada brazos extendidos (desde el suelo)', 'pesada', 6, 1),
  ('eclean62', 'Clean 6.2 · Jalón de cargada brazos flexionados (desde el suelo)', 'pesada', 6, 2),
  ('eclean63', 'Clean 6.3 · Cargada de fuerza (desde el suelo)', 'moderada', 6, 3),
  ('eclean64', 'Clean 6.4 · Cargada de potencia (desde el suelo)', 'moderada', 6, 4),
  ('eclean65', 'Clean 6.5 · Cargada de potencia + sentadilla frontal (desde el suelo)', 'moderada', 6, 5),
  ('eclean66', 'Clean 6.6 · Cargada completa (desde el suelo)', 'moderada', 6, 6),
  ('eclean71', 'Clean 7.1 · Jalón de cargada brazos extendidos (en déficit)', 'pesada', 7, 1),
  ('eclean72', 'Clean 7.2 · Jalón de cargada brazos flexionados (en déficit)', 'pesada', 7, 2),
  ('eclean73', 'Clean 7.3 · Cargada de fuerza (en déficit)', 'moderada', 7, 3),
  ('eclean74', 'Clean 7.4 · Cargada de potencia (en déficit)', 'moderada', 7, 4),
  ('eclean75', 'Clean 7.5 · Cargada de potencia + sentadilla frontal (en déficit)', 'moderada', 7, 5),
  ('eclean76', 'Clean 7.6 · Cargada completa (en déficit)', 'moderada', 7, 6),
  ('esnatch11', 'Snatch 1.1 · Jalón de arranque brazos extendidos (colgado alto)', 'pesada', 1, 1),
  ('esnatch12', 'Snatch 1.2 · Jalón de arranque brazos flexionados (colgado alto)', 'pesada', 1, 2),
  ('esnatch13', 'Snatch 1.3 · Arranque de fuerza (colgado alto)', 'moderada', 1, 3),
  ('esnatch14', 'Snatch 1.4 · Arranque de potencia (colgado alto)', 'moderada', 1, 4),
  ('esnatch15', 'Snatch 1.5 · Arranque de potencia + sentadilla overhead (colgado alto)', 'moderada', 1, 5),
  ('esnatch16', 'Snatch 1.6 · Arranque completo (colgado alto)', 'moderada', 1, 6),
  ('esnatch21', 'Snatch 2.1 · Jalón de arranque brazos extendidos (colgado sobre la rodilla)', 'pesada', 2, 1),
  ('esnatch22', 'Snatch 2.2 · Jalón de arranque brazos flexionados (colgado sobre la rodilla)', 'pesada', 2, 2),
  ('esnatch23', 'Snatch 2.3 · Arranque de fuerza (colgado sobre la rodilla)', 'moderada', 2, 3),
  ('esnatch24', 'Snatch 2.4 · Arranque de potencia (colgado sobre la rodilla)', 'moderada', 2, 4),
  ('esnatch25', 'Snatch 2.5 · Arranque de potencia + sentadilla overhead (colgado sobre la rodilla)', 'moderada', 2, 5),
  ('esnatch26', 'Snatch 2.6 · Arranque completo (colgado sobre la rodilla)', 'moderada', 2, 6),
  ('esnatch31', 'Snatch 3.1 · Jalón de arranque brazos extendidos (desde bloques a la altura de la rodilla)', 'pesada', 3, 1),
  ('esnatch32', 'Snatch 3.2 · Jalón de arranque brazos flexionados (desde bloques a la altura de la rodilla)', 'pesada', 3, 2),
  ('esnatch33', 'Snatch 3.3 · Arranque de fuerza (desde bloques a la altura de la rodilla)', 'moderada', 3, 3),
  ('esnatch34', 'Snatch 3.4 · Arranque de potencia (desde bloques a la altura de la rodilla)', 'moderada', 3, 4),
  ('esnatch35', 'Snatch 3.5 · Arranque de potencia + sentadilla overhead (desde bloques a la altura de la rodilla)', 'moderada', 3, 5),
  ('esnatch36', 'Snatch 3.6 · Arranque completo (desde bloques a la altura de la rodilla)', 'moderada', 3, 6),
  ('esnatch41', 'Snatch 4.1 · Jalón de arranque brazos extendidos (colgado bajo la rodilla)', 'pesada', 4, 1),
  ('esnatch42', 'Snatch 4.2 · Jalón de arranque brazos flexionados (colgado bajo la rodilla)', 'pesada', 4, 2),
  ('esnatch43', 'Snatch 4.3 · Arranque de fuerza (colgado bajo la rodilla)', 'moderada', 4, 3),
  ('esnatch44', 'Snatch 4.4 · Arranque de potencia (colgado bajo la rodilla)', 'moderada', 4, 4),
  ('esnatch45', 'Snatch 4.5 · Arranque de potencia + sentadilla overhead (colgado bajo la rodilla)', 'moderada', 4, 5),
  ('esnatch46', 'Snatch 4.6 · Arranque completo (colgado bajo la rodilla)', 'moderada', 4, 6),
  ('esnatch51', 'Snatch 5.1 · Jalón de arranque brazos extendidos (con pausa bajo la rodilla)', 'pesada', 5, 1),
  ('esnatch52', 'Snatch 5.2 · Jalón de arranque brazos flexionados (con pausa bajo la rodilla)', 'pesada', 5, 2),
  ('esnatch53', 'Snatch 5.3 · Arranque de fuerza (con pausa bajo la rodilla)', 'moderada', 5, 3),
  ('esnatch54', 'Snatch 5.4 · Arranque de potencia (con pausa bajo la rodilla)', 'moderada', 5, 4),
  ('esnatch55', 'Snatch 5.5 · Arranque de potencia + sentadilla overhead (con pausa bajo la rodilla)', 'moderada', 5, 5),
  ('esnatch56', 'Snatch 5.6 · Arranque completo (con pausa bajo la rodilla)', 'moderada', 5, 6),
  ('esnatch61', 'Snatch 6.1 · Jalón de arranque brazos extendidos (desde el suelo)', 'pesada', 6, 1),
  ('esnatch62', 'Snatch 6.2 · Jalón de arranque brazos flexionados (desde el suelo)', 'pesada', 6, 2),
  ('esnatch63', 'Snatch 6.3 · Arranque de fuerza (desde el suelo)', 'moderada', 6, 3),
  ('esnatch64', 'Snatch 6.4 · Arranque de potencia (desde el suelo)', 'moderada', 6, 4),
  ('esnatch65', 'Snatch 6.5 · Arranque de potencia + sentadilla overhead (desde el suelo)', 'moderada', 6, 5),
  ('esnatch66', 'Snatch 6.6 · Arranque completo (desde el suelo)', 'moderada', 6, 6),
  ('esnatch71', 'Snatch 7.1 · Jalón de arranque brazos extendidos (en déficit)', 'pesada', 7, 1),
  ('esnatch72', 'Snatch 7.2 · Jalón de arranque brazos flexionados (en déficit)', 'pesada', 7, 2),
  ('esnatch73', 'Snatch 7.3 · Arranque de fuerza (en déficit)', 'moderada', 7, 3),
  ('esnatch74', 'Snatch 7.4 · Arranque de potencia (en déficit)', 'moderada', 7, 4),
  ('esnatch75', 'Snatch 7.5 · Arranque de potencia + sentadilla overhead (en déficit)', 'moderada', 7, 5),
  ('esnatch76', 'Snatch 7.6 · Arranque completo (en déficit)', 'moderada', 7, 6)
) as v(id, name, load, level, step)
where not exists (select 1 from exercises e where e.name = v.name);
