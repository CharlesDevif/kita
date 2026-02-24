import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
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
import 'package:kita/features/plugins/built_in/describe/describe_plugin.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';

import 'describe_test_helpers.dart';

// === Mock OutputHandle ===

class MockOutputHandle implements OutputHandle {
  MockOutputHandle({required this.agentId});

  @override
  final String agentId;

  final List<({String text, OutputPriority priority})> speakCalls = [];

  final StreamController<SpeechEvent> speechEventsController =
      StreamController<SpeechEvent>.broadcast();

  @override
  Stream<SpeechEvent> get speechEvents => speechEventsController.stream;

  @override
  Future<void> speak(String text,
      {OutputPriority priority = OutputPriority.standard}) async {
    speakCalls.add((text: text, priority: priority));
  }

  @override
  Future<void> haptic(HapticPattern pattern,
      {OutputPriority priority = OutputPriority.standard}) async {}

  @override
  void updateViewport(Widget widget) {}

  @override
  void complete() {}

  void dispose() {
    speechEventsController.close();
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

AgentInput _agentInput({String command = 'decris'}) {
  return AgentInput(
    command: command,
    params: const {},
    source: InputSource.voice,
    timestamp: DateTime(2026, 1, 1),
  );
}

// --- Tests ---

void main() {
  late KitaDescribePlugin plugin;
  late MockSensorAccess mockSensors;
  late MockAIAccess mockAI;
  late MockOutputHandle mockOutput;
  late MockAgentBus mockBus;
  late FakeClock fakeClock;
  late List<LogEntry> logEntries;

  setUp(() {
    plugin = KitaDescribePlugin();
    mockSensors = MockSensorAccess();
    mockAI = MockAIAccess();
    mockOutput = MockOutputHandle(agentId: 'com.kita.describe');
    mockBus = MockAgentBus();
    fakeClock = FakeClock();
    logEntries = [];
    KitaLogger.testLogHandler = (entry) => logEntries.add(entry);
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
    mockOutput.dispose();
  });

  Future<void> spawnPlugin() async {
    final context = AgentContext(
      sensors: mockSensors,
      ai: mockAI,
      bus: mockBus,
      output: mockOutput,
      clock: fakeClock,
    );
    await plugin.onSpawn(context);
  }

  group('manifest', () {
    test('has correct id', () {
      expect(plugin.manifest.id, 'com.kita.describe');
    });

    test('has correct name', () {
      expect(plugin.manifest.name, 'Kita Describe');
    });

    test('has correct version', () {
      expect(plugin.manifest.version, '1.0.0');
    });

    test('declares camera and ai.vision permissions', () {
      expect(plugin.manifest.permissions, ['camera', 'ai.vision']);
    });

    test('has official trust level', () {
      expect(plugin.manifest.trustLevel, TrustLevel.official);
    });

    test('declares vision and text capabilities', () {
      expect(plugin.manifest.capabilities, containsAll(['vision', 'text']));
    });

    test('declares compatible profiles', () {
      expect(
        plugin.manifest.compatibleProfiles,
        containsAll(['blind', 'low_vision', 'standard']),
      );
    });

    test('is onDemand agent type', () {
      expect(plugin.manifest.agentType, AgentType.onDemand);
    });

    test('has standard priority', () {
      expect(plugin.manifest.priority, AgentPriority.standard);
    });
  });

  group('voiceCommands', () {
    test('has decris as primary trigger', () {
      expect(plugin.voiceCommands.first.trigger, 'decris');
    });

    test('has describe alias', () {
      expect(plugin.voiceCommands.first.aliases, contains('describe'));
    });

    test('has decrit alias', () {
      expect(plugin.voiceCommands.first.aliases, contains('decrit'));
    });

    test('has decrivez alias', () {
      expect(plugin.voiceCommands.first.aliases, contains('decrivez'));
    });

    test('has descriptive description', () {
      expect(
        plugin.voiceCommands.first.description,
        isNotEmpty,
      );
    });
  });

  group('handleInput', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('returns text description on full success', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result = await plugin.handleInput(_agentInput());

      expect(result.isSuccess, isTrue);
      final output = (result as Success<AgentOutput>).value;
      expect(output.type, AgentOutputType.text);
      expect(output.content, contains('salon'));
    });

    test('response metadata contains provider info', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result = await plugin.handleInput(_agentInput());
      final output = (result as Success<AgentOutput>).value;

      expect(output.metadata, isNotNull);
      expect(output.metadata!['provider'], 'claude');
      expect(output.metadata!['latency_ms'], 2500);
      expect(output.metadata!['tier'], 'cloudPowerful');
    });

    test('sends describe prompt to AI vision', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      await plugin.handleInput(_agentInput());

      expect(mockAI.lastPromptReceived, KitaDescribePlugin.describePrompt);
    });

