import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/onboarding/data/profile_detection_impl.dart';
import 'package:kita/features/onboarding/domain/profile_detection.dart';

void main() {
  group('resolveProfile', () {
    test('screenReader active returns blind', () {
      final result = resolveProfile(screenReader: true, largeText: false);
      expect(result, AccessibilityProfile.blind);
    });

    test('screenReader active takes priority over largeText', () {
      final result = resolveProfile(screenReader: true, largeText: true);
      expect(result, AccessibilityProfile.blind);
    });

    test('largeText without screenReader returns lowVision', () {
      final result = resolveProfile(screenReader: false, largeText: true);
      expect(result, AccessibilityProfile.lowVision);
    });

    test('no accessibility features returns general', () {
      final result = resolveProfile(screenReader: false, largeText: false);
      expect(result, AccessibilityProfile.general);
    });
  });

  group('ProfileDetectionImpl', () {
    late ProfileDetectionImpl detection;

    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();
      detection = ProfileDetectionImpl();
    });

    tearDown(() {
      detection.dispose();
    });

    test('implements ProfileDetection interface', () {
      expect(detection, isA<ProfileDetection>());
    });

    test('detect returns a DetectedProfile', () {
      final result = detection.detect();
      expect(result, isA<DetectedProfile>());
    });

    test('detect returns general profile in test environment', () {
      final result = detection.detect();
      expect(result.profile, AccessibilityProfile.general);
      expect(result.screenReader, isFalse);
    });

    test('onProfileChanged emits when didChangeAccessibilityFeatures called',
        () async {
      final profiles = <DetectedProfile>[];
      final sub = detection.onProfileChanged.listen(profiles.add);

      detection.didChangeAccessibilityFeatures();
      await Future<void>.delayed(Duration.zero);

      expect(profiles, hasLength(1));
      expect(profiles.first, isA<DetectedProfile>());

      await sub.cancel();
    });

    test('multiple accessibility changes emit multiple events', () async {
      final profiles = <DetectedProfile>[];
      final sub = detection.onProfileChanged.listen(profiles.add);

      detection.didChangeAccessibilityFeatures();
      detection.didChangeAccessibilityFeatures();
      detection.didChangeAccessibilityFeatures();
      await Future<void>.delayed(Duration.zero);

      expect(profiles, hasLength(3));

      await sub.cancel();
    });

    test('dispose prevents further stream emissions', () async {
      final profiles = <DetectedProfile>[];
      final sub = detection.onProfileChanged.listen(profiles.add);

      detection.dispose();
      detection.didChangeAccessibilityFeatures();

      await Future<void>.delayed(Duration.zero);
      expect(profiles, isEmpty);

      await sub.cancel();
    });

    test('dispose can be called multiple times safely', () {
      detection.dispose();
      expect(() => detection.dispose(), returnsNormally);
    });
  });

  group('DetectedProfile', () {
    test('general static returns expected defaults', () {
      const profile = DetectedProfile.general;
      expect(profile.profile, AccessibilityProfile.general);
      expect(profile.screenReader, isFalse);
      expect(profile.largeText, isFalse);
      expect(profile.reduceMotion, isFalse);
      expect(profile.boldText, isFalse);
      expect(profile.highContrast, isFalse);
    });

    test('equality works correctly', () {
      const a = DetectedProfile(
        profile: AccessibilityProfile.blind,
        screenReader: true,
        largeText: false,
        reduceMotion: false,
        boldText: false,
        highContrast: false,
      );
      const b = DetectedProfile(
        profile: AccessibilityProfile.blind,
        screenReader: true,
        largeText: false,
        reduceMotion: false,
        boldText: false,
        highContrast: false,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when profile differs', () {
      const a = DetectedProfile(
        profile: AccessibilityProfile.blind,
        screenReader: true,
        largeText: false,
        reduceMotion: false,
        boldText: false,
        highContrast: false,
      );
      const b = DetectedProfile(
        profile: AccessibilityProfile.general,
        screenReader: false,
        largeText: false,
        reduceMotion: false,
        boldText: false,
        highContrast: false,
      );
      expect(a, isNot(equals(b)));
    });

    test('toString includes relevant info', () {
      const profile = DetectedProfile.general;
      final str = profile.toString();
      expect(str, contains('general'));
      expect(str, contains('screenReader'));
    });
  });

  group('AccessibilityProfile enum', () {
    test('has exactly 3 values', () {
      expect(AccessibilityProfile.values, hasLength(3));
    });

    test('contains blind, lowVision, general', () {
      expect(
        AccessibilityProfile.values,
        containsAll([
          AccessibilityProfile.blind,
          AccessibilityProfile.lowVision,
          AccessibilityProfile.general,
        ]),
      );
    });
  });

  // Integration tests using testWidgets for platform accessibility features.
  // These test the real detection pipeline with test accessibility values.
  group('ProfileDetectionImpl platform accessibility detection', () {
    testWidgets('VoiceOver/TalkBack active selects blind profile',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          _FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final detection = ProfileDetectionImpl(binding: tester.binding);
      addTearDown(detection.dispose);

      final result = detection.detect();
      expect(result.profile, AccessibilityProfile.blind);
      expect(result.screenReader, isTrue);
    });

    testWidgets('no accessibility features selects general profile',
        (tester) async {
      final detection = ProfileDetectionImpl(binding: tester.binding);
      addTearDown(detection.dispose);

      final result = detection.detect();
      expect(result.profile, AccessibilityProfile.general);
      expect(result.screenReader, isFalse);
    });

    testWidgets('reduce motion is detected', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          _FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final detection = ProfileDetectionImpl(binding: tester.binding);
      addTearDown(detection.dispose);

      final result = detection.detect();
      expect(result.reduceMotion, isTrue);
      expect(result.profile, AccessibilityProfile.general);
    });

    testWidgets('bold text is detected', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          _FakeAccessibilityFeatures(boldText: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final detection = ProfileDetectionImpl(binding: tester.binding);
      addTearDown(detection.dispose);

      final result = detection.detect();
      expect(result.boldText, isTrue);
    });

    testWidgets('high contrast is detected', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          _FakeAccessibilityFeatures(highContrast: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final detection = ProfileDetectionImpl(binding: tester.binding);
      addTearDown(detection.dispose);

      final result = detection.detect();
      expect(result.highContrast, isTrue);
    });

    testWidgets('dynamic change from general to blind emits on stream',
        (tester) async {
      // Create detection WITHOUT accessibility features first
      final detection = ProfileDetectionImpl(binding: tester.binding);
      addTearDown(detection.dispose);

      // Collect the first emission from the change stream
      final future = detection.onProfileChanged.first;

      // Enable screen reader — triggers didChangeAccessibilityFeatures
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          _FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final profile = await future;
      expect(profile.profile, AccessibilityProfile.blind);
      expect(profile.screenReader, isTrue);
    });
  });
}

/// Fake [ui.AccessibilityFeatures] for testing.
class _FakeAccessibilityFeatures implements ui.AccessibilityFeatures {
  const _FakeAccessibilityFeatures({
    this.accessibleNavigation = false,
    this.boldText = false,
    this.disableAnimations = false,
    this.highContrast = false,
    this.invertColors = false,
    this.onOffSwitchLabels = false,
    this.reduceMotion = false,
  });

  @override
  final bool accessibleNavigation;

  @override
  final bool boldText;

  @override
  final bool disableAnimations;

  @override
  final bool highContrast;

  @override
  final bool invertColors;

  @override
  final bool onOffSwitchLabels;

  @override
  final bool reduceMotion;

  @override
  bool get supportsAnnounce => false;
}
