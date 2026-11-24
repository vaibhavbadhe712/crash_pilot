import 'package:meta/meta.dart';

/// Result of an AI-synthesized surgical patch and accompanying regression test.
@immutable
class PatchResult {
  final String explanation;
  final String culpritFile;
  final String originalSnippet;
  final String replacementSnippet;
  final String regressionTestCode;
  final String regressionTestPath;
  final int turnNumber;
  final String? rawResponse;
  final bool isRefinement;

  const PatchResult({
    required this.explanation,
    required this.culpritFile,
    required this.originalSnippet,
    required this.replacementSnippet,
    required this.regressionTestCode,
    required this.regressionTestPath,
    this.turnNumber = 1,
    this.rawResponse,
    this.isRefinement = false,
  });

  Map<String, dynamic> toMap() => {
        'explanation': explanation,
        'culpritFile': culpritFile,
        'originalSnippet': originalSnippet,
        'replacementSnippet': replacementSnippet,
        'regressionTestCode': regressionTestCode,
        'regressionTestPath': regressionTestPath,
        'turnNumber': turnNumber,
        'isRefinement': isRefinement,
      };

  factory PatchResult.fromMap(Map<String, dynamic> map) => PatchResult(
        explanation: map['explanation'] as String? ?? 'Autonomous patch applied',
        culpritFile: map['culpritFile'] as String? ?? '',
        originalSnippet: map['originalSnippet'] as String? ?? '',
        replacementSnippet: map['replacementSnippet'] as String? ?? '',
        regressionTestCode: map['regressionTestCode'] as String? ?? '',
        regressionTestPath: map['regressionTestPath'] as String? ??
            'test/generated_crash_test.dart',
        turnNumber: map['turnNumber'] as int? ?? 1,
        rawResponse: map['rawResponse'] as String?,
        isRefinement: map['isRefinement'] as bool? ?? false,
      );

  @override
  String toString() =>
      'PatchResult(file: $culpritFile, turn: $turnNumber, refined: $isRefinement)';
}
