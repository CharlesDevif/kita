import 'memory_domain.dart';

class ConsentEntry {
  const ConsentEntry({
    required this.id,
    required this.domain,
    required this.purpose,
    required this.grantedAt,
    this.revokedAt,
    required this.dataCategory,
  });

  final String id;
  final MemoryDomain domain;
  final String purpose;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final String dataCategory;
}
