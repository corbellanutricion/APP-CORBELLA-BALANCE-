-- El usuario pidió que Core y Balance aparezcan como PILARES propios (no
-- solo como grupo muscular) -- hoy los dos viven agazapados dentro del
-- pilar genérico 'activacion'. Se agregan 'core' y 'balance' al vocabulario
-- de pilares; 'activacion' se queda para lo que NO es core ni balance
-- (escapular, glúteo -- ej. "Retracciones escapulares", "Puente de
-- cadera", "Abducción lateral").

alter table public.exercises drop constraint if exists exercises_pillar_check;
alter table public.exercises
  add constraint exercises_pillar_check
  check (pillar is null or pillar in (
    'movilidad', 'activacion', 'core', 'balance', 'pliometria', 'balisticos',
    'potencia', 'fuerza', 'accesorios', 'hipertrofia', 'sistemas_energeticos', 'estiramientos'
  ));

alter table public.program_exercises drop constraint if exists program_exercises_pillar_check;
alter table public.program_exercises
  add constraint program_exercises_pillar_check
  check (pillar is null or pillar in (
    'movilidad', 'activacion', 'core', 'balance', 'pliometria', 'balisticos',
    'potencia', 'fuerza', 'accesorios', 'hipertrofia', 'sistemas_energeticos', 'estiramientos'
  ));

-- reclasificación: todo lo que hoy es 'activacion' y su grupo muscular
-- empieza con 'Core' -> pilar 'core'; todo lo que es grupo 'Balance' -> 'balance'.
update public.exercises set pillar = 'core' where pillar = 'activacion' and muscle_group like 'Core%';
update public.exercises set pillar = 'balance' where pillar = 'activacion' and muscle_group = 'Balance';
