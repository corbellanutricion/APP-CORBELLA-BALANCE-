-- La tabla push_subscriptions se creó bien (con RLS), pero al crearse por
-- migración no heredó los permisos base que Supabase normalmente aplica
-- solo (los "default privileges") -- por eso send-push fallaba con
-- "permission denied for table push_subscriptions" en vez de solo filtrar
-- por RLS. Se dan los permisos explícitos que le faltaban.

grant select, insert, update, delete on public.push_subscriptions to authenticated;
grant select, insert, update, delete on public.push_subscriptions to service_role;
