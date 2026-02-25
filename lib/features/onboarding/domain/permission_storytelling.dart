import '../domain/profile_detection.dart';

/// Status of a permission request.
enum PermissionRequestStatus {
  /// Permission granted by user.
  granted,

  /// Permission denied (can re-ask).
  denied,

  /// Permission permanently denied (must go to settings).
  permanentlyDenied,

  /// iOS: access restricted by parental controls.
  restricted,
}

/// A permission that Kita needs to request.
enum KitaPermission {
  camera,
  microphone,
  location,
}

/// Result of requesting a single permission.
class PermissionResult {
  const PermissionResult({
    required this.permission,
    required this.status,
    required this.attempts,
  });

  final KitaPermission permission;
  final PermissionRequestStatus status;

  /// Number of times the permission was requested (1 or 2).
  final int attempts;

  bool get isGranted => status == PermissionRequestStatus.granted;
}

/// Storytelling content for a permission request.
class PermissionStory {
  const PermissionStory({
    required this.permission,
    required this.firstExplanation,
    required this.secondExplanation,
  });

  final KitaPermission permission;

  /// First explanation before requesting.
  final String firstExplanation;

  /// Second explanation after first denial.
  final String secondExplanation;
}

/// Abstraction over the native permission request API.
///
/// Allows testing without actual platform permissions.
abstract interface class PermissionRequester {
  /// Request a single permission from the OS.
  Future<PermissionRequestStatus> request(KitaPermission permission);

  /// Open the app settings page.
  Future<void> openSettings();
}

/// Callback for logging consent to the database (RGPD).
typedef ConsentLogger = Future<void> Function({
  required String consentType,
  required String scope,
  required bool granted,
  String? details,
});

/// Service for requesting permissions with contextual storytelling.
///
/// Each permission is explained in natural language before the OS dialog.
/// If denied, a complementary explanation is given and the permission
/// is re-requested once. After 2 denials, Kita accepts and moves on.
abstract interface class PermissionStorytelling {
  /// Request all permissions needed for the given profile.
  ///
  /// Returns results in the order they were requested.
  Future<List<PermissionResult>> requestAll(AccessibilityProfile profile);
}
