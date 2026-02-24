class KitaPreference {
  const KitaPreference({
    required this.id,
    required this.category,
    required this.key,
    required this.value,
    required this.confidenceScore,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String category;
  final String key;
  final String value;
  final double confidenceScore;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
}
