import 'dart:math';

class SynthesisResult {
  final String kind;
  final String sdfJavascript;
  final String spatialLogic;
  final String model;
  final bool isFallback;
  final String? fallbackReason;
  final String? contractVersion;

  const SynthesisResult({
    required this.kind,
    required this.sdfJavascript,
    required this.spatialLogic,
    required this.model,
    required this.isFallback,
    this.fallbackReason,
    this.contractVersion,
  });
}

class SynthesisEngine {
  /// Synthesizes a deterministic Signed Distance Function based on the prompt's hash code.
  static SynthesisResult synthesize(String prompt) {
    final lower = prompt.trim().toLowerCase();
    final kind = lower.isEmpty ? 'object' : lower.split(RegExp(r'\s+')).first;
    
    // Seed a random number generator using the prompt's hash code
    final seed = prompt.hashCode;
    final random = Random(seed);

    final numPrimitives = random.nextInt(3) + 2; // 2 to 4 additional primitives
    
    // We will build a function string.
    final sb = StringBuffer();
    sb.writeln('function sdf(px, py, pz) {');
    
    // Core object base
    sb.writeln('  let d = sdBox(px, py, pz, 0.4, 0.4, 0.4);');
    
    for (int i = 0; i < numPrimitives; i++) {
      final r = (random.nextDouble() * 0.3 + 0.1).toStringAsFixed(3);
      final ox = ((random.nextDouble() * 2 - 1) * 0.5).toStringAsFixed(3);
      final oy = ((random.nextDouble() * 2 - 1) * 0.5).toStringAsFixed(3);
      final oz = ((random.nextDouble() * 2 - 1) * 0.5).toStringAsFixed(3);
      
      sb.writeln('  const p$i = sdSphere(px - ($ox), py - ($oy), pz - ($oz), $r);');
      // randomly choose union or subtract
      if (random.nextBool()) {
        sb.writeln('  d = smin(d, p$i, 0.1);');
      } else {
        sb.writeln('  d = Math.max(d, -p$i);');
      }
    }
    
    sb.writeln('  return d;');
    sb.writeln('}');

    return SynthesisResult(
      kind: kind,
      sdfJavascript: sb.toString(),
      spatialLogic: 'Deterministic procedural synthesis generated $numPrimitives additional primitives.',
      model: 'procedural-synthesis-v1',
      isFallback: false,
    );
  }
}
