import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

abstract final class HtmlArtifactExportImpl {
  static Future<void> copyToClipboard(String html) async {
    try {
      await Clipboard.setData(ClipboardData(text: html));
    } catch (e) {
      debugPrint('Failed to copy artifact HTML: $e');
      rethrow;
    }
  }

  static void downloadAsHtmlFile({required String filename, required String html}) {
    try {
      final url = 'data:text/html;charset=utf-8,${Uri.encodeComponent(html)}';
      final a = web.HTMLAnchorElement()
        ..href = url
        ..download = filename
        ..style.display = 'none';
      web.document.body!.append(a);
      a.click();
      a.remove();
    } catch (e) {
      debugPrint('Failed to download artifact HTML: $e');
      rethrow;
    }
  }
}
