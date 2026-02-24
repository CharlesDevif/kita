import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/memory/domain/consent_entry.dart';
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/domain/forget_request.dart';
import 'package:kita/features/memory/domain/memory_domain.dart';
import 'package:kita/features/memory/domain/memory_vault.dart';

import '../../../mocks/mocks.dart';

void main() {
  group('Memory domain interfaces', () {
    test('MemoryDomain has 4 values', () {
      expect(MemoryDomain.values, hasLength(4));
    });

    test('ForgetScope has 4 values', () {
      expect(ForgetScope.values, hasLength(4));
    });

    test('Episode holds all fields', () {
      final episode = Episode(
        id: 'ep-001',
        timestamp: DateTime(2026, 2, 24),
        source: 'plugin.describe',
        summary: 'A park scene',
        tags: ['outdoor'],
        important: true,
      );
      expect(episode.id, equals('ep-001'));
      expect(episode.domain, equals(MemoryDomain.episodic));
      expect(episode.important, isTrue);
    });

    test('ForgetRequest holds scope and options', () {
      const request = ForgetRequest(
        scope: ForgetScope.domain,
        domain: MemoryDomain.episodic,
        confirmation: true,
      );
      expect(request.scope, equals(ForgetScope.domain));
      expect(request.confirmation, isTrue);
    });

    test('ConsentEntry holds GDPR fields', () {
      final entry = ConsentEntry(
        id: 'c-001',
        domain: MemoryDomain.episodic,
        purpose: 'Store descriptions',
        grantedAt: DateTime(2026, 2, 24),
        dataCategory: 'visual',
      );
      expect(entry.revokedAt, isNull);
      expect(entry.dataCategory, equals('visual'));
    });

    test('MockMemoryVault implements MemoryVault', () {
      final vault = MockMemoryVault();
      expect(vault, isA<MemoryVault>());
    });

    test('MockMemoryVault saves and retrieves episodes', () async {
      final vault = MockMemoryVault();
      final episode = Episode(
        id: 'ep-test',
        timestamp: DateTime.now(),
        source: 'test',
        summary: 'Test episode',
      );
      await vault.saveEpisode(episode);
      expect(vault.savedEpisodes, hasLength(1));
    });

    test('MockMemoryVault manages preferences', () async {
      final vault = MockMemoryVault();
      await vault.setPreference('theme', 'dark');
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
        id: 'c-test',
        domain: MemoryDomain.episodic,
        purpose: 'Testing',
        grantedAt: DateTime.now(),
        dataCategory: 'test',
      );
      await vault.grantConsent(entry);
      expect(vault.consents, hasLength(1));
      await vault.revokeConsent('c-test');
      expect(vault.consents, isEmpty);
    });
  });
}
