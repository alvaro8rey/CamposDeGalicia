-- Eliminar el trigger pg_net que llamaba a la edge function directamente.
-- El webhook configurado en el Dashboard de Supabase ya se encarga de esto,
-- por lo que el trigger pg_net era redundante (causaba doble ejecución: email doble + XP doble).

DROP TRIGGER IF EXISTS trg_sugerencia_aprobada ON sugerencias_campos;
DROP FUNCTION IF EXISTS fn_notificar_sugerencia_aprobada();
