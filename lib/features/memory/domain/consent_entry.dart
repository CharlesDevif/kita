class ConsentEntry {
  const ConsentEntry({
    required this.id,
    required this.consentType,
    required this.scope,
    required this.granted,
    required this.grantedAt,
    this.revokedAt,
    this.details,
  });

  final int id;
  final String consentType;
  final String scope;
  final bool granted;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final String? details;
}
