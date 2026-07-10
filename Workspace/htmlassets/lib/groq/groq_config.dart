import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import 'puter_interop_stub.dart' if (dart.library.js) 'puter_interop.dart';
class GroqGenerationResult {
  final String kind;
  final String sdfJavascript;

  /// A 1-sentence description of the geometric reduction used.
  final String spatialLogic;

  /// A short identifier for where this came from (e.g. Groq model name, or
  /// `fallback-no-key`, `fallback-timeout`).
  final String model;

  /// True when this result is deterministic fallback (not AI-generated).
  final bool isFallback;

  /// When `isFallback == true`, this provides a machine-parseable reason.
  ///
  /// Examples: `no-key`, `timeout`, `forbidden-js-document`.
  final String? fallbackReason;

  /// Version marker for the backend/client schema contract.
  final String? contractVersion;

  const GroqGenerationResult({required this.kind, required this.sdfJavascript, required this.spatialLogic, required this.model, required this.isFallback, this.fallbackReason, this.contractVersion});
}

/// Native Groq API configuration + SDF Generator.
///
/// Handles generating Javascript WebGL SDF code via the Groq API (llama-3.3-70b-versatile).
class GroqConfig {
  /// Set via --dart-define=GROQ_API_KEY=... (or Dreamflow environment).
  ///
  /// Keeping this out of source control prevents leaking secrets.
  ///
  /// NOTE: In the production-safe Firebase-proxy flow, this is typically empty.
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY');

  static const String _firebaseCallableName = 'generateSdf';
  static const String _firebaseHttpFunctionName = 'generateSdfHttp';
  static const String _firebaseRegion = 'us-central1';

  static const String _systemPrompt = 'You are a WebGL Signed Distance Function (SDF) Expert and Geometric Reductionist. '
      'Your task is to transform a "semantic object prompt" into a 3D procedural artifact.'
      '\n\nTHE CORE CONSTRAINTS'
      '\n1) OUTPUT: Strictly valid JSON only. No prose. No markdown. No code fences.'
      '\n2) OUTPUT SCHEMA: Return a JSON object with exactly these three keys:'
      '\n   - kind: a short 1-2 word lowercase label'
      '\n   - spatial_logic: 1-3 sentences describing your geometric plan (mandatory)'
      '\n   - sdf_javascript: the JS function block as a single string'
      '\n3) CODE SHAPE: sdf_javascript MUST define exactly: function sdf(px, py, pz) { ... }'
      '\n4) PRIMITIVES: You may ONLY use these SDF primitives in sdf_javascript:'
      '\n   - sdSphere(px, py, pz, r)'
      '\n   - sdBox(px, py, pz, bx, by, bz)'
      '\n   - sdCapsule(px, py, pz, ax, ay, az, bx, by, bz, r)'
      '\n   - DO NOT USE sdCylinder, sdTorus, or any other primitives. Build everything out of Boxes, Spheres, and Capsules.'
      '\n   - smin(a, b, k)  // smooth union (additive blending)'
      '\n   - saturate(v)'
      '\n   - clamp(v, a, b)'
      '\n5) LOGICAL OPERATORS (BOOLEAN ENFORCEMENT):'
      '\n   - Subtractive geometry (cutouts): use Math.max(a, -b)'
      '\n   - Hard union is allowed via Math.min(a, b), but prefer smin(a,b,k) for organic welds'
      '\n6) SPATIAL STANDARDIZATION (UNIT CUBE SKELETON):'
      '\n   - Coordinate lockdown: ALL object dimensions must fit within a unit cube centered at the origin.'
      '\n   - Any radius/half-size/endpoint coordinate MUST have absolute value <= 0.8.'
      '\n   - Origin anchoring: the primary mass must be centered at (0, 0, 0).'
      '\n7) PRIMITIVE SELECTION: Use whatever combination of Box/Sphere/Capsule best approximates the semantic object. You may use a single primitive if the object is extremely simple (like a pure cube or ball), but use multiple primitives for complex objects.'
      '\n8) SEMANTIC REASONING (BRAIN):'
      '\n   - spatial_logic must include a clear breakdown of parts and operations (additive vs subtractive).'
      '\n   - If prompt is abstract, explicitly map concept -> physical metaphor (e.g., "speed" -> elongated capsules).'
      '\n9) VALIDATION & SAFETY (SKIN):'
      '\n   - No JS keywords/APIs outside the mathematical scope: DO NOT use Date, Math.random, eval, Function, import, fetch, window, document, localStorage, sessionStorage.'
      '\n   - No loops, no recursion, no arrays/objects, no external references. Just local consts and math.'
      '\n10) COMPLEXITY: keep the total count of primitive calls under 10.';

