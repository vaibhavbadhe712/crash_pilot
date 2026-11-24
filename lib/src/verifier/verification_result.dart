import 'package:meta/meta.dart';

/// Represents the outcome of running static analysis and unit tests on a patch.
@immutable
class VerificationResult {
  final bool success;
  final bool analyzePassed;
  final bool testPassed;
  final String analyzeOutput;
  final String testOutput;
  final String combinedLogs;
  final Duration duration;

  const VerificationResult({
    required this.success,
    required this.analyzePassed,
    required this.testPassed,
    this.analyzeOutput = '',
    this.testOutput = '',
    this.combinedLogs = '',
    this.duration = Duration.zero,
  });

  Map<String, dynamic> toMap() => {
        'success': success,
        'analyzePassed': analyzePassed,
        'testPassed': testPassed,
        'analyzeOutput': analyzeOutput,
        'testOutput': testOutput,
        'combinedLogs': combinedLogs,
        'durationMs': duration.inMilliseconds,
      };

  @override
  String toString() =>
      'VerificationResult(success: $success, analyze: $analyzePassed, test: $testPassed)';
}
