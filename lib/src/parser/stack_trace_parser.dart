import '../models/crash_report.dart';

/// Robust parser for Flutter and Dart stack traces.
class StackTraceParser {
  // Regex matching standard Dart stack frames:
  // #0      ClassName.methodName (package:app/path/to/file.dart:142:15)
  // #0      methodName (file:///path/to/file.dart:142:15)
  static final RegExp _frameRegex = RegExp(
    r'#(\d+)\s+([^\(]+?)\s+\((.+?):(\d+)(?::(\d+))?\)',
  );

  // Alternate regex for some Crashlytics demangled lines:
  // package:app/file.dart line 142 col 15 in Class.method
  static final RegExp _altFrameRegex = RegExp(
    r'(package:[^\s]+|file:[^\s]+)\s+line\s+(\d+)(?:\s+col\s+(\d+))?\s+in\s+([^\s]+)',
  );

  /// Parses a raw exception string and stack trace into a structured [CrashReport].
  static CrashReport parse({
    required String rawException,
    String? rawStackTrace,
    String? commitHash,
    String? releaseVersion,
    List<String> breadcrumbs = const [],
    String source = 'manual',
  }) {
    var combined = rawStackTrace != null && rawStackTrace.isNotEmpty
        ? '$rawException\n$rawStackTrace'
        : rawException;

    // Unfold any inline/collapsed frames so each '#<num>' is guaranteed its own line
    combined = combined.replaceAllMapped(
      RegExp(r'(?<!\n)(#\d+\s+)'),
      (m) => '\n${m[1]}',
    );

    final lines = combined.split('\n');
    String exceptionType = 'UnknownException';
    String exceptionMessage = '';

    // Extract exception line (usually first line or before #0)
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) break;

      if (trimmed.contains(':')) {
        final parts = trimmed.split(':');
        exceptionType = parts.first.trim();
        exceptionMessage = parts.sublist(1).join(':').trim();
      } else {
        exceptionType = trimmed;
      }
      break;
    }

    final frames = <StackFrame>[];
    for (final line in lines) {
      final trimmed = line.trim();
      final match = _frameRegex.firstMatch(trimmed);
      if (match != null) {
        final frameNum = int.tryParse(match.group(1) ?? '0') ?? 0;
        final member = match.group(2)?.trim() ?? '';
        final uri = match.group(3)?.trim() ?? '';
        final lineNum = int.tryParse(match.group(4) ?? '0') ?? 0;
        final colNum = int.tryParse(match.group(5) ?? '0') ?? 0;

        final isUserCode = _isUserCode(uri);
        final filePath = _normalizeFilePath(uri);

        frames.add(StackFrame(
          frameNumber: frameNum,
          member: member,
          uri: uri,
          filePath: filePath,
          lineNumber: lineNum,
          columnNumber: colNum,
          isUserCode: isUserCode,
        ));
        continue;
      }

      final altMatch = _altFrameRegex.firstMatch(trimmed);
      if (altMatch != null) {
        final uri = altMatch.group(1)?.trim() ?? '';
        final lineNum = int.tryParse(altMatch.group(2) ?? '0') ?? 0;
        final colNum = int.tryParse(altMatch.group(3) ?? '0') ?? 0;
        final member = altMatch.group(4)?.trim() ?? '';

        final isUserCode = _isUserCode(uri);
        final filePath = _normalizeFilePath(uri);

        frames.add(StackFrame(
          frameNumber: frames.length,
          member: member,
          uri: uri,
          filePath: filePath,
          lineNumber: lineNum,
          columnNumber: colNum,
          isUserCode: isUserCode,
        ));
      }
    }

    // Determine culprit frame (first frame belonging to user code)
    StackFrame? culprit;
    for (final f in frames) {
      if (f.isUserCode) {
        culprit = f;
        break;
      }
    }
    // Fallback to frame 0 if no user code frame identified
    culprit ??= frames.isNotEmpty
        ? frames.first
        : const StackFrame(
            frameNumber: 0,
            member: 'unknown',
            uri: '',
            filePath: '',
            lineNumber: 0,
            columnNumber: 0,
            isUserCode: false,
          );

    final id = 'cp_${DateTime.now().millisecondsSinceEpoch}';

    return CrashReport(
      id: id,
      exceptionType: exceptionType,
      exceptionMessage: exceptionMessage,
      culpritFile: culprit.filePath,
      lineNumber: culprit.lineNumber,
      columnNumber: culprit.columnNumber,
      culpritMember: culprit.member,
      stackFrames: frames,
      rawStackTrace: combined,
      commitHash: commitHash,
      releaseVersion: releaseVersion,
      breadcrumbs: breadcrumbs,
      source: source,
      timestamp: DateTime.now(),
    );
  }

  /// Determines whether a frame URI belongs to application user code rather than SDK/framework.
  static bool _isUserCode(String uri) {
    if (uri.startsWith('dart:') || uri.contains('dart:')) return false;
    if (uri.startsWith('package:flutter/') || uri.contains('package:flutter/')) return false;
    if (uri.startsWith('package:flutter_test/') || uri.contains('package:flutter_test/')) return false;
    if (uri.contains('/.pub-cache/')) return false;
    return true;
  }

  /// Normalizes package: or file: URIs into relative workspace file paths (e.g. `lib/...`).
  static String _normalizeFilePath(String uri) {
    if (uri.startsWith('package:flutter/') ||
        uri.startsWith('package:flutter_test/') ||
        uri.startsWith('dart:')) {
      return uri;
    }
    if (uri.startsWith('package:')) {
      // package:app_name/sub/file.dart -> lib/sub/file.dart
      final slashIndex = uri.indexOf('/');
      if (slashIndex != -1 && slashIndex + 1 < uri.length) {
        return 'lib/${uri.substring(slashIndex + 1)}';
      }
    } else if (uri.startsWith('file:///')) {
      final libIndex = uri.indexOf('/lib/');
      if (libIndex != -1) {
        return uri.substring(libIndex + 1);
      }
    }
    return uri;
  }
}
