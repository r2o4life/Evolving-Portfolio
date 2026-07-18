import 'package:flutter_test/flutter_test.dart';
import 'package:html_artifact_pipeline/services/synthesis_engine.dart';
import 'package:html_artifact_pipeline/services/local_artifact_compiler_service.dart';

void main() {
  group('SynthesisEngine tests', () {
    test('synthesize returns a deterministic sdf for a given prompt', () {
      const prompt = 'futuristic flying car';
      final result1 = SynthesisEngine.synthesize(prompt);
      final result2 = SynthesisEngine.synthesize(prompt);

      expect(result1.kind, 'futuristic');
      expect(result1.isFallback, isFalse);
      expect(result1.sdfJavascript, equals(result2.sdfJavascript));
      expect(result1.spatialLogic, isNotEmpty);
      expect(result1.sdfJavascript.contains('function sdf('), isTrue);
    });

    test('different prompts generate different sdfs', () {
      final result1 = SynthesisEngine.synthesize('apple');
      final result2 = SynthesisEngine.synthesize('banana');

      expect(result1.sdfJavascript, isNot(equals(result2.sdfJavascript)));
    });
  });

  group('LocalArtifactCompilerService tests', () {
    test('compile produces HTML artifact with valid SDF output', () async {
      final compiler = LocalArtifactCompilerService();
      final artifact = await compiler.compile(
        prompt: 'test prompt',
        seed: 42,
        style: 'blueprint',
        width: 800,
        height: 600,
      );

      expect(artifact.prompt, 'test prompt');
      expect(artifact.seed, 42);
      expect(artifact.style, 'blueprint');
      expect(artifact.isFallback, isFalse);
      expect(artifact.generationModel, 'procedural-synthesis-v1');
      expect(artifact.html, contains('function sdf('));
      expect(artifact.html, contains('test prompt'));
      expect(artifact.html, contains('id="c"'));
    });

    test('buildExportHtml produces raw HTML without UI wrappers', () async {
      final compiler = LocalArtifactCompilerService();
      final html = await compiler.buildExportHtml(
        prompt: 'export test',
        seed: 123,
        style: 'museum',
        width: 1024,
        height: 768,
      );

      expect(html, contains('export test'));
      expect(html, contains('function sdf('));
      expect(html, isNot(contains('class="hud"'))); // No HUD in export
    });
  });
}
