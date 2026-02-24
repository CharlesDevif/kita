import '../core/errors/result.dart';
import '../features/io/domain/haptic_service.dart';

abstract interface class PlatformBridge {
  Future<Result<bool>> isAccessibilityEnabled();
  Future<Result<String>> getAccessibilityType();
  Future<Result<void>> triggerHaptic(HapticPattern pattern);
  Future<Result<Map<String, dynamic>>> getPlatformInfo();
}
