-- `foods` nunca tuvo GRANT explícito para service_role (los inserts hasta
-- ahora siempre pasaban por la sesión del coach vía RLS). La importación de
-- USDA inserta con la service role key desde una Edge Function, y sin este
-- grant Postgres la rechaza con "permission denied for table foods" aunque
-- service_role normalmente ignora RLS -- eso es aparte de los privilegios de
-- tabla, que sí hacen falta.
grant select, insert on public.foods to service_role;
