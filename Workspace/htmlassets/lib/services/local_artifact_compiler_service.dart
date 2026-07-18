import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html_artifact_pipeline/models/html_artifact.dart';
import 'package:html_artifact_pipeline/services/synthesis_engine.dart';

class LocalArtifactCompilerService {
  static const String compilerVersion = 'local-0.3.0-webgl';

  final Map<String, SynthesisResult> _kindCache = {};

  Future<HtmlArtifact> compile({required String prompt, required int seed, required String style, required int width, required int height}) async {
    final startedAt = DateTime.now();

    // Simulate a real compile step (network/compute) so UI feels realistic.
    await Future<void>.delayed(const Duration(milliseconds: 650));

    // AI semantic routing (with deterministic fallback) so *any* term maps to a
    // supported particle object kind.
    final normalizedPrompt = prompt.trim();
    final cached = _kindCache[normalizedPrompt];
    final resolvedKind = cached ?? SynthesisEngine.synthesize(normalizedPrompt);
    // Only cache non-fallback generations. This prevents the app from getting
    // “stuck” on a fallback (e.g., when GROQ_API_KEY isn't configured yet).
    if (!resolvedKind.isFallback) _kindCache[normalizedPrompt] = resolvedKind;

    final id = '${startedAt.microsecondsSinceEpoch}-$seed';
    final html = _buildHtml(
      prompt: prompt,
      seed: seed,
      style: style,
      width: width,
      height: height,
      compilerVersion: compilerVersion,
      buildMs: DateTime.now().difference(startedAt).inMilliseconds,
      exportMode: false,
      resolvedKind: resolvedKind,
    );
    return HtmlArtifact(
      id: id,
      prompt: prompt,
      html: html,
      createdAt: startedAt,
      seed: seed,
      style: style,
      width: width,
      height: height,
      compilerVersion: compilerVersion,
      objectKind: resolvedKind.kind,
      spatialLogic: resolvedKind.spatialLogic,
      generationModel: resolvedKind.model,
      isFallback: resolvedKind.isFallback,
      fallbackReason: resolvedKind.fallbackReason,
      contractVersion: resolvedKind.contractVersion,
    );
  }

  /// Builds a minimal, export-ready `index.html` artifact.
  ///
  /// This version intentionally contains *only* the compiled particle object on a
  /// transparent canvas (no background gradients, HUD, stage frame, or animation).
  Future<String> buildExportHtml({required String prompt, required int seed, required String style, required int width, required int height}) async {
    // Use the same semantic routing for export artifacts so downloads always match preview.
    final normalizedPrompt = prompt.trim();
    final cached = _kindCache[normalizedPrompt];
    final resolvedKind = cached ?? SynthesisEngine.synthesize(normalizedPrompt);
    if (!resolvedKind.isFallback) _kindCache[normalizedPrompt] = resolvedKind;
    return _buildHtml(prompt: prompt, seed: seed, style: style, width: width, height: height, compilerVersion: compilerVersion, buildMs: 0, exportMode: true, resolvedKind: resolvedKind);
  }

