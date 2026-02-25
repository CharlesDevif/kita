import '../../../core/utils/logger.dart';
import '../domain/profile_detection.dart';

/// Callback to persist the user profile after onboarding.
typedef PersistProfileCallback = Future<void> Function(
  String userName,
  AccessibilityProfile profile,
);

/// Callback to mark onboarding as complete in persistent storage.
typedef MarkCompleteCallback = Future<void> Function();

/// Service responsible for finalizing the onboarding process.
///
/// Persists the user profile, marks onboarding as complete,
/// and signals the app to transition to passive mode.
class OnboardingCompletion {
  OnboardingCompletion({
    PersistProfileCallback? onPersistProfile,
    MarkCompleteCallback? onMarkComplete,
  })  : _onPersistProfile = onPersistProfile,
        _onMarkComplete = onMarkComplete;

  static final _log = KitaLogger('Onboarding.Completion');

  final PersistProfileCallback? _onPersistProfile;
  final MarkCompleteCallback? _onMarkComplete;

  bool _completed = false;

  /// Whether the onboarding has been completed.
  bool get isCompleted => _completed;

  /// Complete the onboarding flow.
  ///
  /// Persists the user profile and marks onboarding as done.
  /// After completion, the go_router redirect guard should
  /// navigate away from the onboarding screen.
  Future<void> completeOnboarding({
    required String userName,
    required AccessibilityProfile profile,
    bool isConfiguredByCaregiver = false,
    String? caregiverName,
  }) async {
    if (_completed) {
      _log.warning('Onboarding already completed, ignoring duplicate call');
      return;
    }

    _log.info('Completing onboarding');

    // Persist the user profile
    if (_onPersistProfile != null) {
      await _onPersistProfile(userName, profile);
      _log.info('Profile persisted successfully');
    }

    // Mark onboarding as complete in persistent storage
    if (_onMarkComplete != null) {
      await _onMarkComplete();
    }

    _completed = true;
    _log.info('Onboarding completed successfully');
  }
}
