import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import 'ast_context.dart';

/// Dart AST Analyzer that extracts exact syntactic and semantic context for a crash site.
class DartAstAnalyzer {
  /// Analyzes a file at a specific line and column number, returning [AstContext].
  static AstContext analyzeFile({
    required String filePath,
    required int line,
    int column = 1,
    String? workspaceRoot,
  }) {
    final root = workspaceRoot ?? Directory.current.path;
    final file = File(p.isAbsolute(filePath) ? filePath : p.join(root, filePath));

    if (!file.existsSync()) {
      return AstContext(
        filePath: filePath,
        targetLine: line,
        targetColumn: column,
        targetLineSource: '// File not found on disk: $filePath',
        nodeType: 'Unknown',
        methodSource: '',
        methodStartLine: line,
        methodEndLine: line,
      );
    }

    final content = file.readAsStringSync();
    return analyzeSource(
      source: content,
      filePath: filePath,
      line: line,
      column: column,
      workspaceRoot: root,
    );
  }

  /// Analyzes raw Dart source code at a given line/col.
  static AstContext analyzeSource({
    required String source,
    required String filePath,
    required int line,
    int column = 1,
    String? workspaceRoot,
  }) {
    final parseResult = parseString(
      content: source,
      throwIfDiagnostics: false,
    );

    final lineInfo = parseResult.lineInfo;
    final unit = parseResult.unit;

    // Line numbers in LineInfo are 0-based
    final safeLine = line.clamp(1, lineInfo.lineCount);
    final lineOffset = lineInfo.getOffsetOfLine(safeLine - 1);
    final targetOffset = (lineOffset + (column > 0 ? column - 1 : 0))
        .clamp(0, source.isNotEmpty ? source.length - 1 : 0);

    // Extract target line source
    final lines = source.split('\n');
    final targetLineSource = (safeLine - 1 < lines.length)
        ? lines[safeLine - 1].trim()
        : '';

    // Surrounding context (± 5 lines)
    final startIdx = (safeLine - 6).clamp(0, lines.length);
    final endIdx = (safeLine + 5).clamp(0, lines.length);
    final surrounding = lines.sublist(startIdx, endIdx);

    // Find AST node at offset
    final finder = _NodeLocator(targetOffset);
    unit.accept(finder);
    final targetNode = finder.foundNode ?? unit;

    // Traverse upwards to find enclosing method and class
    AstNode? current = targetNode;
    String? enclosingMethod;
    String? enclosingClass;
    AstNode? enclosingMemberNode;

    while (current != null) {
      if (current is MethodDeclaration) {
        enclosingMethod ??= current.name.lexeme;
        enclosingMemberNode ??= current;
      } else if (current is FunctionDeclaration) {
        enclosingMethod ??= current.name.lexeme;
        enclosingMemberNode ??= current;
      } else if (current is ConstructorDeclaration) {
        enclosingMethod ??= current.name?.lexeme ?? 'new';
        enclosingMemberNode ??= current;
      } else if (current is ClassDeclaration) {
        final dynamic c = current;
        try {
          enclosingClass ??= c.name?.lexeme;
        } catch (_) {}
        try {
          enclosingClass ??= c.namePart?.typeName?.lexeme;
        } catch (_) {}
      } else if (current is MixinDeclaration) {
        final dynamic m = current;
        try {
          enclosingClass ??= m.name?.lexeme;
        } catch (_) {}
        try {
          enclosingClass ??= m.namePart?.typeName?.lexeme;
        } catch (_) {}
      } else if (current is ExtensionDeclaration) {
        final dynamic e = current;
        try {
          enclosingClass ??= e.name?.lexeme;
        } catch (_) {}
        try {
          enclosingClass ??= e.namePart?.typeName?.lexeme;
        } catch (_) {}
        enclosingClass ??= 'UnnamedExtension';
      }
      current = current.parent;
    }

    final methodNode = enclosingMemberNode ?? targetNode;
    final methodSource = methodNode.toSource();
    final methodStartLine = lineInfo.getLocation(methodNode.offset).lineNumber;
    final methodEndLine = lineInfo.getLocation(methodNode.end).lineNumber;

    // Discover related test file
    final testFile = _findAssociatedTestFile(filePath, workspaceRoot);

    return AstContext(
      filePath: filePath,
      targetLine: safeLine,
      targetColumn: column,
      targetLineSource: targetLineSource,
      enclosingClass: enclosingClass,
      enclosingMethod: enclosingMethod,
      nodeType: targetNode.runtimeType.toString(),
      methodSource: methodSource,
      methodStartLine: methodStartLine,
      methodEndLine: methodEndLine,
      associatedTestFile: testFile,
      surroundingLines: surrounding,
    );
  }

  /// Finds whether an associated test file exists under `test/`.
  static String? _findAssociatedTestFile(String filePath, String? root) {
    if (filePath.isEmpty) return null;
    final cleanPath = filePath.replaceAll('\\', '/');

    // e.g. lib/features/cart/cart_cubit.dart -> test/features/cart/cart_cubit_test.dart
    String testCandidate;
    if (cleanPath.startsWith('lib/')) {
      final sub = cleanPath.substring(4);
      final withoutExt = p.withoutExtension(sub);
      testCandidate = 'test/${withoutExt}_test.dart';
    } else {
      final base = p.basenameWithoutExtension(cleanPath);
      testCandidate = 'test/${base}_test.dart';
    }

    if (root != null) {
      final fullPath = p.join(root, testCandidate);
      if (File(fullPath).existsSync()) {
        return testCandidate;
      }
    }
    return testCandidate; // return suggested path even if file doesn't exist yet
  }
}

/// AST visitor to locate the most specific node at a given character offset.
class _NodeLocator extends GeneralizingAstVisitor<void> {
  final int offset;
  AstNode? foundNode;

  _NodeLocator(this.offset);

  @override
  void visitNode(AstNode node) {
    if (node.offset <= offset && offset < node.end) {
      foundNode = node;
      super.visitNode(node); // keep descending to find more specific child
    }
  }
}
