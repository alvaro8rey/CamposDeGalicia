import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY   = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM_EMAIL       = Deno.env.get("FROM_EMAIL") ?? "noreply@camposdegalicia.es";
const SUPABASE_URL     = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const XP = 500;

// El webhook de Supabase envía { type, table, record, old_record, schema }
interface WebhookPayload {
  type: "UPDATE";
  table: string;
  record: { user_id: string; nombre: string; aprobada: boolean };
  old_record: { aprobada: boolean };
}

interface DirectPayload {
  userId: string;
  nombreCampo: string;
  xp?: number;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  let raw: WebhookPayload | DirectPayload;
  try {
    raw = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  // Normalizar: admite payload de webhook Y llamada directa
  let userId: string;
  let nombreCampo: string;

  if ("record" in raw) {
    // Payload de Database Webhook
    const { record, old_record } = raw as WebhookPayload;

    // Solo actuar si aprobada pasó de false → true
    if (!record.aprobada || old_record?.aprobada === true) {
      return new Response(JSON.stringify({ ok: true, skipped: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    userId      = record.user_id;
    nombreCampo = record.nombre;
  } else {
    // Llamada directa
    const direct = raw as DirectPayload;
    userId      = direct.userId;
    nombreCampo = direct.nombreCampo;
  }

  if (!userId || !nombreCampo) {
    return new Response(JSON.stringify({ ok: false, error: "Faltan userId o nombreCampo" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE);

  // 1. Sumar XP en la tabla niveles
  const { data: nivelData, error: nivelReadError } = await admin
    .from("niveles")
    .select("current_xp")
    .eq("id_usuario", userId)
    .single();

  if (nivelReadError || !nivelData) {
    console.error("[notificar-aprobacion] No se encontró fila en niveles:", nivelReadError);
    return new Response(JSON.stringify({ ok: false, error: "Fila niveles no encontrada" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { error: xpError } = await admin
    .from("niveles")
    .update({ current_xp: nivelData.current_xp + XP })
    .eq("id_usuario", userId);

  if (xpError) {
    console.error("[notificar-aprobacion] Error actualizando XP:", xpError);
    return new Response(JSON.stringify({ ok: false, error: "Error al actualizar XP" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  console.log(`[notificar-aprobacion] +${XP} XP añadidos a usuario ${userId} (total: ${nivelData.current_xp + XP})`);

  // 2. Obtener email del usuario via Admin API
  const { data: userData, error: userError } = await admin.auth.admin.getUserById(userId);

  if (userError || !userData?.user?.email) {
    console.error("[notificar-aprobacion] Usuario no encontrado:", userError);
    return new Response(JSON.stringify({ ok: false, error: "Usuario no encontrado" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  const userEmail = userData.user.email;
  console.log(`[notificar-aprobacion] Enviando email a ${userEmail} - Campo: ${nombreCampo}`);

  const html = `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<style>
  body { font-family: -apple-system, Arial, sans-serif; color: #333; background: #f5f5f5; margin: 0; padding: 20px; }
  .card { background: white; border-radius: 16px; padding: 32px; max-width: 560px; margin: 0 auto; box-shadow: 0 4px 16px rgba(0,0,0,.08); }
  .badge { display: inline-flex; align-items: center; gap: 8px; background: #e8f5e9; color: #2d7a2d; font-weight: 700; font-size: 14px; padding: 8px 14px; border-radius: 20px; margin-bottom: 20px; }
  h1 { color: #1a1a1a; font-size: 22px; margin: 0 0 8px; }
  .subtitle { color: #666; font-size: 15px; margin: 0 0 24px; }
  .campo-box { background: #f8f9fa; border-left: 4px solid #2d7a2d; border-radius: 8px; padding: 14px 16px; margin: 20px 0; }
  .campo-box .label { font-size: 11px; color: #888; text-transform: uppercase; letter-spacing: .5px; margin-bottom: 4px; }
  .campo-box .value { font-size: 17px; font-weight: 600; color: #1a1a1a; }
  .xp-box { display: flex; align-items: center; gap: 12px; background: linear-gradient(135deg, #1a73e8 0%, #0d47a1 100%); border-radius: 12px; padding: 18px 20px; margin: 20px 0; }
  .xp-icon { font-size: 32px; }
  .xp-text { color: white; }
  .xp-text .xp-amount { font-size: 26px; font-weight: 800; line-height: 1; }
  .xp-text .xp-label { font-size: 13px; opacity: .85; margin-top: 2px; }
  .footer { margin-top: 28px; font-size: 12px; color: #aaa; border-top: 1px solid #eee; padding-top: 16px; }
</style>
</head>
<body>
<div class="card">
  <div class="badge">✅ Sugerencia aprobada</div>
  <h1>¡Tu campo ha sido añadido!</h1>
  <p class="subtitle">Gracias a ti, la comunidad de Campos de Galicia crece. Tu sugerencia ha sido revisada y el campo ya está disponible en la app.</p>

  <div class="campo-box">
    <div class="label">Campo añadido</div>
    <div class="value">🏟️ ${nombreCampo}</div>
  </div>

  <div class="xp-box">
    <div class="xp-icon">⭐</div>
    <div class="xp-text">
      <div class="xp-amount">+${XP} XP</div>
      <div class="xp-label">¡Experiencia añadida a tu perfil!</div>
    </div>
  </div>

  <p style="color:#555;font-size:14px;line-height:1.6;">
    Abre la app para ver tu nuevo nivel y explorar el campo que sugeriste.
    ¡Sigue contribuyendo para ganar más experiencia!
  </p>

  <div class="footer">Campos de Galicia · No respondas a este correo</div>
</div>
</body>
</html>`;

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: [userEmail],
        subject: `¡Tu sugerencia "${nombreCampo}" ha sido aprobada! +${XP} XP`,
        html,
      }),
    });

    const data = await res.json();

    if (!res.ok) {
      console.error("[notificar-aprobacion] Resend error:", JSON.stringify(data));
      return new Response(JSON.stringify({ ok: false, error: data }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log("[notificar-aprobacion] Email enviado a", userEmail, "ID:", data.id);
    return new Response(JSON.stringify({ ok: true, emailId: data.id, xpSumado: XP }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[notificar-aprobacion] Error:", err);
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
