import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/database.dart';
import '../../../core/utils/logger.dart';
import '../domain/ai_response.dart';
import '../domain/provider_tier.dart';
import '../domain/request_priority.dart';

/// Cache for AI responses, backed by the Drift `request_cache` table.
///
/// TTL varies by request priority:
/// - critical: never cached
/// - urgent: 30s
/// - standard: 5 min
/// - background: 1h
///
/// Uses raw SQL to avoid datetime format mismatches between Drift's
/// typed mapping and the `.drift` file's `strftime()` defaults.
class ResponseCache {
  ResponseCache({required KitaDatabase database}) : _db = database;

  static final _log = KitaLogger('AI');

  final KitaDatabase _db;

  /// Look up a cached response for the given prompt and priority.
  ///
  /// Returns `null` if no valid (non-expired) entry exists,
  /// or if the priority is `critical` (never cached).
  Future<AIResponse?> get(String prompt, RequestPriority priority) async {
    if (priority == RequestPriority.critical) return null;

    final hash = _hashPrompt(prompt);
    final now = DateTime.now().toIso8601String();

    final rows = await _db.customSelect(
      'SELECT response_content, provider_id FROM request_cache '
      'WHERE request_hash = ? AND expires_at > ? LIMIT 1',
      variables: [Variable.withString(hash), Variable.withString(now)],
    ).get();

    if (rows.isEmpty) return null;

    final row = rows.first;
    _log.debug('Cache hit for hash $hash');

    return AIResponse(
      content: row.read<String>('response_content'),
      meta: AIResponseMeta(
        providerId: row.read<String>('provider_id'),
        latency: Duration.zero,
        tier: ProviderTier.local,
        cached: true,
      ),
      status: AIResponseStatus.success,
    );
  }

  /// Store a response in the cache with a TTL based on priority.
  ///
  /// Does nothing for `critical` priority (never cached).
  Future<void> put(
    String prompt,
    RequestPriority priority,
    AIResponse response,
  ) async {
    if (priority == RequestPriority.critical) return;

    final ttl = _ttlForPriority(priority);
    if (ttl == Duration.zero) return;

    final hash = _hashPrompt(prompt);
    final now = DateTime.now();
    final expiresAt = now.add(ttl);

    // Upsert: delete existing, then insert.
    await _db.customUpdate(
      'DELETE FROM request_cache WHERE request_hash = ?',
      variables: [Variable.withString(hash)],
      updates: {_db.requestCache},
    );

    await _db.customInsert(
      'INSERT INTO request_cache '
      '(request_hash, request_type, response_content, provider_id, ttl_seconds, created_at, expires_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(hash),
        Variable.withString(priority.name),
        Variable.withString(response.content),
        Variable.withString(response.meta.providerId),
        Variable.withInt(ttl.inSeconds),
        Variable.withString(now.toIso8601String()),
        Variable.withString(expiresAt.toIso8601String()),
      ],
    );

    _log.debug('Cached response for hash $hash (TTL: ${ttl.inSeconds}s)');
  }

  /// Remove all expired entries from the cache.
  Future<int> cleanExpired() async {
    final now = DateTime.now().toIso8601String();

    final count = await _db.customUpdate(
      'DELETE FROM request_cache WHERE expires_at <= ?',
      variables: [Variable.withString(now)],
      updates: {_db.requestCache},
    );

    if (count > 0) {
      _log.info('Cleaned $count expired cache entries');
    }
    return count;
  }

  /// Remove all entries from the cache.
  Future<void> clear() async {
    await _db.customUpdate(
      'DELETE FROM request_cache',
      updates: {_db.requestCache},
    );
    _log.info('Cache cleared');
  }

  Duration _ttlForPriority(RequestPriority priority) {
    return switch (priority) {
      RequestPriority.critical => AppConfig.cacheTtlCritical,
      RequestPriority.urgent => AppConfig.cacheTtlUrgent,
      RequestPriority.standard => AppConfig.cacheTtlStandard,
      RequestPriority.background => AppConfig.cacheTtlBackground,
    };
  }

  /// FNV-1a 64-bit hash, deterministic and stable across runs.
  String _hashPrompt(String prompt) {
    final normalized = prompt.trim().toLowerCase();
    final bytes = utf8.encode(normalized);
    var hash = 0xcbf29ce484222325; // FNV offset basis
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff; // mask to 63 bits
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
