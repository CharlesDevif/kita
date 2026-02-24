import '../../core/utils/logger.dart';
import 'profile_adapter.dart';

/// User accessibility profile types.
enum UserProfile {
  /// Blind user — vocal+haptic primary, visual minimal (VoiceOver).
  aveugle,

  /// Deaf user — visual+haptic primary, vocal off.
  sourd,

  /// Standard user — all modalities active.
  standard,

  /// Helper/caregiver — visual+haptic, vocal off.
  aidant,
}

/// Profile-based multi-modal output routing.
///
/// Routes feedback callbacks (visual, vocal, haptic) based on the
/// active user profile. Ensures Marie (blind) gets voice+haptic,
/// Karim (deaf) gets text+visual, etc.
class ProfileAdapterImpl implements ProfileAdapter {
  ProfileAdapterImpl({
    UserProfile profile = UserProfile.standard,
  }) : _profile = profile;

  UserProfile _profile;
  static final _log = KitaLogger('Shell');

  @override
  String get activeProfile => _profile.name;

  /// Update the active profile.
  void setProfile(UserProfile profile) {
    if (_profile != profile) {
      _log.info('Profile changed: ${_profile.name} -> ${profile.name}');
      _profile = profile;
    }
  }

  @override
  void feedback({
    VoidCallback? visual,
    VoidCallback? vocal,
    VoidCallback? haptic,
  }) {
    switch (_profile) {
      case UserProfile.aveugle:
        // Blind: vocal always, haptic always, visual skipped (VoiceOver)
        vocal?.call();
        haptic?.call();

      case UserProfile.sourd:
        // Deaf: visual always, haptic always, vocal skipped
        visual?.call();
        haptic?.call();

      case UserProfile.standard:
        // Standard: all modalities
        visual?.call();
        vocal?.call();
        haptic?.call();

      case UserProfile.aidant:
        // Helper: visual always, haptic always, vocal skipped
        visual?.call();
        haptic?.call();
    }
  }
}
