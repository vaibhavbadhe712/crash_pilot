import 'package:crash_pilot/crash_pilot.dart';
import 'package:test/test.dart';

void main() {
  group('DartAstAnalyzer Tests', () {
    const sampleDartSource = '''
import 'dart:math';

class PaymentProcessor {
  final List<double> _history = [];

  double calculateAverage() {
    if (_history.isEmpty) {
      return 0.0;
    }
    double sum = 0;
    for (final val in _history) {
      sum += val;
    }
    return sum / _history.length;
  }

  double getLastTransaction() {
    return _history.last;
  }
}
''';

    test('Identifies enclosing class and method correctly from source', () {
      final context = DartAstAnalyzer.analyzeSource(
        source: sampleDartSource,
        filePath: 'lib/src/payment_processor.dart',
        line: 18,
        column: 20,
      );

      expect(context.enclosingClass, equals('PaymentProcessor'));
      expect(context.enclosingMethod, equals('getLastTransaction'));
      expect(context.targetLineSource, contains('return _history.last;'));
      expect(context.associatedTestFile, equals('test/src/payment_processor_test.dart'));
      expect(context.methodSource, contains('double getLastTransaction()'));
    });

    test('Handles top-level functions cleanly', () {
      const topLevelSource = '''
int parseHeartRate(String input) {
  final val = int.parse(input);
  return val;
}
''';

      final context = DartAstAnalyzer.analyzeSource(
        source: topLevelSource,
        filePath: 'lib/heart_rate.dart',
        line: 2,
        column: 15,
      );

      expect(context.enclosingClass, isNull);
      expect(context.enclosingMethod, equals('parseHeartRate'));
      expect(context.targetLineSource, contains('int.parse(input)'));
    });
  });
}
