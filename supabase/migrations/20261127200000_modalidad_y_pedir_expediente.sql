-- "Modalidad" (presencial/online) por paciente, y un interruptor para que el
-- coach pida -- a CUALQUIER paciente existente, no solo a los nuevos -- que
-- llene su propio expediente la próxima vez que abra la app. Complementa el
-- flujo de invitación "coached" (ese es para pacientes que AÚN no tienen
-- cuenta); esto es para pacientes que ya tienen cuenta y login.

alter table public.patients
  add column if not exists modality text not null default 'presencial',
  add column if not exists clinical_record_requested_at timestamptz,
  add column if not exists clinical_record_submitted_at timestamptz;

-- El paciente necesita poder marcar que ya lo llenó (clinical_record_submitted_at)
-- en su propia fila. Se suma (OR) a cualquier política existente del coach.
create policy "patients: el paciente marca su propio expediente como llenado"
on public.patients for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());
