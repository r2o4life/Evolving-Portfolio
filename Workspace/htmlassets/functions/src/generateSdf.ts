import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

const groqApiKey = defineSecret("GROQ_API_KEY");

import {
  GenerateSdfOutput,
  CONTRACT_VERSION,
  buildSystemPrompt,
  forbiddenJsToken,
  normalizeOversizedNumericLiterals,
  sanitizePrompt,
  fallbackSdf,
} from "./sdfUtils";

type GenerateSdfInput = {
  prompt?: unknown;
};

export const generateSdf = onCall(
  {
    // Keep it explicit; you can change regions later.
    region: "us-central1",
    // Basic hardening.
    enforceAppCheck: false,
    cors: true,
    timeoutSeconds: 20,
    memory: "256MiB",
    secrets: [groqApiKey],
  },
  async (request): Promise<GenerateSdfOutput> => {
    const prompt = sanitizePrompt((request.data as GenerateSdfInput | undefined)?.prompt);
    if (!prompt) throw new HttpsError("invalid-argument", "prompt is required");

    // Production-safe: API key lives ONLY on the server.
    // If not configured, we still return a deterministic fallback so UX stays functional.
    const GROQ_API_KEY = groqApiKey.value() ?? "";
    if (!GROQ_API_KEY) return fallbackSdf(prompt, "no-key");

    // Groq "OpenAI-compatible" endpoint.
    const url = "https://api.groq.com/openai/v1/chat/completions";

    const systemPrompt = buildSystemPrompt();

    const model = "llama-3.3-70b-versatile";

    const body = {
      model,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: `Prompt: \"${prompt}\"` },
      ],
      response_format: { type: "json_object" },
      temperature: 0.2,
    };

    const resp = await fetch(url, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify(body),
    });

    if (!resp.ok) {
      // Avoid attaching numeric `details` (can deserialize as int64/Long and
      // break dart2js on web). Return a deterministic fallback instead.
      return fallbackSdf(prompt, `groq-http-${resp.status}`);
    }

    const root = (await resp.json()) as any;
    const content = root?.choices?.[0]?.message?.content;
    if (typeof content !== "string") return fallbackSdf(prompt, "missing-content");

    let parsed: any;
    try {
      parsed = JSON.parse(content);
    } catch {
      return fallbackSdf(prompt, "invalid-json");
    }

    const kind = typeof parsed?.kind === "string" ? parsed.kind.trim().toLowerCase() : "object";
    const spatial_logic = typeof parsed?.spatial_logic === "string" ? parsed.spatial_logic.trim() : "";
    const sdf_javascript = typeof parsed?.sdf_javascript === "string" ? parsed.sdf_javascript : "";

    if (!sdf_javascript || !sdf_javascript.includes("function sdf")) return fallbackSdf(prompt, "invalid-sdf");

    const forbiddenToken = forbiddenJsToken(sdf_javascript);
    if (forbiddenToken) return fallbackSdf(prompt, `forbidden-js-${forbiddenToken}`);

    // Primitive count check removed to allow arbitrary AI generations to succeed without arbitrary complexity constraints.

    const normalized = normalizeOversizedNumericLiterals(sdf_javascript);

    // Light server-side sanity limit.
    const safeJs = normalized.js.slice(0, 6000);

    return {
      kind: kind || "object",
      spatial_logic: spatial_logic.slice(0, 240),
      sdf_javascript: safeJs,
      model,
      is_fallback: false,
      contract_version: CONTRACT_VERSION,
      fallback_reason: null,
    };
  }
);
