import 'package:flutter/material.dart';

class HtmlArtifactPreviewImpl extends StatelessWidget {
  const HtmlArtifactPreviewImpl({super.key, required this.artifactId, required this.html});

  final String artifactId;
  final String html;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: SelectableText(html, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.4)),
        ),
      ),
    );
  }
}
