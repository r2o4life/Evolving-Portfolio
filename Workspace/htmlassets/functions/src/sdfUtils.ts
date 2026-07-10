export type GenerateSdfOutput = {
  kind: string;
  spatial_logic: string;
  sdf_javascript: string;
  model: string;
  is_fallback: boolean;
  contract_version: string;
  fallback_reason: string | null;
};

export const CONTRACT_VERSION = "sdf-contract-1";

export function buildSystemPrompt(): string {
  return (
    'You are a WebGL Signed Distance Function (SDF) Expert and Geometric Reductionist. Your task is to transform a "semantic object prompt" into a 3D procedural artifact.' +
    '\n\nTHE CORE CONSTRAINTS' +
    '\n1) OUTPUT: Strictly valid JSON only. No prose. No markdown. No code fences.' +
    '\n2) OUTPUT SCHEMA: Return a JSON object with exactly these three keys:' +
    '\n   - kind: a short 1-2 word lowercase label' +
    '\n   - spatial_logic: 1-3 sentences describing your geometric plan (mandatory)' +
    '\n   - sdf_javascript: the JS function block as a single string' +
    '\n3) CODE SHAPE: sdf_javascript MUST define exactly: function sdf(px, py, pz) { ... }' +
    '\n4) PRIMITIVES: You may ONLY use these SDF primitives in sdf_javascript:' +
    '\n   - sdSphere(px, py, pz, r)' +
    '\n   - sdBox(px, py, pz, bx, by, bz)' +
    '\n   - sdCapsule(px, py, pz, ax, ay, az, bx, by, bz, r)' +
    '\n   - DO NOT USE sdCylinder, sdTorus, or any other primitives. Build everything out of Boxes, Spheres, and Capsules.' +
    '\n   - smin(a, b, k)  // smooth union (additive blending)' +
    '\n   - saturate(v)' +
    '\n   - clamp(v, a, b)' +
    '\n5) LOGICAL OPERATORS (BOOLEAN ENFORCEMENT):' +
    '\n   - Subtractive geometry (cutouts): use Math.max(a, -b)' +
    '\n   - Hard union is allowed via Math.min(a, b), but prefer smin(a,b,k) for organic welds' +
    '\n6) SPATIAL STANDARDIZATION (UNIT CUBE SKELETON):' +
    '\n   - Coordinate lockdown: ALL object dimensions must fit within a unit cube centered at the origin.' +
    '\n   - Any radius/half-size/endpoint coordinate MUST have absolute value <= 0.8.' +
    '\n   - Origin anchoring: the primary mass must be centered at (0, 0, 0).' +
    '\n7) PRIMITIVE SELECTION: Use whatever combination of Box/Sphere/Capsule best approximates the semantic object. You may use a single primitive if the object is extremely simple (like a pure cube or ball), but use multiple primitives for complex objects.' +
    '\n8) SEMANTIC REASONING (BRAIN):' +
    '\n   - spatial_logic must include a clear breakdown of parts and operations (additive vs subtractive).' +
    '\n   - If prompt is abstract, explicitly map concept -> physical metaphor (e.g., "speed" -> elongated capsules).' +
    '\n9) VALIDATION & SAFETY (SKIN):' +
    '\n   - No JS keywords/APIs outside the mathematical scope: DO NOT use Date, Math.random, eval, Function, import, fetch, window, document, localStorage, sessionStorage.' +
    '\n   - No loops, no recursion, no arrays/objects, no external references. Just local consts and math.' +
    '\n10) COMPLEXITY: keep the total count of primitive calls under 10.'
  );
}

