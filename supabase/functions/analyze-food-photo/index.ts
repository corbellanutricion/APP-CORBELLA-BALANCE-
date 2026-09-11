// supabase/functions/analyze-food-photo/index.ts
//
// Recibe { imageUrl } y regresa una estimación de alimentos, gramos y
// macros usando la API de Claude (visión). Requiere el secret
// ANTHROPIC_API_KEY configurado en el proyecto de Supabase:
//
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//
// Deploy:
//   supabase functions deploy analyze-food-photo

import { serve } from "https://deno.land/std@0.203.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { reportError } from "../_shared/reportError.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Solo aceptamos fotos que vivan en nuestro propio bucket de Storage
// (así nadie puede usar esta función como "analizador gratis" de fotos ajenas).
// food-photos es un bucket PRIVADO desde 2026-09-11 -- el cliente manda una
// URL FIRMADA (.../object/sign/food-photos/...), ya no la pública de antes.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const FOOD_PHOTOS_PREFIX = `${SUPABASE_URL}/storage/v1/object/sign/food-photos/`;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

// Límite de fotos por paciente por día -- cada llamada le cuesta dinero real
// a la cuenta de Anthropic, esto evita que una sola cuenta (por error o mal
// uso) se acabe el presupuesto. Se resetea a las 00:00 UTC.
const DAILY_PHOTO_LIMIT = 5;

async function countTodayAnalyses(patientId: string): Promise<number> {
  const todayStart = new Date().toISOString().slice(0, 10) + "T00:00:00.000Z";
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/food_photo_analyses?patient_id=eq.${patientId}&created_at=gte.${todayStart}&select=id`,
    { headers: { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}` } }
  );
  if (!res.ok) return 0; // si esto falla, no le bloqueamos la función al paciente por un problema nuestro
  const rows = await res.json();
  return Array.isArray(rows) ? rows.length : 0;
}

