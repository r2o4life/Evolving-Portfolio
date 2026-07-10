import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:html_artifact_pipeline/models/html_artifact.dart';
import 'package:html_artifact_pipeline/services/local_artifact_compiler_service.dart';
import 'package:html_artifact_pipeline/theme.dart';
import 'package:html_artifact_pipeline/utils/html_artifact_export.dart';
import 'package:html_artifact_pipeline/utils/html_artifact_validator.dart';
import 'package:html_artifact_pipeline/widgets/html_artifact_preview.dart';

class CompilerPage extends StatefulWidget {
  const CompilerPage({super.key, this.initialPrompt});

  final String? initialPrompt;

  @override
  State<CompilerPage> createState() => _CompilerPageState();
}

class _CompilerPageState extends State<CompilerPage> {
  final _compiler = LocalArtifactCompilerService();

  late final TextEditingController _promptController;

  // Keep the experience lean: no user-facing seed/style/size knobs.
  // These are set deterministically under the hood for repeatable artifacts.
  static const String _defaultStyle = 'Blueprint';
  static const int _defaultWidth = 980;
  static const int _defaultHeight = 640;

  bool _isCompiling = false;
  HtmlArtifact? _artifact;
  HtmlValidationResult? _validation;

  int _latestRequestId = 0;
  String? _lastPromptEcho;
  String? _lastStage;
  String? _lastError;

  String _slugifyPrompt(String prompt) {
    final s = prompt.trim().toLowerCase();
    if (s.isEmpty) return 'object';
    final buf = StringBuffer();
    bool lastWasDash = false;
    for (final codeUnit in s.codeUnits) {
      final ch = String.fromCharCode(codeUnit);
      final isAz = codeUnit >= 97 && codeUnit <= 122;
      final is09 = codeUnit >= 48 && codeUnit <= 57;
      if (isAz || is09) {
        buf.write(ch);
        lastWasDash = false;
      } else {
        if (!lastWasDash && buf.isNotEmpty) {
          buf.write('-');
          lastWasDash = true;
        }
      }
      if (buf.length >= 48) break;
    }
    final out = buf.toString().replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-+'), '').replaceAll(RegExp(r'-+$'), '');
    return out.isEmpty ? 'object' : out;
  }

  Future<String> _buildExportHtml(HtmlArtifact artifact) =>
      _compiler.buildExportHtml(prompt: artifact.prompt, seed: artifact.seed, style: artifact.style, width: artifact.width, height: artifact.height);

