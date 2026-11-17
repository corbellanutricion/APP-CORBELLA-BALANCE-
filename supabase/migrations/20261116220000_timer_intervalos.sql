-- Timer de intervalos para ejercicios de sistemas energéticos (aláctico,
-- láctico, aeróbico): vueltas, segundos de trabajo y segundos de descanso.
-- Es aditivo y opcional -- si el coach no los llena, el ejercicio se ve
-- igual que antes (solo texto), simplemente no aparece el botón de timer
-- en la app del paciente.

alter table public.program_exercises
  add column if not exists interval_rounds integer,
  add column if not exists interval_work_sec integer,
  add column if not exists interval_rest_sec integer;

alter table public.program_exercises
  add constraint program_exercises_interval_rounds_check
  check (interval_rounds is null or interval_rounds > 0);

alter table public.program_exercises
  add constraint program_exercises_interval_work_sec_check
  check (interval_work_sec is null or interval_work_sec > 0);

alter table public.program_exercises
  add constraint program_exercises_interval_rest_sec_check
  check (interval_rest_sec is null or interval_rest_sec >= 0);
