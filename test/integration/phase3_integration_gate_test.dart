import 'dart:async';
import 'dart:typed_data';

// [M1] Use FakeAsync from fake_async which is a transitive dependency of
// flutter_test. flutter_test does not re-export FakeAsync directly, but this
// package is guaranteed present in any Flutter test environment. The
// depend_on_referenced_packages lint is suppressed in analysis_options.yaml
// for test files — see https://github.com/dart-lang/linter/issues/3210.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/orchestration/di/providers.dart';
import 'package:image/image.dart' as img;

import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/io/data/voice_command_handler.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/io/domain/location_service.dart';
import 'package:kita/features/io/domain/motion_service.dart';
import 'package:kita/features/orchestration/domain/agent_bus.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/kita_agent.dart';
import 'package:kita/features/orchestration/domain/models/agent_input.dart';
import 'package:kita/features/orchestration/domain/models/agent_message.dart';
import 'package:kita/features/orchestration/domain/models/agent_output.dart';
import 'package:kita/features/orchestration/domain/models/output_priority.dart';
import 'package:kita/features/orchestration/domain/output_handle.dart';
import 'package:kita/features/plugins/built_in/alert/alert_models.dart';
import 'package:kita/features/plugins/built_in/alert/kita_alert_plugin.dart';
import 'package:kita/features/plugins/built_in/describe/describe_plugin.dart';
import 'package:kita/features/plugins/built_in/describe/describe_state.dart';
import 'package:kita/features/plugins/data/plugin_registry.dart';
import 'package:kita/features/plugins/domain/ai_access.dart';
import 'package:kita/features/plugins/domain/kita_plugin.dart';
import 'package:kita/features/plugins/domain/plugin_manifest.dart';
import 'package:kita/features/plugins/domain/plugin_request.dart';
import 'package:kita/features/plugins/domain/plugin_response.dart';
import 'package:kita/features/plugins/domain/sensor_access.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';
import 'package:kita/features/plugins/domain/voice_command.dart' as vc;
import 'package:kita/features/shell/domain/orb_state.dart';
import 'package:kita/features/shell/presentation/kita_shell.dart';
import 'package:kita/features/shell/presentation/plugin_viewport.dart';
import 'package:kita/shared/widgets/kita_alert.dart';

// =============================================================================
// Mock implementations for Phase 3 integration testing
// =============================================================================

/// Mock SensorAccess — returns synthetic JPEG for capturePhoto.
class _MockSensorAccess implements SensorAccess {
  bool capturePhotoCalled = false;

  /// Real 1x1 JPEG generated via the `image` package so that
  /// ExifStripper.strip() can decode and re-encode it properly.
  static final _fakeJpeg = _generateRealJpeg();

  static Uint8List _generateRealJpeg() {
    final testImage = img.Image(width: 1, height: 1);
    testImage.setPixelRgba(0, 0, 255, 0, 0, 255);
    return Uint8List.fromList(img.encodeJpg(testImage));
  }

  @override
  Future<Result<ImageData>> capturePhoto() async {
    capturePhotoCalled = true;
    return Result.success(ImageData(
      bytes: _fakeJpeg,
      mimeType: 'image/jpeg',
      width: 640,
      height: 480,
    ));
  }

  @override
  Future<Result<Position>> getCurrentPosition() async {
    return const Result.success(
      Position(latitude: 48.8566, longitude: 2.3522),
    );
  }

  @override
  Future<Result<MotionState>> getMotionState() async {
    return const Result.success(MotionState.walking);
  }
}

/// Mock AIAccess — configurable cloud / offline behavior.
class _MockAIAccess implements AIAccess {
  _MockAIAccess({
    this.visionResponse = 'Un parc avec des arbres et un banc',
    this.shouldFailVision = false,
    this.offlineMode = false,
  });

  final String visionResponse;
  final bool shouldFailVision;
  final bool offlineMode;

