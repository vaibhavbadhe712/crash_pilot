import 'dart:convert';
import '../ast/ast_context.dart';
import '../models/crash_report.dart';
import '../models/patch_result.dart';

/// Abstract contract for LLM inference providers in CrashPilot.
abstract class AiProvider {
  /// Synthesizes an initial surgical patch and regression test for a crash.
  Future<PatchResult> generatePatch({
    required CrashReport crash,
    required AstContext astContext,
  });

  /// Refines a previous patch after sandbox verification failure (Reflection loop).
  Future<PatchResult> refinePatch({
    required CrashReport crash,
    required AstContext astContext,
    required PatchResult previousPatch,
    required String failureLogs,
    required int attemptNumber,
  });

  /// Helper to safely parse JSON from LLM responses even if wrapped in markdown blocks.
  static Map<String, dynamic> extractJson(String raw) {
    var cleaned = raw.trim();

    // Strip markdown code fences if present
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }

    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    // Find first { and last }
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }

    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException(
          'Failed to parse LLM response into JSON: $e\nRaw Output:\n$raw');
    }
  }

  /// Parses JSON map into [PatchResult].
  static PatchResult parsePatchResult(
    Map<String, dynamic> json, {
    required String defaultFile,
    required int turn,
    bool isRefinement = false,
    String? raw,
  }) {
    return PatchResult(
      explanation: json['explanation'] as String? ?? 'Autonomous surgical fix',
      culpritFile: (json['culprit_file'] as String?)?.isNotEmpty == true
          ? json['culprit_file'] as String
          : defaultFile,
      originalSnippet: json['original_snippet'] as String? ?? '',
      replacementSnippet: json['replacement_snippet'] as String? ?? '',
      regressionTestCode: json['regression_test_code'] as String? ?? '',
      regressionTestPath: json['regression_test_path'] as String? ??
          'test/generated_crash_test.dart',
      turnNumber: turn,
      isRefinement: isRefinement,
      rawResponse: raw,
    );
  }
}
