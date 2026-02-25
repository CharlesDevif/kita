/// Shared helpers for integration test journeys.
///
/// Provides [buildOnboardingTestApp] and mock implementations
/// reusable across all journey tests.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/data/providers/tts_providers.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/io/domain/speech_event.dart';
import 'package:kita/features/io/domain/tts_service.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/onboarding/domain/permission_storytelling.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';
import 'package:kita/features/onboarding/presentation/onboarding_screen.dart';
import 'package:kita/shared/multi_modal/profile_adapter.dart';

// =============================================================================
// Mock TTS — ne parle pas en tests, capture les textes parlés
// =============================================================================

class IntegrationMockTTSService implements TTSService {
  final List<String> spokenTexts = [];
  String? get lastSpokenText => spokenTexts.isEmpty ? null : spokenTexts.last;
  bool _isSpeaking = false;

  final StreamController<TtsSpeechEvent> _controller =
      StreamController<TtsSpeechEvent>.broadcast();

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Stream<TtsSpeechEvent> get speechEvents => _controller.stream;

  @override
  Future<Result<void>> speak(
    String text, {
    TTSPriority priority = TTSPriority.standard,
  }) async {
    spokenTexts.add(text);
    _isSpeaking = true;
    scheduleMicrotask(() => _isSpeaking = false);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async {
    _isSpeaking = false;
    return const Result.success(null);
  }

  void dispose() => _controller.close();
}

// =============================================================================
// IntegrationMockHapticService — capture les patterns haptic déclenchés
// =============================================================================

class IntegrationMockHapticService implements HapticService {
  final List<HapticPattern> triggered = [];

  @override
  Future<Result<void>> trigger(HapticPattern p) async {
    triggered.add(p);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> info() => trigger(HapticPattern.info);
  @override
  Future<Result<void>> warning() => trigger(HapticPattern.warning);
  @override
  Future<Result<void>> danger() => trigger(HapticPattern.danger);
  @override
  Future<Result<void>> presence() => trigger(HapticPattern.presence);
}

// =============================================================================
// IntegrationMockProfileAdapter — profil aveugle par défaut
// =============================================================================

class IntegrationMockProfileAdapter implements ProfileAdapter {
  @override
  String get activeProfile => 'aveugle';

  @override
  void feedback({
    void Function()? visual,
    void Function()? vocal,
    void Function()? haptic,
  }) {
    vocal?.call();
    haptic?.call();
  }
}

// =============================================================================
// Fake permission requester — accorde toujours
// =============================================================================

class FakePermissionRequester implements PermissionRequester {
  @override
  Future<PermissionRequestStatus> request(KitaPermission permission) async {
    return PermissionRequestStatus.granted;
  }

  @override
  Future<void> openSettings() async {}
}

// =============================================================================
// buildOnboardingTestApp — onboarding avec mocks
// =============================================================================

Widget buildOnboardingTestApp({
  required IntegrationMockTTSService mockTts,
  DetectedProfile detectedProfile = const DetectedProfile(
    profile: AccessibilityProfile.blind,
    screenReader: true,
    largeText: false,
    reduceMotion: false,
    boldText: false,
    highContrast: false,
  ),
}) {
  return ProviderScope(
    overrides: [
      detectedProfileProvider.overrideWith(
        (ref) => Stream.value(detectedProfile),
      ),
      ttsServiceProvider.overrideWithValue(mockTts),
      permissionRequesterProvider.overrideWithValue(FakePermissionRequester()),
    ],
    child: const MaterialApp(
      home: OnboardingScreen(),
    ),
  );
}