  @override
  void initState() {
    super.initState();
    final hasInitialPrompt = widget.initialPrompt?.trim().isNotEmpty ?? false;
    _promptController = TextEditingController(text: hasInitialPrompt ? widget.initialPrompt!.trim() : 'drone');
    
    if (hasInitialPrompt) {
      // Auto-compile when navigating from the Ingress Page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _compile();
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  int _seedForPrompt(String prompt) {
    // Simple 32-bit FNV-1a hash.
    final input = prompt.trim().toLowerCase();
    var hash = 0x811C9DC5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1337 : hash;
  }

  Future<void> _compile() async {
    if (_isCompiling) return;
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a semantic object first.')));
      return;
    }

    final requestId = ++_latestRequestId;
    setState(() {
      _isCompiling = true;
      _lastPromptEcho = prompt;
      _lastStage = 'compile:start';
      _lastError = null;
    });
    try {
      final startedAt = DateTime.now();
      final artifact = await _compiler.compile(
        prompt: prompt,
        seed: _seedForPrompt(prompt),
        style: _defaultStyle,
        width: _defaultWidth,
        height: _defaultHeight,
      );
      if (!mounted) return;
      if (requestId != _latestRequestId) {
        debugPrint('Ignoring stale compile result. requestId=$requestId latest=$_latestRequestId');
        return;
      }
      setState(() {
        _artifact = artifact;
        _validation = HtmlArtifactValidator.validate(artifact.html);
        _lastStage = 'compile:done-${DateTime.now().difference(startedAt).inMilliseconds}ms';
      });
    } catch (e) {
      debugPrint('Compile failed: $e');
      if (!mounted) return;
      if (requestId != _latestRequestId) return;
      setState(() {
        _lastStage = 'compile:error';
        _lastError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compile failed. Check logs.')));
    } finally {
      if (!mounted) return;
      if (requestId != _latestRequestId) return;
      setState(() => _isCompiling = false);
    }
  }

  Future<void> _copyHtml() async {
    final artifact = _artifact;
    if (artifact == null) return;
    final html = await _buildExportHtml(artifact);
    final validation = HtmlArtifactValidator.validate(html);
    if (!validation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export HTML not valid: ${validation.message}')));
      return;
    }

    try {
      await HtmlArtifactExport.copyToClipboard(html);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('HTML copied to clipboard.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copy failed. Check logs.')));
    }
  }

  Future<void> _downloadHtml() async {
    final artifact = _artifact;
    if (artifact == null) return;

    final exportHtml = await _buildExportHtml(artifact);
    final validation = HtmlArtifactValidator.validate(exportHtml);
    if (!validation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export HTML not valid: ${validation.message}')));
      return;
    }

    try {
      final slug = _slugifyPrompt(artifact.prompt);
      HtmlArtifactExport.downloadAsHtmlFile(filename: 'index_${slug}.html', html: exportHtml);
    } catch (e) {
      debugPrint('Download failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download is only available on web.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final a = _artifact;
    final telemetry = <String>[
      if (_lastPromptEcho != null) 'promptEcho="${_lastPromptEcho!.replaceAll('\n', ' ')}"',
      'requestId=$_latestRequestId',
      if (_lastStage != null) 'stage=$_lastStage',
      if (a != null) 'artifactId=${a.id}',
      if (a != null) 'kind=${a.objectKind}',
      if (a != null && a.spatialLogic.trim().isNotEmpty) 'spatialLogic="${a.spatialLogic.replaceAll('\n', ' ')}"',
      if (a != null) 'model=${a.generationModel}',
      if (a != null) 'isFallback=${a.isFallback}',
      if (a != null && (a.fallbackReason?.trim().isNotEmpty ?? false)) 'fallbackReason=${a.fallbackReason}',
      if (a != null && (a.contractVersion?.trim().isNotEmpty ?? false)) 'contract=${a.contractVersion}',
      if (_lastError != null) 'error=${_lastError!.replaceAll('\n', ' ')}',
    ].join(' • ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compiler'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            onPressed: (_artifact == null || (_validation?.isValid ?? false) == false) ? null : _copyHtml,
            icon: Icon(Icons.content_copy_rounded, color: (_artifact == null || (_validation?.isValid ?? false) == false) ? cs.onSurface.withValues(alpha: 0.35) : cs.onSurface),
            tooltip: 'Copy HTML',
          ),
          IconButton(
            onPressed: (_artifact == null || (_validation?.isValid ?? false) == false) ? null : () => _downloadHtml(),
            icon: Icon(Icons.download_rounded, color: (_artifact == null || (_validation?.isValid ?? false) == false) ? cs.onSurface.withValues(alpha: 0.35) : cs.onSurface),
            tooltip: kIsWeb ? 'Download HTML' : 'Download (web only)',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;
                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 380, child: _CompilerPanel(isCompiling: _isCompiling, promptController: _promptController, onCompile: _compile)),
                            const SizedBox(width: 18),
                            Expanded(child: _PreviewPanel(artifact: _artifact, isCompiling: _isCompiling, validation: _validation, telemetryLine: telemetry)),
                          ],
                        )
                      : ListView(
                          children: [
                            _CompilerPanel(isCompiling: _isCompiling, promptController: _promptController, onCompile: _compile),
                            const SizedBox(height: 18),
                            _PreviewPanel(artifact: _artifact, isCompiling: _isCompiling, validation: _validation, telemetryLine: telemetry),
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompilerPanel extends StatelessWidget {
  const _CompilerPanel({
    required this.isCompiling,
    required this.promptController,
    required this.onCompile,
  });

  final bool isCompiling;
  final TextEditingController promptController;
  final Future<void> Function() onCompile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compile', style: context.textStyles.titleMedium?.semiBold),
            Text('Enter a semantic object, compile, then export a clean index.html.', style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            TextField(
              controller: promptController,
              textInputAction: TextInputAction.go,
              maxLines: 1,
              onSubmitted: (_) {
                if (!isCompiling) onCompile();
              },
              decoration: InputDecoration(
                labelText: 'Semantic object',
                hintText: 'drone',
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isCompiling ? null : () => onCompile(),
                icon: Icon(isCompiling ? Icons.hourglass_top_rounded : Icons.bolt_rounded, color: cs.onPrimary),
                label: Text(isCompiling ? 'Compiling…' : 'Compile artifact', style: TextStyle(color: cs.onPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.artifact, required this.isCompiling, required this.validation, required this.telemetryLine});

  final HtmlArtifact? artifact;
  final bool isCompiling;
  final HtmlValidationResult? validation;
  final String telemetryLine;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget content;
    if (artifact == null) {
      content = Container(
        height: 420,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.web_asset_rounded, size: 34, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No artifact generated yet', style: context.textStyles.titleMedium?.semiBold),
            const SizedBox(height: 6),
            Text('Compile to generate a single-file index.html and preview it here.', style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ),
      );
    } else {
      final v = validation;
      final a = artifact!;
      final kind = (a.objectKind.trim().isEmpty) ? 'object' : a.objectKind.trim();
      final src = a.isFallback ? 'fallback' : 'groq';
      content = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Preview', style: context.textStyles.titleMedium?.semiBold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: (v?.isValid ?? false) ? Colors.green : cs.tertiary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text((v?.isValid ?? false) ? 'exportable' : 'check', style: context.textStyles.labelMedium?.withColor(cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (a.isFallback) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: cs.tertiaryContainer.withValues(alpha: 0.35),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: cs.onTertiaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI output was downgraded to a deterministic fallback shape.'
                        '${(a.fallbackReason?.trim().isNotEmpty ?? false) ? "\nReason: ${a.fallbackReason}" : ""}'
                        '\nIf the reason is “no-key”, the Cloud Function is missing the GROQ_API_KEY secret.',
                        style: context.textStyles.bodySmall?.withColor(cs.onTertiaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            AspectRatio(
              aspectRatio: (a.width <= 0 ? 1 : a.width) / (a.height <= 0 ? 1 : a.height),
              child: HtmlArtifactPreview(artifactId: a.id, html: a.html),
            ),
            const SizedBox(height: 12),
            Text(
              '${a.prompt} • kind: $kind • source: $src (${a.generationModel}) • ${a.width}×${a.height} • compiler: ${a.compilerVersion}${(v == null) ? '' : ' • validate: ${v.message}'}',
              style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              telemetryLine,
              style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: isCompiling
          ? _LoadingOverlay(child: content)
          : content,
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.78),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
                      const SizedBox(width: 10),
                      Text('Compiling…', style: context.textStyles.labelLarge?.withColor(cs.onSurface)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
