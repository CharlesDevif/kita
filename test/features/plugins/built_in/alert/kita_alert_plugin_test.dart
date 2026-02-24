import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/orchestration/domain/agent_bus.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/kita_agent.dart';
import 'package:kita/features/orchestration/domain/models/agent_input.dart';
import 'package:kita/features/orchestration/domain/models/agent_manifest.dart';
import 'package:kita/features/orchestration/domain/models/agent_message.dart';
import 'package:kita/features/orchestration/domain/models/agent_output.dart';
import 'package:kita/features/orchestration/domain/models/output_priority.dart';
import 'package:kita/features/orchestration/domain/output_handle.dart';
import 'package:kita/features/plugins/built_in/alert/kita_alert_plugin.dart';
import 'package:kita/features/plugins/domain/ai_access.dart';
import 'package:kita/features/plugins/domain/sensor_access.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';

// === Mock OutputHandle ===

class MockOutputHandle implements OutputHandle {
  MockOutputHandle({required this.agentId});

  @override
  final String agentId;

  final List<({String text, OutputPriority priority})> speakCalls = [];
  final List<({HapticPattern pattern, OutputPriority priority})> hapticCalls =
      [];
  int completeCalled = 0;

  final StreamController<SpeechEvent> _speechEventsController =
      StreamController<SpeechEvent>.broadcast();

  @override
  Stream<SpeechEvent> get speechEvents => _speechEventsController.stream;

  @override
  Future<void> speak(String text,
      {OutputPriority priority = OutputPriority.standard}) async {
    speakCalls.add((text: text, priority: priority));
  }

  @override
  Future<void> haptic(HapticPattern pattern,
      {OutputPriority priority = OutputPriority.standard}) async {
    hapticCalls.add((pattern: pattern, priority: priority));
  }

  @override
  void updateViewport(Widget widget) {}

  @override
  void complete() {
    completeCalled++;
  }

  void dispose() {
    _speechEventsController.close();
  }
}

class MockAgentBus implements AgentBus {
  @override
  void publish(AgentMessage message) {}
  @override
  void subscribe(String agentId, Set<AgentMessageType> types) {}
  @override
  void unsubscribe(String agentId) {}
  @override
  Stream<AgentMessage> streamFor(String agentId) => const Stream.empty();
}

