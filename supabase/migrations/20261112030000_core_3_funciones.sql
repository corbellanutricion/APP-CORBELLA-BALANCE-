-- Desglose de "Core" en sus 3 funciones reales (C2 Activación del
-- documento del usuario: "tronco (anti-extensión, anti-rotación,
-- anti-flexión lateral)"). Aplica a TODO el catálogo de Core -- incluye
-- ejercicios del catálogo original (de antes de esta conversación) y los
-- que se importaron hoy de VIDEOS PREP/Banco. Los "Lanzamiento..."
-- (balísticos) NO entran -- esos producen rotación, no la resisten; se
-- quedan con muscle_group = 'Core' tal cual.
--
-- También 2 correcciones de pilar pedidas directamente:
--   - "Rotación con pelota a 1 pierna" -> balísticos (lanzamiento, no activación)
--   - "Rotación con landmine" -> activación/core (no fuerza)

insert into public.muscle_groups (name, counts_as_volume) values
  ('Core (anti-extensión)', false),
  ('Core (anti-rotación)', false),
  ('Core (anti-flexión lateral)', false)
on conflict (name) do nothing;

-- correcciones de pilar
update public.exercises set pillar = 'balisticos' where id = 'e_vp13'; -- Rotación con pelota a 1 pierna
update public.exercises set pillar = 'activacion' where id = 'e_vp24'; -- Rotación con landmine

-- anti-extensión (sagital: planchas frontales, puentes, crunches, back extension)
update public.exercises set muscle_group = 'Core (anti-extensión)' where id in (
  'emqh7mf0xy4fk', -- Abdominal colgado rodillas al pecho
  'e204', -- Abdominales en el Suelo
  'e195', -- Cobra de Piso
  'e196', -- Cobra en Pelota
  'emqh7ik2eutsw', -- Crunch Colgado rodillas al pecho
  'e207', -- Crunch de Rodillas
  'e206', -- Crunch Inverso
  'e205', -- Extensión de Espalda
  'e200', -- Insecto Muerto
  'e201', -- Perro Pájaro
  'e198', -- Plancha
  'e_vp56', -- Plancha alta
  'e_cb30', -- Plancha alta con movimiento de pesa
  'e_vp55', -- Plancha baja
  'e194', -- Puente con Pelota Medicinal
  'e193', -- Puente de Piso
  'e_vp68' -- Retracciones escapulares en cuadrupedia (aproximado, no es de tronco)
);

-- anti-rotación (transversal: chops/lifts de cable, Pallof, bandas/disco, landmine)
update public.exercises set muscle_group = 'Core (anti-rotación)' where id in (
  'e197', -- Boca de Incendio
  'e210', -- Corte de Cable
  'e192', -- De Marcha
  'e209', -- Elevador de Cable
  'e_vp60', -- Marcha
  'e_vp54', -- Plancha alta con toque de hombros
  'e_vp53', -- Plancha con rotación de tórax
  'e202', -- Press Palloff de Rodillas
  'e208', -- Rotación con Cable
  'e_vp24', -- Rotación con landmine
  'e_cb29', -- Rotaciones con banda
  'e_vp72', -- Rotaciones con banda (variante 2)
  'e_vp73', -- Rotaciones con banda (variante 3)
  'e_vp50' -- Rotaciones con disco
);

-- anti-flexión lateral (frontal/lateral: planchas laterales, carga unilateral)
update public.exercises set muscle_group = 'Core (anti-flexión lateral)' where id in (
  'e199', -- Plancha Lateral
  'e_vp46', -- Plancha lateral con aducción
  'e_vp48', -- Plancha lateral dinámica
  'e_vp49', -- Plancha lateral isométrica
  'e_vp47', -- Plancha lateral isométrica con rotación de tórax
  'e203' -- Transporte de Granjero
);
