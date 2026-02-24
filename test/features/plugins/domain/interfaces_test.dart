import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/plugins/domain/plugin_manifest.dart';
import 'package:kita/features/plugins/domain/plugin_response.dart';
import 'package:kita/features/plugins/domain/plugin_sandbox.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';
import 'package:kita/features/plugins/domain/voice_command.dart';

import '../../../mocks/mocks.dart';

void main() {
  group('Plugins domain interfaces', () {
    test('TrustLevel has 3 values', () {
      expect(TrustLevel.values, hasLength(3));
    });

    test('PluginResponseType has 4 values', () {
      expect(PluginResponseType.values, hasLength(4));
    });

    test('VoiceCommand holds trigger and aliases', () {
      const cmd = VoiceCommand(
        trigger: 'decris',
        description: 'Describe a scene',
        aliases: ['describe', 'what do you see'],
      );
      expect(cmd.trigger, equals('decris'));
      expect(cmd.aliases, hasLength(2));
    });

    test('PluginManifest holds all fields', () {
      const manifest = PluginManifest(
        id: 'com.kita.describe',
        name: 'Kita Describe',
        version: '1.0.0',
        description: 'Scene description',
        trustLevel: TrustLevel.official,
        permissions: ['camera', 'ai.vision'],
        voiceCommands: ['decris'],
      );
      expect(manifest.id, equals('com.kita.describe'));
      expect(manifest.trustLevel, equals(TrustLevel.official));
      expect(manifest.permissions, hasLength(2));
    });

    test('PluginResponse holds content and type', () {
      const response = PluginResponse(
        type: PluginResponseType.text,
        content: 'A beautiful park',
      );
      expect(response.type, equals(PluginResponseType.text));
      expect(response.viewport, isNull);
    });

    test('MockPluginSandbox implements PluginSandbox', () {
      final sandbox = MockPluginSandbox();
      expect(sandbox, isA<PluginSandbox>());
    });
  });
}
