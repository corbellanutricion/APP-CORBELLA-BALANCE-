-- Ajuste del sistema de dosificación por combate con el documento real del
-- usuario ("Sistema de programación - Atletas de combate" en Drive, basado
-- en una certificación de prep física para MMA):
--   1) Las clases de ejercicio son 4, no 3: fundamental, suplemental,
--      asistencia_mayor, asistencia_secundaria. Se corrige el constraint
--      (program_exercises.role no tenía ninguna fila escrita todavía --
--      verificado antes de este cambio -- así que no hace falta backfill).
--   2) exercises.default_role: el "Clase sugerida" del Banco de ejercicios
--      del usuario, para sugerir el rol al elegir el ejercicio en el
--      builder (null para ejercicios que no son de C5 Fuerza/C4 Potencia
--      tipo "Completo", donde el Banco no clasifica por rol).
--   3) Se importan los 34 ejercicios reales del Banco, con su pilar real
--      (columna "Categoría de video" del Banco) y el video correspondiente
--      ya grabado en la carpeta de Drive "VIDEOS PREP" (emparejado por
--      nombre). "Landmine" se mapea al pilar fuerza -- es una variante de
--      equipo dentro de C5 Fuerza, no un pilar aparte.

-- 1) role: 3 -> 4 clases
alter table public.program_exercises drop constraint if exists program_exercises_role_check;
alter table public.program_exercises
  add constraint program_exercises_role_check
  check (role is null or role in ('fundamental', 'suplemental', 'asistencia_mayor', 'asistencia_secundaria'));

-- 2) default_role en el catálogo (sugerencia desde el Banco)
alter table public.exercises
  add column if not exists default_role text;

alter table public.exercises
  add constraint exercises_default_role_check
  check (default_role is null or default_role in ('fundamental', 'suplemental', 'asistencia_mayor', 'asistencia_secundaria'));

