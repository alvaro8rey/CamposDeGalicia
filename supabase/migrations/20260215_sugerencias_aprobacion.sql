-- ============================================================
-- Aprobación de sugerencias de campos + notificación al usuario
-- ============================================================

-- 1. Añadir columna aprobada
ALTER TABLE sugerencias_campos
  ADD COLUMN IF NOT EXISTS aprobada boolean NOT NULL DEFAULT false;

-- 2. Permitir que el admin (service role) lea y actualice sugerencias
CREATE POLICY IF NOT EXISTS "Admin puede leer sugerencias"
  ON sugerencias_campos FOR SELECT
  TO service_role
  USING (true);

CREATE POLICY IF NOT EXISTS "Admin puede actualizar sugerencias"
  ON sugerencias_campos FOR UPDATE
  TO service_role
  USING (true);

-- 3. Función trigger que llama a la edge function cuando aprobada pasa a TRUE
--
--    Requiere que el admin configure una vez el service role key en la BD:
--      ALTER DATABASE postgres SET app.supabase_service_role = 'eyJ...tu_service_role_key...';
--
CREATE OR REPLACE FUNCTION fn_notificar_sugerencia_aprobada()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  service_role_key text;
  project_url      text := 'https://ooqdrhkzsexjnmnvpwqw.supabase.co';
BEGIN
  -- Solo actuar cuando aprobada cambia de false/null → true
  IF NEW.aprobada = TRUE AND (OLD.aprobada IS DISTINCT FROM TRUE) THEN

    -- Leer el service role key almacenado en la configuración de la BD
    service_role_key := current_setting('app.supabase_service_role', true);

    IF service_role_key IS NOT NULL AND service_role_key <> '' THEN
      PERFORM net.http_post(
        url     := project_url || '/functions/v1/notificar-aprobacion-sugerencia',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || service_role_key
        ),
        body    := jsonb_build_object(
          'userId',      NEW.user_id::text,
          'nombreCampo', NEW.nombre,
          'xp',          500
        )
      );
    END IF;

  END IF;
  RETURN NEW;
END;
$$;

-- 4. Crear trigger (idempotente)
DROP TRIGGER IF EXISTS trg_sugerencia_aprobada ON sugerencias_campos;
CREATE TRIGGER trg_sugerencia_aprobada
  AFTER UPDATE OF aprobada ON sugerencias_campos
  FOR EACH ROW
  EXECUTE FUNCTION fn_notificar_sugerencia_aprobada();
