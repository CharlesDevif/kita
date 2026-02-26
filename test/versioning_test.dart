import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pubspec.yaml versioning', () {
    late String pubspecContent;

    setUpAll(() {
      final file = File('pubspec.yaml');
      pubspecContent = file.readAsStringSync();
    });

    test('version field exists in pubspec.yaml', () {
      expect(pubspecContent, contains('version:'));
    });

    test('version follows semver pattern (major.minor.patch+build)', () {
      // Pattern: 1.0.0+1 or 1.0.0-beta.1+1 (pre-release allowed)
      final versionRegex = RegExp(
        r'^version:\s+(\d+)\.(\d+)\.(\d+)(?:-[a-zA-Z0-9.]+)?\+(\d+)',
        multiLine: true,
      );
      expect(
        versionRegex.hasMatch(pubspecContent),
        isTrue,
        reason:
            'version must follow semver pattern major.minor.patch+build '
            '(e.g. 1.0.0+1 or 1.0.0-beta.1+1)',
      );
    });

    test('version is 1.0.0-beta.1+1 for initial beta', () {
      expect(pubspecContent, contains('version: 1.0.0-beta.1+1'));
    });

    test('version major number is >= 1 (no 0.x.x in stores)', () {
      final versionRegex = RegExp(
        r'^version:\s+(\d+)\.',
        multiLine: true,
      );
      final match = versionRegex.firstMatch(pubspecContent);
      expect(match, isNotNull, reason: 'Could not find version field');
      final major = int.parse(match!.group(1)!);
      expect(major, greaterThanOrEqualTo(1));
    });

    test('build number is a positive integer', () {
      final buildRegex = RegExp(
        r'\+(\d+)\s*$',
        multiLine: true,
      );
      final match = buildRegex.firstMatch(pubspecContent);
      expect(match, isNotNull, reason: 'Could not find build number after +');
      final buildNumber = int.parse(match!.group(1)!);
      expect(buildNumber, greaterThan(0));
    });
  });
}
