import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kita/app.dart';
import 'package:kita/features/io/data/providers/tts_providers.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/onboarding/domain/permission_storytelling.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';
import 'package:kita/features/orchestration/di/providers.dart';
import 'package:kita/features/shell/presentation/kita_shell.dart';
import 'package:kita/features/shell/presentation/shell_onboarding.dart';

import 'mocks/mock_ai_router.dart';
import 'mocks/mock_tts_service.dart';

class _FakePermissionRequester implements PermissionRequester {
  @override
  Future<PermissionRequestStatus> request(KitaPermission permission) async {
    return PermissionRequestStatus.granted;
  }

  @override
  Future<void> openSettings() async {}
}

void main() {
  testWidgets(
      'KitaApp shows Shell with conversational onboarding on first launch',
      (tester) async {
    final mockTts = MockTTSService();

    // Disable animations platform-wide to stop KitaOrb infinite rotation.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(() {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServiceProvider.overrideWithValue(mockTts),
          detectedProfileProvider.overrideWith(
            (ref) => Stream.value(DetectedProfile.general),
          ),
          permissionRequesterProvider
              .overrideWithValue(_FakePermissionRequester()),
          // Mock AI router to avoid FallbackChain 15s timeout timers.
          aiRouterProvider.overrideWithValue(MockAIRouter()),
        ],
        child: const KitaApp(),
      ),
    );

    // Pump enough for greeting flow timers to complete.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Shell is the entry point — no redirect to /onboarding
    expect(find.byType(KitaShell), findsOneWidget);

    // Conversational onboarding is displayed within the Shell viewport
    expect(find.byType(ShellOnboarding), findsOneWidget);

    // Drain remaining timers (STT listen timeout = 8s).
    await tester.pump(const Duration(seconds: 10));

    mockTts.dispose();
  });
}