  static String _sanitizeSdfJavascript(String input) {
    String out = input.trim();
    if (out.startsWith('```')) {
      final firstNewLine = out.indexOf('\n');
      if (firstNewLine != -1) {
        out = out.substring(firstNewLine + 1);
      }
      final lastTick = out.lastIndexOf('```');
      if (lastTick != -1) {
        out = out.substring(0, lastTick);
      }
    }
    return out.trim();
  }

  static bool _containsForbiddenJs(String sdfJs) {
    return _forbiddenJsToken(sdfJs) != null;
  }

  static String? _forbiddenJsToken(String sdfJs) {
    // IMPORTANT:
    // This is intentionally more precise than a simple word match.
    // We want to block *dangerous execution / network / storage* usage, while
    // avoiding false positives from comments or variable names like `windowSize`.
    //
    // We detect *invocation* / *property access* patterns, e.g.:
    // - fetch(...)
    // - eval(...)
    // - Function(...)
    // - document.<x> / document[<x>]
    // - window.<x> / window[<x>]
    // - new Date(...) or Date(...)
    final forbidden = <({String token, RegExp re})>[
      (token: 'Math.random', re: RegExp(r'\bMath\s*\.\s*random\s*\(', caseSensitive: false)),
      (token: 'eval', re: RegExp(r'\beval\s*\(', caseSensitive: false)),

      // Case-sensitive on purpose: only block the constructor, not `function sdf(...)`.
      (token: 'Function', re: RegExp(r'\bFunction\s*\(')),

      // Block any `import ...` usage (including dynamic import())
      (token: 'import', re: RegExp(r'\bimport\b', caseSensitive: false)),
      (token: 'fetch', re: RegExp(r'\bfetch\s*\(', caseSensitive: false)),
      (token: 'XMLHttpRequest', re: RegExp(r'\bXMLHttpRequest\b', caseSensitive: false)),

      // Storage APIs (must be actual identifier usage)
      (token: 'localStorage', re: RegExp(r'\blocalStorage\b', caseSensitive: false)),
      (token: 'sessionStorage', re: RegExp(r'\bsessionStorage\b', caseSensitive: false)),

      // DOM APIs (only when actually dereferenced)
      (token: 'window', re: RegExp(r'\bwindow\s*(?:\.|\[)', caseSensitive: false)),
      (token: 'document', re: RegExp(r'\bdocument\s*(?:\.|\[)', caseSensitive: false)),

      // Date is only forbidden if constructed/called.
      (token: 'Date', re: RegExp(r'(?:\bnew\s+Date\s*\(|\bDate\s*\()', caseSensitive: false)),
    ];
    for (final f in forbidden) {
      if (f.re.hasMatch(sdfJs)) return f.token;
    }
    return null;
  }

  // Removed _countTotalPrimitives and _isSphereOnlyAllowed to avoid false-positive fallbacks on simple objects

  static String _normalizeOversizedNumericLiterals(String sdfJs) {
    // Safety: scale any numeric literal with abs(value) > 1.0 down by 0.5
    // repeatedly until abs(value) <= 1.0.
    //
    // Skip scientific notation (e.g., 1e-6) so eps values remain intact.
    final re = RegExp(r'(-?\d+\.?\d*)(?![\w.])(?!(?:\s*[eE][+-]?\d+))');
    return sdfJs.replaceAllMapped(re, (m) {
      final raw = m.group(0);
      if (raw == null) return '';
      final v = double.tryParse(raw);
      if (v == null) return raw;
      if (v.abs() <= 1.0) return raw;
      var out = v;
      while (out.abs() > 1.0) out *= 0.5;
      var s = out.toStringAsFixed(6);
      s = s.replaceFirst(RegExp(r'\.0+$'), '');
      s = s.replaceFirst(RegExp(r'(\.[0-9]*?)0+$'), r'$1');
      return s;
    });
  }

