import 'dart:io';
import 'package:crash_pilot/crash_pilot.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Test verifier that returns simulated passing results
class _FakeVerifier extends SandboxVerifier {
  _FakeVerifier({super.workspaceRoot});

  @override
  Future<VerificationResult> verify({
    required PatchResult patch,
    bool runFullTestSuites = false,
  }) async {
    return const VerificationResult(
      success: true,
      analyzePassed: true,
      testPassed: true,
      analyzeOutput: 'No issues found!',
      testOutput: 'All tests passed!',
      duration: Duration(milliseconds: 120),
    );
  }
}

void main() {
  group('CrashPilotEngine End-to-End Orchestration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cp_engine_test_');
      final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync();
      File(p.join(libDir.path, 'counter.dart')).writeAsStringSync('''
class Counter {
  int? count;
  void increment() {
    count = count! + 1;
  }
}
''');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Autonomous healing loop succeeds and writes diagnostic PR report', () async {
      final config = CrashPilotConfig(
        aiProvider: 'mock',
        dryRun: true,
        autoShorebirdPatch: false,
      );

      final engine = CrashPilotEngine(
        config: config,
        workspaceRoot: tempDir.path,
        customAiProvider: MockAiProvider(),
        customVerifier: _FakeVerifier(workspaceRoot: tempDir.path),
      );

      const sampleTrace = '''
Null check operator used on a null value
#0      Counter.increment (package:my_app/counter.dart:4:18)
''';

      final crash = StackTraceParser.parse(
        rawException: sampleTrace,
        source: 'test',
      );

      final result = await engine.heal(crash);

      expect(result.success, isTrue);
      expect(result.patch, isNotNull);
      expect(result.summary, contains('autonomously healed'));

      final reportFile = File(p.join(tempDir.path, 'CRASHPILOT_PR_REPORT.md'));
      expect(reportFile.existsSync(), isTrue);
      final reportText = reportFile.readAsStringSync();
      expect(reportText, contains('CrashPilot Autonomous Self-Heal Report'));
      expect(reportText, contains('Null check operator used on a null value'));
    });
  });
}
