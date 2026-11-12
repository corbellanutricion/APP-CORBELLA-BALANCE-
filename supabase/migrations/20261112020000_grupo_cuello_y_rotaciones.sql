-- Corrección pedida por el usuario sobre las ~15 aproximaciones de grupo
-- muscular del import de VIDEOS PREP: los ejercicios de cuello van a un
-- grupo nuevo "Cuello" (no existía), y los de rotación (cuello y rotador
-- de hombro) van a "Movilidad" en vez de la aproximación anterior
-- (Deltoide anterior/posterior).

insert into public.muscle_groups (name, counts_as_volume) values ('Cuello', false)
on conflict (name) do nothing;

-- Rotaciones -> Movilidad
update public.exercises set muscle_group = 'Movilidad' where id = 'e_vp8';  -- Rotación de cuello
update public.exercises set muscle_group = 'Movilidad' where id = 'e_vp45'; -- Rotaciones internas de hombro
update public.exercises set muscle_group = 'Movilidad' where id = 'e_cb19'; -- Rotaciones externas con banda

-- Resto de cuello (no son rotación) -> Cuello
update public.exercises set muscle_group = 'Cuello' where id = 'e_vp9';  -- Extensión de cuello
update public.exercises set muscle_group = 'Cuello' where id = 'e_vp10'; -- Flexión de cuello
