// supabase/functions/generate-meal-from-description/index.ts
//
// "Componer platillo con IA": el coach describe un platillo en texto libre
// (ej. "desayuno con chilaquiles y crema") para un tiempo de comida de un
// paciente, y esta función regresa qué alimentos del catálogo (y en qué
// cantidad, en gramos) lo componen para cuadrar lo más posible con el
// objetivo de kcal/macros de ESE tiempo de comida -- el mismo objetivo que
// ya calcula el editor de plan (peso 1 por tiempo normal, 0.4 para
// "Colación", o el reparto de "equivalentes" si ese tiempo los usa). El
// objetivo llega YA calculado desde el front (no se duplica esa fórmula
// aquí) para no tener dos fuentes de verdad del cálculo.
//
// Requiere el secret ANTHROPIC_API_KEY (ya configurado para
// analyze-food-photo, se reusa).
//
// Deploy:
//   supabase functions deploy generate-meal-from-description

import { serve } from "https://deno.land/std@0.203.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { reportError } from "../_shared/reportError.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// El único coach de la app (ver reportError.ts) -- esta función es de uso
// exclusivo del coach (arma platillos DENTRO del editor de plan), un
// paciente nunca debería poder invocarla.
const COACH_USER_ID = "29e3fed0-eb0d-4912-b6b2-9a9b6879d399";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const STOPWORDS = new Set([
  "de", "la", "el", "los", "las", "con", "y", "en", "un", "una", "para", "sin",
  "del", "al", "más", "poco", "poca", "extra", "porción", "plato",
]);

function keywordsFrom(description: string): string[] {
  const words = description
    .toLowerCase()
    .normalize("NFD").replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length >= 4 && !STOPWORDS.has(w));
  return [...new Set(words)].slice(0, 6);
}

type FoodRow = {
  id: string; name: string; category: string | null;
  kcal: number; protein: number; carbs: number; fat: number;
  base_unit: string | null; portion_g: number | null; household_measure: string | null;
};

async function fetchCandidateFoods(description: string): Promise<FoodRow[]> {
  const cols = "id,name,category,kcal,protein,carbs,fat,base_unit,portion_g,household_measure";
  const kws = keywordsFrom(description);
  if (kws.length) {
    const orExpr = kws.map((k) => `name.ilike.*${encodeURIComponent(k)}*`).join(",");
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/foods?select=${cols}&or=(${orExpr})&limit=60`,
      { headers: { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}` } }
    );
    if (res.ok) {
      const rows = await res.json();
      if (Array.isArray(rows) && rows.length >= 5) return rows;
      // pocas coincidencias por palabra clave -- seguimos al catálogo completo abajo,
      // pero conservamos estas para no perder matches exactos si el catálogo es enorme.
      if (Array.isArray(rows) && rows.length) {
        const fallback = await fetchWholeCatalog(cols);
        const seen = new Set(rows.map((r: FoodRow) => r.id));
        return [...rows, ...fallback.filter((f) => !seen.has(f.id))];
      }
    }
  }
  return fetchWholeCatalog(cols);
}

async function fetchWholeCatalog(cols: string): Promise<FoodRow[]> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/foods?select=${cols}&order=name&limit=600`,
    { headers: { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}` } }
  );
  if (!res.ok) return [];
  const rows = await res.json();
  return Array.isArray(rows) ? rows : [];
}

async function patientBelongsToCoach(patientId: string): Promise<boolean> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/patients?id=eq.${patientId}&coach_id=eq.${COACH_USER_ID}&select=id`,
    { headers: { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}` } }
  );
  if (!res.ok) {
    // Un permission-denied (falta GRANT) u otro error real de la consulta NO es lo
    // mismo que "no encontré al paciente" -- si lo tratamos igual, un problema de
    // permisos se ve exactamente como un typo de patientId, y nadie se entera.
    throw new Error("No se pudo verificar el paciente: " + (await res.text()));
  }
  const rows = await res.json();
  return Array.isArray(rows) && rows.length > 0;
}

