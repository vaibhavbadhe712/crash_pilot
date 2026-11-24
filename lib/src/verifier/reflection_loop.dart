import '../ai/ai_provider.dart';
import '../ast/ast_context.dart';
import '../models/crash_report.dart';
import '../models/patch_result.dart';
import 'patch_applier.dart';
import 'sandbox_verifier.dart';
import 'verification_result.dart';

/// Feedback result after running the reflection loop.
class ReflectionLoopResult {
  final bool success;
  final PatchResult finalPatch;
  final VerificationResult verificationResult;
  final int totalTurns;

  const ReflectionLoopResult({
    required this.success,
    required this.finalPatch,
    required this.verificationResult,
    required this.totalTurns,
  });
}

/// Orchestrates the autonomous synthesize-verify-correct reflection loop.
class ReflectionLoop {
  final AiProvider aiProvider;
  final SandboxVerifier verifier;
  final PatchApplier applier;
  final int maxRetries;
  final void Function(String message)? onLog;

  ReflectionLoop({
    required this.aiProvider,
    required this.verifier,
    required this.applier,
    this.maxRetries = 2,
    this.onLog,
  });

  /// Executes the self-healing loop for a given crash and AST context.
  Future<ReflectionLoopResult> run({
    required CrashReport crash,
    required AstContext astContext,
  }) async {
    _log('🧠 Synthesizing surgical patch via AI Provider...');
    PatchResult currentPatch = await aiProvider.generatePatch(
      crash: crash,
      astContext: astContext,
    );

    int turn = 1;
    VerificationResult? lastVerification;

    while (turn <= maxRetries + 1) {
      _log('🛠️ [Turn $turn] Applying candidate patch to disk...');
      final applied = applier.apply(currentPatch);
      if (!applied) {
        _log('⚠️ Warning: Patch snippet did not match cleanly in file.');
      }

      _log('🧪 [Turn $turn] Running sandbox static analysis & regression tests...');
      final vResult = await verifier.verify(patch: currentPatch);
      lastVerification = vResult;

      if (vResult.success) {
        _log('✅ [Turn $turn] VERIFICATION PASSED! 0 errors, all tests green.');
        applier.commit();
        return ReflectionLoopResult(
          success: true,
          finalPatch: currentPatch,
          verificationResult: vResult,
          totalTurns: turn,
        );
      }

      _log('❌ [Turn $turn] Verification failed.');
      _log('Logs:\n${vResult.combinedLogs.split('\n').take(8).join('\n')}');

      if (turn > maxRetries) {
        _log('🛑 Max retries ($maxRetries) reached. Rolling back changes.');
        applier.rollback();
        break;
      }

      turn++;
      _log('🔄 [Reflection Loop] Requesting AI to refine patch based on failure logs...');
      applier.rollback(); // rollback before requesting new patch
      currentPatch = await aiProvider.refinePatch(
        crash: crash,
        astContext: astContext,
        previousPatch: currentPatch,
        failureLogs: vResult.combinedLogs,
        attemptNumber: turn,
      );
    }

    return ReflectionLoopResult(
      success: false,
      finalPatch: currentPatch,
      verificationResult: lastVerification ??
          const VerificationResult(
            success: false,
            analyzePassed: false,
            testPassed: false,
            combinedLogs: 'Failed to complete verification',
          ),
      totalTurns: turn,
    );
  }

  void _log(String msg) {
    if (onLog != null) {
      onLog!(msg);
    }
  }
}