async function recordAnalysisAttempt(patientId: string) {
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/food_photo_analyses`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify([{ patient_id: patientId }]),
    });
  } catch (_e) {
    // si el conteo falla, seguimos con el análisis de todos modos
  }
}

const PROMPT = `Eres un asistente de nutrición. Analiza la foto de este platillo y responde
SOLO con un JSON válido (sin texto adicional, sin markdown), con esta forma exacta:

{
  "items": [
    { "name": "nombre del alimento en español", "grams": 150, "kcal": 250, "protein": 30, "carbs": 0, "fat": 12 }
  ],
  "totals": { "kcal": 250, "protein": 30, "carbs": 0, "fat": 12 },
  "confidence": "alta" | "media" | "baja",
  "notes": "nota breve si algo es difícil de estimar (ej. platillo con salsa, no se ve todo el contenido)"
}

Instrucciones:
- Estima porciones de forma realista según lo que se ve en la imagen (usa referencias visuales como el tamaño del plato).
- Si es un platillo mexicano compuesto (ej. mole, guisado, tacos), intenta separar sus componentes principales.
- Si no puedes distinguir bien un ingrediente (ej. oculto en salsa), dilo en "notes" y baja el "confidence".
- Los números de "totals" deben ser la suma de los items.
- Responde en español.`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  // Declarado fuera del try para que el catch-all (y el aviso al coach) lo
  // pueda incluir como contexto aunque el error haya pasado después.
  let imageUrl: string | undefined;

  try {
    // Debe venir de un usuario logueado de la app (el cliente de Supabase manda
    // este header automáticamente al usar functions.invoke(...)).
    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) {
      return new Response(JSON.stringify({ error: "No autorizado." }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
    const supabase = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY") || "");
    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return new Response(JSON.stringify({ error: "Sesión inválida." }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    ({ imageUrl } = await req.json());
    if (!imageUrl) {
      return new Response(JSON.stringify({ error: "Falta imageUrl" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
    if (!imageUrl.startsWith(FOOD_PHOTOS_PREFIX)) {
      return new Response(JSON.stringify({ error: "URL de imagen no permitida." }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({
          error: "ANTHROPIC_API_KEY no está configurada todavía en este proyecto de Supabase.",
        }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const patientId = userData.user.id;
    const usedToday = await countTodayAnalyses(patientId);
    if (usedToday >= DAILY_PHOTO_LIMIT) {
      return new Response(
        JSON.stringify({
          error: `Ya usaste tus ${DAILY_PHOTO_LIMIT} fotos de hoy para registrar comida con IA. Mañana puedes seguir usándolo, o registra esta comida a mano mientras tanto.`,
        }),
        { status: 429, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Descargamos la imagen y la mandamos como base64 (la API de Claude
    // acepta imágenes por base64 directamente, evitando problemas de acceso
    // si la URL pública tuviera restricciones).
    const imgRes = await fetch(imageUrl);
    if (!imgRes.ok) {
      return new Response(JSON.stringify({ error: "No se pudo descargar la imagen." }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
    const imgBuffer = await imgRes.arrayBuffer();
    // Nota: NO usar String.fromCharCode(...new Uint8Array(buf)) -- con una
    // foto de celular normal (varios MB) revienta el límite de argumentos
    // del motor de JS ("Maximum call stack size exceeded"). Por eso vamos
    // por bloques.
    const imgBytes = new Uint8Array(imgBuffer);
    let imgBinary = "";
    const CHUNK_SIZE = 0x8000; // 32768 bytes por bloque -- muy por debajo del límite
    for (let i = 0; i < imgBytes.length; i += CHUNK_SIZE) {
      imgBinary += String.fromCharCode(...imgBytes.subarray(i, i + CHUNK_SIZE));
    }
    const imgBase64 = btoa(imgBinary);
    const mediaType = imgRes.headers.get("content-type") || "image/jpeg";

    // Se registra el intento AQUÍ, justo antes de llamar a Claude -- así el
    // límite refleja uso real de la API (lo que de verdad cuesta dinero),
    // no fotos que ni siquiera llegaron a analizarse.
    await recordAnalysisAttempt(patientId);

    const claudeRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001", // el más barato — suficiente para esta tarea
        max_tokens: 1000,
        messages: [
          {
            role: "user",
            content: [
              { type: "image", source: { type: "base64", media_type: mediaType, data: imgBase64 } },
              { type: "text", text: PROMPT },
            ],
          },
        ],
      }),
    });

    if (!claudeRes.ok) {
      const errText = await claudeRes.text();
      // Esto le pega a CUALQUIER foto mientras dure (API key revocada, sin
      // saldo, rate limit, etc.) -- vale la pena que el coach se entere ya,
      // no hasta que varios pacientes se quejen.
      await reportError("analyze-food-photo (Claude)", errText, { imageUrl, status: claudeRes.status });
      return new Response(JSON.stringify({ error: "Error de la API de Claude: " + errText }), {
        status: 502,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const claudeData = await claudeRes.json();
    const textBlock = (claudeData.content || []).find((b: any) => b.type === "text");
    const raw = textBlock ? textBlock.text : "{}";

    // Limpieza por si Claude envuelve el JSON en ```json ... ```
    const cleaned = raw.replace(/```json|```/g, "").trim();
    let parsed;
    try {
      parsed = JSON.parse(cleaned);
    } catch (_e) {
      // Claude dejó de responder en el formato esperado -- también vale la
      // pena saberlo pronto (puede ser un cambio de modelo, no solo un
      // platillo raro).
      await reportError("analyze-food-photo (parse)", _e, { imageUrl, raw: cleaned.slice(0, 500) });
      return new Response(
        JSON.stringify({ error: "No se pudo interpretar la respuesta de la IA.", raw: cleaned }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify(parsed), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (e) {
    // Este es justo el que atrapó el bug de "Maximum call stack size
    // exceeded" -- cualquier cosa no prevista cae aquí, así que es el punto
    // más importante para avisar.
    await reportError("analyze-food-photo", e, { imageUrl });
    return new Response(JSON.stringify({ error: e.message || "Error inesperado." }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
