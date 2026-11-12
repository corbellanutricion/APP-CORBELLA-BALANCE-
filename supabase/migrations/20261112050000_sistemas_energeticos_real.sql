-- Reemplaza el modelo "simple" de sistemas energéticos (solo duración +
-- nota libre) por el modelo real de la Sesión 4 del curso de preparación
-- física del usuario: 3 sistemas (aláctico/fosfato, láctico/glucolítico,
-- aeróbico/oxidativo) × 2 cualidades (potencia, capacidad) cada uno.
-- duration_min y notes se quedan igual -- esto se SUMA, no reemplaza.

alter table public.program_exercises
  add column if not exists energy_system text,
  add column if not exists energy_quality text;

alter table public.program_exercises
  add constraint program_exercises_energy_system_check
  check (energy_system is null or energy_system in ('alactico', 'lactico', 'aerobico'));

alter table public.program_exercises
  add constraint program_exercises_energy_quality_check
  check (energy_quality is null or energy_quality in ('potencia', 'capacidad'));
