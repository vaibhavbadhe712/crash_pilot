import '../ast/ast_context.dart';
import '../models/crash_report.dart';

/// Structured prompt templates for synthesizing surgical Dart/Flutter hot-patches.
class PromptTemplates {
  /// System prompt instructing the AI on strict surgical constraints.
  static const String systemPrompt = '''
You are CrashPilot, an autonomous, enterprise-grade AI engineer specialized in Dart 3 and Flutter.
Your task is to analyze production crash reports, identify the exact root cause, and synthesize:
1. A minimal, surgical patch (diff) that fixes the bug defensively without rewriting entire files.
2. A focused regression unit test using package:test or package:flutter_test that proves the crash scenario is eliminated.

STRICT RULES:
- RULE 1: SURGICAL PRECISION. Only replace the minimal necessary lines (5-15 lines). Never rewrite entire methods, classes, or files.
- RULE 2: DART 3 IDIOMS. Use sound null-safety, safe navigation (`?.`), fallback defaults (`??`), pattern matching, and bounds checks.
- RULE 3: NEVER use forced unwraps (`!`) on potentially null objects.
- RULE 4: PRESERVE BEHAVIOR. Never alter unrelated business logic or public method signatures.
- RULE 5: JSON OUTPUT ONLY. Respond with a single valid JSON object and NO surrounding Markdown or code fences.
''';

  /// Generates the initial user prompt for a crash.
  static String buildInitialPrompt({
    required CrashReport crash,
    required AstContext astContext,
  }) {
    return '''
CRASH DETAILS:
- Exception Type: ${crash.exceptionType}
- Exception Message: ${crash.exceptionMessage}
- Culprit File: ${crash.culpritFile} (Line ${crash.lineNumber}, Col ${crash.columnNumber})
- Culprit Member: ${crash.culpritMember}
- Enclosing Class: ${astContext.enclosingClass ?? 'None'}
- Enclosing Method: ${astContext.enclosingMethod ?? 'None'}
- Associated Test File: ${astContext.associatedTestFile ?? 'test/crash_regression_test.dart'}

CRASH SITE CODE (Surrounding Lines):
```dart
${astContext.surroundingLines.join('\n')}
```

TARGET ENCLOSING METHOD SOURCE:
```dart
${astContext.methodSource}
```

STACK TRACE:
```
${crash.rawStackTrace.split('\n').take(12).join('\n')}
```

OUTPUT FORMAT:
Respond with ONLY a raw JSON object with this exact structure:
{
  "explanation": "Clear explanation of the root cause and how the surgical fix resolves it",
  "culprit_file": "${crash.culpritFile}",
  "original_snippet": "The EXACT contiguous string in the file to be replaced (must match whitespace exactly)",
  "replacement_snippet": "The drop-in replacement code (clean, defensive Dart 3)",
  "regression_test_code": "Complete valid Dart test file code starting with import 'package:test/test.dart';",
  "regression_test_path": "${astContext.associatedTestFile ?? 'test/generated_crash_test.dart'}"
}
''';
  }

  /// Prompt for self-correction / reflection when sandbox verification fails.
  static String buildReflectionPrompt({
    required CrashReport crash,
    required AstContext astContext,
    required String previousPatchSnippet,
    required String testFailureOutput,
    required int attemptNumber,
  }) {
    return '''
ATTEMPT $attemptNumber FAILED IN SANDBOX VERIFICATION.

PREVIOUS PROPOSED FIX:
```dart
$previousPatchSnippet
```

TEST / STATIC ANALYSIS FAILURE OUTPUT:
```
$testFailureOutput
```

TASK:
Analyze why the previous fix failed verification. Correct the error and output a refined surgical patch and test.
Remember: Match "original_snippet" character-for-character with the actual file source.

OUTPUT FORMAT:
Respond with ONLY a valid JSON object matching the exact same schema.
''';
  }
}
