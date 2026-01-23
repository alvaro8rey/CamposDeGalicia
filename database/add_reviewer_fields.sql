-- Script para añadir los campos reviewer_name y reviewer_avatar_url a la tabla reseñas
-- Estos campos permiten cachear el nombre y avatar del usuario en el momento de escribir la reseña

-- Añadir columna reviewer_name si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'reseñas'
        AND column_name = 'reviewer_name'
    ) THEN
        ALTER TABLE reseñas ADD COLUMN reviewer_name TEXT;
        RAISE NOTICE 'Columna reviewer_name añadida correctamente';
    ELSE
        RAISE NOTICE 'Columna reviewer_name ya existe';
    END IF;
END $$;

-- Añadir columna reviewer_avatar_url si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'reseñas'
        AND column_name = 'reviewer_avatar_url'
    ) THEN
        ALTER TABLE reseñas ADD COLUMN reviewer_avatar_url TEXT;
        RAISE NOTICE 'Columna reviewer_avatar_url añadida correctamente';
    ELSE
        RAISE NOTICE 'Columna reviewer_avatar_url ya existe';
    END IF;
END $$;

-- IMPORTANTE: Ejecuta este script en el SQL Editor de Supabase
-- Dashboard -> Project -> SQL Editor -> New query -> Pega este código -> Run

-- Después de ejecutar, puedes verificar que las columnas existen con:
-- SELECT column_name, data_type FROM information_schema.columns
-- WHERE table_name = 'reseñas' AND column_name IN ('reviewer_name', 'reviewer_avatar_url');
