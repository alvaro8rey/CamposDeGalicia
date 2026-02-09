-- Migración para añadir campo parking a la tabla campos
-- Fecha: 2026-01-29

-- Añadir columna parking a la tabla campos
ALTER TABLE campos
ADD COLUMN IF NOT EXISTS parking BOOLEAN DEFAULT NULL;

-- Añadir columna parking a la tabla campo_contribuciones
ALTER TABLE campo_contribuciones
ADD COLUMN IF NOT EXISTS parking BOOLEAN DEFAULT NULL;

-- Comentarios
COMMENT ON COLUMN campos.parking IS 'Indica si el campo tiene parking disponible';
COMMENT ON COLUMN campo_contribuciones.parking IS 'Contribución: indica si el campo tiene parking disponible';
