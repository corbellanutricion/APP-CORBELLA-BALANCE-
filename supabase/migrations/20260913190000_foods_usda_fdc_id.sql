-- Permite rastrear qué filas de `foods` vienen de USDA FoodData Central
-- (SR Legacy) y hace segura la reimportación: un fdc_id ya insertado se
-- salta con ON CONFLICT DO NOTHING en vez de duplicarse si el proceso de
-- importación se corta a la mitad y se vuelve a correr.
alter table public.foods
  add column if not exists usda_fdc_id integer unique;

comment on column public.foods.usda_fdc_id is
  'fdc_id de USDA FoodData Central (SR Legacy) cuando el alimento viene de esa importación; NULL para alimentos capturados a mano.';
