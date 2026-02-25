import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../io/data/providers/tts_providers.dart';
import '../data/onboarding_completion.dart';
import '../data/pack_installer.dart';
import '../data/permission_storytelling_impl.dart';
import '../data/platform_permission_requester.dart';
import '../data/profile_detection_impl.dart';
import '../domain/onboarding_state.dart';
import '../domain/permission_storytelling.dart';
import '../domain/profile_detection.dart';

/// Provides the [ProfileDetection] implementation.
///
/// The binding observer is registered on creation and cleaned up on dispose.
final profileDetectionProvider = Provider<ProfileDetection>((ref) {
  final detection = ProfileDetectionImpl();
  ref.onDispose(detection.dispose);
  return detection;
});

/// Exposes the current [DetectedProfile] as a stream, starting with
/// the synchronous detection result.
///
/// Emits the initial profile immediately, then updates whenever the user
/// toggles OS accessibility features (e.g. VoiceOver on/off).
final detectedProfileProvider = StreamProvider<DetectedProfile>((ref) {
  final detection = ref.watch(profileDetectionProvider);
  final initial = detection.detect();

  return Stream.value(initial).asyncExpand(
    (first) async* {
      yield first;
      yield* detection.onProfileChanged;
    },
  );
});

/// Provides the [PackInstaller] for auto-installing plugin packs.
final packInstallerProvider = Provider<PackInstaller>((ref) {
  return PackInstaller();
});

/// Provides the [PermissionRequester] for platform permission requests.
final permissionRequesterProvider = Provider<PermissionRequester>((ref) {
  return PlatformPermissionRequester();
});

/// Provides the [PermissionStorytelling] service.
final permissionStorytellingProvider =
    Provider<PermissionStorytelling>((ref) {
  final requester = ref.watch(permissionRequesterProvider);
  final tts = ref.watch(ttsServiceProvider);
  return PermissionStorytellingImpl(
    requester: requester,
    tts: tts,
  );
});

/// Provides the [OnboardingCompletion] service for finalizing onboarding.
final onboardingCompletionProvider = Provider<OnboardingCompletion>((ref) {
  return OnboardingCompletion();
});

/// Whether onboarding has been completed.
///
/// Defaults to false. Set to true when onboarding flow finishes.
final onboardingCompleteProvider =
    NotifierProvider<OnboardingCompleteNotifier, bool>(
  OnboardingCompleteNotifier.new,
);

/// Simple notifier tracking onboarding completion state.
class OnboardingCompleteNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markComplete() => state = true;
}

/// Notifier managing the onboarding flow state.
///
/// Drives the step-by-step progression and integrates with
/// profile detection, pack installation, and persistence.
final onboardingNotifierProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);

/// [ChangeNotifier] wrapper for go_router's `refreshListenable`.
///
/// Notifies go_router when the onboarding completion state changes
/// so the redirect guard re-evaluates.
final onboardingRefreshListenableProvider =
    Provider<OnboardingRefreshListenable>((ref) {
  final listenable = OnboardingRefreshListenable();
  ref.listen(onboardingCompleteProvider, (prev, next) {
    listenable.notify();
  });
  ref.onDispose(listenable.dispose);
  return listenable;
});

/// Manages the onboarding flow state machine.
class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    final detected = ref.watch(detectedProfileProvider);
    final detectedProfile = detected.asData?.value;

    if (detectedProfile != null) {
      return OnboardingState(
        step: OnboardingStep.welcome,
        detectedProfile: detectedProfile,
      );
    }
    return const OnboardingState(step: OnboardingStep.detecting);
  }

  /// Move to mode choice step after welcome.
  void completeWelcome() {
    state = state.copyWith(step: OnboardingStep.modeChoice);
  }

  /// Choose standard mode ("Pour moi").
  void chooseStandardMode() {
    state = state.copyWith(
      isCaregiverMode: false,
      step: OnboardingStep.profile,
    );
  }

  /// Choose caregiver mode ("Pour quelqu'un d'autre").
  void chooseCaregiverMode() {
    state = state.copyWith(
      isCaregiverMode: true,
      step: OnboardingStep.caregiver,
    );
  }

  /// Set the user's name.
  void setUserName(String name) {
    state = state.copyWith(userName: name);
  }

  /// Confirm profile selection and install the corresponding pack.
  Future<void> selectProfile(AccessibilityProfile profile) async {
    state = state.copyWith(
      detectedProfile: DetectedProfile(
        profile: profile,
        screenReader: state.detectedProfile?.screenReader ?? false,
        largeText: state.detectedProfile?.largeText ?? false,
        reduceMotion: state.detectedProfile?.reduceMotion ?? false,
        boldText: state.detectedProfile?.boldText ?? false,
        highContrast: state.detectedProfile?.highContrast ?? false,
      ),
    );

    // Install the pack for the selected profile
    final installer = ref.read(packInstallerProvider);
    await installer.installPack(profile);

    // Move to permissions step (Story 9.3)
    state = state.copyWith(step: OnboardingStep.permissions);
  }

  /// Mark a permission as granted.
  void grantPermission(String permission) {
    state = state.copyWith(
      permissionsGranted: {...state.permissionsGranted, permission},
    );
  }

  /// Move to the magic moment step.
  void completePermissions() {
    state = state.copyWith(step: OnboardingStep.magic);
  }

  /// Complete the onboarding flow.
  void completeOnboarding() {
    state = state.copyWith(
      step: OnboardingStep.complete,
      onboardingComplete: true,
    );
    ref.read(onboardingCompleteProvider.notifier).markComplete();
  }

  /// Complete the onboarding flow as caregiver.
  void completeCaregiverOnboarding() {
    state = state.copyWith(
      step: OnboardingStep.complete,
      onboardingComplete: true,
      isConfiguredByCaregiver: true,
    );
    ref.read(onboardingCompleteProvider.notifier).markComplete();
  }
}

/// [ChangeNotifier] wrapper to bridge Riverpod state to go_router's
/// `refreshListenable` parameter.
class OnboardingRefreshListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}
