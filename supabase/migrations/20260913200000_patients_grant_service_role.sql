-- Mismo problema que ya se corrigió para `foods`: ninguna tabla nueva viene
-- con GRANT para service_role por default en este proyecto (ver
-- push_subscriptions_grants y foods_grant_service_role). `patients` nunca
-- había sido leída con la service role key desde una Edge Function -- hasta
-- generate-meal-from-description, que la usa para confirmar que el paciente
-- le pertenece al coach que hace la llamada. Sin este grant, esa lectura
-- fallaba con "permission denied for table patients", y la función lo
-- interpretaba (de forma demasiado silenciosa) como "paciente no encontrado".
grant select on public.patients to service_role;
