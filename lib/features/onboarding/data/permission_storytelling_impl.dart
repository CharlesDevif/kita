import '../../../core/utils/logger.dart';
import '../../io/domain/tts_service.dart';
import '../domain/permission_storytelling.dart';
import '../domain/profile_detection.dart';

final _log = KitaLogger('Onboarding');

/// Permission stories — contextual explanations for each permission.
const Map<KitaPermission, PermissionStory> permissionStories = {
  KitaPermission.camera: PermissionStory(
    permission: KitaPermission.camera,
    firstExplanation:
        'Pour décrire ce qui t\'entoure, j\'ai besoin de ta caméra.',
    secondExplanation:
        'La caméra me permet de voir les obstacles et de te décrire '
        'ton environnement. Sans elle, je ne pourrai pas t\'aider à naviguer.',
  ),
  KitaPermission.microphone: PermissionStory(
    permission: KitaPermission.microphone,
    firstExplanation: 'Pour t\'écouter, j\'ai besoin du micro.',
    secondExplanation:
        'Le micro me permet d\'entendre tes commandes vocales. '
        'Sans lui, tu devras tout taper au clavier.',
  ),
  KitaPermission.location: PermissionStory(
    permission: KitaPermission.location,
    firstExplanation:
        'Pour adapter mes alertes à ton environnement, '
        'j\'ai besoin de ta position.',
    secondExplanation:
        'La localisation me permet de savoir si tu es à l\'intérieur ou '
        'à l\'extérieur pour mieux calibrer mes alertes.',
  ),
};

/// Order of permissions by profile.
///
/// Blind users get camera first (most critical for them).
/// All profiles end with location.
List<KitaPermission> permissionOrder(AccessibilityProfile profile) {
  return const [
    KitaPermission.camera,
    KitaPermission.microphone,
    KitaPermission.location,
  ];
}

/// Implementation of [PermissionStorytelling] with vocal explanations.
class PermissionStorytellingImpl implements PermissionStorytelling {
  PermissionStorytellingImpl({
    required this.requester,
    required this.tts,
    this.consentLogger,
  });

  final PermissionRequester requester;
  final TTSService tts;
  final ConsentLogger? consentLogger;

  @override
  Future<List<PermissionResult>> requestAll(
    AccessibilityProfile profile,
  ) async {
    final order = permissionOrder(profile);
    final results = <PermissionResult>[];

    for (final permission in order) {
      final story = permissionStories[permission]!;
      final result = await _requestWithStorytelling(permission, story);
      results.add(result);

      // Log consent for RGPD
      await _logConsent(permission, result);
    }

    _log.info('Permission storytelling complete');
    return results;
  }

  Future<PermissionResult> _requestWithStorytelling(
    KitaPermission permission,
    PermissionStory story,
  ) async {
    // First attempt: speak explanation, then show OS dialog
    await tts.speak(
      story.firstExplanation,
      priority: TTSPriority.standard,
    );
    _log.info('Requesting permission: ${permission.name} (attempt 1)');

    var status = await requester.request(permission);

    if (status == PermissionRequestStatus.granted) {
      return PermissionResult(
        permission: permission,
        status: status,
        attempts: 1,
      );
    }

    // Second attempt with complementary explanation
    if (status == PermissionRequestStatus.denied) {
      await tts.speak(
        story.secondExplanation,
        priority: TTSPriority.standard,
      );
      _log.info('Requesting permission: ${permission.name} (attempt 2)');

      status = await requester.request(permission);
    }

    // After 2 denials or permanently denied, accept and move on
    if (status != PermissionRequestStatus.granted) {
      _log.info(
        'Permission ${permission.name} not granted after attempts, continuing',
      );
    }

    return PermissionResult(
      permission: permission,
      status: status,
      attempts: 2,
    );
  }

  Future<void> _logConsent(
    KitaPermission permission,
    PermissionResult result,
  ) async {
    if (consentLogger == null) return;

    try {
      await consentLogger!(
        consentType: 'os_permission',
        scope: permission.name,
        granted: result.isGranted,
        details:
            'status=${result.status.name}, attempts=${result.attempts}',
      );
    } catch (e) {
      _log.error('Failed to log consent', error: e);
    }
  }
}
