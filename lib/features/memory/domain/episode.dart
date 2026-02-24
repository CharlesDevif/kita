import 'memory_domain.dart';

class Episode {
  const Episode({
    required this.id,
    required this.timestamp,
    required this.source,
    required this.summary,
    this.tags = const [],
    this.important = false,
    this.domain = MemoryDomain.episodic,
  });

  final String id;
  final DateTime timestamp;
  final String source;
  final String summary;
  final List<String> tags;
  final bool important;
  final MemoryDomain domain;
}
