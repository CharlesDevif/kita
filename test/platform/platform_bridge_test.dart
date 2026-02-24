import 'package:flutter_test/flutter_test.dart';
import 'package:kita/platform/platform_bridge.dart';

import '../mocks/mocks.dart';

void main() {
  group('PlatformBridge interface', () {
    test('MockPlatformBridge implements PlatformBridge', () {
      final bridge = MockPlatformBridge();
      expect(bridge, isA<PlatformBridge>());
    });

    test('MockPlatformBridge returns accessibility status', () async {
      final bridge = MockPlatformBridge();
      final result = await bridge.isAccessibilityEnabled();
      expect(result.isSuccess, isTrue);
      result.when(
        success: (enabled) => expect(enabled, isTrue),
        failure: (_) => fail('Should not fail'),
      );
    });

    test('MockPlatformBridge returns accessibility type', () async {
      final bridge = MockPlatformBridge();
      final result = await bridge.getAccessibilityType();
      expect(result.isSuccess, isTrue);
      result.when(
        success: (type) => expect(type, equals('voiceover')),
        failure: (_) => fail('Should not fail'),
      );
    });

    test('MockPlatformBridge returns platform info', () async {
      final bridge = MockPlatformBridge();
      final result = await bridge.getPlatformInfo();
      expect(result.isSuccess, isTrue);
    });
  });
}