  String _buildHtml({required String prompt, required int seed, required String style, required int width, required int height, required String compilerVersion, required int buildMs, required bool exportMode, required SynthesisResult resolvedKind}) {
    // Keep everything inline so the artifact is truly “single-file”.
    final safePrompt = const HtmlEscape(HtmlEscapeMode.element).convert(prompt.trim());
    final safeStyle = const HtmlEscape(HtmlEscapeMode.element).convert(style.trim());

    // Deterministic-ish palette based on seed.
    final palette = _paletteForSeed(seed);

    // "Structurally sound" here means:
    // - valid HTML scaffold
    // - deterministic rendering
    // - exportable as index.html
    // - WebGL pipeline is self-contained, except for Three.js ES module import.
    if (exportMode) {
      return '''<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>Artifact • ${safePrompt.isEmpty ? 'Untitled' : safePrompt}</title>
    <meta name="generator" content="Dreamflow LocalArtifactCompilerService/${compilerVersion}" />
    <style>
      * { box-sizing: border-box; }
      html, body { height: 100%; }
      body { margin: 0; overflow: hidden; background: transparent; }
      canvas { width: 100%; height: 100%; display: block; }
    </style>
  </head>
  <body>
    <canvas id="c" aria-label="Compiled object"></canvas>

    <script type="module">
      import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.165.0/build/three.module.js';

      // Seeded PRNG (Mulberry32)
      function mulberry32(a) {
        return function() {
          let t = (a += 0x6D2B79F5);
          t = Math.imul(t ^ (t >>> 15), t | 1);
          t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
          return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
      }

      const PROMPT = ${jsonEncode(prompt.trim())};
      const STYLE = ${jsonEncode(style.trim())};
      const OBJECT_KIND = ${jsonEncode(resolvedKind.kind)};
      const SEED = ${seed} >>> 0;
      const rand = mulberry32(SEED);

      function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
      function saturate(v) { return clamp(v, 0, 1); }

      const objectKind = (OBJECT_KIND || 'drone');

      // --- SDF primitives ---
      function sdSphere(px, py, pz, r) { return Math.hypot(px, py, pz) - r; }
      function sdBox(px, py, pz, bx, by, bz) {
        const qx = Math.abs(px) - bx;
        const qy = Math.abs(py) - by;
        const qz = Math.abs(pz) - bz;
        const ax = Math.max(qx, 0), ay = Math.max(qy, 0), az = Math.max(qz, 0);
        return Math.hypot(ax, ay, az) + Math.min(Math.max(qx, Math.max(qy, qz)), 0);
      }
      function sdCapsule(px, py, pz, ax, ay, az, bx, by, bz, r) {
        const pax = px - ax, pay = py - ay, paz = pz - az;
        const baxx = bx - ax, bayy = by - ay, bazz = bz - az;
        const baDot = baxx*baxx + bayy*bayy + bazz*bazz;
        const h = baDot === 0 ? 0 : saturate((pax*baxx + pay*bayy + paz*bazz) / baDot);
        const dx = pax - baxx*h, dy = pay - bayy*h, dz = paz - bazz*h;
        return Math.hypot(dx, dy, dz) - r;
      }
      function smin(a, b, k) {
        const h = saturate(0.5 + 0.5 * (b - a) / k);
        return (b * (1 - h) + a * h) - k * h * (1 - h);
      }

      // --- Object SDF (Dynamically Generated) ---
      ${resolvedKind.sdfJavascript}

      // High-fidelity Symmetric Gradient Normal Estimation
      function estimateNormal(px, py, pz) {
        const e = 0.0005; // Finer epsilon for better edge definition
        const n = {
          x: sdf(px + e, py, pz) - sdf(px - e, py, pz),
          y: sdf(px, py + e, pz) - sdf(px, py - e, pz),
          z: sdf(px, py, pz + e) - sdf(px, py, pz - e)
        };
        const mag = Math.sqrt(n.x * n.x + n.y * n.y + n.z * n.z);
        // Guard against zero-length normals at exact SDF centers
        if (mag < 0.00001) return { x: 0, y: 1, z: 0 };
        return { x: n.x / mag, y: n.y / mag, z: n.z / mag };
      }

      // --- Rejection sampling on the SDF boundary ---
      const PARTICLES = 25000;
      const positions = new Float32Array(PARTICLES * 3);
      const normals = new Float32Array(PARTICLES * 3);
      const scales = new Float32Array(PARTICLES);
      const bounds = 0.95;
      const eps = 0.010;
      let accepted = 0;
      let attempts = 0;
      const maxAttempts = PARTICLES * 240;

      while (accepted < PARTICLES && attempts < maxAttempts) {
        attempts++;
        const px = (rand() * 2 - 1) * bounds;
        const py = (rand() * 2 - 1) * bounds;
        const pz = (rand() * 2 - 1) * bounds;
        let d;
        try {
          d = sdf(px, py, pz);
          if (isNaN(d)) d = 100.0;
        } catch(e) {
          d = 100.0;
        }
        if (Math.abs(d) > eps) continue;
        const n = estimateNormal(px, py, pz);
        const finalX = px - n.x * d;
        const finalY = py - n.y * d;
        const finalZ = pz - n.z * d;
        const i3 = accepted * 3;
        positions[i3 + 0] = finalX;
        positions[i3 + 1] = finalY;
        positions[i3 + 2] = finalZ;
        normals[i3 + 0] = n.x;
        normals[i3 + 1] = n.y;
        normals[i3 + 2] = n.z;
        const styleLower = (STYLE || '').toLowerCase();
        const base = styleLower.includes('blueprint') ? 1.9 : styleLower.includes('museum') ? 2.6 : 2.2;
        scales[accepted] = base + rand() * 1.6;
        accepted++;
      }
      if (accepted === 0) {
        for (let i = 0; i < PARTICLES; i++) {
          const phi = Math.acos(-1 + (2 * i) / PARTICLES);
          const theta = Math.sqrt(PARTICLES * Math.PI) * phi;
          const r = 0.5;
          positions[i*3+0] = r * Math.cos(theta) * Math.sin(phi);
          positions[i*3+1] = r * Math.sin(theta) * Math.sin(phi);
          positions[i*3+2] = r * Math.cos(phi);
          normals[i*3+0] = Math.cos(theta) * Math.sin(phi);
          normals[i*3+1] = Math.sin(theta) * Math.sin(phi);
          normals[i*3+2] = Math.cos(phi);
          scales[i] = 2.0;
        }
        accepted = PARTICLES;
      }
      for (let i = accepted; i < PARTICLES; i++) {
        const src = i % Math.max(1, accepted);
        const s3 = src * 3;
        const i3 = i * 3;
        positions[i3 + 0] = positions[s3 + 0];
        positions[i3 + 1] = positions[s3 + 1];
        positions[i3 + 2] = positions[s3 + 2];
        normals[i3 + 0] = normals[s3 + 0];
        normals[i3 + 1] = normals[s3 + 1];
        normals[i3 + 2] = normals[s3 + 2];
        scales[i] = scales[src];
      }

      // --- Three.js scene ---
      const canvas = document.getElementById('c');
      const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: 'high-performance' });
      renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
      renderer.setClearColor(0x000000, 0);

      const scene = new THREE.Scene();
      const camera = new THREE.PerspectiveCamera(45, 1, 0.01, 40);
      camera.position.set(0.0, 0.75, 2.35);
      camera.lookAt(0, 0, 0);

      const root = new THREE.Group();
      scene.add(root);

      const geometry = new THREE.BufferGeometry();
      geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
      geometry.setAttribute('normal', new THREE.BufferAttribute(normals, 3));
      geometry.setAttribute('aScale', new THREE.BufferAttribute(scales, 1));

      const uniforms = {
        uTime: { value: 0.0 },
        uPixelRatio: { value: renderer.getPixelRatio() },
        uBaseColor: { value: new THREE.Color(1.0, 1.0, 1.0) },
        uLightDir: { value: new THREE.Vector3(0.35, 0.85, 0.25).normalize() },
      };

      const material = new THREE.ShaderMaterial({
        transparent: true,
        depthWrite: false,
        uniforms,
        vertexShader: `
          uniform float uTime;
          uniform float uPixelRatio;
          attribute float aScale;
          varying vec3 vNormal;
          varying vec3 vViewDir;
          void main() {
            vNormal = normalize(normalMatrix * normal);
            vec4 mv = modelViewMatrix * vec4(position, 1.0);
            vViewDir = normalize(-mv.xyz);
            gl_Position = projectionMatrix * mv;
            float dist = max(0.001, -mv.z);
            gl_PointSize = (aScale * uPixelRatio) * (220.0 / (dist * 200.0));
            gl_PointSize = clamp(gl_PointSize, 1.0, 6.0);
          }
        `,
        fragmentShader: `
          uniform vec3 uBaseColor;
          uniform vec3 uLightDir;
          varying vec3 vNormal;
          varying vec3 vViewDir;
          void main() {
            vec2 uv = gl_PointCoord * 2.0 - 1.0;
            float r2 = dot(uv, uv);
            if (r2 > 1.0) discard;
            vec3 N = normalize(vNormal);
            vec3 L = normalize(uLightDir);
            vec3 V = normalize(vViewDir);
            vec3 H = normalize(L + V);
            float diff = max(dot(N, L), 0.0);
            float spec = pow(max(dot(N, H), 0.0), 38.0);
            float alpha = smoothstep(1.0, 0.78, sqrt(r2));
            vec3 col = uBaseColor;
            col *= (0.28 + 0.72 * diff);
            col += vec3(1.0) * spec * 0.65;
            gl_FragColor = vec4(col, alpha);
          }
        `,
      });

      const points = new THREE.Points(geometry, material);
      root.add(points);

      function resize() {
        const rect = canvas.getBoundingClientRect();
        const w = Math.max(1, Math.floor(rect.width));
        const h = Math.max(1, Math.floor(rect.height));
        renderer.setSize(w, h, false);
        camera.aspect = w / h;
        camera.updateProjectionMatrix();
      }
      window.addEventListener('resize', () => { resize(); renderer.render(scene, camera); }, { passive: true });
      resize();

      // Export mode: render once (no environment overlays, no fog, no animation loop).
      renderer.render(scene, camera);
      window.addEventListener('unload', () => {
        renderer.dispose();
        geometry.dispose();
        material.dispose();
        const ext = renderer.getContext().getExtension('WEBGL_lose_context');
        if (ext) ext.loseContext();
      });
    </script>
  </body>
</html>''';
    }

    return '''<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>Artifact • ${safePrompt.isEmpty ? 'Untitled' : safePrompt}</title>
    <meta name="generator" content="Dreamflow LocalArtifactCompilerService/${compilerVersion}" />
    <style>
      :root {
        --bg0: ${palette[0]};
        --bg1: ${palette[1]};
        --fg: ${palette[2]};
        --muted: rgba(255,255,255,0.65);
        --card: rgba(255,255,255,0.08);
        --stroke: rgba(255,255,255,0.14);
        --shadow: rgba(0,0,0,0.20);
      }
      * { box-sizing: border-box; }
      html, body { height: 100%; }
      body {
        margin: 0;
        font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Apple Color Emoji", "Segoe UI Emoji";
        color: var(--fg);
        background: radial-gradient(1200px 700px at 20% 15%, var(--bg1), transparent 60%),
                    radial-gradient(900px 600px at 85% 20%, rgba(255,255,255,0.12), transparent 70%),
                    linear-gradient(135deg, var(--bg0), #0b1220 60%, #070b14);
        overflow: hidden;
      }
      .wrap {
        position: relative;
        height: 100%;
        display: grid;
        place-items: center;
        padding: 24px;
      }
       .stage {
         width: min(${width}px, 96vw);
         height: min(${height}px, 78vh);
        border-radius: 22px;
        background: linear-gradient(180deg, rgba(255,255,255,0.12), rgba(255,255,255,0.04));
        border: 1px solid var(--stroke);
        box-shadow: 0 24px 60px var(--shadow);
        overflow: hidden;
        position: relative;
      }
      canvas { position:absolute; inset:0; width:100%; height:100%; display:block; }
      .hud {
        position: absolute;
        left: 16px;
        right: 16px;
        top: 16px;
        display: flex;
        gap: 12px;
        align-items: flex-start;
        justify-content: space-between;
        pointer-events: none;
      }
      .card {
        pointer-events: none;
        padding: 12px 14px;
        border-radius: 16px;
        background: var(--card);
        border: 1px solid var(--stroke);
        backdrop-filter: blur(10px);
      }
      .title { font-size: 14px; font-weight: 650; letter-spacing: 0.2px; }
      .meta { margin-top: 6px; font-size: 12px; color: var(--muted); line-height: 1.45; }
      .pill {
        display:inline-flex;
        gap: 6px;
        align-items:center;
        padding: 8px 10px;
        border-radius: 999px;
        background: rgba(255,255,255,0.10);
        border: 1px solid var(--stroke);
        font-size: 12px;
        color: rgba(255,255,255,0.86);
      }
      .dot { width: 8px; height: 8px; border-radius: 999px; background: rgba(255,255,255,0.85); }
      .footer {
        position: absolute;
        left: 16px;
        bottom: 16px;
        right: 16px;
        display:flex;
        justify-content: space-between;
        align-items:center;
        color: var(--muted);
        font-size: 12px;
        pointer-events:none;
      }
      .kbd {
        font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
        padding: 2px 8px;
        border-radius: 999px;
        border: 1px solid var(--stroke);
        background: rgba(0,0,0,0.15);
      }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="stage">
        <canvas id="c" aria-label="Compiled object"></canvas>
        <div class="hud">
          <div class="card">
            <div class="title">${safePrompt.isEmpty ? 'Semantic object' : safePrompt}</div>
            <div class="meta">
              compiler: ${compilerVersion} • style: ${safeStyle} • seed: ${seed} • build: ${buildMs}ms
            </div>
          </div>
          <div class="pill"><span class="dot"></span> kind: <span id="k">—</span> • index.html</div>
        </div>
        <div class="footer">
          <div>WebGL SDF shell • ShaderMaterial • 25,000 particles</div>
          <div><span class="kbd">index.html</span> export</div>
        </div>
      </div>
    </div>

    <script type="module">
      import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.165.0/build/three.module.js';

      // Seeded PRNG (Mulberry32)
      function mulberry32(a) {
        return function() {
          let t = (a += 0x6D2B79F5);
          t = Math.imul(t ^ (t >>> 15), t | 1);
          t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
          return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
      }

      const PROMPT = ${jsonEncode(prompt.trim())};
      const STYLE = ${jsonEncode(style.trim())};
      const OBJECT_KIND = ${jsonEncode(resolvedKind.kind)};
      const SEED = ${seed} >>> 0;
      const rand = mulberry32(SEED);

      function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
      function saturate(v) { return clamp(v, 0, 1); }

      const objectKind = (OBJECT_KIND || 'drone');
      const kindEl = document.getElementById('k');
      if (kindEl) kindEl.textContent = objectKind;

      // --- SDF primitives (Optimized: No object allocation) ---
      function sdSphere(px, py, pz, r) { return Math.hypot(px, py, pz) - r; }
      function sdBox(px, py, pz, bx, by, bz) {
        const qx = Math.abs(px) - bx;
        const qy = Math.abs(py) - by;
        const qz = Math.abs(pz) - bz;
        const ax = Math.max(qx, 0), ay = Math.max(qy, 0), az = Math.max(qz, 0);
        return Math.hypot(ax, ay, az) + Math.min(Math.max(qx, Math.max(qy, qz)), 0);
      }
      function sdCapsule(px, py, pz, ax, ay, az, bx, by, bz, r) {
        const pax = px - ax, pay = py - ay, paz = pz - az;
        const baxx = bx - ax, bayy = by - ay, bazz = bz - az;
        const baDot = baxx*baxx + bayy*bayy + bazz*bazz;
        const h = baDot === 0 ? 0 : saturate((pax*baxx + pay*bayy + paz*bazz) / baDot);
        const dx = pax - baxx*h, dy = pay - bayy*h, dz = paz - bazz*h;
        return Math.hypot(dx, dy, dz) - r;
      }
      function smin(a, b, k) {
        const h = saturate(0.5 + 0.5 * (b - a) / k);
        return (b * (1 - h) + a * h) - k * h * (1 - h);
      }

      // --- Object SDF (Dynamically Generated) ---
      ${resolvedKind.sdfJavascript}

      // High-fidelity Symmetric Gradient Normal Estimation
      function estimateNormal(px, py, pz) {
        const e = 0.0005; // Finer epsilon for better edge definition
        const n = {
          x: sdf(px + e, py, pz) - sdf(px - e, py, pz),
          y: sdf(px, py + e, pz) - sdf(px, py - e, pz),
          z: sdf(px, py, pz + e) - sdf(px, py, pz - e)
        };
        const mag = Math.sqrt(n.x * n.x + n.y * n.y + n.z * n.z);
        // Guard against zero-length normals at exact SDF centers
        if (mag < 0.00001) return { x: 0, y: 1, z: 0 };
        return { x: n.x / mag, y: n.y / mag, z: n.z / mag };
      }

      // --- Rejection sampling on the SDF boundary (distance ~= 0) ---
      const PARTICLES = Math.max(25000, 25000);
      const positions = new Float32Array(PARTICLES * 3);
      const normals = new Float32Array(PARTICLES * 3);
      const scales = new Float32Array(PARTICLES);

      const bounds = 0.95;
      const eps = 0.010; // boundary thickness
      let accepted = 0;
      let attempts = 0;
      const maxAttempts = PARTICLES * 240;

      while (accepted < PARTICLES && attempts < maxAttempts) {
        attempts++;
        const px = (rand() * 2 - 1) * bounds;
        const py = (rand() * 2 - 1) * bounds;
        const pz = (rand() * 2 - 1) * bounds;
        let d;
        try {
          d = sdf(px, py, pz);
          if (isNaN(d)) d = 100.0;
        } catch(e) {
          d = 100.0;
        }
        if (Math.abs(d) > eps) continue;
        const n = estimateNormal(px, py, pz);
        const finalX = px - n.x * d;
        const finalY = py - n.y * d;
        const finalZ = pz - n.z * d;
        const i3 = accepted * 3;
        positions[i3 + 0] = finalX;
        positions[i3 + 1] = finalY;
        positions[i3 + 2] = finalZ;
        normals[i3 + 0] = n.x;
        normals[i3 + 1] = n.y;
        normals[i3 + 2] = n.z;
        const styleLower = (STYLE || '').toLowerCase();
        const base = styleLower.includes('blueprint') ? 1.9 : styleLower.includes('museum') ? 2.6 : 2.2;
        scales[accepted] = base + rand() * 1.6;
        accepted++;
      }
      if (accepted === 0) {
        for (let i = 0; i < PARTICLES; i++) {
          const phi = Math.acos(-1 + (2 * i) / PARTICLES);
          const theta = Math.sqrt(PARTICLES * Math.PI) * phi;
          const r = 0.5;
          positions[i*3+0] = r * Math.cos(theta) * Math.sin(phi);
          positions[i*3+1] = r * Math.sin(theta) * Math.sin(phi);
          positions[i*3+2] = r * Math.cos(phi);
          normals[i*3+0] = Math.cos(theta) * Math.sin(phi);
          normals[i*3+1] = Math.sin(theta) * Math.sin(phi);
          normals[i*3+2] = Math.cos(phi);
          scales[i] = 2.0;
        }
        accepted = PARTICLES;
      }
      for (let i = accepted; i < PARTICLES; i++) {
        const src = i % Math.max(1, accepted);
        const s3 = src * 3;
        const i3 = i * 3;
        positions[i3 + 0] = positions[s3 + 0];
        positions[i3 + 1] = positions[s3 + 1];
        positions[i3 + 2] = positions[s3 + 2];
        normals[i3 + 0] = normals[s3 + 0];
        normals[i3 + 1] = normals[s3 + 1];
        normals[i3 + 2] = normals[s3 + 2];
        scales[i] = scales[src];
      }

      // --- Three.js scene ---
      const canvas = document.getElementById('c');
      const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: 'high-performance' });
      renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));

      const scene = new THREE.Scene();
      const camera = new THREE.PerspectiveCamera(45, 1, 0.01, 40);
      camera.position.set(0.0, 0.75, 2.35);
      camera.lookAt(0, 0, 0);

      const root = new THREE.Group();
      scene.add(root);

      const geometry = new THREE.BufferGeometry();
      geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
      geometry.setAttribute('normal', new THREE.BufferAttribute(normals, 3));
      geometry.setAttribute('aScale', new THREE.BufferAttribute(scales, 1));

      const uniforms = {
        uTime: { value: 0.0 },
        uPixelRatio: { value: renderer.getPixelRatio() },
        uBaseColor: { value: new THREE.Color(1.0, 1.0, 1.0) },
        uLightDir: { value: new THREE.Vector3(0.35, 0.85, 0.25).normalize() },
      };

      const material = new THREE.ShaderMaterial({
        transparent: true,
        depthWrite: false,
        uniforms,
        vertexShader: `
          uniform float uTime;
          uniform float uPixelRatio;
          attribute float aScale;
          varying vec3 vNormal;
          varying vec3 vViewDir;
          void main() {
            vNormal = normalize(normalMatrix * normal);
            vec4 mv = modelViewMatrix * vec4(position, 1.0);
            vViewDir = normalize(-mv.xyz);
            gl_Position = projectionMatrix * mv;
            float dist = max(0.001, -mv.z);
            gl_PointSize = (aScale * uPixelRatio) * (220.0 / (dist * 200.0));
            gl_PointSize = clamp(gl_PointSize, 1.0, 6.0);
          }
        `,
        fragmentShader: `
          uniform vec3 uBaseColor;
          uniform vec3 uLightDir;
          varying vec3 vNormal;
          varying vec3 vViewDir;
          void main() {
            vec2 uv = gl_PointCoord * 2.0 - 1.0;
            float r2 = dot(uv, uv);
            if (r2 > 1.0) discard;

            vec3 N = normalize(vNormal);
            vec3 L = normalize(uLightDir);
            vec3 V = normalize(vViewDir);
            vec3 H = normalize(L + V);

            float diff = max(dot(N, L), 0.0);
            float spec = pow(max(dot(N, H), 0.0), 38.0);

            float alpha = smoothstep(1.0, 0.78, sqrt(r2));

            vec3 col = uBaseColor;
            col *= (0.28 + 0.72 * diff);
            col += vec3(1.0) * spec * 0.65;

            gl_FragColor = vec4(col, alpha);
          }
        `,
      });

      const points = new THREE.Points(geometry, material);
      root.add(points);

      scene.fog = new THREE.FogExp2(0x000000, 0.85);

      function resize() {
        const rect = canvas.getBoundingClientRect();
        const w = Math.max(1, Math.floor(rect.width));
        const h = Math.max(1, Math.floor(rect.height));
        renderer.setSize(w, h, false);
        camera.aspect = w / h;
        camera.updateProjectionMatrix();
      }
      window.addEventListener('resize', resize, { passive: true });
      resize();

      let pointerX = 0, pointerY = 0;
      let targetX = 0, targetY = 0;
      canvas.addEventListener('pointermove', (e) => {
        const rect = canvas.getBoundingClientRect();
        targetX = (e.clientX - rect.left) / rect.width * 2 - 1;
        targetY = -(e.clientY - rect.top) / rect.height * 2 + 1;
      });
      canvas.style.touchAction = 'none';

      const t0 = performance.now();
      function tick() {
        const t = (performance.now() - t0) * 0.001;
        uniforms.uTime.value = t;

        pointerX += (targetX - pointerX) * 0.1;
        pointerY += (targetY - pointerY) * 0.1;

        root.rotation.y = t * 0.28 + pointerX * 2.0;
        root.rotation.x = Math.sin(t * 0.35) * 0.10 - pointerY * 2.0;
        root.position.y = Math.sin(t * 0.55) * 0.04;

        renderer.render(scene, camera);
        requestAnimationFrame(tick);
      }
      tick();
      window.addEventListener('unload', () => {
        renderer.dispose();
        geometry.dispose();
        material.dispose();
        const ext = renderer.getContext().getExtension('WEBGL_lose_context');
        if (ext) ext.loseContext();
      });
    </script>
  </body>
</html>''';
  }

  List<String> _paletteForSeed(int seed) {
    // Minimal deterministic mapping—good enough for a local prototype.
    final picks = <List<String>>[
      ['#111827', '#2563EB', '#F8FAFC'],
      ['#0B1020', '#7C3AED', '#F9FAFB'],
      ['#06121B', '#10B981', '#ECFEFF'],
      ['#0B0F1A', '#F97316', '#FFFBEB'],
      ['#050B14', '#06B6D4', '#F1F5F9'],
    ];
    return picks[seed.abs() % picks.length];
  }
}
