-- ============================================================
-- Aprobación de sugerencias de campos + notificación al usuario
-- ============================================================

-- 1. Añadir columna aprobada
ALTER TABLE sugerencias_campos
  ADD COLUMN IF NOT EXISTS aprobada boolean NOT NULL DEFAULT false;

-- 2. Permitir que el service role lea y actualice sugerencias
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'sugerencias_campos' AND policyname = 'Admin puede leer sugerencias'
  ) THEN
    CREATE POLICY "Admin puede leer sugerencias"
      ON sugerencias_campos FOR SELECT TO service_role USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'sugerencias_campos' AND policyname = 'Admin puede actualizar sugerencias'
  ) THEN
    CREATE POLICY "Admin puede actualizar sugerencias"
      ON sugerencias_campos FOR UPDATE TO service_role USING (true);
  END IF;
END $$;

-- 3. Trigger function: llama a la edge function via pg_net cuando aprobada → true
--
--    ANTES de ejecutar este SQL, guarda el anon key en Vault (una sola vez):
--
--      SELECT vault.create_secret(
--        'supabase_anon_key',
--        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...tu_anon_key...',
--        'Clave pública para triggers de BD'
--      );
--
--    El anon key está en: Dashboard → Settings → API → anon public
--
CREATE OR REPLACE FUNCTION fn_notificar_sugerencia_aprobada()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  anon_key    text;
  project_url text := 'https://ooqdrhkzsexjnmnvpwqw.supabase.co';
BEGIN
  -- Solo actuar cuando aprobada cambia de false/null → true
  IF NEW.aprobada = TRUE AND (OLD.aprobada IS DISTINCT FROM TRUE) THEN

    -- Leer el anon key desde Vault
    SELECT decrypted_secret INTO anon_key
    FROM vault.decrypted_secrets
    WHERE name = 'supabase_anon_key'
    LIMIT 1;

    IF anon_key IS NOT NULL THEN
      PERFORM net.http_post(
        url     := project_url || '/functions/v1/notificar-aprobacion-sugerencia',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || anon_key
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
