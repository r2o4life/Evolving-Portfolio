import 'package:flutter/foundation.dart';

@immutable
class HtmlArtifact {
  const HtmlArtifact({
    required this.id,
    required this.prompt,
    required this.html,
    required this.createdAt,
    required this.seed,
    required this.style,
    required this.width,
    required this.height,
    required this.compilerVersion,
    required this.objectKind,
    required this.spatialLogic,
    required this.generationModel,
    required this.isFallback,
    required this.fallbackReason,
    required this.contractVersion,
  });

  final String id;
  final String prompt;
  final String html;
  final DateTime createdAt;
  final int seed;
  final String style;
  final int width;
  final int height;
  final String compilerVersion;

  /// The inferred object label used by the particle compiler.
  ///
  /// This may be AI-generated, or derived from fallback logic.
  final String objectKind;

  /// A 1-sentence description of the geometric reduction used to build the SDF.
  final String spatialLogic;

  /// Identifier for the generation source (e.g. Groq model name or `fallback-...`).
  final String generationModel;

  /// Whether this artifact was produced using deterministic fallback generation.
  final bool isFallback;

  /// When `isFallback == true`, why we downgraded to fallback.
  ///
  /// This is a *structured* reason (not just a human message), so it can be
  /// displayed and filtered in telemetry.
  final String? fallbackReason;

  /// Version marker for the backend/client schema contract.
  final String? contractVersion;

  HtmlArtifact copyWith({
    String? id,
    String? prompt,
    String? html,
    DateTime? createdAt,
    int? seed,
    String? style,
    int? width,
    int? height,
    String? compilerVersion,
    String? objectKind,
    String? spatialLogic,
    String? generationModel,
    bool? isFallback,
    String? fallbackReason,
    String? contractVersion,
  }) =>
      HtmlArtifact(
        id: id ?? this.id,
        prompt: prompt ?? this.prompt,
        html: html ?? this.html,
        createdAt: createdAt ?? this.createdAt,
        seed: seed ?? this.seed,
        style: style ?? this.style,
        width: width ?? this.width,
        height: height ?? this.height,
        compilerVersion: compilerVersion ?? this.compilerVersion,
        objectKind: objectKind ?? this.objectKind,
        spatialLogic: spatialLogic ?? this.spatialLogic,
        generationModel: generationModel ?? this.generationModel,
        isFallback: isFallback ?? this.isFallback,
        fallbackReason: fallbackReason ?? this.fallbackReason,
        contractVersion: contractVersion ?? this.contractVersion,
      );
}
