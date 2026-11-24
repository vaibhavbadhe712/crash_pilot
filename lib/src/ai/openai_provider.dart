import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../ast/ast_context.dart';
import '../models/crash_report.dart';
import '../models/patch_result.dart';
import 'ai_provider.dart';
import 'prompt_templates.dart';

/// OpenAI GPT-4o Provider for synthesizing surgical patches.
class OpenAiProvider implements AiProvider {
  final String apiKey;
  final String model;
  final http.Client _client;

  OpenAiProvider({
    required this.apiKey,
    this.model = 'gpt-4o',
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

    final raw = await _callOpenAi(prompt);
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

    final raw = await _callOpenAi(prompt);
    final json = AiProvider.extractJson(raw);
    return AiProvider.parsePatchResult(
      json,
      defaultFile: crash.culpritFile,
      turn: attemptNumber,
      isRefinement: true,
      raw: raw,
    );
  }

  Future<String> _callOpenAi(String prompt) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final requestBody = jsonEncode({
      'model': model,
      'temperature': 0.1,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': PromptTemplates.systemPrompt},
        {'role': 'user', 'content': prompt}
      ]
    });

    final response = await _client.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: requestBody,
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'OpenAI API error (${response.statusCode}): ${response.body}',
        uri: url,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw StateError('OpenAI API returned no choices');
    }

    final message = choices.first['message'] as Map<String, dynamic>?;
    final text = message?['content'] as String?;

    if (text == null || text.trim().isEmpty) {
      throw StateError('OpenAI API returned empty text');
    }

    return text;
  }
}
