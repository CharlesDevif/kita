import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/io/domain/tts_service.dart';
import 'package:kita/features/plugins/domain/ai_access.dart';
import 'package:kita/features/plugins/domain/plugin_request.dart';
import 'package:kita/features/plugins/domain/plugin_response.dart';
import 'package:kita/features/plugins/domain/sensor_access.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';
import 'package:kita/features/plugins/built_in/alert/kita_alert_plugin.dart';
import 'package:kita/shared/multi_modal/profile_adapter.dart'
    hide VoidCallback;

// === Manual Mocks ===

class MockTTSService implements TTSService {
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

class MockHapticService implements HapticService {
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

class MockProfileAdapter implements ProfileAdapter {
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
    // Execute all callbacks in standard profile
    visual?.call();
    vocal?.call();
    haptic?.call();
  }
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

PluginRequest _makeRequest({
  String command = 'obstacle_detected',
  Map<String, dynamic> params = const {},
}) {
  return PluginRequest(
    command: command,
    params: params,
    sensors: StubSensorAccess(),
    ai: StubAIAccess(),
  );
}

PluginRequest _obstacleRequest({
  String type = 'voiture',
  double distance = 2.0,
  double confidence = 0.95,
}) {
  return _makeRequest(
    command: 'obstacle_detected',
    params: {
      'type': type,
      'distance': distance,
      'confidence': confidence,
    },
  );
}

void main() {
  late MockTTSService mockTts;
  late MockHapticService mockHaptic;
  late MockProfileAdapter mockProfileAdapter;
  late KitaAlertPlugin plugin;
  late List<LogEntry> logEntries;

  setUp(() {
    mockTts = MockTTSService();
    mockHaptic = MockHapticService();
    mockProfileAdapter = MockProfileAdapter();
    plugin = KitaAlertPlugin(
      ttsService: mockTts,
      hapticService: mockHaptic,
      profileAdapter: mockProfileAdapter,
    );
    logEntries = [];
    KitaLogger.testLogHandler = (entry) => logEntries.add(entry);
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
  });

  group('manifest', () {
    test('has correct id', () {
      expect(plugin.manifest.id, 'com.kita.alert');
    });

    test('has correct permissions', () {
      expect(plugin.manifest.permissions, containsAll(['camera', 'haptic', 'tts']));
    });

    test('has official trust level', () {
      expect(plugin.manifest.trustLevel, TrustLevel.official);
    });

    test('has voice commands', () {
      expect(plugin.manifest.voiceCommands, containsAll(['ok', "c'est quoi"]));
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
    test('onActivate enables the plugin', () async {
      await plugin.onActivate();
      final result = await plugin.handleRequest(_makeRequest(command: 'ok'));
      expect(result.isSuccess, isTrue);
    });

    test('handleRequest fails when not activated', () async {
      final result = await plugin.handleRequest(_makeRequest(command: 'ok'));
      expect(result.isFailure, isTrue);
    });

    test('onDeactivate dismisses active alert', () async {
      await plugin.onActivate();
      await plugin.handleRequest(_obstacleRequest());
      await plugin.onDeactivate();

      // buildViewport should return null after deactivation
      final viewport = plugin.buildViewport(
        _FakeBuildContext(),
      );
      expect(viewport, isNull);
    });
  });

  group('handleRequest obstacle_detected', () {
    setUp(() async {
      await plugin.onActivate();
    });

    test('immediate alert (< 3m) triggers danger haptic and critical TTS', () async {
      final result = await plugin.handleRequest(
        _obstacleRequest(type: 'voiture', distance: 2.0, confidence: 0.95),
      );

      expect(result.isSuccess, isTrue);

      // ProfileAdapter was called
      expect(mockProfileAdapter.feedbackCalls.length, 1);

      // TTS with critical priority
      expect(mockTts.speakCalls.length, 1);
      expect(mockTts.speakCalls.first.text, contains('Attention'));
      expect(mockTts.speakCalls.first.text, contains('voiture'));
      expect(mockTts.speakCalls.first.text, contains('2 metres'));
      expect(mockTts.speakCalls.first.priority, TTSPriority.critical);

      // Haptic danger
      expect(mockHaptic.dangerCalls, 1);
    });

    test('preventive alert (3-10m) triggers warning haptic and urgent TTS',
        () async {
      final result = await plugin.handleRequest(
        _obstacleRequest(type: 'travaux', distance: 8.0, confidence: 0.88),
      );

      expect(result.isSuccess, isTrue);

      // TTS with urgent priority
      expect(mockTts.speakCalls.length, 1);
      expect(mockTts.speakCalls.first.text, isNot(contains('Attention')));
      expect(mockTts.speakCalls.first.text, contains('travaux'));
      expect(mockTts.speakCalls.first.text, contains('8 metres'));
      expect(mockTts.speakCalls.first.priority, TTSPriority.urgent);

      // Haptic warning
      expect(mockHaptic.warningCalls, 1);
    });

    test('distance > 10m is ignored (no alert)', () async {
      final result = await plugin.handleRequest(
        _obstacleRequest(distance: 15.0),
      );

      expect(result.isSuccess, isTrue);
      expect(mockProfileAdapter.feedbackCalls, isEmpty);
      expect(mockTts.speakCalls, isEmpty);
    });

    test('confidence <= 0.80 is ignored', () async {
      final result = await plugin.handleRequest(
        _obstacleRequest(confidence: 0.80),
      );

      expect(result.isSuccess, isTrue);
      expect(mockProfileAdapter.feedbackCalls, isEmpty);
    });

    test('confidence just above 0.80 triggers alert', () async {
      final result = await plugin.handleRequest(
        _obstacleRequest(confidence: 0.81),
      );

      expect(result.isSuccess, isTrue);
      expect(mockProfileAdapter.feedbackCalls.length, 1);
    });

    test('response type is alert', () async {
      final result = await plugin.handleRequest(_obstacleRequest());

      result.when(
        success: (response) {
          expect(response.type, PluginResponseType.alert);
          expect(response.content, contains('voiture'));
          expect(response.metadata, isNotNull);
          expect(response.metadata!['urgency'], 'immediate');
        },
        failure: (_) => fail('Should succeed'),
      );
    });

    test('stops TTS before speaking new alert', () async {
      await plugin.handleRequest(_obstacleRequest());

      expect(mockTts.stopCalls, 1);
    });
  });

  group('auto-dismiss', () {
    setUp(() async {
      await plugin.onActivate();
    });

    test('alert dismissed after 5 seconds', () {
      FakeAsync().run((async) {
        plugin.onActivate();
        async.flushMicrotasks();

        plugin.handleRequest(_obstacleRequest());
        async.flushMicrotasks();

        // Alert is visible
        expect(plugin.buildViewport(_FakeBuildContext()), isNotNull);

        // Advance past 5s
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Alert is dismissed
        expect(plugin.buildViewport(_FakeBuildContext()), isNull);
      });
    });

    test('new alert resets timer', () {
      FakeAsync().run((async) {
        plugin.onActivate();
        async.flushMicrotasks();

        plugin.handleRequest(_obstacleRequest());
        async.flushMicrotasks();

        // Advance 3s
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(plugin.buildViewport(_FakeBuildContext()), isNotNull);

        // New alert
        plugin.handleRequest(_obstacleRequest(distance: 1.0));
        async.flushMicrotasks();

        // Advance 3 more seconds (6s total from first, 3 from second)
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        // Still visible (second timer hasn't expired)
        expect(plugin.buildViewport(_FakeBuildContext()), isNotNull);

        // Advance past 5s from second alert
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(plugin.buildViewport(_FakeBuildContext()), isNull);
      });
    });
  });

  group('dismiss by ok command', () {
    setUp(() async {
      await plugin.onActivate();
    });

    test('ok command dismisses alert', () async {
      await plugin.handleRequest(_obstacleRequest());
      expect(plugin.buildViewport(_FakeBuildContext()), isNotNull);

      final result = await plugin.handleRequest(
        _makeRequest(command: 'ok'),
      );

      expect(result.isSuccess, isTrue);
      expect(plugin.buildViewport(_FakeBuildContext()), isNull);
    });

    test('dismiss command also works', () async {
      await plugin.handleRequest(_obstacleRequest());
      final result = await plugin.handleRequest(
        _makeRequest(command: 'dismiss'),
      );

      expect(result.isSuccess, isTrue);
      expect(plugin.buildViewport(_FakeBuildContext()), isNull);
    });
  });

  group('c est quoi', () {
    setUp(() async {
      await plugin.onActivate();
    });

    test('describes recent detection', () async {
      await plugin.handleRequest(
        _obstacleRequest(type: 'voiture', distance: 2.5, confidence: 0.95),
      );
      mockTts.speakCalls.clear();

      final result = await plugin.handleRequest(
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

      // TTS was called with description
      expect(mockTts.speakCalls.length, 1);
      expect(mockTts.speakCalls.first.priority, TTSPriority.urgent);
    });

    test('describes via ProfileAdapter (not direct TTS)', () async {
      await plugin.handleRequest(_obstacleRequest());
      final feedbackCountAfterAlert = mockProfileAdapter.feedbackCalls.length;
      mockTts.speakCalls.clear();

      await plugin.handleRequest(
        _makeRequest(command: "c'est quoi"),
      );

      // ProfileAdapter.feedback must have been called again for the description
      expect(
        mockProfileAdapter.feedbackCalls.length,
        feedbackCountAfterAlert + 1,
      );

      // TTS was invoked through the vocal callback
      expect(mockTts.speakCalls.length, 1);
    });

    test('reports no obstacle when no recent detection', () async {
      final result = await plugin.handleRequest(
        _makeRequest(command: "c'est quoi"),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.content, contains('Aucun obstacle'));
        },
        failure: (_) => fail('Should succeed'),
      );
    });

    test('no-obstacle response goes via ProfileAdapter', () async {
      final feedbackCountBefore = mockProfileAdapter.feedbackCalls.length;

      await plugin.handleRequest(
        _makeRequest(command: "c'est quoi"),
      );

      // ProfileAdapter.feedback was called for the "no obstacle" message
      expect(
        mockProfileAdapter.feedbackCalls.length,
        feedbackCountBefore + 1,
      );

      // TTS was invoked through the vocal callback
      expect(mockTts.speakCalls.length, 1);
      expect(mockTts.speakCalls.first.text, contains('Aucun obstacle'));
    });

    test('description expires after 10-second window', () async {
      // Use injectable clock for time control
      var fakeTime = DateTime(2026, 1, 1, 12, 0, 0);
      final timedPlugin = KitaAlertPlugin(
        ttsService: mockTts,
        hapticService: mockHaptic,
        profileAdapter: mockProfileAdapter,
        now: () => fakeTime,
      );
      await timedPlugin.onActivate();

      // 1. Trigger a detection at t=0
      await timedPlugin.handleRequest(
        _obstacleRequest(type: 'voiture', distance: 2.0, confidence: 0.95),
      );
      mockTts.speakCalls.clear();

      // 2. Immediately ask "c'est quoi" — should return description
      final result1 = await timedPlugin.handleRequest(
        _makeRequest(command: 'describe_obstacle'),
      );
      expect(result1.isSuccess, isTrue);
      result1.when(
        success: (response) {
          expect(response.content, contains('voiture'));
        },
        failure: (_) => fail('Should succeed'),
      );
      expect(mockTts.speakCalls.length, 1);
      expect(mockTts.speakCalls.first.text, contains('voiture'));
      mockTts.speakCalls.clear();

      // 3. Advance past the 10-second window
      fakeTime = fakeTime.add(const Duration(seconds: 11));

      // 4. Ask again — should return "Aucun obstacle recent"
      final result2 = await timedPlugin.handleRequest(
        _makeRequest(command: 'describe_obstacle'),
      );
      expect(result2.isSuccess, isTrue);
      result2.when(
        success: (response) {
          expect(response.content, contains('Aucun obstacle'));
        },
        failure: (_) => fail('Should succeed'),
      );
      expect(mockTts.speakCalls.length, 1);
      expect(mockTts.speakCalls.first.text, contains('Aucun obstacle'));
    });

    test('describe_obstacle alias also works', () async {
      await plugin.handleRequest(_obstacleRequest());
      mockTts.speakCalls.clear();

      final result = await plugin.handleRequest(
        _makeRequest(command: 'describe_obstacle'),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.content, contains('voiture'));
        },
        failure: (_) => fail('Should succeed'),
      );
    });
  });

