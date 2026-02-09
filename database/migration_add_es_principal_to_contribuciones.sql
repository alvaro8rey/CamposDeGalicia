-- Migration: Añadir campo es_principal a la tabla campo_contribuciones
-- Fecha: 2026-01-29
-- Descripción: Añade un campo booleano para marcar cuál contribución aprobada
--              debe mostrarse como principal en la vista de detalle del campo.
--              Solo una contribución por campo puede ser principal.

-- Añadir columna es_principal
ALTER TABLE campo_contribuciones
ADD COLUMN IF NOT EXISTS es_principal BOOLEAN DEFAULT false;

-- Comentario para documentación
COMMENT ON COLUMN campo_contribuciones.es_principal IS 'Indica si esta contribución es la principal que se muestra en los detalles del campo. Solo una contribución aprobada por campo debe tener este valor en true.';

-- Crear índice para optimizar búsquedas de contribución principal
CREATE INDEX IF NOT EXISTS idx_campo_contribuciones_principal
ON campo_contribuciones(id_campo, es_principal)
WHERE aprobada = true AND es_principal = true;

-- Nota: Para marcar una contribución como principal, usa la función
-- set_contribucion_principal(id_contribucion UUID) que se creará a continuación
