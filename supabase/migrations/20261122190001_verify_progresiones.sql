do $$
declare
  cnt int;
  cnt_pot int;
begin
  select count(*) into cnt from public.exercises where id like 'eclean%' or id like 'esnatch%';
  select count(*) into cnt_pot from public.exercises where (id like 'eclean%' or id like 'esnatch%') and pillar = 'potencia';
  raise notice 'total clean/snatch: %, con pillar potencia: %', cnt, cnt_pot;
end $$;