const round1 = (n: number) => Math.round(n * 10) / 10;

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });

  let description: string | undefined;

  try {
    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) {
      return new Response(JSON.stringify({ error: "No autorizado." }), {
        status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
    const supabase = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY") || "");
    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return new Response(JSON.stringify({ error: "Sesión inválida." }), {
        status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
    if (userData.user.id !== COACH_USER_ID) {
      return new Response(JSON.stringify({ error: "Esta función es solo para el coach." }), {
        status: 403, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const patientId = body.patientId as string | undefined;
    description = body.description as string | undefined;
    const target = body.target as { kcal?: number; protein?: number; carbs?: number; fat?: number } | undefined;

    if (!patientId || !description || !description.trim()) {
      return new Response(JSON.stringify({ error: "Falta patientId o description." }), {
        status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
    if (description.length > 200) {
      return new Response(JSON.stringify({ error: "Descripción demasiado larga (máx. 200 caracteres)." }), {
        status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
    if (!target || !target.kcal || target.kcal <= 0) {
      return new Response(JSON.stringify({ error: "Falta el objetivo de kcal de este tiempo de comida (calcula el plan primero)." }), {
        status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
    if (!(await patientBelongsToCoach(patientId))) {
      return new Response(JSON.stringify({ error: "Paciente no encontrado." }), {
        status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return new Response(JSON.stringify({ error: "ANTHROPIC_API_KEY no está configurada." }), {
        status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const candidates = await fetchCandidateFoods(description);
    const candidateLines = candidates.map((f) =>
      `${f.id} | ${f.name} | ${f.kcal}kcal/${f.protein}gP/${f.carbs}gC/${f.fat}gF por 100${f.base_unit || "g"}` +
      (f.household_measure ? ` | medida casera: ${f.household_measure}` : "")
    ).join("\n");

    const prompt = `Eres un asistente de nutrición armando un platillo real a partir de una descripción del coach.

Descripción del platillo: "${description}"

Objetivo nutrimental de este tiempo de comida (debes acercarte lo más posible):
kcal: ${Math.round(target.kcal)}, proteína: ${Math.round(target.protein || 0)}g, carbohidratos: ${Math.round(target.carbs || 0)}g, grasa: ${Math.round(target.fat || 0)}g

Alimentos disponibles en el catálogo (usa estos siempre que representen bien un ingrediente del platillo; sus macros son por 100g o por la unidad indicada):
${candidateLines || "(catálogo vacío)"}

Instrucciones:
- Descompón el platillo en sus ingredientes reales (ej. "chilaquiles con crema" = tortilla frita/totopo + salsa + crema, y si aplica pollo o queso agrégalo solo si la descripción lo sugiere).
- Para cada ingrediente, PREFIERE un alimento del catálogo de arriba (usa su "id" tal cual). Si de verdad ningún alimento del catálogo representa ese ingrediente, decláralo como nuevo con sus macros estimados por 100g (usa tu conocimiento nutricional, sé realista).
- Calcula los gramos de cada ingrediente para que la SUMA se acerque lo más posible al objetivo (prioriza acertar kcal y proteína).
- No uses más de 6 ingredientes. No inventes un ingrediente que no tenga sentido con la descripción.
- Responde SOLO con JSON válido, sin texto adicional ni markdown, con esta forma exacta:

{
  "items": [
    { "source": "catalogo", "foodId": "<id exacto del catálogo>", "name": "nombre", "qty_g": 80 },
    { "source": "nuevo", "name": "nombre del ingrediente", "qty_g": 30, "kcal_100g": 195, "protein_100g": 2.1, "carbs_100g": 3.4, "fat_100g": 20 }
  ],
  "notes": "nota breve si algo no cuadró exacto o si un ingrediente no estaba en el catálogo"
}`;

    const claudeRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001", // tarea estructurada, no necesita un modelo caro
        max_tokens: 800,
        messages: [{ role: "user", content: prompt }],
      }),
    });

    if (!claudeRes.ok) {
      const errText = await claudeRes.text();
      await reportError("generate-meal-from-description (Claude)", errText, { description, status: claudeRes.status });
      return new Response(JSON.stringify({ error: "Error de la API de Claude: " + errText }), {
        status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const claudeData = await claudeRes.json();
    const textBlock = (claudeData.content || []).find((b: any) => b.type === "text");
    const raw = textBlock ? textBlock.text : "{}";
    const cleaned = raw.replace(/```json|```/g, "").trim();

    let parsed: { items?: any[]; notes?: string };
    try {
      parsed = JSON.parse(cleaned);
    } catch (_e) {
      await reportError("generate-meal-from-description (parse)", _e, { description, raw: cleaned.slice(0, 500) });
      return new Response(JSON.stringify({ error: "No se pudo interpretar la respuesta de la IA." }), {
        status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const candidateById = new Map(candidates.map((f) => [f.id, f]));
    const matched: { foodId: string; name: string; qty_g: number }[] = [];
    const unmatched: { name: string; qty_g: number; kcal: number; protein: number; carbs: number; fat: number }[] = [];
    const totals = { kcal: 0, protein: 0, carbs: 0, fat: 0 };
    const notes: string[] = [];

    for (const item of parsed.items || []) {
      const qty = parseFloat(item?.qty_g);
      if (!item || !qty || qty <= 0) continue;

      if (item.source === "catalogo" && item.foodId && candidateById.has(item.foodId)) {
        const f = candidateById.get(item.foodId)!;
        const k = qty / 100;
        totals.kcal += (f.kcal || 0) * k;
        totals.protein += (f.protein || 0) * k;
        totals.carbs += (f.carbs || 0) * k;
        totals.fat += (f.fat || 0) * k;
        matched.push({ foodId: f.id, name: f.name, qty_g: Math.round(qty) });
        continue;
      }

      const k100 = {
        kcal: parseFloat(item?.kcal_100g), protein: parseFloat(item?.protein_100g),
        carbs: parseFloat(item?.carbs_100g), fat: parseFloat(item?.fat_100g),
      };
      if (item?.name && !isNaN(k100.kcal)) {
        const k = qty / 100;
        const abs = {
          kcal: round1((k100.kcal || 0) * k), protein: round1((k100.protein || 0) * k),
          carbs: round1((k100.carbs || 0) * k), fat: round1((k100.fat || 0) * k),
        };
        totals.kcal += abs.kcal; totals.protein += abs.protein; totals.carbs += abs.carbs; totals.fat += abs.fat;
        unmatched.push({ name: item.name, qty_g: Math.round(qty), ...abs });
      } else if (item?.name) {
        notes.push(`No se pudo calcular "${item.name}" (faltaron macros).`);
      }
    }

    if (!matched.length && !unmatched.length) {
      return new Response(JSON.stringify({ error: "La IA no propuso ningún ingrediente utilizable. Intenta describirlo distinto." }), {
        status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({
      matched, unmatched,
      totals: { kcal: Math.round(totals.kcal), protein: round1(totals.protein), carbs: round1(totals.carbs), fat: round1(totals.fat) },
      target: { kcal: Math.round(target.kcal), protein: Math.round(target.protein || 0), carbs: Math.round(target.carbs || 0), fat: Math.round(target.fat || 0) },
      notes: [parsed.notes, ...notes].filter(Boolean).join(" "),
    }), { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });

  } catch (e) {
    await reportError("generate-meal-from-description", e, { description });
    return new Response(JSON.stringify({ error: e.message || "Error inesperado." }), {
      status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
