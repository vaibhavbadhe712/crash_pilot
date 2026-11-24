import 'dart:io';
import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

/// Configuration options for the CrashPilot engine.
@immutable
class CrashPilotConfig {
  final String aiProvider; // 'gemini', 'claude', 'openai', 'ollama'
  final String? geminiApiKey;
  final String? anthropicApiKey;
  final String? openaiApiKey;
  final String geminiModel;
  final String claudeModel;
  final String openaiModel;
  final bool autoShorebirdPatch;
  final bool dryRun;
  final int maxRetries;
  final String targetBranch;
  final String? githubToken;
  final String? githubRepo; // 'owner/repo'
  final String? shorebirdToken;

  const CrashPilotConfig({
    this.aiProvider = 'gemini',
    this.geminiApiKey,
    this.anthropicApiKey,
    this.openaiApiKey,
    this.geminiModel = 'gemini-1.5-flash',
    this.claudeModel = 'claude-3-5-sonnet-20241022',
    this.openaiModel = 'gpt-4o',
    this.autoShorebirdPatch = false,
    this.dryRun = false,
    this.maxRetries = 2,
    this.targetBranch = 'main',
    this.githubToken,
    this.githubRepo,
    this.shorebirdToken,
  });

  /// Loads configuration from `crashpilot.yaml` if it exists, overlaid with environment variables.
  factory CrashPilotConfig.load({String? configPath}) {
    final file = File(configPath ?? 'crashpilot.yaml');
    Map<dynamic, dynamic> yamlMap = const {};
    if (file.existsSync()) {
      try {
        final parsed = loadYaml(file.readAsStringSync());
        if (parsed is Map && parsed['crashpilot'] is Map) {
          yamlMap = parsed['crashpilot'] as Map;
        } else if (parsed is Map) {
          yamlMap = parsed;
        }
      } catch (_) {}
    }

    final env = Platform.environment;

    final provider = (yamlMap['ai_provider'] as String?) ??
        env['CRASHPILOT_AI_PROVIDER'] ??
        'gemini';

    return CrashPilotConfig(
      aiProvider: provider.toLowerCase(),
      geminiApiKey: (yamlMap['gemini_api_key'] as String?) ??
          env['GEMINI_API_KEY'] ??
          env['GOOGLE_API_KEY'],
      anthropicApiKey: (yamlMap['anthropic_api_key'] as String?) ??
          env['ANTHROPIC_API_KEY'],
      openaiApiKey: (yamlMap['openai_api_key'] as String?) ??
          env['OPENAI_API_KEY'],
      geminiModel: (yamlMap['gemini_model'] as String?) ??
          env['GEMINI_MODEL'] ??
          'gemini-1.5-pro',
      claudeModel: (yamlMap['claude_model'] as String?) ??
          env['CLAUDE_MODEL'] ??
          'claude-3-5-sonnet-20241022',
      openaiModel: (yamlMap['openai_model'] as String?) ??
          env['OPENAI_MODEL'] ??
          'gpt-4o',
      autoShorebirdPatch: (yamlMap['auto_shorebird_patch'] as bool?) ??
          (env['AUTO_SHOREBIRD_PATCH'] == 'true'),
      dryRun: (yamlMap['dry_run'] as bool?) ?? (env['DRY_RUN'] == 'true'),
      maxRetries: (yamlMap['max_retries'] as int?) ?? 2,
      targetBranch: (yamlMap['target_branch'] as String?) ??
          env['TARGET_BRANCH'] ??
          'main',
      githubToken: (yamlMap['github_token'] as String?) ??
          env['GITHUB_TOKEN'] ??
          env['GH_TOKEN'],
      githubRepo: (yamlMap['github_repo'] as String?) ??
          env['GITHUB_REPOSITORY'],
      shorebirdToken: (yamlMap['shorebird_token'] as String?) ??
          env['SHOREBIRD_TOKEN'],
    );
  }

  /// Generates sample default YAML configuration content.
  static String sampleYaml() => '''
# CrashPilot Configuration
# Autonomous Self-Healing & Shorebird Hot-Patch Bot for Flutter Apps
crashpilot:
  # AI Provider: 'gemini', 'claude', or 'openai'
  ai_provider: gemini
  
  # Models to use (optional overrides)
  gemini_model: gemini-1.5-pro
  # claude_model: claude-3-5-sonnet-20241022
  # openai_model: gpt-4o

  # Deployment settings
  # Set to true to automatically dispatch OTA patch via Shorebird CLI
  auto_shorebird_patch: false

  # Max reflection/self-correction turns if test fails
  max_retries: 2
  target_branch: main
''';
}
