-- El bucket food-photos estaba PÚBLICO y sin políticas propias -- cualquiera
-- sin sesión podía listar las carpetas (IDs de pacientes), listar los
-- nombres de archivo dentro de cada una, y ver las fotos directamente.
-- Confirmado desde afuera el 2026-09-11 (curl sin auth, con la llave
-- pública nada más).
--
-- Esta migración: (1) hace el bucket privado, (2) quita cualquier política
-- vieja que mencione este bucket (por si alguna era la causa del acceso
-- abierto), y (3) deja solo dos políticas: el dueño de la carpeta puede
-- leer/subir la suya, y el coach puede leer todas. Nadie más, ni anónimo
-- ni otro paciente.

update storage.buckets set public = false where id = 'food-photos';

-- Se buscan y eliminan políticas existentes en storage.objects que
-- mencionen food-photos en su condición, sin necesidad de saber sus
-- nombres exactos de antemano.
do $$
declare
  pol record;
begin
  for pol in
    select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and (coalesce(qual, '') ilike '%food-photos%' or coalesce(with_check, '') ilike '%food-photos%')
  loop
    execute format('drop policy %I on storage.objects', pol.policyname);
  end loop;
end $$;

create policy "food-photos: dueño o coach pueden leer"
on storage.objects for select
to authenticated
using (
  bucket_id = 'food-photos'
  and (
    auth.uid()::text = (storage.foldername(name))[1]
    or auth.uid() = '29e3fed0-eb0d-4912-b6b2-9a9b6879d399'
  )
);

create policy "food-photos: el paciente solo sube a su propia carpeta"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'food-photos'
  and auth.uid()::text = (storage.foldername(name))[1]
);
