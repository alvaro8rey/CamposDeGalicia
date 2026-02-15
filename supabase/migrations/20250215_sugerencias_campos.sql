-- Tabla de sugerencias de campos enviadas por usuarios
CREATE TABLE IF NOT EXISTS sugerencias_campos (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  nombre     text        NOT NULL,
  municipio  text,
  provincia  text,
  notas      text,
  imagenes   text[],
  created_at timestamptz DEFAULT now()
);

-- Solo usuarios autenticados pueden insertar sus propias sugerencias
ALTER TABLE sugerencias_campos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuarios autenticados pueden sugerir campos"
  ON sugerencias_campos FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid()::text = user_id::text);

-- Bucket de Storage para las fotos de sugerencias
-- (ejecutar en el dashboard de Supabase → Storage → New bucket)
-- Nombre: sugerencias-fotos, Public: true
