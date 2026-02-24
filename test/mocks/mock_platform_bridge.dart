import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/platform/platform_bridge.dart';

class MockPlatformBridge implements PlatformBridge {
  bool accessibilityEnabled = true;
  String accessibilityType = 'voiceover';

  @override
  Future<Result<bool>> isAccessibilityEnabled() async {
    return Result.success(accessibilityEnabled);
  }

  @override
  Future<Result<String>> getAccessibilityType() async {
    return Result.success(accessibilityType);
  }

  @override
  Future<Result<void>> triggerHaptic(HapticPattern pattern) async {
    return const Result.success(null);
  }

  @override
  Future<Result<Map<String, dynamic>>> getPlatformInfo() async {
    return const Result.success({
      'os': 'ios',
      'version': '17.0',
      'device': 'iPhone 15',
    });
  }
}
