import 'dart:io';
import 'package:crash_pilot/crash_pilot.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('PatchApplier Tests', () {
    late Directory tempDir;
    late File targetDartFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('crash_pilot_test_');
      final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync();
      targetDartFile = File(p.join(libDir.path, 'sample.dart'));
      targetDartFile.writeAsStringSync('''
void run() {
  final list = <String>[];
  final item = list[0];
  print(item);
}
''');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Applies surgical diff and can roll back atomically', () {
      final applier = PatchApplier(workspaceRoot: tempDir.path);

      const patch = PatchResult(
        explanation: 'Guarded index access',
        culpritFile: 'lib/sample.dart',
        originalSnippet: 'final item = list[0];',
        replacementSnippet: 'final item = list.isNotEmpty ? list[0] : null;',
        regressionTestCode: '// regression test',
        regressionTestPath: 'test/sample_test.dart',
      );

      final success = applier.apply(patch);
      expect(success, isTrue);

      final updatedContent = targetDartFile.readAsStringSync();
      expect(updatedContent, contains('list.isNotEmpty ? list[0] : null;'));
      expect(updatedContent, isNot(contains('final item = list[0];')));

      final generatedTest = File(p.join(tempDir.path, 'test/sample_test.dart'));
      expect(generatedTest.existsSync(), isTrue);

      // Rollback
      applier.rollback();
      final rolledBackContent = targetDartFile.readAsStringSync();
      expect(rolledBackContent, contains('final item = list[0];'));
      expect(generatedTest.existsSync(), isFalse);
    });
  });
}
