-- Añadir columnas de coordenadas a la tabla de sugerencias
ALTER TABLE sugerencias_campos
  ADD COLUMN IF NOT EXISTS latitud  double precision,
  ADD COLUMN IF NOT EXISTS longitud double precision;
