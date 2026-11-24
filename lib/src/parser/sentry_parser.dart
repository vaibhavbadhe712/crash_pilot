import 'dart:convert';
import '../models/crash_report.dart';
import 'stack_trace_parser.dart';

/// Ingestion parser for Sentry Flutter Webhook JSON payloads.
class SentryWebhookParser {
  /// Parses a Sentry webhook payload (JSON string or Map) into a [CrashReport].
  static CrashReport parse(dynamic payload) {
    Map<String, dynamic> data;
    if (payload is String) {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } else if (payload is Map<String, dynamic>) {
      data = payload;
    } else {
      throw ArgumentError('Expected JSON string or Map for Sentry payload');
    }

    final event = (data['event'] as Map<String, dynamic>?) ?? data;
    final id = (data['id'] as String?) ??
        (event['event_id'] as String?) ??
        'sentry_${DateTime.now().millisecondsSinceEpoch}';

    String exceptionType = 'UnknownException';
    String exceptionValue = '';
    final rawFrames = <String>[];

    // Check event.exception.values
    final exceptionObj = event['exception'];
    if (exceptionObj is Map && exceptionObj['values'] is List) {
      final values = exceptionObj['values'] as List;
      if (values.isNotEmpty && values.first is Map) {
        final firstVal = values.first as Map<String, dynamic>;
        exceptionType = (firstVal['type'] as String?) ?? exceptionType;
        exceptionValue = (firstVal['value'] as String?) ?? '';

        final stacktrace = firstVal['stacktrace'];
        if (stacktrace is Map && stacktrace['frames'] is List) {
          final frames = stacktrace['frames'] as List;
          // Sentry frames are bottom-to-top or top-to-bottom
          for (var i = 0; i < frames.length; i++) {
            final f = frames[i];
            if (f is Map) {
              final filename = f['filename'] ?? f['abs_path'] ?? '';
              final function = f['function'] ?? 'anonymous';
              final line = f['lineno'] ?? 0;
              final col = f['colno'] ?? 0;
              rawFrames.add('#$i $function ($filename:$line:$col)');
            }
          }
        }
      }
    }

    // Extract breadcrumbs
    final breadcrumbs = <String>[];
    if (event['breadcrumbs'] is Map &&
        (event['breadcrumbs'] as Map)['values'] is List) {
      final bValues = (event['breadcrumbs'] as Map)['values'] as List;
      for (final b in bValues) {
        if (b is Map) {
          final cat = b['category'] ?? 'ui';
          final msg = b['message'] ?? '';
          breadcrumbs.add('[$cat] $msg');
        }
      }
    }

    // Extract tags / commit / release
    final release = event['release'] as String?;
    String? commitHash;
    if (event['tags'] is List) {
      for (final tag in event['tags'] as List) {
        if (tag is List && tag.length >= 2 && tag[0] == 'commit') {
          commitHash = tag[1]?.toString();
        }
      }
    }

    final rawStack = rawFrames.join('\n');
    final parsedReport = StackTraceParser.parse(
      rawException: '$exceptionType: $exceptionValue',
      rawStackTrace: rawStack,
      commitHash: commitHash,
      releaseVersion: release,
      breadcrumbs: breadcrumbs,
      source: 'sentry',
    );

    return CrashReport(
      id: id,
      exceptionType: parsedReport.exceptionType,
      exceptionMessage: parsedReport.exceptionMessage,
      culpritFile: parsedReport.culpritFile,
      lineNumber: parsedReport.lineNumber,
      columnNumber: parsedReport.columnNumber,
      culpritMember: parsedReport.culpritMember,
      stackFrames: parsedReport.stackFrames,
      rawStackTrace: parsedReport.rawStackTrace,
      commitHash: commitHash,
      releaseVersion: release,
      breadcrumbs: breadcrumbs,
      source: 'sentry',
      timestamp: DateTime.now(),
    );
  }
}
