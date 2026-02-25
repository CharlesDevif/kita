import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/onboarding/data/pack_installer.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';

void main() {
  group('PackInstaller', () {
    late PackInstaller installer;

    setUp(() {
      installer = PackInstaller();
    });

    test('blind profile returns Describe + Alert', () {
      final pack = installer.getPackForProfile(AccessibilityProfile.blind);
      expect(pack.agentIds, contains('com.kita.describe'));
      expect(pack.agentIds, contains('com.kita.alert'));
      expect(pack.agentIds, hasLength(2));
    });

    test('lowVision profile returns Describe + Alert', () {
      final pack = installer.getPackForProfile(AccessibilityProfile.lowVision);
      expect(pack.agentIds, contains('com.kita.describe'));
      expect(pack.agentIds, contains('com.kita.alert'));
      expect(pack.agentIds, hasLength(2));
    });

    test('general profile returns Describe only', () {
      final pack = installer.getPackForProfile(AccessibilityProfile.general);
      expect(pack.agentIds, contains('com.kita.describe'));
      expect(pack.agentIds, hasLength(1));
    });

    test('installPack returns success with correct pack', () async {
      final result =
          await installer.installPack(AccessibilityProfile.blind);
      expect(result.isSuccess, isTrue);
      final pack = (result as Success<PackConfig>).value;
      expect(pack.agentIds, contains('com.kita.describe'));
      expect(pack.agentIds, contains('com.kita.alert'));
    });

    test('installPack calls onSavePack callback', () async {
      List<String>? savedIds;
      final installer = PackInstaller(
        onSavePack: (ids) async {
          savedIds = ids;
          return const Result.success(null);
        },
      );

      await installer.installPack(AccessibilityProfile.blind);
      expect(savedIds, isNotNull);
      expect(savedIds, contains('com.kita.describe'));
      expect(savedIds, contains('com.kita.alert'));
    });

    test('installPack propagates save failure', () async {
      final installer = PackInstaller(
        onSavePack: (ids) async {
          return const Result.failure(
            UnexpectedFailure(logMessage: 'save failed'),
          );
        },
      );

      final result =
          await installer.installPack(AccessibilityProfile.blind);
      expect(result.isFailure, isTrue);
    });
  });

  group('defaultPacks', () {
    test('covers all AccessibilityProfile values', () {
      for (final profile in AccessibilityProfile.values) {
        expect(defaultPacks[profile], isNotNull,
            reason: 'Missing pack for $profile');
      }
    });

    test('all packs have non-empty agentIds', () {
      for (final entry in defaultPacks.entries) {
        expect(entry.value.agentIds, isNotEmpty,
            reason: 'Empty agentIds for ${entry.key}');
      }
    });

    test('all packs have non-empty description', () {
      for (final entry in defaultPacks.entries) {
        expect(entry.value.description, isNotEmpty,
            reason: 'Empty description for ${entry.key}');
      }
    });
  });
}
