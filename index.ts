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

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

  try {
    const { imageUrl } = await req.json();
    if (!imageUrl) {
      return new Response(JSON.stringify({ error: "Falta imageUrl" }), {
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
    const imgBase64 = btoa(String.fromCharCode(...new Uint8Array(imgBuffer)));
    const mediaType = imgRes.headers.get("content-type") || "image/jpeg";

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
      return new Response(
        JSON.stringify({ error: "No se pudo interpretar la respuesta de la IA.", raw: cleaned }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify(parsed), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message || "Error inesperado." }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
