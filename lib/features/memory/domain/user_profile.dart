class KitaUserProfile {
  const KitaUserProfile({
    required this.id,
    this.displayName,
    required this.accessibilityProfile,
    required this.language,
    required this.ttsSpeed,
    this.ttsVoice,
    required this.hapticEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String? displayName;
  final String accessibilityProfile;
  final String language;
  final double ttsSpeed;
  final String? ttsVoice;
  final bool hapticEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
}
