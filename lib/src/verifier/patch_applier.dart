import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/patch_result.dart';

/// Applies surgical diffs to disk with atomic backup and rollback guarantees.
class PatchApplier {
  final String workspaceRoot;
  final Map<String, String> _backups = {};
  final List<String> _createdFiles = [];

  PatchApplier({String? workspaceRoot})
      : workspaceRoot = workspaceRoot ?? Directory.current.path;

  /// Applies a [PatchResult] by updating the target file and writing the regression test.
  bool apply(PatchResult patch) {
    final targetPath = p.isAbsolute(patch.culpritFile)
        ? patch.culpritFile
        : p.join(workspaceRoot, patch.culpritFile);

    final file = File(targetPath);
    if (!file.existsSync()) {
      throw FileSystemException('Target file does not exist', targetPath);
    }

    // Save backup if not already saved
    if (!_backups.containsKey(targetPath)) {
      _backups[targetPath] = file.readAsStringSync();
    }

    final originalContent = _backups[targetPath]!;
    final origSnippet = patch.originalSnippet;
    final replSnippet = patch.replacementSnippet;

    if (!originalContent.contains(origSnippet)) {
      // Try whitespace-relaxed matching
      final normalizedOriginal = origSnippet.trim();
      if (!originalContent.contains(normalizedOriginal)) {
        return false;
      }
      final updatedContent = originalContent.replaceFirst(
        normalizedOriginal,
        replSnippet.trim(),
      );
      file.writeAsStringSync(updatedContent);
    } else {
      final updatedContent = originalContent.replaceFirst(
        origSnippet,
        replSnippet,
      );
      file.writeAsStringSync(updatedContent);
    }

    // Write regression test if provided
    if (patch.regressionTestCode.isNotEmpty) {
      final testPath = p.isAbsolute(patch.regressionTestPath)
          ? patch.regressionTestPath
          : p.join(workspaceRoot, patch.regressionTestPath);

      final testFile = File(testPath);
      if (!testFile.existsSync()) {
        testFile.parent.createSync(recursive: true);
        _createdFiles.add(testPath);
      } else if (!_backups.containsKey(testPath)) {
        _backups[testPath] = testFile.readAsStringSync();
      }
      testFile.writeAsStringSync(patch.regressionTestCode);
    }

    return true;
  }

  /// Restores all modified files to original state and deletes created test files.
  void rollback() {
    for (final entry in _backups.entries) {
      final file = File(entry.key);
      file.writeAsStringSync(entry.value);
    }
    _backups.clear();

    for (final path in _createdFiles) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    _createdFiles.clear();
  }

  /// Commits changes by clearing backups (cannot be rolled back after this).
  void commit() {
    _backups.clear();
    _createdFiles.clear();
  }
}
