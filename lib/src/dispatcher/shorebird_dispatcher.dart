import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/config.dart';
import '../models/patch_result.dart';
import 'dispatch_result.dart';

/// Dispatches verified fixes directly to end-user devices via Shorebird OTA Hot-Patching.
class ShorebirdDispatcher {
  final CrashPilotConfig config;
  final String? customShorebirdExecutable;

  ShorebirdDispatcher({
    required this.config,
    this.customShorebirdExecutable,
  });

  /// Checks if the target workspace has Shorebird initialized (`shorebird.yaml`).
  bool hasShorebirdConfig(String workspaceRoot) {
    final shorebirdYaml = File(p.join(workspaceRoot, 'shorebird.yaml'));
    return shorebirdYaml.existsSync();
  }

  /// Triggers Shorebird OTA patch release for Android and/or iOS.
  Future<DispatchResult> dispatchPatch({
    required PatchResult patch,
    required String workspaceRoot,
  }) async {
    final logs = <String>[];

    if (!config.autoShorebirdPatch) {
      logs.add('Shorebird auto-patch is disabled in crashpilot.yaml.');
      return DispatchResult(
        shorebirdPatched: false,
        logs: logs,
      );
    }

    if (!hasShorebirdConfig(workspaceRoot)) {
      logs.add('shorebird.yaml not found in workspace root. Skipping OTA hot-patch.');
      return DispatchResult(
        shorebirdPatched: false,
        logs: logs,
      );
    }

    final executable = customShorebirdExecutable ??
        Platform.environment['SHOREBIRD_EXECUTABLE'] ??
        (Platform.isWindows ? 'shorebird.ps1' : 'shorebird');

    logs.add('🚀 Initiating Shorebird OTA hot-patch deployment...');

    try {
      // 1. Android release patch
      final androidResult = await Process.run(
        executable,
        ['patch', 'android', '--release', '--no-confirm'],
        workingDirectory: workspaceRoot,
        runInShell: true,
      );

      final out = '${androidResult.stdout}\n${androidResult.stderr}';
      final success = androidResult.exitCode == 0;

      logs.add(success
          ? '✅ Shorebird Android hot-patch released successfully!'
          : '⚠️ Shorebird Android patch command finished with code ${androidResult.exitCode}');

      return DispatchResult(
        shorebirdPatched: success,
        shorebirdOutput: out,
        logs: logs,
      );
    } catch (e) {
      logs.add('Failed to execute Shorebird CLI: $e');
      return DispatchResult(
        shorebirdPatched: false,
        shorebirdOutput: e.toString(),
        logs: logs,
      );
    }
  }
}
