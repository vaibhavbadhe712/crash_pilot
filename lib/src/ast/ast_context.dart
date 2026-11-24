import 'package:meta/meta.dart';

/// Context extracted from the Dart Abstract Syntax Tree (AST) around a crash site.
@immutable
class AstContext {
  final String filePath;
  final int targetLine;
  final int targetColumn;
  final String targetLineSource;
  final String? enclosingClass;
  final String? enclosingMethod;
  final String nodeType;
  final String methodSource;
  final int methodStartLine;
  final int methodEndLine;
  final String? associatedTestFile;
  final List<String> surroundingLines;

  const AstContext({
    required this.filePath,
    required this.targetLine,
    required this.targetColumn,
    required this.targetLineSource,
    this.enclosingClass,
    this.enclosingMethod,
    required this.nodeType,
    required this.methodSource,
    required this.methodStartLine,
    required this.methodEndLine,
    this.associatedTestFile,
    this.surroundingLines = const [],
  });

  Map<String, dynamic> toMap() => {
        'filePath': filePath,
        'targetLine': targetLine,
        'targetColumn': targetColumn,
        'targetLineSource': targetLineSource,
        'enclosingClass': enclosingClass,
        'enclosingMethod': enclosingMethod,
        'nodeType': nodeType,
        'methodSource': methodSource,
        'methodStartLine': methodStartLine,
        'methodEndLine': methodEndLine,
        'associatedTestFile': associatedTestFile,
        'surroundingLines': surroundingLines,
      };

  @override
  String toString() =>
      'AstContext(file: $filePath:$targetLine, class: $enclosingClass, method: $enclosingMethod, node: $nodeType)';
}
