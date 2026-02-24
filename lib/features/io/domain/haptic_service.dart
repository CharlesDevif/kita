import '../../../core/errors/result.dart';

enum HapticPattern { info, warning, danger, confirmation, custom }

abstract interface class HapticService {
  Future<Result<void>> trigger(HapticPattern pattern);
  Future<Result<void>> info();
  Future<Result<void>> warning();
  Future<Result<void>> danger();
}
