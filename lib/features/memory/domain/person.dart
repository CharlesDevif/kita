class KitaPerson {
  const KitaPerson({
    required this.id,
    required this.name,
    this.relationship,
    this.notes,
    this.interests = const [],
    this.lastMentionedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String? relationship;
  final String? notes;
  final List<String> interests;
  final DateTime? lastMentionedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
