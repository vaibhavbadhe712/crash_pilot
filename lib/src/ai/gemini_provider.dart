import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../ast/ast_context.dart';
import '../models/crash_report.dart';
import '../models/patch_result.dart';
import 'ai_provider.dart';
import 'prompt_templates.dart';

/// Gemini AI Provider for synthesizing surgical patches.
class GeminiProvider implements AiProvider {
  final String apiKey;
  final String model;
  final http.Client _client;

  GeminiProvider({
    required this.apiKey,
    this.model = 'gemini-1.5-flash',
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

    final raw = await _callGemini(prompt);
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

    final raw = await _callGemini(prompt);
    final json = AiProvider.extractJson(raw);
    return AiProvider.parsePatchResult(
      json,
      defaultFile: crash.culpritFile,
      turn: attemptNumber,
      isRefinement: true,
      raw: raw,
    );
  }

  Future<String> _callGemini(String prompt) async {
    // List of candidate models to try in order
    final candidateModels = <String>{
      model,
      'gemini-1.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-pro-latest',
      'gemini-pro',
    }.toList();

    HttpException? lastException;

    for (final candidate in candidateModels) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$candidate:generateContent?key=$apiKey',
      );

      final requestBody = jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': PromptTemplates.systemPrompt}
          ]
        },
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        }
      });

      try {
        final response = await _client.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) {
            throw StateError('Gemini API returned no candidates');
          }

          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List?;
          final text = parts?.first?['text'] as String?;

          if (text == null || text.trim().isEmpty) {
            throw StateError('Gemini API returned empty text');
          }

          return text;
        }

        // If 404, try next candidate model
        if (response.statusCode == 404) {
          lastException = HttpException(
            'Gemini model $candidate not found (404)',
            uri: url,
          );
          continue;
        }

        throw HttpException(
          'Gemini API error (${response.statusCode}): ${response.body}',
          uri: url,
        );
      } catch (e) {
        if (e is HttpException && e.message.contains('404')) {
          lastException = e;
          continue;
        }
        rethrow;
      }
    }

    throw lastException ??
        HttpException('Failed to call Gemini API across all models');
  }
}
