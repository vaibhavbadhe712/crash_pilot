import 'package:crash_pilot/crash_pilot.dart';
import 'package:test/test.dart';

void main() {
  group('StackTraceParser Tests', () {
    test('Correctly parses standard Flutter stack trace and identifies culprit', () {
      const trace = '''
Null check operator used on a null value
#0      CartCubit.addItem (package:my_app/features/cart/cart_cubit.dart:142:15)
#1      _CartScreenState.build.<anonymous closure> (package:my_app/features/cart/cart_screen.dart:45:20)
#2      _InkResponseState.handleTap (package:flutter/src/material/ink_well.dart:1176:21)
#3      GestureRecognizer.invokeCallback (package:flutter/src/gestures/recognizer.dart:275:24)
''';

      final report = StackTraceParser.parse(rawException: trace);

      expect(report.exceptionType, equals('Null check operator used on a null value'));
      expect(report.culpritFile, equals('lib/features/cart/cart_cubit.dart'));
      expect(report.lineNumber, equals(142));
      expect(report.columnNumber, equals(15));
      expect(report.culpritMember, equals('CartCubit.addItem'));
      expect(report.stackFrames.length, equals(4));
      expect(report.stackFrames.first.isUserCode, isTrue);
      expect(report.stackFrames[2].isUserCode, isFalse);
    });

    test('Parses Sentry Flutter Webhook JSON payload', () {
      final sentryJson = {
        'id': 'sentry_evt_101',
        'event': {
          'release': '1.0.4+12',
          'exception': {
            'values': [
              {
                'type': 'RangeError (index)',
                'value': 'Invalid value: Not in range 0..1: 2',
                'stacktrace': {
                  'frames': [
                    {
                      'filename': 'package:my_app/data/repo.dart',
                      'function': 'Repository.getPost',
                      'lineno': 55,
                      'colno': 8
                    }
                  ]
                }
              }
            ]
          },
          'breadcrumbs': {
            'values': [
              {'category': 'navigation', 'message': 'Tapped button'}
            ]
          }
        }
      };

      final report = SentryWebhookParser.parse(sentryJson);

      expect(report.id, equals('sentry_evt_101'));
      expect(report.exceptionType, equals('RangeError (index)'));
      expect(report.exceptionMessage, contains('Invalid value'));
      expect(report.culpritFile, equals('lib/data/repo.dart'));
      expect(report.lineNumber, equals(55));
      expect(report.releaseVersion, equals('1.0.4+12'));
      expect(report.breadcrumbs, isNotEmpty);
    });

    test('Parses Firebase Crashlytics Webhook payload', () {
      final crashlyticsJson = {
        'issue': {
          'id': 'crashlytics_issue_999',
          'title': 'StateError: Bad state: No element',
          'subtitle': 'package:my_app/list_provider.dart line 30 col 5 in Provider.first',
          'appVersion': '2.1.0'
        }
      };

      final report = CrashlyticsWebhookParser.parse(crashlyticsJson);

      expect(report.id, equals('crashlytics_issue_999'));
      expect(report.exceptionType, equals('StateError'));
      expect(report.culpritFile, equals('lib/list_provider.dart'));
      expect(report.lineNumber, equals(30));
      expect(report.releaseVersion, equals('2.1.0'));
    });
  });
}
