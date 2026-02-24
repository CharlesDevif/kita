import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../ai/domain/image_data.dart';
import '../../io/domain/location_service.dart';
import '../../io/domain/motion_service.dart';
import '../domain/sensor_access.dart';

/// A proxy that filters sensor access based on declared permissions.
///
/// Only sensors listed in [allowedPermissions] can be accessed.
/// Unauthorized access returns [PermissionFailure].
class SandboxedSensorAccess implements SensorAccess {
  const SandboxedSensorAccess({
    required this.delegate,
    required this.allowedPermissions,
    required this.pluginId,
  });

  final SensorAccess delegate;
  final Set<String> allowedPermissions;
  final String pluginId;

  static final _log = KitaLogger('Plugin.Sandbox');

  @override
  Future<Result<ImageData>> capturePhoto() async {
    if (!allowedPermissions.contains('camera')) {
      _log.warning('Plugin $pluginId denied camera access');
      return Result.failure(PermissionFailure(
        userMessage: "Le plugin n'a pas la permission camera.",
        logMessage: 'Plugin $pluginId tried camera without permission',
        permission: 'camera',
      ));
    }
    return delegate.capturePhoto();
  }

  @override
  Future<Result<Position>> getCurrentPosition() async {
    if (!allowedPermissions.contains('location')) {
      _log.warning('Plugin $pluginId denied location access');
      return Result.failure(PermissionFailure(
        userMessage: "Le plugin n'a pas la permission localisation.",
        logMessage: 'Plugin $pluginId tried location without permission',
        permission: 'location',
      ));
    }
    return delegate.getCurrentPosition();
  }

  @override
  Future<Result<MotionState>> getMotionState() async {
    if (!allowedPermissions.contains('motion')) {
      _log.warning('Plugin $pluginId denied motion access');
      return Result.failure(PermissionFailure(
        userMessage: "Le plugin n'a pas la permission mouvement.",
        logMessage: 'Plugin $pluginId tried motion without permission',
        permission: 'motion',
      ));
    }
    return delegate.getMotionState();
  }
}
