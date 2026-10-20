// PackSmart 後端：一個 Worker 兩件事。
//   GET  /reference/v1/*  參考資料（Workers 靜態檔案直接回應，不經過這支程式）
//   POST /v1/trivia       小史萊姆 AI 冷知識的 Claude 轉發，金鑰只存在 Worker secret
//
// 防濫用：只接受 SeedData 裡存在的國家／城市（Worker 自己組 prompt，不能當通用 Claude 入口），
// 結果以 KV 快取 7 天，實際生成次數受每日上限約束。任何失敗都回 503，App 退回內建冷知識。
import Anthropic from "@anthropic-ai/sdk";
import cities from "../../../TravelGenius/Resources/SeedData/cities.json";
import countries from "../../../TravelGenius/Resources/SeedData/countries.json";

interface Env {
  ANTHROPIC_API_KEY: string;
  TRIVIA: KVNamespace;
  DAILY_GENERATION_LIMIT: string;
}

const MODEL = "claude-haiku-5-5";
const CACHE_TTL_SECONDS = 7 * 24 * 60 * 60;
const FACT_COUNT = 5;

const countryNames = new Map(countries.map((c) => [c.code, c.nameZh]));
// 只有 SeedData 裡有城市的國家才能查冷知識；city 為空字串代表整個國家。
const allowedPlaces = new Set(cities.flatMap((c) => [`${c.countryCode}:`, `${c.countryCode}:${c.cityZh}`]));

export default {
  async fetch(request, env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/health") return json({ ok: true });
    if (url.pathname !== "/v1/trivia") return json({ error: "not_found" }, 404);
    if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

    const body = await request.json<{ countryCode?: unknown; city?: unknown }>().catch(() => null);
    const countryCode = typeof body?.countryCode === "string" ? body.countryCode : "";
    const city = typeof body?.city === "string" ? body.city : "";
    const countryName = countryNames.get(countryCode);
    if (!countryName || !allowedPlaces.has(`${countryCode}:${city}`)) {
      return json({ error: "unsupported_place" }, 400);
    }

    const cacheKey = `trivia:v1:${countryCode}:${city}`;
    const cached = await env.TRIVIA.get<string[]>(cacheKey, "json");
    if (cached) return json({ facts: cached });

    if (!(await takeDailyQuota(env))) return json({ error: "daily_limit" }, 503);

    try {
      const facts = await generateFacts(env, city ? `${countryName}${city}` : countryName);
      await env.TRIVIA.put(cacheKey, JSON.stringify(facts), { expirationTtl: CACHE_TTL_SECONDS });
      return json({ facts });
    } catch (error) {
      if (error instanceof Anthropic.RateLimitError) console.warn("Anthropic rate limited");
      else if (error instanceof Anthropic.APIError) console.error(`Anthropic API error ${error.status}: ${error.message}`);
      else console.error("Trivia generation failed", error);
      return json({ error: "upstream_unavailable" }, 503);
    }
  },
} satisfies ExportedHandler<Env>;

/// KV 計數是最終一致的粗略上限；真正的費用保險是 Anthropic Console 的月費上限。
async function takeDailyQuota(env: Env): Promise<boolean> {
  const limit = Number.parseInt(env.DAILY_GENERATION_LIMIT, 10) || 0;
  const key = `quota:${new Date().toISOString().slice(0, 10)}`;
  const used = Number.parseInt((await env.TRIVIA.get(key)) ?? "0", 10);
  if (used >= limit) return false;
  await env.TRIVIA.put(key, String(used + 1), { expirationTtl: 2 * 24 * 60 * 60 });
  return true;
}

async function generateFacts(env: Env, place: string): Promise<string[]> {
  const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, timeout: 25_000, maxRetries: 1 });
  // Haiku 5.5 沒有伺服器端 fallback：被拒絕時 stop_reason 是 refusal，下面會當失敗處理。
  const response = await client.messages.create({
    model: MODEL,
    max_tokens: 4096,
    output_config: {
      effort: "low",
      format: {
        type: "json_schema",
        schema: {
          type: "object",
          properties: { facts: { type: "array", items: { type: "string" } } },
          required: ["facts"],
          additionalProperties: false,
        },
      },
    },
    messages: [
      {
        role: "user",
        content:
          `你是旅遊 App 的吉祥物「小史萊姆」。請提供 ${FACT_COUNT} 則關於「${place}」旅遊的冷知識，` +
          "主題涵蓋當地文化、交通、食物或習俗，內容要冷門有趣、對旅客實用。" +
          "每則 20 到 45 個字、繁體中文、語氣口語可愛，不要編號。",
      },
    ],
  });
  if (response.stop_reason !== "end_turn") throw new Error(`Unexpected stop_reason ${response.stop_reason}`);

  const text = response.content.find((block) => block.type === "text")?.text ?? "";
  const facts = (JSON.parse(text) as { facts: unknown[] }).facts
    .filter((fact): fact is string => typeof fact === "string" && fact.trim().length > 0)
    .map((fact) => fact.trim())
    .slice(0, FACT_COUNT);
  if (facts.length === 0) throw new Error("Model returned no facts");
  return facts;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}