class StubSensorAccess implements SensorAccess {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class StubAIAccess implements AIAccess {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// === Helpers ===

AgentInput _makeInput({
  String command = 'obstacle_detected',
  Map<String, dynamic> params = const {},
}) {
  return AgentInput(
    command: command,
    params: params,
    source: InputSource.sensor,
    timestamp: DateTime(2026, 1, 1),
  );
}

AgentInput _obstacleInput({
  String type = 'voiture',
  double distance = 2.0,
  double confidence = 0.95,
}) {
  return _makeInput(
    command: 'obstacle_detected',
    params: {
      'type': type,
      'distance': distance,
      'confidence': confidence,
    },
  );
}

void main() {
  late MockOutputHandle mockOutput;
  late MockAgentBus mockBus;
  late FakeClock fakeClock;
  late KitaAlertPlugin plugin;
  late List<LogEntry> logEntries;

  setUp(() {
    mockOutput = MockOutputHandle(agentId: 'com.kita.alert');
    mockBus = MockAgentBus();
    fakeClock = FakeClock();
    plugin = KitaAlertPlugin();
    logEntries = [];
    KitaLogger.testLogHandler = (entry) => logEntries.add(entry);
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
    mockOutput.dispose();
  });

  Future<void> spawnPlugin() async {
    final context = AgentContext(
      sensors: StubSensorAccess(),
      ai: StubAIAccess(),
      bus: mockBus,
      output: mockOutput,
      clock: fakeClock,
    );
    await plugin.onSpawn(context);
  }

  group('manifest', () {
    test('has correct id', () {
      expect(plugin.manifest.id, 'com.kita.alert');
    });

    test('has correct permissions', () {
      expect(
          plugin.manifest.permissions, containsAll(['camera', 'haptic', 'tts']));
    });

    test('has official trust level', () {
      expect(plugin.manifest.trustLevel, TrustLevel.official);
    });

    test('is persistent agent type', () {
      expect(plugin.manifest.agentType, AgentType.persistent);
    });

    test('has critical priority', () {
      expect(plugin.manifest.priority, AgentPriority.critical);
    });
  });

  group('voiceCommands', () {
    test('has ok command with aliases', () {
      final ok = plugin.voiceCommands.firstWhere((c) => c.trigger == 'ok');
      expect(ok.aliases, isNotEmpty);
    });

    test('has c est quoi command with aliases', () {
      final quoi =
          plugin.voiceCommands.firstWhere((c) => c.trigger == "c'est quoi");
      expect(quoi.aliases, isNotEmpty);
    });
  });

  group('lifecycle', () {
    test('onSpawn enables the plugin', () async {
      await spawnPlugin();
      final result = await plugin.handleInput(_makeInput(command: 'ok'));
      expect(result.isSuccess, isTrue);
    });

    test('handleInput fails when not spawned', () async {
      final result = await plugin.handleInput(_makeInput(command: 'ok'));
      expect(result.isFailure, isTrue);
    });

    test('onTerminate dismisses active alert', () async {
      await spawnPlugin();
      await plugin.handleInput(_obstacleInput());
      await plugin.onTerminate();

      // buildViewport should return null after termination
      final viewport = plugin.buildViewport(
        _FakeBuildContext(),
      );
      expect(viewport, isNull);
    });
  });

  group('handleInput obstacle_detected', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('immediate alert (< 3m) triggers danger haptic and critical TTS',
        () async {
      final result = await plugin.handleInput(
        _obstacleInput(type: 'voiture', distance: 2.0, confidence: 0.95),
      );

      expect(result.isSuccess, isTrue);

      // TTS via OutputHandle with critical priority
      expect(mockOutput.speakCalls.length, 1);
      expect(mockOutput.speakCalls.first.text, contains('Attention'));
      expect(mockOutput.speakCalls.first.text, contains('voiture'));
      expect(mockOutput.speakCalls.first.text, contains('2 metres'));
      expect(mockOutput.speakCalls.first.priority, OutputPriority.critical);

      // Haptic danger via OutputHandle
      expect(mockOutput.hapticCalls.length, 1);
      expect(mockOutput.hapticCalls.first.pattern, HapticPattern.danger);
    });

    test('preventive alert (3-10m) triggers warning haptic and high TTS',
        () async {
      final result = await plugin.handleInput(
        _obstacleInput(type: 'travaux', distance: 8.0, confidence: 0.88),
      );

      expect(result.isSuccess, isTrue);

      // TTS via OutputHandle with high priority
      expect(mockOutput.speakCalls.length, 1);
      expect(mockOutput.speakCalls.first.text, isNot(contains('Attention')));
      expect(mockOutput.speakCalls.first.text, contains('travaux'));
      expect(mockOutput.speakCalls.first.text, contains('8 metres'));
      expect(mockOutput.speakCalls.first.priority, OutputPriority.high);

      // Haptic warning via OutputHandle
      expect(mockOutput.hapticCalls.length, 1);
      expect(mockOutput.hapticCalls.first.pattern, HapticPattern.warning);
    });

    test('distance > 10m is ignored (no alert)', () async {
      final result = await plugin.handleInput(
        _obstacleInput(distance: 15.0),
      );

      expect(result.isSuccess, isTrue);
      expect(mockOutput.speakCalls, isEmpty);
      expect(mockOutput.hapticCalls, isEmpty);
    });

    test('confidence <= 0.80 is ignored', () async {
      final result = await plugin.handleInput(
        _obstacleInput(confidence: 0.80),
      );

      expect(result.isSuccess, isTrue);
      expect(mockOutput.speakCalls, isEmpty);
    });

    test('confidence just above 0.80 triggers alert', () async {
      final result = await plugin.handleInput(
        _obstacleInput(confidence: 0.81),
      );

      expect(result.isSuccess, isTrue);
      expect(mockOutput.speakCalls.length, 1);
    });

    test('response type is alert', () async {
      final result = await plugin.handleInput(_obstacleInput());

      result.when(
        success: (output) {
          expect(output.type, AgentOutputType.alert);
          expect(output.content, contains('voiture'));
          expect(output.metadata, isNotNull);
          expect(output.metadata!['urgency'], 'immediate');
        },
        failure: (_) => fail('Should succeed'),
      );
    });
  });

  group('dismiss by ok command', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('ok command dismisses alert', () async {
      await plugin.handleInput(_obstacleInput());
      expect(plugin.buildViewport(_FakeBuildContext()), isNotNull);

      final result = await plugin.handleInput(
        _makeInput(command: 'ok'),
      );

      expect(result.isSuccess, isTrue);
      expect(plugin.buildViewport(_FakeBuildContext()), isNull);
    });

    test('dismiss command also works', () async {
      await plugin.handleInput(_obstacleInput());
      final result = await plugin.handleInput(
        _makeInput(command: 'dismiss'),
      );

      expect(result.isSuccess, isTrue);
      expect(plugin.buildViewport(_FakeBuildContext()), isNull);
    });
  });

