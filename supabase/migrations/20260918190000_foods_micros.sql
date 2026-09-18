-- Agrega el panel estándar de micronutrientes por 100g a `foods`, tomado del
-- dataset oficial de USDA FoodData Central (SR Legacy) para los alimentos que
-- vienen de esa fuente (usda_fdc_id). Se guarda como JSONB en vez de columnas
-- individuales para no tener que migrar cada vez que se agregue un nutriente
-- nuevo, y porque no hay necesidad de filtrar/ordenar por nutriente en SQL.
--
-- Claves esperadas dentro de `micros` (todas por 100g, null si no hay dato):
--   vitamin_a_mcg, vitamin_c_mg, vitamin_d_mcg, vitamin_e_mg, vitamin_k_mcg,
--   vitamin_b1_mg, vitamin_b2_mg, vitamin_b3_mg, vitamin_b6_mg,
--   vitamin_b12_mcg, folate_mcg,
--   calcium_mg, iron_mg, magnesium_mg, phosphorus_mg, potassium_mg,
--   sodium_mg, zinc_mg, copper_mg, selenium_mcg,
--   fiber_g, sugar_g, cholesterol_mg, saturated_fat_g
alter table public.foods
  add column if not exists micros jsonb;

comment on column public.foods.micros is
  'Panel estándar de ~24 micronutrientes por 100g (vitaminas, minerales, fibra/azúcar/colesterol/grasa saturada). Backfill desde USDA FoodData Central (SR Legacy) para filas con usda_fdc_id; NULL para alimentos capturados a mano sin ese dato.';
