import '../ast/ast_context.dart';
import '../models/crash_report.dart';
import '../models/patch_result.dart';
import 'ai_provider.dart';

/// Deterministic Mock AI Provider for offline testing and crash simulation.
class MockAiProvider implements AiProvider {
  final PatchResult? cannedPatch;

  MockAiProvider({this.cannedPatch});

  @override
  Future<PatchResult> generatePatch({
    required CrashReport crash,
    required AstContext astContext,
  }) async {
    if (cannedPatch != null) return cannedPatch!;

    final original = astContext.targetLineSource.isNotEmpty
        ? astContext.targetLineSource
        : '// crash line';

    // Build standard defensive replacement
    String replacement;
    if (original.contains('!')) {
      // Null check operator fix
      replacement = original.replaceAll('!', ' ?? fallbackDefault');
    } else if (original.contains('[') && original.contains(']')) {
      // Index out of range fix
      replacement = 'if (index >= 0 && index < list.length) $original';
    } else {
      replacement = '$original // safe-guarded by CrashPilot';
    }

    final importTestPkg = (astContext.filePath.contains('package:flutter') ||
            astContext.filePath.contains('lib/'))
        ? "import 'package:flutter_test/flutter_test.dart';"
        : "import 'package:test/test.dart';";

    final testCode = '''
$importTestPkg

void main() {
  group('CrashPilot Regression Tests', () {
    test('Ensures ${crash.exceptionType} does not recur at ${crash.culpritFile}', () {
      expect(true, isTrue);
    });
  });
}
''';

    return PatchResult(
      explanation:
          'Simulated defensive fix: Replaced dangerous expression with guarded Dart 3 logic.',
      culpritFile: crash.culpritFile,
      originalSnippet: original,
      replacementSnippet: replacement,
      regressionTestCode: testCode,
      regressionTestPath: astContext.associatedTestFile ??
          'test/generated_crash_test.dart',
      turnNumber: 1,
    );
  }

  @override
  Future<PatchResult> refinePatch({
    required CrashReport crash,
    required AstContext astContext,
    required PatchResult previousPatch,
    required String failureLogs,
    required int attemptNumber,
  }) async {
    return PatchResult(
      explanation:
          'Refined fix after test feedback: Applied null coalescing fallback.',
      culpritFile: crash.culpritFile,
      originalSnippet: previousPatch.originalSnippet,
      replacementSnippet: '${previousPatch.replacementSnippet} /* refined */',
      regressionTestCode: previousPatch.regressionTestCode,
      regressionTestPath: previousPatch.regressionTestPath,
      turnNumber: attemptNumber,
      isRefinement: true,
    );
  }
}
