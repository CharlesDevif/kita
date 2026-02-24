import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/plugins/built_in/describe/describe_plugin.dart';
import 'package:kita/features/plugins/domain/plugin_response.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';

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

    test('declares voice commands in manifest', () {
      expect(
        plugin.manifest.voiceCommands,
        containsAll(['decris', 'describe']),
      );
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

  group('handleRequest', () {
    test('returns text description on full success', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result =
          await plugin.handleRequest(testRequest(mockSensors, mockAI));

      expect(result.isSuccess, isTrue);
      final response = (result as Success<PluginResponse>).value;
      expect(response.type, PluginResponseType.text);
      expect(response.content, contains('salon'));
    });

    test('response metadata contains provider info', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result =
          await plugin.handleRequest(testRequest(mockSensors, mockAI));
      final response = (result as Success<PluginResponse>).value;

      expect(response.metadata, isNotNull);
      expect(response.metadata!['provider'], 'claude');
      expect(response.metadata!['latency_ms'], 2500);
      expect(response.metadata!['tier'], 'cloudPowerful');
    });

    test('sends describe prompt to AI vision', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      await plugin.handleRequest(testRequest(mockSensors, mockAI));

      expect(mockAI.lastPromptReceived, KitaDescribePlugin.describePrompt);
    });

    test('returns failure on camera error', () async {
      mockSensors.failureToReturn = PermissionFailure.denied('camera');

      final result =
          await plugin.handleRequest(testRequest(mockSensors, mockAI));

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

      final result =
          await plugin.handleRequest(testRequest(mockSensors, mockAI));

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure, isA<PluginFailure>());
    });

    test('continues with original image when EXIF strip fails', () async {
      // ExifStripper.strip will fail on our minimal JPEG bytes since they
      // can't be decoded as a real image, but the plugin should gracefully
      // degrade and use the original image.
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result =
          await plugin.handleRequest(testRequest(mockSensors, mockAI));

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

      await plugin.handleRequest(testRequest(mockSensors, mockAI));

      final messages = logEntries.map((e) => e.message).toList();
      expect(messages, contains(contains('Handling command')));
      expect(messages, contains(contains('Photo captured')));
      expect(messages, contains(contains('Description received')));
    });

    test('plugin logs contain [Plugin.Describe] source', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      await plugin.handleRequest(testRequest(mockSensors, mockAI));

      // Filter to only plugin logs (ExifStripper logs with [IO] source)
      final pluginLogs = logEntries
          .where((e) => e.message.startsWith('[Plugin.Describe]'))
          .toList();
      expect(pluginLogs, isNotEmpty);
      expect(pluginLogs.length, greaterThanOrEqualTo(3));
    });

    test('camera failure userMessage is in French', () async {
      mockSensors.failureToReturn = PermissionFailure.denied('camera');

      final result =
          await plugin.handleRequest(testRequest(mockSensors, mockAI));
      final failure = (result as Failure).failure;

      expect(failure.userMessage, 'Impossible de prendre la photo.');
    });

    test('AI failure userMessage is in French', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.failureToReturn = const NetworkFailure(
        userMessage: 'Timeout',
        logMessage: 'AI request timed out',
      );

      final result =
          await plugin.handleRequest(testRequest(mockSensors, mockAI));
      final failure = (result as Failure).failure;

      expect(failure.userMessage, "Je n'ai pas pu analyser l'image.");
    });
  });

  group('lifecycle', () {
    test('onActivate completes without error', () async {
      await expectLater(plugin.onActivate(), completes);
    });

    test('onDeactivate completes without error', () async {
      await expectLater(plugin.onDeactivate(), completes);
    });

    test('onActivate logs activation', () async {
      await plugin.onActivate();

      final messages = logEntries.map((e) => e.message).toList();
      expect(messages, contains(contains('Describe plugin activated')));
    });

    test('onDeactivate logs deactivation', () async {
      await plugin.onDeactivate();

      final messages = logEntries.map((e) => e.message).toList();
      expect(messages, contains(contains('Describe plugin deactivated')));
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
