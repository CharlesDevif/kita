import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/domain/haptic_service.dart';

class MockHapticService implements HapticService {
  HapticPattern? lastPattern;

  @override
  Future<Result<void>> trigger(HapticPattern pattern) async {
    lastPattern = pattern;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> info() => trigger(HapticPattern.info);

  @override
  Future<Result<void>> warning() => trigger(HapticPattern.warning);

  @override
  Future<Result<void>> danger() => trigger(HapticPattern.danger);
}
