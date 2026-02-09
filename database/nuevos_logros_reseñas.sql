-- =====================================================
-- NUEVOS LOGROS RELACIONADOS CON RESEÑAS
-- =====================================================
-- Script para añadir logros que recompensan la escritura de reseñas
-- Ejecutar en Supabase SQL Editor

-- 1. Primera Reseña (50 XP)
INSERT INTO logros (id, nombre, descripcion, condicion, orden, xp)
VALUES (
    'b0000000-0000-0000-0000-000000000001'::uuid,
    'Primera Opinión',
    'Escribe tu primera reseña y comparte tu experiencia con la comunidad.',
    'reseñas_escritas>=1',
    10,
    50
)
ON CONFLICT (id) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion,
    condicion = EXCLUDED.condicion,
    orden = EXCLUDED.orden,
    xp = EXCLUDED.xp;

-- 2. Crítico Activo - 5 Reseñas (100 XP)
INSERT INTO logros (id, nombre, descripcion, condicion, orden, xp)
VALUES (
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'Crítico Activo',
    'Has escrito 5 reseñas. Tu opinión es valiosa para la comunidad.',
    'reseñas_escritas>=5',
    11,
    100
)
ON CONFLICT (id) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion,
    condicion = EXCLUDED.condicion,
    orden = EXCLUDED.orden,
    xp = EXCLUDED.xp;

-- 3. Experto Evaluador - 10 Reseñas (200 XP)
INSERT INTO logros (id, nombre, descripcion, condicion, orden, xp)
VALUES (
    'b0000000-0000-0000-0000-000000000003'::uuid,
    'Experto Evaluador',
    '¡10 reseñas escritas! Eres un pilar de la comunidad de Campos de Galicia.',
    'reseñas_escritas>=10',
    12,
    200
)
ON CONFLICT (id) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion,
    condicion = EXCLUDED.condicion,
    orden = EXCLUDED.orden,
    xp = EXCLUDED.xp;

-- 4. Maestro Reseñador - 25 Reseñas (500 XP)
INSERT INTO logros (id, nombre, descripcion, condicion, orden, xp)
VALUES (
    'b0000000-0000-0000-0000-000000000004'::uuid,
    'Maestro Reseñador',
    '25 reseñas escritas. Tu dedicación ayuda a miles de jugadores.',
    'reseñas_escritas>=25',
    13,
    500
)
ON CONFLICT (id) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion,
    condicion = EXCLUDED.condicion,
    orden = EXCLUDED.orden,
    xp = EXCLUDED.xp;

-- 5. Leyenda de la Crítica - 50 Reseñas (1000 XP)
INSERT INTO logros (id, nombre, descripcion, condicion, orden, xp)
VALUES (
    'b0000000-0000-0000-0000-000000000005'::uuid,
    'Leyenda de la Crítica',
    '¡50 reseñas! Eres una leyenda. Tu conocimiento es invaluable.',
    'reseñas_escritas>=50',
    14,
    1000
)
ON CONFLICT (id) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion,
    condicion = EXCLUDED.condicion,
    orden = EXCLUDED.orden,
    xp = EXCLUDED.xp;

-- =====================================================
-- VERIFICACIÓN: Ver todos los logros relacionados con reseñas
-- =====================================================
-- SELECT * FROM logros WHERE condicion LIKE '%reseñas_escritas%' ORDER BY orden;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================
-- 1. XP por reseñas (además de los logros):
--    - Base: 25 XP por reseña
--    - Reseña detallada (>100 caracteres): +10 XP
--    - Reseña con fotos: +15 XP
--    - Editar/actualizar reseña: +5 XP
--    - Total máximo: 55 XP por reseña de calidad
--
-- 2. Sistema de prioridad en reseñas destacadas:
--    - Las reseñas se ordenan primero por nivel del usuario
--    - Usuarios con más nivel aparecen primero
--    - Esto incentiva a los usuarios a subir de nivel
--
-- 3. Actualización automática:
--    - El sistema recalcula XP automáticamente al:
--      * Escribir una nueva reseña
--      * Editar una reseña existente
--      * Visitar un campo
--      * Desbloquear logros
