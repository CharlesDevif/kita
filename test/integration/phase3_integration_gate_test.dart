import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/io/domain/location_service.dart';
import 'package:kita/features/io/domain/motion_service.dart';
import 'package:kita/features/io/domain/tts_service.dart';
import 'package:kita/features/plugins/built_in/alert/kita_alert_plugin.dart';
import 'package:kita/features/plugins/built_in/describe/describe_plugin.dart';
import 'package:kita/features/plugins/built_in/describe/describe_state.dart';
import 'package:kita/features/plugins/data/plugin_registry.dart';
import 'package:kita/features/plugins/domain/ai_access.dart';
import 'package:kita/features/plugins/domain/plugin_request.dart';
import 'package:kita/features/plugins/domain/plugin_response.dart';
import 'package:kita/features/plugins/domain/sensor_access.dart';
import 'package:kita/features/shell/domain/orb_state.dart';
import 'package:kita/features/shell/presentation/kita_shell.dart';
import 'package:kita/features/shell/presentation/plugin_viewport.dart';
import 'package:kita/shared/multi_modal/profile_adapter.dart' hide VoidCallback;
import 'package:kita/shared/widgets/kita_alert.dart';

// =============================================================================
// Mock implementations for Phase 3 integration testing
// =============================================================================

/// Mock SensorAccess — returns synthetic JPEG for capturePhoto.
class _MockSensorAccess implements SensorAccess {
  bool capturePhotoCalled = false;

  /// Minimal valid JPEG: SOI marker + APP0 header + EOI marker.
  static final _fakeJpeg = Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, //
    0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
  ]);

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

/// Mock TTSService — records all speak calls.
class _MockTTSService implements TTSService {
  final List<({String text, TTSPriority priority})> speakCalls = [];
  int stopCalls = 0;

  @override
  bool get isSpeaking => false;

  @override
  Future<Result<void>> speak(
    String text, {
    TTSPriority priority = TTSPriority.standard,
  }) async {
    speakCalls.add((text: text, priority: priority));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async {
    stopCalls++;
    return const Result.success(null);
  }
}

/// Mock HapticService — records all patterns.
class _MockHapticService implements HapticService {
  int dangerCalls = 0;
  int warningCalls = 0;
  int infoCalls = 0;
  final List<HapticPattern> triggerCalls = [];

