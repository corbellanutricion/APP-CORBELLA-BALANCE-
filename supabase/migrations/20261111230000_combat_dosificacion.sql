-- Dosificación para deportes de combate (alto rendimiento): NO es volumen,
-- es un presupuesto de EJERCICIOS por sesión (según tiempo disponible/fase)
-- repartido en una jerarquía de roles:
--   - exercise_budget (en program_days): 3 (mínimo efectivo) | 5 (medio) | 7
--     (mucho tiempo). Cuenta solo fuerza/potencia/accesorios/hipertrofia --
--     pliometría, balísticos, movilidad, activación (core), sistemas
--     energéticos y estiramientos quedan FUERA del conteo (se agregan aparte,
--     sin límite).
--   - role (en program_exercises): fundamental | suplemental (asistencia
--     mayor) | asistencia (secundaria). Plantilla sugerida por presupuesto:
--       3 -> 1 fundamental + 1 suplemental + 1 asistencia
--       5 -> 1 fundamental + 2 suplemental + 2 asistencia
--       7 -> 1 fundamental + 3 suplemental + 3 asistencia
--     (sugerida, no forzada -- el coach puede reasignar el rol de cualquier
--     ejercicio).

alter table public.program_days
  add column if not exists exercise_budget integer;

alter table public.program_days
  add constraint program_days_exercise_budget_check
  check (exercise_budget is null or exercise_budget in (3, 5, 7));

alter table public.program_exercises
  add column if not exists role text;

alter table public.program_exercises
  add constraint program_exercises_role_check
  check (role is null or role in ('fundamental', 'suplemental', 'asistencia'));
