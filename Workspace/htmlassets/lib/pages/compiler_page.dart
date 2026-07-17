import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

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

  static const String _defaultStyle = 'Blueprint';
  static const int _defaultWidth = 980;
  static const int _defaultHeight = 640;

  bool _isCompiling = false;
  HtmlArtifact? _artifact;
  HtmlValidationResult? _validation;

  int _latestRequestId = 0;
  String? _lastError;
  
  // Telemetry stages
  final List<_TelemetryEvent> _telemetryEvents = [];
  Timer? _telemetryTimer;

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _compile();
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _telemetryTimer?.cancel();
    super.dispose();
  }

  int _seedForPrompt(String prompt) {
    final input = prompt.trim().toLowerCase();
    var hash = 0x811C9DC5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1337 : hash;
  }

  void _pushTelemetry(String stage, String details, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _telemetryEvents.add(_TelemetryEvent(
        timestamp: DateTime.now(),
        stage: stage,
        details: details,
        isError: isError,
      ));
    });
  }

  void _startSimulatedTelemetryPipeline(int requestId) {
    _telemetryTimer?.cancel();
    int step = 0;
    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted || requestId != _latestRequestId || !_isCompiling) {
        timer.cancel();
        return;
      }
      step++;
      if (step == 1) _pushTelemetry('sys.AST_Parse', 'Syntactic intent resolved. Constructing graph.');
      if (step == 2) _pushTelemetry('eng.GenSynth', 'Omni-pillar synthesis initiated. Executing generation.');
      if (step == 3) _pushTelemetry('DOM.Render', 'Hydrating nodes. Establishing kinetic event listeners.');
    });
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
      _lastError = null;
      _artifact = null;
      _validation = null;
      _telemetryEvents.clear();
    });
    
    final startTime = DateTime.now();
    _pushTelemetry('pipeline.Init', 'Initializing paradigm engine for: "$prompt"');
    _startSimulatedTelemetryPipeline(requestId);

    try {
      final artifact = await _compiler.compile(
        prompt: prompt,
        seed: _seedForPrompt(prompt),
        style: _defaultStyle,
        width: _defaultWidth,
        height: _defaultHeight,
      );
      if (!mounted || requestId != _latestRequestId) return;
      
      final dt = DateTime.now().difference(startTime).inMilliseconds;
      _pushTelemetry('validation.DOM', 'Artifact validated in ${dt}ms.', isError: false);
      
      setState(() {
        _artifact = artifact;
        _validation = HtmlArtifactValidator.validate(artifact.html);
      });
    } catch (e) {
      debugPrint('Compile failed: $e');
      if (!mounted || requestId != _latestRequestId) return;
      setState(() {
        _lastError = e.toString();
        _pushTelemetry('ERR.Halt', 'Pipeline crashed: $e', isError: true);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compile failed. Check logs.')));
    } finally {
      if (!mounted || requestId != _latestRequestId) return;
      setState(() => _isCompiling = false);
      _telemetryTimer?.cancel();
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
      HtmlArtifactExport.downloadAsHtmlFile(filename: 'index_$slug.html', html: exportHtml);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download is only available on web.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _artifact != null && (_validation?.isValid ?? false);

    return Scaffold(
      backgroundColor: Colors.black, // Forcing a dark, terminal-like feel for the SYNTACTIC paradigm
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.hub_rounded, size: 20, color: Colors.blueAccent),
            const SizedBox(width: 8),
            const Text('Paradigm Exec', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          ],
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
          tooltip: 'Abort & Back',
        ),
        actions: [
          _ActionButton(
            icon: Icons.content_copy_rounded,
            label: 'Copy payload',
            enabled: isReady,
            onTap: _copyHtml,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.download_rounded,
            label: 'Export .html',
            enabled: isReady,
            onTap: _downloadHtml,
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white10, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // TOP CONTROLS (Command-K like)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: Colors.grey.shade900,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14),
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) { if (!_isCompiling) _compile(); },
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.terminal_rounded, size: 18, color: Colors.white54),
                        hintText: 'Enter command payload...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.black,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.blueAccent)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onPressed: _isCompiling ? null : _compile,
                    icon: _isCompiling ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(_isCompiling ? 'EXECUTING' : 'EXECUTE'),
                  ),
                ],
              ),
            ),
            Container(color: Colors.white10, height: 1),
            
            // MAIN CONTENT (Telemetry + Preview)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // TELEMETRY PANEL
                  Container(
                    width: 320,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.white10)),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _telemetryEvents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final event = _telemetryEvents[index];
                        return _TelemetryRow(event: event);
                      },
                    ),
                  ),
                  
                  // ARTIFACT PREVIEW PANEL
                  Expanded(
                    child: Container(
                      color: Colors.black,
                      padding: const EdgeInsets.all(24),
                      child: _isCompiling && _artifact == null
                          ? _buildCompilingState()
                          : _artifact == null
                              ? _buildEmptyState()
                              : _buildArtifactState(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompilingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.blueAccent),
          const SizedBox(height: 16),
          Text('SYNTHESIZING PAYLOAD...', style: TextStyle(color: Colors.blueAccent.shade100, fontFamily: 'monospace', letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.input_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('AWAITING COMMAND', style: TextStyle(color: Colors.white38, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildArtifactState() {
    final a = _artifact!;
    final v = _validation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: (v?.isValid ?? false) ? Colors.green.shade900 : Colors.red.shade900, borderRadius: BorderRadius.circular(4)),
              child: Text(
                (v?.isValid ?? false) ? 'VALIDATED' : 'FAULT',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(width: 8),
            Text('ID: ${a.id.substring(0, 8)}', style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace')),
            const Spacer(),
            Text('${a.width}x${a.height} | ${a.generationModel}', style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: (a.width <= 0 ? 1 : a.width) / (a.height <= 0 ? 1 : a.height),
              child: HtmlArtifactPreview(artifactId: a.id, html: a.html),
            ),
          ),
        ),
      ],
    );
  }
}

class _TelemetryEvent {
  final DateTime timestamp;
  final String stage;
  final String details;
  final bool isError;
  _TelemetryEvent({required this.timestamp, required this.stage, required this.details, this.isError = false});
}

class _TelemetryRow extends StatelessWidget {
  const _TelemetryRow({required this.event});
  final _TelemetryEvent event;

  @override
  Widget build(BuildContext context) {
    final timeStr = '${event.timestamp.second.toString().padLeft(2,'0')}.${event.timestamp.millisecond.toString().padLeft(3,'0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(timeStr, style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.stage, style: TextStyle(color: event.isError ? Colors.redAccent : Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              const SizedBox(height: 2),
              Text(event.details, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.enabled, required this.onTap});
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
    );
  }
}
