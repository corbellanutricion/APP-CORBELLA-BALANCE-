-- El arquetipo final del atleta lo decide el coach, no un cálculo
-- automático -- las etiquetas por calificación (fuerza/velocidad/etc.)
-- quedan como sugerencia clicable, pero lo que se guarda como "el
-- arquetipo" es este campo de texto libre que el coach escribe/confirma.
alter table public.athlete_profiles
  add column if not exists archetype text not null default '';