  @override
  Future<Result<void>> trigger(HapticPattern pattern) async {
    triggerCalls.add(pattern);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> info() async {
    infoCalls++;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> warning() async {
    warningCalls++;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> danger() async {
    dangerCalls++;
    return const Result.success(null);
  }
}

/// Mock ProfileAdapter — executes all callbacks (standard profile).
class _MockProfileAdapter implements ProfileAdapter {
  final List<({VoidCallback? visual, VoidCallback? vocal, VoidCallback? haptic})>
      feedbackCalls = [];

  @override
  String get activeProfile => 'standard';

  @override
  void feedback({
    VoidCallback? visual,
    VoidCallback? vocal,
    VoidCallback? haptic,
  }) {
    feedbackCalls.add((visual: visual, vocal: vocal, haptic: haptic));
    visual?.call();
    vocal?.call();
    haptic?.call();
  }
}

// Helpers

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

/// Minimal fake BuildContext for buildViewport calls.
class _FakeBuildContext extends Fake implements BuildContext {}

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
  // AC-1 : Test flow Describe E2E
  // ---------------------------------------------------------------------------
  group('AC-1: Describe flow E2E', () {
    late KitaDescribePlugin describePlugin;
    late _MockSensorAccess sensors;
    late _MockAIAccess ai;

    setUp(() {
      describePlugin = KitaDescribePlugin();
      sensors = _MockSensorAccess();
      ai = _MockAIAccess(
        visionResponse: 'Un parc avec des arbres et un banc devant vous',
      );
    });

    test('"decris" triggers full pipeline: capture -> EXIF strip -> AI vision -> response',
        () async {
      await describePlugin.onActivate();

      final result = await describePlugin.handleRequest(
        _makeRequest(
          command: 'decris',
          sensors: sensors,
          ai: ai,
        ),
      );

      // Photo was captured
      expect(sensors.capturePhotoCalled, isTrue);

      // AI vision was called
      expect(ai.visionCalls, 1);

      // Prompt sent is the concise describe prompt
      expect(ai.promptsReceived.first, contains('Decris cette image'));

      // Result is success with text response
      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.type, PluginResponseType.text);
          expect(response.content, contains('parc'));
          expect(response.content, contains('arbres'));
          expect(response.metadata, isNotNull);
          expect(response.metadata!['provider'], 'mock-cloud');
        },
        failure: (_) => fail('Should succeed'),
      );
    });

    test('describe plugin state transitions to describing after "decris"',
        () async {
      await describePlugin.onActivate();

      await describePlugin.handleRequest(
        _makeRequest(command: 'decris', sensors: sensors, ai: ai),
      );

      expect(describePlugin.state.phase, DescribePhase.describing);
      expect(describePlugin.state.imageData, isNotNull);
      expect(describePlugin.state.description, isNotNull);
    });

    test('"decris" response metadata includes provider and latency', () async {
      await describePlugin.onActivate();

      final result = await describePlugin.handleRequest(
        _makeRequest(command: 'decris', sensors: sensors, ai: ai),
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
  // AC-2 : Test flow Alert E2E
  // ---------------------------------------------------------------------------
  group('AC-2: Alert flow E2E', () {
    late KitaAlertPlugin alertPlugin;
    late _MockTTSService tts;
    late _MockHapticService haptic;
    late _MockProfileAdapter profile;

    setUp(() {
      tts = _MockTTSService();
      haptic = _MockHapticService();
      profile = _MockProfileAdapter();
      alertPlugin = KitaAlertPlugin(
        ttsService: tts,
        hapticService: haptic,
        profileAdapter: profile,
      );
    });

    test('immediate obstacle (< 3m) triggers danger haptic + critical TTS + KitaAlert',
        () async {
      await alertPlugin.onActivate();

      final result = await alertPlugin.handleRequest(
        _makeRequest(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.0,
            'confidence': 0.95,
          },
        ),
      );

      expect(result.isSuccess, isTrue);

      // ProfileAdapter.feedback was called
      expect(profile.feedbackCalls.length, 1);

      // TTS with critical priority and "Attention !"
      expect(tts.speakCalls.length, 1);
      expect(tts.speakCalls.first.text, contains('Attention'));
      expect(tts.speakCalls.first.text, contains('voiture'));
      expect(tts.speakCalls.first.text, contains('2 metres'));
      expect(tts.speakCalls.first.priority, TTSPriority.critical);

      // Haptic danger
      expect(haptic.dangerCalls, 1);

      // Response type is alert with urgency metadata
      result.when(
        success: (response) {
          expect(response.type, PluginResponseType.alert);
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

    test('preventive obstacle (3-10m) triggers warning haptic + urgent TTS',
        () async {
      await alertPlugin.onActivate();

      final result = await alertPlugin.handleRequest(
        _makeRequest(
          command: 'obstacle_detected',
          params: {
            'type': 'travaux',
            'distance': 8.0,
            'confidence': 0.88,
          },
        ),
      );

      expect(result.isSuccess, isTrue);

      // TTS with urgent priority, no "Attention"
      expect(tts.speakCalls.length, 1);
      expect(tts.speakCalls.first.text, isNot(contains('Attention')));
      expect(tts.speakCalls.first.text, contains('travaux'));
      expect(tts.speakCalls.first.text, contains('8 metres'));
      expect(tts.speakCalls.first.priority, TTSPriority.urgent);

      // Haptic warning
      expect(haptic.warningCalls, 1);

      // Response metadata
      result.when(
        success: (response) {
          expect(response.type, PluginResponseType.alert);
          expect(response.metadata!['urgency'], 'preventive');
        },
        failure: (_) => fail('Should succeed'),
      );
    });

    testWidgets('KitaAlert Semantics has liveRegion', (tester) async {
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

      // Find Semantics with liveRegion
      final semantics = tester.getSemantics(find.byType(KitaAlert));
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
      expect(semantics.label, contains('Alerte'));
    });
  });

  // ---------------------------------------------------------------------------
  // AC-3 : Test fallback Describe offline
  // ---------------------------------------------------------------------------
  group('AC-3: Describe fallback offline', () {
    test('AI vision fails -> returns failure (Describe delegates fallback to AI layer)',
        () async {
      final plugin = KitaDescribePlugin();
      await plugin.onActivate();

      final failingAi = _MockAIAccess(shouldFailVision: true);

      final result = await plugin.handleRequest(
        _makeRequest(
          command: 'decris',
          sensors: _MockSensorAccess(),
          ai: failingAi,
        ),
      );

      // Photo was captured
      expect(failingAi.visionCalls, 1);

      // AI failure propagates as plugin failure
      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Should fail'),
        failure: (failure) {
          expect(failure, isA<PluginFailure>());
        },
      );
    });

    test('AI returns degraded response -> content prefixed with "Mode local"',
        () async {
      final plugin = KitaDescribePlugin();
      await plugin.onActivate();

      final offlineAi = _MockAIAccess(
        visionResponse: 'Texte detecte : Sortie de secours',
        offlineMode: true,
      );

      final result = await plugin.handleRequest(
        _makeRequest(
          command: 'decris',
          sensors: _MockSensorAccess(),
          ai: offlineAi,
        ),
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
    });
  });

  // ---------------------------------------------------------------------------
  // AC-4 : Test enchainement naturel
  // ---------------------------------------------------------------------------
  group('AC-4: Natural chaining flow', () {
    late KitaDescribePlugin plugin;
    late _MockSensorAccess sensors;
    late _MockAIAccess ai;

    setUp(() async {
      plugin = KitaDescribePlugin();
      sensors = _MockSensorAccess();
      ai = _MockAIAccess(
        visionResponse: 'Un parc avec des arbres',
      );
      await plugin.onActivate();
    });

    test('"decris" -> description initiale', () async {
      final result = await plugin.handleRequest(
        _makeRequest(command: 'decris', sensors: sensors, ai: ai),
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
      await plugin.handleRequest(
        _makeRequest(command: 'decris', sensors: sensors, ai: ai),
      );

      // Change AI response for the detailed version
      final detailedAi = _MockAIAccess(
        visionResponse: 'Un parc verdoyant avec 3 grands chenes et un banc en bois',
      );

      // Request more details
      final result = await plugin.handleRequest(
        _makeRequest(
          command: 'plus de details',
          sensors: sensors,
          ai: detailedAi,
        ),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.content, contains('chenes'));
          expect(response.metadata!['detailed'], isTrue);
        },
        failure: (_) => fail('Should succeed'),
      );

      // AI vision was called with the detailed prompt
      expect(detailedAi.promptsReceived.first, contains('detail'));

      // State transitioned to detailed
      expect(plugin.state.phase, DescribePhase.detailed);
    });

    test('"repete" -> re-reads last description without new AI call', () async {
      // Describe first
      await plugin.handleRequest(
        _makeRequest(command: 'decris', sensors: sensors, ai: ai),
      );

      final initialVisionCalls = ai.visionCalls;

      // Repeat
      final result = await plugin.handleRequest(
        _makeRequest(command: 'repete', sensors: sensors, ai: ai),
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
      await plugin.handleRequest(
        _makeRequest(command: 'decris', sensors: sensors, ai: ai),
      );

      final result = await plugin.handleRequest(
        _makeRequest(command: 'merci', sensors: sensors, ai: ai),
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
    });

    test('full chain: decris -> plus de details -> repete -> merci', () async {
      // 1. decris
      final descResult = await plugin.handleRequest(
        _makeRequest(command: 'decris', sensors: sensors, ai: ai),
      );
      expect(descResult.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.describing);

      // 2. plus de details
      final detailedAi = _MockAIAccess(
        visionResponse: 'Description enrichie avec beaucoup de details',
      );
      final detailResult = await plugin.handleRequest(
        _makeRequest(
          command: 'plus de details',
          sensors: sensors,
          ai: detailedAi,
        ),
      );
      expect(detailResult.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.detailed);

      // 3. repete — should repeat the detailed description
      final repeatResult = await plugin.handleRequest(
        _makeRequest(command: 'repete', sensors: sensors, ai: ai),
      );
      expect(repeatResult.isSuccess, isTrue);
      repeatResult.when(
        success: (response) {
          expect(response.content, contains('enrichie'));
        },
        failure: (_) => fail('Should succeed'),
      );

      // 4. merci
      final merciResult = await plugin.handleRequest(
        _makeRequest(command: 'merci', sensors: sensors, ai: ai),
      );
      expect(merciResult.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.idle);
    });

    test('silence timeout auto-returns to passive', () {
      FakeAsync().run((async) {
        plugin.onActivate();
        async.flushMicrotasks();

        plugin.handleRequest(
          _makeRequest(command: 'decris', sensors: sensors, ai: ai),
        );
        async.flushMicrotasks();

        expect(plugin.state.phase, DescribePhase.describing);

        // Advance past silence timeout (5s)
        async.elapse(const Duration(seconds: 6));
        async.flushMicrotasks();

        expect(plugin.state.phase, DescribePhase.idle);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // AC-5 : Two plugins loaded simultaneously
  // ---------------------------------------------------------------------------
  group('AC-5: Two plugins simultaneously', () {
    late PluginRegistryImpl registry;
    late KitaDescribePlugin describePlugin;
    late KitaAlertPlugin alertPlugin;
    late _MockTTSService tts;
    late _MockHapticService haptic;
    late _MockProfileAdapter profile;

    setUp(() {
      registry = PluginRegistryImpl();
      describePlugin = KitaDescribePlugin();
      tts = _MockTTSService();
      haptic = _MockHapticService();
      profile = _MockProfileAdapter();
      alertPlugin = KitaAlertPlugin(
        ttsService: tts,
        hapticService: haptic,
        profileAdapter: profile,
      );
    });

    test('both plugins register and activate without conflict', () async {
      final reg1 = registry.register(describePlugin);
      expect(reg1.isSuccess, isTrue);

      final reg2 = registry.register(alertPlugin);
      expect(reg2.isSuccess, isTrue);

      final act1 = await registry.activate('com.kita.describe');
      expect(act1.isSuccess, isTrue);

      final act2 = await registry.activate('com.kita.alert');
      expect(act2.isSuccess, isTrue);

      // Both accessible
      expect(registry.getPlugin('com.kita.describe'), isNotNull);
      expect(registry.getPlugin('com.kita.alert'), isNotNull);
    });

    test('aggregated voice commands contain both plugins triggers', () async {
      registry.register(describePlugin);
      registry.register(alertPlugin);
      await registry.activate('com.kita.describe');
      await registry.activate('com.kita.alert');

      final commands = registry.aggregatedVoiceCommands;

      // Describe has 'decris' and 'plus de details'
      final triggers = commands.map((c) => c.trigger).toList();
      expect(triggers, contains('decris'));
      expect(triggers, contains('plus de details'));

      // Alert has 'ok' and "c'est quoi"
      expect(triggers, contains('ok'));
      expect(triggers, contains("c'est quoi"));
    });

    test('each plugin handles requests independently', () async {
      registry.register(describePlugin);
      registry.register(alertPlugin);
      await registry.activate('com.kita.describe');
      await registry.activate('com.kita.alert');

      final sensors = _MockSensorAccess();
      final ai = _MockAIAccess(
        visionResponse: 'Un trottoir avec des pietons',
      );

      // Describe request
      final descResult = await describePlugin.handleRequest(
        _makeRequest(command: 'decris', sensors: sensors, ai: ai),
      );
      expect(descResult.isSuccess, isTrue);

      // Alert request
      final alertResult = await alertPlugin.handleRequest(
        _makeRequest(
          command: 'obstacle_detected',
          params: {
            'type': 'poteau',
            'distance': 2.0,
            'confidence': 0.95,
          },
        ),
      );
      expect(alertResult.isSuccess, isTrue);

      // Both responded correctly
      descResult.when(
        success: (response) {
          expect(response.type, PluginResponseType.text);
          expect(response.content, contains('trottoir'));
        },
        failure: (_) => fail('Describe should succeed'),
      );

      alertResult.when(
        success: (response) {
          expect(response.type, PluginResponseType.alert);
          expect(response.content, contains('poteau'));
        },
        failure: (_) => fail('Alert should succeed'),
      );
    });

    test('listed plugins shows both with correct state', () async {
      registry.register(describePlugin);
      registry.register(alertPlugin);
      await registry.activate('com.kita.describe');
      await registry.activate('com.kita.alert');

      final plugins = registry.listPlugins();
      expect(plugins.length, 2);

      final ids = plugins.map((e) => e.id).toSet();
      expect(ids, contains('com.kita.describe'));
      expect(ids, contains('com.kita.alert'));
    });

    testWidgets('KitaShell renders without crash with both plugins active',
        (tester) async {
      registry.register(describePlugin);
      registry.register(alertPlugin);
      await registry.activate('com.kita.describe');
      await registry.activate('com.kita.alert');

      // Build shell with a PluginViewport displaying text
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: KitaShell(
              orbState: OrbState.passive,
              viewportChild: PluginViewport(
                fallbackText: 'Deux plugins actifs',
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
      await alertPlugin.onActivate();
      await alertPlugin.handleRequest(
        _makeRequest(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.0,
            'confidence': 0.95,
          },
        ),
      );

      final alertWidget = alertPlugin.buildViewport(_FakeBuildContext());
      expect(alertWidget, isNotNull);

      // KitaAlert uses height: double.infinity which conflicts with
      // PluginViewport's SingleChildScrollView. Wrap in SizedBox to
      // constrain it, simulating a real screen layout.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: KitaShell(
              orbState: OrbState.passive,
              viewportChild: SizedBox(
                height: 400,
                child: alertWidget,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(KitaShell), findsOneWidget);

      // Deactivate plugin to cancel the auto-dismiss Timer
      await alertPlugin.onDeactivate();
    });
  });

  // ---------------------------------------------------------------------------
  // AC-6 : Plugin lifecycle activate/deactivate
  // ---------------------------------------------------------------------------
  group('AC-6: Plugin lifecycle', () {
    late PluginRegistryImpl registry;
    late KitaDescribePlugin describePlugin;
    late KitaAlertPlugin alertPlugin;
    late _MockTTSService tts;
    late _MockHapticService haptic;
    late _MockProfileAdapter profile;

    setUp(() {
      registry = PluginRegistryImpl();
      describePlugin = KitaDescribePlugin();
      tts = _MockTTSService();
      haptic = _MockHapticService();
      profile = _MockProfileAdapter();
      alertPlugin = KitaAlertPlugin(
        ttsService: tts,
        hapticService: haptic,
        profileAdapter: profile,
      );
    });

    test('Describe lifecycle: register -> activate -> request -> deactivate',
        () async {
      // Register
      final regResult = registry.register(describePlugin);
      expect(regResult.isSuccess, isTrue);

      // Activate
      final actResult = await registry.activate('com.kita.describe');
      expect(actResult.isSuccess, isTrue);
      expect(registry.getPlugin('com.kita.describe'), isNotNull);

      // Handle request
      final reqResult = await describePlugin.handleRequest(
        _makeRequest(
          command: 'decris',
          sensors: _MockSensorAccess(),
          ai: _MockAIAccess(visionResponse: 'Test description'),
        ),
      );
      expect(reqResult.isSuccess, isTrue);

      // Deactivate
      final deactResult = await registry.deactivate('com.kita.describe');
      expect(deactResult.isSuccess, isTrue);
      expect(registry.getPlugin('com.kita.describe'), isNull);
    });

    test('Alert lifecycle: register -> activate -> request -> deactivate',
        () async {
      // Register
      final regResult = registry.register(alertPlugin);
      expect(regResult.isSuccess, isTrue);

      // Activate
      final actResult = await registry.activate('com.kita.alert');
      expect(actResult.isSuccess, isTrue);
      expect(registry.getPlugin('com.kita.alert'), isNotNull);

      // Handle request
      final reqResult = await alertPlugin.handleRequest(
        _makeRequest(
          command: 'obstacle_detected',
          params: {
            'type': 'poteau',
            'distance': 5.0,
            'confidence': 0.90,
          },
        ),
      );
      expect(reqResult.isSuccess, isTrue);

      // Deactivate
      final deactResult = await registry.deactivate('com.kita.alert');
      expect(deactResult.isSuccess, isTrue);
      expect(registry.getPlugin('com.kita.alert'), isNull);

      // Alert should be dismissed after deactivation
      expect(alertPlugin.buildViewport(_FakeBuildContext()), isNull);
    });

    test('deactivation then reactivation works correctly', () async {
      registry.register(describePlugin);
      registry.register(alertPlugin);

      // Activate both
      await registry.activate('com.kita.describe');
      await registry.activate('com.kita.alert');
      expect(registry.getPlugin('com.kita.describe'), isNotNull);
      expect(registry.getPlugin('com.kita.alert'), isNotNull);

      // Deactivate both
      await registry.deactivate('com.kita.describe');
      await registry.deactivate('com.kita.alert');
      expect(registry.getPlugin('com.kita.describe'), isNull);
      expect(registry.getPlugin('com.kita.alert'), isNull);

      // Reactivate both
      final reAct1 = await registry.activate('com.kita.describe');
      final reAct2 = await registry.activate('com.kita.alert');
      expect(reAct1.isSuccess, isTrue);
      expect(reAct2.isSuccess, isTrue);
      expect(registry.getPlugin('com.kita.describe'), isNotNull);
      expect(registry.getPlugin('com.kita.alert'), isNotNull);
    });

    test('deactivating one plugin does not affect the other', () async {
      registry.register(describePlugin);
      registry.register(alertPlugin);

      await registry.activate('com.kita.describe');
      await registry.activate('com.kita.alert');

      // Deactivate only Describe
      await registry.deactivate('com.kita.describe');

      // Alert still active
      expect(registry.getPlugin('com.kita.describe'), isNull);
      expect(registry.getPlugin('com.kita.alert'), isNotNull);

      // Alert can still handle requests
      final result = await alertPlugin.handleRequest(
        _makeRequest(
          command: 'obstacle_detected',
          params: {
            'type': 'mur',
            'distance': 1.5,
            'confidence': 0.95,
          },
        ),
      );
      expect(result.isSuccess, isTrue);
    });

    test('aggregated voice commands reflect only active plugins', () async {
      registry.register(describePlugin);
      registry.register(alertPlugin);

      // Only activate Describe
      await registry.activate('com.kita.describe');

      final triggers1 =
          registry.aggregatedVoiceCommands.map((c) => c.trigger).toSet();
      expect(triggers1, contains('decris'));
      expect(triggers1, isNot(contains('ok')));

      // Activate Alert too
      await registry.activate('com.kita.alert');

      final triggers2 =
          registry.aggregatedVoiceCommands.map((c) => c.trigger).toSet();
      expect(triggers2, contains('decris'));
      expect(triggers2, contains('ok'));

      // Deactivate Describe
      await registry.deactivate('com.kita.describe');

      final triggers3 =
          registry.aggregatedVoiceCommands.map((c) => c.trigger).toSet();
      expect(triggers3, isNot(contains('decris')));
      expect(triggers3, contains('ok'));
    });
  });

  // ---------------------------------------------------------------------------
  // Semantics and accessibility verification
  // ---------------------------------------------------------------------------
  group('Semantics and accessibility', () {
    testWidgets('KitaAlert immediate has liveRegion and correct label',
        (tester) async {
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
      expect(semantics.label, contains('Alerte : Attention ! voiture a 2 metres'));
    });

    testWidgets('KitaAlert dismiss button has 56x56 touch target',
        (tester) async {
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

      // Find the SizedBox wrapping the close icon (dismiss button)
      final sizedBoxes = tester.widgetList<SizedBox>(
        find.ancestor(
          of: find.byIcon(Icons.close),
          matching: find.byType(SizedBox),
        ),
      );

      // At least one SizedBox with 56x56 dimensions
      final hasCriticalTarget = sizedBoxes.any(
        (box) => box.width == 56 && box.height == 56,
      );
      expect(hasCriticalTarget, isTrue,
          reason: 'Dismiss button must have >= 56x56 touch target');
    });

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
  // ---------------------------------------------------------------------------
  group('Alert urgency classification E2E', () {
    late KitaAlertPlugin alertPlugin;
    late _MockTTSService tts;
    late _MockHapticService haptic;
    late _MockProfileAdapter profile;

    setUp(() async {
      tts = _MockTTSService();
      haptic = _MockHapticService();
      profile = _MockProfileAdapter();
      alertPlugin = KitaAlertPlugin(
        ttsService: tts,
        hapticService: haptic,
        profileAdapter: profile,
      );
      await alertPlugin.onActivate();
    });

    test('distance > 10m results in no alert (ignored)', () async {
      final result = await alertPlugin.handleRequest(
        _makeRequest(
          command: 'obstacle_detected',
          params: {
            'type': 'arbre',
            'distance': 15.0,
            'confidence': 0.95,
          },
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(profile.feedbackCalls, isEmpty);
      expect(tts.speakCalls, isEmpty);
      expect(haptic.dangerCalls, 0);
      expect(haptic.warningCalls, 0);
    });

    test('confidence <= 0.80 results in no alert', () async {
      final result = await alertPlugin.handleRequest(
        _makeRequest(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.0,
            'confidence': 0.80,
          },
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(profile.feedbackCalls, isEmpty);
    });

    test('auto-dismiss alert after 5 seconds', () {
      FakeAsync().run((async) {
        alertPlugin.onActivate();
        async.flushMicrotasks();

        alertPlugin.handleRequest(
          _makeRequest(
            command: 'obstacle_detected',
            params: {
              'type': 'voiture',
              'distance': 2.0,
              'confidence': 0.95,
            },
          ),
        );
        async.flushMicrotasks();

        // Alert is visible
        expect(alertPlugin.buildViewport(_FakeBuildContext()), isNotNull);

        // Advance past 5s
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Alert is dismissed
        expect(alertPlugin.buildViewport(_FakeBuildContext()), isNull);
      });
    });

    test('"ok" command dismisses alert', () async {
      await alertPlugin.handleRequest(
        _makeRequest(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.0,
            'confidence': 0.95,
          },
        ),
      );
      expect(alertPlugin.buildViewport(_FakeBuildContext()), isNotNull);

      final result = await alertPlugin.handleRequest(
        _makeRequest(command: 'ok'),
      );
      expect(result.isSuccess, isTrue);
      expect(alertPlugin.buildViewport(_FakeBuildContext()), isNull);
    });

    test('"c\'est quoi" describes recent detection', () async {
      await alertPlugin.handleRequest(
        _makeRequest(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.5,
            'confidence': 0.95,
          },
        ),
      );
      tts.speakCalls.clear();

      final result = await alertPlugin.handleRequest(
        _makeRequest(command: "c'est quoi"),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.content, contains('voiture'));
          expect(response.content, contains('95 pour cent'));
        },
        failure: (_) => fail('Should succeed'),
      );

      expect(tts.speakCalls.length, 1);
      expect(tts.speakCalls.first.priority, TTSPriority.urgent);
    });
  });

  // ---------------------------------------------------------------------------
  // Logging — zero PII
  // ---------------------------------------------------------------------------
  group('Logging: zero PII across all plugins', () {
    test('Describe plugin logs contain no PII', () async {
      final plugin = KitaDescribePlugin();
      await plugin.onActivate();
      logEntries.clear();

      await plugin.handleRequest(
        _makeRequest(
          command: 'decris',
          sensors: _MockSensorAccess(),
          ai: _MockAIAccess(visionResponse: 'Test description'),
        ),
      );

      for (final entry in logEntries) {
        expect(entry.message, isNot(contains('email')));
        expect(entry.message, isNot(contains('latitude')));
        expect(entry.message, isNot(contains('longitude')));
        expect(entry.message, isNot(contains('48.8566')));
      }
    });

    test('Alert plugin logs contain no PII', () async {
      final tts = _MockTTSService();
      final haptic = _MockHapticService();
      final profile = _MockProfileAdapter();
      final plugin = KitaAlertPlugin(
        ttsService: tts,
        hapticService: haptic,
        profileAdapter: profile,
      );
      await plugin.onActivate();
      logEntries.clear();

      await plugin.handleRequest(
        _makeRequest(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.0,
            'confidence': 0.95,
          },
        ),
      );
      await plugin.handleRequest(_makeRequest(command: "c'est quoi"));
      await plugin.handleRequest(_makeRequest(command: 'ok'));

      for (final entry in logEntries) {
        expect(entry.message, isNot(contains('email')));
        expect(entry.message, isNot(contains('latitude')));
        expect(entry.message, isNot(contains('longitude')));
      }
    });

    test('log messages use correct source tags', () async {
      final descPlugin = KitaDescribePlugin();
      await descPlugin.onActivate();
      logEntries.clear();

      await descPlugin.handleRequest(
        _makeRequest(
          command: 'decris',
          sensors: _MockSensorAccess(),
          ai: _MockAIAccess(visionResponse: 'Test'),
        ),
      );

      final describeLogs =
          logEntries.where((e) => e.message.contains('[Plugin.Describe]'));
      expect(describeLogs, isNotEmpty);

      final tts = _MockTTSService();
      final haptic = _MockHapticService();
      final profile = _MockProfileAdapter();
      final alertPlugin = KitaAlertPlugin(
        ttsService: tts,
        hapticService: haptic,
        profileAdapter: profile,
      );
      await alertPlugin.onActivate();
      logEntries.clear();

      await alertPlugin.handleRequest(
        _makeRequest(
          command: 'obstacle_detected',
          params: {
            'type': 'voiture',
            'distance': 2.0,
            'confidence': 0.95,
          },
        ),
      );

      final alertLogs =
          logEntries.where((e) => e.message.contains('[Plugin.Alert]'));
      expect(alertLogs, isNotEmpty);
    });
  });
}
