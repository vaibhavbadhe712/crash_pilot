# 🚀 CrashPilot

> **The World's First Autonomous Self-Healing & Shorebird Hot-Patch Bot for Flutter Apps.**  
> *Zero-friction, instant surgical bug fixes and OTA deployment without waiting for App Store / Play Store reviews.*

---

## 📌 What is CrashPilot?

When a Flutter app crashes in production, it normally takes **24 to 72 hours** for a developer to be alerted, reproduce the bug, write a patch, run tests, and wait for Google Play / Apple App Store approval. In the meantime, thousands of users experience crashes and leave 1-star ratings.

**CrashPilot automates this entire lifecycle in under 10 minutes:**
1. **Ingests** Sentry & Firebase Crashlytics webhook alerts in real time.
2. **Parses Dart AST** (`package:analyzer`) to locate the exact enclosing method, class, and null-safety context.
3. **Synthesizes Surgical Patches** (only 5-15 lines, no speculative rewrites) using Gemini 1.5 Pro, Claude 3.5 Sonnet, or OpenAI GPT-4o.
4. **Verifies in a Sandbox**: Enforces `flutter analyze --fatal-infos` (0 errors, 0 warnings) and runs auto-generated regression unit tests.
5. **Self-Heals**: If tests fail, an automated reflection loop refines the fix.
6. **Dual Dispatch**: Opens a complete diagnostic GitHub Pull Request and triggers **Shorebird CodePush** to hot-patch live user devices in minutes!

---

## 🏗️ Architecture

```
[ Production Mobile App Crash ]
              │
              ▼
   [ Sentry / Crashlytics ] ──(Webhook Alert with Stack Trace)
              │
              ▼
    ╔══════════════════════════════════════════════════════════════╗
    ║                   CRASHPILOT ENGINE                          ║
    ║                                                              ║
    ║  1. Ingestion & Triage      (Deduplication & Severity Gate)  ║
    ║  2. Git & AST Locator       (Pulls commit, parses Dart AST)  ║
    ║  3. AI Patch Synthesizer    (Surgical Fix + Regression Test) ║
    ║  4. Sandbox Verifier        (flutter analyze & flutter test) ║
    ║  5. Self-Correction Loop    (Reflection on any test failure) ║
    ╚══════════════════════════════════════════════════════════════╝
              │
       ┌──────┴──────────────────────────┐
       ▼                                 ▼
[ GitHub Pull Request ]      [ Shorebird OTA Hot-Patch ]
(Detailed Diagnostic PR)     (Zero App Store Wait! 5-min fix)
```

---

## ⚡ Quick Start (Developer Setup)

### 1. Installation
Clone or add CrashPilot to your workspace:
```bash
git clone https://github.com/welvors/crash_pilot.git
cd crash_pilot
dart pub get
```

### 2. Initialize Configuration
Generate `crashpilot.yaml` in your project root:
```bash
dart run bin/crash_pilot.dart init
```

### 3. Simulate Offline (Zero-Key Testing)
Test the entire pipeline on your machine without requiring external API keys:
```bash
dart run bin/crash_pilot.dart simulate
```

### 4. Analyze Any Stack Trace
```bash
dart run bin/crash_pilot.dart analyze-trace --raw "Null check operator used on a null value
#0  CartCubit.addItem (package:my_app/cart_cubit.dart:142:15)"
```

### 5. Autonomous Healing Run
```bash
# Ingest from raw stack trace file:
dart run bin/crash_pilot.dart heal --trace crash.txt

# Or ingest from Sentry Webhook JSON:
dart run bin/crash_pilot.dart heal --json sentry_event.json --source sentry
```

---

## ⚙️ Configuration (`crashpilot.yaml`)

```yaml
crashpilot:
  # AI Provider: 'gemini', 'claude', or 'openai'
  ai_provider: gemini
  gemini_model: gemini-1.5-pro

  # Shorebird OTA CodePush:
  # If true, runs `shorebird patch android/ios` upon test verification
  auto_shorebird_patch: false

  # Self-healing reflection retries
  max_retries: 2
  target_branch: main
```

---

## 🤖 GitHub Actions Workflow

Add `.github/workflows/crashpilot.yml` to your Flutter repository:

```yaml
name: CrashPilot Autonomous Self-Heal

on:
  repository_dispatch:
    types: [production-crash-alert]

jobs:
  auto-heal:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Run CrashPilot
        env:
          GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
          SHOREBIRD_TOKEN: ${{ secrets.SHOREBIRD_TOKEN }}
        run: |
          dart pub global activate --source path /path/to/crash_pilot
          crashpilot heal --json '${{ toJson(github.event.client_payload) }}' --source sentry
```

---

## 🧪 Testing

Run static analysis and the automated test suite:
```bash
dart analyze
dart test
```

---

## 📄 License
MIT License. Built by the Welvors AI Team.