  group('buildViewport', () {
    setUp(() async {
      await plugin.onActivate();
    });

    test('returns null when no active alert', () {
      expect(plugin.buildViewport(_FakeBuildContext()), isNull);
    });

    test('returns KitaAlert when alert is active', () async {
      await plugin.handleRequest(_obstacleRequest());
      final viewport = plugin.buildViewport(_FakeBuildContext());
      expect(viewport, isNotNull);
    });
  });

  group('race conditions', () {
    setUp(() async {
      await plugin.onActivate();
    });

    test('preventive ignored while immediate is active', () async {
      // Trigger immediate alert
      await plugin.handleRequest(
        _obstacleRequest(distance: 1.0, confidence: 0.95),
      );

      // Try preventive — should be ignored
      final result = await plugin.handleRequest(
        _obstacleRequest(distance: 5.0, confidence: 0.90),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.content, contains('Alerte immediate en cours'));
        },
        failure: (_) => fail('Should succeed'),
      );

      // Only one ProfileAdapter call (the first)
      expect(mockProfileAdapter.feedbackCalls.length, 1);
    });

    test('new immediate replaces old immediate', () async {
      await plugin.handleRequest(
        _obstacleRequest(type: 'personne', distance: 2.0),
      );
      await plugin.handleRequest(
        _obstacleRequest(type: 'voiture', distance: 1.0),
      );

      // Two ProfileAdapter calls
      expect(mockProfileAdapter.feedbackCalls.length, 2);

      // Second TTS message should be about voiture
      expect(mockTts.speakCalls.last.text, contains('voiture'));
    });
  });

  group('unknown command', () {
    setUp(() async {
      await plugin.onActivate();
    });

    test('returns failure for unknown command', () async {
      final result = await plugin.handleRequest(
        _makeRequest(command: 'unknown_command'),
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
      await plugin.onActivate();
    });

    test('logs do not contain PII', () async {
      await plugin.handleRequest(_obstacleRequest());
      await plugin.handleRequest(_makeRequest(command: "c'est quoi"));
      await plugin.handleRequest(_makeRequest(command: 'ok'));

      for (final entry in logEntries) {
        expect(entry.message, isNot(contains('email')));
        expect(entry.message, isNot(contains('latitude')));
        expect(entry.message, isNot(contains('longitude')));
      }
    });

    test('log messages use [Plugin.Alert] source', () async {
      await plugin.handleRequest(_obstacleRequest());

      final alertLogs =
          logEntries.where((e) => e.message.contains('[Plugin.Alert]'));
      expect(alertLogs, isNotEmpty);
    });
  });
}

/// Minimal fake BuildContext for testing buildViewport.
class _FakeBuildContext extends Fake implements BuildContext {}
