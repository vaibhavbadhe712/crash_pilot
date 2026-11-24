# Changelog

All notable changes to `crash_pilot` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.1] - 2026-11-24

### Fixed
- Removed incorrect team attribution from README license section.
- Updated repository and homepage URLs to correct personal GitHub account.

---

## [1.0.0] - 2026-11-24

### Added
- **Core Engine** (`CrashPilotEngine`): Master autonomous orchestrator that runs the full self-healing lifecycle.
- **Stack Trace Parser** (`StackTraceParser`): Parses standard Flutter/Dart stack traces and identifies the culprit file, line, column, and enclosing member.
- **Sentry Webhook Ingestion** (`SentryWebhookParser`): Parses Sentry Flutter webhook JSON payloads into structured `CrashReport` objects.
- **Firebase Crashlytics Ingestion** (`CrashlyticsWebhookParser`): Parses Firebase Crashlytics webhook JSON payloads.
- **Dart AST Analyzer** (`DartAstAnalyzer`): Uses `package:analyzer` to extract enclosing class, method, null-safety context, and surrounding code from crash sites.
- **AI Surgical Patch Synthesizer**: Supports 3 providers out of the box:
  - `GeminiProvider` — Google Gemini 1.5 Pro / Flash
  - `ClaudeProvider` — Anthropic Claude 3.5 Sonnet
  - `OpenAiProvider` — OpenAI GPT-4o
  - `MockAiProvider` — Offline simulation (zero API key needed)
- **AI Provider Factory** (`AiProviderFactory`): Auto-selects provider from `crashpilot.yaml` or environment variables.
- **Surgical Prompt Templates** (`PromptTemplates`): Strict Dart 3 prompts enforcing surgical diffs (no full-file rewrites), null-safety, and regression test generation.
- **Atomic Patch Applier** (`PatchApplier`): Applies surgical diffs with guaranteed rollback on failure.
- **Sandbox Verifier** (`SandboxVerifier`): Runs `flutter analyze --fatal-infos` and `flutter test` / `dart test` in isolation.
- **Reflection Loop** (`ReflectionLoop`): 2-turn self-correction agent that refines patches when verification fails.
- **GitHub PR Dispatcher** (`GithubDispatcher`): Creates fully documented GitHub Pull Requests via GitHub REST API, with fallback to a local `CRASHPILOT_PR_REPORT.md` markdown report.
- **Shorebird OTA Dispatcher** (`ShorebirdDispatcher`): Runs `shorebird patch android/ios` to push zero-wait OTA hot-patches to live user devices.
- **CLI Tool** (`crashpilot`): Four commands — `init`, `simulate`, `analyze-trace`, `heal`.
- **Configuration System** (`CrashPilotConfig`): Reads `crashpilot.yaml` and all env variables (`GEMINI_API_KEY`, `GITHUB_TOKEN`, etc.) with zero-code setup.
- **7 Unit Tests**: Full coverage of parsers, AST analyzer, patch applier, and engine orchestration.
