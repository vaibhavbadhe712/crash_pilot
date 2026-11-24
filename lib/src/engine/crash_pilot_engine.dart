import '../ai/ai_provider.dart';
import '../ai/ai_provider_factory.dart';
import '../ast/ast_context.dart';
import '../ast/dart_ast_analyzer.dart';
import '../dispatcher/dispatch_result.dart';
import '../dispatcher/github_dispatcher.dart';
import '../dispatcher/shorebird_dispatcher.dart';
import '../models/config.dart';
import '../models/crash_report.dart';
import '../models/patch_result.dart';
import '../verifier/patch_applier.dart';
import '../verifier/reflection_loop.dart';
import '../verifier/sandbox_verifier.dart';
import '../verifier/verification_result.dart';

/// Comprehensive result of a CrashPilot self-healing run.
class CrashPilotResult {
  final bool success;
  final CrashReport crash;
  final AstContext astContext;
  final PatchResult? patch;
  final VerificationResult? verification;
  final DispatchResult? githubDispatch;
  final DispatchResult? shorebirdDispatch;
  final String summary;
  final List<String> logs;

  const CrashPilotResult({
    required this.success,
    required this.crash,
    required this.astContext,
    this.patch,
    this.verification,
    this.githubDispatch,
    this.shorebirdDispatch,
    required this.summary,
    this.logs = const [],
  });

  Map<String, dynamic> toMap() => {
        'success': success,
        'crash': crash.toMap(),
        'astContext': astContext.toMap(),
        'patch': patch?.toMap(),
        'verification': verification?.toMap(),
        'githubDispatch': githubDispatch?.toMap(),
        'shorebirdDispatch': shorebirdDispatch?.toMap(),
        'summary': summary,
        'logs': logs,
      };
}

/// The Master Autonomous Orchestrator of CrashPilot.
class CrashPilotEngine {
  final CrashPilotConfig config;
  final String workspaceRoot;
  final AiProvider _aiProvider;
  final SandboxVerifier _verifier;
  final PatchApplier _applier;
  final GithubDispatcher _githubDispatcher;
  final ShorebirdDispatcher _shorebirdDispatcher;
  final void Function(String message)? onLog;

  CrashPilotEngine({
    CrashPilotConfig? config,
    String? workspaceRoot,
    AiProvider? customAiProvider,
    SandboxVerifier? customVerifier,
    this.onLog,
  })  : config = config ?? CrashPilotConfig.load(),
        workspaceRoot = workspaceRoot ?? '',
        _aiProvider = customAiProvider ??
            AiProviderFactory.create(config ?? CrashPilotConfig.load()),
        _verifier = customVerifier ?? SandboxVerifier(workspaceRoot: workspaceRoot),
        _applier = PatchApplier(workspaceRoot: workspaceRoot),
        _githubDispatcher = GithubDispatcher(config: config ?? CrashPilotConfig.load()),
        _shorebirdDispatcher =
            ShorebirdDispatcher(config: config ?? CrashPilotConfig.load());

  /// Ingests a [CrashReport], analyzes the code AST, synthesizes and verifies a patch,
  /// and dispatches the result to GitHub and Shorebird.
  Future<CrashPilotResult> heal(CrashReport crash) async {
    final logs = <String>[];
    void log(String msg) {
      logs.add(msg);
      if (onLog != null) onLog!(msg);
    }

    log('🚨 [Crash Ingestion] Processing: ${crash.exceptionType} at ${crash.culpritFile}:${crash.lineNumber}');

    // Step 1: AST Code Intelligence
    log('🔍 [AST Intelligence] Extracting Abstract Syntax Tree context...');
    final astContext = DartAstAnalyzer.analyzeFile(
      filePath: crash.culpritFile,
      line: crash.lineNumber,
      column: crash.columnNumber,
      workspaceRoot: workspaceRoot.isNotEmpty ? workspaceRoot : null,
    );

    log('📌 [AST Match] Enclosing Class: ${astContext.enclosingClass ?? "None"}, Method: ${astContext.enclosingMethod ?? "None"}');

    // Step 2: Verification Reflection Loop
    final loop = ReflectionLoop(
      aiProvider: _aiProvider,
      verifier: _verifier,
      applier: _applier,
      maxRetries: config.maxRetries,
      onLog: log,
    );

    final loopResult = await loop.run(crash: crash, astContext: astContext);

    if (!loopResult.success) {
      log('❌ Self-healing could not produce a verified patch within retry limits.');
      return CrashPilotResult(
        success: false,
        crash: crash,
        astContext: astContext,
        patch: loopResult.finalPatch,
        verification: loopResult.verificationResult,
        summary: 'Verification failed: Patch rolled back safely.',
        logs: logs,
      );
    }

    // Step 3: Dispatch to GitHub
    log('📬 [GitHub Dispatch] Creating diagnostic Pull Request...');
    final ghResult = await _githubDispatcher.dispatch(
      crash: crash,
      astContext: astContext,
      patch: loopResult.finalPatch,
      verification: loopResult.verificationResult,
      workspaceRoot: workspaceRoot.isNotEmpty ? workspaceRoot : null,
    );

    // Step 4: Dispatch to Shorebird (if enabled)
    DispatchResult? shorebirdResult;
    if (config.autoShorebirdPatch) {
      log('⚡ [Shorebird Dispatch] Initiating OTA hot-patch deployment...');
      shorebirdResult = await _shorebirdDispatcher.dispatchPatch(
        patch: loopResult.finalPatch,
        workspaceRoot: workspaceRoot.isNotEmpty ? workspaceRoot : '.',
      );
    }

    log('🎉 [Success] Crash successfully healed, verified, and dispatched!');

    return CrashPilotResult(
      success: true,
      crash: crash,
      astContext: astContext,
      patch: loopResult.finalPatch,
      verification: loopResult.verificationResult,
      githubDispatch: ghResult,
      shorebirdDispatch: shorebirdResult,
      summary: 'Crash ${crash.id} autonomously healed and verified in ${loopResult.totalTurns} turns.',
      logs: logs,
    );
  }
}
