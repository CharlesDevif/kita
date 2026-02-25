import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/domain/speech_event.dart';
import 'package:kita/features/io/domain/tts_service.dart';
import 'package:kita/features/onboarding/data/permission_storytelling_impl.dart';
import 'package:kita/features/onboarding/domain/permission_storytelling.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';

/// Fake TTS that records all spoken texts.
class FakeTTS implements TTSService {
  final List<String> spokenTexts = [];

  @override
  bool get isSpeaking => false;

  @override
  Future<Result<void>> speak(
    String text, {
    TTSPriority priority = TTSPriority.standard,
  }) async {
    spokenTexts.add(text);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async => const Result.success(null);

  @override
  Stream<TtsSpeechEvent> get speechEvents => const Stream.empty();
}

/// Fake permission requester with configurable responses.
class FakePermissionRequester implements PermissionRequester {
  FakePermissionRequester({
    this.responses = const {},
  });

  /// Map of permission -> list of responses for each attempt.
  final Map<KitaPermission, List<PermissionRequestStatus>> responses;
  final Map<KitaPermission, int> _attemptCount = {};
  bool openSettingsCalled = false;

  @override
  Future<PermissionRequestStatus> request(KitaPermission permission) async {
    final count = _attemptCount[permission] ?? 0;
    _attemptCount[permission] = count + 1;

    final permResponses = responses[permission];
    if (permResponses != null && count < permResponses.length) {
      return permResponses[count];
    }
    return PermissionRequestStatus.denied;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCalled = true;
  }
}

void main() {
  group('PermissionStorytellingImpl', () {
    late FakeTTS fakeTTS;
    late FakePermissionRequester fakeRequester;
    late List<Map<String, dynamic>> consentLogs;

    setUp(() {
      fakeTTS = FakeTTS();
      fakeRequester = FakePermissionRequester();
      consentLogs = [];
    });

    PermissionStorytellingImpl createService({
      Map<KitaPermission, List<PermissionRequestStatus>>? responses,
    }) {
      if (responses != null) {
        fakeRequester = FakePermissionRequester(responses: responses);
      }
      return PermissionStorytellingImpl(
        requester: fakeRequester,
        tts: fakeTTS,
        consentLogger: ({
          required String consentType,
          required String scope,
          required bool granted,
          String? details,
        }) async {
          consentLogs.add({
            'consentType': consentType,
            'scope': scope,
            'granted': granted,
            'details': details,
          });
        },
      );
    }

    test('all permissions granted on first attempt', () async {
      final service = createService(
        responses: {
          KitaPermission.camera: [PermissionRequestStatus.granted],
          KitaPermission.microphone: [PermissionRequestStatus.granted],
          KitaPermission.location: [PermissionRequestStatus.granted],
        },
      );

      final results =
          await service.requestAll(AccessibilityProfile.blind);

      expect(results, hasLength(3));
      expect(results[0].permission, KitaPermission.camera);
      expect(results[0].isGranted, isTrue);
      expect(results[0].attempts, 1);
      expect(results[1].permission, KitaPermission.microphone);
      expect(results[1].isGranted, isTrue);
      expect(results[2].permission, KitaPermission.location);
      expect(results[2].isGranted, isTrue);
    });

    test('permission denied once then granted on second attempt', () async {
      final service = createService(
        responses: {
          KitaPermission.camera: [
            PermissionRequestStatus.denied,
            PermissionRequestStatus.granted,
          ],
          KitaPermission.microphone: [PermissionRequestStatus.granted],
          KitaPermission.location: [PermissionRequestStatus.granted],
        },
      );

      final results =
          await service.requestAll(AccessibilityProfile.blind);

      expect(results[0].permission, KitaPermission.camera);
      expect(results[0].isGranted, isTrue);
      expect(results[0].attempts, 2);
    });

    test('permission denied twice continues without', () async {
      final service = createService(
        responses: {
          KitaPermission.camera: [
            PermissionRequestStatus.denied,
            PermissionRequestStatus.denied,
          ],
          KitaPermission.microphone: [PermissionRequestStatus.granted],
          KitaPermission.location: [PermissionRequestStatus.granted],
        },
      );

      final results =
          await service.requestAll(AccessibilityProfile.general);

      expect(results[0].permission, KitaPermission.camera);
      expect(results[0].isGranted, isFalse);
      expect(results[0].status, PermissionRequestStatus.denied);
      expect(results[0].attempts, 2);
      // Flow continues even after denial
      expect(results[1].isGranted, isTrue);
      expect(results[2].isGranted, isTrue);
    });

    test('permanently denied does not re-request', () async {
      final service = createService(
        responses: {
          KitaPermission.camera: [
            PermissionRequestStatus.permanentlyDenied,
          ],
          KitaPermission.microphone: [PermissionRequestStatus.granted],
          KitaPermission.location: [PermissionRequestStatus.granted],
        },
      );

      final results =
          await service.requestAll(AccessibilityProfile.blind);

      expect(results[0].permission, KitaPermission.camera);
      expect(results[0].isGranted, isFalse);
      expect(
        results[0].status,
        PermissionRequestStatus.permanentlyDenied,
      );
      // Flow continues
      expect(results, hasLength(3));
    });

    test('TTS speaks first explanation before requesting', () async {
      final service = createService(
        responses: {
          KitaPermission.camera: [PermissionRequestStatus.granted],
          KitaPermission.microphone: [PermissionRequestStatus.granted],
          KitaPermission.location: [PermissionRequestStatus.granted],
        },
      );

      await service.requestAll(AccessibilityProfile.blind);

      // Should have spoken 3 first explanations (one per permission)
      expect(fakeTTS.spokenTexts, hasLength(3));
      expect(
        fakeTTS.spokenTexts[0],
        contains('caméra'),
      );
      expect(
        fakeTTS.spokenTexts[1],
        contains('micro'),
      );
      expect(
        fakeTTS.spokenTexts[2],
        contains('position'),
      );
    });

    test('TTS speaks second explanation after first denial', () async {
      final service = createService(
        responses: {
          KitaPermission.camera: [
            PermissionRequestStatus.denied,
            PermissionRequestStatus.granted,
          ],
          KitaPermission.microphone: [PermissionRequestStatus.granted],
          KitaPermission.location: [PermissionRequestStatus.granted],
        },
      );

      await service.requestAll(AccessibilityProfile.blind);

      // Camera: first + second explanation, Micro: first, Location: first = 4
      expect(fakeTTS.spokenTexts, hasLength(4));
      // Second explanation should mention obstacles/environment
      expect(
        fakeTTS.spokenTexts[1],
        contains('obstacle'),
      );
    });

    test('consent logger is called for each permission', () async {
      final service = createService(
        responses: {
          KitaPermission.camera: [PermissionRequestStatus.granted],
          KitaPermission.microphone: [PermissionRequestStatus.denied,
            PermissionRequestStatus.denied],
          KitaPermission.location: [PermissionRequestStatus.granted],
        },
      );

      await service.requestAll(AccessibilityProfile.general);

      expect(consentLogs, hasLength(3));
      // Camera granted
      expect(consentLogs[0]['consentType'], 'os_permission');
      expect(consentLogs[0]['scope'], 'camera');
      expect(consentLogs[0]['granted'], isTrue);
      // Microphone denied
      expect(consentLogs[1]['scope'], 'microphone');
      expect(consentLogs[1]['granted'], isFalse);
      // Location granted
      expect(consentLogs[2]['scope'], 'location');
      expect(consentLogs[2]['granted'], isTrue);
    });

    test('works without consent logger', () async {
      final service = PermissionStorytellingImpl(
        requester: FakePermissionRequester(
          responses: {
            KitaPermission.camera: [PermissionRequestStatus.granted],
            KitaPermission.microphone: [PermissionRequestStatus.granted],
            KitaPermission.location: [PermissionRequestStatus.granted],
          },
        ),
        tts: fakeTTS,
      );

      // Should not throw
      final results =
          await service.requestAll(AccessibilityProfile.general);
      expect(results, hasLength(3));
    });

    test('permission order returns camera first for blind profile', () {
      final order = permissionOrder(AccessibilityProfile.blind);
      expect(order.first, KitaPermission.camera);
      expect(order.last, KitaPermission.location);
    });

    test('permission order returns camera first for general profile', () {
      final order = permissionOrder(AccessibilityProfile.general);
      expect(order.first, KitaPermission.camera);
      expect(order.last, KitaPermission.location);
    });
  });

  group('PermissionStory', () {
    test('all permissions have stories', () {
      for (final permission in KitaPermission.values) {
        expect(
          permissionStories[permission],
          isNotNull,
          reason: 'Missing story for ${permission.name}',
        );
      }
    });

    test('all stories have non-empty explanations', () {
      for (final entry in permissionStories.entries) {
        expect(
          entry.value.firstExplanation,
          isNotEmpty,
          reason: 'Empty first explanation for ${entry.key.name}',
        );
        expect(
          entry.value.secondExplanation,
          isNotEmpty,
          reason: 'Empty second explanation for ${entry.key.name}',
        );
      }
    });

    test('camera first explanation matches AC1', () {
      final story = permissionStories[KitaPermission.camera]!;
      expect(
        story.firstExplanation,
        contains('caméra'),
      );
    });

    test('microphone first explanation matches AC2', () {
      final story = permissionStories[KitaPermission.microphone]!;
      expect(
        story.firstExplanation,
        contains('micro'),
      );
    });
  });

  group('PermissionResult', () {
    test('isGranted returns true when granted', () {
      const result = PermissionResult(
        permission: KitaPermission.camera,
        status: PermissionRequestStatus.granted,
        attempts: 1,
      );
      expect(result.isGranted, isTrue);
    });

    test('isGranted returns false when denied', () {
      const result = PermissionResult(
        permission: KitaPermission.camera,
        status: PermissionRequestStatus.denied,
        attempts: 2,
      );
      expect(result.isGranted, isFalse);
    });

    test('isGranted returns false when permanently denied', () {
      const result = PermissionResult(
        permission: KitaPermission.camera,
        status: PermissionRequestStatus.permanentlyDenied,
        attempts: 1,
      );
      expect(result.isGranted, isFalse);
    });
  });
}
