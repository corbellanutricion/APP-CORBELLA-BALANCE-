// supabase/functions/_shared/reportError.ts
//
// Avisa al coach cuando algo truena de verdad en una Edge Function: deja
// registro en error_logs, le manda push (reusa send-push) y, si hay
// RESEND_API_KEY configurada, también correo. Pensado para llamarse desde
// el catch-all de cada función -- nunca debe tronar él mismo (si el aviso
// de error también fallara, ya no hay forma de enterarse).
//
// Secrets que usa (los primeros 3 ya existen en el proyecto):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, WEBHOOK_SECRET
// Opcional para el correo:
//   RESEND_API_KEY   (gratis en resend.com, sin dominio propio funciona
//                      mandando desde onboarding@resend.dev)
//   COACH_ALERT_EMAIL (si no se pone, cae en corbella.nutricion@gmail.com)

const COACH_USER_ID = "29e3fed0-eb0d-4912-b6b2-9a9b6879d399"; // el único coach de la app (ver CB_SELF_MANAGED_COACH_ID)

export async function reportError(
  source: string,
  err: unknown,
  context?: Record<string, unknown>
) {
  const message = err instanceof Error ? err.message : String(err);
  const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
  const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const WEBHOOK_SECRET = Deno.env.get("WEBHOOK_SECRET") || "";
  const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") || "";
  const COACH_EMAIL = Deno.env.get("COACH_ALERT_EMAIL") || "corbella.nutricion@gmail.com";

  // 1) Bitácora -- para poder revisar el historial después, no solo el aviso al vuelo.
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/error_logs`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify([{ source, message, context: context ?? null }]),
    });
  } catch (_e) {
    // si ni esto se pudo, seguimos con push/correo de todos modos
  }

  // 2) Push al coach -- llega al instante si tiene la app instalada con
  // notificaciones activadas (mismo mecanismo que PushBell).
  try {
    await fetch(`${SUPABASE_URL}/functions/v1/send-push`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-webhook-secret": WEBHOOK_SECRET },
      body: JSON.stringify({
        user_id: COACH_USER_ID,
        title: "⚠️ Error en " + source,
        body: message.slice(0, 140),
        url: "/",
        tag: "error-alert",
      }),
    });
  } catch (_e) {
    // no bloqueamos el aviso por correo si el push falla
  }

  // 3) Correo -- respaldo si no vio el push. Se salta solo si no hay API key
  // configurada (no truena, para no bloquear el resto del aviso).
  if (RESEND_API_KEY) {
    try {
      await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          Authorization: `Bearer ${RESEND_API_KEY}`,
        },
        body: JSON.stringify({
          from: "Corbella Balance <onboarding@resend.dev>",
          to: [COACH_EMAIL],
          subject: `⚠️ Error en ${source} — Corbella Balance`,
          text: `${message}\n\nContexto:\n${JSON.stringify(context ?? {}, null, 2)}\n\nHora: ${new Date().toISOString()}`,
        }),
      });
    } catch (_e) {
      // idem -- un correo fallido no debe tirar la función que lo llamó
    }
  }
}
