// supabase/functions/import-usda-foods-chunk/index.ts
//
// Herramienta de UNA SOLA VEZ para ampliar el catálogo de alimentos con datos
// de USDA FoodData Central (SR Legacy, ~7,800 alimentos genéricos). No es
// parte de la app -- la corre un script local (ver scratchpad de la sesión
// que la creó), nunca se llama desde el front.
//
// Recibe un lote de alimentos en inglés (ya extraídos de los CSV de USDA:
// nombre, categoría USDA, macros por 100g, y opcionalmente una medida casera),
// los traduce y categoriza con Claude (agrupados de 20 en 20 para no gastar
// una llamada por alimento), y los inserta en `foods` -- salta los que ya
// existan por `usda_fdc_id` (ON CONFLICT DO NOTHING), así es seguro
// reintentar un lote si se cortó a la mitad.
//
// Auth: header `x-import-secret` contra el secret IMPORT_ADMIN_SECRET
// (generado solo para esta importación, NO es el WEBHOOK_SECRET de la app).
//
// Deploy:
//   supabase functions deploy import-usda-foods-chunk

import { serve } from "https://deno.land/std@0.203.0/http/server.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, x-import-secret",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const IMPORT_ADMIN_SECRET = Deno.env.get("IMPORT_ADMIN_SECRET") || "";

// Los 7 grupos de equivalentes que ya usa el editor de plan (EQ_GROUPS) + 'otro'
// para lo que no encaja bien (bebidas, especias, alcohol, platillos mixtos).
const VALID_CATEGORIES = ["carbohidrato", "proteina", "lacteo", "grasa", "verdura", "fruta", "azucar", "otro"];

type RawItem = {
  fdc_id: number; name_en: string; cat_en: string;
  kcal: number; protein: number; fat: number; carbs: number;
  portion_g: number | null; measure_en: string | null;
};

type Translated = {
  fdc_id: number; name: string; category: string; measure_es: string | null;
};

async function translateGroup(items: RawItem[], apiKey: string): Promise<Translated[]> {
  const lines = items.map((it) =>
    `${it.fdc_id} | ${it.name_en} | categoría USDA: ${it.cat_en}` +
    (it.measure_en ? ` | medida: ${it.measure_en}` : "")
  ).join("\n");

  const prompt = `Traduce estos alimentos del catálogo USDA (inglés) a nombres naturales en español (como los diría un nutriólogo mexicano) y asígnales UNA categoría de esta lista exacta: ${VALID_CATEGORIES.join(", ")}.

Guía de categorías (sistema de equivalentes / intercambios):
- carbohidrato: cereales, pan, pasta, tortilla, arroz, papa, avena
- proteina: carnes, pescado, mariscos, huevo, leguminosas como fuente proteica
- lacteo: leche, yogurt, queso
- grasa: aceites, mantequilla, nueces, semillas, aguacate
- verdura: vegetales no feculentos
- fruta: frutas
- azucar: dulces, postres, mieles, refrescos azucarados
- otro: bebidas sin calorías relevantes, especias, condimentos, alcohol, platillos mixtos/preparados que no encajan en un solo grupo

Alimentos (fdc_id | nombre en inglés | categoría USDA | medida casera si hay):
${lines}

Responde SOLO con JSON válido, sin texto adicional ni markdown, un array con esta forma exacta (un objeto por cada fdc_id de la lista, en el mismo orden):
[{ "fdc_id": 167512, "name": "nombre en español", "category": "una de la lista", "measure_es": "medida casera traducida o null" }]`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": apiKey, "anthropic-version": "2023-06-01" },
    body: JSON.stringify({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 2000,
      messages: [{ role: "user", content: prompt }],
    }),
  });
  if (!res.ok) throw new Error("Claude error: " + (await res.text()));
  const data = await res.json();
  const textBlock = (data.content || []).find((b: any) => b.type === "text");
  const raw = textBlock ? textBlock.text : "[]";
  const cleaned = raw.replace(/```json|```/g, "").trim();
  const parsed = JSON.parse(cleaned);
  if (!Array.isArray(parsed)) throw new Error("Respuesta de Claude no fue un array");
  return parsed;
}

function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });

  try {
    if (!IMPORT_ADMIN_SECRET || req.headers.get("x-import-secret") !== IMPORT_ADMIN_SECRET) {
      return new Response(JSON.stringify({ error: "No autorizado." }), {
        status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return new Response(JSON.stringify({ error: "ANTHROPIC_API_KEY no configurada." }), {
        status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();

    // Modo de verificación rápida (sin llamar a Claude): regresa cuántas filas
    // usda_fdc_id existen ya en `foods`, o una muestra de ellas si se piden ids.
    if (body.peek) {
      const q = body.peek_fdc_ids && body.peek_fdc_ids.length
        ? `usda_fdc_id=in.(${body.peek_fdc_ids.join(",")})`
        : `usda_fdc_id=not.is.null&limit=5`;
      const countRes = await fetch(`${SUPABASE_URL}/rest/v1/foods?select=id&usda_fdc_id=not.is.null`, {
        headers: { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}`, Prefer: "count=exact" },
      });
      const countHeader = countRes.headers.get("content-range") || "";
      const sampleRes = await fetch(`${SUPABASE_URL}/rest/v1/foods?select=*&${q}`, {
        headers: { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}` },
      });
      const sample = await sampleRes.json();
      return new Response(JSON.stringify({ total_usda_rows: countHeader, sample }), {
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const items: RawItem[] = body.items || [];
    if (!items.length) {
      return new Response(JSON.stringify({ error: "Falta items." }), {
        status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const byId = new Map(items.map((it) => [it.fdc_id, it]));
    const groups = chunk(items, 20);
    const rows: Record<string, unknown>[] = [];
    const errors: string[] = [];

    for (const group of groups) {
      try {
        const translated = await translateGroup(group, apiKey);
        for (const t of translated) {
          const src = byId.get(t.fdc_id);
          if (!src) continue;
          const category = VALID_CATEGORIES.includes(t.category) ? t.category : "otro";
          rows.push({
            id: "usda" + t.fdc_id,
            name: t.name || src.name_en,
            category,
            kcal: src.kcal, protein: src.protein, carbs: src.carbs, fat: src.fat,
            base_unit: "g",
            household_measure: t.measure_es || null,
            household_measure_g: src.portion_g,
            portion_g: src.portion_g,
            usda_fdc_id: src.fdc_id,
          });
        }
      } catch (e) {
        errors.push((e as Error).message);
      }
    }

    if (!rows.length) {
      return new Response(JSON.stringify({ inserted: 0, skipped: 0, errors }), {
        status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const insertRes = await fetch(`${SUPABASE_URL}/rest/v1/foods?on_conflict=usda_fdc_id`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        Prefer: "resolution=ignore-duplicates,return=minimal",
      },
      body: JSON.stringify(rows),
    });
    if (!insertRes.ok) {
      errors.push("Insert error: " + (await insertRes.text()));
    }

    return new Response(JSON.stringify({ inserted: rows.length, attempted: items.length, errors }), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message || "Error inesperado." }), {
      status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
