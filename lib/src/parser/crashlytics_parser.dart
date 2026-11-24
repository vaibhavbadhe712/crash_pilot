import 'dart:convert';
import '../models/crash_report.dart';
import 'stack_trace_parser.dart';

/// Ingestion parser for Firebase Crashlytics Webhook JSON payloads.
class CrashlyticsWebhookParser {
  /// Parses a Firebase Crashlytics webhook payload into a [CrashReport].
  static CrashReport parse(dynamic payload) {
    Map<String, dynamic> data;
    if (payload is String) {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } else if (payload is Map<String, dynamic>) {
      data = payload;
    } else {
      throw ArgumentError('Expected JSON string or Map for Crashlytics payload');
    }

    final issue = (data['issue'] as Map<String, dynamic>?) ?? data;
    final id = (issue['id'] as String?) ??
        'crashlytics_${DateTime.now().millisecondsSinceEpoch}';

    final title = (issue['title'] as String?) ?? 'Fatal Crash in Flutter';
    final subtitle = (issue['subtitle'] as String?) ?? '';
    final appVersion = (issue['appVersion'] as String?);

    // Some payloads send raw stackTrace in 'sample' or 'error'
    final rawTrace = (data['stackTrace'] as String?) ??
        (data['error'] as String?) ??
        subtitle;

    final parsedReport = StackTraceParser.parse(
      rawException: title,
      rawStackTrace: rawTrace,
      releaseVersion: appVersion,
      source: 'crashlytics',
    );

    return CrashReport(
      id: id,
      exceptionType: parsedReport.exceptionType,
      exceptionMessage: parsedReport.exceptionMessage.isNotEmpty
          ? parsedReport.exceptionMessage
          : subtitle,
      culpritFile: parsedReport.culpritFile,
      lineNumber: parsedReport.lineNumber,
      columnNumber: parsedReport.columnNumber,
      culpritMember: parsedReport.culpritMember,
      stackFrames: parsedReport.stackFrames,
      rawStackTrace: parsedReport.rawStackTrace,
      commitHash: null,
      releaseVersion: appVersion,
      breadcrumbs: const [],
      source: 'crashlytics',
      timestamp: DateTime.now(),
    );
  }
}
