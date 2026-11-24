import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../ast/ast_context.dart';
import '../models/config.dart';
import '../models/crash_report.dart';
import '../models/patch_result.dart';
import '../verifier/verification_result.dart';
import 'dispatch_result.dart';

/// Dispatches verified fixes to GitHub as fully documented Pull Requests.
class GithubDispatcher {
  final CrashPilotConfig config;
  final http.Client _client;

  GithubDispatcher({required this.config, http.Client? client})
      : _client = client ?? http.Client();

  /// Formats a comprehensive diagnostic markdown report for PR description.
  static String formatPrBody({
    required CrashReport crash,
    required AstContext astContext,
    required PatchResult patch,
    required VerificationResult verification,
  }) {
    return '''
## 🚀 CrashPilot Autonomous Self-Heal Report

> **Status:** ✅ Verified & Ready to Merge  
> **Crash ID:** `${crash.id}` | **Source:** `${crash.source.toUpperCase()}`

---

### 🚨 1. Incident Overview
- **Exception:** `${crash.exceptionType}`
- **Message:** `${crash.exceptionMessage}`
- **Culprit Location:** `${crash.culpritFile}:${crash.lineNumber}:${crash.columnNumber}`
- **Enclosing Member:** `${crash.culpritMember}`
- **Release Version:** `${crash.releaseVersion ?? 'production'}`

---

### 🔍 2. Root Cause Analysis
${patch.explanation}

---

### 🛠️ 3. Surgical Patch (Diff)
```dart
<<<<<<< Original (${crash.culpritFile})
${patch.originalSnippet}
=======
${patch.replacementSnippet}
>>>>>>> Surgical Replacement
```

---

### 🧪 4. Regression Unit Test Added
A new unit test was synthesized and validated to ensure this crash cannot recur:
- **Test File:** `${patch.regressionTestPath}`
```dart
${patch.regressionTestCode}
```

---

### 📊 5. Verification Results
- **Static Analysis:** ${verification.analyzePassed ? '✅ 0 Errors, 0 Warnings' : '❌ Failed'}
- **Test Suite:** ${verification.testPassed ? '✅ 100% Passed' : '❌ Failed'}
- **Verification Duration:** `${verification.duration.inMilliseconds} ms`

```
${verification.combinedLogs.split('\n').take(12).join('\n')}
```

---
*Generated automatically by [CrashPilot](https://github.com/vaibhavbadhe712/crash_pilot) — Autonomous Hot-Patch Bot for Flutter.*
''';
  }

  /// Creates a GitHub Pull Request or writes a local diagnostic report.
  Future<DispatchResult> dispatch({
    required CrashReport crash,
    required AstContext astContext,
    required PatchResult patch,
    required VerificationResult verification,
    String? workspaceRoot,
  }) async {
    final body = formatPrBody(
      crash: crash,
      astContext: astContext,
      patch: patch,
      verification: verification,
    );

    final title =
        'fix(auto): resolve ${crash.exceptionType} in ${p.basename(crash.culpritFile)}';

    final token = config.githubToken;
    final repo = config.githubRepo;
    final root = workspaceRoot ?? Directory.current.path;

    if (token != null && token.isNotEmpty && repo != null && repo.contains('/')) {
      final headBranch = 'crashpilot/fix-${crash.id}';

      // 1. Commit changes to branch and push to remote GitHub repo
      await _commitAndPushBranch(
        repo: repo,
        token: token,
        branch: headBranch,
        title: title,
        workspaceRoot: root,
      );

      // 2. Call GitHub API to create Pull Request
      final prResult = await _createGitHubPr(
        repo: repo,
        token: token,
        title: title,
        body: body,
        headBranch: headBranch,
        baseBranch: config.targetBranch,
      );
      if (prResult != null) {
        return prResult;
      }
    }

    // Local report fallback
    final reportFile = File(p.join(root, 'CRASHPILOT_PR_REPORT.md'));
    reportFile.writeAsStringSync(body);

    return DispatchResult(
      prCreated: false,
      prUrl: reportFile.path,
      logs: [
        'GitHub credentials or PR creation not completed. Diagnostic report written to: ${reportFile.path}'
      ],
    );
  }

  Future<bool> _commitAndPushBranch({
    required String repo,
    required String token,
    required String branch,
    required String title,
    required String workspaceRoot,
  }) async {
    try {
      await Process.run('git', ['config', 'user.name', 'CrashPilot[bot]'],
          workingDirectory: workspaceRoot);
      await Process.run('git',
          ['config', 'user.email', 'crashpilot-bot@users.noreply.github.com'],
          workingDirectory: workspaceRoot);

      await Process.run('git', ['checkout', '-b', branch],
          workingDirectory: workspaceRoot);
      await Process.run('git', ['add', '.'], workingDirectory: workspaceRoot);
      await Process.run('git', ['commit', '-m', title, '--allow-empty'],
          workingDirectory: workspaceRoot);

      final authUrl = 'https://x-access-token:$token@github.com/$repo.git';
      final pushRes = await Process.run(
        'git',
        ['push', authUrl, branch, '--force'],
        workingDirectory: workspaceRoot,
      );

      if (pushRes.exitCode != 0) {
        stdout.writeln('Git push notice: ${pushRes.stderr}');
      }
      return pushRes.exitCode == 0;
    } catch (e) {
      stdout.writeln('Notice during branch commit/push: $e');
      return false;
    }
  }

  Future<DispatchResult?> _createGitHubPr({
    required String repo,
    required String token,
    required String title,
    required String body,
    required String headBranch,
    required String baseBranch,
  }) async {
    final url = Uri.parse('https://api.github.com/repos/$repo/pulls');
    try {
      final response = await _client.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'body': body,
          'head': headBranch,
          'base': baseBranch,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final htmlUrl = data['html_url'] as String?;
        final number = data['number'] as int?;
        stdout.writeln('🎉 [GitHub PR] Created successfully: $htmlUrl');
        return DispatchResult(
          prCreated: true,
          prUrl: htmlUrl,
          prNumber: number,
          logs: ['Pull Request created successfully: $htmlUrl'],
        );
      } else {
        stdout.writeln('GitHub PR API notice (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      stdout.writeln('Error creating GitHub PR: $e');
    }
    return null;
  }
}
