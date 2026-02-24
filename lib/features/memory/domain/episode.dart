import 'memory_domain.dart';

class KitaEpisode {
  const KitaEpisode({
    required this.id,
    required this.source,
    required this.eventType,
    required this.summary,
    this.details,
    this.tags = const [],
    required this.importanceScore,
    required this.isPinned,
    required this.createdAt,
    this.expiresAt,
    this.domain = MemoryDomain.episodic,
  });

  final int id;
  final String source;
  final String eventType;
  final String summary;
  final String? details;
  final List<String> tags;
  final double importanceScore;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final MemoryDomain domain;
}
