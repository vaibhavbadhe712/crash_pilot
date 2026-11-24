import 'package:meta/meta.dart';

/// Represents a stack frame in a Flutter/Dart stack trace.
@immutable
class StackFrame {
  final int frameNumber;
  final String member;
  final String uri;
  final String filePath;
  final int lineNumber;
  final int columnNumber;
  final bool isUserCode;

  const StackFrame({
    required this.frameNumber,
    required this.member,
    required this.uri,
    required this.filePath,
    required this.lineNumber,
    required this.columnNumber,
    required this.isUserCode,
  });

  Map<String, dynamic> toMap() => {
        'frameNumber': frameNumber,
        'member': member,
        'uri': uri,
        'filePath': filePath,
        'lineNumber': lineNumber,
        'columnNumber': columnNumber,
        'isUserCode': isUserCode,
      };

  factory StackFrame.fromMap(Map<String, dynamic> map) => StackFrame(
        frameNumber: map['frameNumber'] as int? ?? 0,
        member: map['member'] as String? ?? '',
        uri: map['uri'] as String? ?? '',
        filePath: map['filePath'] as String? ?? '',
        lineNumber: map['lineNumber'] as int? ?? 0,
        columnNumber: map['columnNumber'] as int? ?? 0,
        isUserCode: map['isUserCode'] as bool? ?? false,
      );

  @override
  String toString() => '#$frameNumber $member ($filePath:$lineNumber:$columnNumber)';
}

/// Represents an ingested production or test crash report.
@immutable
class CrashReport {
  final String id;
  final String exceptionType;
  final String exceptionMessage;
  final String culpritFile;
  final int lineNumber;
  final int columnNumber;
  final String culpritMember;
  final List<StackFrame> stackFrames;
  final String rawStackTrace;
  final String? commitHash;
  final String? releaseVersion;
  final List<String> breadcrumbs;
  final String source;
  final DateTime timestamp;

  const CrashReport({
    required this.id,
    required this.exceptionType,
    required this.exceptionMessage,
    required this.culpritFile,
    required this.lineNumber,
    required this.columnNumber,
    required this.culpritMember,
    required this.stackFrames,
    required this.rawStackTrace,
    this.commitHash,
    this.releaseVersion,
    this.breadcrumbs = const [],
    this.source = 'generic',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'exceptionType': exceptionType,
        'exceptionMessage': exceptionMessage,
        'culpritFile': culpritFile,
        'lineNumber': lineNumber,
        'columnNumber': columnNumber,
        'culpritMember': culpritMember,
        'stackFrames': stackFrames.map((f) => f.toMap()).toList(),
        'rawStackTrace': rawStackTrace,
        'commitHash': commitHash,
        'releaseVersion': releaseVersion,
        'breadcrumbs': breadcrumbs,
        'source': source,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CrashReport.fromMap(Map<String, dynamic> map) => CrashReport(
        id: map['id'] as String? ?? 'crash_${DateTime.now().millisecondsSinceEpoch}',
        exceptionType: map['exceptionType'] as String? ?? 'UnknownException',
        exceptionMessage: map['exceptionMessage'] as String? ?? '',
        culpritFile: map['culpritFile'] as String? ?? '',
        lineNumber: map['lineNumber'] as int? ?? 0,
        columnNumber: map['columnNumber'] as int? ?? 0,
        culpritMember: map['culpritMember'] as String? ?? '',
        stackFrames: (map['stackFrames'] as List<dynamic>?)
                ?.map((e) => StackFrame.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
        rawStackTrace: map['rawStackTrace'] as String? ?? '',
        commitHash: map['commitHash'] as String?,
        releaseVersion: map['releaseVersion'] as String?,
        breadcrumbs: (map['breadcrumbs'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        source: map['source'] as String? ?? 'generic',
        timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );

  @override
  String toString() =>
      'CrashReport(id: $id, type: $exceptionType, file: $culpritFile:$lineNumber, member: $culpritMember)';
}
