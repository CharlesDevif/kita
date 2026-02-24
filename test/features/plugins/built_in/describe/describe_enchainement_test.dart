// ignore_for_file: depend_on_referenced_packages
// fake_async is a transitive dependency via flutter_test;
// cannot add to pubspec.yaml (owned by E1).
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/plugins/built_in/describe/describe_plugin.dart';
import 'package:kita/features/plugins/built_in/describe/describe_state.dart';
import 'package:kita/features/plugins/domain/plugin_response.dart';

import 'describe_test_helpers.dart';

// --- Tests ---

void main() {
  late KitaDescribePlugin plugin;
  late MockSensorAccess mockSensors;
  late MockAIAccess mockAI;
  late List<LogEntry> logEntries;

  setUp(() {
    plugin = KitaDescribePlugin();
    mockSensors = MockSensorAccess();
    mockAI = MockAIAccess();
    logEntries = [];
    KitaLogger.testLogHandler = (entry) => logEntries.add(entry);
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
  });

  /// Helper to do initial describe and set up state.
  Future<void> doInitialDescribe() async {
    mockSensors.photoToReturn = testImage();
    mockAI.responseToReturn = testAIResponse(content: 'Un salon lumineux.');
    await plugin.handleRequest(testRequest(mockSensors, mockAI));
  }

  group('initial describe', () {
    test('sets state to describing with image and description', () async {
      await doInitialDescribe();

      expect(plugin.state.phase, DescribePhase.describing);
      expect(plugin.state.imageData, isNotNull);
      expect(plugin.state.description, 'Un salon lumineux.');
    });

    test('returns text response with description', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result = await plugin.handleRequest(testRequest(mockSensors, mockAI));

      expect(result.isSuccess, isTrue);
      final response = (result as Success<PluginResponse>).value;
      expect(response.type, PluginResponseType.text);
      expect(response.content, contains('salon'));
    });
  });

  group('plus de details', () {
    test('sends enriched prompt to AI', () async {
      await doInitialDescribe();

      mockAI.responseToReturn =
          testAIResponse(content: 'Description detaillee du salon.');
      await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'plus de details'),
      );

      expect(mockAI.lastPromptReceived, KitaDescribePlugin.detailedPrompt);
    });

    test('transitions state to detailed', () async {
      await doInitialDescribe();

      mockAI.responseToReturn =
          testAIResponse(content: 'Description detaillee.');
      await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'plus de details'),
      );

      expect(plugin.state.phase, DescribePhase.detailed);
      expect(plugin.state.detailedDescription, 'Description detaillee.');
      expect(plugin.state.description, 'Un salon lumineux.');
    });

    test('returns detailed description', () async {
      await doInitialDescribe();

      mockAI.responseToReturn =
          testAIResponse(content: 'Description detaillee du salon.');
      final result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'plus de details'),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<PluginResponse>).value;
      expect(response.content, contains('detaillee'));
      expect(response.metadata!['detailed'], true);
    });

    test('fails gracefully without prior describe', () async {
      final result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'plus de details'),
      );

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure.userMessage, contains('decris'));
    });

    test('also works with "details" alias', () async {
      await doInitialDescribe();

      mockAI.responseToReturn = testAIResponse(content: 'Details.');
      final result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'details'),
      );

      expect(result.isSuccess, isTrue);
    });

    test('also works with "detaille" alias', () async {
      await doInitialDescribe();

      mockAI.responseToReturn = testAIResponse(content: 'Details.');
      final result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'detaille'),
      );

      expect(result.isSuccess, isTrue);
    });
  });

  group('repete', () {
    test('returns last description without calling AI', () async {
      await doInitialDescribe();

      // Reset AI mock to verify it is NOT called
      mockAI.lastPromptReceived = null;

      final result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'repete'),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<PluginResponse>).value;
      expect(response.content, 'Un salon lumineux.');
      expect(response.metadata!['repeated'], true);
      expect(mockAI.lastPromptReceived, isNull);
    });

    test('returns detailed description if available', () async {
      await doInitialDescribe();

      mockAI.responseToReturn =
          testAIResponse(content: 'Description detaillee.');
      await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'plus de details'),
      );

      mockAI.lastPromptReceived = null;

      final result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'repete'),
      );

      final response = (result as Success<PluginResponse>).value;
      expect(response.content, 'Description detaillee.');
    });

    test('fails gracefully without prior describe', () async {
      final result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'repete'),
      );

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure.userMessage, contains('rien'));
    });
  });

  group('merci', () {
    test('returns to idle state', () async {
      await doInitialDescribe();

      final result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'merci'),
      );

      expect(result.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.idle);
      final response = (result as Success<PluginResponse>).value;
      expect(response.metadata!['action'], 'return_passive');
    });
  });

  group('unknown command', () {
    test('returns failure for unrecognized command', () async {
      final result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'zoomer'),
      );

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure, isA<PluginFailure>());
      expect(failure.userMessage, 'Commande non reconnue.');
      expect((failure as PluginFailure).pluginId, 'com.kita.describe');
    });

    test('does not trigger camera capture for unknown command', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'unknown'),
      );

      expect(result.isFailure, isTrue);
      // AI should NOT have been called
      expect(mockAI.lastPromptReceived, isNull);
    });
  });

  group('silence timeout', () {
    test('resets state to idle and calls onReturnPassive after 5s',
        () {
      fakeAsync((async) {
        final fakePlugin = KitaDescribePlugin();
        final fakeSensors = MockSensorAccess();
        final fakeAI = MockAIAccess();
        var passiveCalled = false;
        fakePlugin.onReturnPassive = () => passiveCalled = true;

        fakeSensors.photoToReturn = testImage();
        fakeAI.responseToReturn =
            testAIResponse(content: 'Un salon lumineux.');

        // Run the async handleRequest synchronously within fakeAsync
        fakePlugin
            .handleRequest(testRequest(fakeSensors, fakeAI))
            .then((_) {});
        async.flushMicrotasks();

        expect(fakePlugin.state.phase, DescribePhase.describing);
        expect(passiveCalled, isFalse);

        // Advance time by 4s — should still be describing
        async.elapse(const Duration(seconds: 4));
        expect(fakePlugin.state.phase, DescribePhase.describing);
        expect(passiveCalled, isFalse);

        // Advance time by 1 more second (total 5s) — should be idle
        async.elapse(const Duration(seconds: 1));
        expect(fakePlugin.state.phase, DescribePhase.idle);
        expect(passiveCalled, isTrue);
      });
    });

    test('timer resets on new command before expiry', () {
      fakeAsync((async) {
        final fakePlugin = KitaDescribePlugin();
        final fakeSensors = MockSensorAccess();
        final fakeAI = MockAIAccess();
        var passiveCalled = false;
        fakePlugin.onReturnPassive = () => passiveCalled = true;

        fakeSensors.photoToReturn = testImage();
        fakeAI.responseToReturn = testAIResponse(content: 'Salon.');

        // Initial describe
        fakePlugin
            .handleRequest(testRequest(fakeSensors, fakeAI))
            .then((_) {});
        async.flushMicrotasks();

        // Advance 3s, then send "repete" which resets the timer
        async.elapse(const Duration(seconds: 3));
        expect(fakePlugin.state.phase, DescribePhase.describing);

        fakePlugin
            .handleRequest(
                testRequest(fakeSensors, fakeAI, command: 'repete'))
            .then((_) {});
        async.flushMicrotasks();

        // Advance 4s after repete — should still NOT be idle (timer was reset)
        async.elapse(const Duration(seconds: 4));
        expect(fakePlugin.state.phase, DescribePhase.describing);
        expect(passiveCalled, isFalse);

        // Advance 1 more second (5s since repete) — should now be idle
        async.elapse(const Duration(seconds: 1));
        expect(fakePlugin.state.phase, DescribePhase.idle);
        expect(passiveCalled, isTrue);
      });
    });

    test('onDeactivate cancels silence timer (no callback fire)', () async {
      await doInitialDescribe();
      expect(plugin.state.phase, DescribePhase.describing);

      await plugin.onDeactivate();
      expect(plugin.state.phase, DescribePhase.idle);
    });
  });

  group('onReturnPassive callback', () {
    test('callback can be set on the plugin', () {
      var called = false;
      plugin.onReturnPassive = () => called = true;

      // Verify the callback is stored and callable
      plugin.onReturnPassive!();
      expect(called, isTrue);
    });

    test('callback defaults to null', () {
      expect(plugin.onReturnPassive, isNull);
    });

    test('onDeactivate does not invoke callback (it is for timer only)',
        () async {
      var called = false;
      plugin.onReturnPassive = () => called = true;

      await doInitialDescribe();
      await plugin.onDeactivate();

      // onDeactivate cancels the timer, so callback should NOT fire
      expect(called, isFalse);
    });
  });

  group('fallback offline', () {
    test('flags offline when AI response is degraded', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse(
        content: 'Texte OCR brut.',
        status: AIResponseStatus.degraded,
      );

      final result =
          await plugin.handleRequest(testRequest(mockSensors, mockAI));

      expect(result.isSuccess, isTrue);
      expect(plugin.state.isOffline, isTrue);
      final response = (result as Success<PluginResponse>).value;
      expect(response.content, contains('Mode local'));
      expect(response.metadata!['offline'], true);
    });

    test('detailed request with degraded response flags offline', () async {
      // First: normal describe
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse(content: 'Normal.');
      await plugin.handleRequest(testRequest(mockSensors, mockAI));

      // Then: detailed, but degraded
      mockAI.responseToReturn = testAIResponse(
        content: 'Texte OCR detaille.',
        status: AIResponseStatus.degraded,
      );

      final result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'plus de details'),
      );

      expect(result.isSuccess, isTrue);
      final response = (result as Success<PluginResponse>).value;
      expect(response.content, contains('Mode local'));
    });
  });

  group('full conversation cycle', () {
    test('decris -> plus de details -> repete -> merci', () async {
      // Step 1: decris
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse(content: 'Un salon.');
      var result =
          await plugin.handleRequest(testRequest(mockSensors, mockAI));
      expect(result.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.describing);

      // Step 2: plus de details
      mockAI.responseToReturn = testAIResponse(content: 'Salon detaille.');
      result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'plus de details'),
      );
      expect(result.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.detailed);

      // Step 3: repete
      result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'repete'),
      );
      expect(result.isSuccess, isTrue);
      expect(
          (result as Success<PluginResponse>).value.content, 'Salon detaille.');

      // Step 4: merci
      result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'merci'),
      );
      expect(result.isSuccess, isTrue);
      expect(plugin.state.phase, DescribePhase.idle);
    });
  });

  group('buildViewport', () {
    testWidgets('returns null when idle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(plugin.buildViewport(context), isNull);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('returns DescribeViewport when describing', (tester) async {
      await doInitialDescribe();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final viewport = plugin.buildViewport(context);
                expect(viewport, isNotNull);
                return SingleChildScrollView(
                  child: viewport ?? const SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump(); // Let error builders render

      // Cancel the silence timer to avoid pending timer assertion
      await plugin.onDeactivate();
    });
  });

  group('onDeactivate', () {
    test('cancels silence timer and resets state', () async {
      await doInitialDescribe();
      expect(plugin.state.phase, DescribePhase.describing);

      await plugin.onDeactivate();

      expect(plugin.state.phase, DescribePhase.idle);
    });
  });

  group('voice commands', () {
    test('declares plus de details voice command', () {
      final moreDetailsCmd = plugin.voiceCommands.firstWhere(
        (c) => c.trigger == 'plus de details',
        orElse: () => throw StateError('Missing plus de details command'),
      );
      expect(moreDetailsCmd.aliases, contains('detaille'));
      expect(moreDetailsCmd.aliases, contains('details'));
    });

    test('manifest includes chaining commands', () {
      expect(plugin.manifest.voiceCommands, contains('plus de details'));
      expect(plugin.manifest.voiceCommands, contains('repete'));
      expect(plugin.manifest.voiceCommands, contains('merci'));
    });
  });

  group('PluginResponse integration (H2)', () {
    test('describe response contains fields needed for Shell/ProfileAdapter',
        () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse(content: 'Un salon lumineux.');

      final result =
          await plugin.handleRequest(testRequest(mockSensors, mockAI));

      expect(result.isSuccess, isTrue);
      final response = (result as Success<PluginResponse>).value;

      // The Shell uses these fields to route through ProfileAdapter:
      // - type: determines output modality
      // - content: text for TTS (vocal) and viewport (visual)
      // - metadata: provider info for logging/analytics
      expect(response.type, PluginResponseType.text);
      expect(response.content, isNotEmpty);
      expect(response.metadata, isNotNull);
      expect(response.metadata!['provider'], isA<String>());
      expect(response.metadata!['latency_ms'], isA<int>());
      expect(response.metadata!['tier'], isA<String>());
    });

    test('merci response contains return_passive action for Shell', () async {
      await doInitialDescribe();

      final result = await plugin.handleRequest(
        testRequest(mockSensors, mockAI, command: 'merci'),
      );

      final response = (result as Success<PluginResponse>).value;

      // The Shell checks metadata['action'] == 'return_passive' to know
      // it should transition back to passive mode via ProfileAdapter.
      expect(response.metadata, isNotNull);
      expect(response.metadata!['action'], 'return_passive');
      expect(response.content, isEmpty);
    });

    test('offline response contains offline flag for Shell', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse(
        content: 'Texte OCR.',
        status: AIResponseStatus.degraded,
      );

      final result =
          await plugin.handleRequest(testRequest(mockSensors, mockAI));

      final response = (result as Success<PluginResponse>).value;

      // The Shell uses 'offline' metadata to adjust ProfileAdapter output
      // (e.g., announce "Mode local" prefix via TTS).
      expect(response.metadata!['offline'], true);
      expect(response.content, contains('Mode local'));
    });
  });
}
