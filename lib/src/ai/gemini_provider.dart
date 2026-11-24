import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../ast/ast_context.dart';
import '../models/crash_report.dart';
import '../models/patch_result.dart';
import 'ai_provider.dart';
import 'prompt_templates.dart';

/// Gemini AI Provider for synthesizing surgical patches with automatic model discovery and fallback.
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

  /// Discovers available models for this specific API key dynamically.
  Future<List<String>> _discoverAvailableModels() async {
    for (final version in ['v1beta', 'v1']) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/$version/models?key=$apiKey',
        );
        final response = await _client.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final list = data['models'] as List?;
          if (list != null) {
            final valid = <String>[];
            for (final m in list) {
              if (m is Map) {
                final name = (m['name'] as String? ?? '').replaceFirst('models/', '');
                final methods = m['supportedGenerationMethods'] as List?;

                // Ignore non-text, TTS, audio, or embedding models
                if (name.contains('-tts') ||
                    name.contains('audio') ||
                    name.contains('embedding') ||
                    name.contains('imagen')) {
                  continue;
                }

                if (methods != null && methods.contains('generateContent')) {
                  valid.add(name);
                }
              }
            }
            if (valid.isNotEmpty) {
              // Prioritize standard text flash and pro models
              valid.sort((a, b) {
                final aScore = _modelPriority(a);
                final bScore = _modelPriority(b);
                return bScore.compareTo(aScore);
              });
              return valid;
            }
          }
        }
      } catch (_) {}
    }
    return const [];
  }

  static int _modelPriority(String name) {
    if (name == 'gemini-1.5-flash') return 100;
    if (name == 'gemini-2.0-flash') return 95;
    if (name.contains('1.5-flash')) return 90;
    if (name.contains('2.0-flash')) return 85;
    if (name == 'gemini-1.5-pro') return 80;
    if (name.contains('pro')) return 70;
    return 10;
  }

  Future<String> _callGemini(String prompt) async {
    // 1. First probe available models dynamically for this key
    final discovered = await _discoverAvailableModels();

    // 2. Build candidate list prioritizing user choice, then discovered, then standards
    final candidateModels = <String>{
      model,
      ...discovered,
      'gemini-1.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-pro',
      'gemini-pro',
    }.toList();

    HttpException? lastException;

    // Try both v1beta and v1 endpoints
    final apiVersions = ['v1beta', 'v1'];

    for (final candidate in candidateModels) {
      for (final version in apiVersions) {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/$version/models/$candidate:generateContent?key=$apiKey',
        );

        final requestBody = jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': '${PromptTemplates.systemPrompt}\n\n$prompt'}
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

          if (response.statusCode == 404 || response.statusCode == 400) {
            lastException = HttpException(
              'Gemini model $candidate returned ${response.statusCode}: ${response.body}',
              uri: url,
            );
            continue; // try next candidate model
          }

          throw HttpException(
            'Gemini API error (${response.statusCode}): ${response.body}',
            uri: url,
          );
        } catch (e) {
          if (e is HttpException &&
              (e.message.contains('404') || e.message.contains('400'))) {
            lastException = e;
            continue;
          }
          rethrow;
        }
      }
    }

    throw lastException ??
        HttpException(
          'Failed to call Gemini API across all endpoints. Please verify your GEMINI_API_KEY at https://aistudio.google.com/app/apikey',
        );
  }
}
