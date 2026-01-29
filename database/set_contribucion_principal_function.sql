-- Función: set_contribucion_principal
-- Fecha: 2026-01-29
-- Descripción: Marca una contribución como principal y desmarca las demás del mismo campo.
--              Solo una contribución aprobada por campo puede ser principal.

CREATE OR REPLACE FUNCTION set_contribucion_principal(id_contribucion UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    campo_id UUID;
BEGIN
    -- Obtener el id_campo de la contribución
    SELECT id_campo INTO campo_id
    FROM campo_contribuciones
    WHERE id = id_contribucion;

    -- Verificar que la contribución existe
    IF campo_id IS NULL THEN
        RAISE EXCEPTION 'Contribución con id % no encontrada', id_contribucion;
    END IF;

    -- Verificar que la contribución está aprobada
    IF NOT EXISTS (
        SELECT 1 FROM campo_contribuciones
        WHERE id = id_contribucion AND aprobada = true
    ) THEN
        RAISE EXCEPTION 'La contribución con id % no está aprobada', id_contribucion;
    END IF;

    -- Desmarcar todas las contribuciones del mismo campo
    UPDATE campo_contribuciones
    SET es_principal = false
    WHERE id_campo = campo_id AND aprobada = true;

    -- Marcar la contribución especificada como principal
    UPDATE campo_contribuciones
    SET es_principal = true
    WHERE id = id_contribucion;

    RAISE NOTICE 'Contribución % marcada como principal para el campo %', id_contribucion, campo_id;
END;
$$;

-- Comentario para documentación
COMMENT ON FUNCTION set_contribucion_principal(UUID) IS 'Marca una contribución aprobada como principal y desmarca las demás del mismo campo. Solo una contribución por campo puede ser principal.';

-- Ejemplo de uso:
-- SELECT set_contribucion_principal('12345678-1234-1234-1234-123456789012');