    test('returns failure on camera error', () async {
      mockSensors.failureToReturn = PermissionFailure.denied('camera');

      final result = await plugin.handleInput(_agentInput());

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure, isA<PluginFailure>());
      expect((failure as PluginFailure).pluginId, 'com.kita.describe');
    });

    test('returns failure on AI error', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.failureToReturn = const AIProviderFailure(
        userMessage: 'Service IA indisponible.',
        logMessage: 'AI vision timeout',
      );

      final result = await plugin.handleInput(_agentInput());

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure, isA<PluginFailure>());
    });

    test('continues with original image when EXIF strip fails', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result = await plugin.handleInput(_agentInput());

      // Should still succeed — graceful degradation
      expect(result.isSuccess, isTrue);

      // The image sent to AI should be the original (EXIF strip failed)
      expect(mockAI.lastImageReceived, isNotNull);

      // Verify warning was logged
      final warnings = logEntries.where((e) => e.level == LogLevel.warning);
      expect(warnings, isNotEmpty);
    });

    test('logs each pipeline step', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      await plugin.handleInput(_agentInput());

      final messages = logEntries.map((e) => e.message).toList();
      expect(messages, contains(contains('Handling command')));
      expect(messages, contains(contains('Photo captured')));
      expect(messages, contains(contains('Description received')));
    });

    test('plugin logs contain [Plugin.Describe] source', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      await plugin.handleInput(_agentInput());

      // Filter to only plugin logs (ExifStripper logs with [IO] source)
      final pluginLogs = logEntries
          .where((e) => e.message.startsWith('[Plugin.Describe]'))
          .toList();
      expect(pluginLogs, isNotEmpty);
      expect(pluginLogs.length, greaterThanOrEqualTo(3));
    });

    test('camera failure userMessage is in French', () async {
      mockSensors.failureToReturn = PermissionFailure.denied('camera');

      final result = await plugin.handleInput(_agentInput());
      final failure = (result as Failure).failure;

      expect(failure.userMessage, 'Impossible de prendre la photo.');
    });

    test('AI failure userMessage is in French', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.failureToReturn = const NetworkFailure(
        userMessage: 'Timeout',
        logMessage: 'AI request timed out',
      );

      final result = await plugin.handleInput(_agentInput());
      final failure = (result as Failure).failure;

      expect(failure.userMessage, "Je n'ai pas pu analyser l'image.");
    });
  });

  group('lifecycle', () {
    test('onSpawn completes without error', () async {
      await expectLater(spawnPlugin(), completes);
    });

    test('onTerminate completes without error', () async {
      await spawnPlugin();
      await expectLater(plugin.onTerminate(), completes);
    });

    test('onSpawn logs activation', () async {
      await spawnPlugin();

      final messages = logEntries.map((e) => e.message).toList();
      expect(messages, contains(contains('Describe agent spawned')));
    });

    test('onTerminate logs deactivation', () async {
      await spawnPlugin();
      await plugin.onTerminate();

      final messages = logEntries.map((e) => e.message).toList();
      expect(messages, contains(contains('Describe agent terminated')));
    });
  });

  group('buildViewport', () {
    testWidgets('returns null', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            final viewport = plugin.buildViewport(context);
            expect(viewport, isNull);
            return const SizedBox.shrink();
          },
        ),
      );
    });
  });

  group('prompt', () {
    test('is in French', () {
      expect(
        KitaDescribePlugin.describePrompt,
        contains('français'),
      );
    });

    test('requests spatial positioning', () {
      expect(
        KitaDescribePlugin.describePrompt,
        contains('position relative'),
      );
    });

    test('requests visible text', () {
      expect(
        KitaDescribePlugin.describePrompt,
        contains('texte visible'),
      );
    });

    test('requests obstacle/danger info', () {
      expect(
        KitaDescribePlugin.describePrompt,
        contains('obstacles'),
      );
    });

    test('requests concise response', () {
      expect(
        KitaDescribePlugin.describePrompt,
        contains('concises'),
      );
    });

    test('avoids introduction formulas', () {
      expect(
        KitaDescribePlugin.describePrompt,
        contains("Pas de formule d'introduction"),
      );
    });
  });
}
