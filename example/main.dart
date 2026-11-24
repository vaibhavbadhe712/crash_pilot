import 'package:crash_pilot/crash_pilot.dart';

void main() async {
  print('=== CrashPilot Self-Healing Example ===\n');

  // 1. Raw crash trace from Sentry or Crashlytics
  const sampleTrace = '''
Null check operator used on a null value
#0      ScrollPosition.minScrollExtent (package:flutter/src/widgets/scroll_position.dart:235:10)
#1      ScrollController.animateTo (package:flutter/src/widgets/scroll_controller.dart:223:12)
#2      _ChatScreenState._scrollToBottom (package:my_app/features/chat/chat_screen.dart:18:24)
''';

  // 2. Parse the crash into a structured CrashReport
  final crash = StackTraceParser.parse(
    rawException: sampleTrace,
    source: 'crashlytics',
  );

  print('1. Parsed Crash Report:');
  print('   - Type:    ${crash.exceptionType}');
  print('   - Culprit: ${crash.culpritFile}:${crash.lineNumber} in ${crash.culpritMember}');

  // 3. Extract AST context from Dart source
  const sampleDartCode = '''
class _ChatScreenState {
  final ScrollController scrollController = ScrollController();

  void _scrollToBottom() {
    scrollController.animateTo(0);
  }
}
''';

  final ast = DartAstAnalyzer.analyzeSource(
    source: sampleDartCode,
    filePath: crash.culpritFile,
    line: 5,
    column: 5,
  );

  print('\n2. AST Analysis Context:');
  print('   - Enclosing Class:  ${ast.enclosingClass}');
  print('   - Enclosing Method: ${ast.enclosingMethod}');
  print('   - Target Node:      ${ast.nodeType}');

  // 4. Synthesize fix via AI provider
  final mockAi = MockAiProvider();
  final patch = await mockAi.generatePatch(crash: crash, astContext: ast);

  print('\n3. Synthesized Surgical Patch:');
  print('   - Explanation: ${patch.explanation}');
  print('   - Original:    ${patch.originalSnippet}');
  print('   - Replacement: ${patch.replacementSnippet}');

  print('\n=== End of CrashPilot Example ===');
}
