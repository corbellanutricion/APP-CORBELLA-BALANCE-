-- Rescatado del material "Fuerza&Potencia" P1/P2 (mismo curso Apeks/Ehrenstein
-- que Levantamientos Olímpicos). Dos piezas:
--
-- 1) La gráfica de potencia relativa (P2 p.10) clasifica Peso muerto, Sentadilla
--    y Press de banca como "mucha fuerza, poca velocidad" -- el hueco real es
--    que ningún ejercicio fuera de los 84 de Clean/Snatch tenía
--    velocity_category, así que cualquier paciente de rendimiento que solo
--    hace levantamientos básicos (no oly lifts) no podía usar zonas de
--    velocidad. Se agrega SOLO a las versiones básicas/competitivas de cada
--    lift (no a las variantes de asistencia/hipertrofia), que es lo que la
--    fuente realmente clasifica.
-- 2) Ejercicios balísticos/pliométricos/de potencia mencionados en el material
--    que no existían en el catálogo (verificado contra el catálogo real antes
--    de insertar -- "Salto de Profundidad" y "Salto de Cuclillas" ya existían,
--    no se duplican).

update public.exercises set velocity_category = 'traccion' where id in ('e18', 'emqiefra1mf75'); -- Peso Muerto / Peso muerto tradicional
update public.exercises set velocity_category = 'inferior' where id = 'e1'; -- Sentadilla Libre
update public.exercises set velocity_category = 'empuje'   where id = 'e71'; -- Press de Banca Plano

insert into public.exercises (id, name, muscle_group, pillar, default_role, load, video_url, velocity_category)
select v.id, v.name, v.muscle_group, v.pillar, null, v.load, null, v.velocity_category
from (values
  ('e_fp1', 'Fondo de brazos con salto', 'Pecho', 'pliometria', 'moderada', null),
  ('e_fp2', 'Pase de pecho con medball', 'Pecho', 'balisticos', 'moderada', null),
  ('e_fp3', 'Lanzamiento de balón vertical', 'Core', 'balisticos', 'moderada', null),
  ('e_fp4', 'Lanzamiento de balón lateral', 'Core', 'balisticos', 'moderada', null),
  ('e_fp5', 'Trineo (empuje/arrastre)', 'Cuerpo completo', 'potencia', 'pesada', null),
  ('e_fp6', 'Split jerk', 'Cuerpo completo', 'potencia', 'moderada', 'inferior')
) as v(id, name, muscle_group, pillar, load, velocity_category)
where not exists (select 1 from exercises e where e.name = v.name);