-- 3) Banco de ejercicios real (34 filas, con video de VIDEOS PREP emparejado por nombre)
insert into public.exercises (id, name, muscle_group, pillar, load, default_role, video_url) values
  ('e_cb1', 'Tirón colgado', 'Espalda', 'potencia', 'pesada', 'fundamental', 'https://drive.google.com/file/d/1QXk7JJoXmGhjn3efUdehPRZaNm9ry9PU/view'),
  ('e_cb2', 'Clean + press', 'Cuerpo completo', 'potencia', 'pesada', 'fundamental', 'https://drive.google.com/file/d/1sOPEmXyJTXxpd9zGgoCfmni-pqdXEOvZ/view'),
  ('e_cb3', 'Swing', 'Cuerpo completo', 'balisticos', 'pesada', 'suplemental', 'https://drive.google.com/file/d/1LsRqKKL8rMwrXAQy06W7NMw9ilFiONo4/view'),
  ('e_cb4', 'Remo gorila', 'Espalda', 'accesorios', 'moderada', 'asistencia_mayor', 'https://drive.google.com/file/d/1mtTzcPXRLI8DhTTNxzZyPusehQlSXfSb/view'),
  ('e_cb5', 'Landmine peso muerto unilateral', 'Isquiotibiales', 'fuerza', 'moderada', 'asistencia_mayor', 'https://drive.google.com/file/d/1mYCaklrnUgESeY5F2MsrXJ7N39HSgbuE/view'),
  ('e_cb6', 'Landmine rotación de cadera + press', 'Core', 'fuerza', 'moderada', 'asistencia_mayor', 'https://drive.google.com/file/d/1udOmd-i1CDrC4w15hytUHTnXHyvDTt0W/view'),
  ('e_cb7', 'Sentadilla frontal parcial (vigilar rodilla)', 'Cuádriceps', 'fuerza', 'pesada', 'fundamental', 'https://drive.google.com/file/d/1QsBPFIOd7j0eZyZ4H3hw3wHF3HYrDyns/view'),
  ('e_cb8', 'Peso muerto con barra', 'Isquiotibiales', 'fuerza', 'pesada', 'fundamental', 'https://drive.google.com/file/d/12jLlXwJFfUujNbCQ_PdXN5uOCPauQvnN/view'),
  ('e_cb9', 'Búlgara contralateral', 'Glúteo', 'accesorios', 'moderada', 'asistencia_mayor', 'https://drive.google.com/file/d/1OnYJ2FphZ2fV73mNNWQGgICPhDHUF-lN/view'),
  ('e_cb10', 'Step up', 'Cuádriceps', 'accesorios', 'moderada', 'asistencia_mayor', 'https://drive.google.com/file/d/1KOoPUJzzjJ4Xs23bp8MkyK8kL8Vm4ymX/view'),
  ('e_cb11', 'Puente de cadera con barra', 'Glúteo', 'accesorios', 'ligera', 'asistencia_secundaria', 'https://drive.google.com/file/d/1tfepztOyrvWlgXEHUHWsYs1wAN6c-EOG/view'),
  ('e_cb12', 'Press de pecho con barra', 'Pecho', 'fuerza', 'pesada', 'fundamental', 'https://drive.google.com/file/d/1Y2fXbA4CAz9Tj9qV5AdAJQPPdgT5pBSy/view'),
  ('e_cb13', 'Press militar con barra', 'Deltoide anterior', 'fuerza', 'pesada', 'suplemental', 'https://drive.google.com/file/d/1eSC9g86k4oQ3DZ8ysiRBQYLfZ1ZW5DLX/view'),
  ('e_cb14', 'Dominadas pronas', 'Espalda', 'fuerza', 'pesada', 'suplemental', 'https://drive.google.com/file/d/1Qs3pZGcKCkRKlFvFBO075JQw7E_xCRbl/view'),
  ('e_cb15', 'Remo con barra', 'Espalda', 'fuerza', 'pesada', 'suplemental', 'https://drive.google.com/file/d/1_r2wBoClhxaNNDYjXJcTN0mR5v0-QuKx/view'),
  ('e_cb16', 'Remo invertido', 'Espalda', 'accesorios', 'moderada', 'asistencia_mayor', 'https://drive.google.com/file/d/1mfsO3BM7Y2X8K8UYAEQfvEfrjDDJbG1K/view'),
  ('e_cb17', 'Remo unilateral', 'Espalda', 'accesorios', 'moderada', 'asistencia_mayor', 'https://drive.google.com/file/d/1NBklYdkdCXx4EugMBaMoqrkn6397wQ-l/view'),
  ('e_cb18', 'Lagartija con remo', 'Espalda', 'accesorios', 'moderada', 'asistencia_mayor', 'https://drive.google.com/file/d/1Hv2xFCEicovRvtzXSLYXffX26S_tFikp/view'),
  ('e_cb19', 'Rotaciones externas con banda', 'Deltoide posterior', 'accesorios', 'ligera', 'asistencia_secundaria', 'https://drive.google.com/file/d/1Xe267rtqTKr4SrJ8t0cKurG3d3NygU0D/view'),
  ('e_cb20', 'Lanzamiento lateral con dos manos', 'Core', 'balisticos', 'moderada', null, 'https://drive.google.com/file/d/1pxL2DMsyCeAIquz4wKVq4w67ObgSnEG0/view'),
  ('e_cb21', 'Lanzamiento acostado', 'Core', 'balisticos', 'moderada', null, 'https://drive.google.com/file/d/1eP94jgRyRA3BCRkQVKoiy8-ufkwnPeRa/view'),
  ('e_cb22', 'Pogo', 'Pantorrilla', 'pliometria', 'moderada', null, 'https://drive.google.com/file/d/1Kw15sUY3Hw6h4jvB8QHpnBKZ_XwJNQfy/view'),
  ('e_cb23', 'Pogo altos', 'Pantorrilla', 'pliometria', 'moderada', null, 'https://drive.google.com/file/d/1AaFisY9OMI3I7Wj-8g9J1UH8Ja3cIfA0/view'),
  ('e_cb24', 'Salto con aterrizaje', 'Cuádriceps', 'pliometria', 'moderada', null, 'https://drive.google.com/file/d/1XsWJVXxpqRop3N5cQMgy8Sc8xoU8IKsu/view'),
  ('e_cb25', 'Aterrizaje desde cajón', 'Cuádriceps', 'pliometria', 'moderada', null, 'https://drive.google.com/file/d/1cNYnqmr61JMMvDbL2SLsC4hA70Y-Z6IV/view'),
  ('e_cb26', 'Saltos laterales con pelota', 'Glúteo', 'pliometria', 'moderada', null, 'https://drive.google.com/file/d/17sAdbxyLILOCj1CQyq3Dajq7oVTi1Egd/view'),
  ('e_cb27', 'Lagartijas explosivas en banco', 'Pecho', 'pliometria', 'moderada', null, 'https://drive.google.com/file/d/1sKwwi75XECxG3LVWKhn3oIEfDKyM2tUH/view'),
  ('e_cb28', 'Insecto muerto con disco', 'Abdomen', 'activacion', 'ligera', null, 'https://drive.google.com/file/d/1A1_uZaidvihSf2s2YM6TJmSrVe28MPCp/view'),
  ('e_cb29', 'Rotaciones con banda', 'Core', 'activacion', 'ligera', null, 'https://drive.google.com/file/d/1YxPIuOOOqqrk_5JjgT11dr-UxoM0RADP/view'),
  ('e_cb30', 'Plancha alta con movimiento de pesa', 'Core', 'activacion', 'ligera', null, 'https://drive.google.com/file/d/1aSv1POyMuEFUkID2i-sUnfdsr-fwoLGV/view'),
  ('e_cb31', 'Equilibrio a una pierna', 'Balance', 'activacion', 'ligera', null, 'https://drive.google.com/file/d/1JoVgrRdXOZ3UWiGyigaJCRT7feU7Pf-q/view'),
  ('e_cb32', 'Cadera 90/90', 'Movilidad', 'movilidad', 'ligera', null, 'https://drive.google.com/file/d/18aAeXrPhT1E74Qs-XUadSh-Bm_B-qsu9/view'),
  ('e_cb33', 'Tobillo', 'Movilidad', 'movilidad', 'ligera', null, 'https://drive.google.com/file/d/1GR34BxwTLR0BXIWANVBS19o6Zz79VK_J/view'),
  ('e_cb34', 'Glenohumeral dinámica', 'Movilidad', 'movilidad', 'ligera', null, 'https://drive.google.com/file/d/1JprbOffxVoW3-Ud4ke70fBIRFaGY60mC/view')
on conflict (id) do nothing;
