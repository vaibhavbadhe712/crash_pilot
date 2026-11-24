import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../ast/ast_context.dart';
import '../models/crash_report.dart';
import '../models/patch_result.dart';
import 'ai_provider.dart';
import 'prompt_templates.dart';

/// Anthropic Claude AI Provider for synthesizing surgical patches.
class ClaudeProvider implements AiProvider {
  final String apiKey;
  final String model;
  final http.Client _client;

  ClaudeProvider({
    required this.apiKey,
    this.model = 'claude-3-5-sonnet-20241022',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<PatchResult> generatePatch({
    required CrashReport crash,
    required AstContext astContext,
  }) async {
    final prompt = PromptTemplates.buildInitialPrompt(
      crash: crash,
      astContext: astContext,
    );

    final raw = await _callClaude(prompt);
    final json = AiProvider.extractJson(raw);
    return AiProvider.parsePatchResult(
      json,
      defaultFile: crash.culpritFile,
      turn: 1,
      raw: raw,
    );
  }

  @override
  Future<PatchResult> refinePatch({
    required CrashReport crash,
    required AstContext astContext,
    required PatchResult previousPatch,
    required String failureLogs,
    required int attemptNumber,
  }) async {
    final prompt = PromptTemplates.buildReflectionPrompt(
      crash: crash,
      astContext: astContext,
      previousPatchSnippet: previousPatch.replacementSnippet,
      testFailureOutput: failureLogs,
      attemptNumber: attemptNumber,
    );

    final raw = await _callClaude(prompt);
    final json = AiProvider.extractJson(raw);
    return AiProvider.parsePatchResult(
      json,
      defaultFile: crash.culpritFile,
      turn: attemptNumber,
      isRefinement: true,
      raw: raw,
    );
  }

  Future<String> _callClaude(String prompt) async {
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final requestBody = jsonEncode({
      'model': model,
      'max_tokens': 2500,
      'temperature': 0.1,
      'system': PromptTemplates.systemPrompt,
      'messages': [
        {'role': 'user', 'content': prompt}
      ]
    });

    final response = await _client.post(
      url,
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: requestBody,
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Claude API error (${response.statusCode}): ${response.body}',
        uri: url,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List?;
    if (content == null || content.isEmpty) {
      throw StateError('Claude API returned no content');
    }

    final text = content.first['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw StateError('Claude API returned empty text');
    }

    return text;
  }
}
