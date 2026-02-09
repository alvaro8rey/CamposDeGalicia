# Sistema de Contribución Principal

## Descripción

Este sistema permite seleccionar cuál contribución aprobada se muestra como **principal** en la vista de detalle del campo. Las fotos de todas las contribuciones aprobadas se siguen mostrando juntas, pero los datos técnicos (cantina, aforo, medidas, etc.) se toman de la contribución marcada como principal.

## Estructura de Base de Datos

### Campo nuevo: `es_principal`

- **Tabla**: `campo_contribuciones`
- **Tipo**: `BOOLEAN`
- **Default**: `false`
- **Regla**: Solo una contribución aprobada por campo puede tener `es_principal = true`

## Cómo usar desde Supabase

### 1. Ejecutar las migraciones

Ejecuta estos archivos SQL en Supabase en este orden:

```bash
1. migration_add_es_principal_to_contribuciones.sql
2. set_contribucion_principal_function.sql
```

### 2. Aprobar una contribución

Cuando apruebas una contribución, simplemente actualiza el campo:

```sql
UPDATE campo_contribuciones
SET aprobada = true
WHERE id = 'ID_DE_LA_CONTRIBUCION';
```

### 3. Marcar una contribución como principal

Usa la función helper (recomendado):

```sql
SELECT set_contribucion_principal('ID_DE_LA_CONTRIBUCION');
```

Esta función automáticamente:
- ✅ Verifica que la contribución existe
- ✅ Verifica que está aprobada
- ✅ Desmarca todas las demás contribuciones del mismo campo
- ✅ Marca esta contribución como principal

**O manualmente:**

```sql
-- 1. Desmarcar todas las contribuciones del campo
UPDATE campo_contribuciones
SET es_principal = false
WHERE id_campo = 'ID_DEL_CAMPO' AND aprobada = true;

-- 2. Marcar la deseada como principal
UPDATE campo_contribuciones
SET es_principal = true
WHERE id = 'ID_DE_LA_CONTRIBUCION';
```

### 4. Ver contribuciones de un campo

```sql
SELECT
    id,
    id_usuario,
    fecha,
    aprobada,
    es_principal,
    tiene_cantina,
    aforo_grada,
    medidas_campo,
    notas
FROM campo_contribuciones
WHERE id_campo = 'ID_DEL_CAMPO'
AND aprobada = true
ORDER BY es_principal DESC, fecha DESC;
```

## Comportamiento en la App

### Vista de Detalle del Campo

**Datos técnicos (texto):**
- Se muestra la contribución con `es_principal = true`
- Si no hay ninguna marcada, se muestra la más reciente (ordenada por fecha DESC)

**Fotos:**
- Se muestran TODAS las fotos de TODAS las contribuciones aprobadas
- Cada foto muestra el nombre del usuario que la contribuyó

## Ejemplos

### Escenario típico

```sql
-- Usuario A contribuye el lunes
INSERT INTO campo_contribuciones (...) VALUES (...);  -- ID: AAA

-- Admin aprueba
UPDATE campo_contribuciones SET aprobada = true WHERE id = 'AAA';

-- Usuario B contribuye el martes
INSERT INTO campo_contribuciones (...) VALUES (...);  -- ID: BBB

-- Admin aprueba
UPDATE campo_contribuciones SET aprobada = true WHERE id = 'BBB';

-- Estado actual: Se muestra la contribución de B (más reciente)

-- Admin decide que la contribución de A es mejor
SELECT set_contribucion_principal('AAA');

-- Ahora se muestra la contribución de A
-- Las fotos de A y B se siguen mostrando juntas
```

## Notas importantes

1. **Solo contribuciones aprobadas** pueden ser principales
2. **Solo una contribución por campo** puede ser principal
3. **Las fotos se juntan** de todas las contribuciones aprobadas
4. Si **no hay ninguna principal**, se usa la más reciente
5. El campo `es_principal` tiene un **índice optimizado** para búsquedas rápidas