  group('c est quoi', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('describes recent detection', () async {
      await plugin.handleInput(
        _obstacleInput(type: 'voiture', distance: 2.5, confidence: 0.95),
      );
      mockOutput.speakCalls.clear();

      final result = await plugin.handleInput(
        _makeInput(command: "c'est quoi"),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (output) {
          expect(output.content, contains('voiture'));
          expect(output.content, contains('95 pour cent'));
        },
        failure: (_) => fail('Should succeed'),
      );

      // TTS was called via OutputHandle
      expect(mockOutput.speakCalls.length, 1);
      expect(mockOutput.speakCalls.first.priority, OutputPriority.high);
    });

    test('reports no obstacle when no recent detection', () async {
      final result = await plugin.handleInput(
        _makeInput(command: "c'est quoi"),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (output) {
          expect(output.content, contains('Aucun obstacle'));
        },
        failure: (_) => fail('Should succeed'),
      );
    });

    test('description expires after 10-second window', () async {
      await plugin.handleInput(
        _obstacleInput(type: 'voiture', distance: 2.0, confidence: 0.95),
      );
      mockOutput.speakCalls.clear();

      // Advance past the 10-second window
      fakeClock.advance(const Duration(seconds: 11));

      final result = await plugin.handleInput(
        _makeInput(command: 'describe_obstacle'),
      );
      expect(result.isSuccess, isTrue);
      result.when(
        success: (output) {
          expect(output.content, contains('Aucun obstacle'));
        },
        failure: (_) => fail('Should succeed'),
      );
      expect(mockOutput.speakCalls.length, 1);
      expect(mockOutput.speakCalls.first.text, contains('Aucun obstacle'));
    });

    test('describe_obstacle alias also works', () async {
      await plugin.handleInput(_obstacleInput());
      mockOutput.speakCalls.clear();

      final result = await plugin.handleInput(
        _makeInput(command: 'describe_obstacle'),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (output) {
          expect(output.content, contains('voiture'));
        },
        failure: (_) => fail('Should succeed'),
      );
    });
  });

  group('buildViewport', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('returns null when no active alert', () {
      expect(plugin.buildViewport(_FakeBuildContext()), isNull);
    });

    test('returns widget when alert is active', () async {
      await plugin.handleInput(_obstacleInput());
      final viewport = plugin.buildViewport(_FakeBuildContext());
      expect(viewport, isNotNull);
    });
  });

  group('race conditions', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('preventive ignored while immediate is active', () async {
      // Trigger immediate alert
      await plugin.handleInput(
        _obstacleInput(distance: 1.0, confidence: 0.95),
      );

      // Try preventive — should be ignored
      final result = await plugin.handleInput(
        _obstacleInput(distance: 5.0, confidence: 0.90),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (output) {
          expect(output.content, contains('Alerte immediate en cours'));
        },
        failure: (_) => fail('Should succeed'),
      );

      // Only one set of speak/haptic calls (the first)
      expect(mockOutput.speakCalls.length, 1);
    });

    test('new immediate replaces old immediate', () async {
      await plugin.handleInput(
        _obstacleInput(type: 'personne', distance: 2.0),
      );
      await plugin.handleInput(
        _obstacleInput(type: 'voiture', distance: 1.0),
      );

      // Two speak calls
      expect(mockOutput.speakCalls.length, 2);

      // Second TTS message should be about voiture
      expect(mockOutput.speakCalls.last.text, contains('voiture'));
    });
  });

  group('unknown command', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('returns failure for unknown command', () async {
      final result = await plugin.handleInput(
        _makeInput(command: 'unknown_command'),
      );

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Should fail'),
        failure: (failure) {
          expect(failure, isA<PluginFailure>());
        },
      );
    });
  });

  group('logging', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('logs do not contain PII', () async {
      await plugin.handleInput(_obstacleInput());
      await plugin.handleInput(_makeInput(command: "c'est quoi"));
      await plugin.handleInput(_makeInput(command: 'ok'));

      for (final entry in logEntries) {
        expect(entry.message, isNot(contains('email')));
        expect(entry.message, isNot(contains('latitude')));
        expect(entry.message, isNot(contains('longitude')));
      }
    });

    test('log messages use [Plugin.Alert] source', () async {
      await plugin.handleInput(_obstacleInput());

      final alertLogs =
          logEntries.where((e) => e.message.contains('[Plugin.Alert]'));
      expect(alertLogs, isNotEmpty);
    });
  });
}

/// Minimal fake BuildContext for testing buildViewport.
class _FakeBuildContext extends Fake implements BuildContext {}
