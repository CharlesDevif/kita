import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../domain/background_service.dart';
import '../android_background_service_impl.dart';
import '../ios_background_service_impl.dart';

/// Provides the platform-appropriate [KitaBackgroundService].
///
/// On Android: [AndroidBackgroundServiceImpl] with Foreground Service.
/// On iOS: [IosBackgroundServiceImpl] with Background Audio + Location.
/// On other platforms: a no-op stub.
final backgroundServiceProvider = Provider<KitaBackgroundService>((ref) {
  if (Platform.isAndroid) {
    final service = AndroidBackgroundServiceImpl();
    ref.onDispose(service.dispose);
    return service;
  }

  if (Platform.isIOS) {
    final service = IosBackgroundServiceImpl();
    ref.onDispose(service.dispose);
    return service;
  }

  // Other platforms get a no-op stub.
  return _NoOpBackgroundService();
});

/// No-op implementation for unsupported platforms.
class _NoOpBackgroundService implements KitaBackgroundService {
  @override
  BackgroundServiceState get currentState => BackgroundServiceState.idle;

  @override
  Stream<BackgroundServiceState> get stateStream => const Stream.empty();

  @override
  Future<bool> get isRunning async => false;

  @override
  Future<Result<void>> start() async => const Result.success(null);

  @override
  Future<Result<void>> stop() async => const Result.success(null);

  @override
  Future<bool> get isBatteryOptimizationIgnored async => true;

  @override
  Future<Result<bool>> requestBatteryOptimizationExemption() async =>
      const Result.success(true);
}
