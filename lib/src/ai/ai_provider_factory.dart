import '../models/config.dart';
import 'ai_provider.dart';
import 'claude_provider.dart';
import 'gemini_provider.dart';
import 'mock_ai_provider.dart';
import 'openai_provider.dart';

/// Factory to construct the requested [AiProvider] based on config.
class AiProviderFactory {
  static AiProvider create(CrashPilotConfig config) {
    if (config.dryRun) {
      return MockAiProvider();
    }

    switch (config.aiProvider.toLowerCase()) {
      case 'claude':
      case 'anthropic':
        final key = config.anthropicApiKey;
        if (key == null || key.isEmpty) {
          throw StateError(
            'Missing ANTHROPIC_API_KEY. Please set ANTHROPIC_API_KEY in environment or crashpilot.yaml.',
          );
        }
        return ClaudeProvider(apiKey: key, model: config.claudeModel);

      case 'openai':
      case 'gpt':
        final key = config.openaiApiKey;
        if (key == null || key.isEmpty) {
          throw StateError(
            'Missing OPENAI_API_KEY. Please set OPENAI_API_KEY in environment or crashpilot.yaml.',
          );
        }
        return OpenAiProvider(apiKey: key, model: config.openaiModel);

      case 'mock':
      case 'simulate':
        return MockAiProvider();

      case 'gemini':
      case 'google':
      default:
        final key = config.geminiApiKey;
        if (key == null || key.isEmpty) {
          throw StateError(
            'Missing GEMINI_API_KEY. Please set GEMINI_API_KEY in environment or crashpilot.yaml.',
          );
        }
        return GeminiProvider(apiKey: key, model: config.geminiModel);
    }
  }
}