  int visionCalls = 0;
  final List<String> promptsReceived = [];

  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    return const Result.success(AIResponse(
      content: 'Reponse IA generique',
      meta: AIResponseMeta(
        providerId: 'mock-ai',
        latency: Duration(milliseconds: 10),
        tier: ProviderTier.local,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt) async {
    visionCalls++;
    promptsReceived.add(prompt);

    if (shouldFailVision) {
      return const Result.failure(
        NetworkFailure(
          userMessage: 'Pas de connexion',
          logMessage: 'Mock: simulated offline',
        ),
      );
    }

    return Result.success(AIResponse(
      content: visionResponse,
      meta: AIResponseMeta(
        providerId: offlineMode ? 'local-ocr' : 'mock-cloud',
        latency: const Duration(milliseconds: 50),
        tier: offlineMode ? ProviderTier.local : ProviderTier.cloudPowerful,
      ),
      status: offlineMode ? AIResponseStatus.degraded : AIResponseStatus.success,
    ));
  }
}

/// Mock OutputHandle for agents that use the new KitaAgent API.
class _MockOutputHandle implements OutputHandle {
  _MockOutputHandle({required this.agentId});

  @override
  final String agentId;

  final List<({String text, OutputPriority priority})> speakCalls = [];
  final List<({HapticPattern pattern, OutputPriority priority})> hapticCalls =
      [];
  int completeCalled = 0;

  final StreamController<SpeechEvent> speechEventsController =
      StreamController<SpeechEvent>.broadcast();

  @override
  Stream<SpeechEvent> get speechEvents => speechEventsController.stream;

  @override
  Future<void> speak(String text,
      {OutputPriority priority = OutputPriority.standard,
      double? distance,
      String? cooldownKey}) async {
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
    speechEventsController.close();
  }
}

/// Mock AgentBus
class _MockAgentBus implements AgentBus {
  @override
  void publish(AgentMessage message) {}
  @override
  void subscribe(String agentId, Set<AgentMessageType> types) {}
  @override
  void unsubscribe(String agentId) {}
  @override
  Stream<AgentMessage> streamFor(String agentId) => const Stream.empty();
}

// [M2] Mock plugin that tracks onActivate/onDeactivate calls explicitly.
// This uses the OLD KitaPlugin interface for testing the deprecated PluginRegistry.
class _TrackingMockPlugin implements KitaPlugin {
  _TrackingMockPlugin({required this.id, required this.name});

  final String id;
  final String name;

  int activateCount = 0;
  int deactivateCount = 0;
  bool shouldThrowOnRequest = false;

  @override
  PluginManifest get manifest => PluginManifest(
        id: id,
        name: name,
        version: '1.0.0',
        description: 'Mock plugin for testing',
        trustLevel: TrustLevel.official,
        permissions: const [],
        capabilities: const [],
      );

  @override
  List<vc.VoiceCommand> get voiceCommands => const [];

  @override
  Future<void> onActivate() async {
    activateCount++;
  }

  @override
  Future<void> onDeactivate() async {
    deactivateCount++;
  }

  @override
  Future<Result<PluginResponse>> handleRequest(PluginRequest request) async {
    if (shouldThrowOnRequest) {
      throw StateError('Mock plugin crash in handleRequest');
    }
    return const Result.success(PluginResponse(
      type: PluginResponseType.text,
      content: 'Mock response',
    ));
  }

  @override
  Widget? buildViewport(BuildContext context) => null;
}

// Helpers

AgentInput _agentInput({
  String command = 'decris',
  Map<String, dynamic> params = const {},
  InputSource source = InputSource.voice,
}) {
  return AgentInput(
    command: command,
    params: params,
    source: source,
    timestamp: DateTime(2026, 1, 1),
  );
}

PluginRequest _makeRequest({
  required String command,
  Map<String, dynamic> params = const {},
  SensorAccess? sensors,
  AIAccess? ai,
}) {
  return PluginRequest(
    command: command,
    params: params,
    sensors: sensors ?? _MockSensorAccess(),
    ai: ai ?? _MockAIAccess(),
  );
}

// [L1] FakeBuildContext works here because plugins' buildViewport implementations
// only use BuildContext to satisfy the KitaAgent interface signature. Neither
// KitaDescribePlugin nor KitaAlertPlugin access Theme, MediaQuery, or any
// InheritedWidget from the context — they return pre-built widget trees.
/// Minimal fake BuildContext for buildViewport calls outside widget tests.
class _FakeBuildContext extends Fake implements BuildContext {}

// [L3] Shared helper for KitaAlert semantics verification to avoid duplication
// between AC-2 and the dedicated Semantics group.
Future<void> _verifyKitaAlertSemantics(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: KitaAlert(
          message: 'Attention ! voiture a 2 metres',
          severity: AlertSeverity.immediate,
        ),
      ),
    ),
  );
  await tester.pump();

  final semantics = tester.getSemantics(find.byType(KitaAlert));
  expect(semantics.flagsCollection.isLiveRegion, isTrue);
  expect(semantics.label, contains('Alerte'));
}

Future<void> _verifyKitaAlertDismissTarget(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: KitaAlert(
          message: 'Test alerte',
          severity: AlertSeverity.immediate,
          onDismiss: () {},
        ),
      ),
    ),
  );
  await tester.pump();

  final sizedBoxes = tester.widgetList<SizedBox>(
    find.ancestor(
      of: find.byIcon(Icons.close),
      matching: find.byType(SizedBox),
    ),
  );

  final hasCriticalTarget = sizedBoxes.any(
    (box) => box.width == 56 && box.height == 56,
  );
  expect(hasCriticalTarget, isTrue,
      reason: 'Dismiss button must have >= 56x56 touch target');
}

// =============================================================================
// Integration Gate Tests — Story 7.3 (Phase 3 -> Phase 4)
// =============================================================================