export function forbiddenJsToken(sdfJs: string): string | null {
  const forbidden: Array<{ token: string; re: RegExp }> = [
    { token: "Date", re: /\bDate\b/i },
    { token: "Math.random", re: /Math\.random\b/i },
    { token: "eval", re: /\beval\b/i },
    // IMPORTANT: case-sensitive on purpose.
    // We only want to block the `Function(...)` constructor, not `function sdf(...)`.
    { token: "Function", re: /\bFunction\b/ },
    { token: "import", re: /\bimport\b/i },
    { token: "fetch", re: /\bfetch\b/i },
    { token: "XMLHttpRequest", re: /\bXMLHttpRequest\b/i },
    { token: "window", re: /\bwindow\b/i },
    { token: "document", re: /\bdocument\b/i },
    { token: "localStorage", re: /\blocalStorage\b/i },
    { token: "sessionStorage", re: /\bsessionStorage\b/i },
  ];
  for (const f of forbidden) {
    if (f.re.test(sdfJs)) return f.token;
  }
  return null;
}

export function normalizeOversizedNumericLiterals(sdfJs: string): { js: string; scaledCount: number } {
  let scaledCount = 0;
  const re = /(-?\d+\.?\d*)(?![\w.])(?!(?:\s*[eE][+-]?\d+))/g;
  const js = sdfJs.replace(re, (raw) => {
    const v = Number(raw);
    if (!Number.isFinite(v)) return raw;
    if (Math.abs(v) <= 1.0) return raw;
    let out = v;
    while (Math.abs(out) > 1.0) out *= 0.5;
    scaledCount++;
    let s = out.toFixed(6);
    s = s.replace(/\.0+$/, "");
    s = s.replace(/(\.\d*?)0+$/, "$1");
    return s;
  });
  return { js, scaledCount };
}

export function sanitizePrompt(v: unknown): string {
  if (typeof v !== "string") return "";
  return v.trim().slice(0, 160);
}

export function fallbackSdf(prompt: string, reason: string): GenerateSdfOutput {
  const lower = (prompt || "").trim().toLowerCase();
  const kind = (lower.split(/\s+/)[0] || "object").slice(0, 24);
  const spatial_logic = "Reduced to a few primitives and kept within a 2×2×2-ish bound.";

  const phone = `function sdf(px, py, pz) {
  const body = sdBox(px, py, pz, 0.38, 0.65, 0.08);
  const screen = sdBox(px, py + 0.04, pz + 0.01, 0.30, 0.50, 0.03);
  return Math.max(body, -screen);
}`;

  const ring = `function sdf(px, py, pz) {
  const outer = sdSphere(px, py, pz, 0.55);
  const inner = sdSphere(px, py, pz, 0.42);
  const shell = Math.max(outer, -inner);
  const band = sdBox(px, py, pz, 0.70, 0.22, 0.70);
  return Math.max(shell, -band);
}`;

  const mountain = `function sdf(px, py, pz) {
  const base = sdBox(px, py + 0.35, pz, 0.70, 0.25, 0.70);
  const ridge = sdCapsule(px, py, pz, -0.55, 0.35, 0.0, 0.55, -0.55, 0.0, 0.22);
  const peak = sdSphere(px, py - 0.55, pz, 0.26);
  let d = smin(base, ridge, 0.25);
  d = smin(d, peak, 0.20);
  return d;
}`;

  const generic = `function sdf(px, py, pz) {
  const core = sdBox(px, py, pz, 0.52, 0.38, 0.32);
  const notch = sdBox(px + 0.18, py + 0.12, pz, 0.18, 0.12, 0.30);
  return Math.max(core, -notch);
}`;

  let sdf_javascript = generic;
  if (lower.includes("phone") || lower.includes("iphone") || lower.includes("smartphone")) sdf_javascript = phone;
  else if (lower.includes("ring")) sdf_javascript = ring;
  else if (lower.includes("mountain") || lower.includes("mount") || lower.includes("peak")) sdf_javascript = mountain;

  return { kind, spatial_logic, sdf_javascript, model: `fallback-${reason}`, is_fallback: true, contract_version: CONTRACT_VERSION, fallback_reason: reason };
}
