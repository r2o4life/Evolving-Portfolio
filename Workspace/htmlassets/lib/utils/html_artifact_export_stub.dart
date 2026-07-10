import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
    throw UnsupportedError('Download is only supported on web in this prototype.');
  }
}
