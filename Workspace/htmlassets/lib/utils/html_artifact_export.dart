import 'package:html_artifact_pipeline/utils/html_artifact_export_stub.dart'
  if (dart.library.js_interop) 'package:html_artifact_pipeline/utils/html_artifact_export_web.dart';

abstract final class HtmlArtifactExport {
  static Future<void> copyToClipboard(String html) => HtmlArtifactExportImpl.copyToClipboard(html);

  static void downloadAsHtmlFile({required String filename, required String html}) =>
    HtmlArtifactExportImpl.downloadAsHtmlFile(filename: filename, html: html);
}