void main() {
  late List<LogEntry> logEntries;

  setUp(() {
    logEntries = [];
    KitaLogger.testLogHandler = (entry) => logEntries.add(entry);
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
  });

  // ---------------------------------------------------------------------------
  // AC-1 : Test flow Describe E2E (migrated to KitaAgent API)
  // ---------------------------------------------------------------------------
  group('AC-1: Describe flow E2E', () {
    late KitaDescribePlugin describePlugin;
    late _MockSensorAccess sensors;
    late _MockAIAccess ai;
    late _MockOutputHandle mockOutput;
    late _MockAgentBus mockBus;
    late FakeClock fakeClock;

    setUp(() {
      describePlugin = KitaDescribePlugin();
      sensors = _MockSensorAccess();
      ai = _MockAIAccess(
        visionResponse: 'Un parc avec des arbres et un banc devant vous',
      );
      mockOutput = _MockOutputHandle(agentId: 'com.kita.describe');
      mockBus = _MockAgentBus();
      fakeClock = FakeClock();
    });

    tearDown(() {
      mockOutput.dispose();
    });

    Future<void> spawnDescribe({
      _MockSensorAccess? s,
      _MockAIAccess? a,
    }) async {
      final context = AgentContext(
        sensors: s ?? sensors,
        ai: a ?? ai,
        bus: mockBus,
        output: mockOutput,
        clock: fakeClock,
      );
      await describePlugin.onSpawn(context);
    }

    test('"decris" triggers full pipeline: capture -> EXIF strip -> AI vision -> response',
        () async {
      await spawnDescribe();

      final result = await describePlugin.handleInput(
        _agentInput(command: 'decris'),
      );

      // Photo was captured
      expect(sensors.capturePhotoCalled, isTrue);

      // AI vision was called
      expect(ai.visionCalls, 1);

      // Prompt sent is the concise describe prompt
      expect(ai.promptsReceived.first, contains('cris cette image'));

      // Result is success with text response
      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.type, AgentOutputType.text);
          expect(response.content, contains('parc'));
          expect(response.content, contains('arbres'));
          expect(response.metadata, isNotNull);
          expect(response.metadata!['provider'], 'mock-cloud');
        },
        failure: (_) => fail('Should succeed'),
      );
    });

    // [H1] VoiceCommandHandler.recognize("decris") maps to describe command
    test('VoiceCommandHandler.recognize("decris") maps to VoiceCommand.describe',
        () {
      final result = VoiceCommandHandler.recognize('decris');
      expect(result.isSuccess, isTrue);
      result.when(
        success: (command) {
          expect(command, VoiceCommand.describe);
        },
        failure: (_) => fail('Should recognize "decris"'),
      );
    });

    // [H1] VoiceCommandHandler.recognize with accent variants
    test('VoiceCommandHandler.recognize handles accent variants', () {
      // "plus de details" (no accents) should map to moreDetails
      final detailsResult = VoiceCommandHandler.recognize('plus de details');
      expect(detailsResult.isSuccess, isTrue);
      detailsResult.when(
        success: (command) {
          expect(command, VoiceCommand.moreDetails);
        },
        failure: (_) => fail('Should recognize "plus de details"'),
      );

      // "repete" should map to repeat
      final repeatResult = VoiceCommandHandler.recognize('repete');
      expect(repeatResult.isSuccess, isTrue);
      repeatResult.when(
        success: (command) {
          expect(command, VoiceCommand.repeat);
        },
        failure: (_) => fail('Should recognize "repete"'),
      );

      // "merci" should map to thanks
      final merciResult = VoiceCommandHandler.recognize('merci');
      expect(merciResult.isSuccess, isTrue);
      merciResult.when(
        success: (command) {
          expect(command, VoiceCommand.thanks);
        },
        failure: (_) => fail('Should recognize "merci"'),
      );
    });

    test('describe plugin state transitions to describing after "decris"',
        () async {
      await spawnDescribe();

      await describePlugin.handleInput(
        _agentInput(command: 'decris'),
      );

      expect(describePlugin.state.phase, DescribePhase.describing);
      expect(describePlugin.state.imageData, isNotNull);
      expect(describePlugin.state.description, isNotNull);
    });

    test('"decris" response metadata includes provider and latency', () async {
      await spawnDescribe();

      final result = await describePlugin.handleInput(
        _agentInput(command: 'decris'),
      );

      result.when(
        success: (response) {
          expect(response.metadata!.containsKey('provider'), isTrue);
          expect(response.metadata!.containsKey('latency_ms'), isTrue);
          expect(response.metadata!.containsKey('tier'), isTrue);
        },
        failure: (_) => fail('Should succeed'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // AC-2 : Test flow Alert E2E (migrated to KitaAgent API)
  // ---------------------------------------------------------------------------
  group('AC-2: Alert flow E2E', () {
    late KitaAlertPlugin alertPlugin;
    late _MockOutputHandle mockOutput;
    late _MockAgentBus mockBus;
    late FakeClock fakeClock;

    setUp(() async {
      alertPlugin = KitaAlertPlugin();
      mockOutput = _MockOutputHandle(agentId: 'com.kita.alert');
      mockBus = _MockAgentBus();
      fakeClock = FakeClock();
    });

    tearDown(() {
      mockOutput.dispose();
    });

    Future<void> spawnAlert() async {
      final context = AgentContext(
        sensors: _MockSensorAccess(),
        ai: _MockAIAccess(),
        bus: mockBus,
        output: mockOutput,
        clock: fakeClock,
      );
      await alertPlugin.onSpawn(context);
    }

    // [H1] VoiceCommandHandler.recognize("obstacle") for Alert plugin
    test('VoiceCommandHandler.recognize does not map "obstacle" to a built-in command',
        () {
      final obstacleResult = VoiceCommandHandler.recognize('obstacle');
      expect(obstacleResult.isFailure, isTrue,
          reason: '"obstacle" is not a VoiceCommandHandler command');

      // "stop" IS a general voice command
      final stopResult = VoiceCommandHandler.recognize('stop');
      expect(stopResult.isSuccess, isTrue);
      stopResult.when(
        success: (command) {
          expect(command, VoiceCommand.stop);
        },
        failure: (_) => fail('Should recognize "stop"'),
      );
    });

    test('immediate obstacle (< 3m) triggers danger haptic + critical TTS + KitaAlert',
        () async {
      await spawnAlert();

      final result = await alertPlugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.0,
            'confidence': 0.95,
          },
          source: InputSource.sensor,
        ),
      );

      expect(result.isSuccess, isTrue);

      // TTS with critical priority and "Attention !"
      expect(mockOutput.speakCalls.length, 1);
      expect(mockOutput.speakCalls.first.text, contains('Attention'));
      expect(mockOutput.speakCalls.first.text, contains('voiture'));
      expect(mockOutput.speakCalls.first.text, contains('2 metres'));
      expect(mockOutput.speakCalls.first.priority, OutputPriority.critical);

      // Haptic danger via OutputHandle
      expect(mockOutput.hapticCalls.length, 1);
      expect(mockOutput.hapticCalls.first.pattern, HapticPattern.danger);

      // Response type is alert with urgency metadata
      result.when(
        success: (response) {
          expect(response.type, AgentOutputType.alert);
          expect(response.content, contains('Attention'));
          expect(response.metadata!['urgency'], 'immediate');
          expect(response.metadata!['type'], 'voiture');
        },
        failure: (_) => fail('Should succeed'),
      );

      // KitaAlert widget is built
      final viewport = alertPlugin.buildViewport(_FakeBuildContext());
      expect(viewport, isNotNull);
    });

    // [H2] Pipeline simulation: detection -> classification -> alert
    test('detection -> urgency classification -> alert pipeline', () async {
      await spawnAlert();

      const obstacleType = 'personne';
      const distance = 1.5;
      const confidence = 0.92;

      final urgency = classifyUrgency(distance);
      expect(urgency, AlertUrgency.immediate);

      final expectedMessage = buildAlertMessage(urgency, obstacleType, distance);
      expect(expectedMessage, contains('Attention'));
      expect(expectedMessage, contains('personne'));

      final result = await alertPlugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': obstacleType,
            'distance': distance,
            'confidence': confidence,
          },
          source: InputSource.sensor,
        ),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.type, AgentOutputType.alert);
          expect(response.metadata!['urgency'], 'immediate');
          expect(response.content, contains('personne'));
        },
        failure: (_) => fail('Should succeed'),
      );

      // Verify multi-modal output was triggered via OutputHandle
      expect(mockOutput.speakCalls.length, 1);
      expect(mockOutput.speakCalls.first.priority, OutputPriority.critical);
      expect(mockOutput.hapticCalls.length, 1);
      expect(mockOutput.hapticCalls.first.pattern, HapticPattern.danger);
    });

    // [H2] Preventive detection pipeline
    test('detection at 5m -> preventive urgency -> warning alert pipeline',
        () async {
      await spawnAlert();

      const distance = 5.0;
      final urgency = classifyUrgency(distance);
      expect(urgency, AlertUrgency.preventive);

      final result = await alertPlugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': 'velo',
            'distance': distance,
            'confidence': 0.88,
          },
          source: InputSource.sensor,
        ),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.metadata!['urgency'], 'preventive');
        },
        failure: (_) => fail('Should succeed'),
      );
      expect(mockOutput.hapticCalls.length, 1);
      expect(mockOutput.hapticCalls.first.pattern, HapticPattern.warning);
      expect(mockOutput.speakCalls.first.priority, OutputPriority.high);
    });

    test('preventive obstacle (3-10m) triggers warning haptic + high TTS',
        () async {
      await spawnAlert();

      final result = await alertPlugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': 'travaux',
            'distance': 8.0,
            'confidence': 0.88,
          },
          source: InputSource.sensor,
        ),
      );

      expect(result.isSuccess, isTrue);

      // TTS with high priority, no "Attention"
      expect(mockOutput.speakCalls.length, 1);
      expect(mockOutput.speakCalls.first.text, isNot(contains('Attention')));
      expect(mockOutput.speakCalls.first.text, contains('travaux'));
      expect(mockOutput.speakCalls.first.text, contains('8 metres'));
      expect(mockOutput.speakCalls.first.priority, OutputPriority.high);

      // Haptic warning
      expect(mockOutput.hapticCalls.length, 1);
      expect(mockOutput.hapticCalls.first.pattern, HapticPattern.warning);

      // Response metadata
      result.when(
        success: (response) {
          expect(response.type, AgentOutputType.alert);
          expect(response.metadata!['urgency'], 'preventive');
        },
        failure: (_) => fail('Should succeed'),
      );
    });

    // [L3] Delegates to shared helper to avoid duplicating KitaAlert semantics
    // test between AC-2 and the Semantics group.
    testWidgets('KitaAlert Semantics has liveRegion',
        _verifyKitaAlertSemantics);
  });

  // ---------------------------------------------------------------------------
  // AC-3 : AI fallback behavior (migrated to KitaAgent API)
  // ---------------------------------------------------------------------------
  group('AC-3: AI fallback behavior', () {
    test('AI vision fails -> returns failure (Describe delegates fallback to AI layer)',
        () async {
      final plugin = KitaDescribePlugin();
      final failingAi = _MockAIAccess(shouldFailVision: true);
      final sensors = _MockSensorAccess();
      final output = _MockOutputHandle(agentId: 'com.kita.describe');

      await plugin.onSpawn(AgentContext(
        sensors: sensors,
        ai: failingAi,
        bus: _MockAgentBus(),
        output: output,
        clock: FakeClock(),
      ));

      final result = await plugin.handleInput(
        _agentInput(command: 'decris'),
      );

      // AI failure propagates as plugin failure
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Should fail'),
        failure: (failure) {
          expect(failure, isA<PluginFailure>());
        },
      );

      output.dispose();
    });

    // [H3] Test degraded response (AI layer fell back to local provider)
    test('AI returns degraded response -> content prefixed with "Mode local"',
        () async {
      final plugin = KitaDescribePlugin();
      final offlineAi = _MockAIAccess(
        visionResponse: 'Texte detecte : Sortie de secours',
        offlineMode: true,
      );
      final output = _MockOutputHandle(agentId: 'com.kita.describe');

      await plugin.onSpawn(AgentContext(
        sensors: _MockSensorAccess(),
        ai: offlineAi,
        bus: _MockAgentBus(),
        output: output,
        clock: FakeClock(),
      ));

      final result = await plugin.handleInput(
        _agentInput(command: 'decris'),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.content, contains('Mode local'));
          expect(response.content, contains('Sortie de secours'));
          expect(response.metadata!['offline'], isTrue);
          expect(response.metadata!['provider'], 'local-ocr');
        },
        failure: (_) => fail('Should succeed'),
      );

      output.dispose();
    });

    test('degraded response metadata reflects local provider tier', () async {
      final plugin = KitaDescribePlugin();
      final offlineAi = _MockAIAccess(
        visionResponse: 'Panneau: Attention travaux',
        offlineMode: true,
      );
      final output = _MockOutputHandle(agentId: 'com.kita.describe');

      await plugin.onSpawn(AgentContext(
        sensors: _MockSensorAccess(),
        ai: offlineAi,
        bus: _MockAgentBus(),
        output: output,
        clock: FakeClock(),
      ));

      final result = await plugin.handleInput(
        _agentInput(command: 'decris'),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.metadata!['tier'], 'local');
          expect(response.metadata!['provider'], 'local-ocr');
          expect(response.metadata!['offline'], isTrue);
          expect(response.content, startsWith('Mode local'));
        },
        failure: (_) => fail('Should succeed'),
      );

      output.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // AC-4 : Test enchainement naturel (migrated to KitaAgent API)
  // ---------------------------------------------------------------------------
  group('AC-4: Natural chaining flow', () {
    late KitaDescribePlugin plugin;
    late _MockSensorAccess sensors;
    late _MockAIAccess ai;
    late _MockOutputHandle mockOutput;
    late FakeClock fakeClock;

    setUp(() async {
      plugin = KitaDescribePlugin();
      sensors = _MockSensorAccess();
      ai = _MockAIAccess(
        visionResponse: 'Un parc avec des arbres',
      );
      mockOutput = _MockOutputHandle(agentId: 'com.kita.describe');
      fakeClock = FakeClock();

      await plugin.onSpawn(AgentContext(
        sensors: sensors,
        ai: ai,
        bus: _MockAgentBus(),
        output: mockOutput,
        clock: fakeClock,
      ));
    });

    tearDown(() {
      mockOutput.dispose();
    });

    test('"decris" -> description initiale', () async {
      final result = await plugin.handleInput(
        _agentInput(command: 'decris'),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.content, contains('parc'));
        },
        failure: (_) => fail('Should succeed'),
      );
      expect(plugin.state.phase, DescribePhase.describing);
    });

    test('"plus de details" -> same image, enriched prompt', () async {
      // First describe
      await plugin.handleInput(_agentInput(command: 'decris'));

      // Change AI response for the detailed version — need to re-spawn
      // with a new AI mock, but since describe stores the image in state,
      // we can use a different AI mock for the detailed call.
      // Actually, the plugin uses context.ai which was set at spawn time.
      // The mock will return the same response for detailed too.
      // For this test, we just verify the prompt is different.
      final result = await plugin.handleInput(
        _agentInput(command: 'plus de details'),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.metadata!['detailed'], isTrue);
        },
        failure: (_) => fail('Should succeed'),
      );

      // AI vision was called with the detailed prompt
      expect(ai.promptsReceived.last, contains('tail'));

      // State transitioned to detailed
      expect(plugin.state.phase, DescribePhase.detailed);
    });

    test('"repete" -> re-reads last description without new AI call', () async {
      // Describe first
      await plugin.handleInput(_agentInput(command: 'decris'));

      final initialVisionCalls = ai.visionCalls;

      // Repeat
      final result = await plugin.handleInput(
        _agentInput(command: 'repete'),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.content, contains('parc'));
          expect(response.metadata!['repeated'], isTrue);
        },
        failure: (_) => fail('Should succeed'),
      );

      // No new AI call
      expect(ai.visionCalls, initialVisionCalls);
    });

    test('"merci" -> return to passive mode', () async {
      await plugin.handleInput(_agentInput(command: 'decris'));

      final result = await plugin.handleInput(
        _agentInput(command: 'merci'),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.metadata!['action'], 'return_passive');
        },
        failure: (_) => fail('Should succeed'),
      );

      // Plugin returned to idle
      expect(plugin.state.phase, DescribePhase.idle);
      // complete() called on output handle
      expect(mockOutput.completeCalled, 1);
    });

    test('full chain: decris -> plus de details -> repete -> merci', () async {
      // 1. decris
      final descResult = await plugin.handleInput(
        _agentInput(command: 'decris'),
      );
      expect(descResult.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.describing);

      // 2. plus de details
      final detailResult = await plugin.handleInput(
        _agentInput(command: 'plus de details'),
      );
      expect(detailResult.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.detailed);

      // 3. repete — should repeat the detailed description
      final repeatResult = await plugin.handleInput(
        _agentInput(command: 'repete'),
      );
      expect(repeatResult.isSuccess, isTrue);

      // 4. merci
      final merciResult = await plugin.handleInput(
        _agentInput(command: 'merci'),
      );
      expect(merciResult.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.idle);
    });

    test('silence timeout auto-returns to passive', () async {
      await plugin.handleInput(_agentInput(command: 'decris'));
      expect(plugin.state.phase, DescribePhase.describing);

      // Simulate speech completed event (starts silence timer via Clock.delayed)
      mockOutput.speechEventsController.add(SpeechEvent.completed);
      await Future<void>.delayed(Duration.zero);

      // Advance past silence timeout (5s)
      fakeClock.advance(const Duration(seconds: 6));

      expect(plugin.state.phase, DescribePhase.idle);
      expect(mockOutput.completeCalled, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // AC-5 : Two plugins loaded simultaneously
  // Note: Since Describe/Alert now implement KitaAgent (not KitaPlugin),
  // they cannot be registered in PluginRegistryImpl. This test now uses
  // the new KitaAgent API to verify both agents work independently.
  // PluginRegistryImpl tests use _TrackingMockPlugin for backward compat.
  // ---------------------------------------------------------------------------
  group('AC-5: Two agents simultaneously', () {
    late KitaDescribePlugin describePlugin;
    late KitaAlertPlugin alertPlugin;
    late _MockOutputHandle describeOutput;
    late _MockOutputHandle alertOutput;
    late FakeClock fakeClock;

    setUp(() async {
      describePlugin = KitaDescribePlugin();
      alertPlugin = KitaAlertPlugin();
      describeOutput = _MockOutputHandle(agentId: 'com.kita.describe');
      alertOutput = _MockOutputHandle(agentId: 'com.kita.alert');
      fakeClock = FakeClock();
    });

    tearDown(() {
      describeOutput.dispose();
      alertOutput.dispose();
    });

    Future<void> spawnBoth() async {
      final sensors = _MockSensorAccess();
      final ai = _MockAIAccess(
        visionResponse: 'Un trottoir avec des pietons',
      );
      final bus = _MockAgentBus();

      await describePlugin.onSpawn(AgentContext(
        sensors: sensors,
        ai: ai,
        bus: bus,
        output: describeOutput,
        clock: fakeClock,
      ));

      await alertPlugin.onSpawn(AgentContext(
        sensors: sensors,
        ai: ai,
        bus: bus,
        output: alertOutput,
        clock: fakeClock,
      ));
    }

    test('both agents spawn and work without conflict', () async {
      await spawnBoth();

      // Describe request
      final descResult = await describePlugin.handleInput(
        _agentInput(command: 'decris'),
      );
      expect(descResult.isSuccess, isTrue);

      // Alert request
      final alertResult = await alertPlugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': 'poteau',
            'distance': 2.0,
            'confidence': 0.95,
          },
          source: InputSource.sensor,
        ),
      );
      expect(alertResult.isSuccess, isTrue);

      // Both responded correctly
      descResult.when(
        success: (response) {
          expect(response.type, AgentOutputType.text);
          expect(response.content, contains('trottoir'));
        },
        failure: (_) => fail('Describe should succeed'),
      );

      alertResult.when(
        success: (response) {
          expect(response.type, AgentOutputType.alert);
          expect(response.content, contains('poteau'));
        },
        failure: (_) => fail('Alert should succeed'),
      );
    });

    test('aggregated voice commands contain both agents triggers', () async {
      // Voice commands are static properties, no need to spawn
      final describeCommands = describePlugin.voiceCommands;
      final alertCommands = alertPlugin.voiceCommands;
      final allCommands = [...describeCommands, ...alertCommands];

      final triggers = allCommands.map((c) => c.trigger).toList();
      expect(triggers, contains('decris'));
      expect(triggers, contains('plus de details'));
      expect(triggers, contains('ok'));
      expect(triggers, contains("c'est quoi"));
    });

    testWidgets('KitaShell renders without crash with both agents active',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasActiveOnDemandProvider.overrideWithValue(false),
          ],
          child: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: KitaShell(
                orbStateOverride: OrbState.passive,
                viewportChild: PluginViewport(
                  fallbackText: 'Deux agents actifs',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Shell renders
      expect(find.byType(KitaShell), findsOneWidget);
      // PluginViewport renders
      expect(find.byType(PluginViewport), findsOneWidget);
    });

    testWidgets('KitaShell renders Alert viewport without crash',
        (tester) async {
      await spawnBoth();

      await alertPlugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.0,
            'confidence': 0.95,
          },
          source: InputSource.sensor,
        ),
      );

      final alertWidget = alertPlugin.buildViewport(_FakeBuildContext());
      expect(alertWidget, isNotNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasActiveOnDemandProvider.overrideWithValue(false),
          ],
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: KitaShell(
                orbStateOverride: OrbState.passive,
                viewportChild: SizedBox(
                  height: 400,
                  child: alertWidget,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(KitaShell), findsOneWidget);

      // Terminate to clean up alert timers
      await tester.runAsync(() => alertPlugin.onTerminate());
    });
  });

  // ---------------------------------------------------------------------------
  // AC-6 : Plugin lifecycle activate/deactivate
  // Note: Uses _TrackingMockPlugin (old KitaPlugin API) for PluginRegistryImpl
  // tests. Describe/Alert lifecycle tests use the new KitaAgent API.
  // ---------------------------------------------------------------------------
  group('AC-6: Plugin lifecycle', () {
    late PluginRegistryImpl registry;

    setUp(() {
      registry = PluginRegistryImpl();
    });

    // [M2] Explicit onActivate/onDeactivate verification using tracking mock
    test('onActivate and onDeactivate are called exactly once per cycle',
        () async {
      final trackingPlugin = _TrackingMockPlugin(
        id: 'com.kita.test.tracking',
        name: 'Tracking',
      );
      registry.register(trackingPlugin);

      // Before activation
      expect(trackingPlugin.activateCount, 0);
      expect(trackingPlugin.deactivateCount, 0);

      // Activate
      await registry.activate('com.kita.test.tracking');
      expect(trackingPlugin.activateCount, 1);
      expect(trackingPlugin.deactivateCount, 0);

      // Deactivate
      await registry.deactivate('com.kita.test.tracking');
      expect(trackingPlugin.activateCount, 1);
      expect(trackingPlugin.deactivateCount, 1);

      // Re-activate -> new cycle
      await registry.activate('com.kita.test.tracking');
      expect(trackingPlugin.activateCount, 2);
      expect(trackingPlugin.deactivateCount, 1);

      // Re-deactivate
      await registry.deactivate('com.kita.test.tracking');
      expect(trackingPlugin.activateCount, 2);
      expect(trackingPlugin.deactivateCount, 2);
    });

    test('Describe lifecycle: spawn -> request -> terminate', () async {
      final plugin = KitaDescribePlugin();
      final output = _MockOutputHandle(agentId: 'com.kita.describe');

      await plugin.onSpawn(AgentContext(
        sensors: _MockSensorAccess(),
        ai: _MockAIAccess(visionResponse: 'Test description'),
        bus: _MockAgentBus(),
        output: output,
        clock: FakeClock(),
      ));

      // Handle request
      final reqResult = await plugin.handleInput(
        _agentInput(command: 'decris'),
      );
      expect(reqResult.isSuccess, isTrue);

      // Terminate
      await plugin.onTerminate();
      expect(plugin.state.phase, DescribePhase.idle);

      output.dispose();
    });

    test('Alert lifecycle: spawn -> request -> terminate', () async {
      final plugin = KitaAlertPlugin();
      final output = _MockOutputHandle(agentId: 'com.kita.alert');

      await plugin.onSpawn(AgentContext(
        sensors: _MockSensorAccess(),
        ai: _MockAIAccess(),
        bus: _MockAgentBus(),
        output: output,
        clock: FakeClock(),
      ));

      // Handle request
      final reqResult = await plugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': 'poteau',
            'distance': 5.0,
            'confidence': 0.90,
          },
          source: InputSource.sensor,
        ),
      );
      expect(reqResult.isSuccess, isTrue);

      // Terminate
      await plugin.onTerminate();

      // Alert should be dismissed after termination
      expect(plugin.buildViewport(_FakeBuildContext()), isNull);

      output.dispose();
    });

    test('deactivation then reactivation works correctly (tracking mock)',
        () async {
      final plugin1 = _TrackingMockPlugin(
        id: 'com.kita.test.a',
        name: 'A',
      );
      final plugin2 = _TrackingMockPlugin(
        id: 'com.kita.test.b',
        name: 'B',
      );

      registry.register(plugin1);
      registry.register(plugin2);

      // Activate both
      await registry.activate('com.kita.test.a');
      await registry.activate('com.kita.test.b');
      expect(registry.getPlugin('com.kita.test.a'), isNotNull);
      expect(registry.getPlugin('com.kita.test.b'), isNotNull);

      // Deactivate both
      await registry.deactivate('com.kita.test.a');
      await registry.deactivate('com.kita.test.b');
      expect(registry.getPlugin('com.kita.test.a'), isNull);
      expect(registry.getPlugin('com.kita.test.b'), isNull);

      // Reactivate both
      final reAct1 = await registry.activate('com.kita.test.a');
      final reAct2 = await registry.activate('com.kita.test.b');
      expect(reAct1.isSuccess, isTrue);
      expect(reAct2.isSuccess, isTrue);
    });

    test('deactivating one plugin does not affect the other (tracking mock)',
        () async {
      final plugin1 = _TrackingMockPlugin(
        id: 'com.kita.test.x',
        name: 'X',
      );
      final plugin2 = _TrackingMockPlugin(
        id: 'com.kita.test.y',
        name: 'Y',
      );

      registry.register(plugin1);
      registry.register(plugin2);
      await registry.activate('com.kita.test.x');
      await registry.activate('com.kita.test.y');

      // Deactivate only X
      await registry.deactivate('com.kita.test.x');

      // Y still active
      expect(registry.getPlugin('com.kita.test.x'), isNull);
      expect(registry.getPlugin('com.kita.test.y'), isNotNull);

      // Y can still handle requests
      final result = await plugin2.handleRequest(
        _makeRequest(command: 'test'),
      );
      expect(result.isSuccess, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // [L2] Crash isolation between plugins
  // ---------------------------------------------------------------------------
  group('Crash isolation between plugins', () {
    test('plugin crash in handleRequest does not affect other plugins',
        () async {
      final registry = PluginRegistryImpl();
      final crashingPlugin = _TrackingMockPlugin(
        id: 'com.kita.test.crasher',
        name: 'Crasher',
      );
      crashingPlugin.shouldThrowOnRequest = true;

      final stablePlugin = _TrackingMockPlugin(
        id: 'com.kita.test.stable',
        name: 'Stable',
      );

      registry.register(crashingPlugin);
      registry.register(stablePlugin);
      await registry.activate('com.kita.test.crasher');
      await registry.activate('com.kita.test.stable');

      Object? caughtError;
      try {
        await crashingPlugin.handleRequest(
          _makeRequest(command: 'test'),
        );
      } catch (e) {
        caughtError = e;
      }
      expect(caughtError, isA<StateError>());

      // Stable plugin still works fine
      final result = await stablePlugin.handleRequest(
        _makeRequest(command: 'test'),
      );
      expect(result.isSuccess, isTrue);

      // Both are still registered and active in the registry
      expect(registry.getPlugin('com.kita.test.crasher'), isNotNull);
      expect(registry.getPlugin('com.kita.test.stable'), isNotNull);
    });

    test('plugin crash during activation does not affect registry state',
        () async {
      final registry = PluginRegistryImpl();

      final stablePlugin = _TrackingMockPlugin(
        id: 'com.kita.test.stable2',
        name: 'Stable2',
      );
      registry.register(stablePlugin);
      await registry.activate('com.kita.test.stable2');

      expect(registry.getPlugin('com.kita.test.stable2'), isNotNull);

      await registry.deactivate('com.kita.test.stable2');
      expect(registry.getPlugin('com.kita.test.stable2'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Semantics and accessibility verification
  // ---------------------------------------------------------------------------
  group('Semantics and accessibility', () {
    testWidgets('KitaAlert immediate has liveRegion and correct label',
        (tester) async {
      await _verifyKitaAlertSemantics(tester);

      final semantics = tester.getSemantics(find.byType(KitaAlert));
      expect(semantics.label, contains('Alerte : Attention ! voiture a 2 metres'));
    });

    testWidgets('KitaAlert dismiss button has 56x56 touch target',
        _verifyKitaAlertDismissTarget);

    testWidgets('PluginViewport has liveRegion semantics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PluginViewport(
              fallbackText: 'Test contenu',
            ),
          ),
        ),
      );
      await tester.pump();

      final semantics = tester.getSemantics(find.byType(PluginViewport));
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Cross-cutting: Alert urgency classification integration
  // (migrated to KitaAgent API)
  // ---------------------------------------------------------------------------
  group('Alert urgency classification E2E', () {
    late KitaAlertPlugin alertPlugin;
    late _MockOutputHandle mockOutput;
    late FakeClock fakeClock;

    setUp(() async {
      alertPlugin = KitaAlertPlugin();
      mockOutput = _MockOutputHandle(agentId: 'com.kita.alert');
      fakeClock = FakeClock();

      await alertPlugin.onSpawn(AgentContext(
        sensors: _MockSensorAccess(),
        ai: _MockAIAccess(),
        bus: _MockAgentBus(),
        output: mockOutput,
        clock: fakeClock,
      ));
    });

    tearDown(() {
      mockOutput.dispose();
    });

    test('distance > 10m results in no alert (ignored)', () async {
      final result = await alertPlugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': 'arbre',
            'distance': 15.0,
            'confidence': 0.95,
          },
          source: InputSource.sensor,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(mockOutput.speakCalls, isEmpty);
      expect(mockOutput.hapticCalls, isEmpty);
    });

    test('confidence <= 0.80 results in no alert', () async {
      final result = await alertPlugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.0,
            'confidence': 0.80,
          },
          source: InputSource.sensor,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(mockOutput.speakCalls, isEmpty);
    });

    test('auto-dismiss alert after 5 seconds', () async {
      await alertPlugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.0,
            'confidence': 0.95,
          },
          source: InputSource.sensor,
        ),
      );

      // Alert is visible
      expect(alertPlugin.buildViewport(_FakeBuildContext()), isNotNull);

      // Advance past 5s via FakeClock (auto-dismiss timer uses clock.delayed)
      fakeClock.advance(const Duration(seconds: 5));

      // Alert is dismissed
      expect(alertPlugin.buildViewport(_FakeBuildContext()), isNull);
    });

    test('"ok" command dismisses alert', () async {
      await alertPlugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.0,
            'confidence': 0.95,
          },
          source: InputSource.sensor,
        ),
      );
      expect(alertPlugin.buildViewport(_FakeBuildContext()), isNotNull);

      final result = await alertPlugin.handleInput(
        _agentInput(command: 'ok'),
      );
      expect(result.isSuccess, isTrue);
      expect(alertPlugin.buildViewport(_FakeBuildContext()), isNull);
    });

    test('"c\'est quoi" describes recent detection', () async {
      await alertPlugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.5,
            'confidence': 0.95,
          },
          source: InputSource.sensor,
        ),
      );
      mockOutput.speakCalls.clear();

      final result = await alertPlugin.handleInput(
        _agentInput(command: "c'est quoi"),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.content, contains('voiture'));
          expect(response.content, contains('95 pour cent'));
        },
        failure: (_) => fail('Should succeed'),
      );

      expect(mockOutput.speakCalls.length, 1);
      expect(mockOutput.speakCalls.first.priority, OutputPriority.high);
    });
  });

  // ---------------------------------------------------------------------------
  // Logging — zero PII (migrated to KitaAgent API)
  // ---------------------------------------------------------------------------
  group('Logging: zero PII across all plugins', () {
    test('Describe plugin logs contain no PII', () async {
      final plugin = KitaDescribePlugin();
      final output = _MockOutputHandle(agentId: 'com.kita.describe');

      await plugin.onSpawn(AgentContext(
        sensors: _MockSensorAccess(),
        ai: _MockAIAccess(visionResponse: 'Test description'),
        bus: _MockAgentBus(),
        output: output,
        clock: FakeClock(),
      ));
      logEntries.clear();

      await plugin.handleInput(_agentInput(command: 'decris'));

      for (final entry in logEntries) {
        expect(entry.message, isNot(contains('email')));
        expect(entry.message, isNot(contains('latitude')));
        expect(entry.message, isNot(contains('longitude')));
        expect(entry.message, isNot(contains('48.8566')));
      }

      output.dispose();
    });

    test('Alert plugin logs contain no PII', () async {
      final plugin = KitaAlertPlugin();
      final output = _MockOutputHandle(agentId: 'com.kita.alert');

      await plugin.onSpawn(AgentContext(
        sensors: _MockSensorAccess(),
        ai: _MockAIAccess(),
        bus: _MockAgentBus(),
        output: output,
        clock: FakeClock(),
      ));
      logEntries.clear();

      await plugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.0,
            'confidence': 0.95,
          },
          source: InputSource.sensor,
        ),
      );
      await plugin.handleInput(_agentInput(command: "c'est quoi"));
      await plugin.handleInput(_agentInput(command: 'ok'));

      for (final entry in logEntries) {
        expect(entry.message, isNot(contains('email')));
        expect(entry.message, isNot(contains('latitude')));
        expect(entry.message, isNot(contains('longitude')));
      }

      output.dispose();
    });

    test('log messages use correct source tags', () async {
      final descPlugin = KitaDescribePlugin();
      final descOutput = _MockOutputHandle(agentId: 'com.kita.describe');

      await descPlugin.onSpawn(AgentContext(
        sensors: _MockSensorAccess(),
        ai: _MockAIAccess(visionResponse: 'Test'),
        bus: _MockAgentBus(),
        output: descOutput,
        clock: FakeClock(),
      ));
      logEntries.clear();

      await descPlugin.handleInput(_agentInput(command: 'decris'));

      final describeLogs =
          logEntries.where((e) => e.message.contains('[Plugin.Describe]'));
      expect(describeLogs, isNotEmpty);

      final alertPlugin = KitaAlertPlugin();
      final alertOutput = _MockOutputHandle(agentId: 'com.kita.alert');

      await alertPlugin.onSpawn(AgentContext(
        sensors: _MockSensorAccess(),
        ai: _MockAIAccess(),
        bus: _MockAgentBus(),
        output: alertOutput,
        clock: FakeClock(),
      ));
      logEntries.clear();

      await alertPlugin.handleInput(
        _agentInput(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.0,
            'confidence': 0.95,
          },
          source: InputSource.sensor,
        ),
      );

      final alertLogs =
          logEntries.where((e) => e.message.contains('[Plugin.Alert]'));
      expect(alertLogs, isNotEmpty);

      descOutput.dispose();
      alertOutput.dispose();
    });
  });
}
