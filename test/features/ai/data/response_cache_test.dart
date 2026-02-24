import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:kita/core/data/database.dart';
import 'package:kita/features/ai/data/response_cache.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/request_priority.dart';

void main() {
  late KitaDatabase db;
  late ResponseCache cache;

  setUp(() {
    final rawDb = sql.sqlite3.openInMemory();
    db = KitaDatabase(NativeDatabase.opened(rawDb));
    cache = ResponseCache(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  const testResponse = AIResponse(
    content: 'A beautiful park with trees',
    meta: AIResponseMeta(
      providerId: 'claude',
      latency: Duration(milliseconds: 500),
      tier: ProviderTier.cloudPowerful,
    ),
    status: AIResponseStatus.success,
  );

  group('ResponseCache', () {
    group('critical priority — never cached', () {
      test('put does nothing for critical requests', () async {
        await cache.put(
            'obstacle ahead', RequestPriority.critical, testResponse);
        final result =
            await cache.get('obstacle ahead', RequestPriority.critical);
        expect(result, equals(null));
      });

      test('get always returns null for critical requests', () async {
        await cache.put('test prompt', RequestPriority.standard, testResponse);
        final result =
            await cache.get('test prompt', RequestPriority.critical);
        expect(result, equals(null));
      });
    });

    group('cache hit/miss', () {
      test('returns null on cache miss', () async {
        final result =
            await cache.get('unknown prompt', RequestPriority.standard);
        expect(result, equals(null));
      });

      test('returns cached response on hit', () async {
        await cache.put(
            'describe this park', RequestPriority.standard, testResponse);
        final result =
            await cache.get('describe this park', RequestPriority.standard);

        expect(result, isNot(equals(null)));
        expect(result!.content, equals('A beautiful park with trees'));
        expect(result.meta.cached, isTrue);
        expect(result.status, equals(AIResponseStatus.success));
      });

      test('cache is case-insensitive', () async {
        await cache.put(
            'Describe This Park', RequestPriority.standard, testResponse);
        final result =
            await cache.get('describe this park', RequestPriority.standard);
        expect(result, isNot(equals(null)));
      });

      test('cache trims whitespace', () async {
        await cache.put(
            '  describe this  ', RequestPriority.standard, testResponse);
        final result =
            await cache.get('describe this', RequestPriority.standard);
        expect(result, isNot(equals(null)));
      });
    });

    group('TTL by priority', () {
      test('urgent entries are cached', () async {
        await cache.put(
            'urgent request', RequestPriority.urgent, testResponse);
        final result =
            await cache.get('urgent request', RequestPriority.urgent);
        expect(result, isNot(equals(null)));
      });

      test('standard entries are cached', () async {
        await cache.put(
            'standard request', RequestPriority.standard, testResponse);
        final result =
            await cache.get('standard request', RequestPriority.standard);
        expect(result, isNot(equals(null)));
      });

      test('background entries are cached', () async {
        await cache.put(
            'background request', RequestPriority.background, testResponse);
        final result =
            await cache.get('background request', RequestPriority.background);
        expect(result, isNot(equals(null)));
      });
    });

    group('upsert behavior', () {
      test('overwrites existing entry for same prompt', () async {
        const response1 = AIResponse(
          content: 'First response',
          meta: AIResponseMeta(
            providerId: 'claude',
            latency: Duration(milliseconds: 100),
            tier: ProviderTier.cloudPowerful,
          ),
          status: AIResponseStatus.success,
        );
        const response2 = AIResponse(
          content: 'Second response',
          meta: AIResponseMeta(
            providerId: 'openai',
            latency: Duration(milliseconds: 200),
            tier: ProviderTier.cloudFast,
          ),
          status: AIResponseStatus.success,
        );

        await cache.put('same prompt', RequestPriority.standard, response1);
        await cache.put('same prompt', RequestPriority.standard, response2);

        final result =
            await cache.get('same prompt', RequestPriority.standard);
        expect(result, isNot(equals(null)));
        expect(result!.content, equals('Second response'));
      });
    });

    group('cleanExpired', () {
      test('removes expired entries', () async {
        // Insert directly with an already-expired timestamp
        final now = DateTime.now();
        final expired = now.subtract(const Duration(seconds: 10));
        await db.customInsert(
          'INSERT INTO request_cache '
          '(request_hash, request_type, response_content, provider_id, ttl_seconds, created_at, expires_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString('expired-hash'),
            Variable.withString('standard'),
            Variable.withString('old content'),
            Variable.withString('claude'),
            Variable.withInt(1),
            Variable.withString(expired.toIso8601String()),
            Variable.withString(expired.toIso8601String()),
          ],
        );

        final count = await cache.cleanExpired();
        expect(count, equals(1));
      });

      test('keeps non-expired entries', () async {
        await cache.put('keep this', RequestPriority.standard, testResponse);
        final count = await cache.cleanExpired();
        expect(count, equals(0));

        final result =
            await cache.get('keep this', RequestPriority.standard);
        expect(result, isNot(equals(null)));
      });
    });

    group('clear', () {
      test('removes all entries', () async {
        await cache.put('prompt 1', RequestPriority.standard, testResponse);
        await cache.put('prompt 2', RequestPriority.standard, testResponse);
        await cache.put('prompt 3', RequestPriority.background, testResponse);

        await cache.clear();

        final r1 = await cache.get('prompt 1', RequestPriority.standard);
        final r2 = await cache.get('prompt 2', RequestPriority.standard);
        final r3 = await cache.get('prompt 3', RequestPriority.background);

        expect(r1, equals(null));
        expect(r2, equals(null));
        expect(r3, equals(null));
      });
    });

    group('different prompts', () {
      test('different prompts have different cache entries', () async {
        const response2 = AIResponse(
          content: 'Different response',
          meta: AIResponseMeta(
            providerId: 'openai',
            latency: Duration(milliseconds: 100),
            tier: ProviderTier.cloudFast,
          ),
          status: AIResponseStatus.success,
        );

        await cache.put('prompt A', RequestPriority.standard, testResponse);
        await cache.put('prompt B', RequestPriority.standard, response2);

        final rA = await cache.get('prompt A', RequestPriority.standard);
        final rB = await cache.get('prompt B', RequestPriority.standard);

        expect(rA!.content, equals('A beautiful park with trees'));
        expect(rB!.content, equals('Different response'));
      });
    });
  });
}
