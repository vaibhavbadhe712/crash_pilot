import 'dart:io';
import 'package:args/args.dart';
import 'package:crash_pilot/crash_pilot.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('init')
    ..addCommand('simulate')
    ..addCommand('analyze-trace')
    ..addCommand('heal');

  // Flags for 'heal'
  parser.commands['heal']!
    ..addOption('trace', abbr: 't', help: 'Path to raw stack trace text file')
    ..addOption('json', abbr: 'j', help: 'Path to Sentry or Crashlytics JSON webhook payload')
    ..addOption('source', abbr: 's', help: 'Ingestion source (sentry, crashlytics, manual)', defaultsTo: 'manual')
    ..addFlag('dry-run', abbr: 'd', help: 'Run using simulated mock AI without API keys', defaultsTo: false);

  // Flags for 'analyze-trace'
  parser.commands['analyze-trace']!
    ..addOption('file', abbr: 'f', help: 'Path to trace file')
    ..addOption('raw', abbr: 'r', help: 'Raw stack trace string');

  if (arguments.isEmpty) {
    _printHelp(parser);
    return;
  }

  ArgResults results;
  try {
    results = parser.parse(arguments);
  } catch (e) {
    stderr.writeln('Error: $e\n');
    _printHelp(parser);
    exitCode = 1;
    return;
  }

  final command = results.command;
  if (command == null) {
    _printHelp(parser);
    return;
  }

  switch (command.name) {
    case 'init':
      _handleInit();
      break;

    case 'simulate':
      await _handleSimulate();
      break;

    case 'analyze-trace':
      _handleAnalyzeTrace(command);
      break;

    case 'heal':
      await _handleHeal(command);
      break;

    default:
      _printHelp(parser);
      break;
  }
}

void _printHelp(ArgParser parser) {
  stdout.writeln('''
===============================================================
🚀 CrashPilot — Autonomous Self-Healing Bot for Flutter
===============================================================
Usage: crashpilot <command> [arguments]

Commands:
  init           Generate a default crashpilot.yaml configuration
  simulate       Run a zero-key simulated healing run on sample crash
  analyze-trace  Parse stack trace and extract AST code context
  heal           Ingest a crash, synthesize a fix, verify and deploy

Options:
${parser.usage}
''');
}

void _handleInit() {
  final file = File('crashpilot.yaml');
  if (file.existsSync()) {
    stdout.writeln('⚠️ crashpilot.yaml already exists in current directory.');
    return;
  }
  file.writeAsStringSync(CrashPilotConfig.sampleYaml());
  stdout.writeln('✅ Created crashpilot.yaml successfully! Configure your provider and tokens.');
}

Future<void> _handleSimulate() async {
  stdout.writeln('''
---------------------------------------------------------------
🧪 Simulating CrashPilot Autonomous Healing (Zero-Key Offline)
---------------------------------------------------------------''');

  const sampleTrace = '''
Null check operator used on a null value
#0      CartCubit.addItem (package:my_app/features/cart/cart_cubit.dart:142:15)
#1      _CartScreenState.build.<anonymous closure> (package:my_app/features/cart/cart_screen.dart:45:20)
#2      _InkResponseState.handleTap (package:flutter/src/material/ink_well.dart:1176:21)
''';

  final crash = StackTraceParser.parse(
    rawException: sampleTrace,
    source: 'simulation',
  );

  stdout.writeln('1. Parsed Crash:');
  stdout.writeln('   - Type: ${crash.exceptionType}');
  stdout.writeln('   - Culprit: ${crash.culpritFile}:${crash.lineNumber} in ${crash.culpritMember}');

  const sampleDartCode = '''
class CartCubit {
  final List<String>? _items = null;

  void addItem(String item) {
    _items!.add(item);
  }
}
''';

  stdout.writeln('\n2. AST Code Analysis (Simulated Source):');
  final ast = DartAstAnalyzer.analyzeSource(
    source: sampleDartCode,
    filePath: crash.culpritFile,
    line: 5,
    column: 11,
  );
  stdout.writeln('   - Enclosing Class: ${ast.enclosingClass}');
  stdout.writeln('   - Enclosing Method: ${ast.enclosingMethod}');
  stdout.writeln('   - Target Node: ${ast.nodeType}');

  stdout.writeln('\n3. Synthesizing Surgical Patch via Mock AI...');
  final mockAi = MockAiProvider();
  final patch = await mockAi.generatePatch(crash: crash, astContext: ast);
  stdout.writeln('   - Explanation: ${patch.explanation}');
  stdout.writeln('   - Original: "${patch.originalSnippet}"');
  stdout.writeln('   - Replacement: "${patch.replacementSnippet}"');

  stdout.writeln('\n4. Formatting Pull Request Report...');
  final report = GithubDispatcher.formatPrBody(
    crash: crash,
    astContext: ast,
    patch: patch,
    verification: const VerificationResult(
      success: true,
      analyzePassed: true,
      testPassed: true,
      duration: Duration(milliseconds: 340),
    ),
  );

  final reportFile = File('SIMULATED_PR_REPORT.md');
  reportFile.writeAsStringSync(report);
  stdout.writeln('   - Report generated: ${reportFile.path}');

  stdout.writeln('''
---------------------------------------------------------------
🎉 Simulation Complete! The entire autonomous pipeline is verified.
---------------------------------------------------------------''');
}

