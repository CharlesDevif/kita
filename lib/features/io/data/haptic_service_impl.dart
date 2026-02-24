import 'package:flutter/services.dart';

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/haptic_service.dart';

/// Implementation of [HapticService] using the `com.kita/haptic` platform channel.
///
/// Sends differentiated haptic patterns to native code:
/// - info: 1 light vibration
/// - warning: 2 medium vibrations
/// - danger: 3 heavy vibrations
/// - confirmation: 1 light tap
/// - custom: forwarded as-is
///
/// Falls back to Flutter's built-in [HapticFeedback] when the platform
/// channel is unavailable (e.g., in tests or unsupported platforms).
class HapticServiceImpl implements HapticService {
  HapticServiceImpl({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('com.kita/haptic');

  static final _log = KitaLogger('IO');

  final MethodChannel _channel;

  @override
  Future<Result<void>> trigger(HapticPattern pattern) async {
    try {
      await _channel.invokeMethod<void>('triggerPattern', {
        'pattern': pattern.name,
      });
      _log.debug('Haptic triggered: ${pattern.name}');
      return const Result.success(null);
    } on MissingPluginException {
      // Fallback to Flutter's built-in haptic feedback.
      return _fallbackHaptic(pattern);
    } on PlatformException catch (e, stack) {
      _log.error('Haptic platform error', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Haptic platform error: ${e.code} - ${e.message}',
          cause: e,
          stackTrace: stack,
        ),
      );
    } catch (e, stack) {
      _log.error('Haptic unexpected error', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Haptic trigger failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  @override
  Future<Result<void>> info() => trigger(HapticPattern.info);

  @override
  Future<Result<void>> warning() => trigger(HapticPattern.warning);

  @override
  Future<Result<void>> danger() => trigger(HapticPattern.danger);

  /// Fallback using Flutter's built-in [HapticFeedback] API.
  Future<Result<void>> _fallbackHaptic(HapticPattern pattern) async {
    try {
      switch (pattern) {
        case HapticPattern.info:
        case HapticPattern.confirmation:
          await HapticFeedback.lightImpact();
        case HapticPattern.warning:
          await HapticFeedback.mediumImpact();
        case HapticPattern.danger:
          await HapticFeedback.heavyImpact();
        case HapticPattern.custom:
          await HapticFeedback.vibrate();
        case HapticPattern.presence:
          // Triple light heartbeat: 3x lightImpact with 200ms between each.
          await HapticFeedback.lightImpact();
          await Future<void>.delayed(const Duration(milliseconds: 200));
          await HapticFeedback.lightImpact();
          await Future<void>.delayed(const Duration(milliseconds: 200));
          await HapticFeedback.lightImpact();
      }
      _log.debug('Haptic fallback triggered: ${pattern.name}');
      return const Result.success(null);
    } catch (e, stack) {
      _log.warning('Haptic fallback failed', error: e, stackTrace: stack);
      // Haptic is non-critical — return success even on failure.
      return const Result.success(null);
    }
  }
}
