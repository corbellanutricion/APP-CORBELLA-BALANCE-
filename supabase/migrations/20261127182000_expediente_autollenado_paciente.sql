-- Permite que un paciente a distancia llene su propio expediente clínico
-- (bioquímicos, clínicos, dietéticos, estilo de vida, entrenamiento) durante
-- el onboarding "coached", para revisión posterior del coach antes de
-- aprobar la cuenta. Hoy solo el coach podía escribir en clinical_records.

-- Bucket privado para que el paciente suba sus estudios de laboratorio
-- (PDF o foto) cuando no puede hacérselos medir/leer presencialmente al coach.
insert into storage.buckets (id, name, public)
values ('lab-results', 'lab-results', false)
on conflict (id) do nothing;

create policy "lab-results: dueño o coach pueden leer"
on storage.objects for select
to authenticated
using (
  bucket_id = 'lab-results'
  and (
    auth.uid()::text = (storage.foldername(name))[1]
    or auth.uid() = '29e3fed0-eb0d-4912-b6b2-9a9b6879d399'
  )
);

create policy "lab-results: el paciente solo sube a su propia carpeta"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'lab-results'
  and auth.uid()::text = (storage.foldername(name))[1]
);

-- El paciente puede crear/actualizar SU PROPIO expediente clínico. Se suma
-- (OR) a la política existente del coach -- no la reemplaza.
create policy "clinical_records: el paciente escribe su propio expediente"
on public.clinical_records for insert
to authenticated
with check (patient_id = auth.uid());

create policy "clinical_records: el paciente actualiza su propio expediente"
on public.clinical_records for update
to authenticated
using (patient_id = auth.uid())
with check (patient_id = auth.uid());
