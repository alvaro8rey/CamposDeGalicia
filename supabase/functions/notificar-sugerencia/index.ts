import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

// IONOS: puerto 587 con STARTTLS
const SMTP_HOST = Deno.env.get("SMTP_HOST") ?? "smtp.ionos.es";
const SMTP_PORT = Number(Deno.env.get("SMTP_PORT") ?? "587");
const SMTP_USER = Deno.env.get("SMTP_USER") ?? "";
const SMTP_PASS = Deno.env.get("SMTP_PASS") ?? "";
const NOTIFY_TO = Deno.env.get("NOTIFY_TO") ?? "info@camposdegalicia.es";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  let body: {
    nombre: string;
    municipio?: string;
    provincia?: string;
    notas?: string;
    imagenes?: string[];
    userEmail?: string;
  };

  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  console.log("[notificar-sugerencia] Recibido:", JSON.stringify(body));

  if (!SMTP_USER || !SMTP_PASS) {
    console.error("[notificar-sugerencia] ERROR: SMTP_USER o SMTP_PASS no configurados");
    return new Response(JSON.stringify({ ok: false, error: "SMTP credentials not set" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { nombre, municipio, provincia, notas, imagenes, userEmail } = body;

  const imagenesHtml = imagenes && imagenes.length > 0
    ? `<p><strong>Fotos adjuntas:</strong></p>
       <div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:8px;">
         ${imagenes.map((url) => `<img src="${url}" style="width:200px;height:150px;object-fit:cover;border-radius:8px;" />`).join("")}
       </div>`
    : "";

  const html = `<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"/>
<style>
  body{font-family:-apple-system,Arial,sans-serif;color:#333;background:#f5f5f5;margin:0;padding:20px}
  .card{background:white;border-radius:12px;padding:28px;max-width:600px;margin:0 auto;box-shadow:0 2px 8px rgba(0,0,0,.08)}
  h1{color:#2d7a2d;font-size:22px;margin-top:0}
  .label{font-size:12px;color:#888;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px}
  .value{font-size:16px;font-weight:500;margin-bottom:16px}
  .footer{margin-top:24px;font-size:12px;color:#aaa;border-top:1px solid #eee;padding-top:12px}
</style>
</head>
<body>
<div class="card">
  <h1>🏟️ Nueva sugerencia de campo</h1>
  <div class="label">Nombre del campo</div><div class="value">${nombre}</div>
  ${municipio ? `<div class="label">Municipio</div><div class="value">${municipio}</div>` : ""}
  ${provincia ? `<div class="label">Provincia</div><div class="value">${provincia}</div>` : ""}
  ${notas ? `<div class="label">Notas</div><div class="value">${notas}</div>` : ""}
  ${userEmail ? `<div class="label">Enviado por</div><div class="value">${userEmail}</div>` : ""}
  ${imagenesHtml}
  <div class="footer">Campos de Galicia · Sugerencia enviada desde la app</div>
</div>
</body>
</html>`;

  const client = new SMTPClient({
    connection: {
      hostname: SMTP_HOST,
      port: SMTP_PORT,
      tls: false,       // false = usa STARTTLS en puerto 587
      auth: {
        username: SMTP_USER,
        password: SMTP_PASS,
      },
    },
  });

  try {
    console.log(`[notificar-sugerencia] Enviando via ${SMTP_HOST}:${SMTP_PORT}...`);

    await client.send({
      from: SMTP_USER,
      to: NOTIFY_TO,
      subject: `[Sugerencia] ${nombre}${provincia ? " - " + provincia : ""}`,
      html,
    });

    await client.close();
    console.log("[notificar-sugerencia] Email enviado a", NOTIFY_TO);

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[notificar-sugerencia] Error:", err);
    await client.close().catch(() => {});

    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
