import 'package:meta/meta.dart';

/// Result of dispatching a verified patch to GitHub and/or Shorebird CodePush.
@immutable
class DispatchResult {
  final bool prCreated;
  final String? prUrl;
  final int? prNumber;
  final bool shorebirdPatched;
  final String? shorebirdOutput;
  final List<String> logs;

  const DispatchResult({
    this.prCreated = false,
    this.prUrl,
    this.prNumber,
    this.shorebirdPatched = false,
    this.shorebirdOutput,
    this.logs = const [],
  });

  Map<String, dynamic> toMap() => {
        'prCreated': prCreated,
        'prUrl': prUrl,
        'prNumber': prNumber,
        'shorebirdPatched': shorebirdPatched,
        'shorebirdOutput': shorebirdOutput,
        'logs': logs,
      };

  @override
  String toString() =>
      'DispatchResult(PR: $prCreated, URL: $prUrl, Shorebird: $shorebirdPatched)';
}
