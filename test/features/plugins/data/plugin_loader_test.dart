import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/plugins/data/plugin_loader.dart';
import 'package:kita/features/plugins/domain/plugin_manifest.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';

void main() {
  const loader = PluginLoader();

  const validYaml = '''
id: com.kita.describe
name: Kita Describe
version: 1.0.0
description: Scene description plugin
trust_level: official
permissions:
  - camera
  - ai.vision
capabilities:
  - vision
  - text
compatible_profiles:
  - blind
  - low_vision
voice_commands:
  - decris
  - describe
''';

  group('PluginLoader.loadManifest', () {
    group('valid manifests', () {
      test('parses a full valid manifest', () {
        final result = loader.loadManifest(validYaml);

        expect(result.isSuccess, isTrue);
        final manifest = (result as Success<PluginManifest>).value;
        expect(manifest.id, equals('com.kita.describe'));
        expect(manifest.name, equals('Kita Describe'));
        expect(manifest.version, equals('1.0.0'));
        expect(manifest.description, equals('Scene description plugin'));
        expect(manifest.trustLevel, equals(TrustLevel.official));
        expect(manifest.permissions, equals(['camera', 'ai.vision']));
        expect(manifest.capabilities, equals(['vision', 'text']));
        expect(manifest.compatibleProfiles, equals(['blind', 'low_vision']));
        expect(manifest.voiceCommands, equals(['decris', 'describe']));
      });

      test('parses manifest with only required fields', () {
        const yaml = '''
id: com.kita.alert
name: Kita Alert
version: 2.0.0
description: Obstacle detection
trust_level: community_verified
''';
        final result = loader.loadManifest(yaml);

        expect(result.isSuccess, isTrue);
        final manifest = (result as Success<PluginManifest>).value;
        expect(manifest.id, equals('com.kita.alert'));
        expect(manifest.trustLevel, equals(TrustLevel.communityVerified));
        expect(manifest.permissions, isEmpty);
        expect(manifest.capabilities, isEmpty);
        expect(manifest.compatibleProfiles, isEmpty);
        expect(manifest.voiceCommands, isEmpty);
      });

      test('parses unverified trust level', () {
        const yaml = '''
id: org.community.test.plugin
name: Test Plugin
version: 0.1.0
description: A test plugin
trust_level: unverified
''';
        final result = loader.loadManifest(yaml);

        expect(result.isSuccess, isTrue);
        final manifest = (result as Success<PluginManifest>).value;
        expect(manifest.trustLevel, equals(TrustLevel.unverified));
      });

      test('parses manifest with empty optional lists', () {
        const yaml = '''
id: com.kita.minimal
name: Minimal
version: 1.0.0
description: Minimal plugin
trust_level: official
permissions: []
capabilities: []
''';
        final result = loader.loadManifest(yaml);

        expect(result.isSuccess, isTrue);
        final manifest = (result as Success<PluginManifest>).value;
        expect(manifest.permissions, isEmpty);
        expect(manifest.capabilities, isEmpty);
      });
    });

    group('invalid YAML', () {
      test('fails on malformed YAML', () {
        const yaml = '{{{{not: valid: yaml:::';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure, isA<PluginFailure>());
        expect(failure.logMessage, contains('YAML parse error'));
      });

      test('fails on empty string', () {
        final result = loader.loadManifest('');

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure, isA<PluginFailure>());
      });

      test('fails on YAML that is not a map', () {
        const yaml = '- just\n- a\n- list';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure, isA<PluginFailure>());
        expect(failure.logMessage, contains('not a map'));
      });

      test('fails on scalar YAML', () {
        const yaml = 'just a string';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
      });
    });

    group('missing required fields', () {
      test('fails when id is missing', () {
        const yaml = '''
name: Test
version: 1.0.0
description: Test
trust_level: official
''';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure.logMessage, contains('id'));
      });

      test('fails when multiple required fields are missing', () {
        const yaml = '''
id: com.kita.test
''';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure.logMessage, contains('name'));
        expect(failure.logMessage, contains('version'));
        expect(failure.logMessage, contains('description'));
        expect(failure.logMessage, contains('trust_level'));
      });

      test('fails when trust_level is missing', () {
        const yaml = '''
id: com.kita.test
name: Test
version: 1.0.0
description: Test
''';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure.logMessage, contains('trust_level'));
      });
    });

    group('invalid field values', () {
      test('fails on invalid id format (no dots)', () {
        const yaml = '''
id: nodots
name: Test
version: 1.0.0
description: Test
trust_level: official
''';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure.logMessage, contains('Invalid plugin id'));
      });

      test('fails on id with only one dot', () {
        const yaml = '''
id: com.test
name: Test
version: 1.0.0
description: Test
trust_level: official
''';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
      });

      test('fails on id starting with uppercase', () {
        const yaml = '''
id: Com.kita.test
name: Test
version: 1.0.0
description: Test
trust_level: official
''';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
      });

      test('fails on invalid version format', () {
        const yaml = '''
id: com.kita.test
name: Test
version: not-a-version
description: Test
trust_level: official
''';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure.logMessage, contains('Invalid version'));
      });

      test('fails on invalid trust_level', () {
        const yaml = '''
id: com.kita.test
name: Test
version: 1.0.0
description: Test
trust_level: super_trusted
''';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure.logMessage, contains('Invalid trust_level'));
        expect(failure.logMessage, contains('official'));
      });

      test('fails on empty name', () {
        const yaml = '''
id: com.kita.test
name: ""
version: 1.0.0
description: Test
trust_level: official
''';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure.logMessage, contains('name'));
      });

      test('fails on empty description', () {
        const yaml = '''
id: com.kita.test
name: Test
version: 1.0.0
description: ""
trust_level: official
''';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure.logMessage, contains('description'));
      });
    });

    group('invalid list fields', () {
      test('fails when permissions is not a list', () {
        const yaml = '''
id: com.kita.test
name: Test
version: 1.0.0
description: Test
trust_level: official
permissions: not_a_list
''';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure.logMessage, contains('permissions'));
        expect(failure.logMessage, contains('must be a list'));
      });

      test('fails when permissions list contains non-string', () {
        const yaml = '''
id: com.kita.test
name: Test
version: 1.0.0
description: Test
trust_level: official
permissions:
  - camera
  - 42
''';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure.logMessage, contains('permissions'));
        expect(failure.logMessage, contains('only strings'));
      });

      test('fails when capabilities contains non-string', () {
        const yaml = '''
id: com.kita.test
name: Test
version: 1.0.0
description: Test
trust_level: official
capabilities:
  - true
''';
        final result = loader.loadManifest(yaml);

        expect(result.isFailure, isTrue);
        final failure = (result as Failure).failure;
        expect(failure.logMessage, contains('capabilities'));
      });
    });

    group('PluginFailure details', () {
      test('failures include pluginId when available', () {
        const yaml = '''
id: com.kita.test
name: Test
version: bad
description: Test
trust_level: official
''';
        final result = loader.loadManifest(yaml);
        final failure = (result as Failure).failure as PluginFailure;
        expect(failure.pluginId, equals('com.kita.test'));
      });

      test('failures have user-friendly userMessage', () {
        const yaml = 'not: valid: manifest';
        final result = loader.loadManifest(yaml);
        final failure = (result as Failure).failure;
        expect(failure.userMessage, isNotEmpty);
      });
    });

    group('integration — real YAML scenarios', () {
      test('parses describe plugin manifest', () {
        const yaml = '''
id: com.kita.describe
name: Kita Describe
version: 1.0.0
description: Capture et description vocale de scenes pour utilisateurs aveugles
trust_level: official
permissions:
  - camera
  - ai.vision
  - ai.text
capabilities:
  - vision
  - text
compatible_profiles:
  - blind
  - low_vision
voice_commands:
  - decris
  - describe
  - "qu'est-ce que tu vois"
''';
        final result = loader.loadManifest(yaml);
        expect(result.isSuccess, isTrue);
        final manifest = (result as Success<PluginManifest>).value;
        expect(manifest.id, equals('com.kita.describe'));
        expect(manifest.permissions, contains('camera'));
        expect(manifest.voiceCommands, hasLength(3));
      });

      test('parses alert plugin manifest', () {
        const yaml = '''
id: com.kita.alert
name: Kita Alert
version: 1.0.0
description: Detection d'obstacles en temps reel via camera et modele YOLO
trust_level: official
permissions:
  - camera
  - haptic
capabilities:
  - obstacle_detection
compatible_profiles:
  - blind
  - low_vision
  - cognitive
voice_commands:
  - alerte
  - obstacles
''';
        final result = loader.loadManifest(yaml);
        expect(result.isSuccess, isTrue);
        final manifest = (result as Success<PluginManifest>).value;
        expect(manifest.id, equals('com.kita.alert'));
        expect(manifest.trustLevel, equals(TrustLevel.official));
      });

      test('parses third-party community plugin manifest', () {
        const yaml = '''
id: org.example.myreader
name: My Screen Reader Helper
version: 0.3.1
description: A community screen reader helper
trust_level: community_verified
permissions:
  - ai.text
capabilities:
  - text
compatible_profiles:
  - blind
voice_commands:
  - lis
  - read
''';
        final result = loader.loadManifest(yaml);
        expect(result.isSuccess, isTrue);
        final manifest = (result as Success<PluginManifest>).value;
        expect(manifest.trustLevel, equals(TrustLevel.communityVerified));
      });
    });
  });
}
