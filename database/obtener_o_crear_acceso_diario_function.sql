-- Función: obtener_o_crear_acceso_diario
-- Descripción: Obtiene o crea un registro de acceso diario para un usuario
-- Fecha: 2026-02-06
-- Fix: Resuelve ambigüedad de columna id_usuario con RLS activo

CREATE OR REPLACE FUNCTION obtener_o_crear_acceso_diario(p_usuario_id UUID)
RETURNS TABLE (
    id UUID,
    id_usuario UUID,
    ultimo_acceso TIMESTAMP WITH TIME ZONE,
    dias_consecutivos INTEGER,
    ultima_recompensa_reclamada TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Intentar insertar si no existe
    -- Usamos el parámetro p_usuario_id directamente sin ambigüedad
    INSERT INTO public.accesos_diarios (id_usuario, ultimo_acceso, dias_consecutivos)
    VALUES (p_usuario_id, now(), 1)
    ON CONFLICT (id_usuario) DO NOTHING;

    -- Retornar el registro existente o recién creado
    -- Calificamos todas las columnas con el nombre de la tabla para evitar ambigüedad
    RETURN QUERY
    SELECT
        ad.id,
        ad.id_usuario,
        ad.ultimo_acceso,
        ad.dias_consecutivos,
        ad.ultima_recompensa_reclamada
    FROM public.accesos_diarios ad
    WHERE ad.id_usuario = p_usuario_id
    LIMIT 1;
END;
$$;

-- Comentario para documentación
COMMENT ON FUNCTION obtener_o_crear_acceso_diario(UUID) IS
'Obtiene o crea un registro de acceso diario para un usuario. Usa SECURITY DEFINER para bypassear RLS correctamente.';

-- Grant de ejecución para usuarios autenticados
GRANT EXECUTE ON FUNCTION obtener_o_crear_acceso_diario(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION obtener_o_crear_acceso_diario(UUID) TO anon;