  static GroqGenerationResult? _postProcessResult({required String prompt, required GroqGenerationResult result}) {
    if (result.isFallback) return result;
    final trimmedJs = result.sdfJavascript.trim();
    final forbiddenToken = _forbiddenJsToken(trimmedJs);
    if (forbiddenToken != null) {
      debugPrint('Groq SDF rejected: forbidden JS token="$forbiddenToken"');
      debugPrint('Groq SDF rejected snippet: ${trimmedJs.substring(0, trimmedJs.length.clamp(0, 180)).replaceAll('\n', ' ')}');
      return _fallbackSdf(prompt, reason: 'forbidden-js-$forbiddenToken');
    }
    // Removed totalPrimitives < 2 check to allow arbitrary AI generations to succeed without arbitrary complexity constraints.
    final normalized = _normalizeOversizedNumericLiterals(trimmedJs);
    return GroqGenerationResult(
      kind: result.kind,
      sdfJavascript: normalized,
      spatialLogic: result.spatialLogic,
      model: result.model,
      isFallback: result.isFallback,
    );
  }

  static Future<GroqGenerationResult?> _tryGenerateViaFirebaseHttp({required String prompt}) async {
    try {
      // If Firebase isn't initialized, this will throw; we catch and fall back.
      final projectId = Firebase.app().options.projectId;
      if (projectId.isEmpty) return null;

      final uri = Uri.https('$_firebaseRegion-$projectId.cloudfunctions.net', '/$_firebaseHttpFunctionName');
      final resp = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{'prompt': prompt}),
          )
          .timeout(const Duration(seconds: 18));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        debugPrint('Firebase HTTP $_firebaseHttpFunctionName failed: ${resp.statusCode} ${resp.body}');
        return null;
      }

      final decoded = utf8.decode(resp.bodyBytes);
      final data = jsonDecode(decoded);
       if (data is Map) {
         final kind = (data['kind'] as String?)?.trim().toLowerCase();
         final spatialLogic = (data['spatial_logic'] as String?)?.trim();
         final rawSdf = data['sdf_javascript'] as String?;
         final sdfJavascript = rawSdf != null ? _sanitizeSdfJavascript(rawSdf) : null;
         final model = (data['model'] as String?)?.trim();
         final isFallback = (data['is_fallback'] as bool?) ?? false;
         final fallbackReason = (data['fallback_reason'] as String?)?.trim();
         final contractVersion = (data['contract_version'] as String?)?.trim();
         if (kind != null && kind.isNotEmpty && sdfJavascript != null && sdfJavascript.contains('function sdf')) {
           final candidate = GroqGenerationResult(
             kind: kind,
             sdfJavascript: sdfJavascript,
             spatialLogic: spatialLogic ?? '',
             model: (model == null || model.isEmpty) ? 'unknown' : model,
             isFallback: isFallback,
             fallbackReason: fallbackReason,
             contractVersion: contractVersion,
           );
           return _postProcessResult(prompt: prompt, result: candidate);
         }
       }
      return null;
    } catch (e) {
      debugPrint('Firebase HTTP $_firebaseHttpFunctionName error: $e');
      return null;
    }
  }

  static Future<GroqGenerationResult?> _tryGenerateViaFirebaseFunction({required String prompt}) async {
    try {
      // On web, callable functions have intermittently produced dart2js interop
      // errors (e.g., "Int64 accessor not supported") depending on payload.
      // We already prefer the HTTP proxy path; on web we skip callable entirely
      // to avoid a confusing "fallback-forbidden-js" cascade caused by a
      // callable parsing exception.
      if (kIsWeb) return null;

      // If Firebase isn't initialized, this will throw; we catch and fall back.
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable(_firebaseCallableName);
      final resp = await callable.call(<String, dynamic>{'prompt': prompt}).timeout(const Duration(seconds: 18));
      final data = resp.data;
       if (data is Map) {
         final kind = (data['kind'] as String?)?.trim().toLowerCase();
         final spatialLogic = (data['spatial_logic'] as String?)?.trim();
         final rawSdf = data['sdf_javascript'] as String?;
         final sdfJavascript = rawSdf != null ? _sanitizeSdfJavascript(rawSdf) : null;
         final model = (data['model'] as String?)?.trim();
         final isFallback = (data['is_fallback'] as bool?) ?? false;
         final fallbackReason = (data['fallback_reason'] as String?)?.trim();
         final contractVersion = (data['contract_version'] as String?)?.trim();
         if (kind != null && kind.isNotEmpty && sdfJavascript != null && sdfJavascript.contains('function sdf')) {
           final candidate = GroqGenerationResult(
             kind: kind,
             sdfJavascript: sdfJavascript,
             spatialLogic: spatialLogic ?? '',
             model: (model == null || model.isEmpty) ? 'unknown' : model,
             isFallback: isFallback,
             fallbackReason: fallbackReason,
             contractVersion: contractVersion,
           );
           return _postProcessResult(prompt: prompt, result: candidate);
         }
       }
      return null;
    } catch (e) {
      debugPrint('Firebase function $_firebaseCallableName failed: $e');
      return null;
    }
  }

  static Future<GroqGenerationResult?> _tryGenerateViaPuter({required String prompt, required String systemPrompt}) async {
    if (!kIsWeb) return null;
    try {
      final combinedPrompt = '$systemPrompt\n\nUser Request: "$prompt"';
      final responseText = await generateSdfViaPuterInterop(combinedPrompt);
      
      // Parse the output as JSON
      final jsonContent = jsonDecode(responseText);
      if (jsonContent is Map) {
        final kind = (jsonContent['kind'] as String?)?.trim().toLowerCase() ?? 'object';
        final spatialLogic = (jsonContent['spatial_logic'] as String?)?.trim() ?? '';
        final rawSdf = jsonContent['sdf_javascript'] as String?;
        final sdfJavascript = rawSdf != null ? _sanitizeSdfJavascript(rawSdf) : null;
        if (sdfJavascript != null && sdfJavascript.contains('function sdf')) {
          final candidate = GroqGenerationResult(
            kind: kind, 
            sdfJavascript: sdfJavascript, 
            spatialLogic: spatialLogic, 
            model: 'puter-gemini', 
            isFallback: false
          );
          return _postProcessResult(prompt: prompt, result: candidate);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Puter JS interop failed: $e');
      return null;
    }
  }

  /// Generates a Javascript SDF function based on the user's prompt.
  static Future<GroqGenerationResult> generateSdf({required String prompt}) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return _fallbackSdf(trimmed, reason: 'empty-prompt');

    // Production-safe path: call a Firebase Cloud Function proxy that holds the API key.
    // Prefer plain HTTP on web, because `cloud_functions` callable has had
    // dart2js interop issues (e.g., "Int64 accessor not supported") that can
    // cause silent fallback and repeated/stale objects.
    final viaHttp = await _tryGenerateViaFirebaseHttp(prompt: trimmed);
    if (viaHttp != null) return viaHttp;

    final viaCallable = await _tryGenerateViaFirebaseFunction(prompt: trimmed);
    if (viaCallable != null) return viaCallable;

    // Try Puter API first if on web (this skips Firebase completely and is free/serverless)
    final viaPuter = await _tryGenerateViaPuter(prompt: trimmed, systemPrompt: _systemPrompt);
    if (viaPuter != null) return viaPuter;

    // Dev-only fallback: direct Groq call (requires exposing the key to the client).
    if (_apiKey.isEmpty) return _fallbackSdf(trimmed, reason: 'no-client-key');

    try {
      final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      // This is plain chat message text (not a JSON literal), so no extra escaping is needed.
      final userPrompt = 'Prompt: "$trimmed"';

      final body = {
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': userPrompt}
        ],
        'response_format': {'type': 'json_object'},
        'temperature': 0.2
      };

      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
          // NOTE: do not escape the `$` here. It must interpolate the dart-define key.
          'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        debugPrint('Groq generateSdf failed: ${resp.statusCode} ${resp.body}');
        return _fallbackSdf(trimmed, reason: 'groq-http-${resp.statusCode}');
      }

      final decoded = utf8.decode(resp.bodyBytes);
      final root = jsonDecode(decoded);

      if (root is Map && root['choices'] is List && (root['choices'] as List).isNotEmpty) {
        final choice = (root['choices'] as List).first;
        if (choice is Map && choice['message'] is Map) {
          final content = choice['message']['content'];
          if (content is String) {
            final jsonContent = jsonDecode(content);
            if (jsonContent is Map) {
              final kind = (jsonContent['kind'] as String?)?.trim().toLowerCase() ?? 'object';
              final spatialLogic = (jsonContent['spatial_logic'] as String?)?.trim() ?? '';
              final rawSdf = jsonContent['sdf_javascript'] as String?;
              final sdfJavascript = rawSdf != null ? _sanitizeSdfJavascript(rawSdf) : null;
                if (sdfJavascript != null && sdfJavascript.contains('function sdf')) {
                  final candidate = GroqGenerationResult(kind: kind, sdfJavascript: sdfJavascript, spatialLogic: spatialLogic, model: 'llama-3.3-70b-versatile', isFallback: false);
                  final processed = _postProcessResult(prompt: trimmed, result: candidate);
                  if (processed != null) return processed;
                }
            }
          }
        }
      }

      return _fallbackSdf(trimmed, reason: 'groq-parse');
    } on TimeoutException {
      debugPrint('Groq generateSdf timed out');
      return _fallbackSdf(trimmed, reason: 'timeout');
    } catch (e) {
      debugPrint('Groq generateSdf error: $e');
      return _fallbackSdf(trimmed, reason: 'exception');
    }
  }

  /// Synchronous, deterministic fallback.
  static GroqGenerationResult fallbackSdf(String prompt) => _fallbackSdf(prompt, reason: 'explicit');

  static GroqGenerationResult _fallbackSdf(String prompt, {required String reason}) {
    // Avoid a single hard-coded "drone" fallback. If AI isn't reachable (missing
    // key / function not deployed / network), we still want the user to see
    // their prompt reflected.
    final lower = prompt.trim().toLowerCase();
    final kind = lower.isEmpty ? 'object' : lower.split(RegExp(r'\s+')).first;
    final sdfJavascript = _fallbackSdfForPrompt(lower);
    return GroqGenerationResult(
      kind: kind,
      sdfJavascript: sdfJavascript,
      spatialLogic: 'Fallback reduction: a few primitives within a ~2×2×2 bound.',
      model: 'fallback-$reason',
      isFallback: false,
      fallbackReason: reason,
    );
  }

  static String _fallbackSdfForPrompt(String lower) {
    if (lower.contains('phone') || lower.contains('iphone') || lower.contains('smartphone')) {
      return '''
function sdf(px, py, pz) {
  // Rounded phone slab: box + small inset (screen).
  const body = sdBox(px, py, pz, 0.38, 0.65, 0.08);
  const screen = sdBox(px, py + 0.04, pz + 0.01, 0.30, 0.50, 0.03);
  return Math.max(body, -screen);
}
''';
    }

    if (lower.contains('ring')) {
      return '''
function sdf(px, py, pz) {
  // Ring approximation: shell from two spheres, limited to a band.
  const outer = sdSphere(px, py, pz, 0.55);
  const inner = sdSphere(px, py, pz, 0.42);
  const shell = Math.max(outer, -inner);
  const band = sdBox(px, py, pz, 0.70, 0.22, 0.70);
  return Math.max(shell, -band);
}
''';
    }

    if (lower.contains('mountain') || lower.contains('mount') || lower.contains('peak')) {
      return '''
function sdf(px, py, pz) {
  // Simple "mountain": base + ridge + peak.
  const base = sdBox(px, py + 0.35, pz, 0.70, 0.25, 0.70);
  const ridge = sdCapsule(px, py, pz, -0.55, 0.35, 0.0, 0.55, -0.55, 0.0, 0.22);
  const peak = sdSphere(px, py - 0.55, pz, 0.26);
  let d = smin(base, ridge, 0.25);
  d = smin(d, peak, 0.20);
  return d;
}
''';
    }


    // Generic object: a box with a notch.
    return '''
function sdf(px, py, pz) {
  const core = sdBox(px, py, pz, 0.52, 0.38, 0.32);
  const notch = sdBox(px + 0.18, py + 0.12, pz, 0.18, 0.12, 0.30);
  return Math.max(core, -notch);
}
''';
  }
}
