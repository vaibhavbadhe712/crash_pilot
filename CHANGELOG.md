# Changelog

All notable changes to `crash_pilot` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.9] - 2026-11-24

### Fixed
- Added baseline test fallback in Sandbox Verifier so synthetic tests for private (`_`) identifiers don't block valid patches.
- Added strict prompt rules preventing AI from removing framework imports (`package:flutter/material.dart`).
- Added private symbol avoidance rule in test generation prompt.

---

## [1.0.8] - 2026-11-24

### Fixed
- Automated git branch creation and push (`git checkout -b` & `git push`) before creating Pull Request via GitHub REST API.
- Fixed dry-run mode retaining GitHub credentials and target branch for PR dispatch testing.
- Added detailed GitHub API response diagnostics for PR creation.

---

## [1.0.7] - 2026-11-24

### Added
- Added `example/main.dart` demonstrating end-to-end crash ingestion, AST analysis, and patch synthesis.

### Fixed
- Shortened package description to adhere to pub.dev's 60-180 character limit (+10 pub points).
- Expanded `analyzer` dependency range to `>=6.2.0 <15.0.0` for full Dart 3.x and analyzer 7.x-14.x compatibility (+10 pub points).
- Made AST class name extraction compatible across both legacy and modern analyzer AST node schemas.

---

## [1.0.6] - 2026-11-24

### Fixed
- Added full support for HTTP 503 (Google high-demand spikes) and 500 across all Gemini candidate models.
- Prioritized `gemini-2.0-flash` and `gemini-1.5-flash` ahead of `gemini-flash-latest`.
- Implemented an automatic AST defensive guard fallback so if Google's external API is rate-limited or unavailable, CrashPilot still generates a valid, compilable patch and opens the PR without crashing.
- Updated sandbox verifier to use `--no-fatal-infos` so pre-existing lints in target files don't fail verification.
- Updated regression test templates to import `package:flutter_test/flutter_test.dart` for Flutter projects.

---

## [1.0.5] - 2026-11-24

### Fixed
- Enforced strict `gemini-` prefix filtering so non-Gemini models (like `lyria` audio models) are completely excluded.
- Added candidate fallback on HTTP 429 quota exhaustion to automatically attempt alternative Gemini models.
- Cleaned model candidate strings to prevent double `models/` prefix in request URIs.

---

## [1.0.4] - 2026-11-24

### Fixed
- Filtered out non-text models (such as audio, TTS, and embedding models like `gemini-2.5-flash-preview-tts`) during dynamic model discovery.
- Prioritized standard text generation models (`gemini-1.5-flash`, `gemini-2.0-flash`, `gemini-1.5-pro`).
- Added graceful fallback on HTTP 400 (modality mismatches) to try subsequent candidate models.

---

## [1.0.3] - 2026-11-24

### Fixed
- Added dynamic model discovery via `GET /models` endpoint for Gemini API.
- Added dual `v1beta` and `v1` endpoint fallback support.
- Merged system instruction into request contents for universal v1/v1beta compatibility.

---

## [1.0.2] - 2026-11-24

### Fixed
- Fixed Gemini API 404 by defaulting to `gemini-1.5-flash` with multi-model automatic fallback.
- Improved stack trace unfolding for inline/single-line crash inputs.
- Enhanced framework frame detection to ensure user-space files are prioritized.

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
