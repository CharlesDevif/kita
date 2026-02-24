import 'package:flutter_test/flutter_test.dart';
import 'package:kita/shared/multi_modal/profile_adapter.dart';

import '../../mocks/mocks.dart';

void main() {
  group('ProfileAdapter interface', () {
    test('MockProfileAdapter implements ProfileAdapter', () {
      final adapter = MockProfileAdapter();
      expect(adapter, isA<ProfileAdapter>());
      expect(adapter.activeProfile, equals('blind'));
    });

    test('MockProfileAdapter routes feedback by profile', () {
      final adapter = MockProfileAdapter();
      var vocalCalled = false;
      var hapticCalled = false;

      adapter.feedback(
        vocal: () => vocalCalled = true,
        haptic: () => hapticCalled = true,
      );

      expect(vocalCalled, isTrue);
      expect(hapticCalled, isTrue);
      expect(adapter.feedbackLog, containsAll(['vocal', 'haptic']));
    });

    test('MockProfileAdapter skips null callbacks', () {
      final adapter = MockProfileAdapter();
      adapter.feedback(visual: null, vocal: () {}, haptic: null);
      expect(adapter.feedbackLog, equals(['vocal']));
    });
  });
}
