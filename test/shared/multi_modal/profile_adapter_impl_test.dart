import 'package:flutter_test/flutter_test.dart';

import 'package:kita/shared/multi_modal/profile_adapter_impl.dart';

void main() {
  group('ProfileAdapterImpl profile routing', () {
    test('aveugle profile: vocal ON, haptic ON, visual OFF', () {
      final adapter = ProfileAdapterImpl(profile: UserProfile.aveugle);
      var visualCalled = false;
      var vocalCalled = false;
      var hapticCalled = false;

      adapter.feedback(
        visual: () => visualCalled = true,
        vocal: () => vocalCalled = true,
        haptic: () => hapticCalled = true,
      );

      expect(visualCalled, isFalse, reason: 'Visual should be skipped for blind');
      expect(vocalCalled, isTrue, reason: 'Vocal should be ON for blind');
      expect(hapticCalled, isTrue, reason: 'Haptic should be ON for blind');
    });

    test('sourd profile: visual ON, haptic ON, vocal OFF', () {
      final adapter = ProfileAdapterImpl(profile: UserProfile.sourd);
      var visualCalled = false;
      var vocalCalled = false;
      var hapticCalled = false;

      adapter.feedback(
        visual: () => visualCalled = true,
        vocal: () => vocalCalled = true,
        haptic: () => hapticCalled = true,
      );

      expect(visualCalled, isTrue, reason: 'Visual should be ON for deaf');
      expect(vocalCalled, isFalse, reason: 'Vocal should be skipped for deaf');
      expect(hapticCalled, isTrue, reason: 'Haptic should be ON for deaf');
    });

    test('standard profile: all modalities ON', () {
      final adapter = ProfileAdapterImpl(profile: UserProfile.standard);
      var visualCalled = false;
      var vocalCalled = false;
      var hapticCalled = false;

      adapter.feedback(
        visual: () => visualCalled = true,
        vocal: () => vocalCalled = true,
        haptic: () => hapticCalled = true,
      );

      expect(visualCalled, isTrue);
      expect(vocalCalled, isTrue);
      expect(hapticCalled, isTrue);
    });

    test('aidant profile: visual ON, haptic ON, vocal OFF', () {
      final adapter = ProfileAdapterImpl(profile: UserProfile.aidant);
      var visualCalled = false;
      var vocalCalled = false;
      var hapticCalled = false;

      adapter.feedback(
        visual: () => visualCalled = true,
        vocal: () => vocalCalled = true,
        haptic: () => hapticCalled = true,
      );

      expect(visualCalled, isTrue, reason: 'Visual should be ON for helper');
      expect(vocalCalled, isFalse, reason: 'Vocal should be skipped for helper');
      expect(hapticCalled, isTrue, reason: 'Haptic should be ON for helper');
    });
  });

  group('ProfileAdapterImpl null callbacks', () {
    test('handles null visual callback', () {
      final adapter = ProfileAdapterImpl(profile: UserProfile.standard);
      var vocalCalled = false;

      adapter.feedback(visual: null, vocal: () => vocalCalled = true);

      expect(vocalCalled, isTrue);
    });

    test('handles all null callbacks', () {
      final adapter = ProfileAdapterImpl(profile: UserProfile.standard);
      // Should not throw
      adapter.feedback();
    });
  });

  group('ProfileAdapterImpl activeProfile', () {
    test('returns profile name', () {
      final adapter = ProfileAdapterImpl(profile: UserProfile.aveugle);
      expect(adapter.activeProfile, 'aveugle');
    });

    test('setProfile updates active profile', () {
      final adapter = ProfileAdapterImpl(profile: UserProfile.standard);
      expect(adapter.activeProfile, 'standard');

      adapter.setProfile(UserProfile.sourd);
      expect(adapter.activeProfile, 'sourd');
    });

    test('routing changes after setProfile', () {
      final adapter = ProfileAdapterImpl(profile: UserProfile.standard);
      var vocalCalled = false;

      // Standard: vocal ON
      adapter.feedback(vocal: () => vocalCalled = true);
      expect(vocalCalled, isTrue);

      // Switch to sourd: vocal OFF
      vocalCalled = false;
      adapter.setProfile(UserProfile.sourd);
      adapter.feedback(vocal: () => vocalCalled = true);
      expect(vocalCalled, isFalse);
    });
  });

  group('UserProfile enum', () {
    test('has 4 profiles', () {
      expect(UserProfile.values.length, 4);
    });

    test('all profiles have unique names', () {
      final names = UserProfile.values.map((p) => p.name).toSet();
      expect(names.length, 4);
    });
  });
}
