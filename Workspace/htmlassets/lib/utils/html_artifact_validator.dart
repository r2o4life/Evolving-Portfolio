import 'package:flutter/foundation.dart';

/// Minimal sanity checks to avoid exporting obviously broken HTML.
///
/// This is not a full HTML parser—just guardrails for a single-file `index.html`.
abstract final class HtmlArtifactValidator {
  static HtmlValidationResult validate(String html) {
    final s = html.trim();
    if (s.isEmpty) return const HtmlValidationResult(isValid: false, message: 'Empty HTML');

    final lower = s.toLowerCase();
    final hasDoctype = lower.startsWith('<!doctype html');
    final hasHtml = lower.contains('<html');
    final hasHead = lower.contains('<head');
    final hasBody = lower.contains('<body');
    final hasCloseHtml = lower.contains('</html>');
    if (!hasDoctype || !hasHtml || !hasHead || !hasBody || !hasCloseHtml) {
      return const HtmlValidationResult(isValid: false, message: 'Missing required HTML scaffold');
    }

    // Guardrail: allow external module imports ONLY for Three.js.
    // Your compiler targets WebGL via Three.js ES modules, which inherently needs a URL import.
    // Keep this strict so arbitrary remote scripts/styles can't sneak into exports.
    final allowedPrefixes = <String>[
      // jsDelivr
      'https://cdn.jsdelivr.net/npm/three@',
      'https://cdn.jsdelivr.net/npm/three/',
      // unpkg
      'https://unpkg.com/three@',
      'https://unpkg.com/three/',
    ];

    // Collect external URLs from src/href attributes.
    // NOTE: This is intentionally simple; we only need to police outbound URLs.
    final attrUrlRe = RegExp("\\b(?:src|href)\\s*=\\s*([\"'])(.*?)\\1", caseSensitive: false, dotAll: true);
    final urls = <String>[];
    for (final m in attrUrlRe.allMatches(s)) {
      final raw = m.group(2);
      if (raw == null) continue;
      final url = raw.trim();
      if (url.isEmpty) continue;
      urls.add(url);
    }

    // Reject protocol-relative URLs entirely ("//...") to keep exports deterministic.
    final protocolRelative = urls.where((u) => u.startsWith('//')).toList();
    if (protocolRelative.isNotEmpty) {
      debugPrint('HTML validation failed: protocol-relative URLs: ${protocolRelative.take(3).join(', ')}');
      return const HtmlValidationResult(isValid: false, message: 'Protocol-relative URLs are not allowed');
    }

    final external = urls.where((u) => u.toLowerCase().startsWith('http://') || u.toLowerCase().startsWith('https://')).toList();
    if (external.isNotEmpty) {
      final disallowed = <String>[];
      for (final url in external) {
        final allowed = allowedPrefixes.any((p) => url.toLowerCase().startsWith(p));
        if (!allowed) disallowed.add(url);
      }
      if (disallowed.isNotEmpty) {
        debugPrint('HTML validation failed: disallowed external URLs: ${disallowed.take(3).join(', ')}');
        return const HtmlValidationResult(isValid: false, message: 'External URLs found (only Three.js module imports are allowed)');
      }
    }

    // Very rough tag balance check for the most common structure killers.
    int count(String token) => RegExp(RegExp.escape(token), caseSensitive: false).allMatches(s).length;
    if (count('<script') != count('</script>')) {
      return const HtmlValidationResult(isValid: false, message: 'Unbalanced <script> tags');
    }
    if (count('<style') != count('</style>')) {
      return const HtmlValidationResult(isValid: false, message: 'Unbalanced <style> tags');
    }

    return const HtmlValidationResult(isValid: true, message: 'OK');
  }
}

@immutable
class HtmlValidationResult {
  const HtmlValidationResult({required this.isValid, required this.message});

  final bool isValid;
  final String message;
}
