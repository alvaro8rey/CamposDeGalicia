-- Función para aprobar una contribución y actualizar el campo automáticamente
-- Esta función puede ser ejecutada desde Supabase o desde un trigger

CREATE OR REPLACE FUNCTION approve_contribution(contribution_id uuid)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  contrib RECORD;
  campo_id_value uuid;
BEGIN
  -- Obtener los datos de la contribución
  SELECT * INTO contrib
  FROM campo_contribuciones
  WHERE id = contribution_id;

  -- Verificar que la contribución existe
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Contribución no encontrada: %', contribution_id;
  END IF;

  -- Obtener el id del campo
  campo_id_value := contrib.id_campo;

  -- Actualizar el campo con los datos de la contribución
  -- Solo actualiza si el campo no tiene ya ese dato (COALESCE)
  UPDATE campos
  SET
    tiene_cantina = COALESCE(campos.tiene_cantina, contrib.tiene_cantina),
    aforo_grada = COALESCE(campos.aforo_grada, contrib.aforo_grada),
    medidas_campo = COALESCE(campos.medidas_campo, contrib.medidas_campo),
    tipo_iluminacion = COALESCE(campos.tipo_iluminacion, contrib.tipo_iluminacion),
    estado_cesped = COALESCE(campos.estado_cesped, contrib.estado_cesped),
    accesibilidad = COALESCE(campos.accesibilidad, contrib.accesibilidad),
    notas_adicionales = COALESCE(campos.notas_adicionales, contrib.notas)
  WHERE id = campo_id_value;

  -- Marcar la contribución como aprobada
  UPDATE campo_contribuciones
  SET aprobada = TRUE
  WHERE id = contribution_id;

  -- Las fotos se mantienen en campo_contribuciones y se muestran en la galería

  RETURN TRUE;
END;
$$;

-- Comentario de la función
COMMENT ON FUNCTION approve_contribution IS 'Aprueba una contribución y actualiza los datos del campo automáticamente';

-- Ejemplo de uso:
-- SELECT approve_contribution('uuid-de-la-contribucion');

-- ALTERNATIVA: Trigger automático cuando se marca aprobada=TRUE
-- Descomentar si quieres que sea automático al cambiar aprobada a TRUE

/*
CREATE OR REPLACE FUNCTION trigger_approve_contribution()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Solo ejecutar si aprobada cambia de FALSE/NULL a TRUE
  IF NEW.aprobada = TRUE AND (OLD.aprobada IS NULL OR OLD.aprobada = FALSE) THEN
    -- Actualizar el campo con los datos de la contribución
    UPDATE campos
    SET
      tiene_cantina = COALESCE(campos.tiene_cantina, NEW.tiene_cantina),
      aforo_grada = COALESCE(campos.aforo_grada, NEW.aforo_grada),
      medidas_campo = COALESCE(campos.medidas_campo, NEW.medidas_campo),
      tipo_iluminacion = COALESCE(campos.tipo_iluminacion, NEW.tipo_iluminacion),
      estado_cesped = COALESCE(campos.estado_cesped, NEW.estado_cesped),
      accesibilidad = COALESCE(campos.accesibilidad, NEW.accesibilidad),
      notas_adicionales = COALESCE(campos.notas_adicionales, NEW.notas)
    WHERE id = NEW.id_campo;
  END IF;

  RETURN NEW;
END;
$$;

-- Crear el trigger
DROP TRIGGER IF EXISTS on_contribution_approved ON campo_contribuciones;
CREATE TRIGGER on_contribution_approved
  AFTER UPDATE ON campo_contribuciones
  FOR EACH ROW
  EXECUTE FUNCTION trigger_approve_contribution();

COMMENT ON TRIGGER on_contribution_approved ON campo_contribuciones IS 'Actualiza automáticamente el campo cuando se aprueba una contribución';
*/
