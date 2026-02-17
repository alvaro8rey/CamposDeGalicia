-- Columna para saber si el usuario ya fue notificado in-app de la aprobación.
-- La edge function no necesita cambios: DEFAULT false garantiza que nuevas
-- aprobaciones empiecen sin notificar.

ALTER TABLE sugerencias_campos
  ADD COLUMN IF NOT EXISTS notificado_aprobacion boolean NOT NULL DEFAULT false;
