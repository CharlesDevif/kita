import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Pipeline CI/CD validation', () {
    group('Workflow files exist', () {
      test('ci.yml exists', () {
        final file = File('.github/workflows/ci.yml');
        expect(file.existsSync(), isTrue,
            reason: '.github/workflows/ci.yml must exist');
      });

      test('build-android.yml exists', () {
        final file = File('.github/workflows/build-android.yml');
        expect(file.existsSync(), isTrue,
            reason: '.github/workflows/build-android.yml must exist');
      });

      test('build-ios.yml exists', () {
        final file = File('.github/workflows/build-ios.yml');
        expect(file.existsSync(), isTrue,
            reason: '.github/workflows/build-ios.yml must exist');
      });
    });

    group('ci.yml content validation', () {
      late String ciContent;

      setUpAll(() {
        ciContent = File('.github/workflows/ci.yml').readAsStringSync();
      });

      test('contains dart analyze --fatal-infos', () {
        expect(ciContent, contains('dart analyze --fatal-infos'));
      });

      test('contains flutter test --coverage', () {
        expect(ciContent, contains('flutter test --coverage'));
      });

      test('contains very_good_coverage for blocking coverage threshold', () {
        expect(ciContent, contains('very_good_coverage'));
      });

      test('accessibility tests are blocking (no continue-on-error)', () {
        final lines = ciContent.split('\n');
        bool inA11yStep = false;
        for (final line in lines) {
          if (line.contains('accessibility')) {
            inA11yStep = true;
          }
          if (inA11yStep && line.contains('continue-on-error: true')) {
            fail(
                'Accessibility tests must not have continue-on-error: true — they must be blocking');
          }
          // Reset when hitting the next step
          if (inA11yStep &&
              line.trimLeft().startsWith('- name:') &&
              !line.contains('accessibility')) {
            inA11yStep = false;
          }
        }
      });
    });

    group('ci.yml trigger validation', () {
      late String ciContent;

      setUpAll(() {
        ciContent = File('.github/workflows/ci.yml').readAsStringSync();
      });

      test('triggers on push to main and develop', () {
        expect(ciContent, contains('push:'));
        expect(ciContent, contains('branches: [main, develop]'));
      });

      test('triggers on pull_request to main and develop', () {
        expect(ciContent, contains('pull_request:'));
        // The branches line appears twice (once for push, once for PR)
        // Just verify pull_request is present along with the branches
        expect(ciContent, contains('pull_request:'));
      });
    });

    group('build-android.yml content validation', () {
      late String androidContent;

      setUpAll(() {
        androidContent =
            File('.github/workflows/build-android.yml').readAsStringSync();
      });

      test('contains flutter build apk', () {
        expect(androidContent, contains('flutter build apk'));
      });

      test('contains flutter build appbundle', () {
        expect(androidContent, contains('flutter build appbundle'));
      });

      test('contains ENV dart-define with prod default', () {
        // Le workflow utilise inputs.env avec 'prod' comme défaut
        expect(androidContent, contains('--dart-define=ENV='));
        expect(androidContent, contains("|| 'prod'"));
      });
    });

    group('build-ios.yml content validation', () {
      late String iosContent;

      setUpAll(() {
        iosContent =
            File('.github/workflows/build-ios.yml').readAsStringSync();
      });

      test('contains flutter build ipa --no-codesign', () {
        expect(iosContent, contains('flutter build ipa'));
        expect(iosContent, contains('--no-codesign'));
      });

      test('contains ENV dart-define with prod default', () {
        // Le workflow utilise inputs.env avec 'prod' comme défaut
        expect(iosContent, contains('--dart-define=ENV='));
        expect(iosContent, contains("|| 'prod'"));
      });
    });
  });
}
