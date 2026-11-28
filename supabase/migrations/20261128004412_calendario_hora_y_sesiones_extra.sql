-- Ajustes al calendario semanal: hora de la sesión (texto 'HH:MM', sin
-- hora definida = null). "session_type" ya existía (text libre) -- ahora
-- también acepta 'hipertrofia' y 'recuperacion' además de
-- 'preparacion_fisica'/'deporte', pero como es texto libre no hace falta
-- tocar el esquema para eso, solo el código de la app.
alter table public.program_days
  add column if not exists scheduled_time text;
