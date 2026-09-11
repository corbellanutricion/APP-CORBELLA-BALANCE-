-- cb_call_send_push tenía el WEBHOOK_SECRET escrito en texto plano dentro
-- del código SQL de la función (visible para cualquiera con acceso de
-- lectura a pg_proc). Ahora lo lee de Supabase Vault, donde vive cifrado
-- (guardado como 'cb_webhook_secret' en la migración anterior).
create or replace function public.cb_call_send_push(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_url text default '/'::text,
  p_tag text default null::text
)
returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  edge_url text := 'https://uzldrfsejsaqtjmkyyff.supabase.co/functions/v1/send-push';
  webhook_secret text;
begin
  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'cb_webhook_secret'
  limit 1;

  perform net.http_post(
    url := edge_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', webhook_secret),
    body := jsonb_build_object('user_id', p_user_id, 'title', p_title, 'body', p_body, 'url', p_url, 'tag', p_tag)
  );
end;
$function$;
