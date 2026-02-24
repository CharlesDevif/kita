import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/memory/domain/consent_entry.dart';
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/domain/forget_request.dart';
import 'package:kita/features/memory/domain/memory_domain.dart';
import 'package:kita/features/memory/domain/memory_vault.dart';
import 'package:kita/features/memory/domain/person.dart';
import 'package:kita/features/memory/domain/user_profile.dart';
import 'package:kita/features/memory/domain/preference.dart';
import 'package:kita/features/memory/domain/plugin_data_entry.dart';

import '../../../mocks/mocks.dart';

void main() {
  group('Memory domain interfaces', () {
    test('MemoryDomain has 4 values', () {
      expect(MemoryDomain.values, hasLength(4));
    });

    test('ForgetScope has 5 values', () {
      expect(ForgetScope.values, hasLength(5));
    });

    test('KitaEpisode holds all fields', () {
      final episode = KitaEpisode(
        id: 1,
        source: 'plugin.describe',
        eventType: 'describe',
        summary: 'A park scene',
        tags: ['outdoor'],
        importanceScore: 0.8,
        isPinned: true,
        createdAt: DateTime(2026, 2, 24),
      );
      expect(episode.id, equals(1));
      expect(episode.domain, equals(MemoryDomain.episodic));
      expect(episode.isPinned, isTrue);
      expect(episode.importanceScore, equals(0.8));
    });

    test('ForgetRequest holds scope and options', () {
      final request = ForgetRequest.domain(
        MemoryDomain.episodic,
        confirmation: true,
      );
      expect(request.scope, equals(ForgetScope.domain));
      expect(request.confirmation, isTrue);
    });

    test('ForgetRequest.plugin holds pluginId', () {
      final request = ForgetRequest.plugin(
        'com.kita.describe',
        confirmation: true,
      );
      expect(request.scope, equals(ForgetScope.plugin));
      expect(request.pluginId, equals('com.kita.describe'));
    });

    test('ConsentEntry holds GDPR fields', () {
      final entry = ConsentEntry(
        id: 1,
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
        grantedAt: DateTime(2026, 2, 24),
        details: 'Store visual descriptions',
      );
      expect(entry.revokedAt, isNull);
      expect(entry.consentType, equals('data_storage'));
    });

    test('KitaPerson holds all fields', () {
      final person = KitaPerson(
        id: 1,
        name: 'Sophie',
        relationship: 'friend',
        interests: ['cooking', 'travel'],
        createdAt: DateTime(2026, 2, 24),
        updatedAt: DateTime(2026, 2, 24),
      );
      expect(person.name, equals('Sophie'));
      expect(person.interests, hasLength(2));
    });

    test('KitaUserProfile holds all fields', () {
      final profile = KitaUserProfile(
        id: 1,
        displayName: 'Marie',
        accessibilityProfile: 'blind',
        language: 'fr',
        ttsSpeed: 1.2,
        hapticEnabled: true,
        createdAt: DateTime(2026, 2, 24),
        updatedAt: DateTime(2026, 2, 24),
      );
      expect(profile.accessibilityProfile, equals('blind'));
      expect(profile.ttsSpeed, equals(1.2));
    });

    test('KitaPreference holds all fields', () {
      final pref = KitaPreference(
        id: 1,
        category: 'display',
        key: 'theme',
        value: 'dark',
        confidenceScore: 0.9,
        source: 'user',
        createdAt: DateTime(2026, 2, 24),
        updatedAt: DateTime(2026, 2, 24),
      );
      expect(pref.key, equals('theme'));
      expect(pref.confidenceScore, equals(0.9));
    });

    test('PluginDataEntry holds all fields', () {
      final entry = PluginDataEntry(
        id: 1,
        pluginId: 'com.kita.describe',
        namespace: 'settings',
        key: 'model',
        value: 'yolo-v8',
        createdAt: DateTime(2026, 2, 24),
        updatedAt: DateTime(2026, 2, 24),
      );
      expect(entry.pluginId, equals('com.kita.describe'));
      expect(entry.namespace, equals('settings'));
    });

    test('MockMemoryVault implements MemoryVault', () {
      final vault = MockMemoryVault();
      expect(vault, isA<MemoryVault>());
    });

    test('MockMemoryVault saves and retrieves episodes', () async {
      final vault = MockMemoryVault();
      final episode = KitaEpisode(
        id: 0,
        source: 'test',
        eventType: 'test',
        summary: 'Test episode',
        importanceScore: 0.5,
        isPinned: false,
        createdAt: DateTime.now(),
      );
      await vault.saveEpisode(episode);
      expect(vault.savedEpisodes, hasLength(1));
    });

    test('MockMemoryVault manages preferences', () async {
      final vault = MockMemoryVault();
      await vault.setPreference(
        key: 'theme',
        value: 'dark',
        category: 'display',
        source: 'user',
      );
      final result = await vault.getPreference('theme');
      expect(result.isSuccess, isTrue);
      result.when(
        success: (value) => expect(value, equals('dark')),
        failure: (_) => fail('Should not fail'),
      );
    });

    test('MockMemoryVault manages consents', () async {
      final vault = MockMemoryVault();
      final entry = ConsentEntry(
        id: 1,
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
        grantedAt: DateTime.now(),
      );
      await vault.grantConsent(entry);
      expect(vault.consents, hasLength(1));
      await vault.revokeConsent(1);
      expect(vault.consents, isEmpty);
    });
  });
}
