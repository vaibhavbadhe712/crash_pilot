/// CrashPilot — Autonomous Self-Healing & Shorebird Hot-Patch Bot for Flutter Apps.
library;

export 'src/ai/ai_provider.dart';
export 'src/ai/ai_provider_factory.dart';
export 'src/ai/claude_provider.dart';
export 'src/ai/gemini_provider.dart';
export 'src/ai/mock_ai_provider.dart';
export 'src/ai/openai_provider.dart';
export 'src/ai/prompt_templates.dart';
export 'src/ast/ast_context.dart';
export 'src/ast/dart_ast_analyzer.dart';
export 'src/dispatcher/dispatch_result.dart';
export 'src/dispatcher/github_dispatcher.dart';
export 'src/dispatcher/shorebird_dispatcher.dart';
export 'src/engine/crash_pilot_engine.dart';
export 'src/models/config.dart';
export 'src/models/crash_report.dart';
export 'src/models/patch_result.dart';
export 'src/parser/crashlytics_parser.dart';
export 'src/parser/sentry_parser.dart';
export 'src/parser/stack_trace_parser.dart';
export 'src/verifier/patch_applier.dart';
export 'src/verifier/reflection_loop.dart';
export 'src/verifier/sandbox_verifier.dart';
export 'src/verifier/verification_result.dart';
