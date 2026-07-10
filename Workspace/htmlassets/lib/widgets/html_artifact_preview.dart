import 'package:flutter/material.dart';

import 'package:html_artifact_pipeline/widgets/html_artifact_preview_stub.dart'
  if (dart.library.js_interop) 'package:html_artifact_pipeline/widgets/html_artifact_preview_web.dart';

/// Renders an HTML string.
///
/// This uses a web iframe when available, and a code preview fallback elsewhere.
class HtmlArtifactPreview extends StatelessWidget {
  const HtmlArtifactPreview({super.key, required this.artifactId, required this.html});

  final String artifactId;
  final String html;

  @override
  Widget build(BuildContext context) => HtmlArtifactPreviewImpl(
    // Keep a stable key so the underlying web iframe state can update in-place.
    // Recreating platform views repeatedly can lead to non-deterministic rendering
    // issues on some browsers/hosts.
    key: const ValueKey<String>('artifact-preview'),
    artifactId: artifactId,
    html: html,
  );
}
