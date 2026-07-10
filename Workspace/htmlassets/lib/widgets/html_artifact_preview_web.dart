import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

class HtmlArtifactPreviewImpl extends StatefulWidget {
  const HtmlArtifactPreviewImpl({super.key, required this.artifactId, required this.html});

  final String artifactId;
  final String html;

  @override
  State<HtmlArtifactPreviewImpl> createState() => _HtmlArtifactPreviewImplState();
}

class _HtmlArtifactPreviewImplState extends State<HtmlArtifactPreviewImpl> {
  static final Set<String> _registeredViewTypes = <String>{};

  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = _viewTypeFor(widget.artifactId);
    _ensureRegistered(viewType: _viewType, html: widget.html, artifactId: widget.artifactId);
  }

  @override
  void didUpdateWidget(covariant HtmlArtifactPreviewImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.artifactId != oldWidget.artifactId) {
      // Most reliable fix: create a brand new platform view + iframe per artifact.
      // Some hosts/browsers can stop re-executing module scripts after several
      // srcdoc updates on the same iframe.
      final nextViewType = _viewTypeFor(widget.artifactId);
      _ensureRegistered(viewType: nextViewType, html: widget.html, artifactId: widget.artifactId);
      setState(() => _viewType = nextViewType);
    }
  }

  String _viewTypeFor(String artifactId) {
    final safe = artifactId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'artifact-iframe-$safe';
  }

  void _ensureRegistered({required String viewType, required String html, required String artifactId}) {
    if (_registeredViewTypes.contains(viewType)) return;
    _registeredViewTypes.add(viewType);

    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement();
      iframe.setAttribute('style', 'border:0;width:100%;height:100%;');
      iframe.setAttribute('sandbox', 'allow-scripts allow-same-origin');
      // Setting both property and attribute tends to be more reliable than
      // attribute alone across hosts/browsers.
      iframe.srcdoc = html.toJS;
      iframe.setAttribute('srcdoc', html);
      iframe.tabIndex = -1;
      iframe.addEventListener(
        'load',
        ((web.Event _) {
          debugPrint('Preview iframe loaded. artifactId=$artifactId viewId=$viewId');
        }).toJS,
      );
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(color: Theme.of(context).colorScheme.surface, child: HtmlElementView(viewType: _viewType, key: ValueKey<String>(_viewType))),
    );
  }
}
