import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

const groqApiKey = defineSecret("GROQ_API_KEY");

import {
  CONTRACT_VERSION,
  buildSystemPrompt,
  forbiddenJsToken,
  normalizeOversizedNumericLiterals,
  sanitizePrompt,
  fallbackSdf,
} from "./sdfUtils";

export const generateSdfHttp = onRequest(
  {
    region: "us-central1",
    cors: false, // we set headers ourselves
    timeoutSeconds: 20,
    memory: "256MiB",
    secrets: [groqApiKey],
  },
  async (req, res) => {
    // CORS preflight
    if (req.method === "OPTIONS") {
      res.set(corsHeaders);
      res.status(204).send("");
      return;
    }

    res.set(corsHeaders);

    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    let body: any = req.body;
    if (typeof body === "string") {
      try {
        body = JSON.parse(body);
      } catch {
        // ignore
      }
    }

    const prompt = sanitizePrompt(body?.prompt);
    if (!prompt) {
      res.status(400).json({ error: "prompt is required" });
      return;
    }

    const GROQ_API_KEY = groqApiKey.value() ?? "";
    if (!GROQ_API_KEY) {
      res.status(200).json(fallbackSdf(prompt, "no-key"));
      return;
    }

    const url = "https://api.groq.com/openai/v1/chat/completions";
    const model = "llama-3.3-70b-versatile";
    const systemPrompt = buildSystemPrompt();

    const groqBody = {
      model,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: `Prompt: \"${prompt}\"` },
      ],
      response_format: { type: "json_object" },
      temperature: 0.2,
    };

    try {
      const resp = await fetch(url, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${GROQ_API_KEY}`,
        },
        body: JSON.stringify(groqBody),
      });

      if (!resp.ok) {
        res.status(200).json(fallbackSdf(prompt, `groq-http-${resp.status}`));
        return;
      }

      const root = (await resp.json()) as any;
      const content = root?.choices?.[0]?.message?.content;
      if (typeof content !== "string") {
        res.status(200).json(fallbackSdf(prompt, "missing-content"));
        return;
      }

      let parsed: any;
      try {
        parsed = JSON.parse(content);
      } catch {
        res.status(200).json(fallbackSdf(prompt, "invalid-json"));
        return;
      }

      const kind = typeof parsed?.kind === "string" ? parsed.kind.trim().toLowerCase() : "object";
      const spatial_logic = typeof parsed?.spatial_logic === "string" ? parsed.spatial_logic.trim() : "";
      const sdf_javascript = typeof parsed?.sdf_javascript === "string" ? parsed.sdf_javascript : "";
      if (!sdf_javascript || !sdf_javascript.includes("function sdf")) {
        res.status(200).json(fallbackSdf(prompt, "invalid-sdf"));
        return;
      }

      const forbiddenToken = forbiddenJsToken(sdf_javascript);
      if (forbiddenToken) {
        res.status(200).json(fallbackSdf(prompt, `forbidden-js-${forbiddenToken}`));
        return;
      }

      // Primitive count check removed to allow arbitrary AI generations to succeed without arbitrary complexity constraints.

      const normalized = normalizeOversizedNumericLiterals(sdf_javascript);

      res.status(200).json({
        kind: kind || "object",
        spatial_logic: spatial_logic.slice(0, 240),
        sdf_javascript: normalized.js.slice(0, 6000),
        model,
        is_fallback: false,
        contract_version: CONTRACT_VERSION,
        fallback_reason: null,
      });
    } catch {
      res.status(200).json(fallbackSdf(prompt, "exception"));
    }
  }
);
