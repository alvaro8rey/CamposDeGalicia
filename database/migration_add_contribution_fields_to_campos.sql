-- Migration: Añadir campos de contribuciones a la tabla campos
-- Fecha: 2026-01-29
-- Descripción: Añade los campos de contribuciones a la tabla principal de campos
--              para que los datos aprobados se guarden directamente en el campo

-- Añadir columna para cantina
ALTER TABLE campos ADD COLUMN IF NOT EXISTS tiene_cantina boolean;

-- Añadir columna para aforo de grada
ALTER TABLE campos ADD COLUMN IF NOT EXISTS aforo_grada integer;

-- Añadir columna para medidas del campo
ALTER TABLE campos ADD COLUMN IF NOT EXISTS medidas_campo text;

-- Añadir columna para tipo de iluminación
ALTER TABLE campos ADD COLUMN IF NOT EXISTS tipo_iluminacion text;

-- Añadir columna para estado del césped
ALTER TABLE campos ADD COLUMN IF NOT EXISTS estado_cesped text;

-- Añadir columna para accesibilidad
ALTER TABLE campos ADD COLUMN IF NOT EXISTS accesibilidad text;

-- Añadir columna para notas adicionales
ALTER TABLE campos ADD COLUMN IF NOT EXISTS notas_adicionales text;

-- Comentarios para documentación
COMMENT ON COLUMN campos.tiene_cantina IS 'Indica si el campo tiene cantina disponible';
COMMENT ON COLUMN campos.aforo_grada IS 'Capacidad de la grada en número de personas';
COMMENT ON COLUMN campos.medidas_campo IS 'Medidas del campo (ej: 100x60m)';
COMMENT ON COLUMN campos.tipo_iluminacion IS 'Tipo de iluminación del campo (Natural/Artificial)';
COMMENT ON COLUMN campos.estado_cesped IS 'Estado del césped (Bueno/Regular/Malo)';
COMMENT ON COLUMN campos.accesibilidad IS 'Información sobre accesibilidad para personas con discapacidad';
COMMENT ON COLUMN campos.notas_adicionales IS 'Notas adicionales sobre el campo';

-- Nota: Cuando apruebes una contribución en Supabase, deberás actualizar
-- estos campos en la tabla campos con los valores de la contribución aprobada.
-- Ejemplo de query para aprobar y actualizar:
--
-- UPDATE campos
-- SET
--   tiene_cantina = COALESCE(campos.tiene_cantina, (SELECT tiene_cantina FROM campo_contribuciones WHERE id = 'ID_CONTRIBUCION')),
--   aforo_grada = COALESCE(campos.aforo_grada, (SELECT aforo_grada FROM campo_contribuciones WHERE id = 'ID_CONTRIBUCION')),
--   -- ... resto de campos
-- WHERE id = 'ID_CAMPO';
--
-- UPDATE campo_contribuciones SET aprobada = TRUE WHERE id = 'ID_CONTRIBUCION';