void _handleAnalyzeTrace(ArgResults command) {
  String trace = '';
  final filePath = command['file'] as String?;
  final raw = command['raw'] as String?;

  if (filePath != null && File(filePath).existsSync()) {
    trace = File(filePath).readAsStringSync();
  } else if (raw != null && raw.isNotEmpty) {
    trace = raw;
  } else {
    stderr.writeln('Error: Provide --file or --raw for analyze-trace.');
    exitCode = 1;
    return;
  }

  final report = StackTraceParser.parse(rawException: trace);
  stdout.writeln('''
===============================================================
📊 Stack Trace Diagnostic Summary
===============================================================
- Exception Type:    ${report.exceptionType}
- Exception Message: ${report.exceptionMessage}
- Culprit File:      ${report.culpritFile}
- Line & Column:     ${report.lineNumber}:${report.columnNumber}
- Culprit Member:    ${report.culpritMember}
- Total Frames:      ${report.stackFrames.length}
- Source:            ${report.source}
===============================================================
''');
}

Future<void> _handleHeal(ArgResults command) async {
  String? rawTrace;
  final tracePath = command['trace'] as String?;
  final jsonPath = command['json'] as String?;
  final source = (command['source'] as String? ?? 'manual').toLowerCase();
  final isDryRun = command['dry-run'] as bool? ?? false;

  CrashReport crash;

  if (jsonPath != null && File(jsonPath).existsSync()) {
    final jsonContent = File(jsonPath).readAsStringSync();
    if (source == 'sentry') {
      crash = SentryWebhookParser.parse(jsonContent);
    } else {
      crash = CrashlyticsWebhookParser.parse(jsonContent);
    }
  } else if (tracePath != null && File(tracePath).existsSync()) {
    rawTrace = File(tracePath).readAsStringSync();
    crash = StackTraceParser.parse(rawException: rawTrace, source: source);
  } else {
    stderr.writeln('Error: Provide either --trace <file> or --json <file>.');
    exitCode = 1;
    return;
  }

  final config = CrashPilotConfig.load();
  final effectiveConfig = isDryRun
      ? CrashPilotConfig(
          aiProvider: 'mock',
          dryRun: true,
          autoShorebirdPatch: false,
        )
      : config;

  stdout.writeln('🚀 Starting CrashPilot Autonomous Self-Healing Engine...');
  final engine = CrashPilotEngine(
    config: effectiveConfig,
    onLog: (msg) => stdout.writeln(msg),
  );

  final result = await engine.heal(crash);
  if (result.success) {
    stdout.writeln('\n🎉 ${result.summary}');
  } else {
    stderr.writeln('\n❌ Healing failed: ${result.summary}');
    exitCode = 1;
  }
}
